-- corpus_cargo_grid.lua — reusable inventory grid + cell overlays (CLIENT)
-- Cargo_Architecture.md §7. Uniform grid: 1 cell = 1 entry, auto-sorted by
-- category order, no spatial management. Reused by the main inventory and
-- by both halves of the container transfer panel.
--
-- Overlays are NOT CSS: they are PaintOver drawing at fixed corners
-- (stack count ↗, condition ↘, effect/caliber ↙) — known VGUI trap,
-- see the project notes ported from ADS.

local CARGO = Corpus.GetModule("cargo")

CARGO.Grid = CARGO.Grid or {}

local T = CARGO.Theme
local CELL, GAP = 64, 6

-- category order cache for the auto-sort
local function CategoryOrder(catId)
    local cat = CARGO.Items._categories[catId]
    return cat and cat.order or 999
end

local function PaintCell(self, w, h)
    local hovered = self:IsHovered()
    draw.RoundedBox(4, 0, 0, w, h, hovered and T.Colors.cellHover or T.Colors.cell)
    surface.SetDrawColor(hovered and T.Colors.borderHi or T.Colors.border)
    surface.DrawOutlinedRect(0, 0, w, h, 1)

    local def = self.cargoDef
    if def == nil then return end

    -- icon: material path, IMaterial (ARC9 atts) or first-letter fallback
    local icon = def.icon
    if isstring(icon) and icon ~= "" then icon = Material(icon) end
    if icon ~= nil and not istable(icon) and not isstring(icon) and not icon:IsError() then
        surface.SetDrawColor(255, 255, 255)
        surface.SetMaterial(icon)
        surface.DrawTexturedRect(w / 2 - 20, h / 2 - 20, 40, 40)
    else
        draw.SimpleText(string.upper(def.name:sub(1, 1)), "CargoTitle",
            w / 2, h / 2, T.Colors.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function PaintCellOver(self, w, h)
    local entry = self.cargoEntry
    local def = self.cargoDef
    if entry == nil or def == nil then return end

    -- stack count, top-right
    if (entry.count or 1) > 1 then
        draw.SimpleText("x" .. entry.count, "CargoTiny", w - 4, 3,
            T.Colors.text, TEXT_ALIGN_RIGHT)
    end

    -- condition %, bottom-right (only items that track it)
    local cond = T.ConditionOf(entry)
    if cond ~= nil then
        draw.SimpleText(math.Round(cond) .. "%", "CargoTiny", w - 4, h - 14,
            T.ConditionColor(cond), TEXT_ALIGN_RIGHT)
    end

    -- bottom-left: effect tag dot, or ammo caliber for ammunition
    if isstring(def.effect_icon) then
        draw.RoundedBox(2, 4, h - 12, 8, 8, T.EffectColor(def.effect_icon))
    elseif istable(def.ammo) and def.category == "ammo" then
        draw.SimpleText(def.ammo.caliber or "", "CargoTiny", 4, h - 14, T.Colors.textDim)
    end
end

-- ------------------------------------------------------------------
-- Create(parent, opts) -> controller with :Refresh() and :SetFilter(cat).
-- opts:
--   getEntries    function() -> array of snapshot entries
--   onLeftClick   function(entry, cell)?
--   onRightClick  function(entry, cell)?
--   dragSource    string tag stored on cells ("own"/"cont"), nil = no drag
--   onReceiveDrop function(droppedCell)? — makes the canvas a drop target
-- ------------------------------------------------------------------

function CARGO.Grid.Create(parent, opts)
    local controller = { filter = "all" }

    local scroll = vgui.Create("DScrollPanel", parent)
    scroll.Paint = function(_, w, h)
        surface.SetDrawColor(T.Colors.panelAlt)
        surface.DrawRect(0, 0, w, h)
    end

    local layout = vgui.Create("DIconLayout", scroll)
    -- TOP, never FILL: inside a DScrollPanel the canvas sizes itself to its
    -- children while a FILL child sizes itself to the canvas — the circular
    -- collapse clipped the cells and made Refresh() repopulate a zero-height
    -- layout (container side looked empty until reopened). Same family as
    -- the documented DNumSlider/DPropertySheet-in-scroll traps.
    layout:Dock(TOP)
    layout:DockMargin(GAP, GAP, GAP, GAP)
    layout:SetSpaceX(GAP)
    layout:SetSpaceY(GAP)

    if isfunction(opts.onReceiveDrop) then
        scroll:Receiver("cargo_item", function(_, panels, dropped)
            if dropped and IsValid(panels[1]) then opts.onReceiveDrop(panels[1]) end
        end)
    end

    controller.panel = scroll

    function controller.SetFilter(cat)
        controller.filter = cat or "all"
        controller.Refresh()
    end

    function controller.Refresh()
        CARGO.Tooltip.Hide()
        layout:Clear()

        local entries = opts.getEntries() or {}

        -- auto-sort: category order, then name — stable view across syncs
        local sorted = {}
        for _, entry in ipairs(entries) do sorted[#sorted + 1] = entry end
        table.sort(sorted, function(a, b)
            local da, db = CARGO.Items.Get(a.id), CARGO.Items.Get(b.id)
            local oa = da and CategoryOrder(da.category) or 999
            local ob = db and CategoryOrder(db.category) or 999
            if oa ~= ob then return oa < ob end
            local na, nb = da and da.name or a.id, db and db.name or b.id
            if na ~= nb then return na < nb end
            return (a.uid or "") < (b.uid or "")
        end)

        for _, entry in ipairs(sorted) do
            local def = CARGO.Items.Get(entry.id)
            local visible = controller.filter == "all"
                or (def and def.category == controller.filter)
            if visible then
                local cell = layout:Add("DButton")
                cell:SetSize(CELL, CELL)
                cell:SetText("")
                cell.cargoEntry = entry
                cell.cargoDef = def
                cell.cargoSource = opts.dragSource
                cell.Paint = PaintCell
                cell.PaintOver = PaintCellOver

                cell.OnCursorEntered = function(self)
                    CARGO.Tooltip.Show(self, entry)
                end
                cell.DoClick = function(self)
                    if isfunction(opts.onLeftClick) then opts.onLeftClick(entry, self) end
                end
                cell.DoRightClick = function(self)
                    if isfunction(opts.onRightClick) then opts.onRightClick(entry, self) end
                end

                if opts.dragSource then
                    cell:Droppable("cargo_item")
                end
            end
        end

        layout:InvalidateLayout(true) -- recompute rows/height right now
    end

    return controller
end

-- Snapshot entry -> server-side ref (the wire format the server resolves
-- with FindEntry): uid for uniques, id+condition for stacks.
function CARGO.Grid.RefOf(entry)
    if entry.uid then return { uid = entry.uid } end
    return { id = entry.id, condition = entry.condition }
end
