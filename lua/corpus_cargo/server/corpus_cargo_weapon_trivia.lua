-- corpus_cargo_weapon_trivia.lua — trivia overrides for weapons ARC9 fails to
-- describe (SERVER)
--
-- The tooltip's trivia paragraph is NOT a hand-written table by default. ARC9
-- SWEPs carry their own SWEP.Description — already resolved to a plain string
-- by ARC9:GetPhrase at file load — plus a SWEP.Trivia block (manufacturer,
-- caliber, action, country, year). corpus_cargo_capture.lua reads both straight
-- off weapons.Get(class), so EVERY ARC9 pack the server mounts, now or later,
-- gets a real description for free: no class of any future pack has to be
-- catalogued here. Verified against the live code of ARC9 base + the Darsu EFT
-- packs + ARC9MW (dev/other/, 2026-07-14).
--
-- This table is the exception list, and it exists for two distinct reasons:
--
--   1. GAPS. Some SWEPs ask for a phrase their own pack never wrote
--      ("eft_weapon_m16a1_desc" is absent from eft_en.lua), so SWEP.Description
--      resolves to nil and the weapon has nothing to say.
--   2. INHERITED LIES. weapons.Get() runs table.Inherit up the SWEP.Base chain,
--      so a gun with no description of its own silently adopts its PARENT's:
--      the M16A1 (Base = arc9_eft_m4a1) would introduce itself as an M4A1. A
--      one-line truth beats an inherited falsehood.
--
-- Keyed by weapon CLASS — same keys as corpus_cargo_weapon_weights.lua and
-- corpus_cargo_weapon_prices.lua — and loaded by the manifest BEFORE
-- capture.lua, so the boot re-registration of persisted autogen defs picks the
-- text up on the next map load. An entry here always WINS over the SWEP's own
-- description.
--
-- Player-facing strings: English (repo language rule).

local CARGO = Corpus.GetModule("cargo")

CARGO.Capture = CARGO.Capture or {}

