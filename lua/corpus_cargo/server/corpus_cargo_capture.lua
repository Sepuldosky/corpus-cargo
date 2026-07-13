-- corpus_cargo_capture.lua — engine weapons become inventory items (SERVER)
-- Author call (first in-game pass, 2026-07-10): every weapon the engine
-- hands the player — gamemode loadout (physgun/toolgun/camera), loadout
-- mods like Quick Loadouts, world pickups — goes straight into the Cargo
-- inventory instead of the weapon bar. The player starts unarmed and arms
-- himself through the Primary/Secondary/Sidearm/Melee slots.
--
-- WHY the capture rides WeaponEquip and not PlayerCanPickupWeapon (compat
-- lesson, verified against the live code of "Left 4 Dead | Item Pickup
-- System" 3744343101 on 2026-07-11): in hook.Call the FIRST non-nil return
-- wins. Pickup mods like L4D IPS never Give — they pre-authorize their own
-- touch-pickup by returning true from PlayerCanPickupWeapon; and a Give
-- denied with false leaves the weapon as a loose world entity. Our old
-- unconditional false both broke their flow and littered floating physguns.
-- Capturing AFTER the successful equip sidesteps every ordering conflict.
--
-- The WORLD GATE below (roadmap #16, author request 2026-07-11) DOES veto
-- PlayerCanPickupWeapon — but only for weapons RESTING in the world (entity
-- older than an instant): no touch-hoovering; WALK+USE takes, USE carries
-- like an HL2 prop. The lesson above still holds: every give flow (gamemode
-- loadout, our equip/reconcile) creates the entity and hands it over in the
-- same breath and passes untouched, and a denial never strands a floating
-- entity — the weapon was already lying on the ground on purpose.
--
-- The DROP side (roadmap #17, author request 2026-07-12) is the mirror: a
-- single PlayerDroppedWeapon reconciler catches ANY drop path (the native
-- cargo_drop, the "Drop Weapon" mod, or any other addon) — it empties the
-- equipment slot and tags the dropped entity with the instance uid so the
-- world gate and the take-back treat it as THAT item.

local CARGO = Corpus.GetModule("cargo")

CARGO.Capture = CARGO.Capture or {}

local cvCapture = CreateConVar("cargo_capture_weapons", "1", FCVAR_ARCHIVE,
    "Send every weapon the engine gives the player to the Cargo inventory (start unarmed)")
local cvWorldGuns = CreateConVar("cargo_weapon_world_pickup", "1", FCVAR_ARCHIVE,
    "World weapons: no touch pickup — WALK+USE takes them, USE carries them; weapon drops spawn the real gun")
local cvSandboxTools = CreateConVar("cargo_capture_sandbox_tools", "0", FCVAR_ARCHIVE,
    "Auto-capture the sandbox build tools (physgun/toolgun/camera) from the spawn loadout. 0 = drop them (the tool slots only hold one you ALREADY have — WALK+USE a world tool or a dev give)")
local cvNativeDrop = CreateConVar("cargo_native_drop", "1", FCVAR_ARCHIVE,
    "Provide Cargo's own 'drop weapon in hand' command (cargo_drop). The 'Drop Weapon' mod, if mounted, takes precedence — set 0 to use only the mod")

-- The sandbox build tools: their equipment "slots" are the circles in §15.2.
-- By default the engine loadout hands these out every spawn; auto-capturing
-- them stocks the inventory with tools the player never asked for (author
-- call, 2nd fullscreen pass 2026-07-12: the tool slot is for a tool you
-- ALREADY have, not a spawn handout). Only the ANONYMOUS loadout give is
-- dropped — a deliberate WALK+USE take or a dropped Cargo instance still
-- captures, so you can still put one in its slot. Mirrors CARGO.Slots.Tools.
local SANDBOX_TOOL_CLASSES = {
    weapon_physgun = true,
    gmod_tool      = true,
    gmod_camera    = true,
}

function CARGO.Capture.WorldGunsEnabled()
    return cvWorldGuns:GetBool()
end

-- Classes the capture must leave alone. Hands/fists-style SWEPs belong here:
-- they ARE the unarmed state, not gear.
CARGO.Capture.Ignore = {
    ["weapon_fists"] = true,
    -- Corpus default hands (recycled Apex Hands, roadmap #4) and the
    -- original mod, in case it is mounted alongside
    ["corpus_cargo_hands"] = true,
    ["apexswep"] = true,
}

-- Known engine/sandbox silhouettes: footprint {w, h} declared at the def
-- (explicit size beats auto quantization, Cargo_ItemImages §5). Author
-- calibration, first fullscreen in-game pass 2026-07-12: physgun reads as
-- a rifle, the camera is small. Classes not listed fall to the auto path
-- (now floored by ICON_CATEGORY_MINS).
local AUTOGEN_SIZES = {
    weapon_physgun    = { 4, 2 },
    weapon_physcannon = { 4, 2 },
    gmod_tool         = { 3, 2 }, -- {w,h}; author "2x3" = his alto×ancho = 3 wide × 2 tall (3rd pass 2026-07-12)
    gmod_camera       = { 2, 1 },
    weapon_pistol     = { 3, 2 },
    weapon_357        = { 3, 2 },
    weapon_smg1       = { 4, 2 },
    weapon_ar2        = { 5, 2 },
    weapon_shotgun    = { 5, 2 },
    weapon_crossbow   = { 5, 2 },
    weapon_rpg        = { 6, 2 },
    weapon_annabelle  = { 5, 2 },
    weapon_frag       = { 1, 1 },
    weapon_slam       = { 2, 1 },
    weapon_bugbait    = { 2, 2 },
    weapon_crowbar    = { 3, 1 },
    weapon_stunstick  = { 3, 1 },
}

-- Engine melee classes: their autogen def lands in the "melee" category so
-- the captured item equips into the Melee slot (STALKER key 1, roadmap
-- #22). Everything else stays generic "weapons" (primary/secondary/sidearm).
local AUTOGEN_MELEE = {
    weapon_crowbar   = true,
    weapon_stunstick = true,
}

local function RegisterAutogen(class, name)
    CARGO.Items.Register({
        id = "wpn_" .. class,
        name = name,
        weight = 2.5, -- nominal: engine weapons declare no mass
        class = "unique",
        category = AUTOGEN_MELEE[class] and "melee" or "weapons",
        weapon_class = class,
        size = AUTOGEN_SIZES[class],
        autogen = true,
        trivia = "Auto-captured weapon (" .. class .. ").",
    })
end

-- Autogen defs must survive restarts (CHANGELOG #6): they are born at
-- runtime (EnsureDef, when the engine hands over the weapon), so without a
-- registry of their own an equipped non-loadout weapon deserializes into a
-- blob whose id no longer resolves — PlayerLoadout skips its re-give and
-- the slot shows a weapon the player does not have. id -> { name,
-- weapon_class }, re-registered at boot, saved on every new registration.
local autogenDefs = Corpus.Data.Load("cargo", "autogen_defs") or {}

for id, meta in pairs(autogenDefs) do
    -- engine names are localization tokens ("#HL2_Pistol") stored raw — the
    -- client resolves them when the def snapshot arrives, same as first time
    if istable(meta) and isstring(meta.weapon_class) and meta.weapon_class ~= ""
        and CARGO.Items.Get(id) == nil then
        local name = isstring(meta.name) and meta.name ~= "" and meta.name
            or meta.weapon_class
        RegisterAutogen(meta.weapon_class, name)
    end
end

local function EnsureDef(class, wep)
    local id = "wpn_" .. class

    local name = class
    -- engine weapons report a localization token ("#HL2_Pistol"); the client
    -- resolves it with language.GetPhrase when registering the synced def
    if IsValid(wep) then
        local ok, printName = pcall(function() return wep:GetPrintName() end)
        if ok and isstring(printName) and printName ~= "" then name = printName end
    end

    local existing = CARGO.Items.Get(id)
    if existing ~= nil then
        -- a def resurrected from a bare blob id (heal below) carries the
        -- class as placeholder name — upgrade it now that the real weapon
        -- handed over its print name
        if existing.autogen and existing.name == class and name ~= class then
            existing.name = name -- by-ref: the next snapshot carries it
            autogenDefs[id] = { name = name, weapon_class = class }
            Corpus.Data.Save("cargo", "autogen_defs", autogenDefs)
        end
        return id
    end

    RegisterAutogen(class, name)
    autogenDefs[id] = { name = name, weapon_class = class }
    Corpus.Data.Save("cargo", "autogen_defs", autogenDefs)
    return id
end

-- Blobs saved BEFORE the autogen registry existed reference defs that died
-- with their session — they render as blank/letter cells with no name
-- (in-game report 2026-07-11). The blob id itself encodes the class
-- (wpn_<class>): resurrect a minimal def when the record enters memory, so
-- those items resolve again; the placeholder name upgrades on the next real
-- capture of that class (EnsureDef above).
local function HealOrphanDefs(ply)
    local rec = CARGO.Inventory.GetRecord(ply)
    local healed = false
    local function heal(uid)
        local blob = CARGO.Instances.Get(uid)
        if blob == nil or CARGO.Items.Get(blob.id or "") ~= nil then return end
        local class = string.match(blob.id or "", "^wpn_(.+)$")
        if class == nil then return end
        RegisterAutogen(class, class)
        autogenDefs[blob.id] = { name = class, weapon_class = class }
        healed = true
    end
    for _, entry in ipairs(rec.items) do
        if entry.uid then heal(entry.uid) end
    end
    for _, uid in pairs(rec.equip) do heal(uid) end
    if healed then Corpus.Data.Save("cargo", "autogen_defs", autogenDefs) end
end

hook.Add("PlayerInitialSpawn", "corpus_cargo_capture_heal", HealOrphanDefs)

-- def behind an equip value: uid string (instance) or stack entry table
-- (throwable slot, §4 amendment) — both carry an item id to resolve
local function EquippedDefOf(val)
    local id
    if isstring(val) then
        local blob = CARGO.Instances.Get(val)
        id = blob and blob.id or nil
    elseif istable(val) then
        id = val.id
    end
    return id and CARGO.Items.Get(id) or nil
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
    for _, val in pairs(rec.equip) do
        local def = EquippedDefOf(val)
        if def ~= nil and def.weapon_class == class then return true end
    end
    return false
end

-- instances of `class` sitting in equip slots (the grid does not count:
-- only an EQUIPPED class claims the engine weapon as its own). The equipped
-- throwable stack counts too: its give must land as "keep", never re-capture.
local function EquippedClassCount(ply, class)
    local rec = CARGO.Inventory.GetRecord(ply)
    local n = 0
    for _, val in pairs(rec.equip) do
        local def = EquippedDefOf(val)
        if def ~= nil and def.weapon_class == class then n = n + 1 end
    end
    return n
end

-- Pure decision (offline-harness covered): what to do with a weapon the
-- engine just handed the player. An EQUIPPED class is NEVER touched — the
-- engine allows one entity per class, so that entity IS the equipped
-- weapon, whether the gamemode loadout, our loadout re-give or a pickup
-- mod spawned it. This replaces the CargoEquipGive-flag protection as the
-- correctness mechanism: the flag is set/cleared synchronously around
-- ply:Give, but on spawn WeaponEquip can fire DEFERRED and miss it
-- (CHANGELOG #6) — the flag below survives only as a fast-path skip.
function CARGO.Capture.Decide(equippedCount, hasItem)
    if (tonumber(equippedCount) or 0) > 0 then return "keep" end
    if hasItem then return "remove" end
    return "capture"
end

-- ------------------------------------------------------------------
-- World weapons (roadmap #16 + #17 parcial, author request 2026-07-11).
-- A weapon on the ground is the REAL SWEP entity: it renders itself (an
-- ARC9 gun draws its own assembled mirror + attachments — no prop stand-in
-- can match it, in-game report with the EFT pack), it keeps physics, and
-- nobody hoovers it by touch. Interactions: USE carries it like a light
-- HL2 prop (move it, throw it); WALK+USE takes it through the normal
-- engine pickup -> capture -> inventory.
-- ------------------------------------------------------------------

-- Spawn a weapon as a world entity: the drop of a weapon item, or a
-- deliberate take that did not fit going back to the ground. `uid` tags the
-- entity with the Cargo instance it embodies — the capture restores that
-- exact blob (attachments/condition) instead of minting a fresh item
-- (roadmap #17: a dropped gun keeps being ITS item).
function CARGO.Capture.SpawnWorldWeapon(class, pos, uid)
    if not isstring(class) or class == "" then return nil end
    local wep = ents.Create(class)
    if not IsValid(wep) then return nil end
    wep:SetPos(pos)
    wep.CargoInstanceUid = isstring(uid) and uid or nil
    wep.CargoWorldSpawned = true -- our drops are NEVER taken by touch
    wep:Spawn()
    -- a gun dropped straight out of the grid carries its stored magazine (#18);
    -- a fresh SWEP would otherwise spawn with its DefaultClip
    CARGO.Inventory.ApplyClipToEntity(wep, uid)
    return wep
end

-- The world gate. Deny order matters: the WALK+USE grant wins, our own
-- world spawns always deny, give flows (entity born an instant ago) pass,
-- and anything that has been RESTING in the world is denied.
hook.Add("PlayerCanPickupWeapon", "corpus_cargo_world_gate", function(ply, wep)
    if not cvWorldGuns:GetBool() then return end
    if ply.CargoEquipGive then return end        -- our equip give: engine decides
    if wep.CargoUseTaken then return true end    -- WALK+USE grant (PlayerUse below)
    if wep.CargoWorldSpawned then return false end
    if CurTime() - wep:GetCreationTime() < 0.5 then return end -- a give, not a pickup
    return false
end)

-- Look at a world weapon — or a dropped Cargo item — and press USE
-- (PlayerUse repeats every tick while +USE is held: debounced per player).
-- Plain USE = HL2 carry; WALK+USE = deliberate take. For weapons that is a
-- one-shot grant + engine pickup (the capture hook converts it); for items
-- the hook steps aside and lets the engine reach ENT:Use, which the
-- `return false` otherwise blocks (roadmap #27 — the item entity used to
-- dodge this gate entirely, so plain USE hoovered dropped ammo).
hook.Add("PlayerUse", "corpus_cargo_world_use", function(ply, ent)
    if not IsValid(ent) then return end

    local isItem = ent:GetClass() == "corpus_cargo_item"
    if not isItem then
        if not cvWorldGuns:GetBool() then return end
        if not ent:IsWeapon() then return end
        if IsValid(ent:GetOwner()) then return end   -- someone is holding it
    end

    if (ply.CargoNextWorldUse or 0) > CurTime() then return false end
    ply.CargoNextWorldUse = CurTime() + 0.4

    -- USE again while carrying LETS GO, like HL2 props (in-game report
    -- 2026-07-11: the engine releases on the same press BEFORE this hook
    -- runs, and we were re-grabbing it right back — so the press that
    -- grabbed marks the entity, and a marked press only releases)
    if ply.CargoCarryEnt == ent then
        ply.CargoCarryEnt = nil
        if isfunction(ent.IsPlayerHolding) and ent:IsPlayerHolding()
            and isfunction(ply.DropObject) then
            ply:DropObject()
        end
        return false
    end

    if ply:KeyDown(IN_WALK) then
        if isItem then return end -- deliberate take: ENT:Use collects it
        ent.CargoUseTaken = true -- grant for the gate + "deliberate" marker
        if not ply:PickupWeapon(ent) then
            ent.CargoUseTaken = nil
            CARGO.Inventory.Notice(ply, "You can't take that right now.")
        end
    else
        ply.CargoCarryEnt = ent
        ply:PickupObject(ent) -- HL2 prop carry: move it, throw it
    end
    return false -- the interaction is ours either way
end)

-- Spawnmenu gives are DELIBERATE (roadmap #30, in-game report 2026-07-12:
-- clicking a weapon icon never reached the inventory — without a toolgun
-- there was no way to obtain physgun/toolgun/camera at all). Left-clicking
-- an icon runs gm_giveswep -> CCGiveSWEP, which fires PlayerGiveSWEP right
-- before its anonymous ply:Give (sandbox commands.lua:940-948) — and ONLY
-- on that route, which makes it exactly the "the player asked for this by
-- hand" signal the sandbox-tools filter below could not see (both the spawn
-- loadout and the spawnmenu arrive as anonymous gives). Mark the player
-- with class + time; the capture consumes the mark as `deliberate`, same
-- semantics as a WALK+USE take. Nothing is returned from the hook: a
-- non-nil return would hijack sandbox's own allow/deny chain
-- (PlayerGiveSWEP true = allowed, sandbox player.lua:90-94).
hook.Add("PlayerGiveSWEP", "corpus_cargo_capture_spawnmenu", function(ply, class)
    if not IsValid(ply) or not isstring(class) then return end
    ply.CargoSpawnmenuGive = { class = class, t = CurTime() }
end)

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

    -- world-drop context, read NOW: by the time the timer runs the entity
    -- is the held weapon (or gone) and these fields are the only trace
    local dropUid = isstring(wep.CargoInstanceUid) and wep.CargoInstanceUid or nil
    local deliberate = wep.CargoUseTaken == true
    local dropPos = wep:GetPos()

    -- one tick later: the equip has fully settled (stripping mid-equip is
    -- crash-prone) and GetOwner is reliable on every engine branch
    timer.Simple(0, function()
        local owner = ply
        if not IsValid(owner) then
            owner = IsValid(wep) and wep:GetOwner() or nil
        end
        if not IsValid(owner) or not owner:IsPlayer() then return end
        if owner.CargoEquipGive then return end

        -- spawnmenu mark (#30): consumed on class match, short window — an
        -- expired or mismatched mark proves nothing about THIS give
        local mark = owner.CargoSpawnmenuGive
        if not deliberate and istable(mark) and mark.class == class
            and CurTime() - mark.t < 1 then
            deliberate = true
            owner.CargoSpawnmenuGive = nil
        end

        -- a dropped Cargo instance always comes back AS ITSELF: it is not a
        -- duplicate to dedup, it is a concrete item with its own blob
        local blob = dropUid and CARGO.Instances.Get(dropUid) or nil
        local action
        if blob ~= nil then
            action = "capture"
            -- the world entity is about to be Removed below: harvest whatever
            -- is left in its magazine into the blob first (#18), so re-equipping
            -- from the grid does not hand back a free full clip
            CARGO.Inventory.StoreClip(dropUid, wep)
        else
            action = CARGO.Capture.Decide(
                EquippedClassCount(owner, class), HasWeaponItem(owner, class))
        end

        -- "keep": this entity IS the equipped weapon (one per class) — hands
        -- off, no matter which give spawned it or whether the flag was seen
        if action == "keep" then return end

        -- sandbox build tools handed out anonymously by the spawn loadout are
        -- dropped, not stocked (cvSandboxTools): the tool slot only holds one
        -- the player already has. A deliberate take (walk+use sets `deliberate`)
        -- or a dropped Cargo instance (`blob`) still captures below.
        if action == "capture" and blob == nil and not deliberate
            and SANDBOX_TOOL_CLASSES[class] and not cvSandboxTools:GetBool() then
            action = "remove"
        end

        if action == "capture" then
            local ok
            if blob ~= nil then
                ok = CARGO.Inventory.GiveEntry(owner, { id = blob.id, uid = dropUid })
            else
                ok = CARGO.Inventory.GiveItem(owner, id)
            end
            if ok then
                CARGO.Inventory.NotifyPickup(owner, blob ~= nil and blob.id or id, 1)
            elseif blob ~= nil or deliberate then
                -- a DELIBERATE take (walk+use / a Cargo instance) that does
                -- not fit goes back to the ground — only the anonymous
                -- engine handout keeps the old start-unarmed rule (removed
                -- even when the give fails)
                CARGO.Capture.SpawnWorldWeapon(class, dropPos, dropUid)
                CARGO.Inventory.Notice(owner, "You can't carry that.")
            end
        end
        -- the dedup still rules (one item per class): a deliberate give of a
        -- class already owned is removed like any duplicate, but AUDIBLY —
        -- silently eating a spawnmenu click reads as a bug (#30). The rule
        -- itself does not change.
        if action == "remove" and deliberate then
            CARGO.Inventory.Notice(owner, "You already have one.")
        end

        -- capture/remove: take out ONLY the entity the engine just gave,
        -- never StripWeapon(class) — that strips every weapon of the class
        -- (in-game report 2026-07-11: it nuked equipped physgun/toolgun on
        -- reload). If `wep` is already invalid the duplicate is gone anyway.
        if IsValid(wep) then wep:Remove() end
    end)
end)

-- ------------------------------------------------------------------
-- Dropping a weapon (roadmap #17, author request 2026-07-12): the mirror of
-- the capture. A weapon leaving the player's hand must leave Cargo's
-- equipment record too, and keep being ITS instance so a take-back restores
-- the same blob. ONE universal reconciler on PlayerDroppedWeapon covers every
-- drop path — the native cargo_drop below, the "Drop Weapon" mod (Workshop
-- 946373028, whose +drop calls ply:DropWeapon) or any other addon. Author
-- call: the Drop Weapon mod WINS over the native command (its behavior is
-- left untouched; Cargo only reconciles). cargo_drop covers the no-mod case.
-- ------------------------------------------------------------------

hook.Add("PlayerDroppedWeapon", "corpus_cargo_drop_reconcile", function(ply, wep)
    if not IsValid(ply) or not ply:IsPlayer() or not IsValid(wep) then return end
    local class = wep:GetClass()

    -- only an EQUIPPED Cargo weapon is "in hand"; find the slot holding it
    local rec = CARGO.Inventory.GetRecord(ply)
    local uid, slotId
    for sid, u in pairs(rec.equip) do
        local blob = CARGO.Instances.Get(u)
        local def = blob and CARGO.Items.Get(blob.id) or nil
        if def ~= nil and def.weapon_class == class then
            uid, slotId = u, sid
            break
        end
    end
    if uid == nil then return end -- not a Cargo-equipped weapon: leave it alone

    -- unequip WITHOUT returning to the grid — the item is going to the world,
    -- not the backpack. Tag the entity so the world gate (no touch pickup) and
    -- the take-back (WeaponEquip reads CargoInstanceUid) treat it as THIS
    -- instance. The loaded magazine goes into the blob NOW (#18): the entity
    -- keeps its own Clip1 while it lies there, but the take-back destroys it.
    CARGO.Inventory.StoreClip(uid, wep)
    rec.equip[slotId] = nil
    wep.CargoInstanceUid = uid
    wep.CargoWorldSpawned = true
    CARGO.Inventory.Touch(ply)
end)

-- Native "drop the weapon in hand" — bindable exactly like the mod's +drop.
-- Funnels through ply:DropWeapon so the reconciler above does the bookkeeping
-- either way; the target position tosses it in front of the player.
concommand.Add("cargo_drop", function(ply)
    if not cvNativeDrop:GetBool() then return end
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end
    if CARGO.Capture.Ignore[wep:GetClass()] then return end -- hands aren't gear

    -- Third-party bug guard (in-game report 2026-07-12, ARC9 EFT revolver
    -- cr200ds): its per-round reload arms one timer.Simple PER ROUND, and each
    -- one reads swep:GetOwner():GetAmmoCount(...) guarding only IsValid(swep),
    -- never the owner (arc9_eft_cr200ds.lua:406). Dropping mid-reload orphans
    -- those timers and every one of them errors. ARC9 is COMPAT-RUNTIME — we
    -- never fork it — so we simply refuse to drop until the reload finishes.
    -- (An external drop mod calling ply:DropWeapon straight can still hit it;
    -- that is the mod's and ARC9's business, not ours.)
    if isfunction(wep.GetReloading) then
        local okR, reloading = pcall(wep.GetReloading, wep)
        if okR and reloading then
            CARGO.Inventory.Notice(ply, "Finish the reload before dropping.")
            return
        end
    end

    ply:DropWeapon(wep, ply:GetShootPos() + ply:GetAimVector() * 48)
end, nil, "Drop the weapon in hand into the world (keeps its Cargo instance)")
