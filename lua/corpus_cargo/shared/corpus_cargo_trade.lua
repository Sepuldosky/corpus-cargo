-- corpus_cargo_trade.lua — trade price math (SHARED)
-- Cargo_Trade_Arquitectura.md §4 (price = value x condition x spread) and §5
-- (spread config). Pure functions, no state: the SERVER is the authority on
-- price (it recomputes every line at Confirm and never trusts a client total),
-- but the CLIENT needs the same math to render the price of a cell and the
-- running total of the basket. One implementation, both realms.

local CARGO = Corpus.GetModule("cargo")

CARGO.Trade = CARGO.Trade or {}

-- §5 default spread: the trader buys at half and sells at full value. A
-- trader entity (or a player-trader, slice 3) overrides its own pair.
CARGO.Trade.DEFAULT_BUY_MULT  = 0.5
CARGO.Trade.DEFAULT_SELL_MULT = 1.0

-- §4 condition curve. Linear from FLOOR (a wreck still fetches something —
-- a 0-value item would be a free disposal service) up to 1.0 at 100%.
-- Items with no condition (stackables: ammo, food) always price at 1.0.
CARGO.Trade.CONDITION_FLOOR = 0.25

function CARGO.Trade.ConditionMult(condition)
    if not isnumber(condition) then return 1 end
    local c = math.Clamp(condition, 0, 100) / 100
    local floor = CARGO.Trade.CONDITION_FLOOR
    return floor + (1 - floor) * c
end

-- §4: an item with no `value` is NOT tradeable — it shows no price and the
-- server refuses to move it across a trade (it can still be looted/dropped).
function CARGO.Trade.IsTradeable(def)
    return istable(def) and isnumber(def.value) and def.value > 0
end

-- ------------------------------------------------------------------
-- Roadmap #61 — the economy knobs. A GLOBAL `cargo_value_mult` plus one
-- `cargo_value_mult_<category>` per category (built by Items.RegisterCategory,
-- which is what makes the OPEN category set work — see the block there). They
-- COMPOSE MULTIPLICATIVELY: food x10 with global x2 is x20, not x12.
--
-- They multiply the `value` and NOT the price, which in this repo are two
-- different things. Consequences, both wanted (author call 2026-08-22):
--
--   · The spread keeps operating on the SCALED magnitude, so a trader's
--     margin stays a percentage of what the thing is now worth.
--   · The knob does NOT pick a side: raising food x10 makes buying food cost
--     x10 AND selling food to the trader pay x10. The buy/sell gap is ALREADY
--     the spread's job (buy_mult/sell_mult); a knob that moved one side would
--     be a SECOND spread, with two dials fighting over the same thing.
--
-- REPLICATED is not optional, for the reason written in items.lua: the client
-- paints with this very function and the server charges with it.
-- ------------------------------------------------------------------
local cvGlobal = CreateConVar("cargo_value_mult", "1",
    bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
    "Global price multiplier over every item value (composes with the per-category ones)", 0)

-- The multiplier that applies to ONE def's `value`, by its category.
--
-- THE one house of the composition, and every `value` that enters a price
-- goes through it: the base of the item AND each attachment bolted to it. That
-- second half is not decoration — an att is priced by ITS OWN category, so a
-- $100 scope is a $1000 scope with `cargo_value_mult_optics 10` whether it sits
-- loose in the grid or mounted on a rifle. Scaling a mounted att by the GUN's
-- category instead would let mounting launder the multiplier.
function CARGO.Trade.ValueMult(def)
    local m = cvGlobal:GetFloat()
    local cv = istable(def) and CARGO.Items.CategoryMultCvar(def.category) or nil
    if cv ~= nil then m = m * cv:GetFloat() end
    return m
end

-- price of ONE unit, rounded to whole currency (never below 1: a rounding
-- floor of 0 would turn cheap stacks into free money on the buy side)
--
-- The category knob composes into the SAME `m` as the spread on purpose: the
-- `m <= 0` guard right below already means "not for sale" (it is the owner of
-- that reading in this repo — see IsTradeable, absence of `value`), and it
-- runs BEFORE the max(1, ...), so a category at 0 is taken off the market for
-- free and there is ONE rule instead of two. A second rule for the same zero
-- is what the roadmap entry asked for on a false premise (fixed there).
function CARGO.Trade.UnitPrice(def, condition, mult)
    if not CARGO.Trade.IsTradeable(def) then return nil end
    local m = (isnumber(mult) and mult or 1) * CARGO.Trade.ValueMult(def)
    if m <= 0 then return nil end
    local p = def.value * CARGO.Trade.ConditionMult(condition) * m
    return math.max(1, math.floor(p + 0.5))
end

