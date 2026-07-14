-- corpus_cargo_trade.lua — traders, trade sessions and the atomic basket (SERVER)
-- Cargo_Trade_Arquitectura.md §2 (inventory-on-entity), §3 (basket + confirm),
-- §4/§5 (price and spread), §10 (example NPC trader).
--
-- INVENTORY-ON-ENTITY IS NOT NEW HERE. §2 of the trade doc asks for a generic
-- "inventory hanging off an entity"; Cargo already has exactly that and it is
-- battle-tested: Containers.Attach (§8 of Cargo_Architecture) gives an entity
-- an item list, a capacity, persistence by key and the spill-on-remove rule.
-- A trader is a CONTAINER WITH A PRICE LAYER, not a second inventory system —
-- building a parallel one would leave the corpse-loot cross (Cortex, §9) with
-- two primitives to choose from.
--
-- What this file adds on top of that storage:
--   · the spread (buy_mult / sell_mult) and the trader's own wallet
--   · a SESSION (who is looking at which trader) with its own net channel:
--     the container's transfer/takeall net is deliberately NOT wired to a
--     trader — nothing crosses a trader except through Confirm.
--   · the atomic basket: validate EVERYTHING, then move. There is no rollback
--     path because nothing mutates until every check has passed.

local CARGO = Corpus.GetModule("cargo")

CARGO.Trade = CARGO.Trade or {}
CARGO.Trade._traders = CARGO.Trade._traders or {}

local NET_TRADE_OPEN    = Corpus.Net.Register("cargo", "trade_open")
local NET_TRADE_SYNC    = Corpus.Net.Register("cargo", "trade_sync")
local NET_TRADE_CLOSE   = Corpus.Net.Register("cargo", "trade_close")
local NET_TRADE_CONFIRM = Corpus.Net.Register("cargo", "trade_confirm")

local USE_RANGE = 160 -- same reach the container session uses

-- ------------------------------------------------------------------
-- Attach: turns any entity into a trader. Public contract.
-- opts: { name, buy_mult, sell_mult, money = n | nil (bottomless),
--         persistKey, stock = { { id = , count = } , ... } }
-- The stock list only seeds an EMPTY trader (first spawn / no save).
-- ------------------------------------------------------------------

