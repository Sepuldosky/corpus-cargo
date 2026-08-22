-- corpus_cargo_instances.lua — unique-item instance blobs (SERVER)
-- Cargo_Architecture.md §12 (CRG-56/57/58).
--
-- Two TOZ-34 in the same inventory have independent histories: each unique
-- item is an instance identified by uid. The blob has NO file of its own: it
-- travels embedded in the file of whoever owns it (CRG-56), and `_live` is the
-- single runtime source of truth — the owner's `instances` field is a RENDER of
-- it, by reference, never a parallel copy (CRG-57). An instance the world owns
-- (trader stock, a session crate, a dropped item) never reaches disk at all: it
-- dies with the map, which restarts the Lua state wholesale (CRG-59).
--
-- There are TWO owners today and they share ONE routine (RenderOwner /
-- HydrateOwner, below): the player record and the container that declared a
-- persistKey. Everything else is world state and stays in _live.
--
-- Cargo initializes the generic minimum (condition, zones, sub-slots, ammo
-- group) and TRANSPORTS everything else — the owner module defines what the
-- fields mean (CRG-1).

local CARGO = Corpus.GetModule("cargo")

CARGO.Instances = CARGO.Instances or {}
CARGO.Instances._live = CARGO.Instances._live or {}   -- uid -> blob (loaded)
CARGO.Instances._counter = CARGO.Instances._counter or 0

-- uid charset is [a-z0-9_] by construction — valid as a Corpus.Data key.
-- os.time() + per-boot counter: unique within a boot by the counter, across
-- boots by the clock.
local function NewUid()
    CARGO.Instances._counter = CARGO.Instances._counter + 1
    return string.format("i%d_%d", os.time(), CARGO.Instances._counter)
end

-- seed: optional table merged over the generic blob (owner-module fields,
-- or a full blob when rehydrating from a drop/container).
function CARGO.Instances.Create(defId, seed)
    local def = CARGO.Items.Get(defId)
    if def == nil then
        error("Cargo.Instances.Create: unknown item def '" .. tostring(defId) .. "'", 2)
    end
    if def.class ~= "unique" then
        error("Cargo.Instances.Create: '" .. defId .. "' is stackable, it has no instances", 2)
    end

    local blob = { id = defId }

    -- Generic minimum (§3): Cargo initializes, owner module mutates.
    if def.has_condition then blob.condition = 100 end
    if istable(def.condition_zones) then
        blob.zones = {}
        for _, zone in ipairs(def.condition_zones) do blob.zones[zone] = 100 end
    end
    if istable(def.subslots) then blob.subslots = {} end
    -- ammo group only makes sense on things that feed on ammo — a melee
    -- weapon_class alone must not grow an "A" badge
    if istable(def.ammo) or def.category == "weapons" then blob.ammo_group = "A" end

    if istable(seed) then table.Merge(blob, seed) end
    blob.id = defId -- the def link is not seed-overridable

    local uid = NewUid()
    CARGO.Instances._live[uid] = blob
    -- a brand-new instance writes NOTHING (CRG-56): at this point nobody knows
    -- yet whether it belongs to a player or to the map. It reaches disk only if
    -- an owner record renders it on save.
    return uid, blob
end

-- `_live` is the whole truth (CRG-57). A uid that is not here does not exist:
-- hydration happens in ONE place, when the owner record loads, never one file
-- per read.
function CARGO.Instances.Get(uid)
    if not isstring(uid) then return nil end
    return CARGO.Instances._live[uid]
end

-- Dropping the blob from memory is the whole deletion: with no file of its own
-- there is nothing to unlink, and the owner's next save renders `instances`
-- from scratch, so an unreferenced uid leaves the file by itself.
function CARGO.Instances.Delete(uid)
    CARGO.Instances._live[uid] = nil
end

