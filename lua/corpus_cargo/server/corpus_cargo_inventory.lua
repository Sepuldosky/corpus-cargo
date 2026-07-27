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
local NET_EQUIP_DROP = Corpus.Net.Register("cargo", "equip_drop")

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

local function SteamKey(ply)
    -- bots have no SteamID64; they get a session-only, non-persistent key
    return ply:SteamID64() or ("bot" .. ply:EntIndex())
end

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

function CARGO.Inventory.SaveRecord(ply)
    if not cvPersist:GetBool() then return end -- session-only mode: nothing hits disk
    local rec = CARGO.Inventory._records[SteamKey(ply)]
    if rec == nil then return end

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
    local def = CARGO.Items.Get(id)
    local maxStack = istable(def) and def.max_stack or math.huge

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
-- condition = n|nil } for stacks. Returns index, entry.
local function FindEntry(rec, ref)
    if not istable(ref) then return nil end
    for i, entry in ipairs(rec.items) do
        if ref.uid ~= nil then
            if entry.uid == ref.uid then return i, entry end
        elseif entry.uid == nil and entry.id == ref.id and entry.condition == ref.condition then
            return i, entry
        end
    end
    return nil
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

local function EntrySnapshot(entry)
    if entry.uid then
        return { id = entry.id, uid = entry.uid, blob = CARGO.Instances.Get(entry.uid) }
    end
    return { id = entry.id, count = entry.count or 1, condition = entry.condition }
end

function CARGO.Inventory.BuildSnapshot(ply)
    local rec = CARGO.Inventory.GetRecord(ply)
    local snap = { items = {}, equip = {}, quick = rec.quick, belt = rec.belt }

    for _, entry in ipairs(rec.items) do
        snap.items[#snap.items + 1] = EntrySnapshot(entry)
    end
    for slotId, val in pairs(rec.equip) do
        if istable(val) then
            -- stack slot (throwable): count rides for the ×N badge; no blob
            snap.equip[slotId] = { id = val.id, count = val.count or 1,
                condition = val.condition }
        else
            local blob = CARGO.Instances.Get(val)
            if blob then snap.equip[slotId] = { id = blob.id, uid = val, blob = blob } end
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

-- noAmmo: stack-slot (throwable) gives suppress the engine's default clip.
-- Pool-fed SWEPs like weapon_frag put that free clip straight into the ammo
-- POOL, and the §16 mirror would launder it onto the belt — ether. The stack
-- itself is the reserve; the AmmoPool.Push after the equip loads it.
local function GiveEquipWeapon(ply, def, blob, noAmmo)
    if isstring(def.weapon_class) and def.weapon_class ~= "" then
        -- flag lets the capture hook (corpus_cargo_capture.lua) tell OUR
        -- equip-give apart from engine/loadout gives it must intercept
        ply.CargoEquipGive = true
        ply:Give(def.weapon_class, noAmmo == true)
        ply.CargoEquipGive = nil
        -- the stored magazine beats the SWEP's DefaultClip (#18)
        CARGO.Inventory.RestoreClip(ply, def.weapon_class, blob)
    end
end

-- uid: remember the loaded magazine before the SWEP entity dies (#18)
local function StripEquipWeapon(ply, def, uid)
    if isstring(def.weapon_class) and def.weapon_class ~= "" then
        if uid ~= nil then
            CARGO.Inventory.StoreClip(uid, ply:GetWeapon(def.weapon_class))
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
    CARGO.Inventory.Touch(ply)
    return true
end

function CARGO.Inventory.Equip(ply, ref, slotId)
    local rec = CARGO.Inventory.GetRecord(ply)
    local idx, entry = FindEntry(rec, ref)
    if entry == nil then
        CARGO.Inventory.Notice(ply, "That item is not in your inventory.")
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

        -- noAmmo: the stack IS the reserve; the Push loads the pool from it
        GiveEquipWeapon(ply, def, nil, true)
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
    local idx, entry = FindEntry(rec, ref)
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
    local idx, entry = FindEntry(rec, ref)
    if entry == nil then return false end

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

    -- weapons drop as the REAL gun (roadmap #16/#17): the SWEP entity
    -- renders itself (an ARC9 gun draws its assembled mirror on the ground
    -- — no prop stand-in matches it) and carries the instance uid, so
    -- taking it back (walk+use) restores this same blob. The world gate in
    -- capture.lua keeps it from being hoovered by touch.
    local spawned
    local def = CARGO.Items.Get(dropped.id)
    if dropped.uid ~= nil and istable(def)
        and isstring(def.weapon_class) and def.weapon_class ~= ""
        and istable(CARGO.Capture)
        and isfunction(CARGO.Capture.WorldGunsEnabled)
        and CARGO.Capture.WorldGunsEnabled() then
        spawned = CARGO.Capture.SpawnWorldWeapon(def.weapon_class,
            ply:EyePos() + ply:GetAimVector() * 32, dropped.uid)
    end

    if spawned == nil then
        local ent = ents.Create("corpus_cargo_item")
        if IsValid(ent) then
            ent.CargoEntry = dropped
            ent:SetPos(ply:EyePos() + ply:GetAimVector() * 32)
            ent:Spawn()
        end
    end
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
        -- by itself — make one, with the magazine stored first (#18)
        CARGO.Inventory.StoreClip(uid, wep)
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
    if CARGO.Inventory.CountItem(ply, itemId) < 1 then
        CARGO.Inventory.Notice(ply, "You are out of that consumable.")
        return
    end
    CARGO.Inventory.UseEntry(ply, { id = itemId })
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

    local idx, entry = FindEntry(rec, ref)
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

    local idx, entry = FindEntry(rec, ref)
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
        -- stack slot (table): no blob, no default clip — its ammo is the
        -- stack, the ammopool Push reloads the pool from it
        local blob = istable(val) and val or CARGO.Instances.Get(val)
        local def = blob and CARGO.Items.Get(blob.id) or nil
        if def ~= nil and not (isstring(def.weapon_class)
            and def.weapon_class ~= "" and ply:HasWeapon(def.weapon_class)) then
            GiveEquipWeapon(ply, def, istable(val) and nil or blob, istable(val))
        end
    end
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
