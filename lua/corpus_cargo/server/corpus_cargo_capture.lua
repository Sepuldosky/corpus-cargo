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
    -- ARC9 MW2019 fists: same rule — an unarmed state is not gear
    ["arc9_cod2019_me_fist"] = true,
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

-- ------------------------------------------------------------------
-- Weapon KIND -> which equipment slots accept it (roadmap #39, author report
-- from the in-game pass of entry 23, 2026-07-14: "un RPG no puede ir a
-- Sidearm, obviamente"). It could, because `primary`, `secondary` and
-- `sidearm` all filter `category:weapons` (corpus_cargo_slots.lua) — so ANY
-- captured gun fit ANY of the three. The narrowing hook already existed
-- (`def.equip_slots`, honoured by Slots.CanEquip); the autogen def simply
-- never set it.
--
-- DERIVED, not catalogued — the same lesson the trivia paid for. Every ARC9
-- SWEP declares its own type: SWEP.Class is per-weapon ("Handgun", "Hand
-- Grenade", "Grenade launcher", "Submachine Gun") and SWEP.SubCategory is
-- per-pack ("LMGs", "7Pistols"). weapons.Get() resolves BOTH up the SWEP.Base
-- chain, which is how the akimbo pistols and the EFT variants that declare
-- neither still classify. A pack we have never seen classifies itself.
--
-- SWEP.Slot is NOT the signal, tempting as it looks: measured across the live
-- packs (2026-07-14) it is inconsistent — LMGs sit at 2 AND 3, shotguns share
-- 3 with snipers, and a third of the EFT guns declare no Slot at all. It is
-- the same unreliability roadmap #36 is about.
-- ------------------------------------------------------------------

-- FIRST match wins and the order is LOAD-BEARING: "Grenade launcher" contains
-- "grenade", and MW2019's "Throwing Knife" is Class = "Lethal", not melee.
local KIND_RULES = {
    { kind = "long",    words = { "launcher" } },
    { kind = "thrown",  words = { "grenade", "lethal", "tactical", "explosive", "mine" } },
    { kind = "melee",   words = { "melee", "knife", "shield", "bayonet", "machete", "axe" } },
    { kind = "sidearm", words = { "pistol", "handgun", "revolver", "sidearm" } },
    { kind = "long",    words = { "rifle", "carbine", "shotgun", "smg", "submachine",
                                  "machine gun", "lmg", "sniper", "marksman", "dmr",
                                  "assault", "battle" } },
}

local KIND_SLOTS = {
    sidearm = { "sidearm" },
    long    = { "primary", "secondary" },
    -- melee needs no equip_slots: its def lands in the "melee" CATEGORY and the
    -- Melee slot's own filter does the work (STALKER key 1, roadmap #22).
    -- `thrown` deliberately has NO entry: an ARC9 grenade is still a unique
    -- weapon item, and the Throwable slot takes a stackable STACK (§4
    -- amendment). Restricting it to a slot it cannot enter would make it
    -- unequippable — so it keeps today's behaviour until the throwable
    -- taxonomy of roadmap #32 grows to cover ARC9 grenades. Classified, not
    -- yet acted on.
}

-- Escape hatch + the engine weapons, which are not SWEPs at all: weapons.Get()
-- returns nil for them, so they have no type to declare. An entry here beats
-- everything the SWEP says.
CARGO.Capture.WeaponSlotKinds = {
    -- EFT MTs-255-12: a revolving SHOTGUN whose SWEP.Class is EFT's "Revolver"
    -- phrase (eft_class_weapon_revol — the shotguns pack is not in dev/other/,
    -- but the class phrases and the sidearm symptom pin it), so the sidearm
    -- rule matched before the SubCategory ("6Shotguns") was ever consulted
    -- (in-game report 2026-07-24: it equipped in Sidearm)
    arc9_eft_mts255   = "long",
    weapon_pistol     = "sidearm",
    weapon_357        = "sidearm",
    weapon_smg1       = "long",
    weapon_ar2        = "long",
    weapon_shotgun    = "long",
    weapon_crossbow   = "long",
    weapon_rpg        = "long",
    weapon_annabelle  = "long",
    weapon_crowbar    = "melee",
    weapon_stunstick  = "melee",
    weapon_slam       = "thrown",
    weapon_bugbait    = "thrown",
    -- the sandbox tools own their three class-restricted circle slots
    -- (Slots.Tools); they must NOT be narrowed to primary/secondary here
}

local function MatchKind(text)
    if not isstring(text) or text == "" then return nil end
    local hay = string.lower(text)
    for _, rule in ipairs(KIND_RULES) do
        for _, word in ipairs(rule.words) do
            if hay:find(word, 1, true) ~= nil then return rule.kind end
        end
    end
    return nil
end

local function WeaponKind(class)
    local override = CARGO.Capture.WeaponSlotKinds[class]
    if isstring(override) then return override end

    local swep = weapons.Get(class)
    if not istable(swep) then return nil end

    -- SWEP.Class ALONE first, and only then SubCategory. They must NOT be
    -- matched as one haystack: EFT files its hand grenades under the
    -- SubCategory "Grenades & Grenade launchers", which contains "launcher" —
    -- concatenating the two turns an F-1 into a long gun (caught by the offline
    -- harness before it ever shipped). SWEP.Class is the per-WEAPON truth
    -- ("Hand Grenade" vs "Grenade launcher"); SubCategory is only the per-PACK
    -- shelf it sits on, and it is a fallback, not a peer.
    -- ARC9's base default Class is "Unclassified Weapon": it matches no rule and
    -- correctly falls through to SubCategory.
    return MatchKind(swep.Class) or MatchKind(swep.SubCategory)
end

-- ------------------------------------------------------------------
-- Trivia (roadmap #38, author request 2026-07-14). The autogen def used to
-- carry a placeholder ("Auto-captured weapon (<class>)") that said nothing;
-- every captured gun in the game showed the same line. It does not need a
-- table: ARC9 SWEPs describe THEMSELVES, and weapons.Get(class) hands us the
-- whole SWEP table — including everything inherited up the SWEP.Base chain,
-- since weapons.Get() runs table.Inherit (that is how the akimbo pistols get
-- their base gun's text for free). Verified against the live code of ARC9 base
-- + Darsu EFT + ARC9MW, dev/other/, 2026-07-14:
--
--   * SWEP.Description — a PLAIN STRING by the time we read it: the packs call
--     ARC9:GetPhrase at SWEP-file load, so the localization is already done and
--     the server's copy is the English one (which is the mod's language anyway).
--   * SWEP.Trivia — { [labelKey] = valueKey }: manufacturer, caliber, action,
--     country, year. The two packs disagree on the key format and BOTH need
--     work (see ResolveTriviaRows).
--
-- weapons.Get() also means engine weapons (weapon_pistol et al.) return nil —
-- they are not scripted. Their text comes from Capture.WeaponTrivia, same as
-- the ARC9 classes whose pack forgot to write a description.
-- ------------------------------------------------------------------

-- EFT keys the trivia block with phrase keys its own pack never localized
-- ("eft_trivia_manuf1" has no entry in eft_en.lua), and ARC9's de-numbering is
-- dead code: cl_customize_ui_trivia.lua:127 does `title[#title]`, which indexes
-- a STRING with [] — always nil in Lua, so the order digit is never stripped
-- and ARC9's own menu literally prints "eft trivia manuf1". We do it properly:
-- resolve what ARC9 can resolve, then map the known stems.
local TRIVIA_STEMS = {
    manuf   = "Manufacturer",
    cal     = "Caliber",
    act     = "Action",
    country = "Country",
    year    = "Year",
    weight  = "Weight",
}

local function Phrase(str)
    if not isstring(str) or str == "" then return nil end
    if ARC9 == nil or not isfunction(ARC9.GetPhrase) then return str end
    local ok, resolved = pcall(ARC9.GetPhrase, ARC9, str)
    if ok and isstring(resolved) and resolved ~= "" then return resolved end
    return str -- GetPhrase returns nil for anything not in the table
end

-- MW2019 keys with a resolved label ("Country"); EFT with a raw phrase key
-- carrying a trailing order digit ("eft_trivia_manuf1"). One cleaner for both.
local function TriviaLabel(key)
    local label = Phrase(key) or key
    local order = tonumber(label:match("(%d)$")) or 0
    label = label:gsub("%d+$", "")
    local stem = label:match("trivia_(%a+)$")
    if stem ~= nil and TRIVIA_STEMS[stem] ~= nil then
        return TRIVIA_STEMS[stem], order
    end
    return (label:gsub("_", " ")), order
end

local function ResolveTriviaRows(class)
    local swep = weapons.Get(class)
    if not istable(swep) or not istable(swep.Trivia) then return nil end

    local rows = {}
    for key, value in pairs(swep.Trivia) do
        if isstring(key) and key ~= "BaseClass" then
            local text = Phrase(value)
            if text ~= nil then
                local label, order = TriviaLabel(key)
                rows[#rows + 1] = { label = label, value = text, order = order }
            end
        end
    end
    if #rows == 0 then return nil end

    -- pairs() order is not stable across boots and the rows would shuffle every
    -- map load. The digit the packs encode in the key IS the intended order;
    -- the label breaks ties for the packs that write no digit (MW2019).
    table.sort(rows, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.label < b.label
    end)
    for _, row in ipairs(rows) do row.order = nil end
    return rows
end

-- An entry in WeaponTrivia always WINS: it exists to fill the gaps the packs
-- left AND to correct the descriptions table.Inherit hands down from the wrong
-- parent (the M16A1's Base is arc9_eft_m4a1 — without an override it would
-- introduce itself as an M4A1).
local function ResolveTrivia(class)
    local override = (CARGO.Capture.WeaponTrivia or {})[class]
    if isstring(override) and override ~= "" then return override end

    local swep = weapons.Get(class)
    if istable(swep) and isstring(swep.Description) and swep.Description ~= "" then
        return swep.Description
    end
    -- no description anywhere: no paragraph. Better an honest blank than the
    -- old "Auto-captured weapon (...)" noise on every gun in the game.
    return nil
end

local function RegisterAutogen(class, name, caliber)
    local kind = WeaponKind(class)
    CARGO.Items.Register({
        id = "wpn_" .. class,
        name = name,
        -- real weight when the class is catalogued (GAMMA/EFT table, loaded
        -- by the manifest right before this file); 2.5 kg nominal otherwise
        weight = (CARGO.Capture.WeaponWeights or {})[class] or 2.5,
        -- base price from the twin table (exact class, else family prefix —
        -- weapon_vj_* prices flat). NO generic fallback on purpose: an
        -- uncatalogued class ends up with no value, and no value means not
        -- tradeable (Cargo_Trade §4) — better an honest hole in the economy
        -- than a made-up price for a gun nobody priced. The sandbox tools
        -- live in that hole.
        value = isfunction(CARGO.Capture.WeaponValueFor)
            and CARGO.Capture.WeaponValueFor(class)
            or (CARGO.Capture.WeaponValues or {})[class],
        class = "unique",
        category = (kind == "melee") and "melee" or "weapons",
        -- which of primary/secondary/sidearm accept it (Slots.CanEquip). nil =
        -- unrestricted, which is what melee (its category does the work),
        -- thrown and unclassified guns get
        equip_slots = KIND_SLOTS[kind or ""],
        weapon_class = class,
        size = AUTOGEN_SIZES[class],
        -- display label only (schema rule §3: a weapon's REAL type comes from
        -- its entity, never from the def) — the wheel hub and the tooltip
        -- ammo row read it (roadmap #33)
        ammo = isstring(caliber) and { caliber = caliber } or nil,
        autogen = true,
        -- both re-derived from the SWEP on every boot, so they are NOT
        -- persisted in autogen_defs: mount a new ARC9 pack and the guns you
        -- already captured describe themselves on the next map load
        trivia = ResolveTrivia(class),
        trivia_rows = ResolveTriviaRows(class),
    })
end

-- Display caliber of a live weapon (roadmap #33): its engine ammo type,
-- mapped to the label of the Cargo item that feeds it (the same label the
-- belt badge groups on). ARC9 declares the type as the plain class field
-- SWEP.Ammo ("smg1"/"ar2"/"357" across the EFT packs — verified against the
-- live code 2026-07-13); engine weapons answer GetPrimaryAmmoType. A type
-- Cargo does not manage resolves to nil and the def carries no caliber.
local function ResolveCaliber(wep)
    if not IsValid(wep) then return nil end
    local hl2
    if isstring(wep.Ammo) and wep.Ammo ~= "" then
        hl2 = wep.Ammo
    else
        local ok, t = pcall(wep.GetPrimaryAmmoType, wep)
        if ok and isnumber(t) and t >= 0 then hl2 = game.GetAmmoName(t) end
    end
    if hl2 == nil or CARGO.Ammo == nil then return nil end
    return CARGO.Ammo.CaliberForType(hl2)
end

-- Autogen defs must survive restarts (CHANGELOG #6): they are born at
-- runtime (EnsureDef, when the engine hands over the weapon), so without a
-- registry of their own an equipped non-loadout weapon deserializes into a
-- blob whose id no longer resolves — PlayerLoadout skips its re-give and
-- the slot shows a weapon the player does not have. id -> { name,
-- weapon_class }, re-registered at boot, saved on every new registration.
--
-- SERVER CONFIG, not game state (COR-19): the autogen catalog is what the
-- installed weapon packs happen to be, so it outlives deleting a save the same
-- way icon_overrides does. Declared here; today both scopes still resolve to
-- the same folder, so nothing moves.
local CATALOG = { scope = "config" }

local autogenDefs = Corpus.Data.Load("cargo", "autogen_defs", CATALOG) or {}

-- throwable-faced classes (roadmap #32): frag/SLAM never autogen — their
-- Cargo face is the canonical throwable stack (corpus_cargo_ammo.lua)
local function ThrowableFace(class)
    return CARGO.Ammo and istable(CARGO.Ammo.ThrowableClass)
        and CARGO.Ammo.ThrowableClass[class] or nil
end

-- VJ NPC-only classes (3rd in-game report 2026-07-24): a SWEP with
-- MadeForNPCsOnly self-deletes from a player's hands (VJ SWEP:Equip prints
-- "<name> removed! It's made for NPCs only!", weapon_vj_base/shared.lua:417)
-- — AFTER gifting its pickup ammo (:409-415). It can never be gear: an item
-- minted for one is an unequippable farm vector (drop → take → ammo grant →
-- entity deleted → item back, ad infinitum). weapons.Get resolves the flag
-- up the SWEP.Base chain; non-VJ classes have no field and return false.
local function NpcOnlyWeapon(class)
    if not isstring(class) or class == "" then return false end
    local swep = weapons.Get(class)
    return istable(swep) and swep.MadeForNPCsOnly == true
end

local autogenDirty = false
for id, meta in pairs(autogenDefs) do
    -- engine names are localization tokens ("#HL2_Pistol") stored raw — the
    -- client resolves them when the def snapshot arrives, same as first time
    if istable(meta) and ThrowableFace(meta.weapon_class or "") ~= nil then
        -- dead face (roadmap #32): a pre-#32 capture minted wpn_weapon_frag;
        -- re-registering it would resurrect the item-vs-stack conflict
        autogenDefs[id] = nil
        autogenDirty = true
    elseif istable(meta) and NpcOnlyWeapon(meta.weapon_class or "") then
        -- NPC-only VJ class captured before the block existed: the def dies
        -- here and the spawn purge below clears the items that pointed at it
        autogenDefs[id] = nil
        autogenDirty = true
    elseif istable(meta) and isstring(meta.weapon_class) and meta.weapon_class ~= ""
        and CARGO.Items.Get(id) == nil then
        local name = isstring(meta.name) and meta.name ~= "" and meta.name
            or meta.weapon_class
        RegisterAutogen(meta.weapon_class, name,
            isstring(meta.caliber) and meta.caliber or nil)
    end
end
if autogenDirty then Corpus.Data.Save("cargo", "autogen_defs", autogenDefs, CATALOG) end

local function EnsureDef(class, wep)
    local id = "wpn_" .. class

    local name = class
    -- engine weapons report a localization token ("#HL2_Pistol"); the client
    -- resolves it with language.GetPhrase when registering the synced def
    if IsValid(wep) then
        local ok, printName = pcall(function() return wep:GetPrintName() end)
        if ok and isstring(printName) and printName ~= "" then name = printName end
    end

    local caliber = ResolveCaliber(wep)

    local existing = CARGO.Items.Get(id)
    if existing ~= nil then
        local dirty = false
        -- a def resurrected from a bare blob id (heal below) carries the
        -- class as placeholder name — upgrade it now that the real weapon
        -- handed over its print name
        if existing.autogen and existing.name == class and name ~= class then
            existing.name = name -- by-ref: the next snapshot carries it
            dirty = true
        end
        -- defs captured before #33 carry no caliber: upgrade in place now
        -- that a live weapon of the class told us its type
        if existing.autogen and existing.ammo == nil and caliber ~= nil then
            existing.ammo = { caliber = caliber }
            dirty = true
        end
        if dirty then
            autogenDefs[id] = { name = existing.name, weapon_class = class,
                caliber = istable(existing.ammo) and existing.ammo.caliber or nil }
            Corpus.Data.Save("cargo", "autogen_defs", autogenDefs, CATALOG)
        end
        return id
    end

    RegisterAutogen(class, name, caliber)
    autogenDefs[id] = { name = name, weapon_class = class, caliber = caliber }
    Corpus.Data.Save("cargo", "autogen_defs", autogenDefs, CATALOG)
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
        if class == nil or ThrowableFace(class) ~= nil
            or NpcOnlyWeapon(class) then return end
        RegisterAutogen(class, class)
        autogenDefs[blob.id] = { name = class, weapon_class = class }
        healed = true
    end
    for _, entry in ipairs(rec.items) do
        if entry.uid then heal(entry.uid) end
    end
    for _, uid in pairs(rec.equip) do heal(uid) end
    if healed then Corpus.Data.Save("cargo", "autogen_defs", autogenDefs, CATALOG) end
end

-- The slot narrowing above is applied at REGISTRATION, so it only governs new
-- equips: an RPG the player had already parked in Sidearm before roadmap #39
-- would sit there forever, illegal and invisible to the rule. Kick anything
-- whose slot no longer accepts it back into the grid, once, at spawn. This is
-- also the general repair path for the day a def's equip_slots change again.
local function ReconcileEquipSlots(ply)
    local rec = CARGO.Inventory.GetRecord(ply)
    for slotId, val in pairs(rec.equip) do
        -- stack slots (throwable) hold an entry table, not a uid; their defs
        -- are not autogen and are out of scope here
        if isstring(val) then
            local blob = CARGO.Instances.Get(val)
            local def = blob and CARGO.Items.Get(blob.id) or nil
            if def ~= nil and not CARGO.Slots.CanEquip(def, slotId) then
                CARGO.Inventory.Unequip(ply, slotId)
                CARGO.Inventory.Notice(ply,
                    def.name .. " no longer fits that slot. Moved to your bag.")
                Corpus.Log("cargo", "reconcile de slots: " .. tostring(def.id)
                    .. " sacado de '" .. tostring(slotId) .. "' (ya no lo acepta)")
            end
        end
    end
end

-- NPC-only VJ items captured before the block existed are removed outright
-- (3rd in-game report 2026-07-24): equipping one deletes its entity with
-- VJ's "NPCs only" chat spam and the 0.1 s reconcile re-gives it — a loop —
-- and dropping one seeds the ammo farm. They carry no sub-slots (autogen
-- weapon defs never do), so CRG-9 ejection does not apply.
local function PurgeNpcOnlyItems(ply)
    local rec = CARGO.Inventory.GetRecord(ply)
    local removed = 0
    local function npcOnlyId(id)
        local class = string.match(isstring(id) and id or "", "^wpn_(.+)$")
        return class ~= nil and NpcOnlyWeapon(class)
    end
    for i = #rec.items, 1, -1 do
        local entry = rec.items[i]
        if istable(entry) and npcOnlyId(entry.id) then
            table.remove(rec.items, i)
            removed = removed + 1
        end
    end
    for slotId, val in pairs(rec.equip) do
        local id
        if istable(val) then
            id = val.id
        elseif isstring(val) then
            local blob = CARGO.Instances.Get(val)
            id = blob and blob.id or nil
        end
        if npcOnlyId(id) then
            rec.equip[slotId] = nil
            removed = removed + 1
        end
    end
    if removed > 0 then
        CARGO.Inventory.Touch(ply)
        CARGO.Inventory.Notice(ply,
            removed .. " NPC-only weapon(s) removed from your inventory.")
        Corpus.Log("cargo", "purga NPC-only (VJ): " .. removed
            .. " ítems removidos de " .. ply:Nick())
    end
end

hook.Add("PlayerInitialSpawn", "corpus_cargo_capture_heal", function(ply)
    HealOrphanDefs(ply)
    PurgeNpcOnlyItems(ply)
    ReconcileEquipSlots(ply)
end)

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
--
-- DEDUP, AND WHY IT SURVIVES ONLY FOR ANONYMOUS GIVES (author call, in-game
-- 2026-07-14: "no puedo tomar dos M60E4… comprar sí, lo que es raro"). Every
-- captured weapon is its own INSTANCE (own uid, own condition, own magazine),
-- so two M60E4 are two different items and the trade block already sells them
-- as such. What the dedup actually protects against is the ENGINE HANDOUT: the
-- gamemode loadout re-gives its classes on every respawn, and capturing those
-- blindly would mint a fresh pistol item each time you died. So the rule is now
-- scoped to exactly that: an ANONYMOUS give of a class already owned is dropped;
-- a DELIBERATE one (WALK+USE take, spawnmenu click, a dropped Cargo instance)
-- captures — you can carry N identical guns.
function CARGO.Capture.Decide(equippedCount, hasItem, deliberate)
    if (tonumber(equippedCount) or 0) > 0 then return "keep" end
    if hasItem and not deliberate then return "remove" end
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
    -- THE BLOB TRAVELS WITH THE ENTITY (CRG-60). A gun on the ground is a world
    -- drop like any other: a savegame gives the flat fields back but not the
    -- instance, and a uid on its own is a ghost — the take would mint a
    -- factory-fresh item and the condition, the attachments and the stored
    -- magazine would be gone.
    if wep.CargoInstanceUid ~= nil then
        wep.CargoInstances = CARGO.Instances.RenderEntry({ uid = wep.CargoInstanceUid })
    end
    wep:Spawn()
    -- VJ Base compat (roadmap #37, diagnosed against the live code 2026-07-24):
    -- its PlayerCanPickupWeapon hook (vj_base/hooks.lua:354) authorizes ANY
    -- pickup of a VJ weapon younger than 0.15 s (the InitTime window, meant for
    -- its own NPC gives) — and in hook.Call the first non-nil return wins, so
    -- our world gate never got to veto: a VJ gun dropped from the grid spawned
    -- at the player's feet and was hoovered back BY TOUCH the same instant,
    -- farming free ammo each cycle (VJ's SWEP:Equip gifts ClipSize*2,
    -- weapon_vj_base/shared.lua:411). Backdate the stamp so the drop is born a
    -- RESTING weapon: past the window VJ's own hook denies touch pickup too,
    -- and a WALK+USE take still rides its KeyPressed(IN_USE) branch.
    if wep.IsVJBaseWeapon and isnumber(wep.InitTime) then
        wep.InitTime = CurTime() - 1
    end
    -- a gun dropped straight out of the grid carries its stored magazine (#18);
    -- a fresh SWEP would otherwise spawn with its DefaultClip
    CARGO.Inventory.ApplyClipToEntity(wep, uid)
    return wep
end

-- Spawnmenu MIDDLE-CLICK spawns a weapon as a world entity (gm_spawnswep).
-- In-game report 2026-07-13 (1st pass of entries 13/14): freshly spawned
-- grenades were hoovered BY TOUCH — the gate's give-window below abstains
-- for entities younger than 0.5 s, and a weapon you already carry gets its
-- ammo absorbed by the engine bump the instant you step on it (the rounds
-- then land on the BELT via the §16 mirror, not on the slot ×N — "counter
-- didn't move"). Sandbox announces these spawns through PlayerSpawnedSWEP:
-- tag them like our own world spawns, so they are world weapons from frame
-- one — WALK+USE still takes them (the CargoUseTaken grant wins first).
hook.Add("PlayerSpawnedSWEP", "corpus_cargo_world_spawnmenu", function(_, ent)
    if IsValid(ent) then ent.CargoWorldSpawned = true end
end)

-- VJ Base takeover, 2nd form (4th in-game report 2026-07-24: plain USE still
-- took VJ guns and NPC-only guns still reached VJ's Equip). Its
-- PlayerCanPickupWeapon hook (vj_base/hooks.lua:354) always returns non-nil
-- for a VJ weapon — plain USE while looking at it (its KeyPressed branch),
-- the opt-in autopickup userinfo, or its 0.15 s InitTime window — and the
-- first non-nil return in hook.Call ends the chain. Re-seating the function
-- as a SECOND hook behind ours (the previous fix) lost the ordering lottery:
-- hook.Call order between DISTINCT hooks is not insertion-ordered, and VJ's
-- logic kept answering first. The only deterministic order is INSIDE one
-- hook: capture VJ's function, remove its registration, and run it embedded
-- in the world gate below wherever the gate abstains. A takeover of ORDER,
-- not of behavior. Absent mod = nil, and the gate runs bare (COR-5).
local vjPickup = isfunction(hook.GetTable)
    and ((hook.GetTable()["PlayerCanPickupWeapon"] or {})["VJ_PlayerCanPickupWeapon"])
    or nil
if vjPickup ~= nil then
    hook.Remove("PlayerCanPickupWeapon", "VJ_PlayerCanPickupWeapon")
    Corpus.Log("cargo", "VJ Base detectado — su PlayerCanPickupWeapon embebido en el world gate")
end

-- The world gate. Deny order matters: the WALK+USE grant wins, our own
-- world spawns always deny, give flows (entity born an instant ago) pass,
-- and anything that has been RESTING in the world is denied. VJ's own logic
-- (captured above) rules exactly where the gate abstains: the give window
-- and the gate-off convar.
hook.Add("PlayerCanPickupWeapon", "corpus_cargo_world_gate", function(ply, wep)
    -- keep VJ's registration out of the chain even if a lua refresh re-added
    -- it (idempotent, trivially cheap); its logic lives embedded below
    if vjPickup ~= nil then
        hook.Remove("PlayerCanPickupWeapon", "VJ_PlayerCanPickupWeapon")
    end
    -- VJ pickup-ammo gift, neutralized at the choke point (5th in-game report
    -- 2026-07-24: DGL4's pickup history logged "+60 SMG1" on every legit
    -- take). Its SWEP:Equip calls GiveAmmo(ClipSize*2) WITH the engine pickup
    -- popup, so ammo HUDs log the gift even though the WeaponEquip clawback
    -- nets it to zero a tick later — the event itself must never fire. Every
    -- player acquisition (touch, USE, and ply:Give too) passes through this
    -- hook BEFORE Equip runs: zero the gift on THIS instance only, via an own
    -- Primary copy — writing through wep.Primary would mutate the SHARED
    -- class table (a fork by mutation). The clawback reads the same field and
    -- becomes a no-op: nothing gifted, nothing to claw, nothing logged.
    -- Capture off = stock VJ gift (Cargo is not managing the economy).
    if wep.IsVJBaseWeapon == true and wep.CargoVJGiftCut == nil
        and cvCapture:GetBool() and istable(wep.Primary) then
        wep.CargoVJGiftCut = true
        local prim = table.Copy(wep.Primary)
        prim.PickUpAmmoAmount = 0
        wep.Primary = prim
    end
    if not cvWorldGuns:GetBool() then
        -- gate off: stock VJ behavior, from inside the single hook
        if vjPickup ~= nil then return vjPickup(ply, wep) end
        return
    end
    if ply.CargoEquipGive then return end        -- our equip give: engine decides
    -- NPC-only VJ gun: never player-pickable by ANY path at ANY age — VJ
    -- would delete it from the player's hands right after gifting its pickup
    -- ammo (Equip runs the gift BEFORE the removal), and that aborted equip
    -- never reaches WeaponEquip, so the clawback there cannot see the gift.
    -- Denying the pickup is the only lever: no gift, no "NPCs only" chat
    -- spam, no phantom ammo flash on ammo HUDs (4th in-game report).
    if wep.IsVJBaseWeapon == true and wep.MadeForNPCsOnly == true then return false end
    if wep.CargoUseTaken then return true end    -- WALK+USE grant (PlayerUse below)
    if wep.CargoWorldSpawned then return false end
    -- VJ NPC corpse drop: the death drops the very entity the NPC held
    -- (DeathWeaponDrop, npc_vj_human_base/init.lua:4491), and OwnerIsNPC only
    -- updates with a VALID owner (SWEP:OwnerChanged, shared.lua:1011), so it
    -- stays stamped on the loose gun — a WORLD weapon from frame one, never a
    -- give. WALK+USE still takes it (the grant above wins first), and the
    -- PlayerUse take itself honors vj_npc_wep_ply_pickup 0.
    if wep.IsVJBaseWeapon == true and wep.OwnerIsNPC == true then return false end
    if CurTime() - wep:GetCreationTime() < 0.5 then
        -- a give, not a pickup — and for VJ weapons the give window is VJ's
        -- own call (its 0.15 s InitTime rule; non-VJ classes answer nil)
        if vjPickup ~= nil then return vjPickup(ply, wep) end
        return
    end
    return false
end)

-- Look at a world weapon — or a dropped Cargo item, or a world ammo box —
-- and press USE (PlayerUse repeats every tick while +USE is held: debounced
-- per player). Plain USE = HL2 carry; WALK+USE = deliberate take. For
-- weapons that is a one-shot grant + engine pickup (the capture hook
-- converts it); for items the hook steps aside and lets the engine reach
-- ENT:Use, which the `return false` otherwise blocks (roadmap #27 — the
-- item entity used to dodge this gate entirely, so plain USE hoovered
-- dropped ammo); for item_ammo_* boxes (roadmap #32) the give happens right
-- here — their engine pickup is permanently vetoed by the ammopool hook, so
-- there is no ENT:Use or engine grant to delegate to. ONE gate for the
-- three shapes: same debounce, same carry, same WALK semantics.
hook.Add("PlayerUse", "corpus_cargo_world_use", function(ply, ent)
    if not IsValid(ent) then return end

    local isItem = ent:GetClass() == "corpus_cargo_item"
    local ammoSpec
    if not isItem then
        ammoSpec = CARGO.AmmoPool and CARGO.AmmoPool.WorldAmmoSpec
            and CARGO.AmmoPool.WorldAmmoSpec(ent:GetClass()) or nil
    end
    if not isItem and ammoSpec == nil then
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
        if ammoSpec ~= nil then
            -- ammo box: the give is ours (no engine grant exists to convert).
            -- The flag guards the frames until the delayed remove lands.
            if ent.CargoAmmoTaken then return false end
            if CARGO.Inventory.GiveItem(ply, ammoSpec.id, ammoSpec.count) then
                ent.CargoAmmoTaken = true
                CARGO.Inventory.NotifyPickup(ply, ammoSpec.id, ammoSpec.count)
                SafeRemoveEntityDelayed(ent, 0)
            else
                -- too heavy: it stays on the floor, where he can come back for it
                CARGO.Inventory.Notice(ply, "You can't carry that.")
            end
            return false
        end
        -- VJ Base takes (3rd in-game report 2026-07-24), refused BEFORE any
        -- pickup can run — the refusal is the fix: VJ's SWEP:Equip gifts the
        -- pickup ammo BEFORE it self-deletes an NPC-only gun, and an aborted
        -- equip never reaches WeaponEquip, so the clawback there can't see it.
        if ent.IsVJBaseWeapon == true then
            -- NPC-only: it would be deleted from the player's hands anyway
            -- ("<name> removed! It's made for NPCs only!") — no pickup, no
            -- ammo gift, no chat spam, no item
            if ent.MadeForNPCsOnly then
                CARGO.Inventory.Notice(ply, "That weapon is made for NPCs only.")
                return false
            end
            -- honor the server's own switch (vj_npc_wep_ply_pickup 0 =
            -- players don't loot NPC weapons — the author runs it OFF):
            -- Cargo's deliberate take must not outrank the mod's config
            local cvVJ = GetConVar("vj_npc_wep_ply_pickup")
            if ent.OwnerIsNPC == true and cvVJ ~= nil and cvVJ:GetInt() == 0 then
                CARGO.Inventory.Notice(ply, "Picking up NPC weapons is disabled.")
                return false
            end
        end
        -- A second weapon of a class the player ALREADY has equipped can't ride
        -- the engine pickup: it holds one SWEP per class, so PickupWeapon refuses
        -- (in-game 2026-07-23: "You can't take that right now."). A deliberate
        -- floor-take of a duplicate is legit though — every gun is its own
        -- instance (roadmap #15/#30) — so capture it STRAIGHT to the grid,
        -- bypassing the engine equip. The equipped one is untouched; WeaponEquip
        -- never runs for this take.
        local class = ent:GetClass()
        if cvCapture:GetBool() and EquippedClassCount(ply, class) > 0
            and not CARGO.Capture.Ignore[class] and ThrowableFace(class) == nil then
            local id = EnsureDef(class, ent)
            local ok, newUid = CARGO.Inventory.GiveItem(ply, id)
            if ok then
                if isstring(newUid) then CARGO.Inventory.StoreClip(newUid, ent) end
                CARGO.Inventory.NotifyPickup(ply, id, 1)
                ent:Remove()
            else
                CARGO.Inventory.Notice(ply, "You can't carry that.")
            end
            return false
        end
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

    -- VJ Base gifts reserve ammo on EVERY player acquisition of a non-melee
    -- VJ gun (SWEP:Equip, weapon_vj_base/shared.lua:409-415:
    -- PickUpAmmoAmount "Default" = ClipSize*2, a number = that amount).
    -- Under Cargo ammo comes from ITEMS — an equip from the grid, a WALK+USE
    -- take or a loadout give must not mint rounds (no ether, same rule as
    -- the ARC9/QL free-ammo takeovers). Claw the exact grant back one tick
    -- later (order-proof against Equip vs WeaponEquip sequencing; if a 4 Hz
    -- mirror tick sneaks in between, the pool drop reads as consumption and
    -- the belt re-drains — eventually consistent either way). Scheduled
    -- BEFORE the equip-give fast path below on purpose: OUR gives get the
    -- gift too.
    if wep.IsVJBaseWeapon == true and wep.IsMeleeWeapon ~= true
        and IsValid(ply) and ply:IsPlayer() then
        local prim = istable(wep.Primary) and wep.Primary or {}
        local grant
        if prim.PickUpAmmoAmount == "Default" then
            grant = (tonumber(prim.ClipSize) or 0) * 2
        elseif isnumber(prim.PickUpAmmoAmount) then
            grant = prim.PickUpAmmoAmount
        end
        local ammoType = prim.Ammo
        if isnumber(grant) and grant > 0 and ammoType ~= nil then
            local owner = ply
            timer.Simple(0, function()
                if IsValid(owner) and owner:IsPlayer() then
                    owner:RemoveAmmo(grant, ammoType)
                end
            end)
        end
    end

    -- NPC-only VJ gun (3rd in-game report 2026-07-24): VJ deletes it from
    -- player hands right after this equip — never mint an item for it (the
    -- clawback above still runs: the ammo gift fired before the deletion)
    if wep.MadeForNPCsOnly == true and wep.IsVJBaseWeapon == true then return end

    -- our own equip flow gives weapons through this same engine path; the
    -- flag is only set synchronously around ply:Give, so read it NOW
    if IsValid(ply) and ply.CargoEquipGive then return end

    local class = wep:GetClass()
    if CARGO.Capture.Ignore[class] then return end
    -- throwable-faced class (roadmap #32): the frag/SLAM SWEP is never an
    -- item of its own — no def is minted here (resurrecting the second face
    -- is exactly the bug of this front). Its handling lives in the timer.
    local throwFace = ThrowableFace(class)
    -- def cached while the entity is alive; the strip below invalidates it
    local id = throwFace == nil and EnsureDef(class, wep) or nil

    -- world-drop context, read NOW: by the time the timer runs the entity
    -- is the held weapon (or gone) and these fields are the only trace
    local dropUid = isstring(wep.CargoInstanceUid) and wep.CargoInstanceUid or nil
    local dropBlobs = istable(wep.CargoInstances) and wep.CargoInstances or nil
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

        -- throwable-faced class (roadmap #32): an equipped stack claims the
        -- entity as its own SWEP (same keep rule as any equipped class — the
        -- entry-13 take-back of a dropped shell still lands here). Otherwise
        -- the entity dies and the rounds the engine granted on pickup reach
        -- the stack through the §16 mirror (AbsorbType tops the equipped ×N
        -- or the reconciler overflow mints/merges the grid stack).
        if throwFace ~= nil then
            if EquippedClassCount(owner, class) > 0 then return end
            if IsValid(wep) then wep:Remove() end
            return
        end

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

        -- SAVEGAME (CRG-60): the uid is live per BOOT, so a gun that survived a
        -- gm_save/gm_load names an instance that died with the map. Mint it
        -- again from the blob that travelled on the entity. VALUE test, never a
        -- timing one — "is this uid possible in this session?" — which is what
        -- makes it indifferent to when the duplicator wrote the fields.
        local revivedFromSave = false
        if blob == nil and dropUid ~= nil and istable(dropBlobs) then
            local saved = dropBlobs[dropUid]
            local revived = CARGO.Instances.Remint(
                { { id = istable(saved) and saved.id or nil, uid = dropUid } }, dropBlobs)
            if revived[1] ~= nil then
                dropUid = revived[1].uid
                blob = CARGO.Instances.Get(dropUid)
                revivedFromSave = true
                Corpus.Log("cargo", "Capture: arma de mundo restaurada de un savegame ("
                    .. tostring(blob and blob.id) .. ", cargador " .. tostring(blob and blob.clip1) .. ")")
            end
        end
        local action
        if blob ~= nil then
            action = "capture"
            -- the world entity is about to be Removed below: harvest whatever
            -- is left in its magazine into the blob first (#18), so re-equipping
            -- from the grid does not hand back a free full clip.
            --
            -- EXCEPT when the blob just came back from a savegame. Cargo did NOT
            -- spawn that entity — the engine re-created it — so
            -- SpawnWorldWeapon's ApplyClipToEntity never ran and its Clip1 is
            -- the SWEP's DefaultClip, a value from nowhere. Harvesting it writes
            -- a free full magazine over the one that travelled. Measured in game
            -- (planilla R, ronda 2): a dev pistol dropped EMPTY came back with
            -- 18, and the SMG with 15 came back with 45 — the two DefaultClips.
            -- Same rule as everything else in this block: a value that only
            -- makes sense in the session that produced it is not continuity, so
            -- the blob is the authority and the restored entity is not.
            if not revivedFromSave then
                CARGO.Inventory.StoreClip(dropUid, wep)
            end
        else
            action = CARGO.Capture.Decide(
                EquippedClassCount(owner, class), HasWeaponItem(owner, class),
                deliberate)
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
        -- "remove" now only reaches ANONYMOUS gives (see Decide): the engine
        -- loadout re-giving a class the player already carries. Nothing to say
        -- about it — a deliberate take of a second identical gun captures.

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
    if uid == nil then
        -- the equipped THROWABLE stack has no uid but its SWEP can still be
        -- dropped (cargo_drop with the grenade in hand). The rounds stay in
        -- the slot — the entity is just the launcher shell — but it must be
        -- a WORLD weapon, or touching it re-absorbs it instantly (in-game
        -- report 2026-07-13). Take-back lands on "keep" via the equipped
        -- stack, which re-equips it, rounds untouched.
        local eq = rec.equip.throwable
        if istable(eq) then
            local def = CARGO.Items.Get(eq.id)
            if istable(def) and def.weapon_class == class then
                wep.CargoWorldSpawned = true
            end
        end
        return -- not a Cargo-equipped weapon: leave the rest alone
    end

    -- unequip WITHOUT returning to the grid — the item is going to the world,
    -- not the backpack. Tag the entity so the world gate (no touch pickup) and
    -- the take-back (WeaponEquip reads CargoInstanceUid) treat it as THIS
    -- instance. The loaded magazine goes into the blob NOW (#18): the entity
    -- keeps its own Clip1 while it lies there, but the take-back destroys it.
    CARGO.Inventory.StoreClip(uid, wep)
    rec.equip[slotId] = nil
    wep.CargoInstanceUid = uid
    wep.CargoInstances = CARGO.Instances.RenderEntry({ uid = uid }) -- CRG-60, as above
    wep.CargoWorldSpawned = true
    CARGO.Inventory.Touch(ply)
end)

-- Third-party bug guard (in-game report 2026-07-12, ARC9 EFT revolver
-- cr200ds): its per-round reload arms one timer.Simple PER ROUND, and each
-- one reads swep:GetOwner():GetAmmoCount(...) guarding only IsValid(swep),
-- never the owner (arc9_eft_cr200ds.lua:406). Dropping mid-reload orphans
-- those timers and every one of them errors. ARC9 is COMPAT-RUNTIME — we
-- never fork it — so we simply refuse to drop until the reload finishes.
-- Shared by cargo_drop and the slot Drop (#28). (An external drop mod calling
-- ply:DropWeapon straight can still hit it; that is between it and ARC9.)
function CARGO.Capture.DropBlockedByReload(wep)
    if IsValid(wep) and isfunction(wep.GetReloading) then
        local okR, reloading = pcall(wep.GetReloading, wep)
        if okR and reloading then return true end
    end
    return false
end

-- Native "drop the weapon in hand" — bindable exactly like the mod's +drop.
-- Funnels through ply:DropWeapon so the reconciler above does the bookkeeping
-- either way; the target position tosses it in front of the player.
concommand.Add("cargo_drop", function(ply)
    if not cvNativeDrop:GetBool() then return end
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end
    if CARGO.Capture.Ignore[wep:GetClass()] then return end -- hands aren't gear

    if CARGO.Capture.DropBlockedByReload(wep) then
        CARGO.Inventory.Notice(ply, "Finish the reload before dropping.")
        return
    end

    ply:DropWeapon(wep, ply:GetShootPos() + ply:GetAimVector() * 48)
end, nil, "Drop the weapon in hand into the world (keeps its Cargo instance)")
