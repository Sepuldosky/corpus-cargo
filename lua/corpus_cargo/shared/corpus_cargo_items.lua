-- corpus_cargo_items.lua — item contract + generic sub-slot primitive (SHARED)
-- Cargo_Architecture.md §3 (two item classes) and §4 (sub-slots).
--
-- Cargo owns the base schema, how an item is stored and how it renders.
-- The OWNER module keeps the semantics: what onUse does, how condition
-- degrades, what an instance blob means. Cargo transports those fields
-- without interpreting them (cardinal rule of the ecosystem).

local CARGO = Corpus.GetModule("cargo")

CARGO.Items = CARGO.Items or {}
CARGO.Items._defs = CARGO.Items._defs or {}
CARGO.Items._categories = CARGO.Items._categories or {}

-- ------------------------------------------------------------------
-- Categories. Open set: owner modules can register their own; unknown
-- categories referenced by an item def are auto-registered so the UI
-- always has a tab/label for them.
-- ------------------------------------------------------------------

function CARGO.Items.RegisterCategory(id, label, order)
    if not isstring(id) or id == "" then
        error("Cargo.Items.RegisterCategory: 'id' must be a non-empty string", 2)
    end
    CARGO.Items._categories[id] = {
        id = id,
        label = label or (id:sub(1, 1):upper() .. id:sub(2)),
        order = order or 100,
    }
end

-- Base set matching the mockup tab row (InventarioCargo.png). Equipment
-- categories get high order so consumable tabs stay first, like the mock.
-- Labels in English: the mod's player-facing language. Deliberately NO
-- pda/detector categories — those are STALKER-specific; Corpus stays
-- setting-agnostic with a generic "accessories" category (author call,
-- first in-game pass 2026-07-10).
CARGO.Items.RegisterCategory("weapons",     "Weapons",     10)
CARGO.Items.RegisterCategory("ammo",        "Ammo",        20)
CARGO.Items.RegisterCategory("medical",     "Medical",     30)
CARGO.Items.RegisterCategory("food",        "Food",        40)
CARGO.Items.RegisterCategory("attachments", "Attachments", 50)
CARGO.Items.RegisterCategory("optics",      "Optics",      55)
CARGO.Items.RegisterCategory("plates",      "Plates",      60)
CARGO.Items.RegisterCategory("helmets",     "Helmets",     70)
CARGO.Items.RegisterCategory("armor",       "Armor",       71)
CARGO.Items.RegisterCategory("backpacks",   "Backpacks",   72)
CARGO.Items.RegisterCategory("melee",       "Melee",       73)
CARGO.Items.RegisterCategory("accessories", "Accessories", 74)
CARGO.Items.RegisterCategory("misc",        "Misc",        90)

