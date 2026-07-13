-- corpus_cargo_holster.lua — STALKER weapon order + holster (SERVER)
-- Roadmap #22 (slot keys 1-7, re-press to holster) + #4 (default hands).
-- The client only reports WHICH slot key was pressed (intent, contract #7);
-- this file resolves it against the server-owned equipment record and
-- selects, holsters or ignores. The unarmed state is either the recycled
-- Hands SWEP (lua/weapons/corpus_cargo_hands.lua) or no weapon at all —
-- per-player choice via the cargo_holster_hands userinfo convar (Utilities
-- tab, corpus_cargo_options.lua).

local CARGO = Corpus.GetModule("cargo")

CARGO.Holster = CARGO.Holster or {}

-- slot number rides NET_SLOTKEY; 0 is the direct-holster intent (the
-- cargo_holster client concommand), 1-7 index CARGO.Slots.Hotkeys
local NET_SLOTKEY = Corpus.Net.Register("cargo", "slotkey")
-- consumed by the hands SWEP for its hitmarker (weapon scripts cannot call
-- Corpus.Net at file scope, so the SWEP uses the literal name)
Corpus.Net.Register("cargo", "hands_hitmarker")

local HANDS = "corpus_cargo_hands"

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

-- Holster the current weapon into the player's chosen unarmed state.
function CARGO.Holster.Holster(ply)
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
end

-- A slot key pressed on the client. Empty slot = nothing happens (the key
-- is already swallowed client-side: the GMod bucket bar never opens).
function CARGO.Holster.SlotKey(ply, n)
    if not IsValid(ply) or not ply:Alive() then return end
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
hook.Add("PlayerLoadout", "corpus_cargo_holster_spawn", function(ply)
    timer.Simple(0.25, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local cvCapture = GetConVar("cargo_capture_weapons")
        if cvCapture == nil or not cvCapture:GetBool() then return end
        CARGO.Holster.Holster(ply)
    end)
end)
