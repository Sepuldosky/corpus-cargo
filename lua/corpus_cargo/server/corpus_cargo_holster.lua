-- corpus_cargo_holster.lua — STALKER weapon order + holster (SERVER)
-- Roadmap #22 (slot keys 1-7, re-press to holster) + #4 (default hands).
-- The client only reports WHICH slot key was pressed (intent, contract #7);
-- this file resolves it against the server-owned equipment record and
-- selects, holsters or ignores. The unarmed state is either the recycled
-- Hands SWEP (lua/weapons/corpus_cargo_hands.lua) or no weapon at all —
-- per-player choice via the cargo_holster_hands userinfo convar (Utilities
-- tab, corpus_cargo_options.lua).
--
-- HOLSTER TRANSITION — recycled from "Simple Holster" (Chen, Workshop
-- 2546335680; author request 2026-07-23, map + wants in
-- dev/Cargo_SimpleHolster_Referencia.md). Every mod API name was verified
-- against the live code (dev/other/simple holster/lua/autorun/
-- sh_holsterweapon.lua, CRG-24). What is recycled:
--   * the animation cascade + "undraw" trick (sh:11, sh:293-306): a real
--     holster sequence plays forward; a weapon with only a draw animation
--     plays it BACKWARDS at 2x for half the duration — covers any weapon
--     without a dedicated holster anim.
--   * the framework exclusion list (sh:85): bases that animate their own
--     holster on switch (ArcCW/ARC9/TacRP/TFA/CW2/FAS2/UT99/SS/HLAZ) get no
--     manual anim — deploy hands right away and the base does its thing.
--   * the transition locks (sh:368-372): while holstering, IN_ATTACK +
--     IN_ATTACK2 + IN_RELOAD are scrubbed in StartCommand.
--   * last-weapon memory (sh:127/sh:280): m_hLastWeapon points back at the
--     holstered weapon, so lastinv (Q) toggles weapon <-> hands.
--   * the 0.5 s per-player rate limit on the holster action (sh:235).
-- Deliberate deviations from the original:
--   * m_flNextAttack is set to CurTime() + t — the mod passes the bare
--     duration (sh:309) where the engine compares absolute time, so its
--     lock never actually bit; the button scrub is what worked there.
--   * the switch itself stays server-side (our holster is intent-driven);
--     the mod switched client-side via input.SelectWeapon after a timer.
--   * ladder auto-holster (sh:145-180) is NOT ported — out of the agreed
--     scope; the wants list marks it optional.

local CARGO = Corpus.GetModule("cargo")

CARGO.Holster = CARGO.Holster or {}

-- slot number rides NET_SLOTKEY; 0 is the direct-holster intent (the
-- cargo_holster client concommand), 1-7 index CARGO.Slots.Hotkeys
local NET_SLOTKEY = Corpus.Net.Register("cargo", "slotkey")
-- consumed by the hands SWEP for its hitmarker (weapon scripts cannot call
-- Corpus.Net at file scope, so the SWEP uses the literal name)
Corpus.Net.Register("cargo", "hands_hitmarker")

local HANDS = "corpus_cargo_hands"

local cvAnim = CreateConVar("cargo_holster_anim", "1", FCVAR_ARCHIVE,
    "Play the weapon's holster animation (reverse-draw fallback) before switching to hands")

-- per-player holster style: 1 = the Hands SWEP, 0 = no weapon at all
local function HandsMode(ply)
    return ply:GetInfoNum("cargo_holster_hands", 1) ~= 0
end

local function GiveHands(ply)
    if ply:HasWeapon(HANDS) then return end
    -- the class sits in CARGO.Capture.Ignore; the flag is just the fast path
    ply.CargoEquipGive = true
    ply:Give(HANDS)
    ply.CargoEquipGive = nil
end

-- ------------------------------------------------------------------
-- Simple Holster recycle: animation resolution + transition locks
-- ------------------------------------------------------------------

-- Weapon bases that animate their own holster on switch: play nothing for
-- them and let the base do the transition. The mod's exclusion list (sh:85)
-- kept verbatim — it is the field map of which frameworks already do this
-- right (ARC9 is the one that matters in this project).
local function BaseAnimatesHolster(wep)
    if wep.ArcCW or wep.ARC9 or wep.ArcticTacRP or wep.IsTFAWeapon
        or wep.CW20Weapon or wep.IsFAS2Weapon or wep.IsUT99Weapon then
        return true
    end
    local class = wep:GetClass()
    if weapons.IsBasedOn(class, "weapon_ss2_base")
        or weapons.IsBasedOn(class, "weapon_ut2004_base") then
        return true
    end
    -- conditional bases: they animate only when their own convar says so
    local hlaz = GetConVar("hlaz_sv_holster")
    if hlaz ~= nil and hlaz:GetBool()
        and weapons.IsBasedOn(class, "weapon_hlaz_base") then
        return true
    end
    local ss = GetConVar("ss_sv_holsteranims")
    if ss ~= nil and ss:GetBool()
        and weapons.IsBasedOn(class, "weapon_ss_base") then
        return true
    end
    return false
end

-- The cascade (mod sh:11). Returns seq, hasHolsterAnim: with a real holster
-- sequence the anim plays forward; with only a draw to work with, the
-- caller plays it backwards at 2x and half duration (the "undraw" trick).
local function FindHolsterAnim(vm)
    local seq = vm:SelectWeightedSequence(ACT_VM_HOLSTER)
    if seq ~= -1 then return seq, true end
    seq = vm:LookupSequence("holster")
    if seq ~= -1 then return seq, true end
    seq = vm:SelectWeightedSequence(ACT_VM_DRAW)
    if seq ~= -1 then return seq, false end
    seq = vm:LookupSequence("draw")
    if seq ~= -1 then return seq, false end
    seq = vm:SelectWeightedSequence(ACT_SLAM_DETONATOR_THROW_DRAW)
    if seq ~= -1 then return seq, false end
    return nil, false
end

-- The actual switch into the player's chosen unarmed state (the immediate
-- pre-recycle behavior). `prev` is the weapon being holstered, if any.
local function DeployUnarmed(ply, prev)
    if HandsMode(ply) then
        GiveHands(ply)
        local active = ply:GetActiveWeapon()
        if not IsValid(active) or active:GetClass() ~= HANDS then
            ply:SelectWeapon(HANDS)
        end
        ply:DrawViewModel(true)
        ply.CargoVMHidden = nil
    else
        -- bare-hands holster (Simple Holster technique): no active weapon at
        -- all; hide the viewmodel so the last weapon doesn't linger frozen
        ply:SetActiveWeapon(NULL)
        ply:DrawViewModel(false)
        ply.CargoVMHidden = true
    end
    -- lastinv (Q) goes back to the weapon just holstered (mod sh:127/sh:280)
    if IsValid(prev) and prev:GetClass() ~= HANDS then
        ply:SetSaveValue("m_hLastWeapon", prev)
    end