-- ------------------------------------------------------------------
-- OWNER SERIALIZATION — the single routine (CRG-56/57/58)
--
-- An owner is anything that holds entries and carries its blobs with it: the
-- player record (`inv_<steamid64>`) and the persistent container
-- (`cont_<key>`) serialize through THESE two functions, not through a copy
-- each. An owner is just a table with the entry lists it happens to have plus
-- an `instances` map — the reachability walk branches on istable() per list,
-- so a container, which only has `items`, passes through untouched.
--
-- They live HERE and not in the inventory on purpose: they belong to the owner
-- of the blobs, and the point of this pass is that the inventory stops being
-- their seat.
-- ------------------------------------------------------------------

-- Rebuilds `owner.instances` FROM SCRATCH from _live, by reference. Rebuilding
-- instead of patching is the point (CRG-56): a uid that stopped being
-- referenced leaves the file on its own, with no explicit delete and no
-- sweeper. That is why the orphan class cannot exist any more.
--
-- The reachability walk is resolved at CALL time: it lives in inventory.lua,
-- which the manifest loads after this file. Reaching for it at file scope
-- would read a nil.
function CARGO.Instances.RenderOwner(owner)
    if not istable(owner) then return {} end

    local instances = {}
    for uid in pairs(CARGO.Inventory.CollectInstances(owner)) do
        local blob = CARGO.Instances._live[uid]
        if istable(blob) then instances[uid] = blob end
    end
    owner.instances = instances
    return instances
end

-- Pushes the blobs that came in the file into _live WITHOUT COPYING:
-- `owner.instances[uid]` and `_live[uid]` stay THE SAME TABLE (CRG-57). That
-- identity is what makes the divergence CRG-57 forbids impossible — a module
-- mutating one mutates the other. Same spirit as the by-ref invariant COR-7: a
-- "defensive" copy here breaks persistence in silence.
--
-- Returns the set of uids that ARRIVED, so the caller can drop the entries
-- whose blob did not (honest degradation, cites COR-5). The drop stays in each
-- caller because each owner has a different set of lists to sweep.
function CARGO.Instances.HydrateOwner(owner)
    local arrived = {}
    if not istable(owner) then return arrived end

    owner.instances = istable(owner.instances) and owner.instances or {}
    for uid, blob in pairs(owner.instances) do
        if isstring(uid) and istable(blob) then
            CARGO.Instances._live[uid] = blob
            arrived[uid] = true
        end
    end
    return arrived
end

-- The ONE-ENTRY owner. A world drop owns exactly one entry — the item entity,
-- or the real SWEP a dropped gun is — and renders through the SAME routine the
-- two files use, by reference (CRG-57), so a condition that changes while it
-- lies there is the one that gets saved. Sub-slot content rides inside, because
-- the reachability walk is the same one.
function CARGO.Instances.RenderEntry(entry)
    local owner = { items = { entry } }
    CARGO.Instances.RenderOwner(owner)
    return owner.instances
end

-- ------------------------------------------------------------------
-- SAVEGAME RE-MINT (CRG-60, §12)
--
-- A savegame gives an entity its flat state back, blobs included: the marker
-- an entity carries IS a rendered owner (Containers.Save renders on every
-- write, precisely so that it is). What a save CANNOT bring back is the uid —
-- it is unique per BOOT and not globally, so reusing one is a collision
-- waiting to happen (same reason the import of B5 re-uids).
--
-- So a blob that arrives from another session is CREATED AGAIN with a new uid
-- and the entries are rewritten to point at it. Recursive, because a vest
-- carries its plates in `subslots` and those entries name uids too — the same
-- reachability the owner file walks.
--
-- Honest degradation (cites COR-5), the same rule both owner files apply: an
-- entry whose blob did not travel, or whose def this boot does not know (a
-- pack that is no longer mounted), is dropped with a log instead of coming
-- back as a weightless ghost.
--
-- The invariant this serves is of VALUE, not of moment: the caller asks "is
-- this uid possible in this session?", never "when did the duplicator write
-- this?" — an order that is not observable from outside the game (B3, six
-- rounds).
-- ------------------------------------------------------------------

