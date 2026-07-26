-- corpus_cargo_containers.lua — world containers + transfer (SERVER)
-- Cargo_Architecture.md §8. Same grid model as the inventory, side-by-side
-- transfer UX. Capacity is a per-container decision: finite (field crate)
-- or infinite (base stash, capacity = nil). The PLAYER's weight always
-- governs what he can take, whatever the container allows.
--
-- A container that declares a persistKey is an OWNER FILE (CRG-56/58): its
-- blobs travel inside `cont_<key>.json`, rendered and hydrated by the very
-- routine the player record uses (Instances.RenderOwner/HydrateOwner). Without
-- a persistKey nothing reaches disk (CRG-59) — it is world state and dies with
-- the map.
--
-- THE ENTITY KEEPS FLAT STATE ONLY. `ent.CargoContainer` is plain data;
-- the live references (the entity itself, the set of viewers) hang off
-- `_live`, indexed by the session id. The reason is duplicator.CopyEntTable:
-- it does table.Merge(data, ent:GetTable()) stripping only functions, so an
-- Entity field and a set keyed by Player would ride into every duplication and
-- every gm_save. Cleaning that up in a PreEntityCopy would be a patch at the
-- exit point — any other route reading ent:GetTable() still sees the garbage —
-- and it would burn the very hook the savegame block needs free for its own
-- blob. `_live` means the same thing here as in Instances._live: the half that
-- exists only at runtime and never reaches disk.

local CARGO = Corpus.GetModule("cargo")

CARGO.Containers = CARGO.Containers or {}
CARGO.Containers._byId = CARGO.Containers._byId or {}    -- id -> cont (flat state)
CARGO.Containers._live = CARGO.Containers._live or {}    -- id -> { ent, viewers }
CARGO.Containers._nextId = CARGO.Containers._nextId or 0

local NET_CONT_OPEN  = Corpus.Net.Register("cargo", "container_open")
local NET_CONT_SYNC  = Corpus.Net.Register("cargo", "container_sync")
local NET_CONT_CLOSE = Corpus.Net.Register("cargo", "container_close")
local NET_TRANSFER   = Corpus.Net.Register("cargo", "transfer")
local NET_TAKEALL    = Corpus.Net.Register("cargo", "takeall")

local USE_RANGE = 160 -- max distance to keep operating an open container

-- DEV surface (no admin gate — CRG-45, like the rest of the dev kit). No
-- shipped entity declares a persistKey: the demo crate and the demo trader are
-- session-only, which leaves the persistent-owner path (CRG-59) with no route
-- in game. Set this and the two demo entities adopt it, suffixed per class so
-- a crate and a trader can be persistent at the same time without sharing a
-- file. Empty (the default) keeps every demo container ephemeral, exactly as
-- shipped. Caveat, and it is why this is dev-only: TWO crates would share the
-- key, hence the file — one persistent crate at a time.
local cvDevPersist = CreateConVar("cargo_dev_persist_key", "", FCVAR_ARCHIVE,
    "DEV: persist key adopted by the demo crate/trader (empty = session-only, as shipped)")

function CARGO.Containers.DevPersistKey(suffix)
    local key = cvDevPersist:GetString()
    if key == "" or not key:match("^[%w_%-]+$") then return nil end
    return isstring(suffix) and (key .. "_" .. suffix) or key
end

-- The live half of a container: the entity it hangs on and who is looking at
-- it. Never stored on the entity — see the header.
local function Live(cont)
    return istable(cont) and CARGO.Containers._live[cont.id] or nil
end

-- Public because a cont alone no longer names its entity, and callers outside
-- this file (the trade layer today, the savegame block tomorrow) need the way
-- back. Returns nil when the container is gone; every caller already guards
-- with IsValid.
function CARGO.Containers.EntityOf(cont)
    local live = Live(cont)
    return live and live.ent or nil
end

-- ------------------------------------------------------------------
-- Attach: turns any entity into a container. Public contract.
-- opts: { name = display, capacity = kg | nil (infinite),
--         persistKey = [a-z0-9_-]+ | nil (session-only when absent) }
-- ------------------------------------------------------------------