end

-- Holster the current weapon into the player's chosen unarmed state.
-- `instant` skips the transition (spawn deploy — roadmap #4 wants hands NOW).
function CARGO.Holster.Holster(ply, instant)
    local active = ply:GetActiveWeapon()
    local canAnimate = cvAnim:GetBool() and instant ~= true
        and IsValid(active) and active:GetClass() ~= HANDS

    if not canAnimate then
        DeployUnarmed(ply, active)
        return
    end

    if ply.CargoHolstering then return end
    -- the mod's per-player rate limit on the holster ACTION (sh:235)
    if (ply.CargoNextHolster or 0) > CurTime() then return end
    ply.CargoNextHolster = CurTime() + 0.5

    local t = 0
    if not BaseAnimatesHolster(active) then
        local vm = ply:GetViewModel()
        if IsValid(vm) then
            local seq, hasanim = FindHolsterAnim(vm)
            if seq ~= nil then
                vm:SendViewModelMatchingSequence(seq)
                vm:SetPlaybackRate(hasanim and 1 or -2)
                -- reversed draw runs at 2x: half the base duration is honest
                t = vm:SequenceDuration(seq) * (hasanim and 1 or 0.5)
            end
        end
    end

    if t <= 0 then
        -- a framework that animates its own holster, or no usable sequence:
        -- switch now and let the base (or nothing) do the transition
        DeployUnarmed(ply, active)
        return
    end

    ply.CargoHolstering = true
    -- absolute time, unlike the original (see header): the engine compares
    -- m_flNextAttack against the clock, not against a duration
    ply:SetSaveValue("m_flNextAttack", CurTime() + t)

    timer.Simple(t, function()
        if not IsValid(ply) then return end
        ply.CargoHolstering = nil
        if not ply:Alive() then return end
        -- switched away by other means mid-animation (mouse wheel, engine):
        -- the holster is off, don't yank the new weapon out of his hand
        if ply:GetActiveWeapon() ~= active then return end
        DeployUnarmed(ply, active)
    end)
end

-- while the transition plays: no firing, no reloading (mod sh:368-372 — its
-- 10241 literal is exactly IN_ATTACK + IN_ATTACK2 + IN_RELOAD)
local LOCK_BUTTONS = bit.bor(IN_ATTACK, IN_ATTACK2, IN_RELOAD)
hook.Add("StartCommand", "corpus_cargo_holster_lock", function(ply, cmd)
    if ply.CargoHolstering and ply:Alive() then
        cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(LOCK_BUTTONS)))
    end