function CARGO.Instances.Remint(entries, blobs)
    local out = {}
    if not istable(entries) then return out end
    blobs = istable(blobs) and blobs or {}

    -- `seen` is the cycle guard, same reason CollectInstances keeps one:
    -- nothing forbids a blob graph that closes on itself, and this walk
    -- creates as it goes.
    local function mint(uid, seen)
        local blob = blobs[uid]
        if not istable(blob) or seen[uid] then return nil end
        seen[uid] = true

        local def = CARGO.Items.Get(blob.id)
        if def == nil or def.class ~= "unique" then return nil end

        -- copy, never the arrived table: it is dead data from another session
        -- and Create keeps whatever the seed carries
        local seed = table.Copy(blob)
        if istable(seed.subslots) then
            for slotId, list in pairs(seed.subslots) do
                local kept = {}
                for _, e in ipairs(istable(list) and list or {}) do
                    if istable(e) and e.uid == nil then
                        kept[#kept + 1] = e
                    elseif istable(e) then
                        local sub = mint(e.uid, seen)
                        if sub ~= nil then kept[#kept + 1] = { id = e.id, uid = sub } end
                    end
                end
                seed.subslots[slotId] = kept
            end
        end

        return (CARGO.Instances.Create(blob.id, seed))
    end

    for _, entry in ipairs(entries) do
        if istable(entry) and entry.uid == nil then
            out[#out + 1] = entry
        elseif istable(entry) then
            local uid = mint(entry.uid, {})
            if uid == nil then
                Corpus.Log("cargo", "Instances.Remint: entrada sin blob o con def desconocida (uid "
                    .. tostring(entry.uid) .. "), descartada")
            else
                out[#out + 1] = { id = entry.id, uid = uid }
            end
        end
    end
    return out
end

-- Weight of an instance = its def + everything mounted in its sub-slots
-- (plates and accessories weigh; nested unique entries recurse).
-- the attachment tree of §10 weighs like everything else that is mounted; it
-- nests, so it recurses (roadmap #53)
function CARGO.Instances.AttsWeight(atts)
    if not istable(atts) then return 0 end
    local total = 0
    for _, node in ipairs(atts) do
        if istable(node) and isstring(node.att) then
            local def = CARGO.Items.Get(CARGO.ARC9.ItemId(node.att))
            total = total + (istable(def) and def.weight or 0)
            total = total + CARGO.Instances.AttsWeight(node.sub)
        end
    end
    return total
end

-- The rounds LOADED in the magazine weigh, and they weigh the same as they did
-- on the belt (roadmap #56, CRG-67). Before this, the same 30 rounds weighed
-- 0.36 kg hanging off the belt and 0 kg inside the gun, so reloading was a
-- discount — and with an RPG it was a three-kilo one.
--
-- `blob.clip1` is a bare integer with no ammo type in it (that is what #18
-- persists), so the type comes from the weapon CLASS via Ammo.TypeOfClass:
-- §16.2's rule that the real type comes from the ENTITY still holds, and this
-- is the answer for the case that rule does not cover — a gun in the grid has
-- no entity to ask. A class Cargo cannot resolve, or one that eats a type
-- Cargo does not manage, weighs its rounds at 0: honest degradation, never an
-- invented number (cites COR-5).
function CARGO.Instances.ClipWeight(blob)
    if not istable(blob) then return 0 end
    if not isnumber(blob.clip1) or blob.clip1 <= 0 then return 0 end

    local def = CARGO.Items.Get(blob.id)
    if not istable(def) or not isstring(def.weapon_class) then return 0 end

    local hl2 = CARGO.Ammo.TypeOfClass(def.weapon_class)
    if hl2 == nil then return 0 end

    return blob.clip1 * CARGO.Ammo.WeightPerRound(hl2)
end

function CARGO.Instances.WeightOf(uidOrBlob)
    local blob = isstring(uidOrBlob) and CARGO.Instances.Get(uidOrBlob) or uidOrBlob
    if not istable(blob) then return 0 end

    local def = CARGO.Items.Get(blob.id)
    local total = (istable(def) and def.weight or 0) + CARGO.Instances.ClipWeight(blob)

    if istable(blob.subslots) then
        for _, entries in pairs(blob.subslots) do
            for _, entry in ipairs(entries) do
                if entry.uid then
                    total = total + CARGO.Instances.WeightOf(entry.uid)
                else
                    local subDef = CARGO.Items.Get(entry.id)
                    total = total + (istable(subDef) and subDef.weight or 0)
                end
            end
        end
    end

    -- blob.atts DELIBERATELY DOES NOT WEIGH — author call 2026-07-31, planilla
    -- AB round 2, reversing the 2026-07-30 one after seeing the numbers.
    --
    -- The flat 0.3 kg nominal per attachment does not survive contact with a
    -- real EFT build: his MCX 5.56 weighs 2.9 kg and carries TWELVE
    -- attachments, so the parts would outweigh the gun 3.6 to 2.9. That is not
    -- a tuning problem, it is the wrong model — in an EFT build most slots hold
    -- structural pieces (receiver, barrel, handguard, dust cover, sights) that
    -- are the gun, not cargo hanging off it.
    --
    -- Deferred rather than patched with a smaller number: the fix is to decide
    -- WHICH categories carry weight (STALKER GAMMA charges optics, silencers,
    -- launchers, tactical devices, foregrips and extended magazines — never the
    -- structure) and that needs its own pass. Roadmap #55. The recursion below
    -- stays exactly where a category filter will plug in.
    --
    -- AttsWeight is kept and exercised offline on purpose: the decision was
    -- "not yet", not "wrong", and deleting it would make the next pass rewrite
    -- what already works.
    --
    -- The LOADED ROUNDS are a different question and they are already in the
    -- sum above (ClipWeight, roadmap #56): #55 weighs the magazine as a PIECE,
    -- this weighs the bullets inside it. When #55 lands, the weight it gives an
    -- extended mag has to be the EMPTY mag, or the rounds get counted twice.

    return total
end

-- ------------------------------------------------------------------
-- What an instance weighs ON THE WIRE (roadmap #58), and nil when there is
-- nothing to say.
--
-- The tooltip painted `def.weight` — the weight of the CLASS. A loaded RPG
-- added 9 kg to the total and showed 6 on its own card. It is NOT new (a vest
-- with two plates behaved the same since Block 1, because WeightOf recurses and
-- the tooltip did not), but the #56 made it visible: now the number changes on
-- its own, without the player mounting anything. Author's ask, planilla AC,
-- note of AC3: "el tooltip deberia reflejar el peso que tiene el arma por
-- efectos de la municion en el cargador".
--
-- IT RIDES ONLY WHEN IT DIFFERS, exactly like the `fav` of #43: an empty rifle
-- weighs its def and there is no second number worth sending. The client falls
-- back to `def.weight`, so an absent field means "the class weight IS the
-- truth" and not "nobody computed it".
--
-- ⚠ AND IT HAS TO RIDE FROM EVERY WIRE SITE, which is the whole reason this is
-- a function and not a line. FOUR places build an entry carrying a blob that a
-- client will draw: the grid, the equipment slots, the container column and the
-- trader's STOCK. The tooltip draws on all four. Sending it from one would make
-- the SAME rifle read 9 kg in the bag and 6 kg in the crate: a worse defect
-- than the one being fixed, because the number would depend on which window the
-- player happened to open. That is the #76 defect wearing a different hat, and
-- it is caught here by a per-file call-site count and not by good intentions
-- (lesson 89: a helper nobody calls from all four sites measures nothing).
--
-- IT IS FOUR AND NOT FIVE, and the difference is worth writing down because it
-- was measured and not assumed: the trade screen has two grids, but the
-- player's own column reads the INVENTORY snapshot (site 1) — only the stock is
-- its own. And `Priceable` in the trade server LOOKS like a fifth: same shape,
-- same blob. It is not a wire site — it feeds ConditionOfEntry for the price
-- and never leaves the server, so a weight on it would be a field nobody reads.
--
-- The comparison is against an EPSILON and not `~=`: both sides are floats
-- built by summing, so an instance carrying nothing can land a hair off its own
-- def and would ride a "different" weight that renders identical.
function CARGO.Instances.SnapWeight(blob)
    if not istable(blob) then return nil end
    local def = CARGO.Items.Get(blob.id)
    if not istable(def) then return nil end
    local w = CARGO.Instances.WeightOf(blob)
    if math.abs(w - (def.weight or 0)) < 0.001 then return nil end
    return w
end
