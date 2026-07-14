-- corpus_cargo_trade.lua — trade session state, basket and its panels (CLIENT)
-- Cargo_Trade_Arquitectura.md §3 (basket + confirm) and §8 (layout).
--
-- Same split as the container/loot pair: this file owns the WIRE (trader
-- snapshot, basket, intents) and the two panels that only exist while trading
-- (the trader's stock column and the deal bar); corpus_cargo_ui.lua owns the
-- frame and calls in. The basket is CLIENT-SIDE INTENT ONLY — it holds no
-- items and moves nothing. The server re-resolves and re-prices every line at
-- Confirm and its numbers are the only ones that count (§3).

local CARGO = Corpus.GetModule("cargo")

CARGO.Trade = CARGO.Trade or {}

local T = CARGO.Theme

local NET_TRADE_OPEN    = Corpus.Net.Register("cargo", "trade_open")
local NET_TRADE_SYNC    = Corpus.Net.Register("cargo", "trade_sync")
local NET_TRADE_CLOSE   = Corpus.Net.Register("cargo", "trade_close")
local NET_TRADE_CONFIRM = Corpus.Net.Register("cargo", "trade_confirm")

local tradeState          -- the trader snapshot (nil = no session)
local basket = { buy = {}, sell = {} } -- keyed by RefKey -> { ref, count, entry }
local dealBar             -- repainted from the basket every frame

function CARGO.Trade.State()
    return tradeState
end

-- ------------------------------------------------------------------
-- Basket
-- ------------------------------------------------------------------

local function Side(side)
    return side == "buy" and basket.buy or basket.sell
end

function CARGO.Trade.BasketCount(side, entry)
    local line = Side(side)[CARGO.Trade.RefKey(entry)]
    return line and line.count or 0
end

-- how many units of this entry exist to add (a stack already half in the basket
-- can only put its remainder in — BasketAdd clamps against what is pending)
local function Available(entry)
    return entry.uid and 1 or (entry.count or 1)
end

CARGO.Trade.Available = Available -- the own grid (corpus_cargo_ui.lua) needs it too

function CARGO.Trade.BasketAdd(side, entry, count)
    if tradeState == nil then return end
    local def = CARGO.Items.Get(entry.id)
    if not CARGO.Trade.IsTradeable(def) then
        chat.AddText(T.Colors.amber, "[Cargo] ", T.Colors.text,
            (def and def.name or entry.id) .. " has no price: it cannot be traded.")
        return
    end

    local lines = Side(side)
    local key = CARGO.Trade.RefKey(entry)
    local line = lines[key]
    local have = line and line.count or 0
    local room = Available(entry) - have
    if room <= 0 then return end

    local add = math.Clamp(math.floor(count or 1), 1, room)
    if line == nil then
        lines[key] = {
            ref = CARGO.Grid.RefOf(entry),
            count = add,
            entry = entry, -- kept for the strip label/price only
        }
    else
        line.count = line.count + add
        line.entry = entry
    end
    CARGO.UI.RefreshTrade()
end

function CARGO.Trade.BasketRemove(side, key)
    Side(side)[key] = nil
    CARGO.UI.RefreshTrade()
end

function CARGO.Trade.BasketClear()
    basket.buy, basket.sell = {}, {}
end

-- Totals, computed with the SAME shared math the server will re-run (§4). The
-- multipliers come from the trader snapshot: he sells at sellMult and buys at
-- buyMult.
function CARGO.Trade.Totals()
    local cost, gain = 0, 0
    if tradeState == nil then return 0, 0, 0 end

    for _, line in pairs(basket.buy) do
        local unit = CARGO.Trade.PriceOfEntry(line.entry, tradeState.sellMult) or 0
        cost = cost + unit * line.count
    end
    for _, line in pairs(basket.sell) do
        local unit = CARGO.Trade.PriceOfEntry(line.entry, tradeState.buyMult) or 0
        gain = gain + unit * line.count
    end
    return gain - cost, cost, gain
end

-- Price tag of a cell: what the player would PAY for a stock item, what he
-- would GET for one of his own. Returns nil for anything with no value —
-- the cell then shows no tag, which is the honest "not tradeable".
function CARGO.Trade.CellPrice(side, entry)
    if tradeState == nil then return nil end
    return CARGO.Trade.PriceOfEntry(entry,
        side == "buy" and tradeState.sellMult or tradeState.buyMult)
end

-- ------------------------------------------------------------------
-- Intents
-- ------------------------------------------------------------------

function CARGO.Trade.SendConfirm()
    if tradeState == nil then return end
    local payload = { traderId = tradeState.traderId, buy = {}, sell = {} }
    for _, line in pairs(basket.buy) do
        payload.buy[#payload.buy + 1] = { ref = line.ref, count = line.count }
    end
    for _, line in pairs(basket.sell) do
        payload.sell[#payload.sell + 1] = { ref = line.ref, count = line.count }
    end
    if #payload.buy == 0 and #payload.sell == 0 then return end

    net.Start(NET_TRADE_CONFIRM)
    CARGO.Util.WriteBlob(payload)
    net.SendToServer()
    -- the basket empties on the SYNC that follows a successful deal; a failed
    -- one re-syncs too and PruneBasket below drops whatever went stale
end

function CARGO.Trade.Cancel()
    CARGO.Trade.BasketClear()
    CARGO.UI.RefreshTrade()
end

function CARGO.Trade.NotifyClosed()
    if tradeState == nil then return end
    net.Start(NET_TRADE_CLOSE)
    net.WriteUInt(tradeState.traderId, 16)
    net.SendToServer()
    tradeState = nil
    CARGO.Trade.BasketClear()
end

-- The basket points at entries that may have moved (bought, sold, dropped by
-- another flow). After every sync, re-resolve each line against the live
-- lists; whatever is gone leaves the basket instead of lingering as a ghost
-- line the server would reject forever.
local function PruneBasket()
    local function prune(lines, source)
        for key, line in pairs(lines) do
            local found
            for _, entry in ipairs(source or {}) do
                if CARGO.Trade.RefKey(entry) == key then found = entry break end
            end
            if found == nil then
                lines[key] = nil
            else
                line.entry = found
                line.count = math.min(line.count, Available(found))
            end
        end
    end
    prune(basket.buy, tradeState and tradeState.items)
    prune(basket.sell, CARGO.ClientState and CARGO.ClientState.items)
end

CARGO.Trade.PruneBasket = PruneBasket

-- ------------------------------------------------------------------
-- Panels. Both are built by corpus_cargo_ui.lua's frame in the trade state.
-- ------------------------------------------------------------------

local function StripLine(parent, side, key, line, mult)
    local row = vgui.Create("DButton", parent)
    row:Dock(TOP)
    row:SetTall(20)
    row:DockMargin(0, 0, 0, 2)
    row:SetText("")
    row:SetTooltip("Click to take it out of the basket")
    row.Paint = function(self, w, h)
        if self:IsHovered() then
            surface.SetDrawColor(T.Colors.cellHover)
            surface.DrawRect(0, 0, w, h)
        end
        local def = CARGO.Items.Get(line.entry.id)
        local name = (def and def.name or line.entry.id)
            .. (line.count > 1 and (" x" .. line.count) or "")
        local unit = CARGO.Trade.PriceOfEntry(line.entry, mult) or 0
        local total = CARGO.Trade.FormatMoney(unit * line.count)

        surface.SetFont("CargoSmall")
        local priceW = surface.GetTextSize(total)
        draw.SimpleText(T.FitText(name, "CargoSmall", w - priceW - 14),
            "CargoSmall", 4, h / 2, T.Colors.text, nil, TEXT_ALIGN_CENTER)
        draw.SimpleText(total, "CargoSmall", w - 4, h / 2, T.Colors.money,
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    row.DoClick = function() CARGO.Trade.BasketRemove(side, key) end
    return row
end

-- Left column while trading: trader header + his stock grid + the Buy strip.
-- Mirrors the loot column (same grid component, §8 of the trade doc).
function CARGO.Trade.BuildStockColumn(left)
    left:DockPadding(8, 8, 8, 8)

    local header = vgui.Create("DPanel", left)
    header:Dock(TOP)
    header:SetTall(48)
    header.Paint = function(_, w, h)
        T.PaintPanel(w, h)
        local st = tradeState
        if st == nil then return end
        draw.SimpleText(st.name or "Trader", "CargoTitle", 10, 6, T.Colors.text)
        -- the spread, spelled out: what he pays and what he charges (§5)
        local spread = string.format("Buys at %d%% · sells at %d%%",
            math.Round((st.buyMult or 0) * 100), math.Round((st.sellMult or 0) * 100))
        draw.SimpleText(spread, "CargoSmall", 10, 28, T.Colors.textDim)
        if st.moneyText then
            draw.SimpleText(st.moneyText, "CargoHeading", w - 10, 14, T.Colors.money,
                TEXT_ALIGN_RIGHT)
        end
    end

    -- Buy strip: what you are taking from him (mock: the left total)
    local strip = vgui.Create("DPanel", left)
    strip:Dock(BOTTOM)
    strip:SetTall(96)
    strip:DockMargin(0, 8, 0, 0)
    strip:DockPadding(6, 22, 6, 6)
    strip.Paint = function(_, w, h)
        T.PaintPanel(w, h)
        local _, cost = CARGO.Trade.Totals()
        draw.SimpleText("BUY", "CargoSmall", 8, 4, T.Colors.textDim)
        draw.SimpleText(CARGO.Trade.FormatMoney(cost), "CargoSmall", w - 8, 4,
            T.Colors.money, TEXT_ALIGN_RIGHT)
    end

    local list = vgui.Create("DScrollPanel", strip)
    list:Dock(FILL)
    T.SkinScroll(list)
    strip.cargoList = list

    local stockGrid = CARGO.Grid.Create(left, {
        getEntries = function()
            return tradeState and tradeState.items or {}
        end,
        dragSource = "stock",
        priceOf = function(entry) return CARGO.Trade.CellPrice("buy", entry) end,
        basketOf = function(entry) return CARGO.Trade.BasketCount("buy", entry) end,
        -- left click takes the WHOLE stack (author call, 1st in-game pass: it is
        -- what STALKER does, and one round at a time is a chore). Right click is
        -- the way to a partial amount.
        onLeftClick = function(entry) CARGO.Trade.BasketAdd("buy", entry, Available(entry)) end,
        onRightClick = function(entry) CARGO.Trade.AmountMenu("buy", entry) end,
    })
    stockGrid.panel:Dock(FILL)
    stockGrid.panel:DockMargin(0, 8, 0, 0)
    stockGrid.Refresh()

    left.cargoStockGrid = stockGrid
    left.cargoBuyStrip = strip
    return stockGrid
end

-- Right column while trading: the Sell strip + the net + Cancel/Confirm.
-- Docked BOTTOM before the grid takes FILL (the frame calls it in order).
function CARGO.Trade.BuildDealBar(right)
    local bar = vgui.Create("DPanel", right)
    bar:Dock(BOTTOM)
    bar:SetTall(134)
    bar:DockMargin(0, 8, 0, 0)
    bar:DockPadding(6, 22, 6, 6)
    bar.Paint = function(_, w, h)
        T.PaintPanel(w, h)
        local _, _, gain = CARGO.Trade.Totals()
        draw.SimpleText("SELL", "CargoSmall", 8, 4, T.Colors.textDim)
        draw.SimpleText(CARGO.Trade.FormatMoney(gain), "CargoSmall", w - 8, 4,
            T.Colors.money, TEXT_ALIGN_RIGHT)
    end

    local row = vgui.Create("DPanel", bar)
    row:Dock(BOTTOM)
    row:SetTall(32)
    row:DockMargin(0, 6, 0, 0)
    row.Paint = function(_, w, h)
        local net_ = CARGO.Trade.Totals()
        -- the net, in the player's voice: what he ends up paying or getting
        local label = net_ > 0 and ("You get " .. CARGO.Trade.FormatMoney(net_))
            or net_ < 0 and ("You pay " .. CARGO.Trade.FormatMoney(-net_))
            or "Even trade"
        local col = net_ > 0 and T.Colors.money
            or net_ < 0 and T.Colors.amber
            or T.Colors.textDim
        draw.SimpleText(label, "CargoHeading", 4, h / 2, col, nil, TEXT_ALIGN_CENTER)
    end

    local function FlatButton(parent, text, accentCol, onClick)
        local btn = vgui.Create("DButton", parent)
        btn:Dock(RIGHT)
        btn:SetWide(88)
        btn:DockMargin(6, 0, 0, 0)
        btn:SetText("")
        btn.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h,
                self:IsHovered() and T.Colors.cellHover or T.Colors.panelAlt)
            surface.SetDrawColor(accentCol)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(text, "CargoText", w / 2, h / 2, accentCol,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = onClick
        return btn
    end

    FlatButton(row, "Confirm", T.Colors.money, function() CARGO.Trade.SendConfirm() end)
    FlatButton(row, "Cancel", T.Colors.textDim, function() CARGO.Trade.Cancel() end)

    local list = vgui.Create("DScrollPanel", bar)
    list:Dock(FILL)
    T.SkinScroll(list)
    bar.cargoList = list

    dealBar = bar
    return bar
end

-- Repopulates both strips from the basket (called on every refresh).
function CARGO.Trade.RefreshStrips(left)
    if tradeState == nil then return end

    if IsValid(left) and IsValid(left.cargoBuyStrip) then
        local list = left.cargoBuyStrip.cargoList
        list:Clear()
        for key, line in SortedPairs(basket.buy) do
            StripLine(list, "buy", key, line, tradeState.sellMult)
        end
    end

    if IsValid(dealBar) then
        local list = dealBar.cargoList
        list:Clear()
        for key, line in SortedPairs(basket.sell) do
            StripLine(list, "sell", key, line, tradeState.buyMult)
        end
    end
end

-- right-click on a stack: how many units into the basket
function CARGO.Trade.AmountMenu(side, entry)
    local avail = Available(entry) - CARGO.Trade.BasketCount(side, entry)
    if avail <= 1 then
        CARGO.Trade.BasketAdd(side, entry, 1)
        return
    end
    local verb = side == "buy" and "Buy" or "Sell"
    local menu = DermaMenu()
    menu:AddOption(verb .. " 1", function() CARGO.Trade.BasketAdd(side, entry, 1) end)
    menu:AddOption(verb .. " amount...", function()
        Derma_StringRequest(verb .. " how many?", "1 - " .. avail, "", function(txt)
            local n = math.floor(tonumber(txt) or 0)
            if n >= 1 then CARGO.Trade.BasketAdd(side, entry, math.min(n, avail)) end
        end)
    end)
    menu:AddOption(verb .. " all (x" .. avail .. ")", function()
        CARGO.Trade.BasketAdd(side, entry, avail)
    end)
    menu:Open()
end

-- ------------------------------------------------------------------
-- Net
-- ------------------------------------------------------------------

net.Receive(NET_TRADE_OPEN, function()
    tradeState = CARGO.Util.ReadBlob()
    if tradeState == nil then return end
    CARGO.Trade.BasketClear()
    CARGO.UI.OpenTrade()
end)

net.Receive(NET_TRADE_SYNC, function()
    local dealt = net.ReadBool()
    local snap = CARGO.Util.ReadBlob()
    if snap == nil or tradeState == nil then return end
    if snap.traderId ~= tradeState.traderId then return end
    tradeState = snap
    -- a deal that WENT THROUGH empties the basket; a rejected one keeps it
    -- intact (§3) and only drops whatever went stale meanwhile
    if dealt then
        CARGO.Trade.BasketClear()
    else
        PruneBasket()
    end
    CARGO.UI.RefreshTrade()
end)
