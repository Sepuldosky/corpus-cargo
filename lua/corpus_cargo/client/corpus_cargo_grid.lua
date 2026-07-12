-- corpus_cargo_grid.lua — reusable inventory grid + cell overlays (CLIENT)
-- Cargo_Architecture.md §7 (as amended by §15): tiered grid — every item
-- paints w×h cells per its footprint (Cargo_ItemImages §5). Footprint is
-- render only: the data model stays uniform (no spatial management, no
-- rotation, auto-sort by category; carry cost is weight, not space).
-- Reused by the main inventory and the container/loot column.
--
-- The tile flow is DIconLayout doing what the mock's flex-wrap does: rows
-- fill left to right and wrap; row height = tallest tile in the row.
-- Overlays are NOT CSS: they are PaintOver drawing at fixed corners
-- (stack count ↗, condition ↘ + bottom bar, ammo group ↖, caliber ↙).

local CARGO = Corpus.GetModule("cargo")

CARGO.Grid = CARGO.Grid or {}

local T = CARGO.Theme

-- cell unit + gap, scaled from the 1080p mock (42 px / 4 px). Computed per
-- refresh, not at file scope: the resolution can change mid-session.
local function Metrics()
    local s = T.UIScale()
    return math.Round(42 * s), math.max(math.Round(4 * s), 2)
end

-- category order cache for the auto-sort
local function CategoryOrder(catId)
    local cat = CARGO.Items._categories[catId]
    return cat and cat.order or 999
end

local function PaintCell(self, w, h)
    -- No filled tile behind items (author call, 2nd fullscreen pass
    -- 2026-07-12: the dark block dirtied the view — STALKER floats items on
    -- the bare reticle). Only the hover state paints a highlight + border;
    -- resting cells show just the faint layout reticle and the icon.
    if self:IsHovered() then
        draw.RoundedBox(4, 0, 0, w, h, T.Colors.cellHover)
        surface.SetDrawColor(T.Colors.borderHi)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local def = self.cargoDef
    if def == nil then return end

    -- icon via the icon system (Cargo_ItemImages §2/§10): def.icon, generated
    -- render or nil. The icon PNG carries the footprint aspect (§6), so the
    -- aspect-fit fills the tiered tile edge to edge. The letter stays as the
    -- queued placeholder and as the no-model error signal.
    local icon = CARGO.Icons.Get(def.id)
    if icon ~= nil then
        T.DrawIconFit(icon, 3, 3, w - 6, h - 6)
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

    -- bound ammo group (unique weapons), top-left — mock badge "A"/"B"
    if entry.blob and entry.blob.ammo_group ~= nil then
        draw.SimpleText(entry.blob.ammo_group, "CargoTiny", 4, 3, T.Colors.amber)
    end

    -- condition: bar hugging the bottom edge + % above it, bottom-right
    local cond = T.ConditionOf(entry)
    if cond ~= nil then
        T.DrawBar(0, h - 3, w, 3, cond / 100, T.ConditionColor(cond))
        draw.SimpleText(math.Round(cond) .. "%", "CargoTiny", w - 4, h - 16,
            T.ConditionColor(cond), TEXT_ALIGN_RIGHT)
    end

    -- bottom-left: effect tag dot, or ammo caliber for ammunition
    if isstring(def.effect_icon) then
        draw.RoundedBox(2, 4, h - 14, 8, 8, T.EffectColor(def.effect_icon))
    elseif istable(def.ammo) and def.category == "ammo" then
        draw.SimpleText(def.ammo.caliber or "", "CargoTiny", 4, h - 16, T.Colors.textDim)
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
    -- faint cell reticle behind the tiles (mock's gridwrap background).
    -- Painted by the LAYOUT, not the scroll: same origin as the tiles (a
    -- tile's left/top edge always sits on a k*(U+GAP) multiple in layout
    -- space) and it scrolls with the content — alignment came back wrong
    -- from the first in-game pass when the scroll painted it.
    layout.Paint = function(self, w, h)
        local U, GAP = Metrics()
        local step = U + GAP
        surface.SetDrawColor(255, 255, 255, 5)
        for x = 0, w, step do surface.DrawLine(x, 0, x, h) end
        for y = 0, h, step do surface.DrawLine(0, y, w, y) end
    end
    -- TOP, never FILL: inside a DScrollPanel the canvas sizes itself to its
    -- children while a FILL child sizes itself to the canvas — the circular
    -- collapse clipped the cells and made Refresh() repopulate a zero-height
    -- layout (container side looked empty until reopened). Same family as
    -- the documented DNumSlider/DPropertySheet-in-scroll traps.
    layout:Dock(TOP)

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

        local U, GAP = Metrics()
        layout:DockMargin(GAP, GAP, GAP, GAP)
        layout:SetSpaceX(GAP)
        layout:SetSpaceY(GAP)

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
                -- tiered tile: footprint w×h cells, gaps included so tile
                -- edges land on the reticle (unknown defs render 1×1)
                local fp = def and CARGO.Icons.GetFootprint(def) or { w = 1, h = 1 }
                cell:SetSize(fp.w * U + (fp.w - 1) * GAP,
                    fp.h * U + (fp.h - 1) * GAP)
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
