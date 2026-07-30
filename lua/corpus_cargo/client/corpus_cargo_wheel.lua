-- corpus_cargo_wheel.lua — radial weapon menu (CLIENT)
-- Roadmap #31; design closed in Claude Desktop 2026-07-13 and frozen in
-- docs/mockups/cargo_wheel_menu_mock_v2_1.html (geometry, sector map, hub,
-- chips, hover states — the mock rules until VGUI exists; on divergence the
-- code rules). Third chip group (lights, roadmap #46) frozen in
-- docs/mockups/cargo_wheel_lights_mock_v1_1.html under the same rule.
--
-- GOVERNING RULE — zero new server logic for the WEAPON front-end (CRG-30 as
-- amended by #46). The wheel is an alternative front-end for the 1-7 slot
-- keys: committing a sector sends the SAME slotkey intent
-- corpus_cargo_hotkeys.lua sends and the server resolves it in
-- corpus_cargo_holster.lua exactly as today (intent 8 = throwable,
-- wheel-only, CARGO.Slots.WheelSlots). The quick chips call the EXISTING
-- quick-use route (CARGO.UI.QuickUse) and the tool chips the EXISTING
-- selection function (CARGO.UI.SelectTool). The LIGHTS group commits through
-- its registered sources (client routes of the mods, plus exactly ONE
-- payload-free toggle intent for the engine torch — the single net message
-- the CRG-30 amendment allows; server/corpus_cargo_lights.lua receives it).
--
-- Drawn on HUDPaint, no VGUI: the cursor roams free. gui.EnableScreenClicker
-- swallows mouse clicks as GAME input, so the weapon never fires while you
-- aim the wheel — that part is unchanged and is the whole reason it is on.
-- What it does NOT do is hide the button STATE, and since #48 the wheel reads
-- it to offer the click as a second way to commit (measured in game, planilla
-- W; CRG-31 untouched — releasing the key still commits). Keyboard and
-- movement stay with the game. Every color reads the theme — no baked
-- textures — so #29 (spawnmenu-neutral base + DGL4 tint) re-skins the wheel
-- for free. Sectors are annulus segments triangulated as convex quads:
-- surface.DrawPoly fans from its first vertex and an annulus sector is not
-- convex, so one poly per ~5° step.

local CARGO = Corpus.GetModule("cargo")

CARGO.Wheel = CARGO.Wheel or {}
local T = CARGO.Theme

-- same names the server registered (client Register only builds the string)
local NET_SLOTKEY = Corpus.Net.Register("cargo", "slotkey")
local NET_OPEN    = Corpus.Net.Register("cargo", "open")

local cvEnabled = CreateClientConVar("cargo_wheel", "1", true, false,
    "Enable the radial weapon wheel (hold the key, release to commit)")
-- key convar + Think polling, the project's proven bind pattern (see
-- cargo_key_inventory: PlayerButtonDown does not fire client-side in
-- singleplayer). +cargo_wheel/-cargo_wheel below serve console binds.
local cvKey = CreateClientConVar("cargo_key_wheel", tostring(KEY_G), true, false,
    "Key (KEY_* enum) held to show the weapon wheel; releasing it commits (0 = unbound)")
local cvQuickAnchor = CreateClientConVar("cargo_wheel_quick_anchor", "bottom", true, false,
    "Wheel quick-chip group anchor: bottom, top, left or right")
local cvToolsAnchor = CreateClientConVar("cargo_wheel_tools_anchor", "right", true, false,
    "Wheel tool-chip group anchor: right, left, bottom or top")
local cvLightsAnchor = CreateClientConVar("cargo_wheel_lights_anchor", "left", true, false,
    "Wheel light-chip group anchor: left, right, bottom or top (may share a side: the column shifts outward)")
-- #48 (mock block 06). Default 0: today's shape does not change on its own
-- for anybody. Lights only, and only on the side anchors — see GroupCellSize.
local cvLightsWide = CreateClientConVar("cargo_wheel_lights_wide", "0", true, false,
    "Draw the light chips as wide cells showing name and mode (left/right anchor only; top/bottom falls back to square)")
-- #48 step 2. Default 1, unlike the wide cell: this one ADDS a gesture and
-- changes none of the existing ones (CRG-31 is not repealed — releasing the
-- key still commits exactly as it always has), so the convar is here to turn
-- it off if it gets in the way, not to opt into it.
local cvClick = CreateClientConVar("cargo_wheel_click", "1", true, false,
    "Also commit the hovered wheel action on a left click (releasing the key commits too, as always)")
-- #49. A third mode, OFF by default: the #48 default —a click commits and
-- closes— does not change for anybody. Lights only, and the author's reason
-- is the one the wheel's own vocabulary already gives: sectors EQUIP, quick
-- chips USE, lights TOGGLE, and toggling is the only verb worth repeating.
-- Cycling an ARC9 device is literally pressing N times; equipping the same
-- weapon twice means holstering (the #22 re-press) and using a quick slot
-- twice spends two items.
local cvSticky = CreateClientConVar("cargo_wheel_click_sticky", "0", true, false,
    "Clicking a light chip cycles it WITHOUT closing the wheel (lights only; releasing the key then just closes)")

local function S() return CARGO.ClientState end

local function ToolsShown()
    local cv = GetConVar("cargo_ui_tools")
    return cv == nil or cv:GetBool()
end

-- ------------------------------------------------------------------
-- Sector map (mock clock positions: 12 Primary · 2 Sidearm · 4 Melee ·
-- 6 Hands · 8 Throwable · 10 Secondary — STALKER 2 adapted). Screen angles:
-- 0° = east, +90° = south. `intent` is the slotkey payload the server
-- already resolves: 0 = holster, 1-4 = number-row slots, 8 = throwable.
-- ------------------------------------------------------------------

local SECTORS = {
    { slot = "primary",   label = "Primary",   angle = -90,  intent = 3 },
    { slot = "sidearm",   label = "Sidearm",   angle = -30,  intent = 2 },
    { slot = "melee",     label = "Melee",     angle = 30,   intent = 1 },
    { slot = "hands",     label = "Hands",     angle = 90,   intent = 0 },
    { slot = "throwable", label = "Throwable", angle = 150,  intent = 8 },
    { slot = "secondary", label = "Secondary", angle = -150, intent = 4 },
}
local HALF_SPAN = 25 -- sectors span 50°, gaps 10° (mock geometry)

-- ------------------------------------------------------------------
-- Layout: ONE function resolves center, radii and chip boxes; sectors, hub,
-- chips and the pick logic all drink from it. (The mock v1 bug was exactly
-- two scale systems drifting apart — never again.) Mock viewBox 1200×800,
-- hub r 118 / outer r 300 → uniform ScrH scale, reference @1080: hub ≈ 120,
-- outer ≈ 305.
-- ------------------------------------------------------------------

-- Reference geometry @1080 — the ONE place these numbers live. BuildLayout
-- scales them by ScrH and the pure helpers below reason in the same units.
-- A second copy of 305/46/56/24 anywhere is the mock v1 bug all over again
-- (two scale systems drifting apart), which is why GroupOuterExtent reads
-- from here instead of restating the arithmetic.
local REF = {
    hub = 120,     -- hub radius = the deadzone
    ring = 305,    -- outer ring edge; beyond it = cancel
    margin = 46,   -- ring edge -> first chip group
    chip = 56,     -- the square cell; the only anatomy quick and tools get
    gap = 8,       -- between cells of one group
    gapGroup = 24, -- between groups sharing a side (#46)
    wide = 150,    -- lights-only wide cell (#48, mock block 06)
}

-- pure (harness-covered): anchor collision resolution (spec 4.8). The two
-- chip groups may not share a side: quick wins, tools falls back to the
-- nearest free one. Returns quick, tools, fellBack.
local VALID_ANCHOR = { bottom = true, top = true, left = true, right = true }
local FALLBACK = {
    bottom = { "top", "right", "left" },
    top    = { "bottom", "right", "left" },
    left   = { "right", "bottom", "top" },
    right  = { "left", "bottom", "top" },
}
function CARGO.Wheel.ResolveAnchors(quick, tools)
    quick = VALID_ANCHOR[quick] and quick or "bottom"
    tools = VALID_ANCHOR[tools] and tools or "right"
    if quick ~= tools then return quick, tools, false end
    for _, alt in ipairs(FALLBACK[tools]) do
        if alt ~= quick then return quick, alt, true end
    end
end

-- pure (harness-covered): the THIRD group has its OWN collision rule (#46,
-- author's call — deliberately NOT ResolveAnchors' rule): lights MAY share a
-- side, shifted OUTWARD past whoever already sits there. Returns how many
-- group depths to push: 0 = free side, 1 = quick OR shown tools occupy it,
-- 2 = both (unreachable through the convars — ResolveAnchors never lets
-- quick and tools share a side — but the function answers its whole domain;
-- the mock draws that degenerate case in block 04). Fixed outward order:
-- quick -> tools -> lights (mock, §0.ter e).
function CARGO.Wheel.LightsPushOut(lightsAnchor, quickAnchor, toolsAnchor, toolsShown)
    local push = 0
    if quickAnchor == lightsAnchor then push = push + 1 end
    if toolsShown and toolsAnchor == lightsAnchor then push = push + 1 end
    return push
end

-- pure (harness-covered): the cell size of a chip group (#48, mock block
-- 06). The wide cell (150×56 @1080) is the LIGHTS group's exception and it
-- lives ONLY on the side anchors: on top/bottom the requested width is
-- CLAMPED to the height, so the group degrades to the square cell IN THE
-- SAME BUILD. That is the rule — not an error, not a warning: a row of
-- 150-wide cells does not fit the horizontal axis (mock). Writing it as a
-- clamp means the degradation is nowhere a special case; it IS the clamp,
-- and both anatomies coexist per build. Quick and tools always ask for the
-- square one, so this never reaches them (mock: the wide cell is the light
-- panel's exception, not a new mode of the menu).
function CARGO.Wheel.GroupCellSize(anchor, w, h)
    local horizontal = anchor == "bottom" or anchor == "top"
    if horizontal and w > h then return h, h end
    return w, h
end

-- pure (harness-covered): how far the OUTER edge of a chip group ends up
-- from the wheel center, in the @1080 units the layout scales by ScrH.
--
-- It exists to CORRECT the mock, which warns (block 06) that the wide cell
-- with outward push "goes off screen at 1280×720". It does not. The group
-- grows outward from the same anchor line, so the far edge sits at
--     ring + margin + push·(chip + gapGroup) + cellLong
-- = 501 / 581 / 661 @1080 for push 0 / 1 / 2. The layout scales by HEIGHT,
-- so at 1280×720 those are ~334 / ~387 / ~441 real px against the 640 of
-- half the screen: it fits. The tight case is 4:3, not 16:9, and push 2 is
-- unreachable through the convars anyway (ResolveAnchors never lets quick
-- and tools share a side). The harness pins this so nobody re-inherits the
-- warning without recomputing it — which is exactly the mistake #46 paid
-- for with the UnequipDelay claim it had copied from prose.
function CARGO.Wheel.GroupOuterExtent(push, cellLong)
    return REF.ring + REF.margin + push * (REF.chip + REF.gapGroup) + cellLong
end

local warnedAnchors
local warnedPush

function CARGO.Wheel.BuildLayout(lightCount)
    local sw, sh = ScrW(), ScrH()
    local sc = sh / 1080
    local L = {
        cx = sw / 2, cy = sh / 2, scale = sc,
        rIn = REF.hub * sc,
        rOut = REF.ring * sc,
    }

    local quick, tools, fell = CARGO.Wheel.ResolveAnchors(
        cvQuickAnchor:GetString(), cvToolsAnchor:GetString())
    L.quickAnchor, L.toolsAnchor = quick, tools
    local warnKey = quick .. "/" .. tools
    if fell and warnedAnchors ~= warnKey then
        warnedAnchors = warnKey
        Corpus.Log("cargo", "wheel: anclajes de chips en conflicto — tools cae a '"
            .. tools .. "' (cargo_wheel_quick_anchor / cargo_wheel_tools_anchor)")
    end

    -- chip cells: horizontal row on top/bottom anchors, vertical column on
    -- the sides. One resolver serves all three groups (spec 4.8) — and since
    -- #48 it takes the CELL SIZE per group instead of closing over one
    -- constant, which is the whole structural cost of the wide cell (mock
    -- block 06: "the resolver stops having a single cell constant").
    local chip = math.Round(REF.chip * sc)
    local gap = math.Round(REF.gap * sc)
    local margin = math.Round(REF.margin * sc)
    local function GroupCells(anchor, count, cw, ch)
        local horizontal = anchor == "bottom" or anchor == "top"
        cw, ch = CARGO.Wheel.GroupCellSize(anchor, cw, ch)
        local gw = horizontal and (count * cw + (count - 1) * gap) or cw
        local gh = horizontal and ch or (count * ch + (count - 1) * gap)
        local x, y
        if anchor == "bottom" then
            x, y = L.cx - gw / 2, L.cy + L.rOut + margin
        elseif anchor == "top" then
            x, y = L.cx - gw / 2, L.cy - L.rOut - margin - gh
        elseif anchor == "left" then
            x, y = L.cx - L.rOut - margin - gw, L.cy - gh / 2
        else -- right
            x, y = L.cx + L.rOut + margin, L.cy - gh / 2
        end
        local cells = {}
        for i = 1, count do
            cells[i] = {
                x = horizontal and (x + (i - 1) * (cw + gap)) or x,
                y = horizontal and y or (y + (i - 1) * (ch + gap)),
                w = cw, h = ch,
            }
        end
        return cells
    end
    -- quick and tools are 56×56 BY DEFINITION and say so at the call site
    L.quickCells = GroupCells(quick, CARGO.Slots.QUICK_COUNT, chip, chip)
    L.toolCells = GroupCells(tools, #CARGO.Slots.Tools, chip, chip)

    -- Third group: lights (#46, mock blocks 01/03/04). The outward push is
    -- applied to the finished cells, along the anchor axis only. Each
    -- occupant costs chip + gapGroup (24 @1080p between groups vs 8 between
    -- cells — the mock's block separation, §0.ter e). Theme-scaled, never a
    -- loose literal. The list is dynamic: zero sources -> no cells at all.
    --
    -- #48: the WIDE cell changes none of that arithmetic. The multiplier is
    -- the depth of whoever ALREADY sits on the side — quick or tools, square
    -- by definition — while the wide cell only extends the lights group's
    -- own far edge (see GroupOuterExtent). And it exists only on the side
    -- anchors: GroupCellSize clamps it back to square on top/bottom, in the
    -- same build, so both anatomies coexist and the push keeps working.
    local lights = cvLightsAnchor:GetString()
    lights = VALID_ANCHOR[lights] and lights or "left"
    L.lightsAnchor = lights
    if lightCount ~= nil and lightCount > 0 then
        L.lightCells = GroupCells(lights, lightCount,
            cvLightsWide:GetBool() and math.Round(REF.wide * sc) or chip, chip)
        local push = CARGO.Wheel.LightsPushOut(lights, quick, tools, ToolsShown())
        if push > 0 then
            local gapGroup = math.Round(REF.gapGroup * sc)
            local off = push * (chip + gapGroup)
            local dx, dy = 0, 0
            if lights == "left" then dx = -off
            elseif lights == "right" then dx = off
            elseif lights == "top" then dy = -off
            else dy = off end
            for _, c in ipairs(L.lightCells) do
                c.x, c.y = c.x + dx, c.y + dy
            end
            -- one line, never silent, never an error (same pattern as the
            -- tools fallback warning above)
            local pushKey = lights .. "/" .. push
            if warnedPush ~= pushKey then
                warnedPush = pushKey
                Corpus.Log("cargo", "wheel: luces comparten lado '" .. lights
                    .. "' — columna desplazada hacia afuera ("
                    .. push .. " grupo(s); cargo_wheel_lights_anchor)")
            end
        end
    end
    return L
end

-- annulus sector triangulated as convex quads (~5° steps)
local function SectorQuads(L, centerAng)
    local rIn = L.rIn + 8 * L.scale -- visual breathing room around the hub
    local quads = {}
    local a0 = centerAng - HALF_SPAN
    local steps = 10
    for i = 0, steps - 1 do
        local b0 = math.rad(a0 + HALF_SPAN * 2 * i / steps)
        local b1 = math.rad(a0 + HALF_SPAN * 2 * (i + 1) / steps)
        quads[#quads + 1] = {
            { x = L.cx + math.cos(b0) * L.rOut, y = L.cy + math.sin(b0) * L.rOut },
            { x = L.cx + math.cos(b1) * L.rOut, y = L.cy + math.sin(b1) * L.rOut },
            { x = L.cx + math.cos(b1) * rIn,    y = L.cy + math.sin(b1) * rIn },
            { x = L.cx + math.cos(b0) * rIn,    y = L.cy + math.sin(b0) * rIn },
        }
    end
    return quads
end

-- ------------------------------------------------------------------
-- Pick: what the cursor is over. Chips first — a cursor on a chip NEVER
-- activates a sector (spec 4.6). Inside the ring the pick is by nearest
-- sector center, so the 10° gaps stay forgiving.
-- ------------------------------------------------------------------

local function AngleDiff(a, b)
    local d = (a - b) % 360
    if d > 180 then d = d - 360 end
    return d
end

-- pure given a layout + cursor (harness-covered)
function CARGO.Wheel.PickAt(L, mx, my, toolsShown)
    for n, c in ipairs(L.quickCells) do
        if mx >= c.x and mx <= c.x + c.w and my >= c.y and my <= c.y + c.h then
            return { kind = "quick", n = n }
        end
    end
    if toolsShown then
        for i, c in ipairs(L.toolCells) do
            if mx >= c.x and mx <= c.x + c.w and my >= c.y and my <= c.y + c.h then
                return { kind = "tool", i = i }
            end
        end
    end
    if L.lightCells ~= nil then
        for i, c in ipairs(L.lightCells) do
            if mx >= c.x and mx <= c.x + c.w and my >= c.y and my <= c.y + c.h then
                return { kind = "light", i = i }
            end
        end
    end

    local dx, dy = mx - L.cx, my - L.cy
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < L.rIn then return { kind = "deadzone" } end
    if dist > L.rOut then return { kind = "outside" } end

    local ang = math.deg(math.atan2(dy, dx))
    local best, bestDiff
    for _, sec in ipairs(SECTORS) do
        local diff = math.abs(AngleDiff(ang, sec.angle))
        if bestDiff == nil or diff < bestDiff then best, bestDiff = sec, diff end
    end
    return { kind = "sector", sector = best }
end

-- ------------------------------------------------------------------
-- Light source registry (#46, Cargo_Architecture.md §17.8). Third live
-- instance of the registration pattern, after StatusPanel.RegisterBar (§11)
-- and Capture.RegisterWorldPickup (#47) — nothing here is invented. The list
-- is REGISTERED, never hardcoded: a chemlight that becomes a Cargo item
-- tomorrow enters as a source without touching the wheel, and the owner of
-- its logic is the item's module, not Cargo (CRG-1).
--
-- Registration runs once at boot; `available` runs at OPEN (the one thing
-- TLS did right: its list builds on the hold, not every frame); `state`
-- runs every painted frame, because transit must animate (CRG-64).
--
--   spec = {
--     label                     display name (hub line 1; letter fallback)
--     icon                      IMaterial | nil (nil -> initial letter)
--     available(ply, wep) -> bool     does this source exist RIGHT NOW?
--                                     absent mod / no device = false, the
--                                     chip does not exist (CRG-32: nothing
--                                     is invented, columns shrink honestly)
--     state(ply, wep) -> {            live paint data:
--       on       bool|nil             nil while in transit — the chip
--                                     asserts NEITHER the old nor the new
--                                     state (CRG-64)
--       mode     string|nil           current mode name (hub secondary)
--       emitters {colorKey}|nil       ACTIVE emitters -> 3px foot bars, mock
--                                     lexicon: "accent" light, "green"
--                                     visible laser, "orange" IR
--                                     illuminator, "red" IR laser. Only what
--                                     is happening is drawn (§0.ter d)
--       transit  {start,duration}|nil CurTime window of an async third-party
--                                     toggle (CRG-64 paints it)
--       blocked  string|nil           #51: this source is OVERRIDDEN right
--                                     now by something else, so its state is
--                                     true but useless. The string says WHO
--                                     (hub line). Painted as the hatch, NOT
--                                     as OFF: "on but you cannot see it" is
--                                     a third thing, and calling it OFF would
--                                     be the lie CRG-32 forbids.
--     }
--     toggle(ply, wep)          the commit. Mute rejection: if it cannot
--                               run, it runs nothing (deferred block 07)
--     toggleBack(ply, wep)      OPTIONAL (#50): the same commit one step
--                               BACKWARDS, for a source whose modes form a
--                               cycle. Absent = the right button does nothing
--                               over this chip, and that is the honest answer
--                               (CRG-32): a torch has no reverse, and neither
--                               has anything else in the wheel — un-equipping
--                               is not "equipping backwards".
--     expand(ply, wep) -> {chip}|nil  optional: one SOURCE, N CHIPS (ARC9
--                               devices, one per toggleable slot). Each chip
--                               carries the same label/icon/state/toggle.
--   }
-- ------------------------------------------------------------------

CARGO.Wheel._lightSources = CARGO.Wheel._lightSources or {}

function CARGO.Wheel.RegisterLightSource(id, spec)
    if not isstring(id) or id == "" then
        error("Cargo.Wheel.RegisterLightSource: 'id' must be a non-empty string", 2)
    end
    if not istable(spec) or not isfunction(spec.available)
        or not (isfunction(spec.toggle) or isfunction(spec.expand)) then
        error("Cargo.Wheel.RegisterLightSource: spec needs available (function) and toggle or expand (function) (id '" .. id .. "')", 2)
    end

    local src = {
        id = id,
        label = isstring(spec.label) and spec.label or id,
        icon = spec.icon,
        available = spec.available,
        state = spec.state,
        toggle = spec.toggle,
        toggleBack = spec.toggleBack, -- optional (#50); absent = no reverse
        expand = spec.expand,
    }
    -- re-registering an id replaces in place (lua refresh friendly); display
    -- order = registration order, same as the status bars
    for i, existing in ipairs(CARGO.Wheel._lightSources) do
        if existing.id == id then
            CARGO.Wheel._lightSources[i] = src
            return src
        end
    end
    CARGO.Wheel._lightSources[#CARGO.Wheel._lightSources + 1] = src
    return src
end

-- Builds the flat chip list for THIS open (never per frame). A source that
-- errors is skipped loudly — one broken registrant must not kill the column
-- (same defensive rule as the status panel getValue).
function CARGO.Wheel.BuildLightList()
    local out = {}
    local ply = LocalPlayer()
    local wep = IsValid(ply) and ply:GetActiveWeapon() or nil
    if not IsValid(wep) then wep = nil end
    for _, src in ipairs(CARGO.Wheel._lightSources) do
        local ok, avail = pcall(src.available, ply, wep)
        if not ok then
            Corpus.Log("cargo", "wheel: fuente de luz '" .. src.id
                .. "' falló en available (reportar tal cual): " .. tostring(avail))
        elseif avail then
            if src.expand ~= nil then
                local okx, chips = pcall(src.expand, ply, wep)
                if not okx then
                    Corpus.Log("cargo", "wheel: fuente de luz '" .. src.id
                        .. "' falló en expand (reportar tal cual): " .. tostring(chips))
                elseif istable(chips) then
                    for _, chip in ipairs(chips) do
                        out[#out + 1] = chip
                    end
                end
            else
                out[#out + 1] = src
            end
        end
    end
    return out
end

-- Live paint data of one chip, guarded (the paint hook pcalls too, but a
-- broken state() must degrade to an empty table, not kill the frame).
--
-- IT ALSO LOGS, and that is not decoration (2nd pass, planilla V ronda 2):
-- the first version swallowed the error silently, so a state() that THREW
-- was pixel-for-pixel identical to a state() that answered OFF. Its two
-- siblings — available and expand, right above — already log loudly; this
-- one not doing so is the asymmetry that let the torch defect survive a
-- whole round of the planilla. Same lesson the harness paid for in the stub
-- that did not hold state (§0.bis 3), and the same one the double-bound G
-- taught in game: an instrument that cannot distinguish "broken" from
-- "nothing happened" is not an instrument. One line per distinct error, so
-- a per-frame failure cannot flood the console.
local warnedState = {}

local function LightState(chip)
    if not isfunction(chip.state) then return {} end
    local ply = LocalPlayer()
    local wep = IsValid(ply) and ply:GetActiveWeapon() or nil
    if not IsValid(wep) then wep = nil end
    local ok, s = pcall(chip.state, ply, wep)
    if not ok then
        local key = tostring(chip.label) .. "|" .. tostring(s)
        if not warnedState[key] then
            warnedState[key] = true
            Corpus.Log("cargo", "wheel: chip de luz '" .. tostring(chip.label)
                .. "' falló en state (reportar tal cual): " .. tostring(s))
        end
        return {}
    end
    return istable(s) and s or {}
end

-- How far along an in-flight transit is, against the duration the MOD
-- reports — nothing baked (CRG-64). One copy: the hub and the chip both
-- paint it, and #48 would have made the wide cell a third.
local function TransitFrac(s)
    local dur = tonumber(s.transit.duration) or 0
    local t0 = tonumber(s.transit.start) or 0
    return dur > 0 and math.Clamp((CurTime() - t0) / dur, 0, 1) or 1
end

-- The SECONDARY line of a light chip and its color, in ONE place: transit
-- label (asserts neither state — CRG-64) > mode name exactly as the mod
-- gives it > ON/OFF. The hub has painted this since #46 and the wide cell of
-- #48 paints the same line without a hover, so the priority lives here — two
-- copies would drift the day a fifth state appears. Also returns the branch,
-- because what goes UNDER the line differs per branch.
-- Returns text, color, kind ("transit" | "mode" | "state").
local function LightSecondary(s)
    if istable(s.transit) then
        return isstring(s.transit.label) and s.transit.label or "…",
            T.Colors.amber, "transit"
    elseif isstring(s.mode) then
        return s.mode, s.on == true and T.Colors.accent or T.Colors.textDim, "mode"
    end
    return s.on == true and "ON" or "OFF",
        s.on == true and T.Colors.accent or T.Colors.textDim, "state"
end

-- ------------------------------------------------------------------
-- Data readers (spec 4.5 — none of these values is invented here)
-- ------------------------------------------------------------------

-- Hands is an action, not a slot: it never holds an entry
local function SlotData(sec)
    if sec.slot == "hands" then return nil end
    local snap = S()
    return snap and snap.equip and snap.equip[sec.slot] or nil
end

local function ActiveClass()
    local ply = LocalPlayer()
    local wep = IsValid(ply) and ply:GetActiveWeapon() or nil
    return IsValid(wep) and wep:GetClass() or nil
end

-- Engine ammo type consumed by an equipped weapon. Every leg verified
-- against the live ARC9 base (2nd-pass diagnosis, 2026-07-13): its own
-- Ammo1() reads GetProcessedValue("Ammo") (sh_reload.lua:578), the plain
-- class field SWEP.Ammo is the same type as static data ("smg1"/"ar2"/"357"
-- across the EFT packs) and stays readable even when the processed-value
-- machinery has no client state yet; GetPrimaryAmmoType is unreliable on
-- ARC9 (class-level Primary.Ammo is "" — sh shared.lua:334 — and only
-- Initialize corrects it per instance), so it is the LAST leg, for engine
-- weapons. Exposed for the offline harness.
function CARGO.Wheel.AmmoTypeOf(wep)
    if wep.ARC9 then
        local ok, t = pcall(wep.GetProcessedValue, wep, "Ammo")
        if ok and isstring(t) and t ~= "" then return t end
        if isstring(wep.Ammo) and wep.Ammo ~= "" then return wep.Ammo end
    end
    local ok, t = pcall(wep.GetPrimaryAmmoType, wep)
    if ok and isnumber(t) and t >= 0 then return t end
    return nil
end

-- magazine / reserve of an equipped weapon (2nd-pass fix, roadmap #33: this
-- returned nil/nil in game). The clip reads the live SWEP; a Clip1 of -1
-- (no networked local weapon data) falls back to ARC9's own LoadedRounds
-- mirror (NetworkVar, shared.lua:1592 — broadcast, so it answers even for a
-- non-deployed weapon). The reserve reads the ENGINE POOL, which the §16
-- mirror keeps equal to the belt sum — read, never recomputed. Missing
-- pieces still just hide. Exposed for the offline harness.
function CARGO.Wheel.AmmoInfo(def)
    local ply = LocalPlayer()
    if not IsValid(ply) or not isstring(def.weapon_class) then return nil, nil end
    local wep = ply:GetWeapon(def.weapon_class)
    if not IsValid(wep) then return nil, nil end

    local clip
    local okC, c = pcall(wep.Clip1, wep)
    if okC and isnumber(c) and c >= 0 then clip = c end
    if clip == nil and wep.ARC9 and isfunction(wep.GetLoadedRounds) then
        local okL, lr = pcall(wep.GetLoadedRounds, wep)
        if okL and isnumber(lr) and lr >= 0 then clip = lr end
    end

    local ammoType = CARGO.Wheel.AmmoTypeOf(wep)
    local reserve = ammoType ~= nil and ply:GetAmmoCount(ammoType) or nil
    return clip, reserve
end
local AmmoInfo = CARGO.Wheel.AmmoInfo

-- Display caliber when the def carries none (autogen captured before #33 or
-- an equipped-only weapon whose def never re-captured): derive it live from
-- the weapon's engine type, with Cargo's own label — the one the belt badge
-- groups on. Exposed for the offline harness.
function CARGO.Wheel.CaliberOf(def)
    if istable(def.ammo) and def.ammo.caliber then return def.ammo.caliber end
    local ply = LocalPlayer()
    if not IsValid(ply) or not isstring(def.weapon_class) then return nil end
    local wep = ply:GetWeapon(def.weapon_class)
    if not IsValid(wep) then return nil end
    local hl2 = CARGO.Wheel.AmmoTypeOf(wep)
    if not isstring(hl2) then return nil end -- a numeric id names no label
    return CARGO.Ammo.CaliberForType(hl2)
end

-- ARC9 fire mode — COMPAT-RUNTIME: SWEP:GetFiremodeName() verified against
-- the live base (arc9_base/sh_firemodes.lua:158; ARC9's own HUD calls it
-- client-side). Not exposed -> the field hides, never guessed.
local function FiremodeOf(def)
    local ply = LocalPlayer()
    if not IsValid(ply) or not isstring(def.weapon_class) then return nil end
    local wep = ply:GetWeapon(def.weapon_class)
    if not IsValid(wep) or wep.ARC9 == nil then return nil end
    if not isfunction(wep.GetFiremodeName) then return nil end
    local ok, name = pcall(wep.GetFiremodeName, wep)
    return (ok and isstring(name)) and name or nil
end

-- ------------------------------------------------------------------
-- Commit (release over...): every branch is an EXISTING route
-- ------------------------------------------------------------------

local function SendSlotKey(n)
    net.Start(NET_SLOTKEY)
    net.WriteUInt(n, 4)
    net.SendToServer()
end

-- #52: a source that declares itself OVERRIDDEN refuses the commit. The
-- author's argument, and it is better than the one this file used to carry:
-- pressing the engine torch under an ARC9 device is not a valid action we
-- would be getting in the way of, it is an action THE MOD UNDOES BY ITSELF —
-- its PostModify turns the engine flashlight off the moment you cycle the
-- device (sh_attach.lua:143-144, verified). Letting it through would mean
-- committing something that dies on the next click.
--
-- ONE rule, TWO consumers: Commit refuses, and ClickCommit reads the same
-- answer to decide that a refusal must NOT close the menu.
local FLASH_TIME = 0.25

local function BlockedChip(hover, lights)
    if hover == nil or hover.kind ~= "light" then return nil end
    local chip = lights and lights[hover.i] or nil
    if chip == nil then return nil end
    return isstring(LightState(chip).blocked) and chip or nil
end

-- `back` is the right button (#50): the same commit ONE STEP BACKWARDS. Only
-- the lights have a reverse, and only where the source declares `toggleBack`;
-- nothing else in the wheel does — un-equipping is not "equipping backwards"
-- and a quick slot has no undo. A back commit over anything else is an honest
-- no-op rather than an invented meaning (CRG-32).
local function Commit(hover, lights, back)
    if hover == nil then return end
    if back and hover.kind ~= "light" then return end
    -- #52: overridden -> refused, in BOTH directions. Reported so the caller
    -- can tell "nothing happened because I said no" from "nothing happened".
    if BlockedChip(hover, lights) ~= nil then return "blocked" end
    if hover.kind == "quick" then
        -- the server re-checks suit lock / empties; this is only the trigger
        CARGO.UI.QuickUse(hover.n)
    elseif hover.kind == "tool" then
        CARGO.UI.SelectTool(CARGO.Slots.Tools[hover.i])
    elseif hover.kind == "light" then
        local chip = lights and lights[hover.i] or nil
        -- written long-hand ON PURPOSE: `back and chip.toggleBack or
        -- chip.toggle` falls silently FORWARD on a chip with no reverse, which
        -- turns "this source cannot go back" into "it went the wrong way".
        -- The caller already refuses a back click over a chip without
        -- toggleBack, so this looks redundant — it is not: the pick runs TWICE
        -- (once to decide, once inside Close) and the cursor can move between
        -- them, so the chip that gets here is not guaranteed to be the one
        -- that passed the guard. The harness exercises exactly that divergence.
        local fn
        if chip ~= nil then
            if back then fn = chip.toggleBack else fn = chip.toggle end
        end
        if isfunction(fn) then
            -- rejection is MUTE in this pass (block 07 deferred): a toggle
            -- that cannot run runs nothing, and the wheel closes as always.
            -- Close() already wraps the commit in pcall (CRG-25).
            local ply = LocalPlayer()
            local wep = IsValid(ply) and ply:GetActiveWeapon() or nil
            if not IsValid(wep) then wep = nil end
            fn(ply, wep)
        end
    elseif hover.kind == "sector" then
        local sec = hover.sector
        if sec.intent == 0 then
            SendSlotKey(0) -- Hands: the existing holster intent
        elseif SlotData(sec) ~= nil then
            -- the server holsters when the sector's weapon is already in
            -- hand — same re-press semantics as the number keys (#22)
            SendSlotKey(sec.intent)
        end
        -- empty sector: honest no-op (the hub said so on hover)
    end
    -- deadzone / outside: cancel
end

-- ------------------------------------------------------------------
-- Open / close
-- ------------------------------------------------------------------

local state -- nil when closed; { L, sectors = { {sec, quads} }, hover }

function CARGO.Wheel.Open()
    if state ~= nil or not cvEnabled:GetBool() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    -- never fight another cursor context (inventory frame, spawnmenu, chat)
    if gui.IsGameUIVisible() then return end
    if isfunction(vgui.CursorVisible) and vgui.CursorVisible() then return end

    -- a session's first open may predate any inventory sync: ask for one
    -- (the existing open intent answers with the same snapshot the UI uses)
    if S() == nil then
        net.Start(NET_OPEN)
        net.SendToServer()
    end

    -- the light list builds AT OPEN, never per frame (§17.8 — the one thing
    -- TLS did right); state() is what reads live afterwards
    local wep = IsValid(ply) and ply:GetActiveWeapon() or nil
    if not IsValid(wep) then wep = nil end
    local lights = CARGO.Wheel.BuildLightList()
    local L = CARGO.Wheel.BuildLayout(#lights)
    local sectors = {}
    for i, sec in ipairs(SECTORS) do
        sectors[i] = { sec = sec, quads = SectorQuads(L, sec.angle) }
    end
    state = { L = L, sectors = sectors, lights = lights, lightsWep = wep,
        hover = { kind = "deadzone" }, clicked = false, flash = nil }
    gui.EnableScreenClicker(true)
    gui.SetMousePos(L.cx, L.cy) -- start in the deadzone, like the mock
end

-- The list builds AT OPEN (§17.8) — but the weapon in hand CAN change while
-- the wheel is held, because the keyboard deliberately stays alive (§17.4).
-- Measured in game (planilla V, V8): swapping from a weapon with a laser to
-- one without left the old device chip on screen, and a chip of a weapon you
-- are no longer holding cannot tell the truth about anything. So the list
-- re-builds when — and ONLY when — the held weapon changes: still never per
-- frame, which is the part of the rule that mattered.
--
-- The author's other option, blocking the 1-7 keys while the wheel is open,
-- was refused on purpose: the wheel does not own the keyboard, and stomping
-- a bind in silence is the one thing this whole group exists to avoid.
--
-- The NVG transit SURVIVES the rebuild: it lives in an upvalue of
-- client/corpus_cargo_lights.lua, not in the chip table, so CRG-64 keeps
-- painting across a weapon swap mid-window.
local function RefreshLightsIfWeaponChanged()
    if state == nil then return end
    local ply = LocalPlayer()
    local wep = IsValid(ply) and ply:GetActiveWeapon() or nil
    if not IsValid(wep) then wep = nil end
    if wep == state.lightsWep then return end

    state.lightsWep = wep
    state.lights = CARGO.Wheel.BuildLightList()
    state.L = CARGO.Wheel.BuildLayout(#state.lights)
    state.sectors = {}
    for i, sec in ipairs(SECTORS) do
        state.sectors[i] = { sec = sec, quads = SectorQuads(state.L, sec.angle) }
    end
end

-- the pick re-runs at release time: the cursor may have moved since the
-- last painted frame, and the commit must honor where it actually let go
function CARGO.Wheel.Close(commit, back)
    if state == nil then return end
    local L, lights = state.L, state.lights
    -- read the cursor BEFORE releasing the screen clicker: once it is off,
    -- gui.MousePos is not guaranteed to keep reporting the free-cursor
    -- position (post-1st-pass hardening, 2026-07-13)
    local mx, my = gui.MousePos()
    state = nil
    gui.EnableScreenClicker(false)
    if commit then
        -- protected: a commit error must never strand the wheel half-closed
        local ok, err = pcall(function()
            Commit(CARGO.Wheel.PickAt(L, mx, my, ToolsShown()), lights, back)
        end)
        if not ok then
            Corpus.Log("cargo", "wheel: error en el commit (reportar tal cual): "
                .. tostring(err))
        end
    end
end

-- ------------------------------------------------------------------
-- Painting (HUDPaint). All colors from the theme; fonts are the UI's.
-- ------------------------------------------------------------------

local function DrawChipBox(c, hovered)
    surface.SetDrawColor(hovered and T.Colors.cellHover or T.Colors.cell)
    surface.DrawRect(c.x, c.y, c.w, c.h)
    surface.SetDrawColor(hovered and T.Colors.borderHi or T.Colors.border)
    surface.DrawOutlinedRect(c.x, c.y, c.w, c.h, 1)
end

local function DrawEntryIcon(entry, x, y, size, dim)
    local icon = CARGO.Icons.Get(entry.id)
    if icon ~= nil then
        T.DrawIconFit(icon, x, y, size, size)
    else
        local def = CARGO.Items.Get(entry.id)
        draw.SimpleText(def and string.upper(def.name:sub(1, 1)) or "?",
            "CargoHeading", x + size / 2, y + size / 2,
            dim and T.Colors.textDim or T.Colors.text,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- hub content per hover target (spec 4.5: ONE universal info surface)
local function DrawHub(L, hover, lights)
    local r = L.rIn - 6 * L.scale
    T.DrawCircleOutlined(L.cx, L.cy, r, T.Colors.panel, T.Colors.borderHi, 2)

    local maxW = r * 1.6
    local lines = {} -- { text, font, color }
    local cond, hint
    local transitFrac, barsRow -- lights only (mock block 05)

    if hover.kind == "light" then
        -- two lines + hint (§0.ter f): principal = what it is, secondary =
        -- state or mode, hint = the action. Only the transit adds the
        -- segmented bar. No chip carries its own tooltip (§17.5 intact).
        local chip = lights and lights[hover.i] or nil
        local s = chip ~= nil and LightState(chip) or {}
        lines[1] = { chip and chip.label or "?", "CargoTitle", T.Colors.text }
        -- one rule for the line (LightSecondary); the branch decides only
        -- what goes UNDER it
        local secTxt, secCol, secKind = LightSecondary(s)
        lines[2] = { secTxt, "CargoHeading", secCol }
        if secKind == "transit" then
            transitFrac = TransitFrac(s)
        elseif secKind == "mode" and s.on == true
            and istable(s.emitters) and #s.emitters > 0 then
            barsRow = s.emitters -- the same bars the chip teaches
        end
        hint = "Release to toggle"
        -- #51: overridden by something else. The state line stays TRUTHFUL —
        -- it really is on — and the HINT is what changes, because "ON" alone
        -- was true and useless: it promised a beam the player would not see.
        -- Saying who took it over is the whole content of the fix.
        if isstring(s.blocked) then hint = s.blocked end
    elseif hover.kind == "sector" and hover.sector.slot == "hands" then
        lines[1] = { "Hands", "CargoTitle", T.Colors.text }
        hint = "Release to holster"
    elseif hover.kind == "sector" then
        local sec = hover.sector
        local entry = SlotData(sec)
        if entry == nil then
            lines[1] = { sec.label, "CargoTitle", T.Colors.textDim }
            hint = "Empty slot — does nothing"
        else
            local def = CARGO.Items.Get(entry.id)
            local name = def and def.name or entry.id
            lines[1] = { name, "CargoTitle", T.Colors.text }

            -- caliber · fire mode · A/B group — each piece hides when absent
            local bits = {}
            local cal = def and CARGO.Wheel.CaliberOf(def) or nil
            if cal ~= nil then bits[#bits + 1] = cal end
            local fm = def and FiremodeOf(def) or nil
            if fm ~= nil then bits[#bits + 1] = fm end
            if entry.blob and entry.blob.ammo_group then
                bits[#bits + 1] = "Group " .. entry.blob.ammo_group
            end
            if #bits > 0 then
                lines[#lines + 1] = { table.concat(bits, " · "), "CargoSmall", T.Colors.amber }
            end

            if entry.count ~= nil then
                -- throwable stack: the count IS the ammo line
                lines[#lines + 1] = { "×" .. entry.count, "CargoHeading", T.Colors.text }
            elseif def then
                local clip, reserve = AmmoInfo(def)
                if clip ~= nil or reserve ~= nil then
                    lines[#lines + 1] = {
                        (clip ~= nil and tostring(clip) or "—") .. " / "
                            .. (reserve ~= nil and tostring(reserve) or "—"),
                        "CargoHeading", T.Colors.text }
                end
            end

            cond = T.ConditionOf(entry)
            local active = def and isstring(def.weapon_class)
                and def.weapon_class == ActiveClass()
            hint = active and "Release to holster" or "Release to equip"
        end
    elseif hover.kind == "quick" then
        local snap = S()
        local unlocked = snap and hover.n <= (snap.quickUnlocked or 0)
        local itemId = snap and snap.quick and snap.quick[hover.n] or nil
        local def = itemId and CARGO.Items.Get(itemId) or nil
        if not unlocked then
            lines[1] = { "F" .. hover.n, "CargoTitle", T.Colors.textDim }
            hint = "Unlocked by the equipped suit"
        elseif def == nil then
            lines[1] = { "F" .. hover.n, "CargoTitle", T.Colors.textDim }
            hint = "Empty quick slot"
        else
            lines[1] = { def.name, "CargoTitle", T.Colors.text }
            lines[2] = { "×" .. CARGO.UI.QuickCount(itemId), "CargoHeading", T.Colors.text }
            hint = "Release to use"
        end
    elseif hover.kind == "tool" then
        local tool = CARGO.Slots.Tools[hover.i]
        local slot = CARGO.Slots.ById[tool.slotId]
        lines[1] = { slot and slot.label or tool.class, "CargoTitle", T.Colors.text }
        hint = "Release to select"
    else
        -- deadzone / outside: say what is in hand, offer the exit
        local ply = LocalPlayer()
        local wep = IsValid(ply) and ply:GetActiveWeapon() or nil
        local held = IsValid(wep) and wep:GetPrintName() or "Hands"
        lines[1] = { held, "CargoTitle", T.Colors.textDim }
        hint = "Dead zone — release to cancel"
    end

    local extraH = (cond ~= nil and 14 or 0)
        + (transitFrac ~= nil and 14 or 0) + (barsRow ~= nil and 10 or 0)
    local y = L.cy - (#lines * 22 + extraH) / 2
    for _, ln in ipairs(lines) do
        draw.SimpleText(T.FitText(ln[1], ln[2], maxW), ln[2],
            L.cx, y + 11, ln[3], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        y = y + 22
    end
    if cond ~= nil then
        local bw = maxW * 0.7
        -- <25% paints danger (spec 4.5)
        local col = cond < 25 and T.Colors.red or T.ConditionColor(cond)
        T.DrawSegBar(L.cx - bw / 2, y + 4, bw, 5, cond / 100, col)
        y = y + 14
    end
    if transitFrac ~= nil then
        -- segmented progress against the duration the MOD reports — nothing
        -- baked (mock block 05, CRG-64)
        local bw = maxW * 0.85
        T.DrawSegBar(L.cx - bw / 2, y + 4, bw, 5, transitFrac, T.Colors.amber)
        y = y + 14
    end
    if barsRow ~= nil then
        -- the chip's mode-bar lexicon, echoed where the name is (block 05)
        local n = math.min(#barsRow, 3)
        local gapB = math.Round(2 * L.scale)
        local strip = maxW * 0.5
        local bw = math.floor((strip - gapB * (n - 1)) / n)
        local x = L.cx - strip / 2
        for i = 1, n do
            local col = T.Colors[barsRow[i]] or T.Colors.textDim
            surface.SetDrawColor(col)
            surface.DrawRect(x, y + 4, bw, math.max(2, math.Round(3 * L.scale)))
            x = x + bw + gapB
        end
        y = y + 10
    end
    if hint ~= nil then
        draw.SimpleText(T.FitText(hint, "CargoSmall", maxW), "CargoSmall",
            L.cx, L.cy + r - 26 * L.scale, T.Colors.textDim,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- white-on-transparent PNG tinted straight from the theme (DGL4 re-tints for
-- free); no icon mounted -> initial letter, title 20/700 (block 02). Both
-- anatomies draw it, at their own size and place.
local function DrawLightGlyph(chip, x, y, size, col)
    if chip.icon ~= nil then
        surface.SetDrawColor(col)
        surface.SetMaterial(chip.icon)
        surface.DrawTexturedRect(x, y, size, size)
    else
        draw.SimpleText(string.upper((chip.label or "?"):sub(1, 1)), "CargoTitle",
            x + size / 2, y + size / 2, col,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- One light chip (#46 — mock block 02, §0.ter c/d). Three independent,
-- never-overlapping channels: STATE is the fill (accentDim on / cell off),
-- TRANSIT is the only user of amber (border + dimmed pulsing icon + 4px
-- progress track that exists only while the transit does), HOVER raises
-- fill and border one step and never touches the state color. At the foot
-- only what is HAPPENING is drawn: a horizontal line down there always
-- means something active.
--
-- #48 adds the WIDE anatomy (150×56, mock block 06): same three channels,
-- same foot, plus the name and the mode as TEXT. The three channels are
-- untouched on purpose — the wide cell is more ROOM, not a new language.
local function DrawLightChip(L, c, chip, hovered, flash)
    local s = LightState(chip)
    local sc = L.scale
    local transit = istable(s.transit)
    local frac = transit and TransitFrac(s) or nil
    -- the cell knows its own anatomy, so the top/bottom degradation needs no
    -- flag down here: GroupCellSize already handed us a square one and this
    -- is simply false
    local wide = c.w > c.h

    local fill, border
    if transit then
        fill = hovered and T.Colors.cellHover or T.Colors.cell
        border = T.Colors.amber -- hover never wins over the amber border
    elseif s.on == true then
        fill = hovered and T.Colors.accent or T.Colors.accentDim
        border = hovered and T.Colors.borderHi or T.Colors.accent
    else
        fill = hovered and T.Colors.cellHover or T.Colors.cell
        border = hovered and T.Colors.borderHi or T.Colors.border
    end
    surface.SetDrawColor(fill)
    surface.DrawRect(c.x, c.y, c.w, c.h)
    surface.SetDrawColor(border)
    surface.DrawOutlinedRect(c.x, c.y, c.w, c.h, 1)

    local pad = math.Round(8 * sc)
    local iconCol
    if transit then
        local a = 140 + 40 * math.sin(CurTime() * 5) -- ~55%, pulsing
        iconCol = Color(T.Colors.amber.r, T.Colors.amber.g, T.Colors.amber.b, a)
    else
        iconCol = s.on == true and T.Colors.text or T.Colors.textDim
    end

    if wide then
        -- Mock block 06: the icon moves to a 48-px left gutter and the room
        -- that frees carries the two lines the square cell has no space for
        -- — the whole point of the variant is that the mode READS WITHOUT
        -- HOVERING. Inside the gutter the icon keeps the square chip's own
        -- padding rule, so this introduces no third icon size.
        local box = math.Round(48 * sc) - pad * 2
        DrawLightGlyph(chip, c.x + math.Round(4 * sc) + pad,
            c.y + (c.h - box) / 2, box, iconCol)

        local tx = c.x + math.Round(56 * sc)
        local tw = c.w - math.Round(56 * sc) - math.Round(6 * sc)
        -- both lines ride 2 px up when the transit track takes the foot
        local lift = transit and math.Round(2 * sc) or 0
        -- name: lit or transiting reads full, off reads dim (mock cells 1-4)
        draw.SimpleText(T.FitText(chip.label or "?", "CargoText", tw), "CargoText",
            tx, c.y + math.Round(17 * sc) - lift,
            (s.on == true or transit) and T.Colors.text or T.Colors.textDim,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        -- and the SAME secondary line the hub paints on hover, one rule
        local secTxt, secCol = LightSecondary(s)
        draw.SimpleText(T.FitText(secTxt, "CargoSmall", tw), "CargoSmall",
            tx, c.y + math.Round(35 * sc) - lift, secCol,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    else
        DrawLightGlyph(chip, c.x + pad, c.y + pad, c.w - pad * 2, iconCol)
    end

    -- #51: OVERRIDDEN by something else right now — the same 45° hatch the
    -- locked quick chips use, in `border` and NOT in red (author's call: red
    -- reads as an error and this is not one; the player already knows that
    -- hatch means "not available right now"). Goes OVER the fill and icon and
    -- UNDER the foot bars, and is scissor-clipped because HUDPaint has no
    -- panel clipping — CRG-28, paid for by these very stripes bleeding out of
    -- a quickslot. Works in both anatomies: it follows c.w/c.h.
    if isstring(s.blocked) then
        surface.SetDrawColor(T.Colors.border)
        render.SetScissorRect(c.x, c.y, c.x + c.w, c.y + c.h, true)
        local step = math.max(6, math.Round(10 * sc))
        for off = -c.h, c.w, step do
            surface.DrawLine(c.x + off, c.y + c.h, c.x + off + c.h, c.y)
        end
        render.SetScissorRect(0, 0, 0, 0, false)
    end

    -- foot: transit track (only while transiting, BOTH anatomies) + mode
    -- bars (only active emitters — one 3px bar each, mock lexicon geometry
    -- 46/22/14 @1080).
    --
    -- The wide cell draws NO bars in the mock: the mode name replaces them
    -- and says strictly more than the colors encode. The one case the mock
    -- never drew is a device that exposes emitters as DATA but declares no
    -- PrintName for its mode (ARC9 allows it — see HasEmitterData/ModeNameOf
    -- in client/corpus_cargo_lights.lua). There the name is not there to
    -- replace anything, and dropping the bars would hide those emitters
    -- EVERYWHERE, because the hub omits them for that same reason (§17.5).
    -- So the wide cell keeps the bars exactly when there is no mode name to
    -- show. Declared decision of #48, not a silent extension of the mock.
    local showBars = istable(s.emitters) and #s.emitters > 0
        and (not wide or not isstring(s.mode))
    local barH = math.max(1, math.Round(3 * sc))
    local footY = c.y + c.h - math.Round(4 * sc) - barH
    if transit then
        local tbH = math.max(2, math.Round(4 * sc))
        local tbX = c.x + math.Round(2 * sc)
        local tbW = c.w - math.Round(4 * sc)
        local tbY = c.y + c.h - math.Round(2 * sc) - tbH
        surface.SetDrawColor(T.Colors.barBack)
        surface.DrawRect(tbX, tbY, tbW, tbH)
        surface.SetDrawColor(T.Colors.amber)
        surface.DrawRect(tbX, tbY, math.Round(tbW * frac), tbH)
        footY = tbY - math.Round(1 * sc) - barH -- bars step up (block 08 note)
    end
    if showBars then
        local n = math.min(#s.emitters, 3) -- the mock designed up to three
        local gapB = math.Round(2 * sc)
        local strip = c.w - math.Round(10 * sc) -- 46 @1080: 56 - 2 border - 8 margin
        local bw = math.floor((strip - gapB * (n - 1)) / n)
        local x = c.x + math.Round(5 * sc)
        for i = 1, n do
            local col = T.Colors[s.emitters[i]] or T.Colors.textDim
            surface.SetDrawColor(col)
            surface.DrawRect(x, footY, bw, barH)
            x = x + bw + gapB
        end
    end

    -- #52: the refusal flash, and it goes LAST on purpose — over the hatch and
    -- over the bars. ONE red pulse fading out over the whole cell, not the
    -- two-blink + menu fade of mock block 07, which stays deferred because it
    -- drags the root drawer in. The two channels say different things and
    -- read together: the hatch is "this is not available", the flash is "and
    -- I just refused what you pressed".
    if flash ~= nil then
        local r = T.Colors.red
        surface.SetDrawColor(r.r, r.g, r.b, math.floor(170 * flash))
        surface.DrawRect(c.x, c.y, c.w, c.h)
        surface.SetDrawColor(r.r, r.g, r.b, math.floor(255 * flash))
        surface.DrawOutlinedRect(c.x, c.y, c.w, c.h, 1)
    end
end

local function DrawWheel(st)
    local L, hover = st.L, st.hover
    local snap = S()
    local activeClass = ActiveClass()

    -- light scrim: the world stays readable behind the wheel (theme rgb,
    -- lighter alpha than the inventory's — this one shows during combat)
    local sc = T.Colors.scrim
    surface.SetDrawColor(sc.r, sc.g, sc.b, 140)
    surface.DrawRect(0, 0, ScrW(), ScrH())

    for _, s in ipairs(st.sectors) do
        local sec = s.sec
        local entry = SlotData(sec)
        local hovered = hover.kind == "sector" and hover.sector == sec
        local col = hovered and T.Colors.cellHover or T.Colors.cell

        draw.NoTexture()
        surface.SetDrawColor(col.r, col.g, col.b, 235)
        for _, q in ipairs(s.quads) do
            surface.DrawPoly(q)
        end

        -- Sector content per the frozen mock (2nd-pass report 2026-07-13:
        -- the rim labels read scattered — the mock never had them). ALL of
        -- it groups at the mid radius: an info line ABOVE the icon (×N for
        -- the stack, mag/reserve for a weapon, the slot label when neither
        -- applies — mock rows 359-372), and the label alone only on EMPTY
        -- sectors. The name still lives in the hub on hover.
        local mid = math.rad(sec.angle)
        local rMid = (L.rIn + L.rOut) / 2 + 8 * L.scale
        local cx = L.cx + math.cos(mid) * rMid
        local cy = L.cy + math.sin(mid) * rMid

        if sec.slot == "hands" then
            draw.SimpleText("HANDS", "CargoHeading", cx, cy,
                hovered and T.Colors.text or T.Colors.textDim,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        elseif entry ~= nil then
            local isz = math.Round(78 * L.scale)
            local iconY = cy - isz / 2 + 8 * L.scale

            local def = CARGO.Items.Get(entry.id)
            local info, infoFont, infoCol = nil, "CargoHeading", T.Colors.text
            if entry.count ~= nil then
                info = "×" .. entry.count
            elseif def ~= nil then
                local clip, reserve = AmmoInfo(def)
                if clip ~= nil or reserve ~= nil then
                    info = (clip ~= nil and tostring(clip) or "—") .. " / "
                        .. (reserve ~= nil and tostring(reserve) or "—")
                end
            end
            if info == nil then -- melee & friends: the label takes the row
                info, infoFont = string.upper(sec.label), "CargoSmall"
                infoCol = hovered and T.Colors.text or T.Colors.textDim
            end
            draw.SimpleText(info, infoFont, cx, iconY - 4 * L.scale, infoCol,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            DrawEntryIcon(entry, cx - isz / 2, iconY, isz)

            -- accent marker on the weapon currently in hand (spec 4.4) —
            -- OUTSIDE the ring, like the mock's equipped-dot (R_OUT + 12)
            if def and isstring(def.weapon_class) and def.weapon_class == activeClass then
                local rDot = L.rOut + 12 * L.scale
                T.DrawCircle(L.cx + math.cos(mid) * rDot,
                    L.cy + math.sin(mid) * rDot, 4 * L.scale, T.Colors.accent, 16)
            end
        else
            draw.SimpleText(string.upper(sec.label), "CargoSmall",
                cx, cy - 9 * L.scale,
                hovered and T.Colors.text or T.Colors.textDim,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("— empty —", "CargoTiny", cx, cy + 10 * L.scale,
                T.Colors.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    DrawHub(L, hover, st.lights)

    -- quick chips F1-F4 (spec 4.6): rectangular — a different verb (USE,
    -- not equip) gets a different shape, and they never join the angular pick
    for n, c in ipairs(L.quickCells) do
        local hovered = hover.kind == "quick" and hover.n == n
        DrawChipBox(c, hovered)

        local unlocked = snap and n <= (snap.quickUnlocked or 0)
        local itemId = snap and snap.quick and snap.quick[n] or nil
        if not unlocked then
            -- same hatch the fullscreen UI uses — but HUDPaint has no panel
            -- clipping, so scissor or the stripes bleed past the chip box
            -- (in-game report 2026-07-13)
            surface.SetDrawColor(T.Colors.border)
            render.SetScissorRect(c.x, c.y, c.x + c.w, c.y + c.h, true)
            for off = -c.h, c.w, 10 do
                surface.DrawLine(c.x + off, c.y + c.h, c.x + off + c.h, c.y)
            end
            render.SetScissorRect(0, 0, 0, 0, false)
        elseif itemId ~= nil then
            local def = CARGO.Items.Get(itemId)
            if def then
                DrawEntryIcon({ id = itemId }, c.x + 4, c.y + 4, c.w - 8)
                local count = CARGO.UI.QuickCount(itemId)
                draw.SimpleText("x" .. count, "CargoTiny", c.x + c.w - 4, c.y + 2,
                    count > 0 and T.Colors.text or T.Colors.red, TEXT_ALIGN_RIGHT)
            end
        end
        draw.SimpleText("F" .. n, "CargoTiny", c.x + c.w - 4, c.y + c.h - 14,
            T.Colors.textDim, TEXT_ALIGN_RIGHT)
    end

    -- sandbox tool chips (spec 4.7): same show/hide gate as the column
    if ToolsShown() then
        for i, c in ipairs(L.toolCells) do
            local tool = CARGO.Slots.Tools[i]
            local hovered = hover.kind == "tool" and hover.i == i
            DrawChipBox(c, hovered)

            local entry = snap and snap.equip and snap.equip[tool.slotId]
                or CARGO.UI.FindToolItem(tool.class)
            if entry ~= nil then
                DrawEntryIcon(entry, c.x + 4, c.y + 4, c.w - 8,
                    snap and snap.equip and snap.equip[tool.slotId] == nil)
            else
                local slot = CARGO.Slots.ById[tool.slotId]
                draw.SimpleText(slot and slot.label:sub(1, 1) or "?", "CargoHeading",
                    c.x + c.w / 2, c.y + c.h / 2, T.Colors.textDim,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end

    -- light chips (#46, third group — TOGGLE, a third verb with the same
    -- rectangular shape; mock blocks 01-03). The list was built at open;
    -- a source that stopped being available mid-hold still paints (and its
    -- toggle stays valid), the NEXT open shrinks the column (CRG-32)
    if st.lights ~= nil and L.lightCells ~= nil then
        for i, c in ipairs(L.lightCells) do
            -- #52: the refusal flash, resolved HERE and not stored per chip:
            -- the chip list is rebuilt on a weapon swap, so anything kept on
            -- a chip table would evaporate mid-window (the same reason the
            -- NVG transit lives in an upvalue of the lights file, §17.8)
            local flash
            if st.flash ~= nil and st.flash.i == i then
                local dt = CurTime() - st.flash.at
                if dt < FLASH_TIME then
                    flash = 1 - dt / FLASH_TIME
                else
                    st.flash = nil
                end
            end
            DrawLightChip(L, c, st.lights[i],
                hover.kind == "light" and hover.i == i, flash)
        end
    end
end

-- Protected paint (post-1st-pass hardening, 2026-07-13): GMod UNHOOKS a
-- HUDPaint hook that errors — one bad hover state and the wheel dies
-- silently for the whole session, which is exactly the failure shape the
-- author reported (open/equip worked, then hub/chips went dead). The pcall
-- keeps the wheel alive and logs the actual error ONCE, loudly, so the next
-- pass reports the offending line instead of a mystery.
local lastPaintErr

hook.Add("HUDPaint", "corpus_cargo_wheel", function()
    if state == nil then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or gui.IsGameUIVisible() then
        CARGO.Wheel.Close(false) -- death / ESC: cancel, never commit
        return
    end
    local ok, err = pcall(function()
        -- The screen clicker is GLOBAL state and we are not its only consumer:
        -- ARC9's Deploy calls gui.EnableScreenClicker(FALSE) unconditionally
        -- (sh_deploy.lua:125), so switching to an ARC9 weapon with 1-7 while
        -- the wheel is held killed our cursor mid-hold — measured in game
        -- (planilla V, ronda 3, V8; an HL2 weapon does NOT do it, which is
        -- exactly what pointed at the deploy path).
        --
        -- RE-ASSERTED ONLY WHEN IT IS ACTUALLY OFF, and that guard is the whole
        -- fix. The first attempt called EnableScreenClicker(true) every painted
        -- frame "because the call is idempotent" — an ASSUMPTION about an
        -- engine API, never verified, and false: measured in game (planilla V,
        -- ronda 4, V10) the cursor came back but FLICKERED every frame and
        -- could not click anything. Calling it per frame re-initialises the
        -- clicker instead of leaving it alone. Same mistake this very batch
        -- documents twice over (CRG-24 applies to the engine too) — so the
        -- state is read before it is written. vgui.CursorVisible is the same
        -- probe Open() already trusts, a few lines below.
        if isfunction(vgui.CursorVisible) and not vgui.CursorVisible() then
            gui.EnableScreenClicker(true)
        end
        -- before the pick, so the cursor is tested against the layout that is
        -- about to be painted (a rebuild can change the cell count)
        RefreshLightsIfWeaponChanged()
        local mx, my = gui.MousePos()
        state.hover = CARGO.Wheel.PickAt(state.L, mx, my, ToolsShown())
        DrawWheel(state)
    end)
    if not ok and lastPaintErr ~= tostring(err) then
        lastPaintErr = tostring(err)
        Corpus.Log("cargo", "wheel: error de pintado (reportar tal cual): "
            .. lastPaintErr)
    end
end)

-- ------------------------------------------------------------------
-- Input: hold to show, release to commit. Key convar + edge detection in
-- Think (the project's bind pattern) plus +/- concommands for engine binds.
-- Default key G is only ever OUR poll — the engine binds are never written.
-- If the key already has an engine bind both will fire, so warn once
-- (author rule: never stomp a player's bind silently).
--
-- #48 STEP 2 — THE CLICK IS A SECOND WAY TO COMMIT, NEVER A REPLACEMENT.
-- CRG-31 stands untouched: releasing the key commits exactly as it always
-- has, and that is the gesture already in the muscle. The click is added on
-- top for the paused one (author's call, 2026-07-29).
--
-- It is polled HERE, with edge detection, in the same Think as the key —
-- which means it introduces NO new engine API at all: `input.IsButtonDown`
-- is the function this hook already calls every frame, just asked about
-- MOUSE_LEFT instead of a KEY_ enum. That was the whole point of choosing
-- polling over a mouse hook we would be trying for the first time from
-- memory, which is what #46 paid for three times over.
--
-- The one thing that WAS an assumption got measured before a line of this
-- was written (planilla W, W1): the screen clicker swallows the click as a
-- game input, but it does NOT stop the button state from being readable
-- underneath — the same machinery GMod's own context menu uses. Had it come
-- back negative, this would not exist.
-- ------------------------------------------------------------------

local keyWasDown = false
local clickWasDown = false
local backWasDown = false
local warnedBind = false

-- The click, both buttons, one rule. The pick is re-run HERE for the same
-- reason Close does it — the cursor may have moved since the last painted
-- frame — so every gesture honours where the cursor actually is.
local function ClickCommit(back)
    local mx, my = gui.MousePos()
    local hover = CARGO.Wheel.PickAt(state.L, mx, my, ToolsShown())

    -- #52: a refusal does NOT close the menu, in either mode. Closing is how
    -- the wheel acknowledges a commit, and there was none — closing on a
    -- refusal would be a second lie on top of the one this whole block exists
    -- to remove. It also keeps the flash on screen, which is the point.
    if BlockedChip(hover, state.lights) ~= nil then
        state.flash = { i = hover.i, at = CurTime() }
        return
    end

    if back then
        -- The right button exists ONLY over a chip that declares it can go
        -- backwards. Anywhere else it does NOTHING — not "the same as left",
        -- not a cancel: the wheel has no reverse for equipping or using, and
        -- inventing one would be exactly what CRG-32 forbids. Checked BEFORE
        -- the sticky branch so that a right click on a sector cannot close
        -- the menu as a side effect.
        local chip = hover.kind == "light" and state.lights ~= nil
            and state.lights[hover.i] or nil
        if chip == nil or not isfunction(chip.toggleBack) then return end
    end

    if cvSticky:GetBool() and hover.kind == "light" then
        -- #49: act in place and leave the wheel open, so N clicks cycle N
        -- times. Same Commit, same pcall discipline as CRG-25 asks; a light
        -- that refuses (a transit in flight) simply does nothing and the menu
        -- stays up — mute rejection, unchanged.
        local ok, err = pcall(Commit, hover, state.lights, back)
        if not ok then
            Corpus.Log("cargo", "wheel: error en el commit del click sostenido (reportar tal cual): "
                .. tostring(err))
        end
        state.clicked = true -- remembered for the release: see CloseOnRelease
        return
    end

    -- the SAME route releasing the key takes: Close re-runs the pick at this
    -- instant, Commit resolves it, and the whole thing is already wrapped in
    -- the pcall of CRG-25. Zero new commit logic.
    --
    -- Nothing guards against a second commit because nothing has to: Close()
    -- returns early on a nil state, so releasing the key after a click closed
    -- the wheel does nothing. One open, one commit, by construction — the trap
    -- is real and the existing guard already covered it (verified, not
    -- assumed: the harness proves it in the negative).
    CARGO.Wheel.Close(true, back)
end

-- Releasing the key commits — CRG-31, and it stays literally true here. The
-- ONE exception is #49 and it only exists after a gesture you asked for: if a
-- sticky click already acted in THIS opening, releasing just closes, because
-- otherwise finishing a cycle of three clicks would fire a fourth toggle
-- nobody asked for. Never clicked in this opening -> `clicked` is false ->
-- this is exactly the Close(true) of always. The policy lives HERE, where the
-- gesture is decided, and not inside Close, which stays a dumb "commit or
-- not, you tell me" (the click path above needs the other answer).
local function CloseOnRelease()
    CARGO.Wheel.Close(not (state ~= nil and state.clicked == true))
end

hook.Add("Think", "corpus_cargo_wheel_key", function()
    -- Tracked EVERY frame, open or closed, and that is deliberate: if the
    -- state only updated while the wheel was open, opening it with the fire
    -- button already held would read as a fresh press and commit instantly.
    -- Acting is gated below; observing never is.
    -- ONE path for both buttons (#50): the right one is the left one's mirror,
    -- a step backwards. Everything else about the gesture is identical, so it
    -- is the same code and not a second copy that can drift.
    local clickDown = input.IsButtonDown(MOUSE_LEFT)
    local backDown = input.IsButtonDown(MOUSE_RIGHT)
    if state ~= nil and cvClick:GetBool() then
        if clickDown and not clickWasDown then ClickCommit(false)
        elseif backDown and not backWasDown then ClickCommit(true) end
    end
    clickWasDown = clickDown
    backWasDown = backDown

    local key = cvKey:GetInt()
    if key <= 0 then keyWasDown = false return end

    if not warnedBind then
        warnedBind = true
        local bound = input.LookupKeyBinding(key)
        if isstring(bound) and bound ~= "" and bound ~= "+cargo_wheel" then
            Corpus.Log("cargo", "wheel: la tecla asignada ya tiene un bind del engine ('"
                .. bound .. "') — los dos van a disparar. Cambiala en el tab de Cargo (menú Q)")
        end
    end

    local down = input.IsButtonDown(key)
    if down and not keyWasDown then
        if not gui.IsGameUIVisible() and vgui.GetKeyboardFocus() == nil then
            CARGO.Wheel.Open()
        end
    elseif keyWasDown and not down then
        CloseOnRelease()
    end
    keyWasDown = down
end)

concommand.Add("+cargo_wheel", function()
    CARGO.Wheel.Open()
end, nil, "Shows the weapon wheel while held")

concommand.Add("-cargo_wheel", function()
    CloseOnRelease() -- the console bind gets the same rule as the poll (#49)
end, nil, "Releases the weapon wheel, committing the hovered action")
