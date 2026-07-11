-- corpus_cargo_slots.lua — equipment slot table (SHARED, data only, no UI)
-- Cargo_Architecture.md §4. First-level slots + quick slot availability.
-- Slot acceptance reuses the same category-filter grammar as sub-slots
-- (CARGO.Items.MatchesFilter) — one matcher for the whole module.

local CARGO = Corpus.GetModule("cargo")

CARGO.Slots = CARGO.Slots or {}

-- Order here is the render order of the equipment panel (mockup
-- InventarioCargo.png): Head/Body/Back row, weapon rows, accessory row.
CARGO.Slots.List = {
    { id = "head",      label = "Head",      filter = "category:helmets" },
    { id = "body",      label = "Body",      filter = "category:armor" },
    { id = "back",      label = "Back",      filter = "category:backpacks" },
    { id = "primary",   label = "Primary",   filter = "category:weapons" },
    { id = "secondary", label = "Secondary", filter = "category:weapons" },
    { id = "sidearm",   label = "Sidearm",   filter = "category:weapons" },
    { id = "melee",      label = "Melee",       filter = "category:melee" },
    -- generic accessory slots: PDA/Detector are STALKER furniture, Corpus is
    -- setting-agnostic (author call, first in-game pass 2026-07-10)
    { id = "accessory1", label = "Accessory 1", filter = "category:accessories" },
    { id = "accessory2", label = "Accessory 2", filter = "category:accessories" },
}

CARGO.Slots.ById = {}
for _, slot in ipairs(CARGO.Slots.List) do
    CARGO.Slots.ById[slot.id] = slot
end

-- Quick slots F1-F4: availability (not content) is gated by the Body item,
-- like the reference STALKER artifact belt. With no suit equipped, the
-- convar base applies; a suit's def.quick_slots overrides it.
CARGO.Slots.QUICK_COUNT = 4

local cvQuickBase = CreateConVar("cargo_quick_base", "2",
    bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
    "Quick slots (F1-F4) unlocked with no suit equipped", 0, 4)

-- bodyDef: def of the item equipped in Body, or nil
function CARGO.Slots.QuickUnlocked(bodyDef)
    local n = cvQuickBase:GetInt()
    if istable(bodyDef) and isnumber(bodyDef.quick_slots) then
        n = bodyDef.quick_slots
    end
    return math.Clamp(math.floor(n), 0, CARGO.Slots.QUICK_COUNT)
end

-- Equip validation: slot filter + optional def.equip_slots narrowing.
-- Only unique items equip (a stack cannot occupy a slot); plates and other
-- stackables mount through sub-slots instead.
function CARGO.Slots.CanEquip(def, slotId)
    local slot = CARGO.Slots.ById[slotId]
    if slot == nil or not istable(def) then return false end
    if def.class ~= "unique" then return false end
    if not CARGO.Items.MatchesFilter(def, slot.filter) then return false end

    if istable(def.equip_slots) then
        for _, allowed in ipairs(def.equip_slots) do
            if allowed == slotId then return true end
        end
        return false
    end
    return true
end
