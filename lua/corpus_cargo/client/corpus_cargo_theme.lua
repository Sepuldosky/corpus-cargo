-- corpus_cargo_theme.lua — palette, fonts and paint helpers (CLIENT)
-- Single place the whole Cargo UI reads its look from. Dark palette taken
-- from the frozen mockups (docs/mockups/). The mocks are CSS; VGUI has no
-- flexbox/grid — everything here is manual painting on purpose.

local CARGO = Corpus.GetModule("cargo")

CARGO.Theme = CARGO.Theme or {}
local T = CARGO.Theme

T.Colors = {
    bg        = Color(14, 14, 14, 245),
    panel     = Color(24, 24, 24),
    panelAlt  = Color(32, 32, 32),
    cell      = Color(30, 30, 30),
    cellHover = Color(42, 42, 42),
    border    = Color(52, 52, 52),
    borderHi  = Color(90, 90, 90),
    text      = Color(224, 224, 224),
    textDim   = Color(148, 148, 148),
    green     = Color(102, 187, 106),
    amber     = Color(255, 179, 0),
    orange    = Color(255, 111, 0),
    red       = Color(229, 57, 53),
    blue      = Color(33, 118, 205),
    blueDark  = Color(18, 52, 86),
    barBack   = Color(50, 50, 50),
}

surface.CreateFont("CargoTitle",   { font = "Roboto", size = 20, weight = 700 })
surface.CreateFont("CargoHeading", { font = "Roboto", size = 16, weight = 700 })
surface.CreateFont("CargoText",    { font = "Roboto", size = 14, weight = 500 })
surface.CreateFont("CargoSmall",   { font = "Roboto", size = 12, weight = 500 })
surface.CreateFont("CargoTiny",    { font = "Roboto", size = 11, weight = 700 })

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

-- standard panel look: flat box + hairline border
function T.PaintPanel(w, h, bgCol, borderCol)
    draw.RoundedBox(4, 0, 0, w, h, bgCol or T.Colors.panel)
    surface.SetDrawColor(borderCol or T.Colors.border)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
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