CARGO.Capture.WeaponTrivia = {
    -- ------------------------------------------------------------------
    -- ARC9 EFT — no *_desc phrase in the pack (or one inherited from a
    -- different gun entirely)
    -- ------------------------------------------------------------------
    arc9_eft_m16a1 = "Colt M16A1. The 5.56 rifle the US Army carried through Vietnam: twenty-inch barrel, fixed stock, full-auto and no illusions about it. Its grandchildren are all over the Zone. The original still shoots.",
    arc9_eft_m16a2 = "Colt M16A2. The A1 grown up — heavier barrel, three-round burst in place of full-auto, and sights a marksman can actually work with.",
    arc9_eft_asval_mod4 = "AS VAL, Mod 4. The same integrally suppressed 9x39mm rifle under a modern rail-and-polymer rebuild. Subsonic, quiet, and still built to go through body armor.",
    arc9_eft_nl545_di = "Custom AK-545, direct impingement. A Kalashnikov rebuilt around an AR-pattern gas system and furniture — the parts bin of two rifles, and somehow it works.",
    arc9_eft_nl545_gp = "Custom AK-545, gas piston. The Kalashnikov keeps its long-stroke piston and takes everything else from the AR world: rails, stock, trigger.",
    arc9_eft_radian = "Radian Model 1. A precision AR-15 built by people who count grams and thousandths of an inch. It is priced accordingly.",
    arc9_eft_ak50 = "AK-50. A Kalashnikov scaled up around the .50 BMG — a prototype that has no business existing, chambered in a round meant for machine guns.",
    arc9_eft_mxlr = "MXLR. A long-range bolt gun built for exactly one thing: putting a round somewhere the shooter is not.",
    arc9_eft_rdg2b = "RDG-2B smoke grenade. Pull it, drop it, and a wall of grey buys you the ten seconds you needed.",

    -- ------------------------------------------------------------------
    -- ARC9 MW2019 — the pack describes its guns but not its equipment
    -- ------------------------------------------------------------------
    arc9_cod2019_la_m32 = "Milkor MGL. Six 40mm grenades in a revolver cylinder — an area weapon one man can carry and one man can regret.",
    arc9_cod2019_lm_minigun = "M134 Minigun. Six rotating barrels, an electric motor, and an appetite for ammunition no human back can feed for long.",
    arc9_cod2019_nade_c4 = "C4 charge. Plastic explosive and a remote detonator. It goes where you put it, and then it waits for you.",
    arc9_cod2019_nade_claymores = "M18A1 Claymore. Directional mine, tripwire-armed. FRONT TOWARD ENEMY is stamped on the case for a reason people keep discovering.",
    arc9_cod2019_nade_decoy = "Decoy grenade. Blanks and muzzle flashes for a few seconds. It kills nobody; it buys you the corner they were watching.",
    arc9_cod2019_nade_drillcharge = "Drill charge. Screws itself into a wall or a hull and detonates through it. Cover is a suggestion.",
    arc9_cod2019_nade_flash = "M84 flashbang. A million candela and a hundred and seventy decibels. Nobody dies. Nobody sees or hears, either.",
    arc9_cod2019_nade_frag = "M67 fragmentation grenade. Five seconds of fuze and a lethal radius nobody volunteers to measure.",
    arc9_cod2019_nade_gas = "Tear gas grenade. Fills a room with something that makes staying in that room impossible.",
    arc9_cod2019_nade_knife = "Throwing knife. Silent, retrievable, and it insists you be right the first time.",
    arc9_cod2019_nade_landmines = "Proximity mine. Arms itself, then waits for something with a heartbeat to walk past it.",
    arc9_cod2019_nade_molotov = "Molotov cocktail. A bottle, a rag, and a fire that does not care what your armor is rated for.",
    arc9_cod2019_nade_rock = "A rock. Throw it, make a noise somewhere you are not. The oldest trick in the Zone, and it still works.",
    arc9_cod2019_nade_semtex = "Semtex charge. It sticks to whatever it touches — a wall, a truck, a man — and after that it stops mattering what it touched.",
    arc9_cod2019_nade_smoke = "M18 smoke grenade. Grey cover on demand. It hides you from eyes. It does not hide you from thermal.",
    arc9_cod2019_nade_snapshot = "Snapshot grenade. Pings the room and paints whoever is standing in it for a second or two. Information, thrown.",
    arc9_cod2019_nade_stun = "Stun grenade. Less bang than a flashbang, more time on the target's legs. Enough to close the distance.",
    arc9_cod2019_nade_thermite = "Thermite grenade. It does not explode — it simply burns through whatever it is sitting on, engine block included.",
    arc9_cod2019_nade_thermite_alt = "Thermite charge. The same burn, thrown to stick. Whatever it lands on stops being structural.",

    -- ------------------------------------------------------------------
    -- HL2 / sandbox: the engine weapons are not SWEPs, so weapons.Get()
    -- has nothing to read for them — every line they show comes from here.
    -- The build tools are deliberately ABSENT: they are not gear and they
    -- are not lore, they are the sandbox.
    -- ------------------------------------------------------------------
    weapon_pistol = "9mm sidearm. Common, forgettable, and the only thing between you and a bad situation more often than anyone admits.",
    weapon_357 = ".357 Magnum revolver. Six rounds, no arguments. Reloading it takes exactly as long as you do not have.",
    weapon_smg1 = "9mm submachine gun with an underslung grenade launcher. Sprays cheap ammunition and carries one very expensive answer.",
    weapon_ar2 = "Overwatch Standard Issue pulse rifle. Not manufactured by anything human, and it does not pretend otherwise.",
    weapon_shotgun = "12-gauge pump shotgun. Ugly, slow to fill, and unanswerable at the end of a corridor.",
    weapon_crossbow = "Improvised crossbow firing red-hot rebar. Silent, and usually enough.",
    weapon_rpg = "Laser-guided rocket launcher. You will feel every one of these in your back, and so will whatever you point it at.",
    weapon_annabelle = "An old lever-action rifle with a name carved into the stock. Somebody loved it before you found it.",
    weapon_crowbar = "A crowbar. It opens doors, crates and arguments.",
    weapon_stunstick = "Civil Protection stun baton. Standard issue for people who were never asked to be reasonable.",
    weapon_slam = "Selectable Lightweight Attack Munition. Tripmine or remote charge, your call — and it is a call you make once.",
    weapon_bugbait = "A pheropod. Squeeze it and something underground decides you are a friend. Do not drop it.",
}
