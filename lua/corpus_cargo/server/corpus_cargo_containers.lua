-- corpus_cargo_containers.lua — world containers + transfer (SERVER)
-- Cargo_Architecture.md §8. Same grid model as the inventory, side-by-side
-- transfer UX. Capacity is a per-container decision: finite (field crate)
-- or infinite (base stash, capacity = nil). The PLAYER's weight always
-- governs what he can take, whatever the container allows.

local CARGO = Corpus.GetModule("cargo")

CARGO.Containers = CARGO.Containers or {}
CARGO.Containers._byId = CARGO.Containers._byId or {}
CARGO.Containers._nextId = CARGO.Containers._nextId or 0

local NET_CONT_OPEN  = Corpus.Net.Register("cargo", "container_open")
local NET_CONT_SYNC  = Corpus.Net.Register("cargo", "container_sync")
local NET_CONT_CLOSE = Corpus.Net.Register("cargo", "container_close")
local NET_TRANSFER   = Corpus.Net.Register("cargo", "transfer")
local NET_TAKEALL    = Corpus.Net.Register("cargo", "takeall")

local USE_RANGE = 160 -- max distance to keep operating an open container

-- ------------------------------------------------------------------
-- Attach: turns any entity into a container. Public contract.
-- opts: { name = display, capacity = kg | nil (infinite),
--         persistKey = [a-z0-9_-]+ | nil (session-only when absent) }
-- ------------------------------------------------------------------

function CARGO.Containers.Attach(ent, opts)
    if not IsValid(ent) then
        error("Cargo.Containers.Attach: invalid entity", 2)
    end
    if ent.CargoContainer ~= nil then return ent.CargoContainer end
    opts = opts or {}
    -- fail here, not later inside Corpus.Data.Save mid-transfer
    if opts.persistKey ~= nil
        and not (isstring(opts.persistKey) and opts.persistKey:match("^[%w_%-]+$")) then
        error("Cargo.Containers.Attach: 'persistKey' must match [a-z0-9_-]", 2)
    end

    CARGO.Containers._nextId = CARGO.Containers._nextId + 1
    local cont = {
        id = CARGO.Containers._nextId,
        ent = ent,
        name = opts.name or "Container",
        capacity = opts.capacity,
        persistKey = opts.persistKey,
        items = {},
        viewers = {},
    }

    if isstring(cont.persistKey) then
        local saved = Corpus.Data.Load("cargo", "cont_" .. cont.persistKey)
        if istable(saved) and istable(saved.items) then cont.items = saved.items end
        -- legacy grenade faces -> canonical throwable (roadmap #32), same
        -- remap the inventory loader applies — a persisted crate can carry
        -- Bloque B stacks too, and an unknown id renders as a blank cell
        local legacy = CARGO.Ammo and CARGO.Ammo.LegacyThrowIds or {}
        for _, entry in ipairs(cont.items) do
            if entry.uid == nil and legacy[entry.id or ""] then
                entry.id = legacy[entry.id]
            end
        end
    end

    ent.CargoContainer = cont
    CARGO.Containers._byId[cont.id] = cont

    -- Ejection rule extended to containers: a removed session container
    -- spills its contents into the world instead of eating them.
    ent:CallOnRemove("corpus_cargo_container", function()
        CARGO.Containers._byId[cont.id] = nil
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

local function SaveContainer(cont)
    if not isstring(cont.persistKey) then return end
    Corpus.Data.Save("cargo", "cont_" .. cont.persistKey, { items = cont.items })
end

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
    return snap
end

local function SyncViewers(cont)
    local snap = Snapshot(cont)
    for ply in pairs(cont.viewers) do
        if IsValid(ply) then
            net.Start(NET_CONT_SYNC)
            CARGO.Util.WriteBlob(snap)
            net.Send(ply)
        else
            cont.viewers[ply] = nil
        end
    end
end

function CARGO.Containers.OpenFor(ply, ent)
    if not IsValid(ply) or not IsValid(ent) or ent.CargoContainer == nil then return end
    local cont = ent.CargoContainer
    if ply:GetPos():DistToSqr(ent:GetPos()) > USE_RANGE * USE_RANGE then return end

    cont.viewers[ply] = true
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
    if cont == nil or not cont.viewers[ply] then return nil end
    if not IsValid(cont.ent)
        or ply:GetPos():DistToSqr(cont.ent:GetPos()) > USE_RANGE * USE_RANGE then
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
    local cont = CARGO.Containers._byId[contId]
    if cont then cont.viewers[ply] = nil end
end)

hook.Add("PlayerDisconnected", "corpus_cargo_cont_viewers", function(ply)
    for _, cont in pairs(CARGO.Containers._byId) do
        cont.viewers[ply] = nil
    end
end)
