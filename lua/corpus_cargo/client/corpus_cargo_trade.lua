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
local NET_CASH_DROP     = Corpus.Net.Register("cargo", "cash_drop")

-- Height of the basket strip on BOTH sides: the trader's Buy panel and the
-- player's Sell panel (which also carries the net + Cancel/Confirm row).
CARGO.Trade.STRIP_TALL = 134
-- Alto del footer de peso (la columna del jugador en corpus_cargo_ui.lua). El
-- trader NO tiene peso propio, así que la barra BUY crece por esto + su gap de 8
-- para que la fila de abajo quede pareja con Sell + peso (in-game 2026-07-23, W1).
CARGO.Trade.WEIGHT_FOOTER_TALL = 34

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

-- The source list behind each side: the trader's stock, or the player's grid.
local function SourceItems(side)
    if side == "buy" then return tradeState and tradeState.items or {} end
    return CARGO.ClientState and CARGO.ClientState.items or {}
end

-- How many units of this ITEM exist on that side — NOT of the clicked cell.
-- max_stack splits 240 rounds into two entries of 120 and both answer to the
-- same ref, so a basket line is an aggregate over all of them (in-game report
-- 2026-07-14: selling "all" of one stack left the twin stack unreachable).
--
-- The count itself lives in Grid (CRG-74): the loot view needs the same
-- aggregate over the container and over the player's grid, and two copies of
-- a sum are two chances to answer a different number. What is trade-specific
-- is only which LIST to count over, and that is what this adapter binds.
local function Available(side, entry)
    return CARGO.Grid.Aggregate(SourceItems(side), entry)
end

CARGO.Trade.Available = Available -- the own grid (corpus_cargo_ui.lua) needs it too

