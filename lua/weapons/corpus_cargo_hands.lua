-- corpus_cargo_hands.lua — "Hands": the Corpus default unarmed state (SWEP)
--
-- RECYCLED from "Apex Legends: Holster/Melee SWEP" (Steam Workshop 2792160770)
-- by Twilight Sparkle & Buu342, with credits to Internet Overdoser, V92 and
-- WebKnight; animations by Respawn Entertainment (Apex Legends/Titanfall).
-- Recycle approved by the project author (2026-07-11, dev/mods_workshop_mapa.md
-- §2): full credits kept, assets removed on request of the original authors.
-- The mod has been unmaintained for ~4 years; this port renames the class to
-- the module namespace so both addons can coexist mounted.
--
-- Changes against the original (everything else is a faithful port):
--   * Class/print name: apexswep -> corpus_cargo_hands / "Hands".
--   * Sound scripts, net message and convars renamed to the
--     corpus_cargo/cargo_hands namespace (no collision if the original mod is
--     mounted alongside).
--   * ICON: the first port RENAMED the original's three icon VTFs instead of
--     replacing them — byte-identical Apex hands art under our filenames, which
--     both looked like the previous mod in the HUD and contradicted the "assets
--     removed" line above. The three VMT/VTF pairs are deleted; one PNG of the
--     Cargo logo (materials/corpus_cargo/hands_icon.png) now serves the weapon
--     selection, the kill icon and the spawnmenu tile. See the CLIENT block.
--   * MODEL EVENT FOLEY muted: the .mdl fires four Apex_* soundscript events
--     whose foley the recycle removed, so the console filled with "No such
--     sound". They are registered against common/null.wav — see the loop after
--     the sound.Add block.
--   * GLua C-style operators (&&/||/!=///) rewritten as standard Lua, matching
--     the repo style and the offline syntax harness.
--   * DARK ARMS FIX (2nd attempt): the original viewmodel goes dark looking
--     at the horizon and recovers looking up/down or floating (author repro
--     2026-07-11) — the ported model's baked $illumposition samples the
--     lightmap under the player. The 1st attempt (SetLightingOriginEntity ->
--     player, 2026-07-12) did NOT work: the engine still lit the viewmodel
--     off the bad illumposition. This attempt bypasses engine lighting for
--     the viewmodel entirely: PreDrawViewModel/PreDrawPlayerHands take the
--     wheel with render.SuppressEngineLighting(true) + a lighting box we
--     build ourselves, restored in the Post hooks. The box is NOT flat
--     fullbright — it samples the world light at the player's EYE position
--     (render.GetLightColor, a stable point that never dips under the floor
--     with view angle) with a floor so the arms are never pitch black, plus
--     a top-down key so they keep some volume. Result: arms react to the
--     room (dark cellar, bright outside) but never to the horizon glitch.
--     CONFIRMED in-game 2026-07-12 (applied live, no restart). TODO: remit
--     the fix upstream to Twilight Sparkle (mod 2792160770).
--   * melee_swing sound.Add: the original declared the `sound` key twice
--     (left hook overwritten by right hook — Lua keeps the last); both sets
--     are merged here, which is what the code visibly intended.
--   * ANIM SOURCE FIX: DealDamage read the animation name with
--     self:GetSequenceName(vm:GetSequence()) — a VIEWMODEL sequence index
--     looked up against the WEAPON entity's model, whose WorldModel is "".
--     It never resolved, so every per-animation branch was dead code: all
--     punches dealt the base damage and no directional knockback ever applied.
--     It now reads GetCurrentAnim(), the networked name SetAnim maintains.
--   * ANIM TIMING FIX: SetAnim/Deploy asked the viewmodel for
--     SequenceDuration() with no argument ("however long the sequence you are
--     playing right now lasts"), read right after telling it to switch. When
--     that lands on the old sequence the tracked time is wrong and Think
--     swaps back to idle1 either mid-swing or seconds late — the visible break
--     on punch -> idle (author repro 2026-07-14). Both now ask for the
--     duration of the exact sequence being started.
--   * Damage rebalanced for the Corpus context: these are bare fists, not an
--     Apex finisher. See the DAMAGE table.

AddCSLuaFile()

if CLIENT then
    -- ONE icon for the three surfaces. The port shipped the original's three
    -- VTFs renamed to our namespace but BYTE-IDENTICAL (verified by hash
    -- against dev/other/): Apex hands art, i.e. exactly the assets the recycle
    -- agreement says were removed. They are gone; the replacement is Cargo's
    -- own logo, rendered from assets/cargo_logo_dark.svg to a PNG — the same
    -- route the hitmarker below and the wheel icons already take.
    local ICON = "corpus_cargo/hands_icon.png"
    local iconMat = Material(ICON, "smooth mips")

    killicon.Add("corpus_cargo_hands", ICON, Color(255, 255, 255, 255))

    -- Spawnmenu tile. Sandbox reads SWEP.IconOverride and otherwise falls back
    -- to "entities/<class>.png" (verified in the shipped gamemode,
    -- spawnmenu/creationmenu/content/contenttypes/weapons.lua — CRG-24, the
    -- engine is a third party too): it never looked at vgui/entities/, so that
    -- third VTF was already dead weight.
    SWEP.IconOverride = ICON

    -- Weapon selection. WepSelectIcon is a surface TEXTURE ID and cannot hold a
    -- PNG material, so the draw is taken over instead of the field being set.
    -- weapon_base's version (gamemodes/base/entities/weapons/weapon_base/
    -- cl_init.lua) insets 10 px and draws a 2:1 rect; the logo is square, so it
    -- takes that rect's HEIGHT and is centred. PrintWeaponInfo is still called
    -- because the base calls it — this SWEP stubs it to false further down, and
    -- that stays the stub's decision, not this function's.
    -- This is ALSO the HUD the author sees: the DGL4 holo HUD does not paint
    -- the icon itself, its weaponicon component calls this same method for any
    -- class it has no art for (dev/other/DGL4 .../components/weaponicon.lua).
    function SWEP:DrawWeaponSelection(x, y, wide, tall, alpha)
        -- THE HEIGHT OF THIS BOX IS NOT THE HEIGHT YOU CAN DRAW IN. Measured on
        -- the author's HUD after the 1st pass came out clipped: DGL4 hands us a
        -- 140x100 box centred on a panel that is only 144x72, and then scissors
        -- to the PANEL (weaponicon.lua PerformLayout -> _h = size * 100/140;
        -- animatedpanel.lua:189 -> SetScissorRect over selection_size). 14 px
        -- above and 14 below never reach the screen, so a square fitted to
        -- `tall` loses its top and bottom. `wide` is the honest one (140 vs
        -- 144), and the size weapon_base itself paints is (wide - 20) / 2 — the
        -- number every stock icon is laid out around, so it is the one that
        -- fits wherever the base fits. `tall` still clamps, for a box that is
        -- taller than wide.
        local size = math.min((wide - 20) * 0.5, tall * 0.8)
        surface.SetDrawColor(255, 255, 255, alpha)
        surface.SetMaterial(iconMat)
        surface.DrawTexturedRect(x + (wide - size) * 0.5, y + (tall - size) * 0.5, size, size)
        -- same anchor the base passes, resolved against the unshifted args
        self:PrintWeaponInfo(x + wide + 10, y + tall * 0.95, alpha)
    end
end

SWEP.PrintName      = "Hands"
SWEP.Category       = "Corpus"
SWEP.Author         = "WebKnight/Twilight Sparkle/Internet Overdoser/Buu342 (Corpus recycle)"
SWEP.Instructions   = "Unarmed hands. Punch with both mouse buttons, R to inspect."

SWEP.Spawnable      = true
SWEP.UseHands       = true

SWEP.ViewModel      = Model("models/weapons/c_arms_apex.mdl")
SWEP.WorldModel     = ""

SWEP.ViewModelFOV   = 64
SWEP.BobScale       = 1.3
SWEP.SwayScale      = 1.3

SWEP.Primary.ClipSize     = -1
SWEP.Primary.DefaultClip  = -1
SWEP.Primary.Automatic    = true
SWEP.Primary.Ammo         = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = true
SWEP.Secondary.Ammo        = "none"

SWEP.ViewModelFlip  = false

-- the holster flow (corpus_cargo_holster.lua) always selects explicitly;
-- engine auto-switch would only add nondeterminism (original had true)
SWEP.AutoSwitchTo   = false
SWEP.AutoSwitchFrom = true

SWEP.Slot           = 0
SWEP.SlotPos        = 0

SWEP.DrawAmmo         = false
SWEP.DrawCrosshair    = false

SWEP.DisableDuplicator  = true
SWEP.BounceWeaponIcon   = false
SWEP.m_bPlayPickupSound = false

SWEP.HitDistance = 60

-- Animation/hitmarker toggles (renamed from cl_apexmelee_*). Created in
-- shared scope like the original settings file: SWEP:Think runs on both
-- realms and reads them through these same handles.
local cvAnimWalk       = CreateClientConVar("cargo_hands_animwalk", "1", true, false, "Hands: walk animation")
local cvAnimSprint     = CreateClientConVar("cargo_hands_animsprint", "1", true, false, "Hands: sprint animation")
local cvAnimCrouch     = CreateClientConVar("cargo_hands_animcrouch", "1", true, false, "Hands: crouch animation")
local cvAnimJump       = CreateClientConVar("cargo_hands_animjump", "1", true, false, "Hands: jump animation")
local cvAnimJumpSprint = CreateClientConVar("cargo_hands_animjumpsprint", "1", true, false, "Hands: sprinting jump animation")
local cvHitmarker      = CreateClientConVar("cargo_hands_hitmarker", "1", true, false, "Hands: melee hitmarker")

-- registered by corpus_cargo_holster.lua via Corpus.Net.Register("cargo",
-- "hands_hitmarker"); the SWEP only uses the resulting literal (weapon
-- scripts cannot touch the module table in file scope)
local NET_HITMARKER = "corpus_cargo_hands_hitmarker"

local function genOrderedTbl(str, min, max)
    if not min then min = 1 end
    if not max then
        max = min
        min = 1
    end
    local tbl = {}
    for i = min, max do
        table.insert(tbl, str:format(i))
    end
    return tbl
end

sound.Add({
    name = "corpus_hands.deploy",
    channel = CHAN_AUTO,
    level = 65,
    volume = 1,
    pitch = {80, 110},
    sound = genOrderedTbl("weapons/Pilot_Mvmt_Foley_FistRise_1ch_v1_%i.wav", 3),
})

sound.Add({
    name = "corpus_hands.inspect",
    channel = CHAN_AUTO,
    level = 65,
    volume = 1,
    pitch = {80, 110},
    sound = "weapons/Mvmt_Generic_KnuckleCrack_v1_01.wav",
})

local swingSounds = genOrderedTbl("weapons/Pilot_Mvmt_Melee_LeftHook_1P_2ch_v1_%i.wav", 3)
for _, s in ipairs(genOrderedTbl("weapons/Pilot_Mvmt_Melee_RightHook_1P_2ch_v1_%i.wav", 3)) do
    table.insert(swingSounds, s)
end

sound.Add({
    name = "corpus_hands.melee_swing",
    channel = CHAN_AUTO,
    level = 65,
    volume = 1,
    pitch = {90, 110},
    sound = swingSounds,
})

sound.Add({
    name = "corpus_hands.melee_punch",
    channel = CHAN_AUTO,
    level = 65,
    volume = 1,
    pitch = {90, 110},
    sound = genOrderedTbl("weapons/Pilot_Mvmt_Melee_Elbow_1P_2ch_v1_%i.wav", 3),
})

sound.Add({
    name = "corpus_hands.uppercut_swing",
    channel = CHAN_AUTO,
    level = 65,
    volume = 1,
    pitch = {90, 110},
    sound = genOrderedTbl("weapons/Pilot_Mvmt_Melee_Uppercut_1P_2ch_v1_%i.wav", 3),
})

sound.Add({
    name = "corpus_hands.melee_hit",
    channel = CHAN_AUTO,
    level = 65,
    volume = 1,
    pitch = {90, 115},
    sound = genOrderedTbl("weapons/Pilot_Mvmt_Melee_Hit_Flesh_1P_2ch_v1_%i.wav", 6),
})

sound.Add({
    name = "corpus_hands.melee_hit_world",
    channel = CHAN_AUTO,
    level = 75,
    volume = 1,
    pitch = {90, 115},
    sound = genOrderedTbl("weapons/Imp_Player_MeleePunch_Default_1ch_v1_%i.wav", 4),
})

sound.Add({
    name = "corpus_hands.melee_hit_concrete",
    channel = CHAN_AUTO,
    level = 75,
    volume = 1,
    pitch = {90, 115},
    sound = genOrderedTbl("weapons/Imp_Player_MeleePunch_Concrete_1ch_v1_%i.wav", 4),
})

sound.Add({
    name = "corpus_hands.melee_hit_water",
    channel = CHAN_AUTO,
    level = 75,
    volume = 1,
    pitch = {90, 115},
    sound = genOrderedTbl("weapons/Imp_Player_MeleePunch_Water_1ch_v1_%i.wav", 4),
})

sound.Add({
    name = "corpus_hands.melee_hit_metal",
    channel = CHAN_AUTO,
    level = 75,
    volume = 1,
    pitch = {90, 115},
    sound = genOrderedTbl("weapons/Imp_Player_MeleePunch_Metal_1ch_v1_%i.wav", 4),
})

sound.Add({
    name = "corpus_hands.kick_swing",
    channel = CHAN_AUTO,
    level = 65,
    volume = 1,
    pitch = {80, 115},
    sound = genOrderedTbl("weapons/Pilot_Mvmt_Melee_WallKick_1P_2ch_v1_%i.wav", 3),
})

-- MODEL EVENT FOLEY. c_arms_apex.mdl fires four animation events BY SOUNDSCRIPT
-- NAME, baked into the model: Apex_Cloth, Apex_Cloth_Jump, Apex_Gear_Sprint and
-- Apex_Gear_Jump (read out of the .mdl itself, not assumed). The original
-- declared them in its own lua/autorun/apexsfx.lua over sound/player/gear/*,
-- and that gear foley is precisely what the recycle agreement removed (header),
-- so every sprint and every jump printed
--     CSoundEmitterSystemBase::GetParametersForSound: No such sound Apex_Cloth
-- into the console (author repro 2026-07-30). The model is NOT recompiled — the
-- port keeps the original path — so the events keep firing no matter what: the
-- only place the spam can die is the soundscript table, which is what this loop
-- fills. common/null.wav is the engine's own silent sample (verified present in
-- hl2_sound_misc_dir.vpk, which GMod mounts). MUTE and not re-voiced on
-- purpose: sounding them again needs cloth/gear foley this repo does not own.
for _, event in ipairs({"Apex_Cloth", "Apex_Cloth_Jump", "Apex_Gear_Sprint", "Apex_Gear_Jump"}) do
    sound.Add({
        name = event,
        channel = CHAN_AUTO,
        level = 0,
        volume = 0,
        sound = "common/null.wav",
    })
end

util.PrecacheSound("corpus_hands.deploy")
util.PrecacheSound("corpus_hands.inspect")
util.PrecacheSound("corpus_hands.melee_swing")
util.PrecacheSound("corpus_hands.uppercut_swing")
util.PrecacheSound("corpus_hands.melee_punch")
util.PrecacheSound("corpus_hands.melee_hit")
util.PrecacheSound("corpus_hands.melee_hit_world")
util.PrecacheSound("corpus_hands.melee_hit_water")
util.PrecacheSound("corpus_hands.melee_hit_metal")
util.PrecacheSound("corpus_hands.melee_hit_concrete")
util.PrecacheSound("corpus_hands.kick_swing")

local SwingSound      = Sound("corpus_hands.melee_swing")
local SwingSound2     = Sound("corpus_hands.melee_punch")
local UppercutSound   = Sound("corpus_hands.uppercut_swing")

local DeploySound     = Sound("corpus_hands.deploy")
local HitSound        = Sound("corpus_hands.melee_hit")
local WorldHitSound   = Sound("corpus_hands.melee_hit_world")
local WaterHitSound   = Sound("corpus_hands.melee_hit_water")
local MetalHitSound   = Sound("corpus_hands.melee_hit_metal")
local ConcreteHitSound = Sound("corpus_hands.melee_hit_concrete")
local InspectSound    = Sound("corpus_hands.inspect")

-- Damage per animation, keyed by the name SetAnim networks in CurrentAnim.
-- The original ladder (37-47 base, up to 115 on the crouched uppercut) is an
-- Apex legend punching through a shield; these are bare fists in a survival
-- context, so the whole ladder is scaled ~1/10 and only the relative weight of
-- the combo finishers is kept. The knockback forces below are NOT scaled: they
-- are the original authors' tuning and only bite on a dying target.
local DAMAGE = {
    fists_left          = {3, 4},
    fists_right         = {3, 4},
    fists_uppercut      = {5, 7},   -- combo finisher (primary)
    fists_elbowstrike   = {5, 7},   -- combo finisher (secondary)
    fists_uppercut2     = {7, 12},  -- crouched
    fists_uppercut2_alt = {7, 12},  -- crouched
}
local DAMAGE_DEFAULT = {3, 4}

-- Knockback scale. The forces below are the original authors' numbers ("yes we
-- need those specific numbers") and they are tuned for 37-115 damage Apex
-- punches: a jab pushes a ~85 kg ragdoll at ~150 u/s and the crouched uppercut
-- throws it UP at ~300 u/s. Reviving the per-animation branches (see ANIM
-- SOURCE FIX) applied them for the first time and an NPC literally took off
-- (author repro 2026-07-14). One knob, applied to all of them, so the relative
-- shape of that tuning survives: a fist staggers, it does not launch.
local FORCE_SCALE = 0.2

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "AnimationTime")
    self:NetworkVar("Float", 1, "NextMeleeAttack")
    self:NetworkVar("Int", 0, "Combo")
    self:NetworkVar("Int", 1, "AnimPriority")
    self:NetworkVar("String", 0, "CurrentAnim")
    self:NetworkVar("Bool", 0, "LastGroundState")
end

function SWEP:Initialize()
    self:SetHoldType("fist")
end

function SWEP:SetAnim(anim, forceplay, animpriority)
    if forceplay == nil then forceplay = false end
    if animpriority == nil then animpriority = 0 end

    -- if idle, or forced with enough priority, play the given animation
    if self:IsIdle() or (forceplay and self:GetAnimPriority() <= animpriority) then
        local vm = self.Owner:GetViewModel()
        if not IsValid(vm) then return end

        -- see ANIM TIMING FIX in the header: the duration is asked for THIS
        -- sequence, not for "whatever the viewmodel happens to be playing"
        local seq = vm:LookupSequence(anim)
        if seq < 0 then return end -- unknown sequence: leave the state alone

        local rate = vm:GetPlaybackRate()
        if rate <= 0 then rate = 1 end

        self:SetCurrentAnim(anim)
        vm:SendViewModelMatchingSequence(seq)
        self:SetAnimationTime(CurTime() + vm:SequenceDuration(seq) / rate)
        self:SetAnimPriority(animpriority)
    end
end

function SWEP:IsIdle()
    return self:GetCurrentAnim() == "idle1" or self:GetAnimationTime() < CurTime()
end

function SWEP:HandleAnimations()
    if self:GetAnimationTime() ~= 0 and self:GetAnimationTime() < CurTime() then
        self:SetAnimationTime(0)
        self:SetAnimPriority(0)
    end
end

function SWEP:Deploy()
    if not IsValid(self.Owner) then return true end

    local speed = GetConVarNumber("sv_defaultdeployspeed")
    local vm = self.Owner:GetViewModel()
    if not IsValid(vm) then return true end

    self:EmitSound(DeploySound)
    self:SetHoldType("fist")
    vm:SetWeaponModel("models/weapons/c_arms_apex.mdl", self)
    vm:SetPlaybackRate(speed)

    self:SetAnim("deploy", true, 1)

    -- gate both attacks behind the deploy animation we just started. The
    -- original measured it BEFORE starting it (same SequenceDuration() footgun
    -- as SetAnim) and only got away with it because a freshly set weapon model
    -- leaves sequence 0 — "Deploy" — playing. SetAnim already tracked the
    -- honest end time; reuse it.
    local ready = self:GetAnimationTime()
    self:SetNextPrimaryFire(ready)
    self:SetNextSecondaryFire(ready)

    if SERVER then
        self:SetCombo(0)
    end

    return true
end

function SWEP:Holster()
    return true
end

function SWEP:OnDrop()
    self:Remove() -- you can't drop fists
end

-- ------------------------------------------------------------------
-- Dark-arms fix (see header): drive the viewmodel lighting ourselves so the
-- model's broken $illumposition never gets a say. CLIENT only.
-- ------------------------------------------------------------------
if CLIENT then
    -- never let the arms go fully black; keep them reacting to the room
    local LIGHT_FLOOR = 0.16 -- minimum ambient per channel
    local KEY_BOOST   = 1.35 -- top-down key light, for a little volume

    -- Apply a hand-built lighting box for the current frame. Sampled at the
    -- player's EYE position: a point that tracks the head, not the floor
    -- patch the bad illumposition drifts onto when looking at the horizon.
    function SWEP:ApplyHandsLighting()
        local ply = self.Owner
        local amb
        if IsValid(ply) then
            amb = render.GetLightColor(ply:EyePos())
        end
        local r = math.max(amb and amb.x or LIGHT_FLOOR, LIGHT_FLOOR)
        local g = math.max(amb and amb.y or LIGHT_FLOOR, LIGHT_FLOOR)
        local b = math.max(amb and amb.z or LIGHT_FLOOR, LIGHT_FLOOR)

        render.SuppressEngineLighting(true)
        render.ResetModelLighting(r, g, b)          -- uniform ambient, all 6 faces
        render.SetModelLighting(BOX_TOP, r * KEY_BOOST, g * KEY_BOOST, b * KEY_BOOST)
    end

    function SWEP:PreDrawViewModel(vm, weapon, ply)
        self:ApplyHandsLighting()
    end

    function SWEP:PostDrawViewModel(vm, weapon, ply)
        render.SuppressEngineLighting(false)
    end

    -- UseHands = true draws the playermodel's c_hands in a separate pass;
    -- cover it too so a visible seam of hand never lights differently
    function SWEP:PreDrawPlayerHands(hands, vm, ply, weapon)
        self:ApplyHandsLighting()
    end

    function SWEP:PostDrawPlayerHands(hands, vm, ply, weapon)
        render.SuppressEngineLighting(false)
    end
end

-- Button = hand, fixed: primary is the LEFT fist, secondary the RIGHT one (the
-- model ships both sequences). The original declared PrimaryAttack(right), but
-- the engine never passes an argument to PrimaryAttack — the parameter was dead
-- and always nil, so it is dropped and the intent stated outright.
function SWEP:PrimaryAttack()
    self:SetHoldType("fist")
    self.Owner:SetAnimation(PLAYER_ATTACK1)

    local anim = "fists_left"

    timer.Simple(0.1, function()
        if not IsValid(self) then return end
        self.Owner:ViewPunch(Angle(-1.5, -8, 0))
    end)

    if self:GetCombo() >= 2 then
        anim = "fists_uppercut"
        self:EmitSound(SwingSound2)
    end
    self:SetAnim(anim, true, 3)

    self:EmitSound(SwingSound)

    self:SetNextMeleeAttack(CurTime() + 0.2)

    self:SetNextPrimaryFire(CurTime() + 0.9)
    self:SetNextSecondaryFire(CurTime() + 0.9)

    if self.Owner:Crouching() then
        self:SetAnim("fists_uppercut2", true, 3)
        self:EmitSound(UppercutSound)
        timer.Simple(0.2, function()
            if not IsValid(self) then return end
            self.Owner:ViewPunch(Angle(-7.5, -7, 0))
        end)
    end
end

local phys_pushscale = GetConVar("phys_pushscale")
function SWEP:DealDamage()
    -- see ANIM SOURCE FIX in the header: the swing that landed is the one
    -- SetAnim networked, not a viewmodel sequence index read against the
    -- weapon entity's (empty) world model
    local anim = self:GetCurrentAnim()

    self.Owner:LagCompensation(true)

    local tr = util.TraceLine({
        start = self.Owner:GetShootPos(),
        endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * self.HitDistance,
        filter = self.Owner,
        mask = MASK_SHOT_HULL,
    })

    if not IsValid(tr.Entity) then
        tr = util.TraceHull({
            start = self.Owner:GetShootPos(),
            endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * self.HitDistance,
            filter = self.Owner,
            mins = Vector(-10, -10, -8),
            maxs = Vector(10, 10, 8),
            mask = MASK_SHOT_HULL,
        })
    end

    -- the second clause matters in single player: SWEP:Think runs shared there
    if tr.Hit and (SERVER or not (game.SinglePlayer() and CLIENT)) then
        if tr.HitWorld then
            self:EmitSound(WorldHitSound)
        elseif tr.MatType == MAT_CONCRETE then
            self:EmitSound(ConcreteHitSound)
        elseif tr.MatType == MAT_WOOD then
            self:EmitSound(WorldHitSound)
        elseif tr.MatType == MAT_METAL then
            self:EmitSound(MetalHitSound)
        elseif tr.MatType == MAT_FLESH then
            self:EmitSound(HitSound)
        else
            self:EmitSound(WorldHitSound)
        end
    end

    local hit = false
    local scale = phys_pushscale:GetFloat()
    -- knockback on a character: the original tuning, brought down to fist size.
    -- The prop shove further down keeps the raw `scale` — that one always ran
    -- and nobody complained about a punched barrel moving.
    local kb = scale * FORCE_SCALE

    if SERVER and IsValid(tr.Entity) and (tr.Entity:IsNPC() or tr.Entity:IsPlayer() or tr.Entity:Health() > 0) then
        local dmginfo = DamageInfo()

        local attacker = self.Owner
        if not IsValid(attacker) then attacker = self end
        dmginfo:SetAttacker(attacker)

        dmginfo:SetInflictor(self)

        local dmg = DAMAGE[anim] or DAMAGE_DEFAULT
        dmginfo:SetDamage(math.random(dmg[1], dmg[2]))

        -- "yes we need those specific numbers" (original comment) — the shape of
        -- the original authors' tuning, through FORCE_SCALE
        if anim == "fists_left" then
            dmginfo:SetDamageForce(self.Owner:GetRight() * 5912 * kb + self.Owner:GetForward() * 12998 * kb)
        elseif anim == "fists_right" then
            dmginfo:SetDamageForce(self.Owner:GetRight() * -5912 * kb + self.Owner:GetForward() * 12989 * kb)
        elseif anim == "fists_uppercut" then
            dmginfo:SetDamageForce(self.Owner:GetUp() * 3158 * kb + self.Owner:GetForward() * 15012 * kb)
        elseif anim == "fists_uppercut2" then
            dmginfo:SetDamageForce(self.Owner:GetUp() * 25158 * kb + self.Owner:GetForward() * 15012 * kb + self.Owner:GetRight() * 8912 * kb)
        elseif anim == "fists_uppercut2_alt" then
            dmginfo:SetDamageForce(self.Owner:GetUp() * 25158 * kb + self.Owner:GetForward() * 15012 * kb + self.Owner:GetRight() * -8912 * kb)
        elseif anim == "fists_elbowstrike" then
            dmginfo:SetDamageForce(self.Owner:GetUp() * 3158 * kb + self.Owner:GetForward() * 11012 * kb)
        end

        SuppressHostEvents(NULL) -- let breakable gibs spawn client-side in multiplayer
        tr.Entity:TakeDamageInfo(dmginfo)
        SuppressHostEvents(self.Owner)

        hit = true
        if (tr.Entity:IsPlayer() or tr.Entity:IsNPC())
            and util.NetworkStringToID(NET_HITMARKER) ~= 0 then
            net.Start(NET_HITMARKER)
            net.WriteEntity(tr.Entity)
            net.Send(self.Owner)
        end
    end

    if IsValid(tr.Entity) then
        local phys = tr.Entity:GetPhysicsObject()
        if IsValid(phys) then
            phys:ApplyForceOffset(self.Owner:GetAimVector() * 180 * phys:GetMass() * scale, tr.HitPos)
        end
    end

    if SERVER then
        if hit and anim ~= "fists_uppercut" then
            self:SetCombo(self:GetCombo() + 1)
        else
            self:SetCombo(0)
        end
    end

    self.Owner:LagCompensation(false)
end

function SWEP:SecondaryAttack()
    self:SetHoldType("fist")
    self.Owner:SetAnimation(PLAYER_ATTACK1)

    local anim = "fists_right"
    if self:GetCombo() >= 2 then
        anim = "fists_elbowstrike"
    end

    self:SetAnim(anim, true, 3)

    timer.Simple(0.1, function()
        if not IsValid(self) then return end
        self.Owner:ViewPunch(Angle(-1.5, 8, 0))
    end)

    self:EmitSound(SwingSound)

    self:SetNextMeleeAttack(CurTime() + 0.2)

    self:SetNextPrimaryFire(CurTime() + 0.9)
    self:SetNextSecondaryFire(CurTime() + 0.9)

    if self.Owner:Crouching() then
        self:SetAnim("fists_uppercut2_alt", true, 3)
        self:EmitSound(UppercutSound)
        timer.Simple(0.2, function()
            if not IsValid(self) then return end
            self.Owner:ViewPunch(Angle(-7.5, 7, 0))
        end)
    end
end

local inspectanims = { "inspect", "inspect2" }
function SWEP:Reload()
    if self:GetNextPrimaryFire() > CurTime() then return end
    if self:GetCurrentAnim() ~= inspectanims[1] and self:GetCurrentAnim() ~= inspectanims[2] then
        self:SetAnim(table.Random(inspectanims), true, 2)
        self:EmitSound(InspectSound)
    end
end

function SWEP:IsMoving()
    return self.Owner:KeyDown(IN_FORWARD) or self.Owner:KeyDown(IN_BACK)
        or self.Owner:KeyDown(IN_MOVELEFT) or self.Owner:KeyDown(IN_MOVERIGHT)
end

function SWEP:Think()
    local plyvel = Vector(self.Owner:GetVelocity().x, self.Owner:GetVelocity().y, 0):Length()

    self:HandleAnimations()

    local meleetime = self:GetNextMeleeAttack()
    if meleetime > 0 and CurTime() > meleetime then
        self:DealDamage()
        self:SetNextMeleeAttack(0)
    end

    -- both of these used to be rewritten on EVERY tick once the cooldown was
    -- over: a networked int and a hold type churning for nothing. Only write
    -- them when they actually change.
    if SERVER and CurTime() > self:GetNextPrimaryFire() + 0.1 and self:GetCombo() ~= 0 then
        self:SetCombo(0)
    end
    if SERVER and CurTime() > self:GetNextPrimaryFire() and self:GetHoldType() ~= "normal" then
        self:SetHoldType("normal")
    end

    -- jumping animations
    if self.Owner:KeyPressed(IN_JUMP) and self:GetLastGroundState() == true and not self.Owner:OnGround() then
        if plyvel > self.Owner:GetRunSpeed() * 0.9 then
            if cvAnimJumpSprint:GetBool() then
                self:SetAnim("jumprun", true, 1)
            end
        else
            if cvAnimJump:GetBool() then
                self:SetAnim("jumpstand", true, 1)
            end
        end
    end

    -- movement animations
    if self:IsMoving() and self.Owner:OnGround() and not self.Owner:Crouching()
        and self.Owner:WaterLevel() < 2 and plyvel > self.Owner:GetRunSpeed() * 0.9 then
        if self:GetCurrentAnim() ~= "sprint" then
            if cvAnimSprint:GetBool() then
                self:SetAnim("sprint", true)
            else
                self:SetAnim("idle1", true)
            end
        end
    elseif self:IsMoving() and self.Owner:OnGround() and self.Owner:WaterLevel() < 2
        and (plyvel > self.Owner:GetWalkSpeed() * 0.9
            or (self.Owner:Crouching() and plyvel > self.Owner:GetCrouchedWalkSpeed() * 0.9)) then
        if self.Owner:Crouching() and self:GetCurrentAnim() ~= "crouch_walk" then
            if cvAnimCrouch:GetBool() then
                self:SetAnim("crouch_walk", true)
            end
        elseif not self.Owner:Crouching() and self:GetCurrentAnim() ~= "walk" then
            if cvAnimWalk:GetBool() then
                self:SetAnim("walk", true)
            else
                self:SetAnim("idle1", true)
            end
        end
    else
        local force = false

        -- force if we were previously walking
        if self:GetCurrentAnim() == "sprint" or self:GetCurrentAnim() == "crouch_walk"
            or self:GetCurrentAnim() == "walk" then
            force = true
        end

        -- force if we switched crouching
        if self:GetCurrentAnim() == "crouch" and self.Owner:OnGround() and not self.Owner:Crouching() then
            force = true
        elseif self:GetCurrentAnim() == "idle1" and self.Owner:OnGround() and self.Owner:Crouching() then
            force = true
        end

        if self.Owner:Crouching() and self.Owner:OnGround() then
            if self:GetCurrentAnim() ~= "crouch" then
                if cvAnimCrouch:GetBool() then
                    self:SetAnim("crouch", force)
                end
            end
        elseif self:GetCurrentAnim() ~= "idle1" then
            self:SetAnim("idle1", force)
        end
    end
    self:SetLastGroundState(self.Owner:OnGround())
end

function SWEP:PrintWeaponInfo()
    return false
end

if CLIENT then
    net.Receive(NET_HITMARKER, function()
        if not cvHitmarker:GetBool() then return end
        if IsValid(LocalPlayer():GetActiveWeapon()) then
            LocalPlayer():GetActiveWeapon().HitMarkerEnt = net.ReadEntity()
        end
    end)

    local hitmarkeralpha = 0
    local hitmarkersize = 0
    local hitmarkerholdtime = 0
    local hitmarkercolor = Color(255, 255, 255)
    local hitmarkermat = Material("corpus_cargo/hands_hitmarker.png")
    function SWEP:DrawHUD()
        -- arm the marker when we hit something
        if LocalPlayer():GetActiveWeapon().HitMarkerEnt ~= nil then
            hitmarkeralpha = 255
            hitmarkersize = 128
            hitmarkerholdtime = CurTime() + 0.5
            if not IsValid(LocalPlayer():GetActiveWeapon().HitMarkerEnt)
                or LocalPlayer():GetActiveWeapon().HitMarkerEnt:Health() > 0 then
                hitmarkercolor = Color(255, 255, 255)
            else
                hitmarkercolor = Color(255, 0, 0)
            end

            LocalPlayer():GetActiveWeapon().HitMarkerEnt = nil
        end

        -- draw it on screen
        if hitmarkerholdtime > CurTime() then
            local resw = ScrW() / 1600
            local resh = ScrH() / 900
            local hitw = hitmarkersize * resw
            local hith = hitmarkersize * resh

            hitmarkersize = Lerp(1 * FrameTime(), hitmarkersize, 0)
            hitmarkeralpha = Lerp(3 * FrameTime(), hitmarkeralpha, 0)

            surface.SetDrawColor(hitmarkercolor.r, hitmarkercolor.g, hitmarkercolor.b, hitmarkeralpha)
            surface.SetMaterial(hitmarkermat)
            surface.DrawTexturedRect(ScrW() / 2 - hitw / 2, ScrH() / 2 - hith / 2, hitw, hith)
        end
    end
end
