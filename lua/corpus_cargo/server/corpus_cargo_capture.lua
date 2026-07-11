-- corpus_cargo_capture.lua — engine weapons become inventory items (SERVER)
-- Author call (first in-game pass, 2026-07-10): every weapon the engine
-- hands the player — gamemode loadout (physgun/toolgun/camera), loadout
-- mods like Quick Loadouts, world pickups — goes straight into the Cargo
-- inventory instead of the weapon bar. The player starts unarmed and arms
-- himself through the Primary/Secondary/Sidearm/Melee slots.
--
-- WHY WeaponEquip AND NOT PlayerCanPickupWeapon (compat lesson, verified
-- against the live code of "Left 4 Dead | Item Pickup System" 3744343101
-- on 2026-07-11): in hook.Call the FIRST non-nil return wins. Pickup mods
-- like L4D IPS never Give — they pre-authorize their own touch-pickup by
-- returning true from PlayerCanPickupWeapon; and a Give denied with false
-- leaves the weapon as a loose world entity. Our old unconditional false
-- both broke their flow and littered floating physguns. Capturing AFTER
-- the successful equip sidesteps every ordering conflict: the engine has
-- already consumed the world entity, every pickup mod saw its flow
-- complete, and we just convert + strip one tick later.

local CARGO = Corpus.GetModule("cargo")

CARGO.Capture = CARGO.Capture or {}

local cvCapture = CreateConVar("cargo_capture_weapons", "1", FCVAR_ARCHIVE,
    "Send every weapon the engine gives the player to the Cargo inventory (start unarmed)")

-- Classes the capture must leave alone. Hands/fists-style SWEPs belong here:
-- they ARE the unarmed state, not gear (the default-hands sub-block — Apex
-- Hands recycle — will extend this when it lands).
CARGO.Capture.Ignore = {
    ["weapon_fists"] = true,
}

local function EnsureDef(class, wep)
    local id = "wpn_" .. class
    if CARGO.Items.Get(id) ~= nil then return id end

    local name = class
    -- engine weapons report a localization token ("#HL2_Pistol"); the client
    -- resolves it with language.GetPhrase when registering the synced def
    if IsValid(wep) then
        local ok, printName = pcall(function() return wep:GetPrintName() end)
        if ok and isstring(printName) and printName ~= "" then name = printName end
    end

    CARGO.Items.Register({
        id = id,
        name = name,
        weight = 2.5, -- nominal: engine weapons declare no mass
        class = "unique",
        category = "weapons",
        weapon_class = class,
        autogen = true,
        trivia = "Auto-captured weapon (" .. class .. ").",
    })
    return id
end

-- dedup: one item per weapon class per player, counting grid AND equipped
local function HasWeaponItem(ply, class)
    local rec = CARGO.Inventory.GetRecord(ply)
    local function matches(uid)
        local blob = CARGO.Instances.Get(uid)
        local def = blob and CARGO.Items.Get(blob.id) or nil
        return def ~= nil and def.weapon_class == class
    end
    for _, entry in ipairs(rec.items) do
        if entry.uid and matches(entry.uid) then return true end
    end
    for _, uid in pairs(rec.equip) do
        if matches(uid) then return true end
    end
    return false
end

hook.Add("WeaponEquip", "corpus_cargo_capture", function(wep, ply)
    if not cvCapture:GetBool() then return end
    if not IsValid(wep) then return end
    -- older engine branches pass only the weapon; the owner lands a tick later
    if not IsValid(ply) then ply = wep:GetOwner() end
    -- our own equip flow gives weapons through this same engine path; the
    -- flag is only set synchronously around ply:Give, so read it NOW
    if IsValid(ply) and ply.CargoEquipGive then return end

    local class = wep:GetClass()
    if CARGO.Capture.Ignore[class] then return end
    -- def cached while the entity is alive; the strip below invalidates it
    local id = EnsureDef(class, wep)

    -- one tick later: the equip has fully settled (stripping mid-equip is
    -- crash-prone) and GetOwner is reliable on every engine branch
    timer.Simple(0, function()
        local owner = ply
        if not IsValid(owner) then
            owner = IsValid(wep) and wep:GetOwner() or nil
        end
        if not IsValid(owner) or not owner:IsPlayer() then return end
        if owner.CargoEquipGive then return end

        if not HasWeaponItem(owner, class) then
            if CARGO.Inventory.GiveItem(owner, id) then
                CARGO.Inventory.NotifyPickup(owner, id, 1)
            end
            -- over the hard weight cap the give fails: the weapon is still
            -- stripped (start-unarmed rule); the class is gone, not floating
        end
        if owner:HasWeapon(class) then owner:StripWeapon(class) end
    end)
end)