-- What ONE click moves on this side — the trade's adapter onto the module's
-- single gradation (CARGO.Grid.ClickAmount, CRG-74). It serves BOTH halves of
-- the grammar: M1 loads this much into the basket, M3 takes this much back
-- out. That is the whole point of one house — select and deselect cannot
-- drift apart if they ask the same function.
--
-- All this adds is the binding of `side` to the list the aggregate is counted
-- over. The three amounts, the keys and the reason ALT is not CTRL live in
-- corpus_cargo_grid.lua and are documented there.
--
-- SHIFT used to load `Available`, the aggregate over every entry answering to
-- the ref, so one click on one x120 cell of 9x19 loaded all 800 rounds the
-- player was carrying and the deal jumped from a magazine to the whole
-- reserve. The fix (roadmap #67) is NOT to name the clicked entry: stacks of
-- the same id and condition are FUNGIBLE (120 rounds of 9x19 are 120 rounds of
-- 9x19 whichever cell they were drawn in), so there is nothing to name and
-- nothing would be gained by naming it. What the cell has to send is the
-- QUANTITY it shows. Clicking the twin cell adds ITS 120 on top — which is how
-- both stacks stay reachable, the very thing the aggregate was introduced for
-- on 2026-07-14. The aggregate stays as the CAP (BasketAdd's `room`) and as
-- ALT+SHIFT.
function CARGO.Trade.ClickAmount(side, entry)
    return CARGO.Grid.ClickAmount(entry, Available(side, entry))
end

function CARGO.Trade.BasketAdd(side, entry, count)
    if tradeState == nil then return end
    local def = CARGO.Items.Get(entry.id)
    if not CARGO.Trade.IsTradeable(def) then
        chat.AddText(T.Colors.amber, "[Cargo] ", T.Colors.text,
            (def and def.name or entry.id) .. " has no price: it cannot be traded.")
        return
    end

    -- GATE 1 of 5 seen from the CLIENT (roadmap #43, CRG-76). The rule is the
    -- server's and it stands there too (Trade.Confirm -> ResolveSide): this is
    -- the half the author asked for by name — "cuando apretas en el al vender
    -- no te lo permite". Refusing only here would leave a hand-made intent
    -- through; refusing only on the server would leave the player clicking a
    -- cell that does nothing with no idea why. Both, and the server governs.
    -- It reads `entry.fav` off the snapshot, so there is no second source of
    -- truth on this side to drift from the record.
    if side == "sell" and entry.fav then
        chat.AddText(T.Colors.amber, "[Cargo] ", T.Colors.text,
            (def and def.name or entry.id) .. " is a favorite: unmark it before selling it.")
        return
    end

    local lines = Side(side)
    local key = CARGO.Trade.RefKey(entry)
    local line = lines[key]
    local have = line and line.count or 0
    local room = Available(side, entry) - have
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

-- M3, the DESELECT half of the grammar (CRG-74, roadmap #69). It takes off the
-- basket what M1 put on, with the SAME three amounts — the caller hands the
-- count, and the count comes from ClickAmount above, so there is no second
-- gradation to keep in step.
--
-- Keyed and not by entry because the row of the strip has no cell behind it:
-- a line can be the sum of clicks on several twin cells, and what it shows is
-- the line. Falling to zero DELETES the line instead of leaving an x0 sitting
-- in the strip, so "deselect it all" and "click the row" land on the same
-- state — the basket is client-side intent (§3) and an empty intent is no
-- intent.
function CARGO.Trade.BasketTake(side, key, count)
    local lines = Side(side)
    local line = lines[key]
    if line == nil then return end

    line.count = line.count - math.max(1, math.floor(count or 1))
    if line.count <= 0 then lines[key] = nil end
    CARGO.UI.RefreshTrade()
end

function CARGO.Trade.BasketRemove(side, key)
    Side(side)[key] = nil
    CARGO.UI.RefreshTrade()
end

function CARGO.Trade.BasketClear()
    basket.buy, basket.sell = {}, {}
    basket.money = 0
end

-- ------------------------------------------------------------------
-- The money-only line (§7, slice 2).
--
-- It is NOT a line of the buy/sell tables and that is deliberate: those are
-- keyed by RefKey and every path that walks them —PruneBasket, the strips, the
-- click grammar— assumes an entry with a def behind it. Money has no ref, no
-- def and no count, so it rides beside them as a single number. A fake entry
-- with id = "money" would have to be special-cased in every one of those walks.
-- ------------------------------------------------------------------

function CARGO.Trade.BasketMoney()
    return basket.money or 0
end

function CARGO.Trade.SetBasketMoney(amount)
    local n = math.floor(tonumber(amount) or 0)
    basket.money = math.max(n, 0)
    CARGO.UI.RefreshTrade()
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
    -- The offer is money leaving, so it rides with the COST — the same side of
    -- the net the server puts it on. Showing it anywhere else would make the
    -- deal bar and the Confirm disagree about a number the player is reading.
    cost = cost + (basket.money or 0)
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
    local payload = { traderId = tradeState.traderId, buy = {}, sell = {},
        money = basket.money or 0 }
    for _, line in pairs(basket.buy) do
        payload.buy[#payload.buy + 1] = { ref = line.ref, count = line.count }
    end
    for _, line in pairs(basket.sell) do
        payload.sell[#payload.sell + 1] = { ref = line.ref, count = line.count }
    end
    -- a basket that is nothing but money IS a deal (§7: handing cash over), so
    -- the emptiness test has to count it or Confirm becomes unreachable for it
    if #payload.buy == 0 and #payload.sell == 0 and payload.money == 0 then return end

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

-- ------------------------------------------------------------------
-- The `$` button of the header (§7). The hook has been cabled in
-- corpus_cargo_ui.lua since the slice 1 header was built, waiting for this
-- function to exist; until it did, the button said so in chat.
--
-- ONE button, TWO meanings, and the state decides which — that IS the design
-- (§7): in Solo you drop cash into the world, in Trade you offer it across the
-- deal. There is deliberately no way to DROP while the trade screen is open:
-- the button is taken by the offer, and inventing a second gesture for it would
-- be a route the design never described.
--
-- The amount always comes from a PROMPT and never from the click grammar of
-- the grid (author call 2026-08-23). A click that drops a quarter of your
-- wallet without asking is expensive to undo, and money is the one thing where
-- an exact number is the normal ask.
-- ------------------------------------------------------------------
function CARGO.Trade.MoneyButton(state)
    if state == "trade" then
        if tradeState == nil then return end
        T.Prompt("Offer money", "How much do you put in?",
            tostring(CARGO.Trade.BasketMoney()), function(text)
                CARGO.Trade.SetBasketMoney(tonumber(text))
            end)
        return
    end

    -- Solo (and Loot: the button lives in the shared header, and dropping cash
    -- next to an open container is the same gesture as dropping it anywhere).
    local cap = CARGO.Trade.cvCashBundle:GetInt() * CARGO.Trade.cvCashProps:GetInt()
    T.Prompt("Drop money",
        "How much do you drop? (up to " .. CARGO.Trade.FormatMoney(cap)
            .. " in " .. CARGO.Trade.cvCashProps:GetInt() .. " bundles)",
        "", function(text)
            local n = math.floor(tonumber(text) or 0)
            -- The client refuses the obvious nothing and lets the SERVER refuse
            -- everything else (CRG-6). It does not pre-check the wallet or the
            -- quota: both can change between typing and sending, and a client
            -- that guesses would say "no" to a drop the server would have
            -- allowed — the exact mirror of the estafa it is meant to prevent.
            if n <= 0 then return end
            net.Start(NET_CASH_DROP)
            net.WriteUInt(math.min(n, 4294967295), 32)
            net.SendToServer()
        end)
end

function CARGO.Trade.NotifyClosed()
    if tradeState == nil then return end
    net.Start(NET_TRADE_CLOSE)
    net.WriteUInt(tradeState.traderId, 16)
    net.SendToServer()
    tradeState = nil
    CARGO.Trade.BasketClear()
end

-- The SERVER closing the screen (roadmap #65). The same message now travels
-- both ways: from here it means "I closed it", from there "you are done".
--
-- ⚠ THE ORDER OF THESE THREE LINES IS THE WHOLE TRICK, and getting it wrong is
-- a net loop and a double event, not a visual glitch. Closing the frame fires
-- its `OnClose`, which calls `NotifyClosed`, which would send this very message
-- straight back — and the server would fire the entity's `OnTradeClosed` a
-- second time for a player it already evicted. Dropping `tradeState` FIRST
-- makes `NotifyClosed` hit its own early return, so the frame closes silently.
--
-- The basket is intent and holds nothing (Cargo_Trade §3), so dropping it costs
-- the player nothing that was not already his.
net.Receive(NET_TRADE_CLOSE, function()
    local traderId = net.ReadUInt(16)
    -- Not trading, or trading with somebody ELSE: nothing of ours to close.
    -- Without this the message would shut whatever frame happened to be open,
    -- including the plain inventory.
    if tradeState == nil or tradeState.traderId ~= traderId then return end
    tradeState = nil
    CARGO.Trade.BasketClear()
    CARGO.UI.CloseIfOpen()
end)

-- The basket points at entries that may have moved (bought, sold, dropped by
-- another flow). After every sync, re-resolve each line against the live
-- lists; whatever is gone leaves the basket instead of lingering as a ghost
-- line the server would reject forever.
local function PruneBasket()
    local function prune(lines, side)
        for key, line in pairs(lines) do
            local found
            for _, entry in ipairs(SourceItems(side)) do
                if CARGO.Trade.RefKey(entry) == key then found = entry break end
            end
            if found == nil then
                lines[key] = nil
            else
                line.entry = found
                line.count = math.min(line.count, Available(side, found))
            end
        end
    end
    prune(basket.buy, "buy")
    prune(basket.sell, "sell")
end

CARGO.Trade.PruneBasket = PruneBasket

-- ------------------------------------------------------------------
-- Panels. Both are built by corpus_cargo_ui.lua's frame in the trade state.
-- ------------------------------------------------------------------

-- The line seen as if it were a cell, so the row can ask the SAME gradation
-- the grid asks. `line.entry` is only the LAST cell that fed the line — a line
-- of 227 rounds built from an x120 and an x107 carries the x107 — so the count
-- has to be overridden with the line's, or SHIFT on the row would take out
-- whatever the last click happened to be instead of the line the row shows.
local function LineAsEntry(line)
    return { id = line.entry.id, condition = line.entry.condition,
        uid = line.entry.uid, count = line.count }
end

-- THE ONE DOCUMENTED EXCEPTION TO THE GRAMMAR (CRG-74, author's call
-- 2026-08-19): on the basket ROW, M1 REMOVES. Everywhere else M1 selects and
-- M3 deselects, and the reason the row is not made to follow is that a row is
-- a LIST entry, not a cell: it exists only because something is already
-- selected, and taking it out with one click is the gesture the author already
-- has in his hand. What the row GAINS is the amounts, so the vocabulary is the
-- same everywhere even where the button is not:
--
--   M1            a quarter of the stack ceiling
--   SHIFT+M1      the whole line — what one bare click used to do
--   ALT+SHIFT+M1  the whole line as well, and this is not an oversight: a
--                 basket line IS the aggregate of its ref (one line per
--                 RefKey, which is what keeps the twin stack in one deal), so
--                 there is no larger set of "all of that type" to reach for.
--                 Said out loud so no check ever claims to tell the two apart
--                 — they are the same number by construction, not by accident.
local function StripLine(parent, side, key, line, mult)
    local row = vgui.Create("DButton", parent)
    row:Dock(TOP)
    row:SetTall(20)
    row:DockMargin(0, 0, 0, 2)
    row:SetText("")
    row:SetTooltip("Click to take a quarter out · SHIFT: the whole line")
    -- what this row stands for, same idea as `cell.cargoEntry` on a tile: the
    -- row is the only panel of the module that acts on a basket line, and
    -- without a handle on it there is no way to press it from outside a mouse
    row.cargoBasketSide = side
    row.cargoBasketKey = key
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
    row.DoClick = function()
        CARGO.Trade.BasketTake(side, key,
            CARGO.Grid.ClickAmount(LineAsEntry(line), line.count))
    end
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

    -- Buy strip: what you are taking from him (mock: the left total). Same
    -- height as the Sell block on the player side (author call, 2nd in-game
    -- pass): the two strips read as one row across the screen — hence the
    -- shared STRIP_TALL, not two hand-tuned numbers that drift apart.
    local strip = vgui.Create("DPanel", left)
    strip:Dock(BOTTOM)
    -- STRIP_TALL + el footer de peso del jugador (+ su gap de 8): el trader no
    -- tiene strip de peso, así que BUY crece para igualar Sell + peso y la fila
    -- de abajo lee como una sola (in-game 2026-07-23, W1)
    strip:SetTall(CARGO.Trade.STRIP_TALL + 8 + CARGO.Trade.WEIGHT_FOOTER_TALL)
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
        -- M1 selects, M3 deselects, M2 is the menu (CRG-74). Both halves ask
        -- the same ClickAmount, so a quarter goes in with one and a quarter
        -- comes back out with the other.
        onLeftClick = function(entry)
            CARGO.Trade.BasketAdd("buy", entry, CARGO.Trade.ClickAmount("buy", entry))
        end,
        onMiddleClick = function(entry)
            CARGO.Trade.BasketTake("buy", CARGO.Trade.RefKey(entry),
                CARGO.Trade.ClickAmount("buy", entry))
        end,
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
    bar:SetTall(CARGO.Trade.STRIP_TALL)
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
        -- The money line goes LAST and only when there is one. It has to be
        -- visible and it has to be removable: an offer the player cannot see is
        -- money he confirms away without reading, and one he cannot take back
        -- would force him to cancel the whole basket to fix a typo.
        local offer = CARGO.Trade.BasketMoney()
        if offer > 0 then
            local row = list:Add("DPanel")
            row:Dock(TOP)
            row:SetTall(24)
            row:DockMargin(0, 2, 0, 0)
            row.Paint = function(_, w, h)
                draw.RoundedBox(4, 0, 0, w, h, T.Colors.panelAlt)
                draw.SimpleText("Cash offered", "CargoSmall", 6, h / 2,
                    T.Colors.amber, nil, TEXT_ALIGN_CENTER)
                draw.SimpleText(CARGO.Trade.FormatMoney(offer), "CargoSmall",
                    w - 24, h / 2, T.Colors.amber, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            local clear = vgui.Create("DButton", row)
            clear:Dock(RIGHT)
            clear:SetWide(20)
            clear:SetText("")
            clear.Paint = function(self, w, h)
                draw.SimpleText("x", "CargoSmall", w / 2, h / 2,
                    self:IsHovered() and T.Colors.amber or T.Colors.textDim,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            clear.DoClick = function() CARGO.Trade.SetBasketMoney(0) end
        end
    end
end

-- The basket verbs ALONE, as rows on a menu somebody else owns (roadmap #76) —
-- the same shape and the same reason as CARGO.Transfer.AddVerbs: the player's
-- grid while trading opens THE item menu, and this is the section it asks for.
--
-- THE AMOUNT ROWS ARE CONDITIONAL AND THE FIRST ONE IS NOT. With one unit
-- available there is nothing to ask "how many" about, but there is still
-- something to sell.
--
-- A FAVORITE KEEPS ITS "Sell 1" ROW, and that is the opposite call from the
-- favorite row on ammunition (#43) for a reason that is not symmetry: ammo can
-- NEVER be favorited, so a row would be noise; a favorite CAN be sold, right
-- after unmarking it — and the refusal names that fix out loud ("unmark it
-- before selling it"). Hiding the row would leave the player guessing why the
-- item he can see a price for has no way to sell it.
function CARGO.Trade.AddVerbs(menu, side, entry)
    local avail = Available(side, entry) - CARGO.Trade.BasketCount(side, entry)
    local verb = side == "buy" and "Buy" or "Sell"
    menu:AddOption(verb .. " 1", function() CARGO.Trade.BasketAdd(side, entry, 1) end)
    if avail <= 1 then return end
    menu:AddOption(verb .. " amount...", function()
        CARGO.Theme.Prompt(verb .. " how many?", "1 - " .. avail, "", function(txt)
            local n = math.floor(tonumber(txt) or 0)
            if n >= 1 then CARGO.Trade.BasketAdd(side, entry, math.min(n, avail)) end
        end)
    end)
    menu:AddOption(verb .. " all (x" .. avail .. ")", function()
        CARGO.Trade.BasketAdd(side, entry, avail)
    end)
end

-- The STOCK column's menu (right click on the trader's side). Buy-only now
-- that the sell side goes through the item menu, and it keeps the shortcut
-- below for the reason the shortcut existed: with one unit available its menu
-- would hold a single row.
--
-- ⚠ THE ASYMMETRY IS THE POINT AND IT IS WHY THE SELL SIDE HAD TO LOSE IT.
-- Measured while writing #76: a `unique` always aggregates to 1, so on the
-- player's side this shortcut meant M2 on a rifle NEVER opened a menu — it
-- went straight into the basket, and on a FAVORITE rifle straight into the
-- refusal. That is the author's own round-trip in the screen that emits the
-- message telling him to go do it: there was no menu to hang "Remove from
-- favorites" on. Here there is nothing else to offer — the trader's stock has
-- no owner who marked it and is not in your bag to drop — so one row stays a
-- click, which is also what CRG-74 grammar reads as on a column where M1
-- already selects.
function CARGO.Trade.AmountMenu(side, entry)
    local avail = Available(side, entry) - CARGO.Trade.BasketCount(side, entry)
    if avail <= 1 then
        CARGO.Trade.BasketAdd(side, entry, 1)
        return
    end
    local menu = CARGO.Theme.Menu()
    CARGO.Trade.AddVerbs(menu, side, entry)
    menu:Open()
end

-- ------------------------------------------------------------------
-- Net
-- ------------------------------------------------------------------

-- The stock column shows what the TRADER has, which the buyer may never have
-- held: captured-weapon defs are server-side only and ride the snapshot.
net.Receive(NET_TRADE_OPEN, function()
    tradeState = CARGO.Util.ReadBlob()
    if tradeState == nil then return end
    CARGO.Items.AbsorbDefs(tradeState)
    CARGO.Trade.BasketClear()
    CARGO.UI.OpenTrade()
end)

net.Receive(NET_TRADE_SYNC, function()
    local dealt = net.ReadBool()
    local snap = CARGO.Util.ReadBlob()
    if snap == nil or tradeState == nil then return end
    if snap.traderId ~= tradeState.traderId then return end
    CARGO.Items.AbsorbDefs(snap)
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
