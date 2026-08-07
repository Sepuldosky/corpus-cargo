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
-- Every HL2 .mdl below was verified to exist by parsing the real VPKs
-- (sourceengine/hl2_misc_dir.vpk, garrysmod/garrysmod_dir.vpk) — the same rule
-- this project applies to ARC9 names: paths are never trusted from memory.
-- They are also the models HL2's own item_ammo_* entities use, so a box on the
-- floor and its inventory item look like the same object.
--
-- The THREE types of roadmap #57 are the exception, and it is the reason that
-- point stayed open: HL2 has no item_ammo_* entity for them, so there is no
-- model to inherit. They ship with the addon (models/corpus_cargo/, CC BY 4.0
-- — docs/CREDITOS.md) and are the only ones here that are not Valve's.

local CARGO = Corpus.GetModule("cargo")

CARGO.Ammo = CARGO.Ammo or {}

-- max_stack is what makes the belt a real decision. With six slots and no
-- ceiling, one bottomless slot per caliber would be enough and the other five
-- would be decoration; with a ceiling, how much of which caliber you hang on
-- the belt is a choice you pay for in slots and in weight (STALKER's bargain).
-- `value` is the price of ONE round (Cargo_Trade §4: the price of a stack is
-- count x value x spread). Starting numbers, calibrated in play: common brass is
-- pocket change, Combine ordnance is a small fortune — scarcity IS the price.
local AMMO = {
    { hl2 = "Pistol",       caliber = "9x19",  name = "Pistol Rounds",
      model = "models/items/boxsrounds.mdl",
      weight = 0.012, max_stack = 120, value = 8,
      trivia = "Standard 9x19mm pistol cartridge. The most common round there is." },

    { hl2 = "SMG1",         caliber = "4.6x30", name = "SMG Rounds",
      model = "models/items/boxmrounds.mdl",
      weight = 0.012, max_stack = 120, value = 9,
      trivia = "Submachine gun ammunition. Cheap, plentiful, and gone before you notice." },

    -- the two AR2 models are easy to cross (in-game report 2026-07-12: they were):
    -- the CARTRIDGE is the rifle magazine, the AMMO01 ball is the alt-fire orb.
    -- HL2's own item_ammo_ar2 / item_ammo_ar2_altfire pair them this way.
    { hl2 = "AR2",          caliber = "Dark Energy", name = "Pulse Rounds",
      model = "models/items/combine_rifle_cartridge01.mdl",
      weight = 0.02, max_stack = 60, value = 45,
      trivia = "Overwatch pulse ammunition. Not manufactured by anything human." },

    { hl2 = "Buckshot",     caliber = "12ga",  name = "Shotgun Shells",
      model = "models/items/boxbuckshot.mdl",
      weight = 0.05, max_stack = 40, value = 14,
      trivia = "12 gauge buckshot. Heavy for what it is; devastating up close." },

    { hl2 = "357",          caliber = ".357",  name = ".357 Rounds",
      model = "models/items/357ammo.mdl",
      weight = 0.02, max_stack = 24, value = 30,
      trivia = "Magnum revolver ammunition. Few rounds, no complaints." },

    { hl2 = "XBowBolt",     caliber = "Bolt",  name = "Crossbow Bolts",
      model = "models/items/crossbowrounds.mdl",
      weight = 0.15, max_stack = 12, value = 40,
      trivia = "Rebar cut to length and heated red. Silent, and usually enough." },

    { hl2 = "RPG_Round",    caliber = "84mm",  name = "RPG Rockets",
      model = "models/weapons/w_missile_closed.mdl",
      weight = 3.0, max_stack = 2, value = 900,
      trivia = "Laser-guided rocket. You will feel every one of these in your back." },

    { hl2 = "SMG1_Grenade", caliber = "40mm",  name = "SMG Grenades",
      model = "models/items/ar2_grenade.mdl",
      weight = 0.25, max_stack = 5, value = 250,
      trivia = "Underslung launcher grenade. Arcs further than it looks like it should." },

    { hl2 = "AR2AltFire",   caliber = "Orb",   name = "Dark Energy Orbs",
      model = "models/items/combine_rifle_ammo01.mdl",
      weight = 0.5, max_stack = 3, value = 600,
      trivia = "Contained singularity. Carrying it is the second worst idea; firing it is the first." },

    -- ------------------------------------------------------------------
    -- ROADMAP #57 — the pools the live arsenal eats and Cargo did not manage.
    --
    -- WHAT WAS BROKEN, and it is older and bigger than the weight of a loaded
    -- magazine that made it visible: a type outside this table is a type the
    -- §16.3 mirror never looks at, so THE BELT DID NOT FEED THOSE WEAPONS at
    -- all. #56 only made it show up (their magazine weighed 0) and left it
    -- declared as a frontier. Author call (planilla AC, check AC6): they are
    -- REGISTERED AS ITEMS, not remapped onto a type that already has one.
    --
    -- Measured over the LIVE arsenal, not over dev/other/ which the roadmap
    -- warned covers ~2/3: the 380 subscribed .gma of 2026-08-06, index parsed
    -- and every .lua inside read. That census corrected two premises, so both
    -- corrections are written here and not just in the docs:
    --
    --   * "Winchester" IS NOT AN ENGINE AMMO TYPE. It does not exist in
    --     garrysmod/bin/win64/server.dll (AirboatGun, SniperRound and
    --     SniperPenetratedRound all do). It is TFA Base's PrintName for the
    --     AirboatGun pool: tfa_small_entities.lua registers tfa_ammo_winchester
    --     as "Winchester Ammo" with AmmoType = "AirboatGun", 50 rounds. So the
    --     ITEM is named Winchester (that is what the player already reads in
    --     game) and the POOL underneath it is AirboatGun. The id is derived
    --     from the pool, so it is `cargo_ammo_airboatgun` — that mismatch is
    --     deliberate, not a leftover.
    --   * THE ARC9 SNIPERS EAT SniperPenetratedRound, NOT SniperRound. Ten
    --     classes in the live arsenal: seven ARC9MW (kar98k, m14, spr208,
    --     ax50, hdr, rytec, svd) plus arc9_go's awp, scout and ssg08 — which
    --     dev/other/ could not see. SniperRound is a DIFFERENT pool with three
    --     eaters, all VJ (weapon_vj_ssg08 and Half-Life Resurgence's m40a1 and
    --     csniper), which is why both are registered and neither is remapped
    --     into the other: they are two engine pools and the mirror is per pool.
    --
    -- The two share ammo_sniper.mdl, so the NAME is what tells them apart in
    -- the cell (the lesson of the 61 NVG variants). AP/Ball is the engine's own
    -- distinction — the "penetrated" round is the one that goes through walls.
    { hl2 = "SniperPenetratedRound", caliber = "7mm MAG", name = "Sniper Rounds (AP)",
      model = "models/corpus_cargo/ammo_sniper.mdl",
      weight = 0.035, max_stack = 20, value = 55,
      trivia = "Armour-piercing rifle ammunition. It stops at the second wall, not the first." },

    { hl2 = "SniperRound",  caliber = "7.62x51", name = "Sniper Rounds (Ball)",
      model = "models/corpus_cargo/ammo_sniper.mdl",
      weight = 0.03, max_stack = 20, value = 45,
      trivia = "Plain jacketed rifle ammunition. Everything a marksman needs and nothing he'd brag about." },

    -- The caliber label is TFA's own (.308, the text printed on its box) and
    -- NOT the .44 Magnum the shipped model's art shows. Author call 2026-08-06,
    -- knowing the mismatch: the label follows the mod that hands these rounds
    -- out, and the model is a stand-in until a .308 box exists. Re-vesting it
    -- costs one call to Items.SetModel and no change here.
    { hl2 = "AirboatGun",   caliber = ".308",  name = "Winchester Rounds",
      model = "models/corpus_cargo/ammo_winchester.mdl",
      weight = 0.025, max_stack = 50, value = 28,
      trivia = "Hunting rifle ammunition. Older than everything shooting it, and still cheaper by the box." },
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
      weight = 0.4, max_stack = 4, size = { 1, 2 }, value = 160,
      trivia = "MK3A2 fragmentation grenade. Equip the stack; the count is your reserve." },

    { hl2 = "slam",    caliber = "SLAM", id = "cargo_throw_slam",
      name = "S.L.A.M.", weapon_class = "weapon_slam",
      model = "models/weapons/w_slam.mdl",
      weight = 1.2, max_stack = 3, size = { 2, 1 }, value = 250,
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
        value = a.value,  -- per ROUND (Cargo_Trade §4): the stack price is count x this
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
        value = t.value,  -- per grenade
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

-- ------------------------------------------------------------------
-- CLASS -> engine ammo type (roadmap #56). §16.2 says a weapon's REAL type
-- comes from its ENTITY and never from the def, and that stays true: this is
-- the answer for a weapon that HAS no entity — one stored in the grid, which
-- is a blob and a def id and nothing else. So it is not a second truth, it is
-- the CLASS DEFAULT, and the entity still wins wherever there is one.
--
-- Measured over dev/other/ (2026-07-31, 243 SWEP files, inheritance resolved):
-- 215 classes land on a type Cargo manages, 10 on a type it does not (7 ARC9MW
-- marksman rifles on "SniperPenetratedRound", the MW throwing knife, VJ's
-- ssg08), 6 on a "none"/-1 placeholder, and the 12 that resolve to NOTHING are
-- exactly base templates and melee/tools — things with no magazine.
-- Roadmap #57 CLOSED the sniper half of those 10 by registering the pools (see
-- the AMMO table): re-measured over the LIVE arsenal it was 13 classes, not 10,
-- and today the only ones still resolving to nothing are the per-nade custom
-- pools each ARC9 pack mints for its own throwables (arc9_cod2019_knife et al).
-- Those are a THROWABLE question (§16.9), not a belt one, and stay out.
--
-- WHY NOT Primary.Ammo FIRST, which is the obvious candidate: on ARC9 it is
-- EMPTY at class level. `SWEP.Primary.Ammo = SWEP.Ammo` runs when the base
-- file loads, with SWEP.Ammo still "" (Arc9 Base shared.lua:334-335), and only
-- Initialize fixes it PER INSTANCE. The wheel already pays for this in
-- AmmoTypeOf; same finding, other realm.
--
-- WHY GetStored AND NOT weapons.Get: weapons.Get deep-copies the whole SWEP,
-- attachment tables included, to read one string — we climb `.Base` ourselves,
-- the same call this module's icon pipeline already makes for the same reason.
-- ------------------------------------------------------------------

-- Engine weapons are not SWEPs at all: weapons.Get/GetStored return nil for
-- them (capture.lua pays for this twice already, in WeaponSlotKinds and
-- WeaponTrivia). So they need the same escape hatch, and this one carries the
-- headline case of the whole block: an RPG rocket weighs 3 kg.
--
-- CRG-24 applies to the ENGINE too (the lesson of #46): these are NOT written
-- from memory, they are the pairs HL2's own item_ammo_* entities feed, and
-- each one is measured in game before the block closes (planilla AC).
CARGO.Ammo.EngineWeaponTypes = {
    weapon_pistol    = "Pistol",
    weapon_357       = "357",
    weapon_smg1      = "SMG1",
    weapon_ar2       = "AR2",
    weapon_shotgun   = "Buckshot",
    weapon_crossbow  = "XBowBolt",
    weapon_rpg       = "RPG_Round",
    weapon_annabelle = "357",
    weapon_frag      = "Grenade",
    weapon_slam      = "slam",
}

-- class -> type | false. Memo is safe because its INPUT cannot change within a
-- boot: the registered SWEP tables are fixed once the packs mount. It is not
-- the convar-memo trap (a memo that hides live state); nothing here is live.
local typeForClass = {}

local function SwepAmmoField(class, depth)
    local s = weapons.GetStored(class)
    if not istable(s) then return nil end
    if isstring(s.Ammo) and s.Ammo ~= "" then return s.Ammo end
    -- non-ARC9 SWEPs (VJ, ZBase, plain scripted weapons) declare it here, and
    -- for them it is the real value
    if istable(s.Primary) and isstring(s.Primary.Ammo) and s.Primary.Ammo ~= ""
        and s.Primary.Ammo ~= "none" then
        return s.Primary.Ammo
    end
    local base = s.Base
    if isstring(base) and base ~= class and (depth or 0) < 10 then
        return SwepAmmoField(base, (depth or 0) + 1)
    end
    return nil
end

-- The engine ammo type a weapon CLASS feeds on, or nil when it has none or
-- Cargo does not manage it. Deliberately returns nil (never a guess) for the
-- unmanaged types: a round with no item behind it has no weight to claim.
function CARGO.Ammo.TypeOfClass(class)
    if not isstring(class) or class == "" then return nil end

    local memo = typeForClass[class]
    if memo ~= nil then return memo or nil end

    local hl2 = CARGO.Ammo.EngineWeaponTypes[class] or SwepAmmoField(class)
    -- a type with no Cargo item behind it resolves to nothing: not ours, not
    -- weighed, not invented (COR-5 in its weight-shaped form)
    if hl2 ~= nil and CARGO.Ammo.ItemForType(hl2) == nil then hl2 = nil end

    typeForClass[class] = hl2 or false
    return hl2
end

-- Exposed so a re-registration (a pack mounting late) cannot leave a stale
-- "this class has no ammo" behind. Nothing calls it in the normal path.
function CARGO.Ammo.ForgetClassTypes()
    typeForClass = {}
end

-- Weight of ONE round of an engine ammo type, straight off the item def that
-- carries it — there is no second table of per-round weights, and there must
-- not be: the belt stack and the magazine weigh the same round.
function CARGO.Ammo.WeightPerRound(hl2)
    local def = CARGO.Items.Get(CARGO.Ammo.ItemForType(hl2))
    return istable(def) and def.weight or 0
end

-- Engine ammo type -> the DISPLAY caliber label of the item that carries it
-- (roadmap #33: the wheel hub and the captured-weapon defs read it). It is
-- deliberately the label the belt groups on — an EFT rifle eating "smg1"
-- reads as the pool that actually feeds it, not as the trivia caliber EFT
-- buries in localization tokens (checked live: no clean API exposes those).
function CARGO.Ammo.CaliberForType(hl2)
    local def = CARGO.Items.Get(CARGO.Ammo.ItemForType(hl2))
    return istable(def) and istable(def.ammo) and def.ammo.caliber or nil
end