function CARGO.Items.GetCategories()
    local out = {}
    for _, cat in pairs(CARGO.Items._categories) do out[#out + 1] = cat end
    table.sort(out, function(a, b)
        if a.order == b.order then return a.id < b.id end
        return a.order < b.order
    end)
    return out
end

-- ------------------------------------------------------------------
-- Item registration.
--
-- Base schema (Cargo owns — Cargo_Architecture.md §3):
--   id       string, unique
--   name     string
--   weight   number (kg; per unit for stackables)
--   class    "stackable" | "unique"
--   category string (auto-registered if unknown)
--   icon     optional material path
--   display_stats  optional { <statKey> = signedPercent } — manual fallback
--                  when ARC9 is absent (§9); values ARE the deltas shown
--   trivia   optional string
--
-- Extended optional fields transported by Cargo (owner module semantics):
--   model          world model for drops (default cardboard box)
--   max_stack      stack ceiling (default: unlimited)
--   onUse          function(ply, ctx) -> true to consume one unit (SERVER)
--   weapon_class   engine weapon given/stripped on equip/unequip
--   equip_slots    { "primary", ... } narrows which matching slots accept it
--   capacity_bonus kg added to carry capacity while equipped in Back
--   quick_slots    quick slots unlocked while equipped in Body (0-4)
--   has_condition  instance/sub-slot entries start with condition = 100
--   condition_zones { "torso", ... } instance starts zones table at 100 each
--   ammo           { caliber = "9x19", types = { "FMJ", ... } }
--   effect_icon    small overlay tag drawn bottom-left ("hemostatic",
--                  "radiation", "battery" — free string, UI maps known ones)
--   material       display label for plate-like items (e.g. "Cerámica IV")
--
-- Icon system fields (Cargo_ItemImages §4/§5 — consumed client-side):
--   icon_model     optional model path to render for the icon, overriding
--                  the resolved one — escape hatch for weapons whose auto
--                  model (e.g. an ARC9 viewmodel) still frames badly
--   icon_cam       { pos = {x,y,z}, ang = {p,y,r}, fov = n } code-level
--                  camera override for the generated icon
--   size           { w, h } explicit cell footprint (allowed set, §5)
--   icon_override  runtime data override { cam = {...}, size = {w,h} },
--                  written by the dev editor (§8), persisted server-side
--                  and synced with the def snapshot (§10). Beats icon_cam
--                  and size: it exists to fix autogen defs with no code.
-- ------------------------------------------------------------------

local ITEM_CLASSES = { stackable = true, unique = true }

-- Stored and returned BY REFERENCE (same spirit as the Corpus registry
-- invariant): the owner module may keep populating its own def table.
function CARGO.Items.Register(def)
    if not istable(def) then
        error("Cargo.Items.Register: 'def' must be a table", 2)
    end
    if not isstring(def.id) or def.id == "" then
        error("Cargo.Items.Register: 'id' must be a non-empty string", 2)
    end
    if not isstring(def.name) or def.name == "" then
        error("Cargo.Items.Register: 'name' must be a non-empty string (item '" .. def.id .. "')", 2)
    end
    if not isnumber(def.weight) or def.weight < 0 then
        error("Cargo.Items.Register: 'weight' must be a number >= 0 (item '" .. def.id .. "')", 2)
    end
    if not ITEM_CLASSES[def.class] then
        error("Cargo.Items.Register: 'class' must be \"stackable\" or \"unique\" (item '" .. def.id .. "')", 2)
    end

    def.category = def.category or "misc"
    if CARGO.Items._categories[def.category] == nil then
        CARGO.Items.RegisterCategory(def.category)
    end

    if CARGO.Items._defs[def.id] ~= nil and CARGO.Items._defs[def.id] ~= def then
        -- expected on lua refresh; replace so the newest table wins
        Corpus.Log("cargo", "Items.Register: '" .. def.id .. "' re-registered; replacing previous def")
    end

    -- Precache the declared model: a prop the map never used is NOT in the
    -- precache table, and the drop entity / icon gate then read it as invalid
    -- (see Items.ModelUsable). Precaching also networks it to clients.
    if SERVER and isstring(def.model) and def.model ~= ""
        and file.Exists(def.model, "GAME") then
        util.PrecacheModel(def.model)
    end

    -- persisted icon overrides re-attach on (re-)register: autogen defs are
    -- rebuilt every session, but their editor adjustments must survive
    -- (Cargo_ItemImages §4.3). Server-only: clients receive the field with
    -- the def snapshot (§10).
    if SERVER and istable(CARGO.Items._iconOverrides)
        and CARGO.Items._iconOverrides[def.id] ~= nil then
        def.icon_override = CARGO.Items._iconOverrides[def.id]
    end

    CARGO.Items._defs[def.id] = def
    return def
end

function CARGO.Items.Get(id)
    return CARGO.Items._defs[id]
end

-- ------------------------------------------------------------------
-- Model resolution chain (CHANGELOG #3). Started life inside the drop
-- entity (corpus_cargo_item.lua); extracted here SHARED because the icon
-- system (Cargo_ItemImages §3) reuses the exact same chain client-side.
-- Returns a candidate model path or nil — the CALLER validates it against
-- the engine (util.IsValidModel) because validity is realm/content-bound.
-- ------------------------------------------------------------------

-- engine (HL2/base gmod) weapons are not scripted SWEPs, so their world
-- model can't be looked up — small known map so drops/icons look like the gun
local ENGINE_WMODELS = {
    weapon_pistol     = "models/weapons/w_pistol.mdl",
    weapon_357        = "models/weapons/w_357.mdl",
    weapon_smg1       = "models/weapons/w_smg1.mdl",
    weapon_ar2        = "models/weapons/w_irifle.mdl",
    weapon_shotgun    = "models/weapons/w_shotgun.mdl",
    weapon_crossbow   = "models/weapons/w_crossbow.mdl",
    weapon_frag       = "models/weapons/w_grenade.mdl",
    weapon_rpg        = "models/weapons/w_rocket_launcher.mdl",
    weapon_crowbar    = "models/weapons/w_crowbar.mdl",
    weapon_stunstick  = "models/weapons/w_stunbaton.mdl",
    weapon_physcannon = "models/weapons/w_physics.mdl",
    weapon_physgun    = "models/weapons/w_physics.mdl",
    weapon_slam       = "models/weapons/w_slam.mdl",
    gmod_tool         = "models/weapons/w_toolgun.mdl",
    gmod_camera       = "models/maxofs2d/camera.mdl",
}

-- def.model wins; then the scripted SWEP's WorldModel; then the engine map
function CARGO.Items.ResolveModel(def)
    if not istable(def) then return nil end
    if isstring(def.model) and def.model ~= "" then return def.model end
    if isstring(def.weapon_class) then
        local stored = weapons.GetStored(def.weapon_class)
        if stored and isstring(stored.WorldModel) and stored.WorldModel ~= "" then
            return stored.WorldModel
        end
        return ENGINE_WMODELS[def.weapon_class]
    end
    return nil
end

-- Can the engine actually show this model? `util.IsValidModel` ALONE is not a
-- sufficient gate: it answers false for models that exist in mounted content
-- but were never precached on the current map. In-game report 2026-07-12:
-- models/props_junk/garbage_takeoutcarton001a.mdl (a real HL2 prop, verified
-- present in hl2_misc_dir.vpk) silently fell back to the letter icon and to
-- the cardboard drop, while models/items/healthkit.mdl — precached because
-- HL2 registers item_healthkit — worked. The file check covers the
-- mounted-but-unprecached case; both together never let a bogus path through.
function CARGO.Items.ModelUsable(model)
    if not isstring(model) or model == "" then return false end
    if util.IsValidModel(model) then return true end
    return file.Exists(model, "GAME")
end

-- ------------------------------------------------------------------
-- Icon footprint data (Cargo_ItemImages §5). The footprint LOGIC lives in
-- the icon system (client); the allowed set and per-category ceilings live
-- here SHARED because the server validates editor overrides against them
-- (they are def-level data, synced like any def field — §10). Values are
-- the starting candidates from the spec; calibrated empirically in game.
-- ------------------------------------------------------------------

CARGO.Items.ICON_FOOTPRINTS = {
    { 1, 1 }, { 2, 1 }, { 1, 2 }, { 2, 2 }, { 3, 1 }, { 3, 2 },
    { 2, 3 }, { 4, 2 }, { 5, 2 }, { 6, 2 }, { 3, 3 }, { 4, 3 }, { 3, 4 },
}

-- per-category footprint ceiling {maxW, maxH}: keeps a badly scaled model
-- from inflating its cell. Categories not listed use "default".
CARGO.Items.ICON_CATEGORY_CAPS = {
    ammo    = { 2, 1 },
    medical = { 2, 2 },
    weapons = { 6, 2 },
    armor   = { 4, 4 },
    default = { 3, 3 },
}

-- per-category footprint FLOOR {minW, minH} (author calibration, first
-- fullscreen in-game pass 2026-07-12): flat weapon tiles (ARC9 crops
-- measured down to 3x1) read wrong in the tiered grid — a weapon occupies
-- at least a pistol's volume. Enforced in quantization and over persisted
-- footprint metas; explicit def.size / editor overrides stay authoritative.
CARGO.Items.ICON_CATEGORY_MINS = {
    weapons = { 3, 2 },
}

function CARGO.Items.IsAllowedFootprint(w, h)
    if not isnumber(w) or not isnumber(h) then return false end
    for _, fp in ipairs(CARGO.Items.ICON_FOOTPRINTS) do
        if fp[1] == w and fp[2] == h then return true end
    end
    return false
end

-- ------------------------------------------------------------------
-- Category filters. One tiny grammar shared by sub-slots (§4) and
-- equipment slots (corpus_cargo_slots.lua): "category:a,b" accepts any
-- item whose category is listed. Implemented ONCE — optic on Head,
-- exo/shield on Body and plate slots on Body all go through here.
-- ------------------------------------------------------------------

local function ParseFilter(filter)
    if not isstring(filter) then return nil end
    local kind, rest = filter:match("^(%w+):(.+)$")
    if kind ~= "category" or rest == nil then return nil end
    local set = {}
    for cat in rest:gmatch("[^,%s]+") do set[cat] = true end
    return set
end

function CARGO.Items.MatchesFilter(def, filter)
    if not istable(def) then return false end
    local set = ParseFilter(filter)
    if set == nil then return false end
    return set[def.category] == true
end

-- ------------------------------------------------------------------
-- Sub-slot primitive (Cargo_Architecture.md §4). An item def declares
-- N sub-slots, each with a category filter. The same primitive serves
-- Head->optic, Body->exo/shield and Body->plates; no ad-hoc variants.
--
-- Occupied sub-slots live in the instance blob as
--   blob.subslots[spec.id] = { { id = <itemId>, uid = ?, condition = ? }, ... }
-- and are ALWAYS ejected back to an inventory before the host instance
-- is destroyed (mandatory ejection rule, enforced server-side).
-- ------------------------------------------------------------------

function CARGO.Items.DeclareSubSlot(def, spec)
    if isstring(def) then def = CARGO.Items._defs[def] end
    if not istable(def) then
        error("Cargo.Items.DeclareSubSlot: 'def' must be a registered def table or item id", 2)
    end
    if not istable(spec) or not isstring(spec.id) or spec.id == "" then
        error("Cargo.Items.DeclareSubSlot: 'spec.id' must be a non-empty string", 2)
    end
    if ParseFilter(spec.filter) == nil then
        error("Cargo.Items.DeclareSubSlot: 'spec.filter' must look like \"category:a,b\" (sub-slot '" .. spec.id .. "')", 2)
    end

    def.subslots = def.subslots or {}
    for _, existing in ipairs(def.subslots) do
        if existing.id == spec.id then
            error("Cargo.Items.DeclareSubSlot: sub-slot '" .. spec.id .. "' already declared on '" .. tostring(def.id) .. "'", 2)
        end
    end

    def.subslots[#def.subslots + 1] = {
        id = spec.id,
        filter = spec.filter,
        maxItems = spec.maxItems or 1,
        label = spec.label or spec.id,
    }
    return def
end

function CARGO.Items.GetSubSlot(def, subId)
    if not istable(def) or not istable(def.subslots) then return nil end
    for _, spec in ipairs(def.subslots) do
        if spec.id == subId then return spec end
    end
    return nil
end
