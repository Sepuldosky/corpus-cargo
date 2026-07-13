-- corpus_cargo_theme.lua — palette, fonts and paint helpers (CLIENT)
-- Single place the whole Cargo UI reads its look from. Dark palette taken
-- from the frozen mockups (docs/mockups/). The mocks are CSS; VGUI has no
-- flexbox/grid — everything here is manual painting on purpose.

local CARGO = Corpus.GetModule("cargo")

CARGO.Theme = CARGO.Theme or {}
local T = CARGO.Theme

-- olive/military palette lifted from the fullscreen mock
-- (cargo_fullscreen_ui_mock_v1.html :root vars)
T.Colors = {
    bg        = Color(11, 12, 10, 245),
    panel     = Color(20, 21, 15),
    panelAlt  = Color(25, 26, 19),
    cell      = Color(15, 16, 11),
    cellHover = Color(34, 37, 26),
    border    = Color(43, 45, 34),
    borderHi  = Color(58, 61, 46),
    text      = Color(214, 217, 200),
    textDim   = Color(110, 114, 99),
    green     = Color(157, 192, 75),
    greenDim  = Color(92, 112, 48),
    amber     = Color(217, 161, 59),
    orange    = Color(216, 122, 44),
    red       = Color(199, 80, 58),
    blue      = Color(91, 143, 168),
    blueDark  = Color(24, 34, 40),
    money     = Color(222, 216, 194),
    barBack   = Color(10, 11, 7),
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

-- standard panel look: flat box + hairline border
function T.PaintPanel(w, h, bgCol, borderCol)
    draw.RoundedBox(4, 0, 0, w, h, bgCol or T.Colors.panel)
    surface.SetDrawColor(borderCol or T.Colors.border)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
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
