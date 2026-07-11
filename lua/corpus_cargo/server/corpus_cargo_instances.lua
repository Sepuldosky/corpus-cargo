-- corpus_cargo_instances.lua — unique-item instance blobs (SERVER)
-- Cargo_Architecture.md §3 (instance blob) and §12 (one file per instance).
--
-- Two TOZ-34 in the same inventory have independent histories: each unique
-- item is an instance identified by uid, persisted as its own blob via
-- Corpus.Data (data/corpus/cargo/inst_<uid>.json). Cargo initializes the
-- generic minimum (condition, zones, sub-slots, ammo group) and TRANSPORTS
-- everything else — the owner module defines what the fields mean.

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
    CARGO.Instances.Save(uid)
    return uid, blob
end

function CARGO.Instances.Get(uid)
    if not isstring(uid) then return nil end
    local blob = CARGO.Instances._live[uid]
    if blob ~= nil then return blob end

    blob = Corpus.Data.Load("cargo", "inst_" .. uid)
    if blob ~= nil then CARGO.Instances._live[uid] = blob end
    return blob
end

function CARGO.Instances.Save(uid)
    local blob = CARGO.Instances._live[uid]
    if blob == nil then return end
    Corpus.Data.Save("cargo", "inst_" .. uid, blob)
end

-- Corpus.Data has no Delete primitive yet (candidate for the framework,
-- flagged in cargo_estado.md as boundary debt). Until it exists, the file
-- goes away through the file library, inside the module's own namespace.
function CARGO.Instances.Delete(uid)
    CARGO.Instances._live[uid] = nil
    file.Delete("corpus/cargo/inst_" .. uid .. ".json")
end

-- Weight of an instance = its def + everything mounted in its sub-slots
-- (plates and accessories weigh; nested unique entries recurse).
function CARGO.Instances.WeightOf(uidOrBlob)
    local blob = isstring(uidOrBlob) and CARGO.Instances.Get(uidOrBlob) or uidOrBlob
    if not istable(blob) then return 0 end

    local def = CARGO.Items.Get(blob.id)
    local total = istable(def) and def.weight or 0

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
    return total
end
