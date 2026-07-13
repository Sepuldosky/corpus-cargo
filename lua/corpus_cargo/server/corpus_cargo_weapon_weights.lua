-- corpus_cargo_weapon_weights.lua — real weights for auto-captured weapons (SERVER)
-- Data source: STALKER GAMMA 0.9.5 database (stalker-gamma-db.com, field
-- st_prop_weight, kg) — fetched 2026-07-13. GAMMA carries most of the same
-- guns as the ARC9 EFT packs, so its weights populate the autogen defs
-- instead of the 2.5 kg nominal. Classes GAMMA does not carry fall back to
-- Escape from Tarkov / real-world figures, tagged "EFT approx".
--
-- Keyed by weapon CLASS (deterministic — PrintNames are localization-prone).
-- Loaded by the manifest BEFORE corpus_cargo_capture.lua: the boot
-- re-registration of persisted autogen defs already reads this table, so
-- existing captured weapons pick up their real weight on the next map load.
-- Adding a class here is all it takes to weight any future capture.

local CARGO = Corpus.GetModule("cargo")

CARGO.Capture = CARGO.Capture or {}

CARGO.Capture.WeaponWeights = {
    -- ------------------------------------------------------------------
    -- ARC9 EFT Assault Rifles (Workshop pack)
    -- ------------------------------------------------------------------
    arc9_eft_9a91            = 1.80, -- GAMMA wpn_9a91
    arc9_eft_adar15          = 2.88, -- GAMMA wpn_adar2_15
    arc9_eft_ak101           = 3.60, -- GAMMA wpn_ak101
    arc9_eft_ak102           = 3.60, -- GAMMA wpn_ak102
    arc9_eft_ak103           = 3.60, -- GAMMA wpn_ak103
    arc9_eft_ak104           = 2.50, -- GAMMA wpn_ak104
    arc9_eft_ak105           = 3.20, -- GAMMA wpn_ak105
    arc9_eft_ak12            = 3.20, -- GAMMA wpn_ak12
    arc9_eft_ak74            = 3.30, -- GAMMA wpn_ak74
    arc9_eft_ak74m           = 3.40, -- GAMMA wpn_ak74m
    arc9_eft_akm             = 3.30, -- GAMMA wpn_akm
    arc9_eft_akms            = 3.30, -- GAMMA wpn_akms
    arc9_eft_aks74           = 3.30, -- GAMMA wpn_aks74_new
    arc9_eft_aks74u          = 2.48, -- GAMMA wpn_ak74u
    arc9_eft_ash12           = 4.50, -- GAMMA wpn_ash12
    arc9_eft_asval           = 2.50, -- GAMMA wpn_val
    arc9_eft_asval_mod4      = 2.50, -- GAMMA wpn_val_modern
    arc9_eft_aug             = 3.90, -- GAMMA wpn_aug_a3 (the ARC9 gun is the A3)
    arc9_eft_auga1           = 3.30, -- GAMMA wpn_aug (classic A1)
    arc9_eft_g36             = 4.00, -- GAMMA wpn_g36
    arc9_eft_hk416           = 3.74, -- GAMMA wpn_hk416
    arc9_eft_m16a1           = 3.09, -- GAMMA wpn_m16
    arc9_eft_m16a2           = 3.51, -- GAMMA wpn_m16a2
    arc9_eft_m4a1            = 3.02, -- GAMMA wpn_m4
    arc9_eft_mcx             = 2.40, -- EFT approx (SIG MCX .300 BLK, not in GAMMA)
    arc9_eft_mdr             = 3.77, -- GAMMA wpn_dtmdr
    arc9_eft_mdr556          = 3.77, -- GAMMA wpn_dtmdr (no 5.56 variant in GAMMA)
    arc9_eft_mk47_mutant     = 3.26, -- GAMMA wpn_mk47
    arc9_eft_nl545_di        = 3.40, -- EFT approx (custom AK-545 build)
    arc9_eft_nl545_gp        = 3.40, -- EFT approx (custom AK-545 build)
    arc9_eft_radian          = 3.30, -- EFT approx (Radian Model 1)
    arc9_eft_rd704           = 3.50, -- EFT approx (RD-704)
    arc9_eft_rpk16           = 3.87, -- GAMMA wpn_rpk74_16
    arc9_eft_sa58            = 3.80, -- GAMMA wpn_fal_sa58_osw
    arc9_eft_sag_ak545       = 3.50, -- EFT approx (SAG AK-545)
    arc9_eft_sag_ak545short  = 3.20, -- EFT approx (SAG AK-545 Short)
    arc9_eft_scarh           = 3.60, -- GAMMA wpn_scar_new
    arc9_eft_scarl           = 3.30, -- EFT approx (SCAR-L, GAMMA only carries the H)
    arc9_eft_scarx17         = 3.50, -- EFT approx (SCAR X-17 custom)
    arc9_eft_spear           = 3.60, -- EFT approx (SIG MCX-SPEAR)
    arc9_eft_sr3             = 2.00, -- GAMMA wpn_vihr (SR-3 Vikhr)
    arc9_eft_tx15            = 3.20, -- EFT approx (Lone Star TX-15 DML)
    arc9_eft_velociraptor    = 2.90, -- EFT approx (Velociraptor .300 BLK)
    arc9_eft_vpo136          = 3.50, -- EFT approx (VPO-136 Vepr KM)
    arc9_eft_vpo209          = 3.40, -- EFT approx (VPO-209 .366 TKM)
    arc9_eft_vsk94           = 2.80, -- GAMMA wpn_vsk94
    arc9_eft_vss             = 2.59, -- GAMMA wpn_vintorez (NOT wpn_vssk, that's the VKS)

    -- ------------------------------------------------------------------
    -- ARC9 EFT Snipers (Workshop pack)
    -- ------------------------------------------------------------------
    arc9_eft_ai_axmc         = 6.80, -- EFT approx (Accuracy International AXMC .338)
    arc9_eft_ak50            = 10.00, -- EFT approx (AK-50 .50 BMG prototype)
    arc9_eft_dvl10           = 6.00, -- GAMMA wpn_dvl10
    arc9_eft_m700            = 3.96, -- GAMMA wpn_remington700
    arc9_eft_mosin_infantry  = 3.70, -- GAMMA wpn_mosin (no infantry/sniper split)
    arc9_eft_mosin_sniper    = 3.70, -- GAMMA wpn_mosin
    arc9_eft_mp18            = 2.60, -- EFT approx (MP-18 single-shot)
    arc9_eft_mxlr            = 6.00, -- EFT approx
    arc9_eft_sako_trg        = 3.95, -- GAMMA wpn_trg
    arc9_eft_sv98            = 6.20, -- GAMMA wpn_sv98
    arc9_eft_t5000           = 6.50, -- EFT approx (ORSIS T-5000M)
    arc9_eft_vpo215          = 2.60, -- EFT approx (VPO-215 .366 bolt)

    -- ------------------------------------------------------------------
    -- ARC9 EFT explosives (Workshop pack: grenades + launchers)
    -- ------------------------------------------------------------------
    arc9_eft_f1              = 0.60, -- GAMMA grenade_f1
    arc9_eft_f1_rd           = 0.60, -- GAMMA grenade_f1 (impact-fuze variant)
    arc9_eft_fn40gl          = 2.00, -- EFT approx (FN40GL Mk2)
    arc9_eft_m18             = 0.45, -- EFT approx (M18 smoke)
    arc9_eft_m18y            = 0.45, -- EFT approx (M18 smoke, yellow)
    arc9_eft_m32a1           = 5.30, -- EFT approx (Milkor M32A1 MSGL)
    arc9_eft_m67             = 0.40, -- EFT approx (M67 frag)
    arc9_eft_m7290           = 0.45, -- EFT approx (M7290 flashbang)
    arc9_eft_rdg2b           = 0.50, -- EFT approx (RDG-2B smoke)
    arc9_eft_rgd5            = 0.31, -- GAMMA grenade_rgd5
    arc9_eft_rgn             = 0.30, -- EFT approx (RGN impact frag)
    arc9_eft_rgo             = 0.52, -- EFT approx (RGO impact frag)
    arc9_eft_rshg2           = 3.80, -- EFT approx (RShG-2 rocket)
    arc9_eft_v40             = 0.22, -- EFT approx (V40 mini frag)
    arc9_eft_vog17           = 0.28, -- EFT approx (VOG-17 improvised)
    arc9_eft_vog25           = 0.25, -- EFT approx (VOG-25 improvised)
    arc9_eft_zarya           = 0.60, -- EFT approx (Zarya stun grenade)

    -- ------------------------------------------------------------------
    -- ARC9 EFT pistols (Workshop pack)
    -- ------------------------------------------------------------------
    arc9_eft_apb             = 1.25, -- EFT approx (APB, suppressed APS)
    arc9_eft_aps             = 1.02, -- GAMMA wpn_aps
    arc9_eft_cr200ds         = 0.70, -- EFT approx (Chiappa Rhino 200DS)
    arc9_eft_cr50ds          = 0.95, -- EFT approx (Chiappa Rhino 50DS)
    arc9_eft_deagle_l5       = 1.50, -- EFT approx (Desert Eagle L5)
    arc9_eft_deagle_l6       = 1.80, -- EFT approx (Desert Eagle L6)
    arc9_eft_deagle_xix      = 1.90, -- GAMMA wpn_desert_eagle (Mark XIX)
    arc9_eft_fn57            = 0.61, -- GAMMA wpn_fn57
    arc9_eft_glock17         = 0.62, -- GAMMA wpn_glock17
    arc9_eft_glock18c        = 0.67, -- EFT approx (Glock 18C)
    arc9_eft_glock19x        = 0.60, -- EFT approx (Glock 19X)
    arc9_eft_m1911           = 1.07, -- GAMMA wpn_colt1911
    arc9_eft_m45             = 1.25, -- GAMMA wpn_m45a1
    arc9_eft_m9a3            = 0.95, -- GAMMA wpn_beretta
    arc9_eft_mp443           = 0.95, -- GAMMA wpn_mp443
    arc9_eft_p226r           = 0.80, -- GAMMA wpn_sig226
    arc9_eft_pb              = 1.15, -- GAMMA wpn_pb
    arc9_eft_pl15            = 0.80, -- GAMMA wpn_pl15
    arc9_eft_pm              = 0.73, -- GAMMA wpn_pm
    arc9_eft_rsh12           = 2.00, -- GAMMA wpn_eft_rsh12
    arc9_eft_sr1mp           = 0.90, -- GAMMA wpn_sr1m
    arc9_eft_tt33            = 0.85, -- GAMMA wpn_tt33
    arc9_eft_usp             = 1.21, -- GAMMA wpn_usp

    -- ------------------------------------------------------------------
    -- HL2 / sandbox: rough real-world figures so the engine loadout is not
    -- uniformly 2.5 kg either
    -- ------------------------------------------------------------------
    weapon_pistol     = 0.7,
    weapon_357        = 1.0,
    weapon_smg1       = 2.7,  -- MP7-style
    weapon_ar2        = 3.5,
    weapon_shotgun    = 3.2,  -- SPAS-12
    weapon_crossbow   = 3.0,
    weapon_rpg        = 6.3,  -- GAMMA wpn_rpg7
    weapon_annabelle  = 3.2,
    weapon_crowbar    = 2.0,
    weapon_stunstick  = 1.0,
    weapon_slam       = 1.0,
    weapon_bugbait    = 0.5,
    weapon_physgun    = 4.0,
    weapon_physcannon = 4.0,
    gmod_tool         = 2.0,
    gmod_camera       = 0.8,
}