function CARGO.Containers.Attach(ent, opts)
    if not IsValid(ent) then
        error("Cargo.Containers.Attach: invalid entity", 2)
    end
    -- Already attached IN THIS SESSION? The question is answered by the LIVE
    -- half, never by the flat table: `ent.CargoContainer` is plain data, and
    -- plain data hanging off an entity is precisely what a savegame or a dupe
    -- restores. A marker that came back that way names a session id that died
    -- with the map — trusting it leaves the entity permanently unusable, since
    -- Attach would return a container that is in no registry and OpenFor would
    -- find no live half. And a dead id can COLLIDE with one this session
    -- already minted, which is why the entity has to match too: without that,
    -- the crate would open somebody else's contents.
    -- In-game report 2026-07-26: after gm_load, crate and trader did nothing on
    -- USE. Restoring what the marker CARRIED (its item list) is not this
    -- block's job — those entries point at instances that died with the map;
    -- a persistent container reloads its own file below, and the savegame
    -- block owns the rest.
    local prior = ent.CargoContainer
    if prior ~= nil then
        local live = CARGO.Containers._live[prior.id]
        if live ~= nil and live.ent == ent then return prior end
        ent.CargoContainer = nil
    end

    opts = opts or {}
    -- fail here, not later inside Corpus.Data.Save mid-transfer
    if opts.persistKey ~= nil
        and not (isstring(opts.persistKey) and opts.persistKey:match("^[%w_%-]+$")) then
        error("Cargo.Containers.Attach: 'persistKey' must match [a-z0-9_-]", 2)
    end

    CARGO.Containers._nextId = CARGO.Containers._nextId + 1
    local cont = {
        id = CARGO.Containers._nextId,
        name = opts.name or "Container",
        capacity = opts.capacity,
        persistKey = opts.persistKey,
        items = {},
        instances = {},
    }

    if isstring(cont.persistKey) then
        local saved = Corpus.Data.Load("cargo", "cont_" .. cont.persistKey)
        if istable(saved) then
            if istable(saved.items) then cont.items = saved.items end
            cont.instances = istable(saved.instances) and saved.instances or {}
        end

        -- HYDRATION (CRG-56/57), the same routine the player record runs: the
        -- blobs came INSIDE this file and land in _live by reference. This is
        -- what makes `cont_<key>` an owner file of the first class, and it is
        -- what gives CRG-58 its second owner.
        local arrived = CARGO.Instances.HydrateOwner(cont)

        -- Honest degradation (cites COR-5), same rule GetRecord applies: an
        -- entry whose blob did NOT come in the file is dropped with a log,
        -- instead of rendering a weightless ghost. Note what it MEANS now: "the
        -- file came in incomplete", not "the blobs were never written" — until
        -- this pass a persisted crate stored entries and no blobs, so every
        -- unique it held was discarded on restart. That was the bug.
        for i = #cont.items, 1, -1 do
            local uid = istable(cont.items[i]) and cont.items[i].uid or nil
            if uid ~= nil and not arrived[uid] then
                Corpus.Log("cargo", "Containers.Attach: entrada sin blob (uid " .. tostring(uid) .. "), descartada")
                table.remove(cont.items, i)
            end
        end

        -- legacy grenade faces -> canonical throwable (roadmap #32), same
        -- remap the inventory loader applies — a persisted crate can carry
        -- Bloque B stacks too, and an unknown id renders as a blank cell.
        -- It stays HERE and not in the shared routine: this is a migration of
        -- FORM, not serialization, and the record's own version remaps `equip`
        -- slots a container does not have (see the inventory loader).
        local legacy = CARGO.Ammo and CARGO.Ammo.LegacyThrowIds or {}
        for _, entry in ipairs(cont.items) do
            if entry.uid == nil and legacy[entry.id or ""] then
                entry.id = legacy[entry.id]
            end
        end
    end

    ent.CargoContainer = cont
    CARGO.Containers._byId[cont.id] = cont
    CARGO.Containers._live[cont.id] = { ent = ent, viewers = {} }

    -- Ejection rule extended to containers: a removed session container
    -- spills its contents into the world instead of eating them.
    ent:CallOnRemove("corpus_cargo_container", function()
        CARGO.Containers._byId[cont.id] = nil
        CARGO.Containers._live[cont.id] = nil
        if cont.persistKey ~= nil then return end
        for _, entry in ipairs(cont.items) do
            local drop = ents.Create("corpus_cargo_item")
            if IsValid(drop) then
                drop.CargoEntry = entry
                drop:SetPos(ent:GetPos() + Vector(0, 0, 8))
                drop:Spawn()
            end
        end
    end)

    return cont
end

-- THE SINGLE WRITER of `cont_<key>`. Public because the trade layer persists
-- the same container and must not write that file itself: while one writer
-- knew how to serialize `instances` and the other did not, the blobs survived
-- or died depending on who saved last.
--
-- The saved table is spelled out on purpose — name, capacity and persistKey are
-- decisions the caller of Attach makes at attach time, not saved state. What
-- goes to disk is what an owner file is: entries plus the blobs they reach.
function CARGO.Containers.Save(cont)
    if not istable(cont) or not isstring(cont.persistKey) then return end

    -- RENDER (CRG-56/57), the same routine the player record runs.
    CARGO.Instances.RenderOwner(cont)
    Corpus.Data.Save("cargo", "cont_" .. cont.persistKey,
        { items = cont.items, instances = cont.instances })
end

local SaveContainer = CARGO.Containers.Save

local function ContainerWeight(cont)
    local total = 0
    for _, entry in ipairs(cont.items) do
        if entry.uid then
            total = total + CARGO.Instances.WeightOf(entry.uid)
        else
            local def = CARGO.Items.Get(entry.id)
            total = total + (istable(def) and def.weight or 0) * (entry.count or 1)
        end
    end
    return total
end

local function Snapshot(cont)
    local snap = {
        contId = cont.id,
        name = cont.name,
        capacity = cont.capacity,
        weight = ContainerWeight(cont),
        items = {},
    }
    for _, entry in ipairs(cont.items) do
        if entry.uid then
            snap.items[#snap.items + 1] = { id = entry.id, uid = entry.uid, blob = CARGO.Instances.Get(entry.uid) }
        else
            snap.items[#snap.items + 1] = { id = entry.id, count = entry.count or 1, condition = entry.condition }
        end
    end

    -- the viewer may never have held what is in here: a captured weapon's def
    -- is server-side only, and without it the cell draws blank and 1×1
    CARGO.Items.PackDefs(snap, snap.items)
    return snap
end

local function SyncViewers(cont)
    local live = Live(cont)
    if live == nil then return end

    local snap = Snapshot(cont)
    for ply in pairs(live.viewers) do
        if IsValid(ply) then
            net.Start(NET_CONT_SYNC)
            CARGO.Util.WriteBlob(snap)
            net.Send(ply)
        else
            live.viewers[ply] = nil
        end
    end
end

function CARGO.Containers.OpenFor(ply, ent)
    if not IsValid(ply) or not IsValid(ent) or ent.CargoContainer == nil then return end
    local cont = ent.CargoContainer
    local live = Live(cont)
    if live == nil then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > USE_RANGE * USE_RANGE then return end

    live.viewers[ply] = true
    net.Start(NET_CONT_OPEN)
    CARGO.Util.WriteBlob(Snapshot(cont))
    net.Send(ply)
    CARGO.Inventory.Sync(ply) -- the right half of the transfer panel
end

-- ------------------------------------------------------------------
-- Transfer core. dir: "take" (container -> player) | "put"
-- ------------------------------------------------------------------

local function ViewedContainer(ply, contId)
    local cont = CARGO.Containers._byId[contId]
    local live = Live(cont)
    if cont == nil or live == nil or not live.viewers[ply] then return nil end
    if not IsValid(live.ent)
        or ply:GetPos():DistToSqr(live.ent:GetPos()) > USE_RANGE * USE_RANGE then
        return nil
    end
    return cont
end

local function FindContEntry(cont, ref)
    for i, entry in ipairs(cont.items) do
        if ref.uid ~= nil then
            if entry.uid == ref.uid then return i, entry end
        elseif entry.uid == nil and entry.id == ref.id and entry.condition == ref.condition then
            return i, entry
        end
    end
    return nil
end

local function AddContStack(cont, id, count, condition)
    for _, entry in ipairs(cont.items) do
        if entry.uid == nil and entry.id == id and entry.condition == condition then
            entry.count = (entry.count or 1) + count
            return
        end
    end
    cont.items[#cont.items + 1] = { id = id, count = count, condition = condition }
end

local function EntryWeight(entry, count)
    if entry.uid then return CARGO.Instances.WeightOf(entry.uid) end
    local def = CARGO.Items.Get(entry.id)
    return (istable(def) and def.weight or 0) * (count or entry.count or 1)
end

-- Returns true when something moved (false -> blocked, notify).
local function TransferOne(ply, cont, dir, ref, count)
    if dir == "take" then
        local idx, entry = FindContEntry(cont, ref)
        if entry == nil then return false end

        if entry.uid then
            local ok = CARGO.Inventory.GiveEntry(ply, entry)
            if not ok then return false, "too heavy" end
            table.remove(cont.items, idx)
        else
            count = math.Clamp(math.floor(count or entry.count or 1), 1, entry.count or 1)
            local ok = CARGO.Inventory.GiveEntry(ply,
                { id = entry.id, count = count, condition = entry.condition })
            if not ok then return false, "too heavy" end
            entry.count = (entry.count or 1) - count
            if entry.count <= 0 then table.remove(cont.items, idx) end
        end
        return true
    end

    -- "put": player -> container. Equipped items must be unequipped first;
    -- only grid entries move.
    local rec = CARGO.Inventory.GetRecord(ply)
    local idx, entry
    for i, e in ipairs(rec.items) do
        if ref.uid ~= nil then
            if e.uid == ref.uid then idx, entry = i, e break end
        elseif e.uid == nil and e.id == ref.id and e.condition == ref.condition then
            idx, entry = i, e
            break
        end
    end
    if entry == nil then return false end

    count = entry.uid and 1 or math.Clamp(math.floor(count or entry.count or 1), 1, entry.count or 1)
    if cont.capacity ~= nil
        and ContainerWeight(cont) + EntryWeight(entry, count) > cont.capacity then
        return false, "the container can't hold more weight"
    end

    if entry.uid then
        table.remove(rec.items, idx)
        cont.items[#cont.items + 1] = { id = entry.id, uid = entry.uid }
    else
        entry.count = (entry.count or 1) - count
        if entry.count <= 0 then table.remove(rec.items, idx) end
        AddContStack(cont, entry.id, count, entry.condition)
    end
    return true
end

local function AfterTransfer(ply, cont)
    SaveContainer(cont)
    SyncViewers(cont)
    CARGO.Inventory.Touch(ply)
end

-- ------------------------------------------------------------------
-- Net receivers
-- ------------------------------------------------------------------

net.Receive(NET_TRANSFER, function(_, ply)
    local contId = net.ReadUInt(16)
    local dir = net.ReadString()
    local count = net.ReadUInt(16)
    local ref = CARGO.Util.ReadBlob()

    local cont = ViewedContainer(ply, contId)
    if cont == nil or ref == nil or (dir ~= "take" and dir ~= "put") then return end

    local ok, err = TransferOne(ply, cont, dir, ref, count)
    if not ok and err then CARGO.Inventory.Notice(ply, err) end
    AfterTransfer(ply, cont)
end)

net.Receive(NET_TAKEALL, function(_, ply)
    local contId = net.ReadUInt(16)
    local dir = net.ReadString()
    local cont = ViewedContainer(ply, contId)
    if cont == nil or (dir ~= "take" and dir ~= "put") then return end

    -- snapshot of refs first: TransferOne mutates the source list
    local refs = {}
    local source = dir == "take" and cont.items or CARGO.Inventory.GetRecord(ply).items
    for _, entry in ipairs(source) do
        refs[#refs + 1] = entry.uid and { uid = entry.uid }
            or { id = entry.id, condition = entry.condition }
    end

    local blocked = false
    for _, ref in ipairs(refs) do
        local ok = TransferOne(ply, cont, dir, ref, math.huge)
        blocked = blocked or not ok
    end
    if blocked then
        CARGO.Inventory.Notice(ply, dir == "take"
            and "Couldn't take everything: you ran out of carry weight."
            or "Couldn't move everything: the container ran out of capacity.")
    end
    AfterTransfer(ply, cont)
end)

net.Receive(NET_CONT_CLOSE, function(_, ply)
    local contId = net.ReadUInt(16)
    local live = CARGO.Containers._live[contId]
    if live then live.viewers[ply] = nil end
end)

hook.Add("PlayerDisconnected", "corpus_cargo_cont_viewers", function(ply)
    for _, live in pairs(CARGO.Containers._live) do
        live.viewers[ply] = nil
    end
end)
