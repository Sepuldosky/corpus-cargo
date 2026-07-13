-- corpus_cargo_ammo.lua — HL2 ammunition items + caliber map (SHARED)
-- Cargo_Architecture.md §16 (ammo system, roadmap #19).
--
-- THE MODEL (author call 2026-07-12): the ammo BELT is the player's real
-- reserve. A belt stack is not a copy of the pool — it IS the pool, mirrored
-- per HL2 engine ammo type (server/corpus_cargo_ammopool.lua keeps both sides
-- equal). The grid is only storage. Weapons of the same HL2 type SHARE the
-- reserve (like HL2 itself, like STALKER); what stays per-weapon is the
-- MAGAZINE (Clip1), which already persists in the instance blob (roadmap #18).
--
-- WHY THE ENGINE TYPE IS THE POOL KEY AND THE CALIBER IS NOT: ARC9 weapons
-- declare SWEP.Ammo as a plain HL2 type ("pistol"), and ARC9's reserve IS the
-- native pool — SWEP:Ammo1() is literally
-- ply:GetAmmoCount(self:GetProcessedValue("Ammo")) (Arc9 Base sh_reload.lua:578-586,
-- verified against the live code 2026-07-12). Two ARC9 EFT weapons of
-- "different" calibers therefore share one HL2 type. So `hl2` is the truth and
-- `caliber` is a DISPLAY label (it is what the A/B belt badge groups on).
--
-- Every .mdl below was verified to exist by parsing the real VPKs
-- (sourceengine/hl2_misc_dir.vpk, garrysmod/garrysmod_dir.vpk) — the same rule
-- this project applies to ARC9 names: paths are never trusted from memory.
-- They are also the models HL2's own item_ammo_* entities use, so a box on the
-- floor and its inventory item look like the same object.

local CARGO = Corpus.GetModule("cargo")

CARGO.Ammo = CARGO.Ammo or {}

-- max_stack is what makes the belt a real decision. With six slots and no
-- ceiling, one bottomless slot per caliber would be enough and the other five
-- would be decoration; with a ceiling, how much of which caliber you hang on
-- the belt is a choice you pay for in slots and in weight (STALKER's bargain).
local AMMO = {
    { hl2 = "Pistol",       caliber = "9x19",  name = "Pistol Rounds",
      model = "models/items/boxsrounds.mdl",
      weight = 0.012, max_stack = 120,
      trivia = "Standard 9x19mm pistol cartridge. The most common round there is." },

    { hl2 = "SMG1",         caliber = "4.6x30", name = "SMG Rounds",
      model = "models/items/boxmrounds.mdl",
      weight = 0.012, max_stack = 120,
      trivia = "Submachine gun ammunition. Cheap, plentiful, and gone before you notice." },

    -- the two AR2 models are easy to cross (in-game report 2026-07-12: they were):
    -- the CARTRIDGE is the rifle magazine, the AMMO01 ball is the alt-fire orb.
    -- HL2's own item_ammo_ar2 / item_ammo_ar2_altfire pair them this way.
    { hl2 = "AR2",          caliber = "Dark Energy", name = "Pulse Rounds",
      model = "models/items/combine_rifle_cartridge01.mdl",
      weight = 0.02, max_stack = 60,
      trivia = "Overwatch pulse ammunition. Not manufactured by anything human." },

    { hl2 = "Buckshot",     caliber = "12ga",  name = "Shotgun Shells",
      model = "models/items/boxbuckshot.mdl",
      weight = 0.05, max_stack = 40,
      trivia = "12 gauge buckshot. Heavy for what it is; devastating up close." },

    { hl2 = "357",          caliber = ".357",  name = ".357 Rounds",
      model = "models/items/357ammo.mdl",
      weight = 0.02, max_stack = 24,
      trivia = "Magnum revolver ammunition. Few rounds, no complaints." },

    { hl2 = "XBowBolt",     caliber = "Bolt",  name = "Crossbow Bolts",
      model = "models/items/crossbowrounds.mdl",
      weight = 0.15, max_stack = 12,
      trivia = "Rebar cut to length and heated red. Silent, and usually enough." },

    { hl2 = "RPG_Round",    caliber = "84mm",  name = "RPG Rockets",
      model = "models/weapons/w_missile_closed.mdl",
      weight = 3.0, max_stack = 2,
      trivia = "Laser-guided rocket. You will feel every one of these in your back." },

    { hl2 = "SMG1_Grenade", caliber = "40mm",  name = "SMG Grenades",
      model = "models/items/ar2_grenade.mdl",
      weight = 0.25, max_stack = 5,
      trivia = "Underslung launcher grenade. Arcs further than it looks like it should." },

    { hl2 = "AR2AltFire",   caliber = "Orb",   name = "Dark Energy Orbs",
      model = "models/items/combine_rifle_ammo01.mdl",
      weight = 0.5, max_stack = 3,
      trivia = "Contained singularity. Carrying it is the second worst idea; firing it is the first." },
}

-- THROWABLE-faced types (roadmap #32, in-game report 2026-07-13): the HL2
-- "Grenade" and "slam" pools are still MANAGED types — throwing drains them
-- through the same §16 mirror — but their canonical item is a THROWABLE for
-- the equipment slot (§4 amendment), never belt ammunition. Bloque B had
-- registered them as belt items and the mirror minted frags-as-ammo whenever
-- the engine granted the type (spawnmenu give, death respawn). The SMG1
-- launcher grenade stays in AMMO above: it feeds a weapon, you don't throw it.
-- (SLAM rides the same call — the handoff's dirección, same conflict shape.)
local THROWABLES = {
    { hl2 = "Grenade", caliber = "Frag", id = "cargo_throw_frag",
      name = "Frag Grenade", weapon_class = "weapon_frag",
      model = "models/weapons/w_grenade.mdl",
      weight = 0.4, max_stack = 4, size = { 1, 2 },
      trivia = "MK3A2 fragmentation grenade. Equip the stack; the count is your reserve." },

    { hl2 = "slam",    caliber = "SLAM", id = "cargo_throw_slam",
      name = "S.L.A.M.", weapon_class = "weapon_slam",
      model = "models/weapons/w_slam.mdl",
      weight = 1.2, max_stack = 3, size = { 2, 1 },
      trivia = "Selectable Lightweight Attack Munition. Tripmine or remote charge, your call." },
}

-- Ordered list of the engine ammo types Cargo manages: the pool reconciler and
-- the death wipe walk exactly this list, and nothing outside it is touched.
CARGO.Ammo.TYPES = {}

local idByType = {}  -- lowercase engine type -> Cargo item id

for _, a in ipairs(AMMO) do
    local id = "cargo_ammo_" .. a.hl2:lower()

    CARGO.Items.Register({
        id = id,
        name = a.name,
        weight = a.weight,
        class = "stackable",
        category = "ammo",
        model = a.model,
        max_stack = a.max_stack,
        size = { 2, 1 },  -- the ammo category ceiling (Cargo_ItemImages §5)
        ammo = { caliber = a.caliber, hl2 = a.hl2 },
        trivia = a.trivia,
    })

    CARGO.Ammo.TYPES[#CARGO.Ammo.TYPES + 1] = a.hl2
    idByType[a.hl2:lower()] = id
end

-- weapon_class -> canonical throwable item id. The capture consults this so a
-- frag/SLAM SWEP never mints a wpn_<class> autogen item (that would resurrect
-- the second face this front kills); the mirror books the rounds instead.
CARGO.Ammo.ThrowableClass = {}

for _, t in ipairs(THROWABLES) do
    CARGO.Items.Register({
        id = t.id,
        name = t.name,
        weight = t.weight,
        class = "stackable",
        category = "throwables",
        model = t.model,
        max_stack = t.max_stack,
        size = t.size,
        weapon_class = t.weapon_class,
        ammo = { caliber = t.caliber, hl2 = t.hl2 },
        trivia = t.trivia,
    })

    CARGO.Ammo.TYPES[#CARGO.Ammo.TYPES + 1] = t.hl2
    idByType[t.hl2:lower()] = t.id
    CARGO.Ammo.ThrowableClass[t.weapon_class] = t.id
end

-- Dead ids -> canonical throwable. Consumed by the record/container loaders:
-- Bloque B's belt faces and the entry-13 dev item persisted in real records
-- (the author's own), and an unknown id renders as a blank cell.
CARGO.Ammo.LegacyThrowIds = {
    cargo_ammo_grenade = "cargo_throw_frag",
    cargo_ammo_slam    = "cargo_throw_slam",
    cargo_dev_frag     = "cargo_throw_frag",
    -- autogen uniques a pre-#32 capture may have minted for these classes
    wpn_weapon_frag    = "cargo_throw_frag",
    wpn_weapon_slam    = "cargo_throw_slam",
}

-- Engine ammo type -> the Cargo item that carries it. nil for any type Cargo
-- does not manage (another addon's custom ammo: not ours, not touched).
-- Lookup is case-insensitive because ARC9 spells it "pistol" and HL2 spells it
-- "Pistol", and GetAmmoCount happily takes either.
function CARGO.Ammo.ItemForType(hl2)
    if not isstring(hl2) then return nil end
    return idByType[hl2:lower()]
end

-- Item def -> the engine ammo type it feeds. nil for anything that is not
-- ammunition (a weapon def also carries def.ammo, but only as a display label:
-- its real type comes from the weapon entity, never from here).
function CARGO.Ammo.TypeOfDef(def)
    if not istable(def) or not istable(def.ammo) then return nil end
    if not isstring(def.ammo.hl2) then return nil end
    return def.ammo.hl2
end

function CARGO.Ammo.Managed(hl2)
    return CARGO.Ammo.ItemForType(hl2) ~= nil
end
