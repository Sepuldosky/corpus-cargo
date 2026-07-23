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
    -- ARC9 MW2019 (ARC9MW pack). Same scale as the EFT ranks above — a
    -- pistol is pocket change, an AR is a few runs of loot, a .50 rifle is a
    -- goal. Unlike the weights (which the pack declares), NOTHING here comes
    -- from MW2019: the game has no economy to copy, so these are ours and
    -- they are meant to be tuned in play.
    -- ------------------------------------------------------------------
    arc9_cod2019_ar_ak47           = 1300,
    arc9_cod2019_ar_an94           = 2600,
    arc9_cod2019_ar_asval          = 2600,
    arc9_cod2019_ar_cr56amax       = 2400,
    arc9_cod2019_ar_fal            = 2200,
    arc9_cod2019_ar_famas          = 2000,
    arc9_cod2019_ar_grau556        = 2300,
    arc9_cod2019_ar_kilo141        = 2200,
    arc9_cod2019_ar_m13            = 2500,
    arc9_cod2019_ar_m4             = 2200,
    arc9_cod2019_ar_oden           = 2800,
    arc9_cod2019_ar_ram7           = 2400,
    arc9_cod2019_ar_scar           = 3200,

    arc9_cod2019_sm_aug            = 1800,
    arc9_cod2019_sm_bizon          = 1200,
    arc9_cod2019_sm_cx9            = 1700,
    arc9_cod2019_sm_iso            = 1600,
    arc9_cod2019_sm_mp5            = 1400,
    arc9_cod2019_sm_mp7            = 1500,
    arc9_cod2019_sm_p90            = 1700,
    arc9_cod2019_sm_striker45      = 1500,
    arc9_cod2019_sm_uzi            = 1100,
    arc9_cod2019_sm_vector         = 1900,

    arc9_cod2019_sh_725            = 1000,
    arc9_cod2019_sh_jak12          = 2600,
    arc9_cod2019_sh_model680       = 700,
    arc9_cod2019_sh_origin12       = 2400,
    arc9_cod2019_sh_r90            = 1800,
    arc9_cod2019_sh_vlk            = 900,

    arc9_cod2019_lm_bruenmk9       = 3800,
    arc9_cod2019_lm_finn           = 3600,
    arc9_cod2019_lm_holger         = 2800,
    arc9_cod2019_lm_m91            = 4200,
    arc9_cod2019_lm_mg34           = 3000,
    arc9_cod2019_lm_minigun        = 6000,
    arc9_cod2019_lm_pkm            = 3400,
    arc9_cod2019_lm_raal           = 4400,
    arc9_cod2019_lm_sa86           = 3000,

    arc9_cod2019_mm_kar98k         = 1200,
    arc9_cod2019_mm_m14            = 3000,
    arc9_cod2019_mm_mk2            = 1400,
    arc9_cod2019_mm_sks            = 900,
    arc9_cod2019_mm_spr208         = 3300,
    arc9_cod2019_mm_crossbow       = 1500,

    arc9_cod2019_sn_ax50           = 7500,
    arc9_cod2019_sn_hdr            = 6500,
    arc9_cod2019_sn_rytec          = 8500,
    arc9_cod2019_sn_svd            = 3800,

    arc9_cod2019_pi_357            = 900,
    arc9_cod2019_pi_50gs           = 1600,
    arc9_cod2019_pi_m19            = 500,
    arc9_cod2019_pi_m1911          = 450,
    arc9_cod2019_pi_renetti        = 650,
    arc9_cod2019_pi_sykov          = 300,
    arc9_cod2019_pi_x16            = 550,
    -- akimbos price slightly OVER two of the gun: the pair is a matched set,
    -- and a trader who has to source two of anything says so
    arc9_cod2019_pi_357_akimbo     = 1900,
    arc9_cod2019_pi_50gs_akimbo    = 3400,
    arc9_cod2019_pi_m19_akimbo     = 1050,
    arc9_cod2019_pi_m1911_akimbo   = 950,
    arc9_cod2019_pi_renetti_akimbo = 1350,
    arc9_cod2019_pi_sykov_akimbo   = 650,
    arc9_cod2019_pi_x16_akimbo     = 1150,

    arc9_cod2019_la_jokr           = 3500,
    arc9_cod2019_la_m32            = 4500,
    arc9_cod2019_la_pila           = 3800,
    arc9_cod2019_la_rpg            = 1800,
    arc9_cod2019_la_strela         = 3600,

    arc9_cod2019_me_knife          = 120,
    arc9_cod2019_me_shield         = 900,

    arc9_cod2019_nade_c4           = 250,
    arc9_cod2019_nade_claymores    = 300,
    arc9_cod2019_nade_decoy        = 60,
    arc9_cod2019_nade_drillcharge  = 280,
    arc9_cod2019_nade_flash        = 130,
    arc9_cod2019_nade_frag         = 160,
    arc9_cod2019_nade_gas          = 170,
    arc9_cod2019_nade_knife        = 80,
    arc9_cod2019_nade_landmines    = 300,
    arc9_cod2019_nade_molotov      = 90,
    arc9_cod2019_nade_rock         = 10, -- it is a rock. Someone WILL try to sell it
    arc9_cod2019_nade_semtex       = 200,
    arc9_cod2019_nade_smoke        = 150,
    arc9_cod2019_nade_snapshot     = 220,
    arc9_cod2019_nade_stun         = 120,
    arc9_cod2019_nade_thermite     = 240,
    arc9_cod2019_nade_thermite_alt = 240,

    -- ------------------------------------------------------------------
    -- ARSENAL DEL AUTOR (volcado de cargo_dev_dump_weapons, 2026-07-14):
    -- 369 armas montadas, 184 sin precio. Estos packs NO estan en dev/other/,
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
    arc9_eft_m60e6                   = 4200,            -- M60E6
    arc9_eft_mp5k                    = 1300,            -- MP5K-N
    arc9_eft_mp7a2                   = 1600,            -- MP7A2
    arc9_eft_mp9n                    = 1400,            -- MP9-N
    arc9_eft_mr155                   = 900,             -- MP-155
    arc9_eft_saiga12fa               = 2600,            -- Saiga-12K FA
    arc9_eft_vector9                 = 2000,            -- Vector 9x19
    -- EFT: fusiles de asalto
    arc9_eft_aek971                  = 2400,            -- AEK-971
    arc9_eft_an94                    = 3000,            -- AN-94
    arc9_eft_avt                     = 1400,            -- AVT-40
    arc9_eft_m16a4                   = 2000,            -- Colt M16A4
    arc9_eft_makeshift_af53          = 2500,            -- AF-53
    arc9_eft_makeshift_ak15          = 2200,            -- AK-15
    arc9_eft_makeshift_ak19          = 2300,            -- AK-19
    arc9_eft_makeshift_ak_308        = 2700,            -- AK-308
    arc9_eft_makeshift_mcx223        = 2800,            -- MCX 5.56
    arc9_eft_makeshift_mdr_300       = 2900,            -- DT MDR .300
    arc9_eft_makeshift_valak         = 2400,            -- VALAK
    -- makeshift: altas del volcado 2026-07-23 (pasada de la #27, 11 clases; precio de arranque)
    arc9_eft_makeshift_1911_919_1    = 800,             -- M919 (1911 en 9x19)
    arc9_eft_makeshift_ash_20        = 2000,            -- ASh-20 (lanzagranadas)
    arc9_eft_makeshift_fal_newd      = 2800,            -- NEWD M53 (FAL 7.62)
    arc9_eft_makeshift_mxlr357       = 1800,            -- MXLR .357
    arc9_eft_makeshift_nl12g         = 1200,            -- CG NL 12/70 (escopeta)
    arc9_eft_makeshift_pk_76225_2    = 1200,            -- TPPK (SMG)
    arc9_eft_makeshift_rpdak         = 2400,            -- AD-44 (RPD/AK)
    arc9_eft_makeshift_sako_50       = 3500,            -- Sako TRG 50 (sniper)
    arc9_eft_makeshift_sks939        = 1600,            -- SKS-9x39
    arc9_eft_makeshift_tsvd_1        = 2200,            -- TSVD (Dragunov)
    arc9_eft_makeshift_valakmod4     = 2450,            -- VALAK Mod.4
    -- EFT: subfusiles
    arc9_eft_fn_p90                  = 2600,            -- P90
    arc9_eft_kedr                    = 700,             -- PP-91 Kedr
    arc9_eft_makeshift_ppsh_9        = 900,             -- PPSh-41 9x19
    arc9_eft_makeshift_ump919        = 1500,            -- UMP 9
    arc9_eft_makeshift_uzi45acp      = 1300,            -- UZI .45
    arc9_eft_mp5                     = 1500,            -- MP5
    arc9_eft_mp7a1                   = 1700,            -- MP7A1
    arc9_eft_mp9                     = 1400,            -- MP9
    arc9_eft_mpx                     = 1800,            -- MPX
    arc9_eft_pp1901                  = 1200,            -- PP-19-01 Vityaz
    arc9_eft_ppsh41                  = 800,             -- PPSh-41
    arc9_eft_saiga9                  = 1400,            -- Saiga-9
    arc9_eft_sr2m                    = 1600,            -- SR-2M Veresk
    arc9_eft_stm9                    = 1900,            -- STM-9
    arc9_eft_ump                     = 1500,            -- UMP .45
    arc9_eft_uzi                     = 1200,            -- UZI
    arc9_eft_uzi_pro                 = 1300,            -- UZI PRO
    arc9_eft_vector45                = 2100,            -- Vector .45
    arc9_wtt_scorpion                = 1700,            -- CZ Scorpion EVO 3 (pack arc9_wtt)
    -- EFT: ametralladoras — el M60E4 es el arma del reporte del autor
    arc9_eft_m249                    = 4000,            -- M249 SAW
    arc9_eft_m60e4                   = 4400,            -- M60E4 — 10,5 kg, no 2,5
    arc9_eft_makeshift_rpk556        = 2600,            -- RPK-16 5.56
    arc9_eft_makeshift_rpk762        = 2700,            -- RPK-16 7.62
    arc9_eft_pkm                     = 4600,            -- PKM
    arc9_eft_pkp                     = 5000,            -- PKP Pecheneg
    arc9_eft_rpd                     = 2800,            -- RPD
    -- EFT: sniper y tirador designado
    arc9_eft_g28                     = 5500,            -- HK G28
    arc9_eft_m1a                     = 3400,            -- M1A
    arc9_eft_makeshift_m700_223      = 3200,            -- M700 .223
    arc9_eft_makeshift_mosin308      = 1500,            -- Mosin .308
    arc9_eft_makeshift_mp43_577      = 900,             -- MP-43 .577
    arc9_eft_mk18_mjolnir            = 8000,            -- Mk-18 Mjolnir .338
    arc9_eft_rsass                   = 6000,            -- RSASS
    arc9_eft_sr25                    = 5200,            -- SR-25
    arc9_eft_svd                     = 3000,            -- SVD
    arc9_eft_svds                    = 3300,            -- SVDS
    arc9_eft_tkpd                    = 7000,            -- TKPD .338
    arc9_eft_rangefinder             = 600,             -- R1500 — telemetro, no arma
    -- EFT: carabinas
    arc9_eft_rfb                     = 3000,            -- Kel-Tec RFB
    arc9_eft_sks                     = 900,             -- SKS
    arc9_eft_svt                     = 1200,            -- SVT-40
    arc9_eft_vpo101                  = 1000,            -- VPO-101 Vepr-Hunter
    -- EFT: escopetas
    arc9_eft_aa12                    = 4000,            -- AA-12
    arc9_eft_ks23                    = 1800,            -- KS-23M
    arc9_eft_m3super90               = 1600,            -- M3 Super 90
    arc9_eft_m590                    = 1500,            -- 590A1
    arc9_eft_m870                    = 1400,            -- M870
    arc9_eft_mr133                   = 700,             -- MP-133
    arc9_eft_mr153                   = 900,             -- MP-153
    arc9_eft_mr43                    = 500,             -- MP-43-1C
    arc9_eft_mr43_sawedoff           = 400,             -- MP-43 recortada
    arc9_eft_mts255                  = 1000,            -- MTs-255-12
    arc9_eft_saiga12k                = 2400,            -- Saiga-12K
    arc9_eft_toz106                  = 300,             -- TOZ-106
    -- EFT: pistolas
    arc9_eft_makeshift_pm919         = 300,             -- PM 9x19
    arc9_eft_pd20                    = 400,             -- Blicky (PD-20)
    -- EFT: bengalas y arrojadizos sueltos
    arc9_eft_rsp30_blue              = 80,              -- RSP-30 azul
    arc9_eft_rsp30_firework          = 80,              -- RSP-30 fuegos artificiales
    arc9_eft_rsp30_green             = 80,              -- RSP-30 verde
    arc9_eft_rsp30_red               = 80,              -- RSP-30 roja
    arc9_eft_rsp30_white             = 80,              -- RSP-30 bengala
    arc9_eft_rsp30_yellow            = 80,              -- RSP-30 amarilla
    arc9_eft_sp81                    = 250,             -- SP-81 pistola de senales
    arc9_eft_throwable_kolbas        = 20,              -- la salchicha arrojadiza
    -- EFT: cuerpo a cuerpo
    arc9_eft_melee_6x5               = 150,             -- 6Kh5 bayoneta
    arc9_eft_melee_a2607             = 120,             -- A-2607
    arc9_eft_melee_a2607d            = 120,             -- A-2607
    arc9_eft_melee_akula             = 180,             -- Akula
    arc9_eft_melee_camper            = 140,             -- Camper
    arc9_eft_melee_crash             = 140,             -- SCA
    arc9_eft_melee_crowbar           = 100,             -- palanca
    arc9_eft_melee_cultist           = 300,             -- cuchillo cultista
    arc9_eft_melee_fulcrum           = 200,             -- ER Bayonet
    arc9_eft_melee_gladius           = 220,             -- TWG
    arc9_eft_melee_hultafors         = 130,             -- martillo Dead Blow
    arc9_eft_melee_kiba              = 200,             -- KATT
    arc9_eft_melee_kukri             = 240,             -- M48 Kukri
    arc9_eft_melee_labris            = 350,             -- Chained Labrys
    arc9_eft_melee_m2                = 150,             -- M-2
    arc9_eft_melee_mpl50             = 120,             -- pala MPL-50
    arc9_eft_melee_rebel             = 400,             -- Red Rebel (pico de hielo)
    arc9_eft_melee_scythe            = 180,             -- hoz vieja
    arc9_eft_melee_sp8               = 200,             -- SP-8
    arc9_eft_melee_taiga             = 190,             -- Taiga-1
    arc9_eft_melee_taran             = 110,             -- baston PR-Taran
    arc9_eft_melee_voodoo            = 230,             -- Hawk
    arc9_eft_melee_wycc              = 160,             -- hacha

    -- CS:GO: pistolas
    arc9_go_cz75                     = 700,             -- CZ75-Auto
    arc9_go_deagle                   = 1600,            -- Desert Eagle
    arc9_go_elite_single             = 500,             -- Beretta
    arc9_go_fiveseven                = 900,             -- Five-SeveN
    arc9_go_glock                    = 500,             -- Glock-18
    arc9_go_p2000                    = 550,             -- P2000
    arc9_go_p250                     = 550,             -- P250
    arc9_go_r8                       = 1000,            -- R8 Revolver
    arc9_go_tec9                     = 800,             -- Tec-9
    arc9_go_usp                      = 600,             -- USP-S
    -- CS:GO: duales — son DOS armas, y las cargas las dos
    arc9_go_elite                    = 1050,            -- Dual Berettas
    arc9_go_akimbo_cz75              = 1500,            -- Dual CZ75
    arc9_go_akimbo_deagle            = 3400,            -- Dual Desert Eagle
    arc9_go_akimbo_fiveseven         = 1900,            -- Dual Five-SeveN
    arc9_go_akimbo_glock             = 1050,            -- Dual Glock-18
    arc9_go_akimbo_mp9               = 2900,            -- Dual MP9
    arc9_go_akimbo_p2000             = 1150,            -- Dual P2000
    arc9_go_akimbo_p250              = 1150,            -- Dual P250
    arc9_go_akimbo_r8                = 2100,            -- Dual R8
    arc9_go_akimbo_sawnoff           = 1200,            -- Dual Sawed-Off
    arc9_go_akimbo_taser             = 2200,            -- Dual Zeus x27
    arc9_go_akimbo_usp               = 1250,            -- Dual USP
    -- CS:GO: subfusiles
    arc9_go_bizon                    = 1200,            -- PP-Bizon
    arc9_go_mac10                    = 1000,            -- MAC-10
    arc9_go_mp5                      = 1500,            -- MP5
    arc9_go_mp5sd                    = 1800,            -- MP5-SD
    arc9_go_mp7                      = 1500,            -- MP7
    arc9_go_mp9                      = 1400,            -- MP9
    arc9_go_p90                      = 1700,            -- P90
    arc9_go_ump                      = 1300,            -- UMP-45
    -- CS:GO: fusiles
    arc9_go_ak47                     = 1400,            -- AK-47
    arc9_go_aug                      = 2600,            -- AUG
    arc9_go_awp                      = 7000,            -- AWP
    arc9_go_famas                    = 2000,            -- FAMAS
    arc9_go_g1sg3                    = 5000,            -- G3SG1
    arc9_go_galil                    = 1300,            -- Galil SAR
    arc9_go_galilar                  = 1300,            -- Galil AR
    arc9_go_m4a1                     = 2400,            -- M4A1-S
    arc9_go_m4a4                     = 2300,            -- M4A4
    arc9_go_scar17                   = 3200,            -- SCAR-17
    arc9_go_scar20                   = 5400,            -- SCAR-20
    arc9_go_scout                    = 2800,            -- Scout
    arc9_go_sg556                    = 2700,            -- SG 553
    arc9_go_ssg08                    = 3000,            -- SSG 08
    -- CS:GO: pesadas
    arc9_go_m249                     = 4000,            -- M249
    arc9_go_negev                    = 4200,            -- Negev
    arc9_go_m3                       = 1200,            -- M3
    arc9_go_mag7                     = 1600,            -- MAG-7
    arc9_go_nova                     = 1300,            -- Nova
    arc9_go_sawedoff                 = 600,             -- Sawed-Off
    arc9_go_xm1014                   = 2200,            -- XM1014
    -- CS:GO: equipo y cuerpo a cuerpo
    arc9_go_knife_bayonet            = 200,             -- bayoneta
    arc9_go_knife_ct                 = 120,             -- cuchillo CT
    arc9_go_knife_flip               = 150,             -- Flip Knife
    arc9_go_knife_t                  = 120,             -- cuchillo T
    arc9_go_knife_shield             = 900,             -- escudo antidisturbios
    arc9_go_zeus                     = 1100,            -- Zeus x27
    -- CS:GO: granadas y cargas
    arc9_go_nade_breach              = 280,             -- Breach Charge
    arc9_go_nade_c4                  = 500,             -- C4
    arc9_go_nade_claymores           = 300,             -- Claymore
    arc9_go_nade_decoy               = 60,              -- Decoy
    arc9_go_nade_flashbang           = 130,             -- Flashbang
    arc9_go_nade_frag                = 160,             -- HE Grenade
    arc9_go_nade_incendiary          = 220,             -- Incendiary
    arc9_go_nade_landmines           = 300,             -- Landmine
    arc9_go_nade_mines               = 240,             -- Bump Mine
    arc9_go_nade_molotov             = 90,              -- Molotov
    arc9_go_nade_rock                = 10,              -- una piedra
    arc9_go_nade_smoke               = 150,             -- Smoke
    arc9_go_nade_sonar               = 220,             -- Tactical Awareness

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
