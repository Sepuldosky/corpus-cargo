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

    -- trade only (Cargo_Trade §8): unit price top-left, and the amber basket
    -- frame + count for what is already pending in the deal. Both come from
    -- the controller's callbacks, so the solo/loot grids draw neither.
    local price = isfunction(self.cargoPriceOf) and self.cargoPriceOf(entry) or nil
    local pricedW = 0
    if price ~= nil then
        local txt = CARGO.Trade.FormatMoney(price)
        surface.SetFont("CargoTiny")
        pricedW = surface.GetTextSize(txt) + 4
        draw.SimpleText(txt, "CargoTiny", 4, 3, T.Colors.money)
    end

    local inBasket = isfunction(self.cargoBasketOf) and self.cargoBasketOf(entry) or 0
    if inBasket > 0 then
        surface.SetDrawColor(T.Colors.amber)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        draw.SimpleText("·" .. inBasket, "CargoTiny", w - 4, h / 2 - 6,
            T.Colors.amber, TEXT_ALIGN_RIGHT)
    end

    -- stack count, top-right
    if (entry.count or 1) > 1 then
        draw.SimpleText("x" .. entry.count, "CargoTiny", w - 4, 3,
            T.Colors.text, TEXT_ALIGN_RIGHT)
    end

    -- bound ammo group (unique weapons), top-left — mock badge "A"/"B".
    -- Shifted right of the price tag when both share the corner (trade).
    if entry.blob and entry.blob.ammo_group ~= nil then
        draw.SimpleText(entry.blob.ammo_group, "CargoTiny", 4 + pricedW, 3, T.Colors.amber)
    end

    -- condition: bar hugging the bottom edge + the number above it,
    -- bottom-right. The NUMBER is "67%" or "2/3" depending on whether the def
    -- declared `uses` (roadmap #66) — Theme decides, so the cell, the tooltip
    -- and the sub-slot row cannot drift apart. The BAR stays on the raw
    -- condition either way: it is continuous and it is what the price reads.
    local cond = T.ConditionOf(entry)
    if cond ~= nil then
        T.DrawBar(0, h - 3, w, 3, cond / 100, T.ConditionColor(cond))
        draw.SimpleText(T.ConditionShort(def, cond), "CargoTiny", w - 4, h - 16,
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
--   dragSource    string tag stored on cells ("own"/"cont"/"stock"), nil = no drag
--   onReceiveDrop function(droppedCell)? — makes the canvas a drop target
--   onCellDrop    function(targetEntry, droppedCell) -> handled? — makes every
--                 CELL a drop target too, so an item can be dropped ON another
--                 item (mounting into a sub-slot, roadmap #47). Returning
--                 false falls through to onReceiveDrop, which is what keeps
--                 the container/trade transfer working when the cell under the
--                 cursor is not a valid host: the canvas behaviour must never
--                 depend on WHERE inside the canvas you let go.
--   priceOf       function(entry) -> number|nil — trade: unit price tag
--   basketOf      function(entry) -> n — trade: units pending in the basket
-- ------------------------------------------------------------------

function CARGO.Grid.Create(parent, opts)
    local controller = { filter = "all" }

    local scroll = vgui.Create("DScrollPanel", parent)
    T.SkinScroll(scroll) -- stock Derma bar breaks the palette (report 2026-07-13)
    scroll.Paint = function(self, w, h)
        surface.SetDrawColor(T.Colors.panelAlt)
        surface.DrawRect(0, 0, w, h)

        -- faint cell reticle covering the WHOLE viewport (roadmap #24).
        -- It used to live in the layout's Paint so it would share origin
        -- with the tiles and scroll with them (entry 8's alignment fix) —
        -- but a DIconLayout is only as tall as its content: an empty grid
        -- showed no reticle at all and a short one cut off at the last row
        -- (in-game report 2026-07-12). Painting the viewport keeps it full;
        -- the CANVAS OFFSET keeps the phase locked to the tiles: a tile
        -- edge always sits at margin + k*(U+GAP) in canvas space, and the
        -- canvas rides at GetPos() while scrolling — so the reticle still
        -- moves with the content and the entry-8 alignment survives.
        local U, GAP = Metrics()
        local step = U + GAP
        local cx, cy = 0, 0
        local canvas = self.GetCanvas ~= nil and self:GetCanvas() or nil
        if IsValid(canvas) then cx, cy = canvas:GetPos() end
        surface.SetDrawColor(255, 255, 255, 5)
        for x = (cx + GAP) % step, w, step do
            surface.DrawLine(x, 0, x, h)
        end
        for y = (cy + GAP) % step, h, step do
            surface.DrawLine(0, y, w, y)
        end
    end

    local layout = vgui.Create("DIconLayout", scroll)
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
            -- the filter is a DISPLAY tab, not an internal category (#23):
            -- one tab groups several categories, unmapped ones fall to Misc
            local visible = CARGO.Items.MatchesTab(def, controller.filter)
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
                cell.cargoPriceOf = opts.priceOf
                cell.cargoBasketOf = opts.basketOf
                cell.Paint = PaintCell
                cell.PaintOver = PaintCellOver

                cell.OnCursorEntered = function(self)
                    CARGO.Tooltip.Show(self, entry)
                end
                cell.DoClick = function(self)
                    -- STALKER-style pick foley by category (author's sound
                    -- bank map, sound/corpus/cargo/items/about.txt)
                    CARGO.Sounds.PickFor(def)
                    if isfunction(opts.onLeftClick) then opts.onLeftClick(entry, self) end
                end
                cell.DoRightClick = function(self)
                    if isfunction(opts.onRightClick) then opts.onRightClick(entry, self) end
                end

                if opts.dragSource then
                    cell:Droppable("cargo_item")
                end

                -- A cell that is ALSO a receiver shadows the canvas receiver
                -- (dragndrop walks up from the hovered panel and stops at the
                -- first one), so the fall-through below is not optional: skip
                -- it and dropping an item onto another item inside a loot
                -- panel would silently do nothing instead of transferring.
                if isfunction(opts.onCellDrop) then
                    cell:Receiver("cargo_item", function(self, panels, dropped)
                        if not dropped or not IsValid(panels[1]) then return end
                        if panels[1] == self then return end -- dropped on itself
                        if opts.onCellDrop(entry, panels[1]) then return end
                        if isfunction(opts.onReceiveDrop) then
                            opts.onReceiveDrop(panels[1])
                        end
                    end)
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
