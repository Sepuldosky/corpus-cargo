-- corpus_cargo_inventory.lua — per-player inventory (SERVER)
-- Cargo_Architecture.md §4 (equip), §7 (grid model), §12 (persistence).
--
-- Data model (persisted per player as data/corpus/cargo/inv_<steamid64>.json):
--   items  : array of grid entries
--            stack  entry: { id, count, condition? } — condition only on
--                          returned sub-slot items; stacks merge ONLY on
--                          equal condition (prevents wear laundering)
--            unique entry: { id, uid } — blob lives in CARGO.Instances
--   equip  : { [slotId] = uid } — except STACK slots (throwable, §4
--            amendment): their value is a stack entry table { id, count,
--            condition? }. Every consumer of rec.equip branches on istable().
--   quick  : { [1..4] = itemId } (bindings; JSON round-trip re-normalized)
--   belt   : { [1..6] = stack entry } — ammo belt (§16). These stacks ARE the
--            player's engine ammo reserve, mirrored per HL2 ammo type by
--            corpus_cargo_ammopool.lua. Numeric keys re-normalized like quick.
--   wallet : native money provider storage
--   instances : { [uid] = blob } — the blobs this player owns, embedded
--            (CRG-56). This file is self-contained: no entry of it points at
--            another file. The field is a RENDER of Instances._live rebuilt on
--            every save, and on load it hydrates back into _live BY REFERENCE
--            (CRG-57) — same table, never a parallel copy. Both directions go
--            through Instances.RenderOwner/HydrateOwner, the SINGLE routine
--            this record shares with the persistent container.
--
-- The server owns the inventory; the client only renders snapshots and
-- sends intents. Every mutation ends in Save + Sync + movement refresh.
--
-- EQUIPMENT SIGNALS (CRG-62, roadmap #47). Cargo broadcasts THAT an
-- equipment slot changed; what the change MEANS lives in the consumer
-- (CRG-1). Two hooks, fired only after the record is already consistent —
-- a listener reading rec.equip mid-way would see a state that never existed:
--
--   Corpus_Cargo_EquipChanged(ply, slotId, defId | nil, blob | nil)
--       every first-level slot door: Equip, Unequip and DropEquipped.
--       defId nil = the slot emptied. blob nil = the value is a stack entry
--       (throwable) or the slot emptied — a stack has no instance.
--       slotId nil = the WHOLE set was re-applied (RegiveEquipped): the
--       listener re-reads everything instead of diffing one slot. That is
--       the respawn door, and it is why a listener owning player-side state
--       does not have to hook PlayerLoadout and race the order.
--
--   Corpus_Cargo_SubSlotChanged(ply, hostUid, subId)
--       SubSlotAttach / SubSlotDetach. The host blob is already mutated.
--
-- Corpus_Cargo_BodyChanged is UNTOUCHED and still fires: its signature is
-- live contract (the roadmap #10 disguise reader). The generic signal fires
-- IN ADDITION, never in its place.

local CARGO = Corpus.GetModule("cargo")

CARGO.Inventory = CARGO.Inventory or {}
CARGO.Inventory._records = CARGO.Inventory._records or {}   -- sid64 -> record

-- Net contract (§ contrato de red): every string through the Corpus
-- primitive, never a raw AddNetworkString. Container messages live in
-- corpus_cargo_containers.lua.
local NET_OPEN      = Corpus.Net.Register("cargo", "open")
local NET_SYNC      = Corpus.Net.Register("cargo", "sync")
local NET_NOTICE    = Corpus.Net.Register("cargo", "notice")
local NET_PICKUP    = Corpus.Net.Register("cargo", "pickup")
local NET_EQUIP     = Corpus.Net.Register("cargo", "equip")
local NET_UNEQUIP   = Corpus.Net.Register("cargo", "unequip")
local NET_USE       = Corpus.Net.Register("cargo", "use")
local NET_DROP      = Corpus.Net.Register("cargo", "drop")
local NET_QUICKBIND = Corpus.Net.Register("cargo", "quickbind")
local NET_QUICKUSE  = Corpus.Net.Register("cargo", "quickuse")
local NET_AMMOGROUP = Corpus.Net.Register("cargo", "ammogroup")
local NET_SUB_ATT   = Corpus.Net.Register("cargo", "subslot_attach")
local NET_SUB_DET   = Corpus.Net.Register("cargo", "subslot_detach")
local NET_BELT_SET  = Corpus.Net.Register("cargo", "belt_set")
local NET_BELT_CLR  = Corpus.Net.Register("cargo", "belt_clear")
local NET_BELT_MOVE  = Corpus.Net.Register("cargo", "belt_move")
local NET_BELT_DROP  = Corpus.Net.Register("cargo", "belt_drop")
local NET_EQUIP_DROP = Corpus.Net.Register("cargo", "equip_drop")
local NET_SORT       = Corpus.Net.Register("cargo", "sort")
local NET_FAVORITE   = Corpus.Net.Register("cargo", "favorite")

-- Lifecycle convars (server, archived):
--   cargo_lose_on_death — death wipes the whole inventory + money (roadmap
--     #15). Default OFF: without it the inventory survives death, as before.
--   cargo_persistence — persist records to disk across sessions. 0 keeps them
--     session-only: the in-memory _records still survive respawn within a
--     session, but nothing is written to / loaded from Corpus.Data. Since the
--     blobs travel inside the record (CRG-56), 0 now really means NOTHING is
--     written — instance blobs used to leak past this gate with a file each.
local cvLoseOnDeath = CreateConVar("cargo_lose_on_death", "0", FCVAR_ARCHIVE,
    "On death, lose the entire inventory (items, equipment, quick, belt) and money")
local cvPersist = CreateConVar("cargo_persistence", "1", FCVAR_ARCHIVE,
    "Persist inventories to disk across sessions (0 = session-only, nothing written or loaded)")

-- ------------------------------------------------------------------
-- Records: load / save / normalize
-- ------------------------------------------------------------------

-- The key that says "this is the same owner", and the ONE house of that
-- question: the record file is named with it, and the cash quota (§7) counts
-- bundles by it. Public because the cash entity lives outside the module's
-- files and must not re-derive it — a second copy of this rule is how a
-- player's bundles stop counting as his after a rewrite here.
function CARGO.Inventory.OwnerKey(ply)
    -- bots have no SteamID64; they get a session-only, non-persistent key
    return ply:SteamID64() or ("bot" .. ply:EntIndex())
end

local SteamKey = CARGO.Inventory.OwnerKey

-- Every uid an OWNER can REACH: grid entries, equipped uniques (a STACK slot
-- holds a table, not a uid — §4 amendment) and, recursively, whatever hangs in
-- their sub-slots. The belt is stacks today and carries no uid; it is walked
-- anyway, in case it ever stops being stacks-only. Cycle guard: the visited
-- set, since nothing forbids a blob graph from closing on itself.
--
-- This is the single reachability primitive of CRG-56: the render
-- (Instances.RenderOwner), the prune on disconnect and anything that has to ask
-- "what does this owner carry?" all walk with it.
--
-- The parameter is an OWNER, not a player record: every list is guarded by its
-- own istable(), so a persistent container — which has `items` and nothing
-- else — walks through this untouched. That genericity is why the single
-- serializer of CRG-58's second owner needed no second walker.
function CARGO.Inventory.CollectInstances(owner)
    local seen = {}
    if not istable(owner) then return seen end

    local function visit(uid)
        if not isstring(uid) or seen[uid] then return end
        seen[uid] = true

        local blob = CARGO.Instances.Get(uid)
        if not istable(blob) or not istable(blob.subslots) then return end
        for _, entries in pairs(blob.subslots) do
            if istable(entries) then
                for _, e in ipairs(entries) do
                    if istable(e) then visit(e.uid) end
                end
            end
        end
    end

    if istable(owner.items) then
        for _, entry in ipairs(owner.items) do
            if istable(entry) then visit(entry.uid) end
        end
    end
    if istable(owner.equip) then
        for _, val in pairs(owner.equip) do
            if isstring(val) then visit(val) end
        end
    end
    if istable(owner.belt) then
        for _, entry in pairs(owner.belt) do
            if istable(entry) then visit(entry.uid) end
        end
    end

    return seen
end

function CARGO.Inventory.GetRecord(ply)
    local sid = SteamKey(ply)
    local rec = CARGO.Inventory._records[sid]
    if rec ~= nil then return rec end

    rec = cvPersist:GetBool() and Corpus.Data.Load("cargo", "inv_" .. sid) or nil
    if rec == nil then
        rec = { items = {}, equip = {}, quick = {}, belt = {}, wallet = {}, instances = {} }
    else
        -- Corpus.Data does not guarantee key types on the JSON round-trip:
        -- re-normalize the numeric quick/belt-slot keys (contract in its
        -- header).
        rec.items = istable(rec.items) and rec.items or {}
        rec.equip = istable(rec.equip) and rec.equip or {}
        rec.quick = CARGO.Util.NumberKeys(rec.quick)
        rec.belt = CARGO.Util.NumberKeys(rec.belt)
        rec.wallet = istable(rec.wallet) and rec.wallet or {}

        -- HYDRATION (CRG-56/57), the same routine the persistent container
        -- runs: the blobs came inside this file and land in _live BY REFERENCE.
        -- It runs BEFORE the legacy remaps below, which read blobs through
        -- Instances.Get (i.e. through _live).
        local arrived = CARGO.Instances.HydrateOwner(rec)

        -- Honest degradation (cites COR-5): an entry whose blob did NOT come in
        -- the file is dropped with a log — an item with no blob is never
        -- half-rendered. The drop lives here, not in HydrateOwner: only this
        -- owner knows that `equip` is one of its lists.
        for i = #rec.items, 1, -1 do
            local uid = istable(rec.items[i]) and rec.items[i].uid or nil
            if uid ~= nil and not arrived[uid] then
                Corpus.Log("cargo", "GetRecord: entrada sin blob (uid " .. tostring(uid) .. "), descartada")
                table.remove(rec.items, i)
            end
        end
        for slotId, val in pairs(rec.equip) do
            if isstring(val) and not arrived[val] then
                Corpus.Log("cargo", "GetRecord: entrada sin blob (uid " .. val .. "), descartada")
                rec.equip[slotId] = nil
            end
        end

        -- legacy slot ids from the first dev pass (pda/detector became the
        -- generic accessory slots) — remap so nothing equipped is orphaned
        if rec.equip.pda ~= nil and rec.equip.accessory1 == nil then
            rec.equip.accessory1 = rec.equip.pda
        end
        if rec.equip.detector ~= nil and rec.equip.accessory2 == nil then
            rec.equip.accessory2 = rec.equip.detector
        end
        rec.equip.pda, rec.equip.detector = nil, nil

        -- Legacy grenade faces -> canonical throwable (roadmap #32): Bloque B
        -- persisted frags/SLAMs as belt ammunition and entry 13 as a dev item;
        -- both ids died with the taxonomy. Stacks remap in place; a belt stack
        -- MOVES to the grid (a throwable can no longer hang on the belt); a
        -- pre-#32 autogen unique collapses to a 1-count stack and its blob dies.
        local legacy = CARGO.Ammo and CARGO.Ammo.LegacyThrowIds or {}
        for i = #rec.items, 1, -1 do
            local e = rec.items[i]
            local newId = legacy[e.id or ""]
            if newId ~= nil then
                if e.uid ~= nil then
                    CARGO.Instances.Delete(e.uid)
                    rec.items[i] = { id = newId, count = 1 }
                else
                    e.id = newId
                end
            end
        end
        for slotId, val in pairs(rec.equip) do
            if istable(val) and legacy[val.id or ""] then
                val.id = legacy[val.id]
            elseif isstring(val) then
                local blob = CARGO.Instances.Get(val)
                local newId = istable(blob) and legacy[blob.id or ""] or nil
                if newId ~= nil then
                    rec.equip[slotId] = nil
                    rec.items[#rec.items + 1] = { id = newId, count = 1 }
                    CARGO.Instances.Delete(val)
                end
            end
        end
        for n, entry in pairs(rec.belt) do
            local newId = legacy[entry.id or ""]
            if newId ~= nil then
                entry.id = newId
                rec.items[#rec.items + 1] = entry
                rec.belt[n] = nil
            end
        end
    end

    CARGO.Inventory._records[sid] = rec
    return rec
end

-- ------------------------------------------------------------------
-- GRID ORDER (roadmap #67)
--
-- `ord` is WHERE an entry sits in the player's grid, and it belongs to the
-- PLAYER: it survives a pickup, a drop, a relog and a map change, and only the
-- Sort button rewrites one that already exists. Before it, position was a
-- function of the CONTENTS — the client re-derived the whole order on every
-- refresh (§7 auto-sort), so nothing the player put somewhere could stay there
-- and every pickup reflowed the grid under the cursor.
--
-- `ord` is NOT an identity, and that is deliberate: the Sort button rewrites
-- every one of them at once, so an intent that named an `ord` could be
-- re-targeted by a re-sort landing between the click and the packet. That is
-- the whole reason #68 did not reuse this field for naming a cell.
--
-- `cid` IS the identity, and it is the other half of this same header (CRG-73,
-- roadmap #68): one integer per entry, minted once here and never reassigned,
-- which is what lets a click name the CELL it landed on instead of the first
-- entry that happens to match. Two things make it work, and both are
-- deliberate:
--   · Sort never touches it. It rewrites `ord` and only `ord`, so the player
--     can re-arrange his bag without invalidating an intent already in flight.
--   · The counter lives ON THE RECORD, is persisted, and only ever counts up.
--     Deriving "the highest cid plus one" from the live entries would recycle
--     the number of an entry that just left, and a recycled number is the one
--     thing that would let a stale intent fire on a cell the player never
--     clicked — the exact failure this field exists to prevent.
--
-- Two stack entries of the same id and condition stay FUNGIBLE whenever the
-- question is a QUANTITY — 120 rounds of 9x19 are 120 rounds of 9x19 whichever
-- cell they were drawn in — and that is why the trade basket and the container
-- transfer keep aggregating (#67) while the five paths that MOVE a cell resolve
-- through the `cid` (#68). Those are two different questions, not two answers
-- to one, and over there the aggregate is what keeps the twin stack reachable.
--
-- The two funnels stamp: SaveRecord (disk) and BuildSnapshot (wire). Every
-- mutation path in this file ends in one of them, which is why the ~8 places
-- that append an entry do not each have to remember.
-- ------------------------------------------------------------------

-- WHERE an entry sits. Two regimes, read off the record's own state — see the
-- header above.
local function StampOrd(rec)
    local maxOrd, stamped = 0, 0
    for _, entry in ipairs(rec.items) do
        if isnumber(entry.ord) then
            stamped = stamped + 1
            if entry.ord > maxOrd then maxOrd = entry.ord end
        end
    end
    if stamped == #rec.items then return end

    -- A record where NOBODY carries one is legacy (or brand new) and gets
    -- seeded WHOLE by the shared criterion, so the first load looks exactly
    -- like it always did — no player ever sees his bag shuffled by the
    -- upgrade. A record already in play stamps only the NEWCOMERS and puts
    -- them at the END, which is the whole of "a pickup stops moving everything
    -- else". The regime is read off the record's own state and not off a
    -- flag: a flag would have to be persisted, and a persisted flag can lie.
    if stamped == 0 then
        local seeded = {}
        for _, entry in ipairs(rec.items) do seeded[#seeded + 1] = entry end
        table.sort(seeded, CARGO.Items.AutoSortLess)
        for i, entry in ipairs(seeded) do entry.ord = i end
        return
    end

    for _, entry in ipairs(rec.items) do
        if not isnumber(entry.ord) then
            maxOrd = maxOrd + 1
            entry.ord = maxOrd
        end
    end
end

-- WHICH entry it is (CRG-73). Monotonic, persisted on the record, never reused
-- - the header above says why reuse is the failure mode this field exists to
-- prevent.
local function StampCid(rec)
    local nextCid = isnumber(rec.cidNext) and rec.cidNext or 1

    -- A record that carries cids but arrived WITHOUT its counter - a file
    -- written before this field existed, a LAN import that rebuilt its entries
    -- from scratch - must not hand out a number that is already on the table.
    -- The counter is authoritative when it is the higher of the two and the
    -- entries are when they are; taking the max of both is what makes the
    -- seeding safe from either direction.
    for _, entry in ipairs(rec.items) do
        if isnumber(entry.cid) and entry.cid >= nextCid then nextCid = entry.cid + 1 end
    end

    for _, entry in ipairs(rec.items) do
        if not isnumber(entry.cid) then
            entry.cid = nextCid
            nextCid = nextCid + 1
        end
    end
    rec.cidNext = nextCid
end

-- THE funnel. One guard, then the two independent stamps: position and identity
-- are different questions and neither reads the other.
local function StampEntries(rec)
    if not istable(rec) or not istable(rec.items) then return end
    StampOrd(rec)
    StampCid(rec)
end

-- ------------------------------------------------------------------
-- FAVORITES (roadmap #43, CRG-76)
--
-- A favorite is a flag OF THE PLAYER over an item. Not of the def — two AK-74
-- of the same def, one favorite and the other not, is precisely the case the
-- author named ("la tuya que siempre usas") — and not of the CELL either.
-- It lives in `rec.fav`, a set of keys on the record, which is why persistence
-- costs nothing: the whole record is saved and loaded (§12), so a new field on
-- it round-trips by itself.
--
-- ⭐ THE SHAPE OF THE KEY IS THE DESIGN, and it is the author's vote of
-- 2026-08-21:
--     unique     -> the uid       (that instance, exactly)
--     stackable  -> the id        (all bandages, or none)
--
-- WHY NOT PER CELL, which is the granular reading and was on the table:
-- `AddStack` MERGES on its own — same id, same condition, room under
-- `max_stack` — so a flag living on a cell is UNDEFINED the moment you pick
-- another one off the floor. Either the entry that walked in has no flag, or it
-- lands in a non-favorite cell and the favorite splits into two halves with no
-- rule governing them. There is no error and no warning in either case. Making
-- it well-defined means touching the merge, which is roadmap #73 and drags #67
-- and #70 with it. THIS SHAPE DOES NOT NEED TO: there is nothing on the entry
-- to lose, because the flag was never on the entry.
-- The honest cost, and the author was told it before he voted: you cannot have
-- 3 favorite bandages and 2 not.
--
-- The eligibility rule (no ammunition) lives in Items.CanFavorite, SHARED, so
-- the client's menu and this server's refusal cannot drift apart.
-- ------------------------------------------------------------------

-- Accepts the two shapes an "item the player holds" comes in: a grid entry (or
-- a stack slot) as a table, and a bare uid string, which is what `rec.equip`
-- stores for a unique. Taking both is what lets the five gates — three of which
-- only ever see one shape — call the same function.
function CARGO.Inventory.FavoriteKey(entry)
    if isstring(entry) then
        return entry ~= "" and ("u:" .. entry) or nil
    end
    if not istable(entry) then return nil end
    if entry.uid ~= nil then return "u:" .. tostring(entry.uid) end
    if not isstring(entry.id) or entry.id == "" then return nil end
    return "i:" .. entry.id
end

-- ⭐ THE single house. The gates call THIS; not one of them re-reads `rec.fav`.
-- The whole value of the entry is that no route out of the inventory can ignore
-- a favorite, and that is a property of there being ONE predicate: the sixth
-- gate somebody writes has to come here and ask.
function CARGO.Inventory.IsFavorite(rec, entry)
    if not istable(rec) or not istable(rec.fav) then return false end
    local key = CARGO.Inventory.FavoriteKey(entry)
    return key ~= nil and rec.fav[key] == true
end

-- The def behind either shape, so eligibility can be asked about a uid too.
local function DefOfHeld(entry)
    if isstring(entry) then
        local blob = CARGO.Instances.Get(entry)
        return blob and CARGO.Items.Get(blob.id) or nil
    end
    if not istable(entry) then return nil end
    return CARGO.Items.Get(entry.id)
end

-- Drops `u:` keys whose instance no longer exists anywhere. A uid is never
-- recycled (`i<os.time()>_<counter>`: unique within a boot by the counter and
-- across boots by the clock), so a stale key cannot silently adopt another
-- item — but it would accumulate in the file forever, one per favorite weapon
-- ever destroyed.
--
-- `i:` KEYS ARE NEVER PRUNED, and that is not an omission: an id key names a
-- CLASS of item. Spending your last bandage must not forget that bandages are
-- favorites, or the mark would evaporate exactly when the stack runs out and
-- come back unmarked with the next pickup.
-- An instance held by a container or lying on the floor is still in `_live`, so
-- storing your favorite rifle in a crate keeps the mark — you moved it, you did
-- not destroy it.
function CARGO.Inventory.PruneFavorites(rec)
    if not istable(rec) or not istable(rec.fav) then return 0 end
    local dropped = 0
    for key in pairs(rec.fav) do
        local uid = isstring(key) and string.match(key, "^u:(.+)$") or nil
        if uid ~= nil and CARGO.Instances.Get(uid) == nil then
            rec.fav[key] = nil
            dropped = dropped + 1
        end
    end
    return dropped
end

-- Re-sorts the grid with the SHARED criterion, on the player's say-so. The
-- only thing in the module that rewrites an `ord` that already exists.
function CARGO.Inventory.SortGrid(ply)
    local rec = CARGO.Inventory.GetRecord(ply)
    if not istable(rec.items) then return end

    local list = {}
    for _, entry in ipairs(rec.items) do list[#list + 1] = entry end
    table.sort(list, CARGO.Items.AutoSortLess)
    for i, entry in ipairs(list) do entry.ord = i end

    CARGO.Inventory.Touch(ply)
end

function CARGO.Inventory.SaveRecord(ply)
    if not cvPersist:GetBool() then return end -- session-only mode: nothing hits disk
    local rec = CARGO.Inventory._records[SteamKey(ply)]
    if rec == nil then return end

    StampEntries(rec)

    -- RENDER (CRG-56/57), the same routine the persistent container runs:
    -- `instances` is rebuilt from scratch out of _live on every save, so a uid
    -- that stopped being referenced (dropped to the world, sold, eaten by a
    -- sub-slot detach) leaves the file on its own.
    CARGO.Instances.RenderOwner(rec)

    Corpus.Data.Save("cargo", "inv_" .. SteamKey(ply), rec)
end

-- ------------------------------------------------------------------
-- Weight / capacity
-- ------------------------------------------------------------------

local function EntryWeight(entry)
    if entry.uid then return CARGO.Instances.WeightOf(entry.uid) end
    local def = CARGO.Items.Get(entry.id)
    return (istable(def) and def.weight or 0) * (entry.count or 1)
end

function CARGO.Inventory.TotalWeight(ply)
    local rec = CARGO.Inventory.GetRecord(ply)
    local total = 0
    for _, entry in ipairs(rec.items) do
        total = total + EntryWeight(entry)
    end
    for _, val in pairs(rec.equip) do
        -- stack slot (throwable): the entry weighs like any grid stack
        total = total + (istable(val) and EntryWeight(val) or CARGO.Instances.WeightOf(val))
    end
    -- belt stacks left the grid but not the player (§15.2: carry cost is
    -- weight, wherever the stack lives)
    for _, entry in pairs(rec.belt or {}) do
        total = total + EntryWeight(entry)
    end
    return total
end

function CARGO.Inventory.Capacity(ply)
    local rec = CARGO.Inventory.GetRecord(ply)
    local backDef
    if rec.equip.back then
        local blob = CARGO.Instances.Get(rec.equip.back)
        backDef = blob and CARGO.Items.Get(blob.id) or nil
    end
    return CARGO.Weight.Capacity(backDef)
end

-- Public contract: soft-deps (Coagulant) poll this for their own effects.
function CARGO.Inventory.GetWeightFraction(ply)
    local cap = CARGO.Inventory.Capacity(ply)
    if cap <= 0 then return 0 end
    return CARGO.Inventory.TotalWeight(ply) / cap
end

local function FitsWeight(ply, extraKg)
    local cap = CARGO.Inventory.Capacity(ply)
    return CARGO.Inventory.TotalWeight(ply) + extraKg <= cap * CARGO.Weight.MAX_FRACTION
end

-- ------------------------------------------------------------------
-- Entry primitives
-- ------------------------------------------------------------------

-- Stacks merge only when both sides carry the same condition (usually nil).
-- A worn plate returned from a sub-slot must never launder into a factory
-- stack — that would be a free repair.
local function AddStack(rec, id, count, condition)
    local maxStack = CARGO.Items.MaxStack(CARGO.Items.Get(id))

    for _, entry in ipairs(rec.items) do
        if entry.uid == nil and entry.id == id and entry.condition == condition
            and (entry.count or 1) < maxStack then
            local room = maxStack - (entry.count or 1)
            local moved = math.min(room, count)
            entry.count = (entry.count or 1) + moved
            count = count - moved
            if count <= 0 then return end
        end
    end
    while count > 0 do
        local put = math.min(count, maxStack)
        rec.items[#rec.items + 1] = { id = id, count = put, condition = condition }
        count = count - put
    end
end

-- ref from the client: { uid = "..." } for uniques, { id = "...",
-- condition = n|nil } for stacks, plus `cid` when the intent names one specific
-- CELL (CRG-73, roadmap #68). Returns index, entry.
--
-- THE `cid` CONJUNCT IS THE WHOLE OF #68. A ref that carries one resolves to
-- THAT cell and to no other, and it deliberately does NOT fall back to the
-- first match: the fallback IS the bug the author reported on 2026-08-19 - drag
-- the cell that says x107 onto the belt and the belt fills with the 120 of the
-- first 9x19 entry, because the cell never travelled in the ref. Same defect,
-- other symptom: DropEntry clamped `count` to the first entry, so dropping the
-- 107 took 107 out of a 120 and left a remainder of 13 - one more item on the
-- floor than there were cells in the grid, with the total conserved.
--
-- A ref WITHOUT a cid keeps resolving against the first match, and that is not
-- a leftover: savegames, the LAN import (CRG-61) and every entry CleanStack
-- rebuilds from scratch send refs with no cid, and a ref that cannot name a
-- cell must never become unreachable.
--
-- id and condition are still matched on the way through. A `cid` alone would be
-- enough on a healthy record, and checking all three is what makes it enough on
-- an unhealthy one too: a number that somehow pointed at another item could
-- never fire.
local function FindEntry(rec, ref)
    if not istable(ref) then return nil end
    for i, entry in ipairs(rec.items) do
        if ref.uid ~= nil then
            if entry.uid == ref.uid then return i, entry end
        elseif entry.uid == nil and entry.id == ref.id and entry.condition == ref.condition
            and (ref.cid == nil or entry.cid == ref.cid) then
            return i, entry
        end
    end
    return nil
end

-- The five paths that MOVE a named cell - equip, use, drop, belt, sub-slot -
-- resolve through this instead of calling FindEntry directly. A ref that names
-- a cell and misses it must not fall back (that is #68) and must not fail
-- MUTELY either, or a click the player really did make reads as a dead button:
-- author vote 2026-08-19. The cell can legitimately be gone by the time the
-- packet lands - another path merged it, spent it or emptied it.
--
-- Returns index, entry, stale. `stale` is true ONLY when the ref did name a
-- cell, so each caller keeps its own wording for the ordinary miss instead of
-- printing two notices for one failure.
local function FindCell(ply, rec, ref)
    local idx, entry = FindEntry(rec, ref)
    if entry ~= nil then return idx, entry, false end

    local stale = istable(ref) and ref.cid ~= nil
    if stale then
        CARGO.Inventory.Notice(ply, "That stack is no longer in that cell.")
    end
    return nil, nil, stale
end

-- The intent, and it is a TOGGLE with no payload beyond the ref: a client that
-- sent "make it true" could disagree with a record that already says true, and
-- the two would drift with nothing to reconcile them. `ref.slot` names an
-- equipment slot; anything else resolves against the grid.
function CARGO.Inventory.ToggleFavorite(ply, ref)
    local rec = CARGO.Inventory.GetRecord(ply)
    if not istable(ref) then return false end

    local held
    if isstring(ref.slot) and ref.slot ~= "" then
        held = rec.equip[ref.slot]
        if held == nil then return false end
    else
        local _, entry = FindCell(ply, rec, ref)
        if entry == nil then return false end
        held = entry
    end

    if not CARGO.Items.CanFavorite(DefOfHeld(held)) then
        CARGO.Inventory.Notice(ply, "Ammunition can't be marked as a favorite.")
        return false
    end

    local key = CARGO.Inventory.FavoriteKey(held)
    if key == nil then return false end

    rec.fav = rec.fav or {}
    -- `nil` and not `false` when turning it off: the set stays clean across the
    -- JSON round-trip, and IsFavorite compares against true either way.
    rec.fav[key] = (rec.fav[key] ~= true) or nil
    CARGO.Inventory.Touch(ply)
    return true
end

-- Inserts an existing entry (from a container, drop pickup or ejection).
-- skipCap: mandatory-ejection paths must never fail on weight.
function CARGO.Inventory.GiveEntry(ply, entry, skipCap)
    if not skipCap and not FitsWeight(ply, EntryWeight(entry)) then
        return false, "too heavy"
    end
    local rec = CARGO.Inventory.GetRecord(ply)
    if entry.uid then
        rec.items[#rec.items + 1] = { id = entry.id, uid = entry.uid }
    else
        AddStack(rec, entry.id, entry.count or 1, entry.condition)
    end
    return true
end

-- ONE world-spawn path for everything that leaves (or never enters) the
-- record: the real SWEP when it is a weapon and the world gate allows it
-- — roadmap #16/#17, an ARC9 gun draws its assembled mirror on the ground
-- and no prop stand-in matches it — and the corpus_cargo_item entity
-- otherwise, which renders its own blob on Spawn. DropEntry and GiveOrDrop
-- share it so a second route cannot drift from this one.
local function SpawnDropped(pos, dropped)
    local def = CARGO.Items.Get(dropped.id)
    if dropped.uid ~= nil and istable(def)
        and isstring(def.weapon_class) and def.weapon_class ~= ""
        and istable(CARGO.Capture)
        and isfunction(CARGO.Capture.WorldGunsEnabled)
        and CARGO.Capture.WorldGunsEnabled()
        and CARGO.Capture.SpawnWorldWeapon(def.weapon_class, pos, dropped.uid) ~= nil then
        return true
    end

    local ent = ents.Create("corpus_cargo_item")
    if not IsValid(ent) then return false end
    ent.CargoEntry = dropped
    ent:SetPos(pos)
    ent:Spawn()
    return true
end

-- ------------------------------------------------------------------
-- Public contract: give / take / count (what Coagulant & Craving consume)
-- ------------------------------------------------------------------

-- Stackable: countOrSeed = number (default 1). Unique: countOrSeed =
-- optional blob seed table. Returns ok(, err | uid).
function CARGO.Inventory.GiveItem(ply, id, countOrSeed)
    local def = CARGO.Items.Get(id)
    if def == nil then return false, "unknown item: " .. tostring(id) end

    if def.class == "stackable" then
        local count = isnumber(countOrSeed) and math.max(math.floor(countOrSeed), 1) or 1
        if not FitsWeight(ply, def.weight * count) then return false, "too heavy" end
        AddStack(CARGO.Inventory.GetRecord(ply), id, count, nil)
        CARGO.Inventory.Touch(ply)
        return true
    end

    if not FitsWeight(ply, def.weight) then return false, "too heavy" end
    local uid = CARGO.Instances.Create(id, istable(countOrSeed) and countOrSeed or nil)
    local rec = CARGO.Inventory.GetRecord(ply)
    rec.items[#rec.items + 1] = { id = id, uid = uid }
    CARGO.Inventory.Touch(ply)
    return true, uid
end

-- CRG-65 — "no entra" nunca significa "se destruye" (author call 2026-07-30,
-- roadmap #53). A caller that HANDS Cargo an object it already took out of
-- somewhere else has no way to put it back: if GiveItem refuses (weight, an
-- unknown def) and the caller ignores the return, the object is gone. That is
-- CRG-9's failure mode arriving through the other door — not a flow that
-- destroys an item with occupied sub-slots, but a flow that destroys the item
-- it was handed. Two live sites had it: the ARC9 detach bridge and the ammo
-- pool mirror, and BOTH carried a comment claiming nothing was lost.
--
-- The line the author drew: REFUSING an action and saying so is fine (walk+use
-- while overweight still answers "You can't carry that" and the gun stays on
-- the floor — nothing was taken from anywhere). CONSUMING the object and
-- saying so is the bug. Only the second shape goes through here.
--
-- Returns ok, droppedToFloor(, uid). ok is false only when the def is unknown,
-- which is the one case where there is nothing to spawn either.
function CARGO.Inventory.GiveOrDrop(ply, id, countOrSeed)
    local def = CARGO.Items.Get(id)
    if def == nil then return false, false end

    local ok, extra = CARGO.Inventory.GiveItem(ply, id, countOrSeed)
    if ok then return true, false, extra end

    local dropped
    if def.class == "stackable" then
        local count = isnumber(countOrSeed) and math.max(math.floor(countOrSeed), 1) or 1
        dropped = { id = id, count = count }
    else
        dropped = { id = id,
            uid = CARGO.Instances.Create(id, istable(countOrSeed) and countOrSeed or nil) }
    end

    if not SpawnDropped(ply:EyePos() + ply:GetAimVector() * 32, dropped) then
        return false, false
    end
    return true, true, dropped.uid
end

-- Same floor, no player in the frame: a world drop re-applying its tree can
-- find an att that no longer fits, and there is nobody to hand it to. It lands
-- next to the gun instead of evaporating (CRG-65 without an owner).
function CARGO.Inventory.DropAt(pos, id, count)
    local def = CARGO.Items.Get(id)
    if def == nil or pos == nil then return false end

    local dropped
    if def.class == "stackable" then
        dropped = { id = id, count = math.max(math.floor(count or 1), 1) }
    else
        dropped = { id = id, uid = CARGO.Instances.Create(id) }
    end
    return SpawnDropped(pos, dropped)
end

function CARGO.Inventory.TakeItem(ply, id, count)
    count = math.max(math.floor(count or 1), 1)
    if CARGO.Inventory.CountItem(ply, id) < count then return false end

    local rec = CARGO.Inventory.GetRecord(ply)
    -- factory stacks (no condition) drain first, worn ones after
    for pass = 1, 2 do
        for i = #rec.items, 1, -1 do
            local entry = rec.items[i]
            local worn = entry.condition ~= nil
            if entry.uid == nil and entry.id == id and ((pass == 1 and not worn) or (pass == 2 and worn)) then
                local moved = math.min(entry.count or 1, count)
                entry.count = (entry.count or 1) - moved
                count = count - moved
                if entry.count <= 0 then table.remove(rec.items, i) end
                if count <= 0 then
                    CARGO.Inventory.Touch(ply)
                    return true
                end
            end
        end
    end
    CARGO.Inventory.Touch(ply)
    return true
end

function CARGO.Inventory.CountItem(ply, id)
    local rec = CARGO.Inventory.GetRecord(ply)
    local n = 0
    for _, entry in ipairs(rec.items) do
        if entry.uid == nil and entry.id == id then n = n + (entry.count or 1) end
    end
    return n
end

-- Presence across BOTH classes: "does the player carry at least one <id>?".
-- CountItem deliberately counts stack units only (its result feeds TakeItem's
-- stack drain), so unique items — stored as { id, uid } — are invisible to it.
-- Consumers checking presence of a unique (Coagulant's tourniquet, paid
-- in-game 2026-07-13) must ask here, not CountItem.
function CARGO.Inventory.HasItem(ply, id)
    local rec = CARGO.Inventory.GetRecord(ply)
    for _, entry in ipairs(rec.items) do
        if entry.id == id then return true end
    end
    return false
end

-- Remove ONE unique instance of `id` from the grid (and delete its blob). The
-- stack-only TakeItem/CountItem are blind to uniques (they key on entry.uid ==
-- nil), so a consumer that must actually CONSUME a unique — Coagulant OCCUPYING
-- a tourniquet while it is strapped to a limb, so one tourniquet ties one limb
-- (in-game 2026-07-23) — asks here. Returns true if one was removed.
function CARGO.Inventory.TakeUnique(ply, id)
    local rec = CARGO.Inventory.GetRecord(ply)
    for i = #rec.items, 1, -1 do
        local entry = rec.items[i]
        if entry.uid ~= nil and entry.id == id then
            table.remove(rec.items, i)
            CARGO.Instances.Delete(entry.uid)
            CARGO.Inventory.Touch(ply)
            return true
        end
    end
    return false
end

-- Public contract: instance blob equipped in a slot (Cortex reads Body to
-- resolve the apparent faction / disguise — Cargo_Architecture.md §6).
-- Stack slots (throwable) have no instance: the stack entry itself comes
-- back — it carries .id like a blob does, which is what consumers key on.
function CARGO.Inventory.GetEquipped(ply, slotId)
    local rec = CARGO.Inventory.GetRecord(ply)
    local val = rec.equip[slotId]
    if val == nil then return nil end
    if istable(val) then return val end
    return CARGO.Instances.Get(val), val
end

-- ------------------------------------------------------------------
-- Mandatory ejection (§4): before an instance is destroyed, everything
-- mounted in its sub-slots returns to the owner's inventory. A shield
-- generator is never lost as a side effect of losing the vest.
-- ------------------------------------------------------------------

function CARGO.Inventory.EjectSubSlots(ply, blob)
    if not istable(blob) or not istable(blob.subslots) then return end
    for subId, entries in pairs(blob.subslots) do
        for _, entry in ipairs(entries) do
            CARGO.Inventory.GiveEntry(ply, entry, true) -- never fails on weight
        end
        blob.subslots[subId] = nil
    end
end

-- ------------------------------------------------------------------
-- Save + sync + movement in one place: every mutation ends here.
-- ------------------------------------------------------------------

function CARGO.Inventory.Touch(ply)
    CARGO.Inventory.SaveRecord(ply)
    CARGO.Movement.Refresh(ply)
    CARGO.Inventory.Sync(ply)
end

function CARGO.Inventory.Notice(ply, text)
    net.Start(NET_NOTICE)
    net.WriteString(text)
    net.Send(ply)
end

-- On-screen "you picked up X" feed. Sends the item id (not the name): the
-- client resolves the display name from its own registered def, and for
-- captured engine weapons the autogen def rode in on the Sync that Touch()
-- queued just before — call this AFTER the give so ordering holds.
function CARGO.Inventory.NotifyPickup(ply, id, count)
    if not IsValid(ply) or not isstring(id) then return end
    net.Start(NET_PICKUP)
    net.WriteString(id)
    net.WriteUInt(math.max(count or 1, 1), 16)
    net.Send(ply)
end

-- `fav` rides HERE and nowhere else (roadmap #43). This is the single funnel
-- the fields of a grid cell are built in, so the flag reaches the client the
-- same way `cid` and `ord` do: no second net route was minted for it, and the
-- client never needs the `rec.fav` set — it only ever asks the entry it drew.
-- Only `true` is written, never `false`: the blob stays the size it was for
-- every player who has no favorites at all.
local function EntrySnapshot(rec, entry)
    local fav = CARGO.Inventory.IsFavorite(rec, entry) or nil
    if entry.uid then
        -- `w` is the EFFECTIVE weight and rides only when it differs from the
        -- def's (roadmap #58) — site 1 of the five that carry a blob
        local blob = CARGO.Instances.Get(entry.uid)
        return { id = entry.id, uid = entry.uid, ord = entry.ord, cid = entry.cid,
            fav = fav, w = CARGO.Instances.SnapWeight(blob), blob = blob }
    end
    -- `cid` rides so the client can name back the cell it drew (#68). It rides
    -- on the unique too, even though its ref is the uid: #70 addresses a DRAG
    -- by cell, and a field only some cells carry would be a second rule.
    return { id = entry.id, count = entry.count or 1, condition = entry.condition,
        ord = entry.ord, cid = entry.cid, fav = fav }
end

function CARGO.Inventory.BuildSnapshot(ply)
    local rec = CARGO.Inventory.GetRecord(ply)
    StampEntries(rec) -- the wire funnel (see StampEntries): a cell without an `ord`
                    -- would fall back to the auto-sort and drift from the rest
    -- same funnel, same reason: the favorites of instances that no longer exist
    -- anywhere would pile up in the record file forever (see PruneFavorites)
    CARGO.Inventory.PruneFavorites(rec)
    local snap = { items = {}, equip = {}, quick = rec.quick, belt = rec.belt }

    for _, entry in ipairs(rec.items) do
        snap.items[#snap.items + 1] = EntrySnapshot(rec, entry)
    end
    for slotId, val in pairs(rec.equip) do
        -- the flag rides on the equipment slots too, and it is not decoration:
        -- the author's case is "your weapon", and your weapon is EQUIPPED most
        -- of the time. Without it the slot menu would offer a Drop the server
        -- then refuses — the dead button CRG-6 exists to prevent.
        local fav = CARGO.Inventory.IsFavorite(rec, val) or nil
        if istable(val) then
            -- stack slot (throwable): count rides for the ×N badge; no blob
            snap.equip[slotId] = { id = val.id, count = val.count or 1,
                condition = val.condition, fav = fav }
        else
            local blob = CARGO.Instances.Get(val)
            if blob then
                -- site 2 of five (#58): the equipped weapon is precisely the one
                -- whose loaded rounds the author was reading off the card
                snap.equip[slotId] = { id = blob.id, uid = val, blob = blob,
                    fav = fav, w = CARGO.Instances.SnapWeight(blob) }
            end
        end
    end

    -- defs auto-generated server-side (captured engine weapons) don't exist
    -- on the client until a snapshot carries them (Items.PackDefs, which the
    -- container and the trader now call too — the client learns a def from
    -- whichever snapshot shows it first)
    CARGO.Items.PackDefs(snap, snap.items)
    CARGO.Items.PackDefs(snap, snap.equip)
    CARGO.Items.PackDefs(snap, rec.belt or {})

    local bodyDef
    if snap.equip.body then bodyDef = CARGO.Items.Get(snap.equip.body.id) end
    snap.quickUnlocked = CARGO.Slots.QuickUnlocked(bodyDef)

    local cap, base, back = CARGO.Inventory.Capacity(ply)
    snap.weight, snap.capacity, snap.capBase, snap.capBack =
        CARGO.Inventory.TotalWeight(ply), cap, base, back

    -- money: whatever provider is active formats its own value
    local okM, money = pcall(function() return CARGO.Money.Format(CARGO.Money.Get(ply)) end)
    snap.money = okM and money or "?"
    snap.moneyLabel = CARGO.Money.Label()

    -- faction/rank: Cortex owns the data, Cargo only renders (§6). Expected
    -- contract (mock-first, Cortex block pending): cortex.GetFactionInfo(ply)
    -- -> { faction = string, rank = string }. Honest degradation: no Cortex,
    -- no faction line — never a crash.
    local cortex = Corpus.GetModule("cortex")
    if cortex and isfunction(cortex.GetFactionInfo) then
        local okF, info = pcall(cortex.GetFactionInfo, ply)
        if okF and istable(info) then
            snap.faction = { name = info.faction, rank = info.rank }
        end
    end

    return snap
end

function CARGO.Inventory.Sync(ply)
    if not IsValid(ply) then return end
    net.Start(NET_SYNC)
    CARGO.Util.WriteBlob(CARGO.Inventory.BuildSnapshot(ply))
    net.Send(ply)
end

-- ------------------------------------------------------------------
-- Magazine persistence (roadmap #18 — prerequisite of #17, in-game report
-- 2026-07-12: a dropped ARC9 revolver came back with its 3 spent rounds
-- refilled). A weapon that leaves the player is DESTROYED as an entity
-- (strip on unequip, Remove on take-back) and comes back through ply:Give,
-- which hands out the SWEP's DefaultClip — a free full magazine. So the
-- loaded round count travels in the instance blob: Cargo TRANSPORTS the
-- number, the weapon base owns what it means (contract §3).
-- ------------------------------------------------------------------

function CARGO.Inventory.StoreClip(uid, wep)
    if not isstring(uid) or not IsValid(wep) then return end
    local blob = CARGO.Instances.Get(uid)
    if not istable(blob) then return end
    local ok, clip = pcall(wep.Clip1, wep)
    if ok and isnumber(clip) and clip >= 0 then
        -- mutating the live blob IS the update (CRG-57): the write happens in
        -- the Touch of whoever called us, which is the one holding the player.
        blob.clip1 = clip
    end
end

-- ARC9 keeps the real magazine in the native Clip1 and MIRRORS it in its own
-- LoadedRounds NetworkVar (verified against the base) — set both when the SWEP
-- exposes it. Applied now AND one tick later: a weapon base fills the clip
-- during its own Initialize/Deploy, after ply:Give returns.
--
-- AlreadyGaveAmmo is the load-bearing part (2nd in-game pass 2026-07-12: an
-- AK-19 fired down to 15/30 still came back FULL, even with Clip1 restored).
-- Verified against the live base, sh_attach.lua:147-155 — inside PostModify,
-- server side, with a valid player owner:
--
--     timer.Simple(0, function()               -- runs after each att attaches
--         if (ammo/clipsize changed) and self.AlreadyGaveAmmo then ...
--         elseif !self.AlreadyGaveAmmo then
--             self:SetClip1(self:GetProcessedValue("ClipSize"))  -- FREE FULL MAG
--             self.AlreadyGaveAmmo = true
--         end
--     end)
--
-- Initialize seeds AlreadyGaveAmmo = false (sh_init.lua:44), and PostModify
-- settles only once the attachments do — a net round-trip AFTER ply:Give, i.e.
-- after every timer we could queue. So we do not race it: we CLAIM the flag.
-- With it true, ARC9 takes neither branch and our magazine stands. A weapon
-- with no stored magazine never reaches here (RestoreClip returns early), so a
-- brand-new gun still gets its full clip from ARC9, exactly as intended.
local function ApplyClip(wep, clip)
    if not IsValid(wep) then return end
    if wep.AlreadyGaveAmmo ~= nil then wep.AlreadyGaveAmmo = true end
    wep:SetClip1(clip)
    if isfunction(wep.SetLoadedRounds) then pcall(wep.SetLoadedRounds, wep, clip) end
end

function CARGO.Inventory.RestoreClip(ply, class, blob)
    if not istable(blob) or not isnumber(blob.clip1) then return end
    local clip = blob.clip1
    local function apply()
        if not IsValid(ply) then return end
        ApplyClip(ply:GetWeapon(class), clip)
    end
    apply()
    timer.Simple(0, apply)
end

-- ------------------------------------------------------------------
-- blob.atts — the attachment tree, harvested and re-applied AT THE GATE
-- (roadmap #53, B3/B4). Same shape as the magazine, for the same reason: the
-- live SWEP entity is the only place ARC9 keeps what is mounted
-- (slottbl.Installed, sh_attach.lua:19) and it gives nothing back when it dies
-- (OnRemove/OnDrop, sh_init.lua:215-234).
--
-- The trap, and it is the same one Artagdoll paid for: this is harvested IN
-- THE GATE, never in a timer. Fifty milliseconds later the entity is gone and
-- there is nothing left to ask.
-- ------------------------------------------------------------------

-- the blob carries no uid of its own (Instances.Create), so the harvest works
-- on the blob TABLE and the two entry points differ only in how they got it
local function HarvestInto(blob, wep)
    if not istable(blob) or not IsValid(wep) then return end
    if CARGO.ARC9 == nil or not CARGO.ARC9.Available() then return end

    local ok, tree = pcall(CARGO.ARC9.HarvestTree, wep)
    if not ok then
        -- a pcall that swallows is worse than no pcall (lección del #46)
        Corpus.Log("cargo", "atts: la cosecha falló sobre "
            .. tostring(wep:GetClass()) .. " — " .. tostring(tree))
        return
    end
    -- mutating the live blob IS the update (CRG-57)
    blob.atts = tree
end

function CARGO.Inventory.StoreAtts(uid, wep)
    if not isstring(uid) then return end
    HarvestInto(CARGO.Instances.Get(uid), wep)
end

-- Which equipped instance IS this weapon entity? A give from GiveEquipWeapon
-- leaves no uid on the entity (only world drops carry CargoInstanceUid), so
-- the link is the class, the same way StripEquipWeapon resolves it.
function CARGO.Inventory.EquippedUidForClass(ply, class)
    if not IsValid(ply) or not isstring(class) or class == "" then return nil end
    local rec = CARGO.Inventory.GetRecord(ply)
    for _, val in pairs(rec.equip or {}) do
        if isstring(val) then
            local blob = CARGO.Instances.Get(val)
            local def = blob and CARGO.Items.Get(blob.id) or nil
            if def ~= nil and def.weapon_class == class then return val, blob end
        end
    end
    return nil
end

-- THE BLOB HAS TO FOLLOW THE GUN WHILE IT IS IN YOUR HANDS, not only at the
-- gates (planilla AB, check AB8 en FALLA).
--
-- The gates are where the tree is RESCUED — the entity is about to die there.
-- But mounting a scope from ARC9's own C menu crosses no gate at all, so until
-- this existed the blob stayed at whatever it said when the weapon was last
-- stored. Persistence was right and everything DERIVED from the blob was
-- stale: CRG-66 says the instance weighs what it carries, and the weight only
-- caught up after putting the gun away. Same for the price.
--
-- Deliberately ONE TICK LATE, which is the opposite of the gate rule and for
-- the opposite reason: the inventory hooks fire from inside ReceiveWeapon's
-- ownership diff (sh_net.lua:90-122), which runs BEFORE BuildSubAttachments
-- installs the new tree (:125). Harvesting on the spot would record the tree
-- the player just replaced. Here the entity is not going anywhere — nothing
-- expires in a tick — so waiting is safe; at a gate it never is.
function CARGO.Inventory.SyncAttsSoon(ply)
    if not IsValid(ply) then return end
    if CARGO.ARC9 == nil or not CARGO.ARC9.Available() then return end
    if ply.CargoAttSyncQueued then return end -- one per tick, not one per att
    ply.CargoAttSyncQueued = true

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        ply.CargoAttSyncQueued = nil

        local wep = ply:GetActiveWeapon() -- the C menu works on the held gun
        if not IsValid(wep) or not istable(wep.Attachments) then return end
        local uid, blob = CARGO.Inventory.EquippedUidForClass(ply, wep:GetClass())
        if blob == nil then return end

        local before = blob.atts
        HarvestInto(blob, wep)
        -- only pay for a sync + movement refresh when something moved
        if util.TableToJSON(before or {}) ~= util.TableToJSON(blob.atts or {}) then
            CARGO.Inventory.Touch(ply)
        end
    end)
end

-- Everything the live entity knows that the blob does not. The gates call
-- THIS, so a gate added later gets the attachment tree for free instead of
-- having to remember a second call.
--
-- StoreClip keeps its own name and behaviour on purpose: it is cited by an
-- IMMUTABLE audit act (corpus/docs/auditorias/2026-07-19) and by §10 of the
-- architecture, and renaming it would leave those citations describing
-- something that no longer exists.
function CARGO.Inventory.StoreFromEntity(uid, wep)
    CARGO.Inventory.StoreClip(uid, wep)
    CARGO.Inventory.StoreAtts(uid, wep)
end

-- Re-apply the tree onto a freshly born SWEP, BY THE MOD'S OWN SERVER ROUTE.
--
-- The sequence is ARC9's, read off the server branch of ReceiveWeapon
-- (sh_net.lua:141-149) and not invented — with two deliberate differences:
--   * FillIntegralSlots is NOT called (author call, 2026-07-30). It CONSUMES
--     from the store, and the store is us, so every equip and every respawn
--     would quietly eat items off the grid to top up integral slots. It is
--     also the root of roadmap #42, which stays its own entry.
--   * DoInvalidateCache IS called. It is easy to miss and it clears
--     StatCache/HookCache/AttPosCache (sh_0_stats.lua:49-57); without it the
--     gun keeps serving processed stats from before the tree changed.
--
-- CRG-23 holds: the write goes through the mod's API. And the ownership diff
-- never runs — it lives INSIDE ReceiveWeapon's own `if SERVER` block
-- (sh_net.lua:83-123), so calling BuildSubAttachments directly steps around
-- it. That is what makes re-applying free: these atts already belong to this
-- instance, they are not being bought a second time.
--
-- Afterwards the blob is RE-HARVESTED from the entity so it converges on what
-- the gun actually carries: whatever PruneAttachments rejected already went
-- back through our ARC9_PlayerGiveAtt hook (to the grid, or to the floor —
-- CRG-65), and an att the pack deleted stops haunting the blob.
function CARGO.Inventory.ApplyAtts(wep, blob, ply, fallbackPos)
    if not IsValid(wep) or not istable(blob) then return end
    if CARGO.ARC9 == nil or not CARGO.ARC9.Available() then return end
    if not istable(blob.atts) then return end

    local tree, orphans, unknown = CARGO.ARC9.ResolveTree(blob.atts, wep)
    if tree == nil then return end

    local ok, err = pcall(function()
        wep:BuildSubAttachments(tree)
        wep:DoInvalidateCache()
        wep:PruneAttachments()
        wep:SendWeapon()
        wep:PostModify()
    end)
    if not ok then
        Corpus.Log("cargo", "atts: la re-aplicación falló sobre "
            .. tostring(wep:GetClass()) .. " — " .. tostring(err))
        return -- the blob is NOT rewritten: a failed apply must not erase it
    end

    -- an att the pack no longer declares cannot come back as an item (our def
    -- ids derive from ARC9.Attachments), so it is dropped — but it is SAID
    for att, n in pairs(unknown) do
        Corpus.Log("cargo", "atts: '" .. tostring(att) .. "' x" .. n
            .. " ya no existe en ARC9.Attachments — descartado de "
            .. tostring(wep:GetClass()))
    end

    -- an att that still exists but found no slot goes back as an item
    for att, n in pairs(orphans) do
        local itemId = CARGO.ARC9.ItemId(att)
        if CARGO.Items.Get(itemId) ~= nil then
            if IsValid(ply) then
                CARGO.Inventory.GiveOrDrop(ply, itemId, n)
            else
                CARGO.Inventory.DropAt(fallbackPos or wep:GetPos(), itemId, n)
            end
        end
    end

    HarvestInto(blob, wep)
end

-- world entities (a drop straight out of the grid) take the same treatment
function CARGO.Inventory.ApplyClipToEntity(wep, uid)
    if not IsValid(wep) or not isstring(uid) then return end
    local blob = CARGO.Instances.Get(uid)
    if not istable(blob) or not isnumber(blob.clip1) then return end
    local clip = blob.clip1
    ApplyClip(wep, clip)
    timer.Simple(0, function() ApplyClip(wep, clip) end)
end

-- ------------------------------------------------------------------
-- Equip / unequip
-- ------------------------------------------------------------------

-- NEVER with the engine's free ammo, and that is CRG-17 taken literally: the
-- reserve is rebuilt from the belt AND FROM NOTHING ELSE.
--
-- This argument was already written here, and it was only applied to the
-- throwable slot: "pool-fed SWEPs like weapon_frag put that free clip straight
-- into the ammo POOL, and the §16 mirror would launder it onto the belt —
-- ether". Every HL2 engine weapon is pool-fed in exactly the same way, so the
-- reasoning covered them from the start and the flag did not.
--
-- MEASURED IN GAME (planilla AC, ronda 1, 2026-08-01), on the author's own
-- dump: equipping weapon_rpg took the reserve from 6 rockets to 9, and the
-- crossbow from 8 bolts to 11. THREE ROCKETS IS NINE KILOS of free carry
-- capacity per equip — a bigger hole than the one this block was opened to
-- close, and it stayed invisible until the magazine started weighing.
--
-- It only ever bit the ENGINE weapons: an ARC9 gun declares SWEP.Ammo and
-- leaves Primary.Ammo empty at class level (Arc9 Base shared.lua:334-335), so
-- the engine had nothing to hand out, and ARC9's own gift was already
-- neutralised at the source by the arc9_mult_defaultammo takeover (§16.4).
-- That is why five packs' worth of weapons never showed it.
local function GiveEquipWeapon(ply, def, blob)
    if isstring(def.weapon_class) and def.weapon_class ~= "" then
        -- flag lets the capture hook (corpus_cargo_capture.lua) tell OUR
        -- equip-give apart from engine/loadout gives it must intercept
        ply.CargoEquipGive = true
        ply:Give(def.weapon_class, true)
        ply.CargoEquipGive = nil

        -- ORDER IS LOAD-BEARING (roadmap #53, B4): the tree goes on BEFORE the
        -- magazine. A mag attachment changes ClipSize, and ARC9's PostModify
        -- answers a ClipSize change with Unload + SetRequestReload
        -- (sh_attach.lua:147-159) — applied after RestoreClip, it would empty
        -- the magazine we just restored into the pool. This is an argument
        -- about the SEQUENCE and not the instant, so it is measured in game
        -- with an att that moves ClipSize, never with a scope.
        -- and the client's own preset restore is taken over FIRST: it fires
        -- 0.075 s after the entity's first Think and would charge the grid for
        -- what it mounts (roadmap #53, B4). Unconditional — a bare gun is
        -- precisely the one it would dress up.
        CARGO.ARC9.TakeOverPresets(ply:GetWeapon(def.weapon_class))
        CARGO.Inventory.ApplyAtts(ply:GetWeapon(def.weapon_class), blob, ply)

        -- the stored magazine beats the SWEP's DefaultClip (#18)
        CARGO.Inventory.RestoreClip(ply, def.weapon_class, blob)
    end
end

-- uid: remember the loaded magazine AND the attachment tree before the SWEP
-- entity dies (#18 / roadmap #53 B3 — StoreFromEntity is both)
local function StripEquipWeapon(ply, def, uid)
    if isstring(def.weapon_class) and def.weapon_class ~= "" then
        if uid ~= nil then
            CARGO.Inventory.StoreFromEntity(uid, ply:GetWeapon(def.weapon_class))
        end
        ply:StripWeapon(def.weapon_class)
    end
end

function CARGO.Inventory.Unequip(ply, slotId)
    local rec = CARGO.Inventory.GetRecord(ply)
    local uid = rec.equip[slotId]
    if uid == nil then return false end

    -- stack slot (throwable): the stack returns to the grid, the SWEP goes
    -- with it, and the reserve it mirrored leaves the pool (Push below)
    if istable(uid) then
        local entry = uid
        rec.equip[slotId] = nil
        local def = CARGO.Items.Get(entry.id)
        if def then StripEquipWeapon(ply, def, nil) end
        AddStack(rec, entry.id, entry.count or 1, entry.condition)
        hook.Run("Corpus_Cargo_EquipChanged", ply, slotId, nil, nil)
        CARGO.Inventory.Touch(ply)
        if CARGO.AmmoPool then CARGO.AmmoPool.Push(ply) end
        return true
    end

    local blob = CARGO.Instances.Get(uid)
    rec.equip[slotId] = nil
    rec.items[#rec.items + 1] = { id = blob and blob.id or "?", uid = uid }

    if blob then
        local def = CARGO.Items.Get(blob.id)
        if def then StripEquipWeapon(ply, def, uid) end
    end
    if slotId == "body" then
        -- signal for Cortex (disguise resolution) — soft, fires into the void
        -- until Cortex's block lands
        hook.Run("Corpus_Cargo_BodyChanged", ply, nil, nil)
    end
    hook.Run("Corpus_Cargo_EquipChanged", ply, slotId, nil, nil)
    CARGO.Inventory.Touch(ply)
    return true
end

function CARGO.Inventory.Equip(ply, ref, slotId)
    local rec = CARGO.Inventory.GetRecord(ply)
    local idx, entry, stale = FindCell(ply, rec, ref)
    if entry == nil then
        -- FindCell already spoke for the stale cell; this is the other miss
        if not stale then
            CARGO.Inventory.Notice(ply, "That item is not in your inventory.")
        end
        return false
    end

    -- stack slot (throwable, §4 amendment): the WHOLE stack occupies the
    -- slot — grid stacks already respect max_stack, so nothing re-splits
    local slot = CARGO.Slots.ById[slotId]
    if istable(slot) and slot.stack then
        if entry.uid ~= nil then
            CARGO.Inventory.Notice(ply, "That item does not fit that slot.")
            return false
        end
        local def = CARGO.Items.Get(entry.id)
        if def == nil or not CARGO.Slots.CanEquip(def, slotId) then
            CARGO.Inventory.Notice(ply, "That item does not fit that slot.")
            return false
        end

        -- previous occupant returns to the grid first (may merge into the
        -- incoming stack under max_stack — refind after)
        if rec.equip[slotId] ~= nil then CARGO.Inventory.Unequip(ply, slotId) end
        local idx2, e2 = FindEntry(rec, ref)
        if e2 == nil then return false end
        table.remove(rec.items, idx2)
        rec.equip[slotId] = { id = e2.id, count = e2.count or 1, condition = e2.condition }

        -- the stack IS the reserve; the Push loads the pool from it
        GiveEquipWeapon(ply, def, nil)
        -- no blob: a stack slot holds an entry table, never an instance
        hook.Run("Corpus_Cargo_EquipChanged", ply, slotId, def.id, nil)
        CARGO.Inventory.Touch(ply)
        if CARGO.AmmoPool then CARGO.AmmoPool.Push(ply) end
        return true
    end

    if entry.uid == nil then
        CARGO.Inventory.Notice(ply, "That item is not in your inventory.")
        return false
    end

    local blob = CARGO.Instances.Get(entry.uid)
    local def = blob and CARGO.Items.Get(blob.id) or nil
    if def == nil or not CARGO.Slots.CanEquip(def, slotId) then
        CARGO.Inventory.Notice(ply, "That item does not fit that slot.")
        return false
    end

    -- previous occupant returns to the grid first
    if rec.equip[slotId] ~= nil then CARGO.Inventory.Unequip(ply, slotId) end

    -- FindEntry again: Unequip appended to rec.items, indices moved
    idx = FindEntry(rec, ref)
    table.remove(rec.items, idx)
    rec.equip[slotId] = entry.uid

    GiveEquipWeapon(ply, def, blob)
    if slotId == "body" then
        hook.Run("Corpus_Cargo_BodyChanged", ply, def.id, blob)
    end
    hook.Run("Corpus_Cargo_EquipChanged", ply, slotId, def.id, blob)
    CARGO.Inventory.Touch(ply)
    return true
end

-- ------------------------------------------------------------------
-- Use / drop
-- ------------------------------------------------------------------

-- The onUse callback is the owner module's domain (CORPUS_Architecture.md
-- §5): Cargo runs it and consumes one unit if it returns true. Cargo never
-- interprets what the item did.
function CARGO.Inventory.UseEntry(ply, ref)
    local rec = CARGO.Inventory.GetRecord(ply)
    local idx, entry = FindCell(ply, rec, ref)
    if entry == nil then return false end

    local def = CARGO.Items.Get(entry.id)
    if def == nil or not isfunction(def.onUse) then
        CARGO.Inventory.Notice(ply, "That item cannot be used.")
        return false
    end

    local blob = entry.uid and CARGO.Instances.Get(entry.uid) or nil
    local ok, consume = pcall(def.onUse, ply, { entry = entry, blob = blob })
    if not ok then
        Corpus.Log("cargo", "onUse de '" .. entry.id .. "' falló: " .. tostring(consume))
        return false
    end

    if consume == true then
        if entry.uid then
            -- destroying a unique instance: mandatory ejection first
            if blob then CARGO.Inventory.EjectSubSlots(ply, blob) end
            table.remove(rec.items, idx)
            CARGO.Instances.Delete(entry.uid)
        else
            entry.count = (entry.count or 1) - 1
            if entry.count <= 0 then table.remove(rec.items, idx) end
        end
    end
    CARGO.Inventory.Touch(ply)
    return true
end

function CARGO.Inventory.DropEntry(ply, ref, count)
    local rec = CARGO.Inventory.GetRecord(ply)
    local idx, entry = FindCell(ply, rec, ref)
    if entry == nil then return false end

    -- GATE 4 of 5 (roadmap #43, CRG-76): drop from the grid
    if CARGO.Inventory.IsFavorite(rec, entry) then
        CARGO.Inventory.Notice(ply, "That's a favorite: unmark it before dropping it.")
        return false
    end

    local dropped
    if entry.uid then
        table.remove(rec.items, idx)
        dropped = { id = entry.id, uid = entry.uid }
    else
        count = math.Clamp(math.floor(count or 1), 1, entry.count or 1)
        entry.count = (entry.count or 1) - count
        if entry.count <= 0 then table.remove(rec.items, idx) end
        dropped = { id = entry.id, count = count, condition = entry.condition }
    end

    -- weapons drop as the REAL gun and everything else as the item entity —
    -- the shared SpawnDropped above, which taking it back (walk+use) reads to
    -- restore this same blob. The world gate in capture.lua keeps it from
    -- being hoovered by touch.
    SpawnDropped(ply:EyePos() + ply:GetAimVector() * 32, dropped)
    CARGO.Inventory.Touch(ply)
    return true
end

-- Drop straight from an equipment slot (roadmap #28). Three shapes, all of
-- them EXISTING machinery — the trap of this front is double bookkeeping:
--   · weapon in hand    -> ply:DropWeapon. The universal PlayerDroppedWeapon
--                          reconciler (capture.lua) empties the slot and tags
--                          the entity with the uid EXACTLY ONCE — nothing is
--                          repeated here.
--   · weapon carried    -> no world entity exists to hand over: store the
--                          magazine, clear the slot and spawn the real SWEP
--                          with its instance (same route as DropEntry).
--   · non-weapon gear / -> the corpus_cargo_item entity. A unique travels
--     throwable stack      WITH its whole blob — plates and sub-slot content
--                          ride inside it, nothing is lost (§4 ejection is
--                          for destruction; a drop destroys nothing). The
--                          throwable stack leaves the reserve, so Push.
function CARGO.Inventory.DropEquipped(ply, slotId)
    local rec = CARGO.Inventory.GetRecord(ply)
    local val = rec.equip[slotId]
    if val == nil then return false end

    -- GATE 5 of 5 (roadmap #43, CRG-76): drop straight from an equipment slot.
    -- Author's vote 2026-08-21, and it was put to him because it is the one of
    -- the five that adds friction to a gesture that is instant today: the case
    -- of use is "don't lose your rifle", and your rifle is equipped most of the
    -- time — a lock that switches off exactly while the item is in use protects
    -- the wrong moment. It goes BEFORE the three shapes below on purpose: two
    -- of them hand the item to the world through machinery that does its own
    -- bookkeeping (ply:DropWeapon and the reconciler), so a gate placed after
    -- the branch would have to be written three times.
    if CARGO.Inventory.IsFavorite(rec, val) then
        CARGO.Inventory.Notice(ply, "That's a favorite: unmark it before dropping it.")
        return false
    end

    local dropPos = ply:EyePos() + ply:GetAimVector() * 32

    local function spawnItemEnt(entry)
        local ent = ents.Create("corpus_cargo_item")
        if IsValid(ent) then
            ent.CargoEntry = entry
            ent:SetPos(dropPos)
            ent:Spawn()
        end
        return ent
    end

    -- stack slot (throwable): the stack drops as an item, the SWEP leaves
    if istable(val) then
        rec.equip[slotId] = nil
        local def = CARGO.Items.Get(val.id)
        if def then StripEquipWeapon(ply, def, nil) end
        spawnItemEnt({ id = val.id, count = val.count or 1, condition = val.condition })
        hook.Run("Corpus_Cargo_EquipChanged", ply, slotId, nil, nil)
        CARGO.Inventory.Touch(ply)
        if CARGO.AmmoPool then CARGO.AmmoPool.Push(ply) end
        return true
    end

    local uid = val
    local blob = CARGO.Instances.Get(uid)
    local def = blob and CARGO.Items.Get(blob.id) or nil
    if def == nil then return false end

    local class = isstring(def.weapon_class) and def.weapon_class ~= ""
        and def.weapon_class or nil
    if class ~= nil then
        local wep = ply:GetWeapon(class)
        local active = ply:GetActiveWeapon()
        if IsValid(wep) and IsValid(active) and active == wep then
            -- in hand: the honest route. Same ARC9 mid-reload guard as
            -- cargo_drop (shared helper — orphaned per-round timers error)
            if istable(CARGO.Capture) and isfunction(CARGO.Capture.DropBlockedByReload)
                and CARGO.Capture.DropBlockedByReload(wep) then
                CARGO.Inventory.Notice(ply, "Finish the reload before dropping.")
                return false
            end
            ply:DropWeapon(wep, ply:GetShootPos() + ply:GetAimVector() * 48)
            return true
        end

        -- carried (or eaten by a respawn race): no entity goes to the world
        -- by itself — make one, with the magazine and the attachment tree
        -- stored first (#18 / roadmap #53 B3). SpawnWorldWeapon below builds a
        -- NEW entity, so whatever is not harvested here dies with this one.
        CARGO.Inventory.StoreFromEntity(uid, wep)
        rec.equip[slotId] = nil
        if IsValid(wep) then ply:StripWeapon(class) end
        local spawned
        if istable(CARGO.Capture) and isfunction(CARGO.Capture.SpawnWorldWeapon)
            and CARGO.Capture.WorldGunsEnabled() then
            spawned = CARGO.Capture.SpawnWorldWeapon(class, dropPos, uid)
        end
        if spawned == nil then spawnItemEnt({ id = def.id, uid = uid }) end
        if slotId == "body" then
            hook.Run("Corpus_Cargo_BodyChanged", ply, nil, nil)
        end
        hook.Run("Corpus_Cargo_EquipChanged", ply, slotId, nil, nil)
        CARGO.Inventory.Touch(ply)
        return true
    end

    -- non-weapon gear (helmet / vest / backpack / accessory): the item
    -- entity, carrying its whole instance
    rec.equip[slotId] = nil
    spawnItemEnt({ id = def.id, uid = uid })
    if slotId == "body" then
        hook.Run("Corpus_Cargo_BodyChanged", ply, nil, nil)
    end
    hook.Run("Corpus_Cargo_EquipChanged", ply, slotId, nil, nil)
    CARGO.Inventory.Touch(ply)
    return true
end

-- ------------------------------------------------------------------
-- Quick slots (bind + use)
-- ------------------------------------------------------------------

function CARGO.Inventory.QuickBind(ply, slotN, itemId)
    if slotN < 1 or slotN > CARGO.Slots.QUICK_COUNT then return end
    local rec = CARGO.Inventory.GetRecord(ply)

    if itemId == "" or itemId == nil then
        rec.quick[slotN] = nil
    else
        local def = CARGO.Items.Get(itemId)
        if def == nil or not isfunction(def.onUse) then
            CARGO.Inventory.Notice(ply, "Only usable items can go in quick slots.")
            return
        end
        rec.quick[slotN] = itemId
    end
    CARGO.Inventory.Touch(ply)
end

-- WHICH ENTRY THE KEY FIRES ON (roadmap #66). Until this existed the quick
-- route built its ref by hand as `{ id = itemId }`, and that ref only ever
-- matched ONE shape of entry — a stack with no condition. Two things fell
-- through the gap, and both were SILENT:
--
--   · A UNIQUE was unreachable, because FindEntry only matches `{ id = ... }`
--     against entries with `uid == nil`, and the CountItem gate above it (stack
--     units only, as its own comment says) answered 0 first. So a unique bound
--     to a key answered "You are out of that consumable" forever, over a bag
--     that held two of them. Nothing gated the bind: the context menu hid the
--     option for uniques but the DRAG-AND-DROP onto the quick cell never did,
--     and the server only ever asked for an onUse. Coagulant's Tourniquet
--     (class = unique, onUse, "Not consumed") sits in exactly that state today.
--   · A STACK WITH A CONDITION was unreachable too, and this one did not even
--     say so: CountItem counted it, so the gate passed, and then FindEntry
--     failed on `entry.condition ~= nil` and UseEntry returned false with no
--     Notice at all. A stack carrying a condition is a LEGAL state and says so
--     in corpus_cargo_lan.lua (a worn plate back from a sub-slot, CRG-7).
--
-- THE BIND STAYS KEYED BY DEF ID, and that is the half worth defending. A uid
-- would look more precise and would be wrong: it dies with the instance, so
-- the first time the jar runs out the key is bound to nothing and the player
-- has to re-bind it — the state this route is supposed to survive. The id
-- outlives every instance and this resolves it fresh on each press.
--
-- THE RULE IS "THE MOST-USED ONE THAT STILL WORKS" (author vote 2026-08-19):
-- the lowest condition among those above 0. It is the STALKER rule — you
-- finish the open jar before opening another — and the reason it matters is
-- that Cargo never deletes an item at 0 (CRG-1: that call is the owner's), so
-- without it a spent jar would sit at the front of the list and eat every
-- press. Ties break by uid so two identical jars do not depend on record order,
-- which is the same reason CRG-69 sorts the catalogue.
--
-- A def with NO condition at all is a plain consumable: always usable, and it
-- sorts AFTER anything partially spent so a half jar still goes first.
local function QuickTarget(rec, itemId)
    local best, bestRank, first
    for _, entry in ipairs(rec.items) do
        if entry.id == itemId then
            if first == nil then first = entry end
            local cond = entry.condition
            if entry.uid then
                local blob = CARGO.Instances.Get(entry.uid)
                cond = blob and blob.condition or nil
            end
            local rank = cond == nil and math.huge or cond
            if cond == nil or cond > 0 then
                if best == nil or rank < bestRank
                    or (rank == bestRank and (entry.uid or "") < (best.uid or "")) then
                    best, bestRank = entry, rank
                end
            end
        end
    end

    -- every one of them spent: hand the owner module the first anyway and let
    -- its onUse be the one that says so. Cargo deciding that a 0 means "gone"
    -- would be Cargo deciding what condition MEANS, which is not its call.
    best = best or first
    if best == nil then return nil end
    if best.uid then return { uid = best.uid } end
    -- The `cid` is not decoration here: this function PICKED one entry out of
    -- several and the ref has to be able to say which one. Without it the rule
    -- above chooses the most-worn jar and then hands UseEntry a ref that
    -- resolves to the FIRST - the selection would be computed and discarded.
    -- This is the second and last place in the module that builds a stack ref
    -- by hand; the other is Grid.RefOf on the client (#68).
    return { id = best.id, condition = best.condition, cid = best.cid }
end

function CARGO.Inventory.QuickUse(ply, slotN)
    local rec = CARGO.Inventory.GetRecord(ply)

    local bodyDef
    if rec.equip.body then
        local blob = CARGO.Instances.Get(rec.equip.body)
        bodyDef = blob and CARGO.Items.Get(blob.id) or nil
    end
    if slotN > CARGO.Slots.QuickUnlocked(bodyDef) then
        CARGO.Inventory.Notice(ply, "Quick slot F" .. slotN .. " is locked (unlocked by the equipped suit).")
        return
    end

    local itemId = rec.quick[slotN]
    if itemId == nil then return end
    local ref = QuickTarget(rec, itemId)
    if ref == nil then
        CARGO.Inventory.Notice(ply, "You are out of that consumable.")
        return
    end
    CARGO.Inventory.UseEntry(ply, ref)
end

-- ------------------------------------------------------------------
-- Ammo belt (§16, roadmap #19). The belt is no longer inert storage: it IS
-- the player's real reserve. Moving a stack here loads the engine ammo pool
-- of its type; taking it back unloads it. The mirror that keeps the two sides
-- equal lives in corpus_cargo_ammopool.lua — these two functions only have to
-- push after they mutate.
-- ------------------------------------------------------------------

-- Merge `moving` units into a belt occupant of equal id+condition, capped at
-- max_stack. Returns how many units did not fit. Shared by BeltSet (grid ->
-- belt) and BeltMove (belt -> belt) so the ceiling rule lives in one place.
local function BeltMergeInto(occ, moving, maxStack)
    local put = math.max(math.min(maxStack - (occ.count or 1), moving), 0)
    occ.count = (occ.count or 1) + put
    return moving - put
end

function CARGO.Inventory.BeltSet(ply, slotN, ref)
    if slotN < 1 or slotN > CARGO.Slots.BELT_COUNT then return end
    local rec = CARGO.Inventory.GetRecord(ply)

    local idx, entry = FindCell(ply, rec, ref)
    if entry == nil or entry.uid ~= nil then return end

    local def = CARGO.Items.Get(entry.id)
    if not istable(def) or def.category ~= "ammo" then
        CARGO.Inventory.Notice(ply, "Only ammunition goes on the belt.")
        return
    end

    -- the stack moves; equal id+condition merges (anti-laundering rule holds),
    -- a different occupant returns to the grid first — a swap never silently
    -- loses a stack. No weight gate: the stack stays on the same player either
    -- way. What does NOT fit under max_stack stays behind in the grid: the
    -- ceiling is what makes six belt slots a decision instead of decoration.
    local maxStack = def.max_stack or math.huge
    local moving = entry.count or 1
    local occ = rec.belt[slotN]

    if occ ~= nil and occ.id == entry.id and occ.condition == entry.condition then
        local left = BeltMergeInto(occ, moving, maxStack)
        if left == moving then
            CARGO.Inventory.Notice(ply, "That belt slot is full.")
            return
        end
        moving = left
    else
        if occ ~= nil then
            AddStack(rec, occ.id, occ.count or 1, occ.condition)
        end
        local put = math.min(maxStack, moving)
        rec.belt[slotN] = { id = entry.id, count = put, condition = entry.condition }
        moving = moving - put
    end

    table.remove(rec.items, idx)
    if moving > 0 then AddStack(rec, entry.id, moving, entry.condition) end

    CARGO.Inventory.Touch(ply)
    if CARGO.AmmoPool then CARGO.AmmoPool.Push(ply) end
end

-- Reorder: move a stack that already hangs on the belt to another belt slot
-- (roadmap #25). Same id+condition merges under max_stack and the remainder
-- stays in the SOURCE slot (nothing leaves the belt on a merge); a different
-- occupant returns to the grid, same as BeltSet displacement (author call) —
-- a move never silently loses a stack. The displaced occupant does leave the
-- belt, so the pool mirror still needs the Push.
function CARGO.Inventory.BeltMove(ply, fromN, toN)
    if fromN < 1 or fromN > CARGO.Slots.BELT_COUNT then return end
    if toN < 1 or toN > CARGO.Slots.BELT_COUNT or toN == fromN then return end
    local rec = CARGO.Inventory.GetRecord(ply)

    local entry = rec.belt[fromN]
    if entry == nil then return end
    local occ = rec.belt[toN]

    if occ ~= nil and occ.id == entry.id and occ.condition == entry.condition then
        local def = CARGO.Items.Get(entry.id)
        local maxStack = istable(def) and def.max_stack or math.huge
        local moving = entry.count or 1
        local left = BeltMergeInto(occ, moving, maxStack)
        if left == moving then
            CARGO.Inventory.Notice(ply, "That belt slot is full.")
            return
        end
        if left > 0 then entry.count = left else rec.belt[fromN] = nil end
    else
        rec.belt[toN] = entry
        rec.belt[fromN] = nil
        if occ ~= nil then AddStack(rec, occ.id, occ.count or 1, occ.condition) end
    end

    CARGO.Inventory.Touch(ply)
    if CARGO.AmmoPool then CARGO.AmmoPool.Push(ply) end
end

function CARGO.Inventory.BeltClear(ply, slotN)
    local rec = CARGO.Inventory.GetRecord(ply)
    local entry = rec.belt[slotN]
    if entry == nil then return end
    rec.belt[slotN] = nil
    AddStack(rec, entry.id, entry.count or 1, entry.condition)
    CARGO.Inventory.Touch(ply)
    if CARGO.AmmoPool then CARGO.AmmoPool.Push(ply) end
end

-- Drop straight from a belt slot to the world (roadmap #72). Author report:
-- "Falta drop desde el belt para expulsarlo del inventario a la municion" --
-- until now the only way out was BeltClear and then a second drop from the
-- grid, which needs weight room in the grid, which is exactly what you do not
-- have when you want to throw something away.
--
-- Shape is the stack branch of DropEquipped (#28), not a new route: empty (or
-- decrement) the slot -> spawn -> Touch -> Push.
--
-- THE Push IS THE POINT OF THE ENTRY, and it is invisible on screen. The belt
-- is NOT inert storage: it IS the engine ammo pool (§16.3, CRG-15). This is the
-- FOURTH door that takes something off the belt -- BeltSet, BeltMove and
-- BeltClear are the other three -- and a door that skips the mirror leaves the
-- player having thrown the box and still carrying the rounds in reserve. The
-- inventory looks right; it shows up on the next reload.
--
-- A belt entry is ALWAYS a stack (the server refuses anything whose category
-- is not "ammo"), so it goes out through the shared SpawnDropped and never
-- through the weapon route -- and it never needs a `cid`: a belt slot is named
-- by its NUMBER, and rec.belt[slotN] already IS the entry.
function CARGO.Inventory.BeltDrop(ply, slotN, count)
    if slotN < 1 or slotN > CARGO.Slots.BELT_COUNT then return false end
    local rec = CARGO.Inventory.GetRecord(ply)
    local entry = rec.belt[slotN]
    if entry == nil then return false end

    local have = entry.count or 1
    count = math.Clamp(math.floor(count or 1), 1, have)
    if count >= have then
        rec.belt[slotN] = nil
    else
        entry.count = have - count
    end

    SpawnDropped(ply:EyePos() + ply:GetAimVector() * 32,
        { id = entry.id, count = count, condition = entry.condition })
    CARGO.Inventory.Touch(ply)
    if CARGO.AmmoPool then CARGO.AmmoPool.Push(ply) end
    return true
end

-- ------------------------------------------------------------------
-- Ammo group A/B (generic blob field on weapons, §3)
-- ------------------------------------------------------------------

function CARGO.Inventory.SetAmmoGroup(ply, uid, group)
    if group ~= "A" and group ~= "B" then return end
    local rec = CARGO.Inventory.GetRecord(ply)

    local owned = FindEntry(rec, { uid = uid }) ~= nil
    if not owned then
        for _, equippedUid in pairs(rec.equip) do
            if equippedUid == uid then owned = true break end
        end
    end
    if not owned then return end

    local blob = CARGO.Instances.Get(uid)
    if blob == nil then return end
    blob.ammo_group = group
    CARGO.Inventory.Touch(ply) -- the blob rides in the record now (CRG-56)
end

-- ------------------------------------------------------------------
-- Sub-slot attach / detach (the generic primitive at work)
-- ------------------------------------------------------------------

-- The host instance may sit in the grid or be equipped; either way it must
-- belong to the player.
local function FindOwnedInstance(rec, uid)
    local blob = CARGO.Instances.Get(uid)
    if blob == nil then return nil end
    if FindEntry(rec, { uid = uid }) ~= nil then return blob end
    for _, equippedUid in pairs(rec.equip) do
        if equippedUid == uid then return blob end
    end
    return nil
end

function CARGO.Inventory.SubSlotAttach(ply, hostUid, subId, ref)
    local rec = CARGO.Inventory.GetRecord(ply)
    local hostBlob = FindOwnedInstance(rec, hostUid)
    if hostBlob == nil then return end

    local hostDef = CARGO.Items.Get(hostBlob.id)
    local spec = CARGO.Items.GetSubSlot(hostDef, subId)
    if spec == nil then return end

    hostBlob.subslots = hostBlob.subslots or {}
    hostBlob.subslots[subId] = hostBlob.subslots[subId] or {}
    if #hostBlob.subslots[subId] >= spec.maxItems then
        CARGO.Inventory.Notice(ply, "Sub-slot '" .. spec.label .. "' is full.")
        return
    end

    local idx, entry = FindCell(ply, rec, ref)
    if entry == nil then return end
    local def = CARGO.Items.Get(entry.id)
    if def == nil or not CARGO.Items.MatchesFilter(def, spec.filter) then
        CARGO.Inventory.Notice(ply, "That item does not fit '" .. spec.label .. "'.")
        return
    end

    local mounted
    if entry.uid then
        table.remove(rec.items, idx)
        mounted = { id = entry.id, uid = entry.uid }
    else
        -- one unit off the stack; wear travels with it, factory units start
        -- at 100 when the def declares condition
        entry.count = (entry.count or 1) - 1
        if entry.count <= 0 then table.remove(rec.items, idx) end
        mounted = { id = entry.id }
        if entry.condition ~= nil then
            mounted.condition = entry.condition
        elseif def.has_condition then
            mounted.condition = 100
        end
    end

    table.insert(hostBlob.subslots[subId], mounted)
    hook.Run("Corpus_Cargo_SubSlotChanged", ply, hostUid, subId)
    CARGO.Inventory.Touch(ply)
end

function CARGO.Inventory.SubSlotDetach(ply, hostUid, subId, entryIndex)
    local rec = CARGO.Inventory.GetRecord(ply)
    local hostBlob = FindOwnedInstance(rec, hostUid)
    if hostBlob == nil or not istable(hostBlob.subslots) then return end

    local entries = hostBlob.subslots[subId]
    if not istable(entries) or entries[entryIndex] == nil then return end

    local entry = table.remove(entries, entryIndex)
    CARGO.Inventory.GiveEntry(ply, entry, true) -- ejection path: never blocked
    hook.Run("Corpus_Cargo_SubSlotChanged", ply, hostUid, subId)
    CARGO.Inventory.Touch(ply)
end

-- ------------------------------------------------------------------
-- Net receivers (client intents)
-- ------------------------------------------------------------------

net.Receive(NET_OPEN, function(_, ply)
    CARGO.Inventory.Sync(ply)
end)

net.Receive(NET_EQUIP, function(_, ply)
    local ref = CARGO.Util.ReadBlob()
    local slotId = net.ReadString()
    if ref then CARGO.Inventory.Equip(ply, ref, slotId) end
end)

net.Receive(NET_UNEQUIP, function(_, ply)
    CARGO.Inventory.Unequip(ply, net.ReadString())
end)

net.Receive(NET_USE, function(_, ply)
    local ref = CARGO.Util.ReadBlob()
    if ref then CARGO.Inventory.UseEntry(ply, ref) end
end)

net.Receive(NET_DROP, function(_, ply)
    local ref = CARGO.Util.ReadBlob()
    local count = net.ReadUInt(16)
    if ref then CARGO.Inventory.DropEntry(ply, ref, count) end
end)

-- Rate-limited because it is the one intent with NO payload to validate: every
-- other receiver here is gated by what it names, and this one would otherwise
-- be a free disk write per packet.
net.Receive(NET_SORT, function(_, ply)
    if not IsValid(ply) then return end
    if (ply.cargoNextSort or 0) > CurTime() then return end
    ply.cargoNextSort = CurTime() + 0.25
    CARGO.Inventory.SortGrid(ply)
end)

net.Receive(NET_FAVORITE, function(_, ply)
    local ref = CARGO.Util.ReadBlob()
    if ref then CARGO.Inventory.ToggleFavorite(ply, ref) end
end)

net.Receive(NET_QUICKBIND, function(_, ply)
    local slotN = net.ReadUInt(4)
    local itemId = net.ReadString()
    CARGO.Inventory.QuickBind(ply, slotN, itemId)
end)

net.Receive(NET_QUICKUSE, function(_, ply)
    CARGO.Inventory.QuickUse(ply, net.ReadUInt(4))
end)

net.Receive(NET_BELT_SET, function(_, ply)
    local slotN = net.ReadUInt(4)
    local ref = CARGO.Util.ReadBlob()
    if ref then CARGO.Inventory.BeltSet(ply, slotN, ref) end
end)

net.Receive(NET_BELT_CLR, function(_, ply)
    CARGO.Inventory.BeltClear(ply, net.ReadUInt(4))
end)

net.Receive(NET_BELT_MOVE, function(_, ply)
    local fromN = net.ReadUInt(4)
    local toN = net.ReadUInt(4)
    CARGO.Inventory.BeltMove(ply, fromN, toN)
end)

-- The Alive() gate is copied from NET_EQUIP_DROP and is the only belt intent
-- that needs it: the other three move a stack INSIDE the record, this one puts
-- an entity in the world.
net.Receive(NET_BELT_DROP, function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local slotN = net.ReadUInt(4)
    local count = net.ReadUInt(16)
    CARGO.Inventory.BeltDrop(ply, slotN, count)
end)

net.Receive(NET_EQUIP_DROP, function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    CARGO.Inventory.DropEquipped(ply, net.ReadString())
end)

net.Receive(NET_AMMOGROUP, function(_, ply)
    local uid = net.ReadString()
    local group = net.ReadString()
    CARGO.Inventory.SetAmmoGroup(ply, uid, group)
end)

net.Receive(NET_SUB_ATT, function(_, ply)
    local hostUid = net.ReadString()
    local subId = net.ReadString()
    local ref = CARGO.Util.ReadBlob()
    if ref then CARGO.Inventory.SubSlotAttach(ply, hostUid, subId, ref) end
end)

net.Receive(NET_SUB_DET, function(_, ply)
    local hostUid = net.ReadString()
    local subId = net.ReadString()
    local entryIndex = net.ReadUInt(8)
    CARGO.Inventory.SubSlotDetach(ply, hostUid, subId, entryIndex)
end)

-- ------------------------------------------------------------------
-- Death wipe (roadmap #15, author call 2026-07-12): with cargo_lose_on_death
-- the player loses EVERYTHING on death — grid, equipment, quick binds, belt
-- and money. Not a loot drop: it is gone (loot-on-death is a Cortex-owned
-- cross-module block). Runs on PlayerDeath so the empty equip is already in
-- place when PlayerLoadout's reconcile re-give runs on respawn.
-- ------------------------------------------------------------------

function CARGO.Inventory.WipeOnDeath(ply)
    local rec = CARGO.Inventory.GetRecord(ply)

    -- destroy every reachable instance so no blob survives in `_live` (the host
    -- plus any uid'd sub-slot entry it carries)
    local function purgeInstance(uid)
        local blob = CARGO.Instances.Get(uid)
        if istable(blob) and istable(blob.subslots) then
            for _, entries in pairs(blob.subslots) do
                for _, e in ipairs(entries) do
                    if e.uid then CARGO.Instances.Delete(e.uid) end
                end
            end
        end
        CARGO.Instances.Delete(uid)
    end

    for _, val in pairs(rec.equip) do
        -- stack slot (throwable): no instance to purge, just take the SWEP
        local id = istable(val) and val.id
            or (CARGO.Instances.Get(val) or {}).id
        local def = id and CARGO.Items.Get(id) or nil
        if def and isstring(def.weapon_class) and def.weapon_class ~= "" then
            ply:StripWeapon(def.weapon_class)
        end
        if isstring(val) then purgeInstance(val) end
    end
    for _, entry in ipairs(rec.items) do
        if entry.uid then purgeInstance(entry.uid) end
    end

    -- money goes through the active provider (respects DarkRP etc., §6)
    local okBal, bal = pcall(CARGO.Money.Get, ply)
    if okBal and isnumber(bal) and bal > 0 then pcall(CARGO.Money.Take, ply, bal) end

    rec.items, rec.equip, rec.quick, rec.belt = {}, {}, {}, {}

    -- the belt was the reserve (§16), so wiping it must wipe the engine pool
    -- too — otherwise the rounds survive the death that took the belt carrying
    -- them, and the corpse respawns armed (in-game report 2026-07-12)
    if CARGO.AmmoPool then CARGO.AmmoPool.Clear(ply) end

    CARGO.Inventory.Touch(ply)
end

-- ------------------------------------------------------------------
-- THE re-give of equipped weapon classes — one routine, every caller.
--
-- `rec.equip` names what the player wears; this is what turns that record into
-- weapons in his hands. TWO callers, and they are the reason it has a name at
-- all: the spawn hook below, and the LAN import (CRG-61), which replaces the
-- record from under a player who is standing there alive.
--
-- Giving the import a re-give of ITS own would be a second path for something
-- that already has one — the same argument that put the savegame restore
-- inside `Containers.Attach`, the primitive's only door (entry 46), and that
-- put both owner files behind a single serializer (CRG-58). If the re-give
-- ever changes, it changes here and both callers get it.
--
-- A class the player ALREADY holds is left alone. This runs mid-round —
-- Quick Loadouts fires the whole chain from its net receive, and the import
-- fires it whenever someone types the command — and re-giving would stomp the
-- live magazine with the stale blob clip. On a real spawn the player owns
-- nothing, so nothing is skipped.
-- ------------------------------------------------------------------

function CARGO.Inventory.RegiveEquipped(ply)
    if not IsValid(ply) then return end
    local rec = CARGO.Inventory.GetRecord(ply)
    for _, val in pairs(rec.equip) do
        -- stack slot (table): no blob — its ammo is the stack, and the
        -- ammopool Push reloads the pool from it
        local blob = istable(val) and val or CARGO.Instances.Get(val)
        local def = blob and CARGO.Items.Get(blob.id) or nil
        if def ~= nil and not (isstring(def.weapon_class)
            and def.weapon_class ~= "" and ply:HasWeapon(def.weapon_class)) then
            GiveEquipWeapon(ply, def, istable(val) and nil or blob)
        end
    end

    -- The whole set was just (re-)applied to this player entity, so the
    -- generic signal fires with NO slot: "re-read everything" (see header).
    -- A listener that owns player-side state — the NVG compat writes a
    -- networked var — gets the respawn door here instead of hooking
    -- PlayerLoadout and betting on hook order, which is the bug Quick
    -- Loadouts already cost this repo.
    hook.Run("Corpus_Cargo_EquipChanged", ply, nil, nil, nil)
end

-- ------------------------------------------------------------------
-- Lifecycle
-- ------------------------------------------------------------------

hook.Add("PlayerInitialSpawn", "corpus_cargo_inv_load", function(ply)
    CARGO.Inventory.GetRecord(ply)
end)

hook.Add("PlayerDeath", "corpus_cargo_inv_death", function(ply)
    if cvLoseOnDeath:GetBool() then CARGO.Inventory.WipeOnDeath(ply) end
end)

-- Equipped weapon classes survive respawn. By default the inventory persists
-- through death; cargo_lose_on_death wipes it instead (WipeOnDeath already ran
-- on PlayerDeath, so rec.equip is empty here and re-gives nothing).
hook.Add("PlayerLoadout", "corpus_cargo_inv_loadout", function(ply)
    CARGO.Inventory.RegiveEquipped(ply)

    -- Deferred reconcile (CHANGELOG #6): on spawn the gamemode loadout and
    -- the capture timers land AFTER this hook, and their give/remove churn
    -- can eat the gives above (WeaponEquip may fire deferred, past the
    -- CargoEquipGive window). One tick after the dust settles, run the same
    -- routine again — it skips whatever the player already holds, so the
    -- second pass only fills what was eaten. The capture keeps equipped
    -- classes now (Capture.Decide), so these gives survive flag-free.
    timer.Simple(0.1, function()
        CARGO.Inventory.RegiveEquipped(ply)
    end)
end)

hook.Add("PlayerDisconnected", "corpus_cargo_inv_save", function(ply)
    CARGO.Inventory.SaveRecord(ply)

    -- PRUNE (CRG-57): the blobs leave with their owner. The record was just
    -- rendered to disk, so dropping them from _live loses nothing — and without
    -- this the live table only ever grows over a session.
    local rec = CARGO.Inventory._records[SteamKey(ply)]
    if rec ~= nil then
        for uid in pairs(CARGO.Inventory.CollectInstances(rec)) do
            CARGO.Instances._live[uid] = nil
        end
    end

    CARGO.Inventory._records[SteamKey(ply)] = nil
end)

hook.Add("ShutDown", "corpus_cargo_inv_shutdown", function()
    for _, ply in ipairs(player.GetAll()) do
        CARGO.Inventory.SaveRecord(ply)
    end
end)