end)

-- A slot key pressed on the client. Empty slot = nothing happens (the key
-- is already swallowed client-side: the GMod bucket bar never opens).
function CARGO.Holster.SlotKey(ply, n)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply.CargoHolstering then return end -- mid-transition: inputs wait
    if (ply.CargoNextSlotKey or 0) > CurTime() then return end
    ply.CargoNextSlotKey = CurTime() + 0.1

    if n == 0 then
        CARGO.Holster.Holster(ply)
        return
    end

    -- 1-7 are the number-row keys; WheelSlots are wheel-only intents
    -- (8 = throwable, roadmap #31) that no key ever sends
    local slotId = CARGO.Slots.Hotkeys[n] or CARGO.Slots.WheelSlots[n]
    if slotId == nil then return end

    local blob = CARGO.Inventory.GetEquipped(ply, slotId)
    local def = istable(blob) and CARGO.Items.Get(blob.id) or nil
    local class = istable(def) and def.weapon_class or nil
    if not isstring(class) or class == "" then return end

    -- re-pressing the key of the weapon already in hand holsters it
    local active = ply:GetActiveWeapon()
    if IsValid(active) and active:GetClass() == class then
        CARGO.Holster.Holster(ply)
        return
    end

    -- the equip flow gave the SWEP when the item entered the slot; if a
    -- respawn race ate it, the loadout reconcile re-gives — don't fight it
    if not ply:HasWeapon(class) then return end

    if ply.CargoVMHidden then
        ply:DrawViewModel(true)
        ply.CargoVMHidden = nil
    end
    ply:SelectWeapon(class)
end

net.Receive(NET_SLOTKEY, function(_, ply)
    CARGO.Holster.SlotKey(ply, net.ReadUInt(4))
end)

-- any switch to a real weapon (slot key, mouse wheel, engine) lifts the
-- bare-hands viewmodel hide
hook.Add("PlayerSwitchWeapon", "corpus_cargo_holster_vm", function(ply, _, new)
    if IsValid(new) and ply.CargoVMHidden then
        ply.CargoVMHidden = nil
        ply:DrawViewModel(true)
    end
end)

-- Default hands on spawn (roadmap #4): with the capture active the player
-- spawns unarmed — instead of the engine's empty viewmodel, deploy the
-- chosen unarmed state. Runs AFTER the loadout re-gives (inventory hook)
-- and the capture churn (timers at 0 and the reconcile at 0.1) settle.
-- `instant`: a spawn deploy plays no holster animation.
hook.Add("PlayerLoadout", "corpus_cargo_holster_spawn", function(ply)
    timer.Simple(0.25, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local cvCapture = GetConVar("cargo_capture_weapons")
        if cvCapture == nil or not cvCapture:GetBool() then return end
        CARGO.Holster.Holster(ply, true)
    end)
end)