-- Condition behind an entry, whatever shape it comes in: a client snapshot
-- entry carries the instance blob, a stack carries its own condition field.
-- (Server callers hand the blob in the same field — see Trade.EntryOf.)
function CARGO.Trade.ConditionOfEntry(entry)
    if not istable(entry) then return nil end
    if istable(entry.blob) and isnumber(entry.blob.condition) then
        return entry.blob.condition
    end
    if isnumber(entry.condition) then return entry.condition end
    return nil
end

-- What is bolted onto a weapon is worth what it is worth (roadmap #53, author
-- call 2026-07-30): selling a rifle with an expensive scope has to pay for the
-- scope. The att does NOT pay the gun's condition — attachments have no
-- condition of their own in ARC9 and none in Cargo (§10.1), so a $100 scope on
-- a wreck is still a $100 scope. The spread DOES apply: it is the trader's
-- margin, not wear.
--
-- Pure, and shared on purpose: the server is the authority (CRG-18) and the
-- client paints with the SAME function, so a mounted att can never make the
-- two disagree.
function CARGO.Trade.AttsValue(atts)
    if not istable(atts) then return 0 end
    local total = 0
    for _, node in ipairs(atts) do
        if istable(node) and isstring(node.att) then
            local def = CARGO.Items.Get(CARGO.ARC9.ItemId(node.att))
            -- an att with no value is not "free": ausencia = no está a la
            -- venta (CRG-18), so it simply adds nothing
            -- Each att pays ITS OWN category knob (#61) — see Trade.ValueMult:
            -- the sum this returns is already scaled, and the caller applies
            -- only the spread on top.
            if istable(def) and isnumber(def.value) then
                total = total + def.value * CARGO.Trade.ValueMult(def)
            end
            total = total + CARGO.Trade.AttsValue(node.sub)
        end
    end
    return total
end

-- unit price of a snapshot/record entry under a given multiplier
function CARGO.Trade.PriceOfEntry(entry, mult)
    if not istable(entry) then return nil end
    local base = CARGO.Trade.UnitPrice(CARGO.Items.Get(entry.id),
        CARGO.Trade.ConditionOfEntry(entry), mult)
    if base == nil then return nil end -- not for sale: the atts do not make it so

    local atts = istable(entry.blob) and entry.blob.atts or nil
    if not istable(atts) then return base end

    local m = isnumber(mult) and mult or 1
    local extra = CARGO.Trade.AttsValue(atts) * m
    return base + math.floor(extra + 0.5)
end

-- Stable key of a ref/entry, so client and server agree on what "the same
-- line" is: uniques are their uid; stacks are id + condition (the same
-- identity the inventory uses to merge stacks — no laundering of wear).
function CARGO.Trade.RefKey(ref)
    if not istable(ref) then return "?" end
    if ref.uid ~= nil then return "u:" .. ref.uid end
    return "s:" .. tostring(ref.id) .. "|" .. tostring(ref.condition)
end

-- ------------------------------------------------------------------
-- Persona: cosmetic profile a CONTENT addon hangs on the default trader —
-- model, idle sequences and voice lines. Same substitution spirit as
-- Items.SetModel: Cargo stays generic (no persona = silent citizen on plaza
-- idles); corpus-stalker registers Sidorovich from outside. Shape (all
-- fields optional):
--   { name, model, radius, wait_interval, idles = { "seq", ... },
--     sounds = { greet_first / greet / wait / bye / trade_open_first /
--                trade_open / trade_done = { "path/relative/to/sound.ogg", ... } } }
-- Sound paths must be PRE-FILTERED by the registrar (file.Exists): the bank
-- is unversioned (COR-17 side) and a path that never mounted must not play.
-- Shared so a content addon can call it from either realm; only the server
-- entity reads it.
-- ------------------------------------------------------------------

function CARGO.Trade.SetDefaultPersona(persona)
    CARGO.Trade._defaultPersona = istable(persona) and persona or nil
end

function CARGO.Trade.GetDefaultPersona()
    return CARGO.Trade._defaultPersona
end

-- Money label. The provider interface (§6 of Cargo_Architecture) lives on the
-- SERVER, so the client cannot ask it to format a number — but every price tag
-- and basket total in the trade screen is a number the client renders. Server
-- side this delegates to the active provider (the authority); client side it
-- mirrors the native USD format.
-- DEBT (declared): with a custom provider (DarkRP) whose format differs, the
-- client's price LABELS would read in USD shape while the wallet reads in the
-- provider's — the numbers are still the provider's, only the decoration
-- differs. The honest fix is a provider-supplied format string in the snapshot;
-- it lands the day a non-USD provider actually shows up.
function CARGO.Trade.FormatMoney(amount)
    if SERVER and CARGO.Money ~= nil then
        return CARGO.Money.Format(amount)
    end
    local neg = amount < 0
    local s = tostring(math.floor(math.abs(amount)))
    local grouped = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (neg and "-$" or "$") .. grouped
end
