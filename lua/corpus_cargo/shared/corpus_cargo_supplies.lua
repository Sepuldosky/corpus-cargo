-- corpus_cargo_supplies.lua — HL2 supply items + generic backpacks (SHARED)
-- Default content of the base framework (CHANGELOG #34, author call 2026-07-23).
-- Like the ammo set (§16), this gives a server with NO content addon a usable
-- baseline: the standard HL2 health/suit pickups as inventory items, plus two
-- generic backpacks for the Back slot.
--
-- The health/battery onUse closures apply the ENGINE pickup values
-- (sk_healthkit / sk_healthvial / sk_battery defaults) with the engine pickup
-- sounds — HL2 semantics, NOT medicine: wounds, blood and treatments are
-- Coagulant's domain and these items never touch them. Cargo owns these defs,
-- so their (engine-generic) semantics live here — CRG-1 stays intact.
--
-- The backpacks declare NO model on purpose: HL2 has no backpack prop, so they
-- drop as the cardboard box (the honest default) until a content addon
-- substitutes a real one via Items.SetModel (corpus_stalker does).
-- onUse registers in BOTH realms like every def (COR-12); it only RUNS on
-- server, and only there it touches health/armor.

local CARGO = Corpus.GetModule("cargo")

-- one gate per engine stat: at the ceiling the unit is NOT consumed (like the
-- HL2 entity, which refuses the touch instead of wasting the kit)
local function Heal(amount)
    return function(ply)
        if ply:Health() >= ply:GetMaxHealth() then
            Corpus.GetModule("cargo").Inventory.Notice(ply, "You are already at full health.")
            return false
        end
        ply:SetHealth(math.min(ply:Health() + amount, ply:GetMaxHealth()))
        return true
    end
end

CARGO.Items.Register({
    id = "cargo_hl2_healthkit", name = "Health Kit",
    weight = 0.5, class = "stackable", category = "medical",
    size = { 2, 2 }, max_stack = 5, value = 150,
    model = "models/items/healthkit.mdl",
    trivia = "Standard first aid kit. Restores up to 25 health on the spot.",
    onUse = function(ply)
        local ok = Heal(25)(ply)
        if ok then ply:EmitSound("HealthKit.Touch") end
        return ok
    end,
})

CARGO.Items.Register({
    id = "cargo_hl2_healthvial", name = "Health Vial",
    weight = 0.2, class = "stackable", category = "medical",
    size = { 1, 2 }, max_stack = 10, value = 60,
    model = "models/items/healthvial.mdl",
    trivia = "Small medical vial. Restores up to 10 health on the spot.",
    onUse = function(ply)
        local ok = Heal(10)(ply)
        if ok then ply:EmitSound("HealthVial.Touch") end
        return ok
    end,
})

CARGO.Items.Register({
    id = "cargo_hl2_battery", name = "Suit Battery",
    weight = 0.7, class = "stackable", category = "misc",
    size = { 2, 1 }, max_stack = 5, value = 120,
    model = "models/items/battery.mdl",
    effect_icon = "battery",
    trivia = "HEV suit energy cell. Charges the suit by 15, up to 100.",
    onUse = function(ply)
        if ply:Armor() >= 100 then
            Corpus.GetModule("cargo").Inventory.Notice(ply, "Suit energy is already full.")
            return false
        end
        ply:SetArmor(math.min(ply:Armor() + 15, 100))
        ply:EmitSound("ItemBattery.Touch")
        return true
    end,
})

-- Two sizes so picking a backpack is a real choice (weight and grid cost vs.
-- capacity), same bargain the belt ceilings buy for ammo. Starting numbers,
-- calibrated in play like every value/weight in the default set.
CARGO.Items.Register({
    id = "cargo_backpack_small", name = "Backpack",
    weight = 1.8, class = "unique", category = "backpacks",
    size = { 3, 3 }, value = 1500,
    has_condition = true, capacity_bonus = 12,
    trivia = "Simple travel pack. Adds +12 kg of carry capacity while equipped on Back.",
})

CARGO.Items.Register({
    id = "cargo_backpack_large", name = "Large Backpack",
    weight = 3.2, class = "unique", category = "backpacks",
    size = { 3, 3 }, value = 3200,
    has_condition = true, capacity_bonus = 24,
    trivia = "Expedition rucksack. Adds +24 kg of carry capacity while equipped on Back.",
})
