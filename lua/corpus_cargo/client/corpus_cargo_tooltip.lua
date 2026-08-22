-- corpus_cargo_tooltip.lua — item inspection tooltip (CLIENT)
-- Cargo_Architecture.md §9 + tooltip mockups (TooltipArmaCargo.png,
-- TresTooltipArmaduraCascoMochilaCargo.png). One floating panel, manual
-- row layout (no CSS in VGUI): name/weight/condition, trivia, stat rows,
-- ammo pills, per-zone condition, sub-slot contents, backpack capacity,
-- installed ARC9 attachments.
--
-- Stat source hierarchy (§9): ARC9 GetProcessedValue when the player HOLDS
-- the weapon (read-only, absolute values); def.display_stats otherwise
-- (manual deltas). Both feed the same visual rows.

local CARGO = Corpus.GetModule("cargo")

CARGO.Tooltip = CARGO.Tooltip or {}

local T = CARGO.Theme
local WIDTH, PAD = 360, 12

local active

function CARGO.Tooltip.Hide()
    if IsValid(active) then active:Remove() end
    active = nil
end

-- ------------------------------------------------------------------
-- Row builders: each appends a painted DPanel and returns its height.
-- ------------------------------------------------------------------

local function AddRow(parent, tall, paint)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:SetTall(tall)
    row:DockMargin(PAD, 0, PAD, 4)
    row.Paint = paint
    return tall + 4
end

-- The star of a favorite is 9 px wide (its outer diameter) plus 6 of gap. It
-- is a constant and not a text measurement because it is DRAWN and not typed:
-- Roboto — the module's font, read off GMod's own resource/fonts — has no glyph
-- for U+2605, so a draw.SimpleText would paint the missing-glyph box (see
-- T.DrawStar). Keep the two numbers in step with the call below.
local STAR_R, STAR_GAP = 4.5, 6

