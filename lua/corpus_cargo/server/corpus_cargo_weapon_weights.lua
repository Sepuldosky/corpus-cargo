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
    -- ARC9 MW2019 (ARC9MW pack). Data source: the pack ITSELF — every gun
    -- declares its real mass in its SWEP.Trivia block
    -- (ARC9:GetPhrase("mw19_weight") -> string.format(..., 4.79, 4.79*2.2)),
    -- read out of the live code on 2026-07-14. Those numbers are transcribed
    -- verbatim below; they are not guesses and they beat any figure we could
    -- invent. The 33 classes the pack does NOT weigh (launchers, grenades,
    -- melee, akimbos) fall back to real-world figures, tagged "real approx".
    --
    -- We bake the numbers instead of parsing SWEP.Trivia at runtime because
    -- what ARC9 stores there is an already-formatted display string
    -- ("4.79 kg / 10.54 lbs") — scraping kg out of localized prose every boot
    -- is a fragile contract with a mod we do not control.
    -- ------------------------------------------------------------------
    arc9_cod2019_ar_ak47           = 4.79, -- MW19 declared
    arc9_cod2019_ar_an94           = 3.85, -- MW19 declared
    arc9_cod2019_ar_asval          = 2.60, -- MW19 declared
    arc9_cod2019_ar_cr56amax       = 3.95, -- MW19 declared
    arc9_cod2019_ar_fal            = 4.45, -- MW19 declared
    arc9_cod2019_ar_famas          = 3.61, -- MW19 declared
    arc9_cod2019_ar_grau556        = 3.62, -- MW19 declared
    arc9_cod2019_ar_kilo141        = 3.25, -- MW19 declared
    arc9_cod2019_ar_m13            = 2.61, -- MW19 declared
    arc9_cod2019_ar_m4             = 3.45, -- MW19 declared
    arc9_cod2019_ar_oden           = 6.00, -- MW19 declared
    arc9_cod2019_ar_ram7           = 3.27, -- MW19 declared
    arc9_cod2019_ar_scar           = 3.58, -- MW19 declared

    arc9_cod2019_sm_aug            = 3.20, -- MW19 declared
    arc9_cod2019_sm_bizon          = 2.10, -- MW19 declared
    arc9_cod2019_sm_cx9            = 2.77, -- MW19 declared
    arc9_cod2019_sm_iso            = 2.60, -- MW19 declared
    arc9_cod2019_sm_mp5            = 2.54, -- MW19 declared
    arc9_cod2019_sm_mp7            = 2.10, -- MW19 declared
    arc9_cod2019_sm_p90            = 2.60, -- MW19 declared
    arc9_cod2019_sm_striker45      = 2.70, -- MW19 declared
    arc9_cod2019_sm_uzi            = 3.50, -- MW19 declared
    arc9_cod2019_sm_vector         = 2.70, -- MW19 declared (Fennec)

    arc9_cod2019_sh_725            = 3.91, -- MW19 declared
    arc9_cod2019_sh_jak12          = 5.50, -- MW19 declared
    arc9_cod2019_sh_model680       = 3.20, -- MW19 declared
    arc9_cod2019_sh_origin12       = 4.20, -- MW19 declared
    arc9_cod2019_sh_r90            = 4.20, -- MW19 declared
    arc9_cod2019_sh_vlk            = 2.26, -- MW19 declared

    arc9_cod2019_lm_bruenmk9       = 10.00, -- MW19 declared
    arc9_cod2019_lm_finn           = 4.50,  -- MW19 declared
    arc9_cod2019_lm_holger         = 3.63,  -- MW19 declared
    arc9_cod2019_lm_m91            = 11.20, -- MW19 declared
    arc9_cod2019_lm_mg34           = 12.50, -- MW19 declared
    arc9_cod2019_lm_minigun        = 19.00, -- MW19 declared
    arc9_cod2019_lm_pkm            = 9.20,  -- MW19 declared
    arc9_cod2019_lm_raal           = 10.00, -- MW19 declared
    arc9_cod2019_lm_sa86           = 6.60,  -- MW19 declared

    arc9_cod2019_mm_kar98k         = 3.70, -- MW19 declared
    arc9_cod2019_mm_m14            = 5.10, -- MW19 declared (EBR-14)
    arc9_cod2019_mm_mk2            = 3.30, -- MW19 declared
    arc9_cod2019_mm_sks            = 3.85, -- MW19 declared
    arc9_cod2019_mm_spr208         = 5.00, -- MW19 declared
    arc9_cod2019_mm_crossbow       = 3.00, -- real approx (pack declares no mass)

    arc9_cod2019_sn_ax50           = 13.00, -- MW19 declared
    arc9_cod2019_sn_hdr            = 6.06,  -- MW19 declared
    arc9_cod2019_sn_rytec          = 15.10, -- MW19 declared
    arc9_cod2019_sn_svd            = 4.40,  -- MW19 declared (Dragunov)

    arc9_cod2019_pi_357            = 1.10, -- MW19 declared
    arc9_cod2019_pi_50gs           = 2.00, -- MW19 declared
    arc9_cod2019_pi_m19            = 0.84, -- MW19 declared
    arc9_cod2019_pi_m1911          = 1.00, -- MW19 declared
    arc9_cod2019_pi_renetti        = 1.00, -- MW19 declared
    arc9_cod2019_pi_sykov          = 0.73, -- MW19 declared
    arc9_cod2019_pi_x16            = 1.10, -- MW19 declared
    -- akimbos: two of the gun, and the game makes you carry both
    arc9_cod2019_pi_357_akimbo     = 2.20,
    arc9_cod2019_pi_50gs_akimbo    = 4.00,
    arc9_cod2019_pi_m19_akimbo     = 1.68,
    arc9_cod2019_pi_m1911_akimbo   = 2.00,
    arc9_cod2019_pi_renetti_akimbo = 2.00,
    arc9_cod2019_pi_sykov_akimbo   = 1.46,
    arc9_cod2019_pi_x16_akimbo     = 2.20,

    -- launchers (real approx: the pack declares no mass for any of them)
    arc9_cod2019_la_jokr           = 12.50, -- real approx (NLAW-class guided)
    arc9_cod2019_la_m32            = 5.30,  -- real approx (Milkor M32 MSGL)
    arc9_cod2019_la_pila           = 14.00, -- real approx (MANPADS-class)
    arc9_cod2019_la_rpg            = 6.30,  -- GAMMA wpn_rpg7
    arc9_cod2019_la_strela         = 9.80,  -- real approx (Strela-2 launcher)

    -- melee (arc9_cod2019_me_fist is NOT here: it is the unarmed state, and
    -- Capture.Ignore drops it before it can ever become an item)
    arc9_cod2019_me_knife          = 0.30, -- real approx
    arc9_cod2019_me_shield         = 5.50, -- real approx (ballistic riot shield)

    -- lethal & tactical (real approx throughout)
    arc9_cod2019_nade_c4           = 0.60,
    arc9_cod2019_nade_claymores    = 1.58, -- M18A1
    arc9_cod2019_nade_decoy        = 0.30,
    arc9_cod2019_nade_drillcharge  = 1.50,
    arc9_cod2019_nade_flash        = 0.20, -- M84
    arc9_cod2019_nade_frag         = 0.40, -- M67
    arc9_cod2019_nade_gas          = 0.45,
    arc9_cod2019_nade_knife        = 0.15,
    arc9_cod2019_nade_landmines    = 1.20,
    arc9_cod2019_nade_molotov      = 0.70,
    arc9_cod2019_nade_rock         = 0.50,
    arc9_cod2019_nade_semtex       = 0.30,
    arc9_cod2019_nade_smoke        = 0.45, -- M18
    arc9_cod2019_nade_snapshot     = 0.35,
    arc9_cod2019_nade_stun         = 0.25,
    arc9_cod2019_nade_thermite     = 0.90, -- AN-M14
    arc9_cod2019_nade_thermite_alt = 0.90,

    -- ------------------------------------------------------------------
    -- ARSENAL DEL AUTOR (volcado de cargo_dev_dump_weapons, 2026-07-14):
    -- 369 armas montadas, 184 sin peso. Estos packs NO estan en dev/other/,
    -- asi que se catalogaron desde el propio volcado (clase, nombre, tipo,
    -- municion, cargador) + cifras reales: los EFT que faltaban (SMG,
    -- escopetas, LMG, melee, gear, makeshift), el pack de CS:GO (arc9_go) y
    -- el Scorpion de arc9_wtt. El reporte que lo destapo: el M60E4 pesaba
    -- 2,5 kg.
    --
    -- Las CLASES BASE del volcado (arc9_base, arc9_eft_base, arc9_go_base,
    -- *_base_nade, *_melee_base) NO se catalogan a proposito: son plantillas
    -- de SWEP, no armas que el jugador pueda recibir.
    -- ------------------------------------------------------------------
    -- EFT: variantes y altas tardias (sin subcategoria en el volcado)
    arc9_eft_m60e6                   = 9.30,            -- M60E6
    arc9_eft_mp5k                    = 2.00,            -- MP5K-N
    arc9_eft_mp7a2                   = 1.90,            -- MP7A2
    arc9_eft_mp9n                    = 1.60,            -- MP9-N
    arc9_eft_mr155                   = 3.20,            -- MP-155
    arc9_eft_saiga12fa               = 3.80,            -- Saiga-12K FA
    arc9_eft_vector9                 = 2.70,            -- Vector 9x19
    -- EFT: fusiles de asalto
    arc9_eft_aek971                  = 3.30,            -- AEK-971
    arc9_eft_an94                    = 3.85,            -- AN-94
    arc9_eft_avt                     = 3.90,            -- AVT-40
    arc9_eft_m16a4                   = 3.40,            -- Colt M16A4
    arc9_eft_makeshift_af53          = 3.60,            -- AF-53
    arc9_eft_makeshift_ak15          = 3.80,            -- AK-15
    arc9_eft_makeshift_ak19          = 3.35,            -- AK-19
    arc9_eft_makeshift_ak_308        = 4.00,            -- AK-308
    arc9_eft_makeshift_mcx223        = 2.90,            -- MCX 5.56
    arc9_eft_makeshift_mdr_300       = 3.77,            -- DT MDR .300
    arc9_eft_makeshift_valak         = 3.50,            -- VALAK
    -- EFT: subfusiles
    arc9_eft_fn_p90                  = 2.60,            -- P90
    arc9_eft_kedr                    = 1.55,            -- PP-91 Kedr
    arc9_eft_makeshift_ppsh_9        = 3.60,            -- PPSh-41 9x19
    arc9_eft_makeshift_ump919        = 2.30,            -- UMP 9
    arc9_eft_makeshift_uzi45acp      = 3.50,            -- UZI .45
    arc9_eft_mp5                     = 2.54,            -- MP5
    arc9_eft_mp7a1                   = 1.90,            -- MP7A1
    arc9_eft_mp9                     = 1.60,            -- MP9
    arc9_eft_mpx                     = 2.70,            -- MPX
    arc9_eft_pp1901                  = 2.90,            -- PP-19-01 Vityaz
    arc9_eft_ppsh41                  = 3.63,            -- PPSh-41
    arc9_eft_saiga9                  = 3.40,            -- Saiga-9
    arc9_eft_sr2m                    = 1.90,            -- SR-2M Veresk
    arc9_eft_stm9                    = 2.90,            -- STM-9
    arc9_eft_ump                     = 2.30,            -- UMP .45
    arc9_eft_uzi                     = 3.50,            -- UZI
    arc9_eft_uzi_pro                 = 2.30,            -- UZI PRO
    arc9_eft_vector45                = 2.70,            -- Vector .45
    arc9_wtt_scorpion                = 2.77,            -- CZ Scorpion EVO 3 (pack arc9_wtt)
    -- EFT: ametralladoras — el M60E4 es el arma del reporte del autor
    arc9_eft_m249                    = 7.50,            -- M249 SAW
    arc9_eft_m60e4                   = 10.50,           -- M60E4 — 10,5 kg, no 2,5
    arc9_eft_makeshift_rpk556        = 3.87,            -- RPK-16 5.56
    arc9_eft_makeshift_rpk762        = 4.00,            -- RPK-16 7.62
    arc9_eft_pkm                     = 9.00,            -- PKM
    arc9_eft_pkp                     = 8.20,            -- PKP Pecheneg
    arc9_eft_rpd                     = 7.40,            -- RPD
    -- EFT: sniper y tirador designado
    arc9_eft_g28                     = 5.15,            -- HK G28
    arc9_eft_m1a                     = 4.20,            -- M1A
    arc9_eft_makeshift_m700_223      = 3.96,            -- M700 .223
    arc9_eft_makeshift_mosin308      = 3.70,            -- Mosin .308
    arc9_eft_makeshift_mp43_577      = 3.00,            -- MP-43 .577
    arc9_eft_mk18_mjolnir            = 7.00,            -- Mk-18 Mjolnir .338
    arc9_eft_rsass                   = 5.90,            -- RSASS
    arc9_eft_sr25                    = 4.88,            -- SR-25
    arc9_eft_svd                     = 4.30,            -- SVD
    arc9_eft_svds                    = 4.68,            -- SVDS
    arc9_eft_tkpd                    = 6.50,            -- TKPD .338
    arc9_eft_rangefinder             = 0.30,            -- R1500 — telemetro, no arma
    -- EFT: carabinas
    arc9_eft_rfb                     = 3.60,            -- Kel-Tec RFB
    arc9_eft_sks                     = 3.85,            -- SKS
    arc9_eft_svt                     = 3.85,            -- SVT-40
    arc9_eft_vpo101                  = 3.80,            -- VPO-101 Vepr-Hunter
    -- EFT: escopetas
    arc9_eft_aa12                    = 5.20,            -- AA-12
    arc9_eft_ks23                    = 3.85,            -- KS-23M
    arc9_eft_m3super90               = 3.30,            -- M3 Super 90
    arc9_eft_m590                    = 3.20,            -- 590A1
    arc9_eft_m870                    = 3.60,            -- M870
    arc9_eft_mr133                   = 3.20,            -- MP-133
    arc9_eft_mr153                   = 3.30,            -- MP-153
    arc9_eft_mr43                    = 3.20,            -- MP-43-1C
    arc9_eft_mr43_sawedoff           = 2.20,            -- MP-43 recortada
    arc9_eft_mts255                  = 3.50,            -- MTs-255-12
    arc9_eft_saiga12k                = 3.80,            -- Saiga-12K
    arc9_eft_toz106                  = 2.30,            -- TOZ-106
    -- EFT: pistolas
    arc9_eft_makeshift_pm919         = 0.73,            -- PM 9x19
    arc9_eft_pd20                    = 0.55,            -- Blicky (PD-20)
    -- EFT: bengalas y arrojadizos sueltos
    arc9_eft_rsp30_blue              = 0.30,            -- RSP-30 azul
    arc9_eft_rsp30_firework          = 0.30,            -- RSP-30 fuegos artificiales
    arc9_eft_rsp30_green             = 0.30,            -- RSP-30 verde
    arc9_eft_rsp30_red               = 0.30,            -- RSP-30 roja
    arc9_eft_rsp30_white             = 0.30,            -- RSP-30 bengala
    arc9_eft_rsp30_yellow            = 0.30,            -- RSP-30 amarilla
    arc9_eft_sp81                    = 0.85,            -- SP-81 pistola de senales
    arc9_eft_throwable_kolbas        = 0.50,            -- la salchicha arrojadiza
    -- EFT: cuerpo a cuerpo
    arc9_eft_melee_6x5               = 0.30,            -- 6Kh5 bayoneta
    arc9_eft_melee_a2607             = 0.25,            -- A-2607
    arc9_eft_melee_a2607d            = 0.25,            -- A-2607
    arc9_eft_melee_akula             = 0.35,            -- Akula
    arc9_eft_melee_camper            = 0.30,            -- Camper
    arc9_eft_melee_crash             = 0.30,            -- SCA
    arc9_eft_melee_crowbar           = 2.00,            -- palanca
    arc9_eft_melee_cultist           = 0.30,            -- cuchillo cultista
    arc9_eft_melee_fulcrum           = 0.35,            -- ER Bayonet
    arc9_eft_melee_gladius           = 0.40,            -- TWG
    arc9_eft_melee_hultafors         = 1.00,            -- martillo Dead Blow
    arc9_eft_melee_kiba              = 0.35,            -- KATT
    arc9_eft_melee_kukri             = 0.60,            -- M48 Kukri
    arc9_eft_melee_labris            = 3.00,            -- Chained Labrys
    arc9_eft_melee_m2                = 0.30,            -- M-2
    arc9_eft_melee_mpl50             = 2.00,            -- pala MPL-50
    arc9_eft_melee_rebel             = 0.70,            -- Red Rebel (pico de hielo)
    arc9_eft_melee_scythe            = 1.00,            -- hoz vieja
    arc9_eft_melee_sp8               = 0.35,            -- SP-8
    arc9_eft_melee_taiga             = 0.40,            -- Taiga-1
    arc9_eft_melee_taran             = 0.80,            -- baston PR-Taran
    arc9_eft_melee_voodoo            = 0.55,            -- Hawk
    arc9_eft_melee_wycc              = 1.20,            -- hacha

    -- CS:GO: pistolas
    arc9_go_cz75                     = 1.10,            -- CZ75-Auto
    arc9_go_deagle                   = 1.90,            -- Desert Eagle
    arc9_go_elite_single             = 0.95,            -- Beretta
    arc9_go_fiveseven                = 0.61,            -- Five-SeveN
    arc9_go_glock                    = 0.62,            -- Glock-18
    arc9_go_p2000                    = 0.70,            -- P2000
    arc9_go_p250                     = 0.70,            -- P250
    arc9_go_r8                       = 1.30,            -- R8 Revolver
    arc9_go_tec9                     = 1.40,            -- Tec-9
    arc9_go_usp                      = 0.72,            -- USP-S
    -- CS:GO: duales — son DOS armas, y las cargas las dos
    arc9_go_elite                    = 1.90,            -- Dual Berettas
    arc9_go_akimbo_cz75              = 2.20,            -- Dual CZ75
    arc9_go_akimbo_deagle            = 3.80,            -- Dual Desert Eagle
    arc9_go_akimbo_fiveseven         = 1.22,            -- Dual Five-SeveN
    arc9_go_akimbo_glock             = 1.24,            -- Dual Glock-18
    arc9_go_akimbo_mp9               = 3.20,            -- Dual MP9
    arc9_go_akimbo_p2000             = 1.40,            -- Dual P2000
    arc9_go_akimbo_p250              = 1.40,            -- Dual P250
    arc9_go_akimbo_r8                = 2.60,            -- Dual R8
    arc9_go_akimbo_sawnoff           = 5.60,            -- Dual Sawed-Off
    arc9_go_akimbo_taser             = 1.20,            -- Dual Zeus x27
    arc9_go_akimbo_usp               = 1.44,            -- Dual USP
    -- CS:GO: subfusiles
    arc9_go_bizon                    = 2.10,            -- PP-Bizon
    arc9_go_mac10                    = 2.84,            -- MAC-10
    arc9_go_mp5                      = 2.54,            -- MP5
    arc9_go_mp5sd                    = 3.10,            -- MP5-SD
    arc9_go_mp7                      = 1.90,            -- MP7
    arc9_go_mp9                      = 1.60,            -- MP9
    arc9_go_p90                      = 2.60,            -- P90
    arc9_go_ump                      = 2.30,            -- UMP-45
    -- CS:GO: fusiles
    arc9_go_ak47                     = 3.47,            -- AK-47
    arc9_go_aug                      = 3.90,            -- AUG
    arc9_go_awp                      = 6.50,            -- AWP
    arc9_go_famas                    = 3.61,            -- FAMAS
    arc9_go_g1sg3                    = 5.00,            -- G3SG1
    arc9_go_galil                    = 3.75,            -- Galil SAR
    arc9_go_galilar                  = 3.75,            -- Galil AR
    arc9_go_m4a1                     = 3.10,            -- M4A1-S
    arc9_go_m4a4                     = 3.02,            -- M4A4
    arc9_go_scar17                   = 3.60,            -- SCAR-17
    arc9_go_scar20                   = 4.85,            -- SCAR-20
    arc9_go_scout                    = 3.20,            -- Scout
    arc9_go_sg556                    = 3.40,            -- SG 553
    arc9_go_ssg08                    = 3.50,            -- SSG 08
    -- CS:GO: pesadas
    arc9_go_m249                     = 7.50,            -- M249
    arc9_go_negev                    = 8.00,            -- Negev
    arc9_go_m3                       = 3.20,            -- M3
    arc9_go_mag7                     = 3.20,            -- MAG-7
    arc9_go_nova                     = 3.50,            -- Nova
    arc9_go_sawedoff                 = 2.80,            -- Sawed-Off
    arc9_go_xm1014                   = 3.20,            -- XM1014
    -- CS:GO: equipo y cuerpo a cuerpo
    arc9_go_knife_bayonet            = 0.30,            -- bayoneta
    arc9_go_knife_ct                 = 0.25,            -- cuchillo CT
    arc9_go_knife_flip               = 0.25,            -- Flip Knife
    arc9_go_knife_t                  = 0.25,            -- cuchillo T
    arc9_go_knife_shield             = 5.50,            -- escudo antidisturbios
    arc9_go_zeus                     = 1.00,            -- Zeus x27
    -- CS:GO: granadas y cargas
    arc9_go_nade_breach              = 1.50,            -- Breach Charge
    arc9_go_nade_c4                  = 3.00,            -- C4
    arc9_go_nade_claymores           = 1.58,            -- Claymore
    arc9_go_nade_decoy               = 0.30,            -- Decoy
    arc9_go_nade_flashbang           = 0.20,            -- Flashbang
    arc9_go_nade_frag                = 0.40,            -- HE Grenade
    arc9_go_nade_incendiary          = 0.60,            -- Incendiary
    arc9_go_nade_landmines           = 1.20,            -- Landmine
    arc9_go_nade_mines               = 0.80,            -- Bump Mine
    arc9_go_nade_molotov             = 0.70,            -- Molotov
    arc9_go_nade_rock                = 0.50,            -- una piedra
    arc9_go_nade_smoke               = 0.45,            -- Smoke
    arc9_go_nade_sonar               = 0.35,            -- Tactical Awareness

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
