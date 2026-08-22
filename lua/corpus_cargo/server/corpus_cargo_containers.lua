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
-- exit point — any other route reading ent:GetTable() still sees the garbage.
-- `_live` means the same thing here as in Instances._live: the half that
-- exists only at runtime and never reaches disk.
--
-- AND BECAUSE that merge carries the flat half wholesale, the flat half IS the
-- savegame blob (CRG-60). `Containers.Save` renders `instances` on every write
-- — persistent or not — so the marker an entity carries is a complete,
-- self-contained owner at ALL times, and `Attach` mints it again with fresh
-- uids when it comes back from another session. Nothing writes it from a
-- PreEntityCopy, and that is the same argument as above read forwards: a blob
-- that is only correct inside the copy hook is a blob that is wrong everywhere
-- else ent:GetTable() is read.

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
-- this file (the trade layer, the content addon's trader) need the way
-- back. Returns nil when the container is gone; every caller already guards
-- with IsValid.
function CARGO.Containers.EntityOf(cont)
    local live = Live(cont)
    return live and live.ent or nil
end

-- ------------------------------------------------------------------
-- THE SAVEGAME SIDE OF THE MARKER (CRG-60).
--
-- A marker that did NOT validate came back from another session — a gm_load or
-- a duplicator paste — and it carries a whole owner blob: its entries plus the
-- `instances` map Containers.Save renders on every write. The uid cannot be
-- reused, so the blobs are minted again and the entries rewritten
-- (Instances.Remint).
--
-- WHY IT LIVES HERE and not in a PostEntityPaste of each entity: Attach is the
-- one door into the primitive (CRG-21), so every entity that becomes a
-- container — the demo crate, the demo trader, the Sidorovich of the content
-- addon, tomorrow's corpse — gets this for free, without a line of its own and
-- without the hook having to fire in any particular order. It is also the only
-- place where the container is BORN, which is what makes the replacement below
-- meaningful.
--
-- AUTHOR'S CALL 2026-07-26 (A): THE SAVEGAME WINS over the owner file. A
-- persistent container may hold both — `Attach` read `cont_<key>` just above —
-- and they can disagree. `cont_<key>` declares scope `save`: it is game state,
-- not server config (COR-19), and B6's layout puts it under
-- `saves/<perfil>/maps/<mapa>/`. So loading a game is going back to that
-- moment, contents included, and the file is reconciled to match.
--
-- Replacing (never appending) is also what makes this idempotent: run it twice
-- and the list is the same. That matters because the order in which the
-- duplicator writes the flat fields is not observable from outside the game —
-- the invariant has to be of VALUE, not of moment (B3, six rounds).
-- ------------------------------------------------------------------

local function AdoptSavedState(cont, prior)
    if not istable(prior) or not istable(prior.items) then return end

    cont.items = CARGO.Instances.Remint(prior.items, prior.instances)
    CARGO.Containers.Save(cont) -- renders, and reconciles `cont_<key>` when persistent
    Corpus.Log("cargo", "Containers.Attach: estado restaurado de un savegame ("
        .. #cont.items .. " entradas)")
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
    -- USE. What the marker CARRIED is no longer thrown away, and that is what
    -- CRG-60 buys: its entries name instances that died with the map, so they
    -- are minted again from the blobs that travelled with them
    -- (AdoptSavedState, below the persistKey block).
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

    -- LAST, on purpose: whatever the savegame carried outranks the file (see
    -- the header of AdoptSavedState). A container with no prior marker, or one
    -- that validated and returned above, never reaches this.
    AdoptSavedState(cont, prior)

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
    if not istable(cont) then return end

    -- RENDER (CRG-56/57), the same routine the player record runs — and it runs
    -- for EVERY container, persistent or not. That is what makes the flat
    -- marker the entity carries a self-contained owner blob at all times, and
    -- that marker is exactly what a savegame takes with it (CRG-60): rendering
    -- only for the ones that reach disk would leave a session crate saving
    -- entries whose blobs stayed behind. It is deliberately NOT written from a
    -- PreEntityCopy — patching state at the exit point is what the entry-45
    -- saneo already rejected: any other route reading ent:GetTable() (the dupe
    -- tool, a third-party save) would see the incomplete half.
    CARGO.Instances.RenderOwner(cont)

    if not isstring(cont.persistKey) then return end -- CRG-59: no declared owner, no disk
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
            -- site 3 of five (#58): the crate column draws the same tooltip, so
            -- the weight has to ride here too or the SAME rifle reads 9 kg in
            -- the bag and 6 kg in the crate
            local blob = CARGO.Instances.Get(entry.uid)
            snap.items[#snap.items + 1] = { id = entry.id, uid = entry.uid,
                w = CARGO.Instances.SnapWeight(blob), blob = blob }
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

-- Roadmap #67: the container splits by `max_stack`, exactly like the
-- inventory's AddStack, and for the same reason the inventory does — ONE CELL
-- IS ONE STACK everywhere, or the rule the player learns on his own grid stops
-- holding the moment he opens a crate. Before this, a crate merged without a
-- ceiling and a single cell could read x800: the SHIFT that loads "the clicked
-- stack" would have loaded the whole pile on the loot side while behaving on
-- the player's, which is worse than either rule applied consistently.
local function AddContStack(cont, id, count, condition)
    local maxStack = CARGO.Items.MaxStack(CARGO.Items.Get(id))

    for _, entry in ipairs(cont.items) do
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
        cont.items[#cont.items + 1] = { id = id, count = put, condition = condition }
        count = count - put
    end
end

-- A stack ref names a QUANTITY, not a cell (roadmap #67). `max_stack` splits a
-- pile into several entries and they are FUNGIBLE — 120 rounds of 9x19 are 120
-- rounds of 9x19 whichever cell they were drawn in — so a click asking for 120
-- has to get 120 even when the entry it resolved to only holds the 80 of the
-- remainder. Without these two, splitting the container would have introduced
-- exactly that wart: click the x120 cell, receive 80, no error anywhere.
local function StackTotal(list, ref)
    local total = 0
    for _, e in ipairs(list) do
        if e.uid == nil and e.id == ref.id and e.condition == ref.condition then
            total = total + (e.count or 1)
        end
    end
    return total
end

-- Drains `count` units across as many entries as it takes and drops the ones
-- it empties. Walks BACKWARDS so table.remove cannot skip an entry, and so the
-- newest cell is the one that shrinks. Returns what it actually took.
local function DrainStack(list, ref, count)
    local left = count
    for i = #list, 1, -1 do
        if left <= 0 then break end
        local e = list[i]
        if e.uid == nil and e.id == ref.id and e.condition == ref.condition then
            local take = math.min(e.count or 1, left)
            e.count = (e.count or 1) - take
            left = left - take
            if e.count <= 0 then table.remove(list, i) end
        end
    end
    return count - left
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
            local total = StackTotal(cont.items, ref)
            count = math.Clamp(math.floor(count or total), 1, total)
            local ok = CARGO.Inventory.GiveEntry(ply,
                { id = entry.id, count = count, condition = entry.condition })
            if not ok then return false, "too heavy" end
            DrainStack(cont.items, ref, count)
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

    -- GATE 3 of 5 (roadmap #43, CRG-76): the INDIVIDUAL transfer into the
    -- container. Author's vote 2026-08-21, and the reason is his own wording —
    -- "no puedes mandarlo al loot box sin quitarle el favorito" is only true if
    -- EVERY route is closed. Blocking the mass move and letting the drag
    -- through would make the lock depend on which gesture you touched it with,
    -- which is the exact incoherence roadmap #69 closed.
    if CARGO.Inventory.IsFavorite(rec, entry) then
        return false, "that's a favorite: unmark it before storing it"
    end

    if entry.uid then
        count = 1
    else
        local total = StackTotal(rec.items, ref)
        count = math.Clamp(math.floor(count or total), 1, total)
    end
    if cont.capacity ~= nil
        and ContainerWeight(cont) + EntryWeight(entry, count) > cont.capacity then
        return false, "the container can't hold more weight"
    end

    if entry.uid then
        table.remove(rec.items, idx)
        cont.items[#cont.items + 1] = { id = entry.id, uid = entry.uid }
    else
        DrainStack(rec.items, ref, count)
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

    -- Snapshot of refs first: TransferOne mutates the source list. DEDUPED by
    -- RefKey, and that is a bug fix and not tidiness: a stack ref names a
    -- QUANTITY, not a cell (roadmap #67), so with `max_stack` splitting 800
    -- rounds into seven entries the FIRST ref moves all seven and the other six
    -- resolve to nothing — which this loop reads as "blocked" and announces as
    -- a failure that never happened. It was live on the PUT direction before
    -- #67 (the player's grid always split), and #67 makes the container split
    -- too, so it would have reached Take all as well.
    local refs, seen = {}, {}
    local rec = CARGO.Inventory.GetRecord(ply)
    local source = dir == "take" and cont.items or rec.items
    local heldBack = false
    for _, entry in ipairs(source) do
        -- GATE 2 of 5 (roadmap #43, CRG-76): "Move all". It SKIPS favorites
        -- instead of letting TransferOne refuse them, and that is not a second
        -- copy of the rule — it is the difference between moving everything you
        -- can and reporting a failure that did not happen. Falling through to
        -- the gate below would set `blocked` and print "the container ran out
        -- of capacity", which is a lie about a container that has room.
        if dir == "put" and CARGO.Inventory.IsFavorite(rec, entry) then
            heldBack = true
        else
            local ref = entry.uid and { uid = entry.uid }
                or { id = entry.id, condition = entry.condition }
            local key = CARGO.Trade.RefKey(ref)
            if not seen[key] then
                seen[key] = true
                refs[#refs + 1] = ref
            end
        end
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
    if heldBack then
        CARGO.Inventory.Notice(ply, "Your favorites stayed in your pack.")
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

-- ------------------------------------------------------------------
-- CONTAINERS IN AN AREA (roadmap #60, asked by Coagulant for its hospital
-- area, COA-50 §17)
--
-- Medicine in a hospital does not assume a backpack, it assumes a pharmacy:
-- the `can()` of an action has to be able to look at the containers within a
-- radius and not only at the medic's inventory.
--
-- ⚠ THEY MIRROR THE INVENTORY SET ON PURPOSE, name for name and semantics for
-- semantics, so a consumer does not have to learn a second model. Whatever is
-- true of `Inventory.HasItem` is true of `AreaHas`, and so on down the list.
-- That mirroring is the contract; a "smarter" area function that answered
-- differently from its inventory twin would be the worse outcome.
--
-- WHY IT LIVES HERE AND NOT IN COAGULANT: the public contract of Cargo exposes
-- `Containers.Attach` and nothing about content — `_byId` and `Snapshot` are
-- off-contract. Coagulant already carries one debt of that class (it counts
-- its button items straight off `CARGO.ClientState.items`, with a written note
-- that it breaks IN SILENCE if the snapshot changes). Signing a second one for
-- convenience turns an accident into a method.
--
-- ⚠ THEY ARE FOUR AND THE ENTRY ASKED FOR THREE, and the difference is
-- measured and not a preference. The entry says "el espejo EXACTO de las tres
-- que Coagulant ya usa" — but the treatment path uses FOUR: it gates on
-- `HasItem` and then consumes with `TakeUnique` for a `unique` and `TakeItem`
-- for a stack (corpus_coagulant_treatment.lua:163 and :170 — the tourniquet is
-- a unique). With only the three, the hospital area could SEE a tourniquet in a
-- cabinet and have no way to consume it: the exact G4 defect the entry invokes
-- — "la accion existe, el item esta, y el boton dice que no hay" — moved from
-- the presence side to the take side. Shipping three would have reproduced, in
-- the area, the bug the entry was written to avoid.
--
-- WHAT THIS DOES NOT ADD, so it is not read as more than it is: no permissions.
-- That `OpenFor` does not check ownership (anyone within 160 u opens any
-- container) is a fact of Cargo that the hospital area WIDENS — from 160 u to
-- whatever the room measures — but does not create. It lives in the #12.
-- ------------------------------------------------------------------

-- Every live container whose entity is valid and within `radius` of `pos`.
-- Distance is measured to the ENTITY and not to the flat state, because the
-- flat state has no position: `cont` is what goes to disk (CRG-60) and the
-- entity is the live half.
local function ContainersNear(pos, radius)
    local out = {}
    if not isvector(pos) then return out end
    local r = math.max(tonumber(radius) or 0, 0)
    local r2 = r * r
    for _, cont in pairs(CARGO.Containers._byId) do
        local live = Live(cont)
        if live ~= nil and IsValid(live.ent)
            and live.ent:GetPos():DistToSqr(pos) <= r2 then
            out[#out + 1] = cont
        end
    end
    return out
end

CARGO.Containers.Near = ContainersNear -- the three below are its only callers today

-- Presence across BOTH classes — the twin of Inventory.HasItem, and it exists
-- for the same reason that one does: AreaCount below counts stack units only,
-- so a `unique` (the tourniquet) is invisible to it. An AreaCount without its
-- AreaHas reproduces the G4 defect in the area.
function CARGO.Containers.AreaHas(pos, radius, id)
    for _, cont in ipairs(ContainersNear(pos, radius)) do
        for _, entry in ipairs(cont.items or {}) do
            if entry.id == id then return true end
        end
    end
    return false
end

-- Stack units only, exactly like Inventory.CountItem: its result is what feeds
-- AreaTake's drain, and uniques are not drained by count.
function CARGO.Containers.AreaCount(pos, radius, id)
    local n = 0
    for _, cont in ipairs(ContainersNear(pos, radius)) do
        for _, entry in ipairs(cont.items or {}) do
            if entry.uid == nil and entry.id == id then n = n + (entry.count or 1) end
        end
    end
    return n
end

-- ALL OR NOTHING, like Inventory.TakeItem: it checks the total first and only
-- then moves anything, so a `can()` that passed cannot be followed by a `do()`
-- that half-consumed. A partial drain across a room would leave the caller with
-- no way to know what it got.
--
-- It drains ACROSS containers on purpose — that is the whole point of a
-- pharmacy: two bandages on one shelf and three on the next are five. Within
-- each container, factory stacks drain before worn ones, which is the same pass
-- order TakeItem uses and the same reason (CRG-7: no wear laundering — a worn
-- stack is not interchangeable with a fresh one, so the fresh ones go first).
--
-- Every container it touches is SAVED and its open viewers re-synced. Neither
-- is optional: `Containers.Save` is the single writer of `cont_<key>` (CRG-43),
-- and a crate somebody is looking at while the medic drains it would otherwise
-- keep drawing stock that is gone.
function CARGO.Containers.AreaTake(pos, radius, id, count)
    count = math.max(math.floor(tonumber(count) or 1), 1)
    if CARGO.Containers.AreaCount(pos, radius, id) < count then return false end

    local left = count
    for _, cont in ipairs(ContainersNear(pos, radius)) do
        local touched = false
        for pass = 1, 2 do
            for i = #(cont.items or {}), 1, -1 do
                local entry = cont.items[i]
                local worn = entry.condition ~= nil
                if entry.uid == nil and entry.id == id
                    and ((pass == 1 and not worn) or (pass == 2 and worn)) then
                    local moved = math.min(entry.count or 1, left)
                    entry.count = (entry.count or 1) - moved
                    left = left - moved
                    touched = true
                    if entry.count <= 0 then table.remove(cont.items, i) end
                    if left <= 0 then break end
                end
            end
            if left <= 0 then break end
        end
        if touched then
            CARGO.Containers.Save(cont)
            SyncViewers(cont)
        end
        if left <= 0 then break end
    end
    return true
end

-- Remove ONE unique instance from the area and delete its blob — the twin of
-- Inventory.TakeUnique, and the fourth function the measurement added. Without
-- it a `unique` in a cabinet is visible to AreaHas and consumable by nothing.
-- The blob dies with the entry for the same reason it does in the inventory:
-- an instance nobody owns is a leak in data/ that no pass would ever notice.
function CARGO.Containers.AreaTakeUnique(pos, radius, id)
    for _, cont in ipairs(ContainersNear(pos, radius)) do
        for i = #(cont.items or {}), 1, -1 do
            local entry = cont.items[i]
            if entry.uid ~= nil and entry.id == id then
                table.remove(cont.items, i)
                CARGO.Instances.Delete(entry.uid)
                CARGO.Containers.Save(cont)
                SyncViewers(cont)
                return true
            end
        end
    end
    return false
end