-- `wEff` is the instance's EFFECTIVE weight (roadmap #58) and is nil whenever
-- there is nothing extra to say — an empty rifle, or any stackable, which has
-- no blob to carry anything. Falling back to `def.weight` is what makes the
-- absent field mean "the class weight IS the truth" instead of "it did not
-- arrive": the client never recomputes it, because the sum lives in
-- Instances.WeightOf on the server and a second copy here is exactly the
-- drifting second truth CRG-56/57 exist to prevent.
local function AddTitle(parent, def, condPct, fav, wEff)
    return AddRow(parent, 24, function(_, w)
        -- name must never collide with the condition text on the right. The
        -- reserve used to be a flat 150 px, which was tuned against
        -- "Condition 100%"; the uses form ("2/3 uses · 67%", roadmap #66) is
        -- longer, so it is MEASURED now instead of guessed — a magic number
        -- that only fits the label it was tuned for is a defect waiting for
        -- the next label. It counts BOTH things that sit to the right of the
        -- name — the condition label AND the weight, which draws right after
        -- it: the flat 150 covered the weight by accident, and measuring only
        -- the label would have pushed the kg off the panel on a long name with
        -- no condition at all, a case that worked before this pass.
        --
        -- THE STAR (roadmap #43) IS THE THIRD THING TO THE RIGHT OF THE NAME,
        -- and it enters the reserve for exactly the reason above: the author
        -- asked for it "al lado derecho del peso", so a name long enough would
        -- either be painted over by it or push it off the panel. That is
        -- literally the defect this same line paid for in the #66 pass — and
        -- the star only appears on SOME items, which is the shape of bug that
        -- looks fine until the day someone favorites a long-named rifle.
        local label = condPct ~= nil and T.ConditionLong(def, condPct) or nil
        local kg = T.FormatKg(wEff or def.weight)
        surface.SetFont("CargoSmall")
        local reserve = surface.GetTextSize(kg) + 8
        if fav then reserve = reserve + STAR_R * 2 + STAR_GAP end
        if label ~= nil then
            surface.SetFont("CargoText")
            reserve = reserve + surface.GetTextSize(label) + 12
        end
        local name = T.FitText(def.name, "CargoHeading", w - reserve)
        draw.SimpleText(name, "CargoHeading", 0, 2, T.Colors.text)
        surface.SetFont("CargoHeading")
        local nameW = surface.GetTextSize(name)
        draw.SimpleText(kg, "CargoSmall", nameW + 8, 6, T.Colors.textDim)
        if fav then
            -- amber comes from the PALETTE and is not a hand-written yellow:
            -- it re-tints with the rest of the UI under DGL4 (CRG-29), where
            -- amber is one of the fixed signal colors, so the star stays yellow
            -- whatever hue the HUD takes.
            surface.SetFont("CargoSmall")
            local kgW = surface.GetTextSize(kg)
            T.DrawStar(nameW + 8 + kgW + STAR_GAP + STAR_R, 11, STAR_R, T.Colors.amber)
        end
        if label ~= nil then
            -- "Condition 67%" / "Broken", or "2/3 uses · 67%" when the def
            -- declared `uses` (roadmap #66). The percent stays next to the uses
            -- on purpose: it is what the resale price is computed from, so
            -- hiding it turns a half-used jar selling at half into a price bug.
            draw.SimpleText(label, "CargoText", w, 4,
                T.ConditionColor(condPct), TEXT_ALIGN_RIGHT)
        end
    end)
end

local function EscapeMarkup(text)
    return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function AddParagraph(parent, text)
    local mk = markup.Parse(
        "<font=CargoSmall><colour=148,148,148>" .. EscapeMarkup(text) .. "</colour></font>",
        WIDTH - PAD * 2)
    return AddRow(parent, mk:GetHeight(), function()
        mk:Draw(0, 0)
    end)
end

local function AddSection(parent, label)
    return AddRow(parent, 18, function(_, w)
        draw.SimpleText(label, "CargoSmall", 0, 6, T.Colors.textDim)
        surface.SetFont("CargoSmall")
        local tw = surface.GetTextSize(label)
        surface.SetDrawColor(T.Colors.border)
        surface.DrawRect(tw + 8, 12, w - tw - 8, 1)
    end)
end

-- delta row: label | bar | signed % (manual display_stats route)
local function AddDeltaRow(parent, label, delta)
    return AddRow(parent, 16, function(_, w)
        draw.SimpleText(label, "CargoSmall", 0, 1, T.Colors.text)
        local col = delta < 0 and T.Colors.red or T.Colors.green
        T.DrawBar(90, 5, w - 90 - 50, 6, math.abs(delta) / 30, col)
        draw.SimpleText(string.format("%+d%%", delta), "CargoSmall", w, 1,
            col, TEXT_ALIGN_RIGHT)
    end)
end

-- absolute row: label | value (ARC9 GetProcessedValue route)
local function AddValueRow(parent, label, value)
    return AddRow(parent, 16, function(_, w)
        draw.SimpleText(label, "CargoSmall", 0, 1, T.Colors.text)
        draw.SimpleText(value, "CargoSmall", w, 1, T.Colors.textDim, TEXT_ALIGN_RIGHT)
    end)
end

local function AddAmmoRow(parent, ammo)
    return AddRow(parent, 22, function(_, w)
        local lead = "Ammo " .. (ammo.caliber or "?")
        draw.SimpleText(lead, "CargoText", 0, 3, T.Colors.text)
        surface.SetFont("CargoText")
        local x = surface.GetTextSize(lead) + 10
        for _, kind in ipairs(ammo.types or {}) do
            surface.SetFont("CargoSmall")
            local tw = surface.GetTextSize(kind)
            if x + tw + 14 > w then break end -- never bleed past the tooltip
            draw.RoundedBox(8, x, 2, tw + 14, 18, T.Colors.panelAlt)
            draw.SimpleText(kind, "CargoSmall", x + 7, 4, T.Colors.text)
            x = x + tw + 20
        end
    end)
end

local function AddZoneRow(parent, label, pct)
    return AddRow(parent, 16, function(_, w)
        draw.SimpleText(label, "CargoSmall", 0, 1, T.Colors.text)
        if pct <= 0 then
            draw.SimpleText("Broken", "CargoSmall", w, 1, T.Colors.red, TEXT_ALIGN_RIGHT)
            return
        end
        T.DrawBar(80, 5, w - 80 - 46, 6, pct / 100, T.ConditionColor(pct))
        draw.SimpleText(math.Round(pct) .. "%", "CargoSmall", w, 1,
            T.ConditionColor(pct), TEXT_ALIGN_RIGHT)
    end)
end

-- `def` is the def of the MOUNTED item, and it rides only so this row speaks
-- the same unit as the cell the item came from: a thing with `uses` reads
-- "2/3" here too, not a percent (roadmap #66). It is optional — the two
-- callers that pass no pct pass no def either.
local function AddSubEntryRow(parent, text, pct, empty, def)
    return AddRow(parent, 20, function(_, w)
        draw.RoundedBox(4, 0, 0, w, 20, empty and T.Colors.panelAlt or T.Colors.blueDark)
        draw.SimpleText(T.FitText(text, "CargoSmall", w - 60), "CargoSmall", 8, 3,
            empty and T.Colors.textDim or T.Colors.text)
        if pct ~= nil then
            draw.SimpleText(T.ConditionShort(def, pct), "CargoSmall", w - 8, 3,
                T.ConditionColor(pct), TEXT_ALIGN_RIGHT)
        end
    end)
end

-- ------------------------------------------------------------------
-- Show: builds the panel for a snapshot entry next to its cell.
-- ------------------------------------------------------------------

function CARGO.Tooltip.Show(cell, entry)
    CARGO.Tooltip.Hide()
    local def = CARGO.Items.Get(entry.id)
    if def == nil then return end
    local blob = entry.blob

    local tip = vgui.Create("DPanel")
    tip:SetDrawOnTop(true)
    tip:SetMouseInputEnabled(false)
    tip:DockPadding(0, 10, 0, 0) -- rows dock from the top; keep it in sync with y = 10
    tip.Paint = function(_, w, h) T.PaintPanel(w, h, T.Colors.panel, T.Colors.borderHi) end

    -- self-cleaning: the tooltip lives only while its cell is hovered
    tip.Think = function(self)
        if not IsValid(cell) or not cell:IsHovered() then
            self:Remove()
            if active == self then active = nil end
        end
    end

    local y = 10
    y = y + AddTitle(tip, def, T.ConditionOf(entry), entry.fav == true, entry.w)

    -- icon zoom (Cargo_ItemImages §6/§10): the 64 px/cell renders hold up at
    -- tooltip size; painted from Icons.Get each frame so it hot-swaps in
    -- when the queued render lands. No letter here — no icon, no row.
    do
        local icon = CARGO.Icons.Get(entry.id)
        if icon ~= nil then
            local mw, mh = icon:Width(), icon:Height()
            if mw <= 0 or mh <= 0 then mw, mh = 1, 1 end
            local boxH = math.min(140, math.ceil((WIDTH - PAD * 2) * mh / mw))
            y = y + AddRow(tip, boxH, function(_, w)
                local mat = CARGO.Icons.Get(entry.id)
                if mat ~= nil then T.DrawIconFit(mat, 0, 0, w, boxH) end
            end)
        end
    end

    if isstring(def.trivia) and def.trivia ~= "" then
        y = y + AddParagraph(tip, def.trivia)
    end

    -- stats: ARC9 route only when the weapon is actually held (a SWEP
    -- instance is required for processed values); manual deltas otherwise
    local statsDone = false
    if isstring(def.weapon_class) and CARGO.ARC9 and CARGO.ARC9.Available and CARGO.ARC9.Available() then
        local ply = LocalPlayer()
        local wep = IsValid(ply) and ply:GetWeapon(def.weapon_class) or nil
        if IsValid(wep) then
            local rows = CARGO.ARC9.WeaponStats(wep)
            if rows and #rows > 0 then
                y = y + AddSection(tip, "Stats (ARC9)")
                for _, row in ipairs(rows) do
                    y = y + AddValueRow(tip, row.label, row.value)
                end
                statsDone = true
            end
            local installed = CARGO.ARC9.Installed(wep)
            if #installed > 0 then
                y = y + AddSection(tip, "Installed attachments")
                for _, att in ipairs(installed) do
                    y = y + AddSubEntryRow(tip, att.name .. (att.integral and " (integral)" or ""))
                end
            end
        end
    end
    if not statsDone and istable(def.display_stats) then
        y = y + AddSection(tip, "Stats (manual)")
        for _, row in ipairs(T.DisplayStatRows(def.display_stats)) do
            y = y + AddDeltaRow(tip, row.label, row.delta)
        end
    end

    -- spec rows the SWEP declares about itself (manufacturer, caliber, action,
    -- country, year): resolved and ordered server-side at capture, so this only
    -- paints. Unlike the stats above they do NOT need the weapon in hand — an
    -- ARC9 gun sitting in the grid still tells you who made it.
    if istable(def.trivia_rows) and #def.trivia_rows > 0 then
        y = y + AddSection(tip, "Specs")
        for _, row in ipairs(def.trivia_rows) do
            y = y + AddValueRow(tip, row.label, row.value)
        end
    end

    if istable(def.ammo) then
        y = y + AddAmmoRow(tip, def.ammo)
    end

    -- per-zone condition (armor mockup): render in the def's declared order
    if istable(blob) and istable(blob.zones) and istable(def.condition_zones) then
        y = y + AddSection(tip, "Condition by zone")
        for _, zone in ipairs(def.condition_zones) do
            if blob.zones[zone] ~= nil then
                y = y + AddZoneRow(tip, T.ZoneLabel(zone), tonumber(blob.zones[zone]) or 0)
            end
        end
    end

    -- declared sub-slots with their mounted contents
    if istable(def.subslots) then
        for _, spec in ipairs(def.subslots) do
            y = y + AddSection(tip, "Sub-slot " .. spec.label .. " · filter: " .. spec.filter)
            local entries = istable(blob) and istable(blob.subslots)
                and blob.subslots[spec.id] or nil
            local shown = 0
            if istable(entries) then
                for _, sub in ipairs(entries) do
                    local subDef = CARGO.Items.Get(sub.id)
                    local label = subDef and subDef.name or sub.id
                    if subDef and subDef.material then
                        label = label .. " · " .. subDef.material
                    end
                    y = y + AddSubEntryRow(tip, label, sub.condition, false, subDef)
                    shown = shown + 1
                end
            end
            for _ = shown + 1, spec.maxItems do
                y = y + AddSubEntryRow(tip, "+ Empty slot", nil, true)
            end
        end
    end

    -- backpack rows (Back = capacity modifier, §5)
    if isnumber(def.capacity_bonus) then
        y = y + AddSection(tip, "Capacity")
        y = y + AddRow(tip, 16, function(_, w)
            draw.SimpleText("Capacity", "CargoSmall", 0, 1, T.Colors.text)
            draw.SimpleText("+" .. T.FormatKg(def.capacity_bonus), "CargoSmall", w, 1,
                T.Colors.green, TEXT_ALIGN_RIGHT)
        end)
        y = y + AddRow(tip, 16, function(_, w)
            draw.SimpleText("Mov. penalty", "CargoSmall", 0, 1, T.Colors.text)
            draw.SimpleText("total-weight curve", "CargoSmall", w, 1,
                T.Colors.textDim, TEXT_ALIGN_RIGHT)
        end)
    end

    tip:SetSize(WIDTH, y + 8)
    tip:InvalidateLayout(true)

    -- next to the cursor, clamped on screen
    local mx, my = gui.MousePos()
    tip:SetPos(math.min(mx + 18, ScrW() - WIDTH - 8),
        math.min(my + 8, ScrH() - tip:GetTall() - 8))

    active = tip
end
