-- corpus_cargo_weapon_prices.lua — base value (def.value) of auto-captured weapons (SERVER)
-- Cargo_Trade_Arquitectura.md §4: an item's price is value x condition x spread,
-- and an item with NO value is not tradeable. Captured weapons have no code of
-- their own (their def is autogen, corpus_cargo_capture.lua), so without this
-- table the bulk of the guns in play could never be sold or bought.
--
-- Same pattern — and the same class keys — as corpus_cargo_weapon_weights.lua:
-- keyed by weapon CLASS (PrintNames are localization-prone), loaded by the
-- manifest BEFORE capture.lua so the boot re-registration of persisted autogen
-- defs picks the value up on the next map load. Adding a class here is all it
-- takes to price any future capture.
--
-- SCALE (author calibration pending, in-game): the currency is whatever the
-- money provider says (native USD starts at $1000, cargo_money_start). Ranks
-- follow the STALKER/EFT economy in shape, not in absolute numbers — a pistol
-- is pocket change, an AR is a few runs of loot, a .338 rifle is a goal. These
-- are STARTING numbers: they are meant to be tuned in play, and the tuning is
-- one table edit (Cargo_Trade §11: "economía balanceada" is declared content
-- debt, not a mechanism).

local CARGO = Corpus.GetModule("cargo")

CARGO.Capture = CARGO.Capture or {}

CARGO.Capture.WeaponValues = {
    -- ------------------------------------------------------------------
    -- ARC9 EFT assault rifles / carbines
    -- ------------------------------------------------------------------
    arc9_eft_9a91            = 1400,
    arc9_eft_adar15          = 1100,
    arc9_eft_ak101           = 1900,
    arc9_eft_ak102           = 1900,
    arc9_eft_ak103           = 1800,
    arc9_eft_ak104           = 1800,
    arc9_eft_ak105           = 1800,
    arc9_eft_ak12            = 2400,
    arc9_eft_ak74            = 1200,
    arc9_eft_ak74m           = 1500,
    arc9_eft_akm             = 1300,
    arc9_eft_akms            = 1350,
    arc9_eft_aks74           = 1250,
    arc9_eft_aks74u          = 1000,
    arc9_eft_ash12           = 3600,
    arc9_eft_asval           = 2600,
    arc9_eft_asval_mod4      = 2900,
    arc9_eft_aug             = 2600,
    arc9_eft_auga1           = 2300,
    arc9_eft_g36             = 2400,
    arc9_eft_hk416           = 3000,
    arc9_eft_m16a1           = 1600,
    arc9_eft_m16a2           = 1700,
    arc9_eft_m4a1            = 2200,
    arc9_eft_mcx             = 2800,
    arc9_eft_mdr             = 2700,
    arc9_eft_mdr556          = 2500,
    arc9_eft_mk47_mutant     = 2600,
    arc9_eft_nl545_di        = 2300,
    arc9_eft_nl545_gp        = 2300,
    arc9_eft_radian          = 2700,
    arc9_eft_rd704           = 2000,
    arc9_eft_rpk16           = 2100,
    arc9_eft_sa58            = 2900,
    arc9_eft_sag_ak545       = 2200,
    arc9_eft_sag_ak545short  = 2100,
    arc9_eft_scarh           = 3200,
    arc9_eft_scarl           = 2800,
    arc9_eft_scarx17         = 3400,
    arc9_eft_spear           = 3800,
    arc9_eft_sr3             = 2400,
    arc9_eft_tx15            = 1500,
    arc9_eft_velociraptor    = 2600,
    arc9_eft_vpo136          = 800,
    arc9_eft_vpo209          = 800,
    arc9_eft_vsk94           = 2500,
    arc9_eft_vss             = 3000,

    -- ------------------------------------------------------------------
    -- ARC9 EFT snipers / marksman
    -- ------------------------------------------------------------------
    arc9_eft_ai_axmc         = 8000,
    arc9_eft_ak50            = 7000,
    arc9_eft_dvl10           = 5200,
    arc9_eft_m700            = 3400,
    arc9_eft_mosin_infantry  = 900,
    arc9_eft_mosin_sniper    = 1100,
    arc9_eft_mp18            = 500,
    arc9_eft_mxlr            = 4600,
    arc9_eft_sako_trg        = 5000,
    arc9_eft_sv98            = 4200,
    arc9_eft_t5000           = 6000,
    arc9_eft_vpo215          = 700,

    -- ------------------------------------------------------------------
    -- ARC9 EFT explosives (grenades + launchers)
    -- ------------------------------------------------------------------
    arc9_eft_f1              = 120,
    arc9_eft_f1_rd           = 140,
    arc9_eft_fn40gl          = 1800,
    arc9_eft_m18             = 150,
    arc9_eft_m18y            = 150,
    arc9_eft_m32a1           = 4500,
    arc9_eft_m67             = 160,
    arc9_eft_m7290           = 130,
    arc9_eft_rdg2b           = 110,
    arc9_eft_rgd5            = 100,
    arc9_eft_rgn             = 180,
    arc9_eft_rgo             = 200,
    arc9_eft_rshg2           = 1200,
    arc9_eft_v40             = 220,
    arc9_eft_vog17           = 90,
    arc9_eft_vog25           = 110,
    arc9_eft_zarya           = 120,

    -- ------------------------------------------------------------------
    -- ARC9 EFT pistols
    -- ------------------------------------------------------------------
    arc9_eft_apb             = 900,
    arc9_eft_aps             = 700,
    arc9_eft_cr200ds         = 600,
    arc9_eft_cr50ds          = 800,
    arc9_eft_deagle_l5       = 1400,
    arc9_eft_deagle_l6       = 1500,
    arc9_eft_deagle_xix      = 1600,
    arc9_eft_fn57            = 900,
    arc9_eft_glock17         = 500,
    arc9_eft_glock18c        = 1100,
    arc9_eft_glock19x        = 550,
    arc9_eft_m1911           = 450,
    arc9_eft_m45             = 700,
    arc9_eft_m9a3            = 500,
    arc9_eft_mp443           = 400,
    arc9_eft_p226r           = 550,
    arc9_eft_pb              = 600,
    arc9_eft_pl15            = 650,
    arc9_eft_pm              = 250,
    arc9_eft_rsh12           = 2000,
    arc9_eft_sr1mp           = 750,
    arc9_eft_tt33            = 300,
    arc9_eft_usp             = 700,

    -- ------------------------------------------------------------------
    -- HL2 / sandbox. The tool weapons (physgun, toolgun, camera) are
    -- deliberately ABSENT: no value => not tradeable. Selling the toolgun to
    -- a trader for cash is not a mechanic, it is a bug report waiting to
    -- happen (they are also the sandbox tools the player is handed back).
    -- ------------------------------------------------------------------
    weapon_pistol     = 300,
    weapon_357        = 900,
    weapon_smg1       = 1100,
    weapon_ar2        = 2600,
    weapon_shotgun    = 1200,
    weapon_crossbow   = 1500,
    weapon_rpg        = 3500,
    weapon_annabelle  = 1000,
    weapon_crowbar    = 60,
    weapon_stunstick  = 150,
    weapon_slam       = 250,
    weapon_bugbait    = 80,
}
