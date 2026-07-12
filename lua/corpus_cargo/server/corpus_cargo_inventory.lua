-- corpus_cargo_inventory.lua — per-player inventory (SERVER)
-- Cargo_Architecture.md §4 (equip), §7 (grid model), §12 (persistence).
--
-- Data model (persisted per player as data/corpus/cargo/inv_<steamid64>.json):
--   items  : array of grid entries
--            stack  entry: { id, count, condition? } — condition only on
--                          returned sub-slot items; stacks merge ONLY on
--                          equal condition (prevents wear laundering)
--            unique entry: { id, uid } — blob lives in CARGO.Instances
--   equip  : { [slotId] = uid }
--   quick  : { [1..4] = itemId } (bindings; JSON round-trip re-normalized)
--   wallet : native money provider storage
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

-- ------------------------------------------------------------------
-- Records: load / save / normalize
-- ------------------------------------------------------------------

local function SteamKey(ply)
    -- bots have no SteamID64; they get a session-only, non-persistent key
    return ply:SteamID64() or ("bot" .. ply:EntIndex())
end

function CARGO.Inventory.GetRecord(ply)
    local sid = SteamKey(ply)
    local rec = CARGO.Inventory._records[sid]
    if rec ~= nil then return rec end

    rec = Corpus.Data.Load("cargo", "inv_" .. sid)
    if rec == nil then
        rec = { items = {}, equip = {}, quick = {}, wallet = {} }
    else
        -- Corpus.Data does not guarantee key types on the JSON round-trip:
        -- re-normalize the numeric quick-slot keys (contract in its header).
        rec.items = istable(rec.items) and rec.items or {}
        rec.equip = istable(rec.equip) and rec.equip or {}
        rec.quick = CARGO.Util.NumberKeys(rec.quick)
        rec.wallet = istable(rec.wallet) and rec.wallet or {}
        -- legacy slot ids from the first dev pass (pda/detector became the
        -- generic accessory slots) — remap so nothing equipped is orphaned
        if rec.equip.pda ~= nil and rec.equip.accessory1 == nil then
            rec.equip.accessory1 = rec.equip.pda
        end
        if rec.equip.detector ~= nil and rec.equip.accessory2 == nil then
            rec.equip.accessory2 = rec.equip.detector
        end
        rec.equip.pda, rec.equip.detector = nil, nil
    end

    CARGO.Inventory._records[sid] = rec
    return rec
end

function CARGO.Inventory.SaveRecord(ply)
    local rec = CARGO.Inventory._records[SteamKey(ply)]
    if rec == nil then return end
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
    for _, uid in pairs(rec.equip) do
        total = total + CARGO.Instances.WeightOf(uid)
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