function CARGO.Trade.AttachTrader(ent, opts)
    if not IsValid(ent) then
        error("Cargo.Trade.AttachTrader: invalid entity", 2)
    end
    if ent.CargoTrader ~= nil then return ent.CargoTrader end
    opts = opts or {}

    -- storage, persistence and the spill-on-remove rule come from the
    -- container primitive; capacity is nil (a trader's stock is not weight-capped)
    local cont = CARGO.Containers.Attach(ent, {
        name = opts.name or "Trader",
        capacity = nil,
        persistKey = opts.persistKey,
    })

    local trader = {
        cont = cont,
        ent = ent,
        name = opts.name or "Trader",
        buyMult = isnumber(opts.buy_mult) and opts.buy_mult or CARGO.Trade.DEFAULT_BUY_MULT,
        sellMult = isnumber(opts.sell_mult) and opts.sell_mult or CARGO.Trade.DEFAULT_SELL_MULT,
        money = opts.money, -- nil = bottomless (an NPC that always can pay)
        persistKey = opts.persistKey,
        viewers = {},
    }

    -- the wallet persists next to the stock when the trader is persistent
    if isstring(trader.persistKey) then
        local saved = Corpus.Data.Load("cargo", "trader_" .. trader.persistKey)
        if istable(saved) and isnumber(saved.money) then trader.money = saved.money end
    end

    -- seed the demo/initial stock only when the container came up empty
    if #cont.items == 0 and istable(opts.stock) then
        for _, line in ipairs(opts.stock) do
            local def = CARGO.Items.Get(line.id or "")
            if def == nil then
                Corpus.Log("cargo", "Trade: stock desconocido '" .. tostring(line.id) .. "', ignorado")
            elseif def.class == "stackable" then
                cont.items[#cont.items + 1] = {
                    id = def.id, count = math.max(math.floor(line.count or 1), 1),
                }
            else
                for _ = 1, math.max(math.floor(line.count or 1), 1) do
                    local uid = CARGO.Instances.Create(def.id, line.seed)
                    cont.items[#cont.items + 1] = { id = def.id, uid = uid }
                end
            end
        end
    end

    ent.CargoTrader = trader
    CARGO.Trade._traders[cont.id] = trader

    ent:CallOnRemove("corpus_cargo_trader", function()
        CARGO.Trade._traders[cont.id] = nil
    end)

    return trader
end

local function SaveTrader(trader)
    if not isstring(trader.persistKey) then return end
    Corpus.Data.Save("cargo", "cont_" .. trader.persistKey, { items = trader.cont.items })
    Corpus.Data.Save("cargo", "trader_" .. trader.persistKey, { money = trader.money })
end

-- ------------------------------------------------------------------
-- Snapshot: the stock as the client sees it, each line already priced at
-- what the PLAYER WOULD PAY (sell_mult). The client re-derives the same
-- number with the shared math for its basket total; the server recomputes
-- it again at Confirm and only its number counts (§3).
-- ------------------------------------------------------------------

local function StockEntrySnapshot(entry)
    if entry.uid then
        return { id = entry.id, uid = entry.uid, blob = CARGO.Instances.Get(entry.uid) }
    end
    return { id = entry.id, count = entry.count or 1, condition = entry.condition }
end

local function Snapshot(trader)
    local snap = {
        traderId = trader.cont.id,
        name = trader.name,
        buyMult = trader.buyMult,
        sellMult = trader.sellMult,
        money = trader.money,
        moneyText = trader.money and CARGO.Money.Format(trader.money) or nil,
        items = {},
    }
    for _, entry in ipairs(trader.cont.items) do
        local e = StockEntrySnapshot(entry)
        e.price = CARGO.Trade.PriceOfEntry(e, trader.sellMult)
        snap.items[#snap.items + 1] = e
    end
    return snap
end

-- dealtFor: the player whose Confirm just executed. Only HIS client empties the
-- basket; a failed confirm re-syncs with dealt = false and the basket survives
-- intact, which is what §3 means by "rollback limpio".
local function SyncViewers(trader, dealtFor)
    local snap = Snapshot(trader)
    for ply in pairs(trader.viewers) do
        if IsValid(ply) then
            net.Start(NET_TRADE_SYNC)
            net.WriteBool(ply == dealtFor)
            CARGO.Util.WriteBlob(snap)
            net.Send(ply)
        else
            trader.viewers[ply] = nil
        end
    end
end

function CARGO.Trade.OpenFor(ply, ent)
    if not IsValid(ply) or not IsValid(ent) or ent.CargoTrader == nil then return end
    local trader = ent.CargoTrader
    if ply:GetPos():DistToSqr(ent:GetPos()) > USE_RANGE * USE_RANGE then return end

    trader.viewers[ply] = true
    net.Start(NET_TRADE_OPEN)
    CARGO.Util.WriteBlob(Snapshot(trader))
    net.Send(ply)
    CARGO.Inventory.Sync(ply) -- the right half of the trade screen
end

local function ViewedTrader(ply, traderId)
    local trader = CARGO.Trade._traders[traderId]
    if trader == nil or not trader.viewers[ply] then return nil end
    if not IsValid(trader.ent)
        or ply:GetPos():DistToSqr(trader.ent:GetPos()) > USE_RANGE * USE_RANGE then
        return nil
    end
    return trader
end

-- ------------------------------------------------------------------
-- The basket (§3). A line is { ref, count }; the server resolves each ref
-- against the live source, prices it, and only then moves anything.
-- ------------------------------------------------------------------

local function MatchesRef(entry, ref)
    if ref.uid ~= nil then return entry.uid == ref.uid end
    return entry.uid == nil and entry.id == ref.id and entry.condition == ref.condition
end

-- Removal is BY IDENTITY, never by a stored index: the moment one line is
-- removed every later index in that list shifts, and a two-unique basket
-- would then delete the wrong entry (or nil).
local function RemoveEntry(list, entry)
    for i = #list, 1, -1 do
        if list[i] == entry then
            table.remove(list, i)
            return true
        end
    end
    return false
end

-- stacks that a basket drained to zero
local function DropEmptyStacks(list)
    for i = #list, 1, -1 do
        local e = list[i]
        if e.uid == nil and (e.count or 1) <= 0 then table.remove(list, i) end
    end
end

-- an entry in "priceable" shape (the blob is what carries condition)
local function Priceable(entry)
    if entry.uid then
        return { id = entry.id, uid = entry.uid, blob = CARGO.Instances.Get(entry.uid) }
    end
    return { id = entry.id, count = entry.count, condition = entry.condition }
end

local function EntryUnitWeight(entry)
    if entry.uid then return CARGO.Instances.WeightOf(entry.uid) end
    local def = CARGO.Items.Get(entry.id)
    return istable(def) and def.weight or 0
end

-- A stack ref (id + condition) does NOT name one entry: `max_stack` splits a
-- pile of 240 SMG rounds into TWO entries of 120, and both answer to the same
-- ref. In-game report 2026-07-14: the basket could only ever take one of them
-- ("Sell all" on 120 left the other 120 unreachable). So a stack LINE is an
-- AGGREGATE over every entry that matches the ref — that is the logical item
-- the player sees, and the cells all light amber together because they are one
-- line, not several.
local function MatchingEntries(list, ref)
    local out, total = {}, 0
    for _, entry in ipairs(list) do
        if MatchesRef(entry, ref) then
            out[#out + 1] = entry
            total = total + (entry.uid and 1 or (entry.count or 1))
        end
    end
    return out, total
end

-- Resolves one side of the basket into concrete, priced, weighed lines.
-- Returns lines, total, weight or nil, error — the error is the player-facing
-- reason (voice of interface, §3: "the trader no longer has that", not "nil").
local function ResolveSide(lines, listOf, source, mult)
    local out, total, weight = {}, 0, 0
    local seen = {}
    local list = listOf(source)

    for _, line in ipairs(lines or {}) do
        local ref = line.ref
        if not istable(ref) then return nil, "Malformed basket." end

        local key = CARGO.Trade.RefKey(ref)
        if seen[key] then return nil, "Duplicate line in the basket." end
        seen[key] = true

        local entries, available = MatchingEntries(list, ref)
        if #entries == 0 then return nil, "An item in the basket is gone." end

        local first = entries[1]
        local def = CARGO.Items.Get(first.id)
        local unit = CARGO.Trade.IsTradeable(def) and CARGO.Trade.UnitPrice(def,
            CARGO.Trade.ConditionOfEntry(Priceable(first)), mult) or nil
        if unit == nil then
            return nil, (def and def.name or first.id) .. " cannot be traded."
        end

        -- what actually moves, spread across the entries that back the line
        local count = math.Clamp(math.floor(line.count or 1), 1, available)
        local parts, left = {}, count
        for _, entry in ipairs(entries) do
            if left <= 0 then break end
            local take = entry.uid and 1 or math.min(entry.count or 1, left)
            parts[#parts + 1] = { entry = entry, take = take }
            left = left - take
        end

        total = total + unit * count
        weight = weight + EntryUnitWeight(first) * count
        out[#out + 1] = {
            id = first.id, condition = first.condition,
            uid = first.uid, parts = parts, count = count, unit = unit,
        }
    end

    return out, total, weight
end

-- ------------------------------------------------------------------
-- Confirm: validate everything, then move. Atomic by construction (§3).
-- ------------------------------------------------------------------

function CARGO.Trade.Confirm(ply, trader, basket)
    local rec = CARGO.Inventory.GetRecord(ply)

    -- BUY: what the player takes from the stock, priced with the trader's sell_mult
    local buys, cost = ResolveSide(basket.buy,
        function(t) return t.cont.items end, trader, trader.sellMult)
    if buys == nil then return false, cost end

    -- SELL: what the player hands over, priced with the trader's buy_mult
    local sells, gain = ResolveSide(basket.sell,
        function(r) return r.items end, rec, trader.buyMult)
    if sells == nil then return false, gain end

    if #buys == 0 and #sells == 0 then return false, "The basket is empty." end

    local net_ = gain - cost

    -- money: the player never ends up in the red (§3)
    if net_ < 0 then
        local have = CARGO.Money.Get(ply)
        if have < -net_ then
            return false, "Not enough money: you're "
                .. CARGO.Money.Format(-net_ - have) .. " short."
        end
    end

    -- the trader's wallet is finite unless it declared none (§10 demo NPC
    -- runs bottomless; a real trader can be drained)
    if net_ > 0 and isnumber(trader.money) and trader.money < net_ then
        return false, "The trader can't afford that: he only has "
            .. CARGO.Money.Format(trader.money) .. "."
    end

    -- WEIGHT IS NOT A GATE HERE (author call, 1st in-game pass 2026-07-14 —
    -- amends §3, which listed it as a validation). Buying is a deliberate act:
    -- refusing the deal because the player would walk out overloaded turns the
    -- trader into a nanny. He CAN buy past his capacity and leave overloaded —
    -- and the weight curve (§5 of Cargo_Architecture) already charges him for
    -- it in movement speed. The carry limit still governs what he PICKS UP off
    -- the floor; what he pays for is his problem.
    -- (weightIn/weightOut stay resolved above: the money and stock checks are
    -- the atomic ones, and slice 2's cash lines will read them.)

    -- ---------------- everything validated: now it moves ----------------

    -- BUYS FIRST, and out of the stock list before the sells go in: otherwise a
    -- basket that sells 30 rounds of 9mm and buys 30 rounds of the same stack
    -- could buy back the very rounds it just sold (the sold stack merges into
    -- the stock line the buy resolved against).
    for _, line in ipairs(buys) do
        if line.uid then
            RemoveEntry(trader.cont.items, line.parts[1].entry)
            CARGO.Inventory.GiveEntry(ply, { id = line.id, uid = line.uid }, true)
        else
            -- the line may be backed by SEVERAL stock stacks (max_stack splits
            -- them): drain each of them by its share
            for _, part in ipairs(line.parts) do
                part.entry.count = (part.entry.count or 1) - part.take
            end
            -- skipCap: weight is not a gate on a purchase (see above). Without
            -- it, GiveEntry would refuse the line and the deal would silently
            -- half-execute — exactly what the atomic rule forbids.
            CARGO.Inventory.GiveEntry(ply,
                { id = line.id, count = line.count, condition = line.condition }, true)
        end
    end
    DropEmptyStacks(trader.cont.items)

    -- sold items leave the player and land in the stock (a trader RESELLS what
    -- he buys — that is what makes the spread readable in play)
    for _, line in ipairs(sells) do
        if line.uid then
            RemoveEntry(rec.items, line.parts[1].entry)
            trader.cont.items[#trader.cont.items + 1] = { id = line.id, uid = line.uid }
        else
            for _, part in ipairs(line.parts) do
                part.entry.count = (part.entry.count or 1) - part.take
            end
            local left = line.count
            local maxStack = (CARGO.Items.Get(line.id) or {}).max_stack or math.huge
            -- top up the stock's own stacks first, then spill into new ones:
            -- the trader's list obeys the same max_stack the inventory does
            for _, stock in ipairs(trader.cont.items) do
                if left <= 0 then break end
                if stock.uid == nil and stock.id == line.id
                    and stock.condition == line.condition
                    and (stock.count or 1) < maxStack then
                    local room = maxStack - (stock.count or 1)
                    local put = math.min(room, left)
                    stock.count = (stock.count or 1) + put
                    left = left - put
                end
            end
            while left > 0 do
                local put = math.min(left, maxStack)
                trader.cont.items[#trader.cont.items + 1] = {
                    id = line.id, count = put, condition = line.condition,
                }
                left = left - put
            end
        end
    end
    DropEmptyStacks(rec.items)

    -- money moves last, in one step
    if net_ > 0 then
        CARGO.Money.Add(ply, net_)
        if isnumber(trader.money) then trader.money = trader.money - net_ end
    elseif net_ < 0 then
        CARGO.Money.Take(ply, -net_)
        if isnumber(trader.money) then trader.money = trader.money - net_ end
    end

    CARGO.Inventory.SaveRecord(ply)
    SaveTrader(trader)
    CARGO.Inventory.Touch(ply)
    SyncViewers(trader, ply)

    return true, net_
end

-- ------------------------------------------------------------------
-- Net
-- ------------------------------------------------------------------

net.Receive(NET_TRADE_CONFIRM, function(_, ply)
    local basket = CARGO.Util.ReadBlob()
    if not istable(basket) then return end

    local trader = ViewedTrader(ply, basket.traderId)
    if trader == nil then
        CARGO.Inventory.Notice(ply, "The trader is out of reach.")
        return
    end

    local ok, res = CARGO.Trade.Confirm(ply, trader, basket)
    if not ok then
        CARGO.Inventory.Notice(ply, res)
        SyncViewers(trader) -- the basket may have gone stale: re-show the truth
        return
    end

    local net_ = res
    local msg = net_ > 0 and ("Deal closed: you got " .. CARGO.Money.Format(net_) .. ".")
        or net_ < 0 and ("Deal closed: you paid " .. CARGO.Money.Format(-net_) .. ".")
        or "Deal closed: an even trade."
    CARGO.Inventory.Notice(ply, msg)
end)

net.Receive(NET_TRADE_CLOSE, function(_, ply)
    local traderId = net.ReadUInt(16)
    local trader = CARGO.Trade._traders[traderId]
    if trader then trader.viewers[ply] = nil end
end)

hook.Add("PlayerDisconnected", "corpus_cargo_trade_viewers", function(ply)
    for _, trader in pairs(CARGO.Trade._traders) do
        trader.viewers[ply] = nil
    end
end)
