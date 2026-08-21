-- corpus_cargo_theme.lua — palette, fonts and paint helpers (CLIENT)
-- Single place the whole Cargo UI reads its look from. The mocks are CSS;
-- VGUI has no flexbox/grid — everything here is manual painting on purpose.
--
-- RUNTIME PALETTES (roadmap #29, mock docs/mockups/cargo_theme_dynamic_mock_v1_1.html):
-- the palette is swappable at runtime. T.Colors keys keep their names AND
-- their table identity — ApplyPalette mutates every Color IN PLACE, so all
-- the Paint closures (and file-scope tables) that captured a T.Colors.*
-- reference re-skin on the next frame with zero consumer changes.
--   · base "spawnmenu" (DEFAULT, author call): neutral grays in the key of
--     GMod's own spawnmenu/browser — benign, ready to integrate over it.
--   · base "olive": the original GAMMA palette from the fullscreen mock.
--   · DGL4 mounted + cargo_theme_dgl4: the whole palette derives from the
--     ACTIVE HoloHUD2 preset color (COMPAT-RUNTIME — read via its API,
--     never assumed; without the mod the base palette stands, no crash).

local CARGO = Corpus.GetModule("cargo")

CARGO.Theme = CARGO.Theme or {}
local T = CARGO.Theme

-- Color objects are created ONCE; palettes below only mutate their rgba.
-- Starts on the neutral base; RefreshTheme() at the bottom settles it.
T.Colors = {
    bg        = Color(8, 10, 12, 245),
    scrim     = Color(8, 10, 12, 205),   -- fullscreen backdrop (frame + wheel)
    panel     = Color(38, 42, 48),
    panelAlt  = Color(46, 51, 58),
    cell      = Color(24, 27, 31),
    cellHover = Color(52, 58, 66),
    border    = Color(74, 80, 88),
    borderHi  = Color(104, 112, 122),
    text      = Color(223, 226, 229),
    textDim   = Color(139, 146, 153),
    accent    = Color(79, 155, 214),     -- selection/highlight identity color
    accentDim = Color(46, 90, 124),
    green     = Color(108, 191, 90),     -- "good" (condition, weight)
    greenDim  = Color(63, 111, 52),
    amber     = Color(214, 165, 79),
    orange    = Color(214, 130, 60),
    red       = Color(207, 80, 64),
    blue      = Color(79, 155, 214),
    blueDark  = Color(20, 32, 42),
    money     = Color(225, 225, 218),
    barBack   = Color(10, 11, 13),
}

-- plain rgba tables (NOT Color objects: palettes are data, T.Colors is the
-- live surface)
local function C(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end

T.PALETTES = {
    -- neutral spawnmenu-family grays (#29a). Values from the author's
    -- dynamic-palette mock ("spawnmenu (derma)" theme) — tuned against the
    -- real Derma Default skin family rather than invented olive-adjacent grays.
    spawnmenu = {
        bg = C(8, 10, 12, 245),   scrim = C(8, 10, 12, 205),
        panel = C(38, 42, 48),    panelAlt = C(46, 51, 58),
        cell = C(24, 27, 31),     cellHover = C(52, 58, 66),
        border = C(74, 80, 88),   borderHi = C(104, 112, 122),
        text = C(223, 226, 229),  textDim = C(139, 146, 153),
        accent = C(79, 155, 214), accentDim = C(46, 90, 124),
        green = C(108, 191, 90),  greenDim = C(63, 111, 52),
        amber = C(214, 165, 79),  orange = C(214, 130, 60),
        red = C(207, 80, 64),     blue = C(79, 155, 214),
        blueDark = C(20, 32, 42), money = C(225, 225, 218),
        barBack = C(10, 11, 13),
    },
    -- the original olive/military palette (cargo_fullscreen_ui_mock_v1.html),
    -- kept as an option: cargo_theme olive
    olive = {
        bg = C(11, 12, 10, 245),  scrim = C(4, 5, 3, 205),
        panel = C(20, 21, 15),    panelAlt = C(25, 26, 19),
        cell = C(15, 16, 11),     cellHover = C(34, 37, 26),
        border = C(43, 45, 34),   borderHi = C(58, 61, 46),
        text = C(214, 217, 200),  textDim = C(110, 114, 99),
        accent = C(157, 192, 75), accentDim = C(92, 112, 48),
        green = C(157, 192, 75),  greenDim = C(92, 112, 48),
        amber = C(217, 161, 59),  orange = C(216, 122, 44),
        red = C(199, 80, 58),     blue = C(91, 143, 168),
        blueDark = C(24, 34, 40), money = C(222, 216, 194),
        barBack = C(10, 11, 7),
    },
}

surface.CreateFont("CargoTitle",   { font = "Roboto", size = 20, weight = 700 })
surface.CreateFont("CargoHeading", { font = "Roboto", size = 16, weight = 700 })
surface.CreateFont("CargoText",    { font = "Roboto", size = 14, weight = 500 })
surface.CreateFont("CargoSmall",   { font = "Roboto", size = 12, weight = 500 })
surface.CreateFont("CargoTiny",    { font = "Roboto", size = 11, weight = 700 })

-- layout scale: the fullscreen mock is authored at 1080p; hand-tuned pixel
-- dimensions multiply by this (fonts stay fixed — they read fine across the
-- supported range, and VGUI fonts cannot be resized per-frame anyway)
function T.UIScale()
    return math.max(ScrH() / 1080, 0.6)
end

-- condition %: green while healthy, amber worn, red near-broken
function T.ConditionColor(pct)
    if pct == nil then return T.Colors.textDim end
    if pct <= 0 then return T.Colors.red end
    if pct < 33 then return T.Colors.orange end
    if pct < 66 then return T.Colors.amber end
    return T.Colors.green
end

-- weight footer: colored by proximity to the limit (§7)
function T.WeightColor(frac)
    if frac > 1 then return T.Colors.red end
    if frac > 0.9 then return T.Colors.orange end
    if frac > 0.6 then return T.Colors.amber end
    return T.Colors.green
end

function T.DrawBar(x, y, w, h, frac, col)
    surface.SetDrawColor(T.Colors.barBack)
    surface.DrawRect(x, y, w, h)
    surface.SetDrawColor(col)
    surface.DrawRect(x, y, math.Clamp(frac, 0, 1) * w, h)
end

-- segmented bar (mock's .seg under equipment slots): 4 px ticks, 3 px gaps
function T.DrawSegBar(x, y, w, h, frac, col)
    surface.SetDrawColor(T.Colors.barBack)
    surface.DrawRect(x, y, w, h)
    local fill = math.Clamp(frac, 0, 1) * w
    surface.SetDrawColor(col)
    local cx = x
    while cx < x + fill do
        surface.DrawRect(cx, y, math.min(4, x + fill - cx), h)
        cx = cx + 7
    end
end

-- 45 degree hatching over the LEFT `frac` of its own rect, in PANEL space.
--
-- WHY IT TAKES THE PANEL. The diagonals run past the rect by construction —
-- that is what makes them read as a texture instead of as ticks — so they have
-- to be clipped or they bleed onto the row below. The engine's scissor works in
-- SCREEN space while `surface.DrawLine` inside a Paint works in PANEL space, so
-- the rect has to be converted, and the panel is the only thing that can do it.
-- This is CRG-28, and the clip is not belt-and-braces: the stripes of a
-- quickslot bleeding out of their cell are what paid for that norm.
-- (The prose says "the engine's scissor" and not the call by name on purpose:
-- the source gate counts the CALLS, and a name written in a comment would pad
-- the count with something that draws nothing.)
--
-- The module has two older copies of this pattern (the locked quick chip in
-- corpus_cargo_ui.lua and the overridden light chip in corpus_cargo_wheel.lua).
-- They are NOT migrated here on purpose: both live in HUDPaint, where the two
-- coordinate spaces already coincide, and a red from the wheel would read as a
-- red from the status panel in the pass that ships this.
function T.DrawHatch(panel, x, y, w, h, frac, col, step)
    frac = math.Clamp(frac or 1, 0, 1)
    if frac <= 0 or w <= 0 or h <= 0 then return end
    local fw = math.floor(w * frac + 0.5)
    if fw <= 0 then return end

    local sx, sy = panel:LocalToScreen(x, y)
    sx, sy = tonumber(sx) or 0, tonumber(sy) or 0

    surface.SetDrawColor(col)
    render.SetScissorRect(sx, sy, sx + fw, sy + h, true)
    step = math.max(4, step or 6)
    for off = -h, fw, step do
        surface.DrawLine(x + off, y + h, x + off + h, y)
    end
    render.SetScissorRect(0, 0, 0, 0, false)
end

-- Five-pointed star, filled, centered on cx/cy with outer radius r.
--
-- IT IS DRAWN AND NOT TYPED, and that is a MEASUREMENT and not a preference:
-- the module's font is Roboto (Roboto-Medium.ttf, read off disk in GMod's own
-- resource/fonts), and Roboto has NO glyph for U+2605 BLACK STAR, U+2606 WHITE
-- STAR or U+272F. A draw.SimpleText("*") would paint the missing-glyph box.
-- Drawing it also means the palette tints it like every other shape here —
-- same reason PaintMenuArrow does not use the stock Derma arrow texture.
--
-- THE FIRST VERTEX IS THE CENTER, and that is the whole trick: surface.DrawPoly
-- is a triangle FAN from vertex one, and a star is CONCAVE — fanning from a
-- point would put triangles outside the shape. Fanning from the center gives
-- ten triangles that are each entirely inside it. The contour runs clockwise
-- (increasing angle, screen Y down), the same winding T.DrawCircle above uses.
function T.DrawStar(cx, cy, r, col)
    local inner = r * 0.382 -- the regular 5-point ratio (1/phi^2)
    local pts = { { x = cx, y = cy } }
    for i = 0, 10 do -- 10 and not 9: the contour closes back on its first point
        local a = math.rad(-90 + (i % 10) * 36)
        local rad = (i % 2 == 0) and r or inner
        pts[#pts + 1] = { x = cx + math.cos(a) * rad, y = cy + math.sin(a) * rad }
    end
    draw.NoTexture()
    surface.SetDrawColor(col)
    surface.DrawPoly(pts)
end

-- standard panel look: flat box + hairline border
function T.PaintPanel(w, h, bgCol, borderCol)
    draw.RoundedBox(4, 0, 0, w, h, bgCol or T.Colors.panel)
    surface.SetDrawColor(borderCol or T.Colors.border)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

-- Skin a DScrollPanel's scrollbar to the palette (in-game report 2026-07-13:
-- the inventory scroll was still stock Derma). Buttons hidden, spawnmenu-flat
-- track + grip; colors are READ inside the Paint closures, so a palette swap
-- (#29 / DGL4 tint) re-skins live like everything else. Touches only the
-- VBar — the scroll's own Paint (the grid reticle, #24) stays whose it is.
function T.SkinScroll(scroll)
    if not IsValid(scroll) or not isfunction(scroll.GetVBar) then return end
    local bar = scroll:GetVBar()
    if not IsValid(bar) then return end
    bar:SetHideButtons(true)
    bar.Paint = function(_, w, h)
        surface.SetDrawColor(T.Colors.panelAlt)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(T.Colors.border)
        surface.DrawRect(0, 0, 1, h) -- hairline seam against the content
    end
    bar.btnGrip.Paint = function(self, w, h)
        local col = (self.Depressed or self:IsHovered())
            and T.Colors.borderHi or T.Colors.border
        draw.RoundedBox(2, 2, 0, w - 4, h, col)
    end
end

-- ------------------------------------------------------------------
-- THE context menu of the module (CRG-75, roadmap #74)
--
-- In-game report (2026-08-19): "tambien el menu contextual tiene color derma,
-- deberia tomar el color del hud de DGL4 que tiene cargo". It was the LAST
-- piece of UI in the module that did not read this file -- frame, cells,
-- wheel, tooltip and chips all derive from T.Colors, and a bare DermaMenu()
-- drew stock Derma gray on top of an interface that is not gray.
--
-- The DGL4 tint costs nothing here ON PURPOSE: T.Colors already derives the
-- whole palette from the mod's accent and mutates its Color objects IN PLACE
-- (CRG-29), so a menu that reads T.Colors takes the HUD color with no compat
-- line of its own, and re-skins live. Reading the mod a second time from here
-- would be a second house that desyncs in silence.
--
-- WHY IT WRAPS AddOption/AddSubMenu INSTEAD OF JUST PAINTING THE PANEL. This
-- is the trap of the front and it does NOT show on the first pass:
--   · a DMenuOption paints ITSELF (derma.SkinHook "MenuOption"), so a helper
--     that only sets menu.Paint leaves every row stock gray.
--   · DMenu:AddSubMenu builds its child with a BARE DermaMenu(true, self) --
--     READ in GMod's own vgui/dmenuoption.lua, not assumed -- which is a
--     SEPARATE menu this helper never saw. The four submenus of the item menu
--     would stay gray, and you only find out by opening one.
-- So the skin lands on the DESCENDANCY, not on the instance.
-- ------------------------------------------------------------------

-- the submenu marker: DMenuOption's own arrow is a stock Derma texture, which
-- on a dark panel is a dark smudge. Same DrawPoly primitive as every other
-- shape here -- no baked texture, so the palette tints it too.
local function PaintMenuArrow(w, h, col)
    local cx, cy = w * 0.5, h * 0.5
    local s = math.max(3, math.floor(math.min(w, h) * 0.3))
    draw.NoTexture()
    surface.SetDrawColor(col)
    surface.DrawPoly({
        { x = cx - s * 0.5, y = cy - s },
        { x = cx + s * 0.8, y = cy },
        { x = cx - s * 0.5, y = cy + s },
    })
end

-- Hover and enabled/disabled read the SAME two signals the stock skin reads
-- (panel.Hovered / panel.Highlight and IsEnabled), so a themed option cannot
-- disagree with an unthemed one about its own state.
local function SkinMenuOption(opt)
    if not IsValid(opt) then return opt end
    opt:SetFont("CargoText")

    opt.Paint = function(self, w, h)
        -- Unlike every other Paint in this file, this one cannot merely READ
        -- the palette: DLabel keeps the text color as a SNAPSHOT (UpdateFGColor
        -- copies the rgba into the engine), so it has to PUSH it. Pushing every
        -- frame is what keeps CRG-29 true here -- a live DGL4 re-tint reaches an
        -- open menu the same way it reaches the frame behind it.
        local enabled = self:IsEnabled()
        self:SetTextColor(enabled and T.Colors.text or T.Colors.textDim)
        if enabled and (self.Hovered or self.Highlight) then
            surface.SetDrawColor(T.Colors.cellHover)
            surface.DrawRect(0, 0, w, h)
        end
        -- false, like DMenuOption's own Paint: the engine still draws the label
        -- text. Returning true would paint a row with nothing written on it.
        return false
    end

    if IsValid(opt.SubMenuArrow) then
        opt.SubMenuArrow.Paint = function(_, w, h)
            PaintMenuArrow(w, h, T.Colors.textDim)
        end
    end
    return opt
end

local function SkinMenu(menu)
    if not IsValid(menu) then return menu end

    menu.Paint = function(_, w, h)
        T.PaintPanel(w, h, T.Colors.panel, T.Colors.border)
    end
    -- a DMenu IS a DScrollPanel (MaxHeight is 90% of the screen), so a long
    -- one grows the same stock scrollbar the inventory grew before #24
    T.SkinScroll(menu)

    local addOption, addSubMenu, addSpacer = menu.AddOption, menu.AddSubMenu, menu.AddSpacer

    menu.AddOption = function(self, text, fn)
        return SkinMenuOption(addOption(self, text, fn))
    end

    -- AddSubMenu returns (SubMenu, option). BOTH need it: the option carries
    -- the arrow, and the submenu is a whole new DMenu -- skinned RECURSIVELY so
    -- a submenu of a submenu cannot fall out of the norm either.
    menu.AddSubMenu = function(self, text, fn)
        local sub, opt = addSubMenu(self, text, fn)
        SkinMenuOption(opt)
        return SkinMenu(sub), opt
    end

    menu.AddSpacer = function(self)
        local pnl = addSpacer(self)
        if IsValid(pnl) then
            pnl.Paint = function(_, w, h)
                surface.SetDrawColor(T.Colors.border)
                surface.DrawRect(0, 0, w, h)
            end
        end
        return pnl
    end

    return menu
end

-- The ONE door: every context menu in the module opens through here (CRG-75).
-- A ninth menu written straight on DermaMenu() is a gray menu again, which is
-- exactly how this entry was born.
function T.Menu()
    return SkinMenu(DermaMenu())
end

-- ------------------------------------------------------------------
-- THE prompt of the module (CRG-75 too, roadmap #75)
--
-- Author, right after closing the #74 in game: "el unico cambio menor que
-- quiero es que el menu de 'how much' cuando mandas por amount o compras por
-- amount tambien tiene que tener el color del hud asi como el menu contextual".
-- It is the same norm and the same reason: the "amount..." box of the trade and
-- of the loot was the LAST stock Derma surface of the module, and it only
-- became visible once the menus stopped being gray.
--
-- IT WRAPS Derma_StringRequest INSTEAD OF RE-IMPLEMENTING IT. The engine
-- function owns the layout -- it sizes the window from the label, centers it,
-- wires Enter, and makes it modal -- and rewriting all of that to change six
-- colors would be a far bigger diff with a far worse failure mode. It returns
-- its Window (read in derma/derma_utils.lua), so the whole subtree is reachable
-- from right here.
--
-- Dispatch is by `panel.ClassName`, which vgui.Create stamps on every instance
-- (includes/extensions/client/panel/scriptedpanels.lua) -- and NOT by
-- `GetClassName()`, which returns the ENGINE class ("EditablePanel") and cannot
-- tell a DButton from a DLabel. Both were read on disk, not assumed.
-- ------------------------------------------------------------------

local function SkinPromptChild(pnl)
    local cls = pnl.ClassName

    if cls == "DLabel" then
        pnl:SetFont("CargoText")
        pnl:SetTextColor(T.Colors.text)

    elseif cls == "DTextEntry" then
        pnl:SetFont("CargoText")
        pnl:SetTextColor(T.Colors.text)
        pnl:SetCursorColor(T.Colors.text)
        pnl:SetHighlightColor(T.Colors.accentDim)
        pnl.Paint = function(self, w, h)
            T.PaintPanel(w, h, T.Colors.cell,
                self:HasFocus() and T.Colors.borderHi or T.Colors.border)
            -- ⚠ THE TEXT OF A DTextEntry IS NOT DRAWN BY THE ENGINE ON ITS OWN:
            -- the SKIN draws it (skins/default.lua PaintTextEntry calls this),
            -- so a Paint that replaces the skin and forgets this line leaves a
            -- box you can type into and never see. It is the one difference
            -- between this and every other Paint in this file.
            self:DrawTextEntryText(T.Colors.text, T.Colors.accentDim, T.Colors.text)
            return true
        end

    elseif cls == "DButton" then
        pnl:SetFont("CargoText")
        pnl:SetTextColor(T.Colors.text)
        pnl.Paint = function(self, w, h)
            local bg = T.Colors.cell
            if self:IsDown() then
                bg = T.Colors.accentDim
            elseif self.Hovered then
                bg = T.Colors.cellHover
            end
            T.PaintPanel(w, h, bg, T.Colors.border)
            -- false, like DButton's own Paint: the engine still draws the label
            return false
        end
    end
end

function T.Prompt(title, text, default, onOk, onCancel)
    local win = Derma_StringRequest(title, text, default, onOk, onCancel)
    if not IsValid(win) then return win end

    win.Paint = function(self, w, h)
        if self:GetBackgroundBlur() and isfunction(Derma_DrawBackgroundBlur) then
            Derma_DrawBackgroundBlur(self, self.m_fCreateTime)
        end
        T.PaintPanel(w, h, T.Colors.panel, T.Colors.border)
        return true
    end

    -- The frame's OWN furniture is skipped, not skinned: the three window
    -- buttons are hidden here (Derma_StringRequest calls ShowCloseButton(false))
    -- and painting them would put three boxes back on a title bar that is meant
    -- to be empty. The title is a DLabel but wants the heading font, so it is
    -- handled here instead of by the generic walk.
    local skip = {}
    for _, key in ipairs({ "btnClose", "btnMaxim", "btnMinim" }) do
        local b = win[key]
        if IsValid(b) then skip[b] = true end
    end
    if IsValid(win.lblTitle) then
        skip[win.lblTitle] = true
        win.lblTitle:SetFont("CargoHeading")
        win.lblTitle:SetTextColor(T.Colors.text)
    end

    -- recursive because the pieces live TWO levels down: Derma_StringRequest
    -- hangs the label and the entry off an InnerPanel and the two buttons off a
    -- ButtonPanel, so a one-level pass would skin nothing at all.
    local function walk(p)
        for _, child in ipairs(p:GetChildren()) do
            if not skip[child] then SkinPromptChild(child) end
            walk(child)
        end
    end
    walk(win)

    return win
end

-- THE circle primitive (in-game finding 2026-07-13: the sandbox tool circles
-- had hard, flat edges). draw.RoundedBox with radius = half the size does NOT
-- make a circle — its radius is quantized to GMod's corner materials — and the
-- old 24-segment poly showed visible flats at slot size. One triangulated
-- surface.DrawPoly here (no baked textures: #29 must be able to tint every
-- circle from the palette at runtime), consumed by every circle in the module:
-- the sandbox tool slots, the $ header button and the wheel hub.
function T.DrawCircle(cx, cy, r, col, segments)
    segments = segments or (r > 40 and 48 or 32)
    local pts = {}
    for i = 0, segments - 1 do
        local a = math.rad(i * 360 / segments)
        pts[i + 1] = { x = cx + math.cos(a) * r, y = cy + math.sin(a) * r }
    end
    draw.NoTexture()
    surface.SetDrawColor(col)
    surface.DrawPoly(pts)
end

-- filled circle + ring border, both from the same primitive (an opaque fill
-- over a slightly larger border disc — palette colors are opaque, so the
-- border never bleeds through the fill)
function T.DrawCircleOutlined(cx, cy, r, fill, border, thickness)
    T.DrawCircle(cx, cy, r, border)
    T.DrawCircle(cx, cy, r - (thickness or 1), fill)
end

-- aspect-fit draw of an item icon inside a box — never stretched (the icon
-- PNGs carry the footprint aspect, Cargo_ItemImages §6). Shared by grid
-- cells, equipment/quick slots and the tooltip zoom.
function T.DrawIconFit(mat, x, y, w, h)
    local mw, mh = mat:Width(), mat:Height()
    if mw <= 0 or mh <= 0 then mw, mh = 1, 1 end
    local scale = math.min(w / mw, h / mh)
    local dw, dh = mw * scale, mh * scale
    surface.SetDrawColor(255, 255, 255)
    surface.SetMaterial(mat)
    surface.DrawTexturedRect(x + (w - dw) / 2, y + (h - dh) / 2, dw, dh)
end

-- 90°-rotated aspect-fit: wide weapon icons inside the tall vertical slots
-- of the fullscreen equipment column (mock rotates the rifle in Primary)
function T.DrawIconFitVertical(mat, x, y, w, h)
    local mw, mh = mat:Width(), mat:Height()
    if mw <= 0 or mh <= 0 then mw, mh = 1, 1 end
    -- after the 90° turn the drawn bounds are mh×mw, so fit against those
    local scale = math.min(w / mh, h / mw)
    surface.SetDrawColor(255, 255, 255)
    surface.SetMaterial(mat)
    surface.DrawTexturedRectRotated(x + w / 2, y + h / 2,
        mw * scale, mh * scale, 90)
end

-- effect overlay tags (§7 bottom-left corner): known ids get a color; an
-- unknown tag still renders, just neutral — Cargo does not interpret it
local EFFECT_COLORS = {
    hemostatic = T.Colors.red,
    radiation  = T.Colors.amber,
    battery    = T.Colors.green,
}

function T.EffectColor(tag)
    return EFFECT_COLORS[tag] or T.Colors.textDim
end

-- zone keys arrive as free blob strings; known ones get a display label
local ZONE_LABELS = {
    torso = "Torso", stomach = "Stomach", arms = "Arms", legs = "Legs",
    head = "Head",
}

function T.ZoneLabel(key)
    return ZONE_LABELS[key] or (key:sub(1, 1):upper() .. key:sub(2))
end

-- display_stats keys (§9 manual fallback route)
local STAT_LABELS = {
    accuracy = "Accuracy", handling = "Handling",
    damage = "Damage", firerate = "Fire rate",
}
local STAT_ORDER = { "accuracy", "handling", "damage", "firerate" }

function T.DisplayStatRows(display_stats)
    local rows = {}
    for _, key in ipairs(STAT_ORDER) do
        if display_stats[key] ~= nil then
            rows[#rows + 1] = { label = STAT_LABELS[key], delta = display_stats[key] }
        end
    end
    for key, v in SortedPairs(display_stats) do
        if STAT_LABELS[key] == nil then
            rows[#rows + 1] = { label = key, delta = v }
        end
    end
    return rows
end

-- overall condition of a snapshot entry: explicit stack condition, blob
-- condition, or the zone average when the owner module tracks per-zone
function T.ConditionOf(entry)
    if entry.condition ~= nil then return entry.condition end
    local blob = entry.blob
    if not istable(blob) then return nil end
    if blob.condition ~= nil then return blob.condition end
    if istable(blob.zones) then
        local sum, n = 0, 0
        for _, v in pairs(blob.zones) do
            sum = sum + (tonumber(v) or 0)
            n = n + 1
        end
        if n > 0 then return sum / n end
    end
    return nil
end

-- The condition TEXT of an entry, and the ONE place that decides whether it
-- reads as a percent or as uses (roadmap #66, CRG-71). Both forms live here
-- and not at the three call sites on purpose: a cell, a tooltip title and a
-- mounted sub-slot row showing three different units for the same jar is
-- exactly the kind of drift a shared helper stops.
--
-- SHORT is for anywhere with 4 characters of room (the grid cell, the sub-slot
-- row). LONG is the tooltip, and it keeps the PERCENT next to the uses on the
-- author's vote (2026-08-19): the percent is what the price is computed from,
-- so hiding it makes a half-used jar reselling at half read as a pricing bug.
--
-- `def` may be nil (an entry whose def this realm has not learned yet): with no
-- def there is no `uses`, so it falls back to the percent of always.
function T.ConditionShort(def, pct)
    local left = CARGO.Items.UsesLeft(def, pct)
    if left ~= nil then return left .. "/" .. CARGO.Items.UsesOf(def) end
    return math.Round(pct) .. "%"
end

function T.ConditionLong(def, pct)
    local left = CARGO.Items.UsesLeft(def, pct)
    if left ~= nil then
        return left .. "/" .. CARGO.Items.UsesOf(def) .. " uses · "
            .. math.Round(pct) .. "%"
    end
    if pct <= 0 then return "Broken" end
    return "Condition " .. math.Round(pct) .. "%"
end

function T.FormatKg(kg)
    return string.format("%.1f kg", kg)
end

-- truncate text with "..." so it never bleeds out of its cell/row
function T.FitText(text, font, maxW)
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxW then return text end
    local out = text
    while #out > 1 do
        out = out:sub(1, #out - 1)
        if surface.GetTextSize(out .. "...") <= maxW then break end
    end
    return out .. "..."
end

-- ------------------------------------------------------------------
-- Runtime theme (#29): base palette convar + DGL4 preset tint.
-- ------------------------------------------------------------------

local cvTheme = CreateClientConVar("cargo_theme", "spawnmenu", true, false,
    "Cargo base palette: spawnmenu (neutral grays, default) or olive (GAMMA)")
local cvThemeDGL4 = CreateClientConVar("cargo_theme_dgl4", "1", true, false,
    "Derive the Cargo UI palette from the DGL4 holographic HUD's active preset when mounted")

-- write a palette onto the live Color objects (identity preserved — that IS
-- the re-skin mechanism; see header)
local function ApplyPalette(pal)
    for key, live in pairs(T.Colors) do
        local src = pal[key]
        if istable(src) then
            live.r, live.g, live.b = src.r, src.g, src.b
            live.a = src.a or 255
        end
    end
end

local function Mix(a, b, f)
    return C(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f)
end
local function Scaled(a, f, alpha)
    return C(a.r * f, a.g * f, a.b * f, alpha)
end

-- Monochrome palette derived from one accent color — the approximation of
-- the mock's DGL4 snapshots (foxtrot/classic): panels are deep tints of the
-- accent, text is the accent lifted toward white, warn/bad/info stay fixed
-- signal colors (they must read as warnings under ANY tint).
local WHITE = C(255, 255, 255)
function T.BuildDGL4Palette(accent)
    local a = C(accent.r, accent.g, accent.b)
    return {
        bg = Scaled(a, 0.05, 245),   scrim = Scaled(a, 0.04, 205),
        panel = Scaled(a, 0.10),     panelAlt = Scaled(a, 0.14),
        cell = Scaled(a, 0.07),      cellHover = Scaled(a, 0.22),
        border = Scaled(a, 0.30),    borderHi = Scaled(a, 0.55),
        text = Mix(a, WHITE, 0.35),  textDim = Scaled(a, 0.55),
        accent = a,                  accentDim = Scaled(a, 0.5),
        green = a,                   greenDim = Scaled(a, 0.5),
        amber = C(255, 210, 74),     orange = C(255, 150, 60),
        red = C(255, 90, 60),        blue = C(124, 232, 255),
        blueDark = Scaled(a, 0.12),  money = Mix(a, WHITE, 0.35),
        barBack = Scaled(a, 0.04),
    }
end

-- the healthy end of a HoloHUD2 PARAM_COLORRANGES value: highest threshold
-- key wins (health at 100% = the preset's identity color)
local function RangesTopColor(param)
    if not istable(param) or not istable(param.colors) then return nil end
    local bestK, best
    for k, col in pairs(param.colors) do
        k = tonumber(k)
        if k ~= nil and istable(col) and col.r ~= nil
            and (bestK == nil or k > bestK) then
            bestK, best = k, col
        end
    end
    return best
end

-- The accent of the ACTIVE DGL4 preset. COMPAT-RUNTIME: every call goes
-- through pcall against the live API (mapped 2026-07-13 vs the mounted mod:
-- HOLOHUD2.client.GetModifiers() modules/client.lua:24, HOLOHUD2.settings.Get
-- modules/settings.lua:30). Two sources, in order:
--   1. the GLOBAL tint (GetModifiers().color) when set and not plain white;
--   2. DECISION (handoff §3.4 asked for it in writing): presets don't expose
--      an active-preset name — they are per-element value tables — so the
--      accent falls back to the HEALTHY color of the health element
--      (settings.health.health_color, top threshold). health is the one
--      element every official preset styles, and its 100% color IS the
--      preset's identity (Foxtrot Uniform: the PCV green 180,255,100 —
--      read from preset4.lua, not from memory).
-- Returns nil when DGL4 is absent or exposes nothing usable.
function T.DGL4Accent()
    if not istable(HOLOHUD2) then return nil end

    local okM, mods = pcall(function() return HOLOHUD2.client.GetModifiers() end)
    if okM and istable(mods) and istable(mods.color) and mods.color.r ~= nil then
        local c = mods.color
        if not (c.r >= 250 and c.g >= 250 and c.b >= 250) then
            return C(c.r, c.g, c.b)
        end
    end

    local okS, hs = pcall(function() return HOLOHUD2.settings.Get("health") end)
    if okS and istable(hs) then
        local top = RangesTopColor(hs.health_color)
        if top ~= nil then return C(top.r, top.g, top.b) end
    end
    return nil
end

function T.RefreshTheme()
    local pal = T.PALETTES[cvTheme:GetString()] or T.PALETTES.spawnmenu
    if cvThemeDGL4:GetBool() then
        local accent = T.DGL4Accent()
        if accent ~= nil then pal = T.BuildDGL4Palette(accent) end
    end
    ApplyPalette(pal)
end

-- settle now (base palette; DGL4 may not be mounted yet at include time),
-- again at ready (mount order is never assumed), live on its settings hook
-- (HOLOHUD2's OWN hook system, not GMod's — modules/settings.lua:69 fires
-- "OnSettingsChanged" through HOLOHUD2.hook.Call) and on convar flips.
T.RefreshTheme()

Corpus.OnReady(function()
    T.RefreshTheme()
    if istable(HOLOHUD2) and istable(HOLOHUD2.hook)
        and isfunction(HOLOHUD2.hook.Add) then
        pcall(HOLOHUD2.hook.Add, "OnSettingsChanged", "corpus_cargo_theme",
            function() T.RefreshTheme() end)
    end
end)

if istable(cvars) and isfunction(cvars.AddChangeCallback) then
    cvars.AddChangeCallback("cargo_theme", function() T.RefreshTheme() end,
        "corpus_cargo_theme")
    cvars.AddChangeCallback("cargo_theme_dgl4", function() T.RefreshTheme() end,
        "corpus_cargo_theme")
end