-- Public contract: instance blob equipped in a slot (Cortex reads Body to
-- resolve the apparent faction / disguise — Cargo_Architecture.md §6).
function CARGO.Inventory.GetEquipped(ply, slotId)
    local rec = CARGO.Inventory.GetRecord(ply)
    local uid = rec.equip[slotId]
    if uid == nil then return nil end
    return CARGO.Instances.Get(uid), uid
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
    local snap = { items = {}, equip = {}, quick = rec.quick }

    for _, entry in ipairs(rec.items) do
        snap.items[#snap.items + 1] = EntrySnapshot(entry)
    end
    for slotId, uid in pairs(rec.equip) do
        local blob = CARGO.Instances.Get(uid)
        if blob then snap.equip[slotId] = { id = blob.id, uid = uid, blob = blob } end
    end

    -- defs auto-generated server-side (captured engine weapons) don't exist
    -- on the client until it sees them here and registers them. Defs with an
    -- icon override ride the same channel (Cargo_ItemImages §10): the
    -- override is def-level data, the client merges it and re-renders local
    for _, entry in ipairs(snap.items) do
        local def = CARGO.Items.Get(entry.id)
        if def and (def.autogen or def.icon_override ~= nil) then
            snap.defs = snap.defs or {}
            snap.defs[def.id] = def
        end
    end
    for _, slotEntry in pairs(snap.equip) do
        local def = CARGO.Items.Get(slotEntry.id)
        if def and (def.autogen or def.icon_override ~= nil) then
            snap.defs = snap.defs or {}
            snap.defs[def.id] = def
        end
    end

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
-- Equip / unequip
-- ------------------------------------------------------------------

local function GiveEquipWeapon(ply, def)
    if isstring(def.weapon_class) and def.weapon_class ~= "" then
        -- flag lets the capture hook (corpus_cargo_capture.lua) tell OUR
        -- equip-give apart from engine/loadout gives it must intercept
        ply.CargoEquipGive = true
        ply:Give(def.weapon_class)
        ply.CargoEquipGive = nil
    end
end

local function StripEquipWeapon(ply, def)
    if isstring(def.weapon_class) and def.weapon_class ~= "" then
        ply:StripWeapon(def.weapon_class)
    end
end

function CARGO.Inventory.Unequip(ply, slotId)
    local rec = CARGO.Inventory.GetRecord(ply)
    local uid = rec.equip[slotId]
    if uid == nil then return false end

    local blob = CARGO.Instances.Get(uid)
    rec.equip[slotId] = nil
    rec.items[#rec.items + 1] = { id = blob and blob.id or "?", uid = uid }

    if blob then
        local def = CARGO.Items.Get(blob.id)
        if def then StripEquipWeapon(ply, def) end
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
    if entry == nil or entry.uid == nil then
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

    GiveEquipWeapon(ply, def)
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
    CARGO.Instances.Save(uid)
    CARGO.Inventory.Sync(ply)
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
    CARGO.Instances.Save(hostUid)
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
    CARGO.Instances.Save(hostUid)
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
-- Lifecycle
-- ------------------------------------------------------------------

hook.Add("PlayerInitialSpawn", "corpus_cargo_inv_load", function(ply)
    CARGO.Inventory.GetRecord(ply)
end)

-- Equipped weapon classes survive respawn (inventory persists through
-- death in this block; loot-on-death is future design).
hook.Add("PlayerLoadout", "corpus_cargo_inv_loadout", function(ply)
    local rec = CARGO.Inventory.GetRecord(ply)
    for _, uid in pairs(rec.equip) do
        local blob = CARGO.Instances.Get(uid)
        local def = blob and CARGO.Items.Get(blob.id) or nil
        if def then GiveEquipWeapon(ply, def) end
    end

    -- Deferred reconcile (CHANGELOG #6): on spawn the gamemode loadout and
    -- the capture timers land AFTER this hook, and their give/remove churn
    -- can eat the gives above (WeaponEquip may fire deferred, past the
    -- CargoEquipGive window). One tick after the dust settles, re-give
    -- whatever equipped class the player still lacks — the capture keeps
    -- equipped classes now (Capture.Decide), so these gives survive
    -- flag-free.
    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        local rec2 = CARGO.Inventory.GetRecord(ply)
        for _, uid in pairs(rec2.equip) do
            local blob = CARGO.Instances.Get(uid)
            local def = blob and CARGO.Items.Get(blob.id) or nil
            if def and isstring(def.weapon_class) and def.weapon_class ~= ""
                and not ply:HasWeapon(def.weapon_class) then
                GiveEquipWeapon(ply, def)
            end
        end
    end)
end)

hook.Add("PlayerDisconnected", "corpus_cargo_inv_save", function(ply)
    CARGO.Inventory.SaveRecord(ply)
    CARGO.Inventory._records[SteamKey(ply)] = nil
end)

hook.Add("ShutDown", "corpus_cargo_inv_shutdown", function()
    for _, ply in ipairs(player.GetAll()) do
        CARGO.Inventory.SaveRecord(ply)
    end
end)
