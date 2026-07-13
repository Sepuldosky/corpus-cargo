-- corpus_cargo_wheel.lua — radial weapon menu (CLIENT)
-- Roadmap #31; design closed in Claude Desktop 2026-07-13 and frozen in
-- docs/mockups/cargo_wheel_menu_mock_v2_1.html (geometry, sector map, hub,
-- chips, hover states — the mock rules until VGUI exists; on divergence the
-- code rules).
--
-- GOVERNING RULE — zero new server logic. The wheel is an alternative
-- front-end for the 1-7 slot keys: committing a sector sends the SAME
-- slotkey intent corpus_cargo_hotkeys.lua sends and the server resolves it
-- in corpus_cargo_holster.lua exactly as today (intent 8 = throwable,
-- wheel-only, CARGO.Slots.WheelSlots). The quick chips call the EXISTING
-- quick-use route (CARGO.UI.QuickUse) and the tool chips the EXISTING
-- selection function (CARGO.UI.SelectTool). No new net messages.
--
-- Drawn on HUDPaint, no VGUI: the cursor roams free (gui.EnableScreenClicker
-- swallows mouse clicks, so nothing fires while aiming the wheel), keyboard
-- and movement stay with the game. Every color reads the theme — no baked
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

local warnedAnchors

function CARGO.Wheel.BuildLayout()
    local sw, sh = ScrW(), ScrH()
    local sc = sh / 1080
    local L = {
        cx = sw / 2, cy = sh / 2, scale = sc,
        rIn = 120 * sc,  -- hub radius = the deadzone
        rOut = 305 * sc, -- outer ring edge; beyond it = cancel
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
    -- the sides. One resolver serves both groups (spec 4.8).
    local chip = math.Round(56 * sc)
    local gap = math.Round(8 * sc)
    local margin = math.Round(46 * sc)
    local function GroupCells(anchor, count)
        local horizontal = anchor == "bottom" or anchor == "top"
        local gw = horizontal and (count * chip + (count - 1) * gap) or chip
        local gh = horizontal and chip or (count * chip + (count - 1) * gap)
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
                x = horizontal and (x + (i - 1) * (chip + gap)) or x,
                y = horizontal and y or (y + (i - 1) * (chip + gap)),
                w = chip, h = chip,
            }
        end
        return cells
    end
    L.quickCells = GroupCells(quick, CARGO.Slots.QUICK_COUNT)
    L.toolCells = GroupCells(tools, #CARGO.Slots.Tools)
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

local function Commit(hover)
    if hover == nil then return end
    if hover.kind == "quick" then
        -- the server re-checks suit lock / empties; this is only the trigger
        CARGO.UI.QuickUse(hover.n)
    elseif hover.kind == "tool" then
        CARGO.UI.SelectTool(CARGO.Slots.Tools[hover.i])
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

    local L = CARGO.Wheel.BuildLayout()
    local sectors = {}
    for i, sec in ipairs(SECTORS) do
        sectors[i] = { sec = sec, quads = SectorQuads(L, sec.angle) }
    end
    state = { L = L, sectors = sectors, hover = { kind = "deadzone" } }
    gui.EnableScreenClicker(true)
    gui.SetMousePos(L.cx, L.cy) -- start in the deadzone, like the mock
end

-- the pick re-runs at release time: the cursor may have moved since the
-- last painted frame, and the commit must honor where it actually let go
function CARGO.Wheel.Close(commit)
    if state == nil then return end
    local L = state.L
    -- read the cursor BEFORE releasing the screen clicker: once it is off,
    -- gui.MousePos is not guaranteed to keep reporting the free-cursor
    -- position (post-1st-pass hardening, 2026-07-13)
    local mx, my = gui.MousePos()
    state = nil
    gui.EnableScreenClicker(false)
    if commit then
        -- protected: a commit error must never strand the wheel half-closed
        local ok, err = pcall(function()
            Commit(CARGO.Wheel.PickAt(L, mx, my, ToolsShown()))
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
local function DrawHub(L, hover)
    local r = L.rIn - 6 * L.scale
    T.DrawCircleOutlined(L.cx, L.cy, r, T.Colors.panel, T.Colors.borderHi, 2)

    local maxW = r * 1.6
    local lines = {} -- { text, font, color }
    local cond, hint

    if hover.kind == "sector" and hover.sector.slot == "hands" then
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

    local y = L.cy - (#lines * 22 + (cond ~= nil and 14 or 0)) / 2
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
    if hint ~= nil then
        draw.SimpleText(T.FitText(hint, "CargoSmall", maxW), "CargoSmall",
            L.cx, L.cy + r - 26 * L.scale, T.Colors.textDim,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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

        local mid = math.rad(sec.angle)
        local rMid = (L.rIn + L.rOut) / 2 + 6 * L.scale
        local cx = L.cx + math.cos(mid) * rMid
        local cy = L.cy + math.sin(mid) * rMid

        -- slot label toward the outer edge
        local rLab = L.rOut - 16 * L.scale
        draw.SimpleText(sec.label, "CargoTiny",
            L.cx + math.cos(mid) * rLab, L.cy + math.sin(mid) * rLab,
            hovered and T.Colors.text or T.Colors.textDim,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if sec.slot == "hands" then
            draw.SimpleText("HANDS", "CargoHeading", cx, cy,
                hovered and T.Colors.text or T.Colors.textDim,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        elseif entry ~= nil then
            local isz = math.Round(78 * L.scale)
            DrawEntryIcon(entry, cx - isz / 2, cy - isz / 2, isz)
            if entry.count ~= nil then
                draw.SimpleText("×" .. entry.count, "CargoSmall",
                    cx + isz / 2, cy - isz / 2, T.Colors.text)
            end

            -- accent marker on the weapon currently in hand (spec 4.4)
            local def = CARGO.Items.Get(entry.id)
            if def and isstring(def.weapon_class) and def.weapon_class == activeClass then
                local rDot = L.rOut - 7 * L.scale
                T.DrawCircle(L.cx + math.cos(mid) * rDot,
                    L.cy + math.sin(mid) * rDot, 4 * L.scale, T.Colors.accent, 16)
            end
        else
            draw.SimpleText("—", "CargoHeading", cx, cy, T.Colors.textDim,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    DrawHub(L, hover)

    -- quick chips F1-F4 (spec 4.6): rectangular — a different verb (USE,
    -- not equip) gets a different shape, and they never join the angular pick
    for n, c in ipairs(L.quickCells) do
        local hovered = hover.kind == "quick" and hover.n == n
        DrawChipBox(c, hovered)

        local unlocked = snap and n <= (snap.quickUnlocked or 0)
        local itemId = snap and snap.quick and snap.quick[n] or nil
        if not unlocked then
            surface.SetDrawColor(T.Colors.border)
            for off = -c.h, c.w, 10 do
                surface.DrawLine(c.x + off, c.y + c.h, c.x + off + c.h, c.y)
            end
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
-- ------------------------------------------------------------------

local keyWasDown = false
local warnedBind = false

hook.Add("Think", "corpus_cargo_wheel_key", function()
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
        CARGO.Wheel.Close(true)
    end
    keyWasDown = down
end)

concommand.Add("+cargo_wheel", function()
    CARGO.Wheel.Open()
end, nil, "Shows the weapon wheel while held")

concommand.Add("-cargo_wheel", function()
    CARGO.Wheel.Close(true)
end, nil, "Releases the weapon wheel, committing the hovered action")
