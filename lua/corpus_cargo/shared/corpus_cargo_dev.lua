-- corpus_cargo_dev.lua — dev harness: selftest + demo item kit (SHARED)
-- Verification pattern of the ecosystem (corpus_flujo_trabajo.txt §1 PASO 4):
-- deterministic auto-test for the pure math, in-game confirmation for the
-- rest. Demo items exist ONLY so the framework can be verified before any
-- owner module (Caliber/Coagulant/Craving) registers real content — they
-- play the owner-module role, clearly namespaced as cargo_dev_*.

local CARGO = Corpus.GetModule("cargo")

-- ------------------------------------------------------------------
-- Demo item kit (both realms: the client grid renders from defs too)
-- ------------------------------------------------------------------

-- STALKER prop models from the OPTIONAL corpus_stalker addon (recycled
-- ZONA StalkerRP packs — see dev/zona_stalkerrp_contenido.md). The addon is
-- personal/unpublishable (GSC assets), so nothing here may assume it:
-- honest fallback to the previous model (or the letter placeholder) when
-- the file is not mounted. file.Exists is realm-safe for GAME paths.
local function ZonaModel(path, fallback)
    if isstring(path) and file.Exists(path, "GAME") then return path end
    return fallback
end

CARGO.Items.Register({
    id = "cargo_dev_helmet", name = "Sphere-08 Helmet (dev)",
    weight = 1.9, class = "unique", category = "helmets",
    size = { 3, 3 }, value = 2600,
    model = ZonaModel("models/stalker/outfit/hardhat.mdl"),
    has_condition = true,
    trivia = "Sealed military helmet with a standard front mount. Framework test item.",
})
CARGO.Items.DeclareSubSlot("cargo_dev_helmet", {
    id = "optic", filter = "category:optics", maxItems = 1, label = "optic",
})

CARGO.Items.Register({
    id = "cargo_dev_nvg", name = "PNV-10T NVG (dev)",
    weight = 0.6, class = "unique", category = "optics",
    size = { 2, 1 }, value = 9000,
    -- stand-in: ZONA has no NVG prop; the dome mask reads as head optics
    model = ZonaModel("models/stalker/outfit/dome_mask.mdl"),
    has_condition = true, effect_icon = "battery",
    trivia = "Test night vision goggles. Mount them on the helmet's optic sub-slot.",
})

local devVest = CARGO.Items.Register({
    id = "cargo_dev_vest", name = "CS-3a Vest (dev)",
    weight = 6.8, class = "unique", category = "armor",
    size = { 3, 4 }, value = 4800,
    -- Clear Sky light suit: the CS-3a's actual STALKER counterpart
    model = ZonaModel("models/stalker/outfit/cs_light.mdl"),
    condition_zones = { "torso", "stomach", "arms", "legs" },
    quick_slots = 3,
    trivia = "Test tactical vest with per-zone condition. Real mitigation lands with Caliber Block 3.",
})
-- Body sub-slots: the SAME primitive serves the exo/shield accessory
-- (Caliber Block 3 attachment point) and the plate slots (§4).
CARGO.Items.DeclareSubSlot(devVest, {
    id = "accessory", filter = "category:exoshield", maxItems = 1, label = "exo/shield",
})
CARGO.Items.DeclareSubSlot(devVest, {
    id = "plates", filter = "category:plates", maxItems = 2, label = "plates",
})

CARGO.Items.Register({
    id = "cargo_dev_backpack", name = "Tri-Zip Backpack (dev)",
    weight = 2.4, class = "unique", category = "backpacks",
    size = { 3, 3 }, value = 2200,
    model = ZonaModel("models/hgn/srp/items/backpack-1.mdl"),
    has_condition = true, capacity_bonus = 18,
    trivia = "Three-zip assault pack, 40 L. Adds +18 kg of carry capacity while equipped on Back.",
})

CARGO.Items.Register({
    id = "cargo_dev_plate", name = "Ceramic Plate IV (dev)",
    weight = 1.2, class = "stackable", category = "plates",
    size = { 2, 3 }, value = 1500,
    -- stand-in: flat textolite sheet, the closest plate-shaped ZONA prop
    model = ZonaModel("models/materials_textolite.mdl"),
    has_condition = true, material = "Ceramic IV",
    trivia = "Test ballistic plate. What a plate does is Caliber's call; Cargo only stores and shows it.",
})

CARGO.Items.Register({
    id = "cargo_dev_medkit", name = "Field Medkit (dev)",
    weight = 0.4, class = "stackable", category = "medical",
    size = { 2, 2 }, value = 700,
    model = ZonaModel("models/stalker/item/medical/medkit1.mdl",
        "models/items/healthkit.mdl"),
    effect_icon = "hemostatic",
    trivia = "Test consumable for the onUse flow. Real medicine is Coagulant's domain.",
    -- onUse is the OWNER-module side of the contract (CORPUS_Architecture
    -- §5): this dev item plays that role for verification only.
    onUse = function(ply)
        ply:SetHealth(math.min(ply:Health() + 25, ply:GetMaxHealth()))
        ply:EmitSound("items/medshot4.wav") -- HL2 healthkit heal cue
        return true -- consume one unit
    end,
})

CARGO.Items.Register({
    id = "cargo_dev_food", name = "Canned Food (dev)",
    weight = 0.3, class = "stackable", category = "food",
    size = { 2, 2 }, value = 180,
    model = ZonaModel("models/stalker/item/food/tuna.mdl",
        "models/props_junk/garbage_takeoutcarton001a.mdl"),
    trivia = "Test food. Real hunger is Craving's domain.",
    onUse = function(ply)
        local cargoMod = Corpus.GetModule("cargo")
        cargoMod.Inventory.Notice(ply, "You eat the canned food. (Craving is not mounted: no hunger effect.)")
        return true
    end,
})

-- The throwable slot's test item WAS cargo_dev_frag (entry 13); roadmap #32
-- made the frag a REAL item (cargo_throw_frag, corpus_cargo_ammo.lua — the
-- canonical face of the HL2 "Grenade" type), so the kit hands that one out
-- and the dev def is gone. Old persisted stacks remap on load
-- (CARGO.Ammo.LegacyThrowIds).

-- Feeds the SAME engine pool as the real "Pistol Rounds" item (§16): a second
-- item on one HL2 type is exactly the case the author raised (two weapons of
-- "different" calibers that both eat HL2 pistol ammo), so keeping this dev
-- stack around is what makes the shared-pool and drain-order paths testable.
CARGO.Items.Register({
    id = "cargo_dev_ammo_9mm", name = "9x19 FMJ (dev)",
    weight = 0.012, class = "stackable", category = "ammo",
    size = { 2, 1 }, max_stack = 120, value = 8,
    model = ZonaModel("models/stalker/ammo/9x19.mdl"),
    ammo = { caliber = "9x19", hl2 = "Pistol", types = { "FMJ", "AP", "HP" } },
    trivia = "Test ammunition for caliber overlays and large stacks.",
})

CARGO.Items.Register({
    id = "cargo_dev_smg", name = "Tactical SMG (dev)",
    weight = 3.0, class = "unique", category = "weapons",
    size = { 4, 2 }, value = 1100,
    weapon_class = "weapon_smg1", equip_slots = { "primary", "secondary" },
    has_condition = true,
    ammo = { caliber = "4.6x30", types = { "FMJ" } },
    display_stats = { accuracy = -8, handling = -21, damage = -11, firerate = -9 },
    trivia = "Test weapon (HL2 SMG). Manual stats via display_stats — the ARC9 route uses GetProcessedValue.",
})

CARGO.Items.Register({
    id = "cargo_dev_pistol", name = "Service Pistol (dev)",
    weight = 0.9, class = "unique", category = "weapons",
    size = { 3, 2 }, value = 300,
    weapon_class = "weapon_pistol", equip_slots = { "sidearm" },
    has_condition = true,
    ammo = { caliber = "9x19", types = { "FMJ" } },
    trivia = "Test sidearm (HL2 pistol).",
})

CARGO.Items.Register({
    id = "cargo_dev_melee", name = "Crowbar (dev)",
    weight = 2.5, class = "unique", category = "melee",
    size = { 3, 1 }, value = 60,
    weapon_class = "weapon_crowbar",
    trivia = "Test melee weapon (HL2 crowbar).",
})

-- generic accessories: the accessory slots are setting-agnostic (no PDA/
-- detector STALKER furniture in the base framework)
CARGO.Items.Register({
    id = "cargo_dev_pda", name = "Datapad (dev)",
    weight = 0.5, class = "unique", category = "accessories",
    size = { 2, 2 }, value = 1200,
    model = ZonaModel("models/stalker/item/handhelds/pda.mdl"),
    trivia = "Minor test accessory for the accessory slots.",
})

CARGO.Items.Register({
    id = "cargo_dev_detector", name = "Scanner (dev)",
    weight = 0.4, class = "unique", category = "accessories",
    size = { 2, 1 }, value = 900,
    model = ZonaModel("models/scanner_anomaly.mdl"),
    has_condition = true,
    trivia = "Minor test accessory for the accessory slots.",
})

-- ------------------------------------------------------------------
-- Def listing — SHARED on purpose (2026-08-08)
-- ------------------------------------------------------------------
-- The listing used to live inside the SERVER block, so `cargo_dev_items`
-- could only ever report the server catalogue. That is not a cosmetic gap:
-- Cargo does NOT sync module defs over the wire (COR-12) — the client grid
-- renders from ITS OWN defs — so "which defs exist" is a different question
-- per realm, and the client's was unanswerable in game. On 2026-08-08 the
-- client was missing 4.413 defs and no instrument could say so
-- (dev/VEREDICTO_ready_barrier_cliente.md); the check that would have caught
-- it, `cargo_dev_items`, wins the SERVER registration on a listen server and
-- would have come back green off the one realm that was fine.
--
-- ONE routine, two names — same reason `corpus_selftest` has `_cl`. Two
-- copies of the listing is how the realms drift apart in what they report.

-- "bulk" = a DERIVED catalogue, not hand-written content: it floods an
-- unfiltered listing without telling you anything. Captured weapons and
-- ARC9 attachments were the first two; the 61 Neosun NVG variants
-- (roadmap #47) are the third, and they are the same shape — one def per
-- third-party variant, reachable with a filter like everything else.
local function IsBulk(id, def)
    return def.arc9_att ~= nil or id:sub(1, 4) == "wpn_"
        or id:sub(1, 10) == "cargo_nvg_"
end

-- nil filter: every non-bulk def. With filter: case-insensitive plain
-- substring over id AND display name, bulk included.
local function FindDefs(filter)
    local out = {}
    for id, def in pairs(CARGO.Items._defs) do
        if filter == nil then
            if not IsBulk(id, def) then out[#out + 1] = { id = id, def = def } end
        elseif id:lower():find(filter, 1, true)
            or def.name:lower():find(filter, 1, true) then
            out[#out + 1] = { id = id, def = def }
        end
    end
    table.sort(out, function(a, b)
        local ca = a.def.category or "misc"
        local cb = b.def.category or "misc"
        if ca == cb then return a.id < b.id end
        return ca < cb
    end)
    return out
end

-- The realm is printed in the header, not left to be inferred from which
-- command was typed: a listing that does not say where it was taken is how a
-- green check ends up reporting the same realm twice.
local function ListDefs(args)
    local filter = isstring(args and args[1]) and args[1]:lower() or nil
    local rows = FindDefs(filter)

    MsgN(string.format("— %d ítems registrados en el realm %s%s —", #rows,
        SERVER and "SERVER" or "CLIENT",
        filter and (" (filtro '" .. filter .. "')") or ""))
    local lastCat
    for _, r in ipairs(rows) do
        local cat = r.def.category or "misc"
        if cat ~= lastCat then
            MsgN("[" .. cat .. "]")
            lastCat = cat
        end
        MsgN(string.format("  %-28s %s (%s)", r.id, r.def.name, r.def.class))
    end

    if filter == nil then
        local bulk = 0
        for id, def in pairs(CARGO.Items._defs) do
            if IsBulk(id, def) then bulk = bulk + 1 end
        end
        if bulk > 0 then
            MsgN("(+" .. bulk .. " armas capturadas/attachments ocultos — usá un filtro para verlos; armas: cargo_dev_dump_weapons)")
        end
    end
    if SERVER then
        MsgN("dar uno: cargo_dev_give_item <id|texto> [cantidad]")
        MsgN("el catálogo del CLIENTE es otro (COR-12): cargo_dev_items_cl")
    end
end

-- ------------------------------------------------------------------
-- Dev commands (server) — TODO: gate behind the future Corpus admin
-- permission primitive (own design session pending); until then these are
-- open like Caliber's debug commands.
-- ------------------------------------------------------------------

if SERVER then

    local KIT = {
        { "cargo_dev_helmet" }, { "cargo_dev_nvg" }, { "cargo_dev_vest" },
        { "cargo_dev_backpack" }, { "cargo_dev_plate", 3 },
        { "cargo_dev_medkit", 4 }, { "cargo_dev_food", 5 },
        { "cargo_dev_ammo_9mm", 60 }, { "cargo_dev_smg" },
        { "cargo_dev_pistol" }, { "cargo_dev_melee" },
        { "cargo_dev_pda" }, { "cargo_dev_detector" },
        { "cargo_throw_frag", 3 },
        -- real HL2 supplies + generic backpacks (#34): the default set is what
        -- the in-game pass verifies (box drop, SetModel substitution, onUse)
        { "cargo_hl2_healthkit", 2 }, { "cargo_hl2_healthvial", 2 },
        { "cargo_hl2_battery", 2 },
        { "cargo_backpack_small" }, { "cargo_backpack_large" },
        -- real HL2 ammo (§16): enough to hang stacks on the belt and watch the
        -- reserve follow. cargo_ammo_pistol shares its pool with the dev 9mm.
        { "cargo_ammo_pistol", 120 }, { "cargo_ammo_smg1", 120 },
        { "cargo_ammo_buckshot", 40 }, { "cargo_ammo_357", 24 },
    }

    concommand.Add("cargo_dev_give", function(ply)
        if not IsValid(ply) then ply = player.GetAll()[1] end
        if not IsValid(ply) then return end
        for _, it in ipairs(KIT) do
            CARGO.Inventory.GiveItem(ply, it[1], it[2])
        end
        Corpus.Log("cargo", "kit dev entregado a " .. ply:Nick())
    end, nil, "Gives the Cargo test item kit")

    -- ------------------------------------------------------------------
    -- Per-item dev acquisition (entry 34 PARCHE 4, author request
    -- 2026-07-23): the kit hands a fixed set, but verifying ONE def (a new
    -- supply, a Coagulant med, a backpack) should not require the lot —
    -- and the author has no way to know which ids exist in a session.
    -- Captured weapons (wpn_*) and bridged ARC9 attachments are BULK:
    -- hundreds of autogen defs that would drown the listing, so they only
    -- show under an explicit filter (cargo_dev_dump_weapons is the
    -- instrument for the weapon set anyway).
    -- ------------------------------------------------------------------

    concommand.Add("cargo_dev_items", function(_, _, args)
        ListDefs(args)
    end, nil, "Lists SERVER item defs grouped by category (arg: id/name filter; captured weapons and attachments only show filtered). The client catalogue is a different one: cargo_dev_items_cl")

    concommand.Add("cargo_dev_give_item", function(ply, _, args)
        if not IsValid(ply) then ply = player.GetAll()[1] end
        if not IsValid(ply) then return end
        if not isstring(args and args[1]) or args[1] == "" then
            Corpus.Log("cargo", "uso: cargo_dev_give_item <id|texto> [cantidad] — lista: cargo_dev_items")
            return
        end

        -- exact id first (raw, ids may not be lowercase); then the same
        -- substring search as the listing — one hit gives, several print
        local chosen
        if CARGO.Items.Get(args[1]) ~= nil then
            chosen = args[1]
        else
            local matches = FindDefs(args[1]:lower())
            if #matches == 0 then
                Corpus.Log("cargo", "give_item: nada matchea '" .. args[1]
                    .. "' — lista: cargo_dev_items")
                return
            end
            if #matches > 1 then
                Corpus.Log("cargo", "give_item: '" .. args[1] .. "' es ambiguo ("
                    .. #matches .. " matches):")
                for i = 1, math.min(#matches, 12) do
                    MsgN("  " .. matches[i].id .. "  " .. matches[i].def.name)
                end
                if #matches > 12 then MsgN("  ...") end
                return
            end
            chosen = matches[1].id
        end

        local def = CARGO.Items.Get(chosen)
        local want = math.max(math.floor(tonumber(args and args[2]) or 1), 1)
        local given = 0
        if def.class == "stackable" then
            local ok, err = CARGO.Inventory.GiveItem(ply, chosen, want)
            if ok then given = want
            else Corpus.Log("cargo", "give_item: " .. tostring(err)) end
        else
            -- one instance (blob on disk) per unit — clamped so a typo in
            -- the count argument cannot mint hundreds of them
            want = math.min(want, 10)
            for _ = 1, want do
                local ok, err = CARGO.Inventory.GiveItem(ply, chosen)
                if not ok then
                    Corpus.Log("cargo", "give_item: " .. tostring(err))
                    break
                end
                given = given + 1
            end
        end
        if given > 0 then
            Corpus.Log("cargo", "give_item: " .. given .. "x " .. chosen
                .. " a " .. ply:Nick())
        end
    end, nil, "Gives N units of ONE item def, by exact id or by id/name text (default 1; unique items cap at 10 per call). List: cargo_dev_items")

    concommand.Add("cargo_dev_money", function(ply)
        if not IsValid(ply) then ply = player.GetAll()[1] end
        if not IsValid(ply) then return end
        CARGO.Money.Add(ply, 1000)
        CARGO.Inventory.Sync(ply)
        Corpus.Log("cargo", "+$1000 (provider " .. CARGO.Money.Label() .. ") a " .. ply:Nick())
    end, nil, "Adds $1000 through the active money provider")

    -- ARC9 acquisition path for testing: with the bridge active the player
    -- owns ZERO attachments (single-source rule), the C menu shows all
    -- locked and there is nothing to attach FROM until something grants
    -- items. World entities need arc9_atts_generate_entities 1 (ARC9
    -- default 0), so this is the practical dev route.
    concommand.Add("cargo_dev_atts", function(ply, _, args)
        if not IsValid(ply) then ply = player.GetAll()[1] end
        if not IsValid(ply) then return end
        if ARC9 == nil then
            Corpus.Log("cargo", "cargo_dev_atts: ARC9 no montado")
            return
        end

        local want = tonumber(args and args[1]) or 5
        local filter = isstring(args and args[2]) and args[2]:lower() or nil
        local given = 0
        for id, def in SortedPairs(CARGO.Items._defs) do
            if given >= want then break end
            if def.arc9_att and (filter == nil
                or id:lower():find(filter, 1, true)
                or def.name:lower():find(filter, 1, true)) then
                if CARGO.Inventory.GiveItem(ply, id, 2) then given = given + 1 end
            end
        end
        Corpus.Log("cargo", "cargo_dev_atts: " .. given .. " attachments x2 a " .. ply:Nick())
    end, nil, "Gives N bridged ARC9 attachment items x2 (args: [count] [name filter])")

    -- Arsenal dump (author request 2026-07-13, entry 15 support): one line
    -- per installed ARC9 weapon — class, print name, EFT type (SubCategory),
    -- HL2 ammo, clip size and the weight the autogen def would get TODAY
    -- (WeaponWeights hit or the 2.5 nominal fallback) — so the GAMMA
    -- database (stalker-gamma-db.com) can be cross-referenced without
    -- unpacking the mods into dev/. Console + tab-separated
    -- data/corpus/cargo/weapon_dump.txt. Arg "all" dumps every SWEP.
    -- A SWEP the capture can never hand the player is NOT a hole in the tables
    -- (author report, 2026-07-14: the dump still showed 9 "MISSING" after entry
    -- 25 closed every real gap — all 9 were SWEP BASE TEMPLATES and the MW2019
    -- fists). Flagging them as MISSING makes the dump cry wolf, and the dump is
    -- the instrument you diagnose WITH: a false alarm in it costs a real search.
    -- Two exclusions, both honest:
    --   * not Spawnable  -> a base/template (arc9_base, arc9_eft_base, the
    --     *_base_nade and *_melee_base of every pack). Nothing spawns it.
    --   * Capture.Ignore -> deliberately never an item (fists, hands).
    -- They still appear in the dump — hiding them would be its own lie — but as
    -- "n/a", and they do not count towards the gap tally.
    local function DumpStatus(class, t)
        if CARGO.Capture and CARGO.Capture.Ignore
            and CARGO.Capture.Ignore[class] then
            return "ignored" -- unarmed state, not gear
        end
        if t.Spawnable ~= true then
            return "base" -- SWEP template: the player can never receive it
        end
        return "weapon"
    end

    concommand.Add("cargo_dev_dump_weapons", function(_, _, args)
        local wantAll = istable(args) and args[1] == "all"
        local weights = istable(CARGO.Capture)
            and CARGO.Capture.WeaponWeights or {}
        -- the twin gap: no value => not tradeable (Cargo_Trade §4). A weapon
        -- missing its price is as broken as one missing its weight, and it used
        -- to be invisible here.
        local values = istable(CARGO.Capture)
            and CARGO.Capture.WeaponValues or {}

        local rows, gapsW, gapsV, real = {}, 0, 0, 0
        for _, t in ipairs(weapons.GetList() or {}) do
            local class = isstring(t.ClassName) and t.ClassName or ""
            local base = isstring(t.Base) and t.Base or ""
            local isArc9 = t.ARC9 == true or base:find("arc9", 1, true) ~= nil
                or class:find("^arc9_") ~= nil
            if class ~= "" and (wantAll or isArc9) then
                local status = DumpStatus(class, t)
                -- price through the same resolver the capture uses (exact
                -- class, else family prefix — weapon_vj_* et al.): a
                -- family-priced gun must not read MISSING here
                local kg, val = weights[class], values[class]
                if val == nil and istable(CARGO.Capture)
                    and isfunction(CARGO.Capture.WeaponValueFor) then
                    val = CARGO.Capture.WeaponValueFor(class)
                end

                local wCell, vCell
                if status ~= "weapon" then
                    wCell = "n/a (" .. status .. ")"
                    vCell = "n/a (" .. status .. ")"
                else
                    real = real + 1
                    if kg ~= nil then
                        wCell = string.format("%.2f kg", kg)
                    else
                        wCell = "MISSING (2.5 nominal)"
                        gapsW = gapsW + 1
                    end
                    if val ~= nil then
                        vCell = tostring(val)
                    else
                        vCell = "MISSING (not tradeable)"
                        gapsV = gapsV + 1
                    end
                end

                rows[#rows + 1] = table.concat({
                    class,
                    isstring(t.PrintName) and t.PrintName or class,
                    isstring(t.SubCategory) and t.SubCategory or "-",
                    isstring(t.Ammo) and t.Ammo or "-",
                    tostring(tonumber(t.ClipSize) or "-"),
                    wCell,
                    vCell,
                }, "\t")
            end
        end
        table.sort(rows)

        local summary = string.format(
            "# %d SWEPs, %d capturables | sin peso: %d | sin precio: %d",
            #rows, real, gapsW, gapsV)
        local body = summary .. "\n"
            .. "class\tname\ttype\tammo\tclip\tweight\tprice\n"
            .. table.concat(rows, "\n")
        file.CreateDir("corpus/cargo")
        file.Write("corpus/cargo/weapon_dump.txt", body)
        MsgN(body)
        Corpus.Log("cargo", "cargo_dev_dump_weapons: " .. #rows
            .. " SWEPs (" .. real .. " capturables) volcados a "
            .. "data/corpus/cargo/weapon_dump.txt — sin peso: " .. gapsW
            .. ", sin precio: " .. gapsV)
    end, nil, "Dump installed ARC9 weapons (class/name/type/ammo/clip/weight/price) to console + data file; bases and ignored classes are marked n/a, not MISSING. Arg 'all' dumps every SWEP")

    -- ------------------------------------------------------------------
    -- Legacy inst_* purge. Entry 41 stopped WRITING one file per instance
    -- (CRG-56), but a third party who ran Cargo before it still has them on
    -- disk — the author's own data/ held 354 orphans out of 370 files. This
    -- is the first real call site of Corpus.Data.List/Delete.
    --
    -- DRY RUN by default: this deletes player data and has NO admin gate yet
    -- (CRG-45 waits on the Corpus permission primitive — one is not invented
    -- here). Only the literal `confirm` deletes anything.
    --
    -- The filter is `^inst_` and nothing else: autogen_defs, icon_overrides,
    -- inv_*, cont_* and trader_* are current data and must survive.
    -- ------------------------------------------------------------------

    local PURGE_PREVIEW = 10

    concommand.Add("cargo_dev_purge_legacy", function(_, _, args)
        local confirm = istable(args) and args[1] == "confirm"

        local legacy = {}
        for _, key in ipairs(Corpus.Data.List("cargo")) do
            if key:match("^inst_") ~= nil then legacy[#legacy + 1] = key end
        end

        if #legacy == 0 then
            Corpus.Log("cargo", "purge: no quedan claves inst_* legacy en data/corpus/cargo/")
            return
        end

        if not confirm then
            MsgN(string.format("— %d claves inst_* legacy (DRY RUN: no se borró nada) —", #legacy))
            for i = 1, math.min(#legacy, PURGE_PREVIEW) do MsgN("  " .. legacy[i]) end
            if #legacy > PURGE_PREVIEW then
                MsgN(string.format("  ... y %d más", #legacy - PURGE_PREVIEW))
            end
            Corpus.Log("cargo", "purge: dry run — para borrarlas: cargo_dev_purge_legacy confirm")
            return
        end

        local borradas = 0
        for _, key in ipairs(legacy) do
            if Corpus.Data.Delete("cargo", key) then borradas = borradas + 1 end
        end
        Corpus.Log("cargo", "purge: " .. borradas .. " de " .. #legacy
            .. " claves inst_* legacy borradas de data/corpus/cargo/")
    end, nil, "Lists (dry run) or deletes ('confirm') the legacy inst_* instance files left behind by pre-entry-41 Cargo. Never touches inv_/cont_/trader_ nor the catalog files")

    -- ------------------------------------------------------------------
    -- What does THIS entity carry of Cargo's? (planilla R, round 3)
    --
    -- A dropped weapon came back from a savegame with nothing of ours on it,
    -- and an ABSENCE leaves no trace to log: there is no marker left to ask.
    -- Two rounds could not tell "the blob never travelled" from "the blob
    -- travelled and something overwrote it", because both end in a
    -- factory-fresh item. This makes it observable — look at the entity and
    -- read what is actually there.
    --
    -- It prints the container marker too, on purpose: pointing it at a crate
    -- and then at a dropped gun IN THE SAME SAVE is the whole experiment. The
    -- crate is a scripted entity and the gun is a SWEP, and whether the engine
    -- treats their Lua tables the same is exactly the open question.
    -- No admin gate, like the rest of the dev kit (CRG-45).
    -- ------------------------------------------------------------------
    concommand.Add("cargo_dev_worldwep", function(ply, _, args)
        if not IsValid(ply) then ply = player.GetAll()[1] end
        if not IsValid(ply) then return end

        local ent = ply:GetEyeTrace().Entity
        if not IsValid(ent) then
            Corpus.Log("cargo", "worldwep: no estás mirando ninguna entidad")
            return
        end

        Corpus.Log("cargo", "worldwep: " .. ent:GetClass() .. " #" .. ent:EntIndex())

        local uid = isstring(ent.CargoInstanceUid) and ent.CargoInstanceUid or nil
        local blobs = istable(ent.CargoInstances) and ent.CargoInstances or nil
        Corpus.Log("cargo", "  CargoInstanceUid  = " .. tostring(uid))
        Corpus.Log("cargo", "  CargoWorldSpawned = " .. tostring(ent.CargoWorldSpawned))
        Corpus.Log("cargo", "  CargoInstances    = "
            .. (blobs and (table.Count(blobs) .. " blob(s)") or "nil"))
        if blobs ~= nil and uid ~= nil and istable(blobs[uid]) then
            local b = blobs[uid]
            Corpus.Log("cargo", "    blob del uid: id=" .. tostring(b.id)
                .. " condition=" .. tostring(b.condition) .. " clip1=" .. tostring(b.clip1))
        end
        Corpus.Log("cargo", "  instancia viva    = "
            .. tostring(uid ~= nil and CARGO.Instances.Get(uid) ~= nil))

        -- LA TABLA DE SAVE DEL ARMA (planilla AC ronda 4). El apagado del
        -- regalo en la fuente NO funcionó —el historial de DGL4 sigue
        -- anunciando los 3 cohetes aunque el pool quede en 0—, y antes de
        -- probar un segundo nombre de campo hay que MEDIR si el campo existe
        -- y qué vale. Adivinar de nuevo sería la tercera vuelta sobre una
        -- suposición, que es justo lo que CRG-24 prohíbe: el engine es un
        -- tercero y su datamap no se lee de memoria.
        --
        -- Se imprimen sólo los campos con "ammo"/"clip" en el nombre: la tabla
        -- entera son cientos de líneas y la consola de GMod las trunca.
        if ent:IsWeapon() then
            local okS, save = pcall(ent.GetSaveTable, ent)
            if not okS or not istable(save) then
                Corpus.Log("cargo", "  save table: NO LEGIBLE en esta entidad — "
                    .. "si no hay datamap, el regalo no se puede apagar por ahí y la frontera es esa")
            else
                -- Por NOMBRE y también por VALOR. Filtrar sólo por "ammo"/"clip"
                -- asume que el campo se llama como uno espera, y ésa es la
                -- suposición que ya falló una vez en este mismo frente. El
                -- regalo que el HUD anuncia es un número conocido —los 3
                -- cohetes—, así que cualquier campo que valga exactamente eso
                -- es candidato, se llame como se llame.
                local esperado = tonumber(args and args[1]) or 3
                local vistos, porValor = 0, 0
                for k, v in pairs(save) do
                    local nombre = tostring(k):lower()
                    local porNombre = nombre:find("ammo", 1, true) or nombre:find("clip", 1, true)
                    local coincide = tonumber(v) == esperado
                    if porNombre or coincide then
                        Corpus.Log("cargo", "  save." .. tostring(k) .. " = " .. tostring(v)
                            .. (coincide and not porNombre and "   <<< vale " .. esperado
                                .. ", candidato por VALOR" or ""))
                        if porNombre then vistos = vistos + 1 end
                        if coincide then porValor = porValor + 1 end
                    end
                end
                Corpus.Log("cargo", "  save table: " .. vistos .. " campo(s) de ammo/clip y "
                    .. porValor .. " que valen " .. esperado
                    .. ", sobre " .. table.Count(save) .. " totales"
                    .. ((vistos == 0 and porValor == 0)
                        and "  <<< ninguno: el regalo NO vive en el datamap" or ""))
                Corpus.Log("cargo", "  (el valor buscado se cambia: cargo_dev_worldwep <n>)")
            end
            Corpus.Log("cargo", "  CargoGiftCut      = " .. tostring(ent.CargoGiftCut)
                .. "   (si es nil, esta arma nunca pasó por el world gate)")
        end

        local cont = istable(ent.CargoContainer) and ent.CargoContainer or nil
        Corpus.Log("cargo", "  CargoContainer    = " .. (cont
            and (#(cont.items or {}) .. " entrada(s), "
                .. table.Count(cont.instances or {}) .. " blob(s)") or "nil"))
        local entry = istable(ent.CargoEntry) and ent.CargoEntry or nil
        Corpus.Log("cargo", "  CargoEntry        = " .. (entry
            and (tostring(entry.id) .. (entry.uid and (" uid=" .. entry.uid) or "")) or "nil"))
    end, nil, "DEV: prints the Cargo fields the entity you are looking at carries (world drop, crate, trader). Point it at a crate and at a dropped gun in the same save to compare")

    -- ------------------------------------------------------------------
    -- roadmap #56 — el ledger de la munición cargada, y el CONTRASTE que la
    -- planilla AC necesita.
    --
    -- Lo que el harness NO puede probar de este bloque es lo único que se
    -- escribió sin poder derivarlo del árbol: los valores de
    -- Ammo.EngineWeaponTypes. `weapons.GetStored` devuelve nil para las armas
    -- de HL2, así que offline sólo se prueba que la tabla SE CONSULTA — no que
    -- acierte. Y ahí cae el caso estrella del bloque, el RPG y sus 3 kg.
    --
    -- POR ESO ESTE COMANDO NO SE APOYA EN LO QUE AUDITA: al lado de nuestra
    -- respuesta imprime la del ENGINE (`GetPrimaryAmmoType` -> `GetAmmoName`),
    -- que es una fuente independiente, y las compara. Un comando que llamara a
    -- `Ammo.TypeOfClass` dos veces no mediría nada.
    --
    -- La columna del engine sólo existe para las armas que están EN LA MANO o
    -- en el mundo: un arma guardada en el grid no tiene entidad, que es
    -- justamente el caso que la tabla resuelve. La ausencia se imprime como
    -- ausencia (`sin entidad`), nunca como coincidencia.
    -- ------------------------------------------------------------------
    concommand.Add("cargo_dev_ammoweight", function(ply)
        if not IsValid(ply) then ply = player.GetAll()[1] end
        if not IsValid(ply) then return end
        if not SERVER then return end

        local rec = CARGO.Inventory.GetRecord(ply)

        -- el tipo según el ENGINE, para el arma viva de esa clase si la hay
        local function EngineType(class)
            local wep = ply:GetWeapon(class)
            if not IsValid(wep) then return nil end
            local ok, t = pcall(wep.GetPrimaryAmmoType, wep)
            if not ok or not isnumber(t) or t < 0 then return nil end
            local name = game.GetAmmoName(t)
            return isstring(name) and name or nil
        end

        local function Linea(donde, uid)
            local blob = CARGO.Instances.Get(uid)
            if not istable(blob) then return end
            local def = CARGO.Items.Get(blob.id)
            local class = istable(def) and def.weapon_class or nil
            if not isstring(class) or class == "" then return end

            local nuestro = CARGO.Ammo.TypeOfClass(class)
            local suyo = EngineType(class)
            local veredicto
            if suyo == nil then
                veredicto = "sin entidad (no comparable)"
            elseif nuestro == nil then
                veredicto = "DISCREPA: el engine dice " .. suyo .. " y nosotros nada"
            elseif nuestro:lower() == suyo:lower() then
                veredicto = "coincide"
            else
                veredicto = "DISCREPA: engine=" .. suyo
            end

            Corpus.Log("cargo", string.format(
                "  %-9s %-26s tipo=%-14s clip1=%-4s balas=%6.3f kg  def=%5.2f  total=%6.2f  [%s]",
                donde, class, tostring(nuestro or "-"), tostring(blob.clip1 or "-"),
                CARGO.Instances.ClipWeight(blob),
                (istable(def) and def.weight or 0),
                CARGO.Instances.WeightOf(blob), veredicto))
        end

        Corpus.Log("cargo", "ammoweight: peso de la municion cargada (roadmap #56)")
        Corpus.Log("cargo", "  la columna [ ] contrasta NUESTRA resolucion contra la del ENGINE;")
        Corpus.Log("cargo", "  'sin entidad' no es coincidencia, es que no hay con que comparar")

        for slot, val in pairs(rec.equip or {}) do
            if isstring(val) then Linea("equip:" .. slot, val) end
        end
        for _, entry in ipairs(rec.items or {}) do
            if entry.uid then Linea("grid", entry.uid) end
        end

        -- EL ESPEJO (CRG-15), y por qué se imprime acá: la planilla AC ronda 2
        -- devolvió tres síntomas —el cinturón no baja, la munición del pickup
        -- no llega a ningún lado, y el unload se niega— que son UN solo hecho
        -- si el espejo no está corriendo. `Reconcile` y `UnloadWeapon`
        -- comparten exactamente un gate, y sin esta línea no había manera de
        -- distinguir "está apagado" de "corre y falla".
        --
        -- El invariante se imprime COMPARADO, no cada mitad por su lado: un
        -- volcado que muestra el pool y te deja sumar el cinturón a ojo no
        -- mide el invariante, lo insinúa.
        local ready = CARGO.AmmoPool.IsReady(ply)
        local totals = CARGO.AmmoPool.BeltTotals(CARGO.Inventory.GetRecord(ply))
        Corpus.Log("cargo", "  ESPEJO: cargo_ammo_pool=" .. GetConVar("cargo_ammo_pool"):GetInt()
            .. "  ready=" .. tostring(ready)
            .. (ready and "" or "   <<< APAGADO: ni el cinturon sigue al pool ni se puede descargar"))

        local balas, desync = 0, 0
        for _, hl2 in ipairs(CARGO.Ammo.TYPES) do
            local n = ply:GetAmmoCount(hl2)
            local belt = totals[hl2] or 0
            if n > 0 or belt > 0 then
                balas = balas + n * CARGO.Ammo.WeightPerRound(hl2)
                local veredicto = "espejo OK"
                if n > belt then
                    veredicto = "DESINCRONIZADO: sobran " .. (n - belt) .. " en el pool (deberia ABSORBER al cinturon)"
                    desync = desync + 1
                elseif n < belt then
                    veredicto = "DESINCRONIZADO: faltan " .. (belt - n) .. " en el pool (deberia DRENAR el cinturon)"
                    desync = desync + 1
                end
                Corpus.Log("cargo", string.format("  reserva   %-20s pool=%-5d cinturon=%-5d %6.3f kg  [%s]",
                    hl2, n, belt, n * CARGO.Ammo.WeightPerRound(hl2), veredicto))
            end
        end
        if desync > 0 then
            Corpus.Log("cargo", "  ESPEJO: " .. desync .. " tipo(s) DESINCRONIZADOS — CRG-15 roto."
                .. " Si ready=true, el espejo corre y NO esta arreglando: eso es un defecto de logica."
                .. " Si ready=false, el espejo nunca corrio: eso es el gate del spawn")
        end

        local cap = CARGO.Inventory.Capacity(ply)
        Corpus.Log("cargo", string.format(
            "  TOTAL %.2f kg de %.2f  ·  reserva del pool %.3f kg  ·  arma en mano: %s",
            CARGO.Inventory.TotalWeight(ply), cap, balas,
            IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() or "ninguna"))
    end, nil, "DEV: per-weapon breakdown of loaded-magazine weight (roadmap #56), with OUR class->ammo-type answer contrasted against the ENGINE's own")

    -- ------------------------------------------------------------------
    -- AB1 (roadmap #53) — is wep.Attachments per ENTITY or shared by CLASS?
    --
    -- The precondition the whole block hangs on. ARC9 never copies that table
    -- when a weapon initializes (only DefaultAttachments = table.Copy(...),
    -- sh_init.lua:43) and writes the mounted state THROUGH it: Attach sets
    -- slottbl.Installed (sh_attach.lua:19) on a slot reached via
    -- AttachmentAddresses, which BuildAttachmentAddresses fills FROM
    -- self.Attachments (sh_subatts.lua:8-19). So if the engine hands every SWEP
    -- entity the same table, two guns of one class share their configuration
    -- and "the config belongs to THIS instance" is unreachable as asked.
    -- Names verified against dev/other/Arc9 Base, 2026-07-30 (CRG-24) — and the
    -- engine is a third party too, which is why this is measured, not read.
    --
    -- WHY IT IS NOT "two weapons in the inventory": a player holds ONE SWEP per
    -- class, which the capture already paid for in game (capture.lua:906-912).
    -- The second one is a grid ITEM, and an item has no Attachments to compare.
    -- The two entities must coexist in the MAP: one in your hands, one on the
    -- floor (drop it, or spawn it from the spawnmenu).
    --
    -- TWO readings, on purpose. Table IDENTITY explains the mechanism; the
    -- INSTALLED set is the verdict, because identity can come back false while
    -- the state is still shared through a deeper reference. Mount a light on
    -- ONE of them: if the other shows it too, they share.
    --
    -- An ABSENCE is reported as an absence — one entity found is NOT evidence
    -- that they do not share, and neither is two bare guns agreeing. Round 3 of
    -- planilla R already paid for reading a silent absence as a result.
    -- ------------------------------------------------------------------
    local function InstalledSig(wep)
        local parts = {}
        for addr, slot in pairs(wep.AttachmentAddresses or {}) do
            if istable(slot) and slot.Installed then
                parts[#parts + 1] = tostring(addr) .. "=" .. tostring(slot.Installed)
            end
        end
        table.sort(parts) -- addresses are ints today; sort the strings anyway
        return table.concat(parts, ","), #parts
    end

    concommand.Add("cargo_dev_attshare", function(ply, _, args)
        if not IsValid(ply) then ply = player.GetAll()[1] end
        if not IsValid(ply) then return end

        local class = isstring(args and args[1]) and args[1] or nil
        if class == nil then
            local held = ply:GetActiveWeapon()
            class = IsValid(held) and held:GetClass() or nil
        end
        if class == nil then
            Corpus.Log("cargo", "attshare: sin clase — pasala como argumento o empuñá el arma")
            return
        end

        local found = {}
        for _, ent in ipairs(ents.FindByClass(class)) do
            if IsValid(ent) and istable(ent.Attachments) then found[#found + 1] = ent end
        end

        Corpus.Log("cargo", "attshare: clase " .. class .. " — " .. #found
            .. " entidad(es) viva(s) con tabla Attachments")

        for i, wep in ipairs(found) do
            local owner = wep:GetOwner()
            local where = IsValid(owner)
                and (owner:IsPlayer() and owner:Nick() or owner:GetClass())
                or "suelo/mundo"
            Corpus.Log("cargo", "  [" .. i .. "] #" .. wep:EntIndex() .. " en " .. where)
            Corpus.Log("cargo", "      Attachments         = " .. tostring(wep.Attachments))
            Corpus.Log("cargo", "      DefaultAttachments  = " .. tostring(wep.DefaultAttachments))
            Corpus.Log("cargo", "      AttachmentAddresses = " .. tostring(wep.AttachmentAddresses))

            local lines = {}
            for addr, slot in pairs(wep.AttachmentAddresses or {}) do
                if istable(slot) and slot.Installed then
                    lines[#lines + 1] = "      slot " .. tostring(addr)
                        .. " Installed=" .. tostring(slot.Installed)
                        .. " ToggleNum=" .. tostring(slot.ToggleNum)
                end
            end
            table.sort(lines)
            if #lines == 0 then
                Corpus.Log("cargo", "      (sin nada montado)")
            else
                for _, line in ipairs(lines) do Corpus.Log("cargo", line) end
            end
        end

        if #found < 2 then
            Corpus.Log("cargo", "attshare: VEREDICTO N/A — hacen falta DOS entidades de la misma "
                .. "clase vivas a la vez, y hay " .. #found .. ". Esto NO dice que no compartan: "
                .. "dice que no se midió. Dropeá una segunda (o spawneala del menú Q) y repetí. "
                .. "Con 0, el arma en la mano no es ARC9 o la clase está mal escrita")
            return
        end

        local sigA, nA = InstalledSig(found[1])
        local sameTable, sameSig, anyMounted = true, true, nA > 0
        for i = 2, #found do
            local sigB, nB = InstalledSig(found[i])
            if not rawequal(found[1].Attachments, found[i].Attachments) then sameTable = false end
            if sigB ~= sigA then sameSig = false end
            if nB > 0 then anyMounted = true end
        end

        Corpus.Log("cargo", "attshare: tabla Attachments compartida por referencia = "
            .. tostring(sameTable) .. " (mecanismo, no veredicto)")

        if not sameSig then
            Corpus.Log("cargo", "attshare: VEREDICTO — POR ENTIDAD. Dos entidades de la misma "
                .. "clase tienen distinto Installed en este instante, así que el estado montado "
                .. "NO se comparte y el invariante (a) del #53 es alcanzable")
        elseif not anyMounted then
            Corpus.Log("cargo", "attshare: VEREDICTO NO CONCLUYENTE — las " .. #found
                .. " están peladas, y coincidir en nada no distingue nada. Montá una linterna en "
                .. "UNA SOLA y volvé a correr el comando")
        else
            Corpus.Log("cargo", "attshare: VEREDICTO — SOSPECHA DE COMPARTIDA POR CLASE. Las "
                .. #found .. " coinciden CON algo montado. Si lo montaste en UNA sola, comparten "
                .. "y el #53 va por el plan B. Si montaste lo mismo en las dos, no distingue: "
                .. "dejá una pelada y repetí")
        end
    end, nil, "DEV (roadmap #53 / AB1): compares wep.Attachments across every live entity of one ARC9 class. Arg: [class], default the weapon in your hands. Needs TWO entities of that class alive at once - hold one and drop another, then mount a light on ONE")

    -- ------------------------------------------------------------------
    -- THE ATTACHMENT LEDGER (author report 2026-07-31, note of check AB9)
    --
    -- Reported: with one UZI Pro in hand, ARC9's C menu offered the extended
    -- magazine that belongs to ANOTHER UZI stored in the backpack. If that is
    -- real it is duplication — mount it on the second gun and the part exists
    -- twice. Four candidate causes, and they need different fixes, so this
    -- prints the number that tells them apart instead of guessing:
    --
    --   1. arc9_free_atts back at 1 — its own PlayerGetAtts short-circuits to
    --      999 BEFORE our hook ever runs (sh_attinv.lua). Not our bug at all,
    --      and every att in the game reads as available.
    --   2. the att is not bridged (Free / InvAtt / no PrintName): our hook
    --      ABSTAINS and ARC9's own store answers. Also not duplication.
    --   3. it is a FACTORY part — the UZI Pro declares eft_uzi_mag_32pro in
    --      its own SWEP.Attachments, so nobody ever paid a grid item for it
    --      and seeing one is not a copy of the other gun's.
    --   4. genuinely counted twice: mounted inside a blob AND sitting in the
    --      grid. That is the only one that is ours, and the only one where
    --      grid > 0 and mounted > 0 at the same time.
    --
    -- `montado` walks every instance the player owns — grid entries, equipped
    -- slots, and recursively through blob.atts — which is the ledger #53 is
    -- supposed to keep: an att is in exactly ONE place.
    -- ------------------------------------------------------------------
    local function CountMounted(atts, out)
        for _, node in ipairs(atts or {}) do
            if istable(node) and isstring(node.att) then
                out[node.att] = (out[node.att] or 0) + 1
                CountMounted(node.sub, out)
            end
        end
    end

    concommand.Add("cargo_dev_attstock", function(ply, _, args)
        if not IsValid(ply) then ply = player.GetAll()[1] end
        if not IsValid(ply) then return end
        if ARC9 == nil then
            Corpus.Log("cargo", "attstock: ARC9 no montado")
            return
        end

        local free = GetConVar("arc9_free_atts")
        local freeN = free and free:GetInt() or -1
        Corpus.Log("cargo", "attstock: arc9_free_atts=" .. tostring(freeN)
            .. (freeN ~= 0 and "  <<< EN 1 EL MOD CONTESTA 999 ANTES QUE NUESTRO HOOK" or "")
            .. "  cargo_arc9_bridge=" .. tostring(GetConVar("cargo_arc9_bridge"):GetInt()))

        -- lo montado, sobre TODAS las instancias del jugador
        local mounted = {}
        local rec = CARGO.Inventory.GetRecord(ply)
        local function scan(uid)
            local blob = isstring(uid) and CARGO.Instances.Get(uid) or nil
            if istable(blob) then CountMounted(blob.atts, mounted) end
        end
        for _, entry in ipairs(rec.items or {}) do scan(entry.uid) end
        for _, val in pairs(rec.equip or {}) do scan(val) end

        local filter = isstring(args and args[1]) and args[1]:lower() or nil
        local lines, dobles = {}, 0
        for id, def in pairs(CARGO.Items._defs) do
            local short = def.arc9_att
            if isstring(short) and (filter == nil or short:lower():find(filter, 1, true)) then
                local grid = CARGO.Inventory.CountItem(ply, id)
                local mon  = mounted[short] or 0
                if grid > 0 or mon > 0 then
                    local ok, hookN = pcall(hook.Run, "ARC9_PlayerGetAtts", ply, short, nil)
                    local flag = (grid > 0 and mon > 0) and "   <<< uno puesto Y uno suelto" or ""
                    if flag ~= "" then dobles = dobles + 1 end
                    lines[#lines + 1] = "  " .. short .. "  grid=" .. grid
                        .. "  montado=" .. mon
                        .. "  hook=" .. tostring(ok and hookN or "err") .. flag
                end
            end
        end
        table.sort(lines)
        for _, l in ipairs(lines) do Corpus.Log("cargo", l) end
        Corpus.Log("cargo", "attstock: " .. #lines .. " att(s) con presencia, "
            .. dobles .. " con copia puesta Y suelta")
        Corpus.Log("cargo", "attstock: OJO — esa columna NO prueba duplicación. Un att "
            .. "stackeable no tiene identidad, así que una FOTO no distingue 'el mismo "
            .. "contado dos veces' de 'tenés uno puesto y otro de repuesto', que es legítimo")
        Corpus.Log("cargo", "attstock: lo que SÍ distingue es la RESTA: corré esto, montá "
            .. "uno desde el menú C, y corré de nuevo. Si `grid` no bajó en 1, ahí hay "
            .. "duplicación de verdad")
    end, nil, "DEV (roadmap #53): attachment ledger. Per att: how many sit in the grid, how many are mounted across ALL your instances, and what our PlayerGetAtts hook answers. An att in BOTH places at once is the duplication. Arg: [name filter]")

end

-- ------------------------------------------------------------------
-- Demo status bars (client). The panel belongs to Cargo but its CONTENT
-- belongs to modules (§11) — none is mounted yet, so two engine-value bars
-- exercise the RegisterBar API. cargo_dev_bars 0 hides them.
-- ------------------------------------------------------------------

if CLIENT then
    local cvBars = CreateClientConVar("cargo_dev_bars", "1", true, false,
        "Demo bars (health/HL2 armor) on the status panel")

    Corpus.OnReady(function()
        if not cvBars:GetBool() then return end
        CARGO.StatusPanel.RegisterBar("dev", {
            id = "health", label = "Health", color = Color(229, 57, 53),
            getValue = function(ply)
                return ply:Health() / math.max(ply:GetMaxHealth(), 1) * 100
            end,
        })
        CARGO.StatusPanel.RegisterBar("dev", {
            id = "armor", label = "HL2 Armor", color = Color(66, 165, 245),
            getValue = function(ply) return ply:Armor() end,
        })
    end)

    -- CLIENT-only name, same routine as cargo_dev_items (see its header). This
    -- is the direct check for the 2026-08-08 defect: the client renders from
    -- ITS defs, and until now nothing in game could list them.
    concommand.Add("cargo_dev_items_cl", function(_, _, args)
        ListDefs(args)
    end, nil, "Lists CLIENT item defs — the catalogue the grid actually renders from (arg: id/name filter)")
end

-- ------------------------------------------------------------------
-- Selftest: deterministic checks over the pure surface, in the realm where
-- it runs (same pattern as corpus_selftest). Listen server, server realm:
-- lua_run Corpus.GetModule("cargo")._SelfTest()
-- ------------------------------------------------------------------

function CARGO._SelfTest()
    local pass, fail = 0, 0
    local function check(name, ok)
        if ok then pass = pass + 1 else
            fail = fail + 1
            Corpus.Log("cargo", "SELFTEST FALLA: " .. name)
        end
    end

    -- item contract validation rejects broken defs
    check("register rechaza class inválida", not pcall(CARGO.Items.Register,
        { id = "st_bad", name = "x", weight = 1, class = "wrong" }))
    check("register rechaza peso negativo", not pcall(CARGO.Items.Register,
        { id = "st_bad2", name = "x", weight = -1, class = "unique" }))

    -- one filter grammar for sub-slots and equipment slots
    local vest = CARGO.Items.Get("cargo_dev_vest")
    local plate = CARGO.Items.Get("cargo_dev_plate")
    check("filtro acepta categoría listada", CARGO.Items.MatchesFilter(plate, "category:plates"))
    check("filtro rechaza categoría ajena", not CARGO.Items.MatchesFilter(plate, "category:optics"))
    check("filtro multi-categoría", CARGO.Items.MatchesFilter(plate, "category:optics,plates"))

    -- display tabs (#23): fixed set, grouping layer OVER the open categories
    local tabs = CARGO.Items.GetTabs()
    check("set de tabs fijo (8, All primero, Misc último)",
        #tabs == 8 and tabs[1].id == "all" and tabs[#tabs].id == "misc")
    check("melee y throwables caen en Weapons",
        CARGO.Items.TabOf("melee") == "weapons"
            and CARGO.Items.TabOf("throwables") == "weapons")
    check("helmets, armor, plates y backpacks caen en Gear",
        CARGO.Items.TabOf("helmets") == "gear" and CARGO.Items.TabOf("armor") == "gear"
            and CARGO.Items.TabOf("plates") == "gear"
            and CARGO.Items.TabOf("backpacks") == "gear")
    check("attachments y optics caen en Mods",
        CARGO.Items.TabOf("attachments") == "mods"
            and CARGO.Items.TabOf("optics") == "mods")
    check("categoría ajena cae en el paraguas Misc",
        CARGO.Items.TabOf("artifacts") == "misc")
    check("def sin categoría cae en Misc", CARGO.Items.TabOf(nil) == "misc")
    check("MatchesTab: la placa está bajo Gear y no bajo Weapons",
        CARGO.Items.MatchesTab(plate, "gear")
            and not CARGO.Items.MatchesTab(plate, "weapons"))
    check("MatchesTab: All acepta todo", CARGO.Items.MatchesTab(plate, "all"))
    check("MatchesTab: entrada sin def cae en Misc",
        CARGO.Items.MatchesTab(nil, "misc") and not CARGO.Items.MatchesTab(nil, "gear"))
    -- la capa de tabs NO se filtra al grammar de slots/sub-slots (contrato #3)
    check("los filtros de categoría siguen intactos (el tab no es categoría)",
        CARGO.Items.MatchesFilter(plate, "category:plates")
            and not CARGO.Items.MatchesFilter(plate, "category:gear"))

    -- ------------------------------------------------------------------
    -- Enumeración del catálogo (CRG-69). El consumidor que la pidió siembra
    -- stock con ella, así que lo que se mide es lo que a él le importa: que
    -- el subconjunto sea el correcto, que el orden sea REPRODUCIBLE y que la
    -- lista devuelta no sea la del registro.
    -- ------------------------------------------------------------------
    local todas = CARGO.Items.GetAll()
    check("GetAll devuelve una lista no vacía", #todas > 0)

    -- ORDEN: es la mitad del contrato y es lo único que se rompe SIN SÍNTOMA
    -- (sin el sort, el catálogo sale en orden de hash y cambia entre
    -- arranques; nada falla, y un defecto que dependa del orden se lee como
    -- mala suerte). Se recorre la lista ENTERA, no una muestra.
    local ordenada = true
    for i = 2, #todas do
        if not (todas[i - 1].id < todas[i].id) then ordenada = false break end
    end
    check("GetAll sale ordenada por id, de punta a punta", ordenada)

    -- las defs van POR REFERENCIA (mismo invariante que Items.Get), y la
    -- LISTA es fresca: mutarla no puede tocar el registro
    check("GetAll devuelve la MISMA def que Get, no una copia",
        CARGO.Items.GetAll()[1] == CARGO.Items.Get(CARGO.Items.GetAll()[1].id))
    local n0 = #todas
    todas[#todas + 1] = { id = "st_no_registrada" }
    check("la lista de GetAll es del caller (mutarla no toca el registro)",
        #CARGO.Items.GetAll() == n0)

    -- ByCategory: subconjunto correcto, y CRUZADO contra GetAll — si el
    -- predicado se equivocara, los dos accesores discreparían
    local placas = CARGO.Items.ByCategory("plates")
    local placasEsperadas = 0
    for _, def in ipairs(CARGO.Items.GetAll()) do
        if def.category == "plates" then placasEsperadas = placasEsperadas + 1 end
    end
    check("ByCategory coincide con filtrar GetAll a mano",
        #placas == placasEsperadas and placasEsperadas > 0)
    local todasPlacas = true
    for _, def in ipairs(placas) do
        if def.category ~= "plates" then todasPlacas = false break end
    end
    check("ByCategory no deja entrar una categoría ajena", todasPlacas)
    check("ByCategory encuentra la placa dev y no la comida dev",
        table.HasValue(placas, CARGO.Items.Get("cargo_dev_plate"))
            and not table.HasValue(placas, CARGO.Items.Get("cargo_dev_food")))

    -- una categoría que nadie registró tiene cero ítems, y eso es una
    -- medición legítima: no es un error y no revienta
    check("categoría inexistente devuelve lista vacía",
        #CARGO.Items.ByCategory("no_existe_esta_categoria") == 0)
    check("argumento inválido devuelve lista vacía, no explota",
        #CARGO.Items.ByCategory(nil) == 0 and #CARGO.Items.ByCategory("") == 0
            and #CARGO.Items.ByCategory(42) == 0)

    -- precio de comercio (Cargo_Trade §4): value x condición x spread
    local Tr = CARGO.Trade
    check("sin value no es comerciable",
        not Tr.IsTradeable({ id = "x", value = nil })
            and not Tr.IsTradeable({ id = "x", value = 0 }))
    check("con value es comerciable", Tr.IsTradeable(plate))
    check("condición 100% (o sin condición) no descuenta",
        Tr.ConditionMult(100) == 1 and Tr.ConditionMult(nil) == 1)
    check("condición 0% cae al piso, no a cero",
        Tr.ConditionMult(0) == Tr.CONDITION_FLOOR and Tr.CONDITION_FLOOR > 0)
    check("la curva de condición es monótona",
        Tr.ConditionMult(50) > Tr.ConditionMult(0)
            and Tr.ConditionMult(50) < Tr.ConditionMult(100))
    check("precio a value completo (sell_mult 1.0)",
        Tr.UnitPrice(plate, nil, 1.0) == plate.value)
    check("el trader compra por menos de lo que vende",
        Tr.UnitPrice(plate, nil, Tr.DEFAULT_BUY_MULT)
            < Tr.UnitPrice(plate, nil, Tr.DEFAULT_SELL_MULT))
    check("un ítem gastado vale menos que uno nuevo",
        Tr.UnitPrice(plate, 40, 1.0) < Tr.UnitPrice(plate, 100, 1.0))
    check("el precio nunca cae a 0 (piso 1)",
        Tr.UnitPrice({ id = "cheap", value = 1 }, 0, 0.1) == 1)
    check("RefKey distingue unique de stack",
        Tr.RefKey({ uid = "abc" }) ~= Tr.RefKey({ id = "abc" })
            and Tr.RefKey({ id = "p", condition = 50 }) ~= Tr.RefKey({ id = "p" }))

    -- sub-slot primitive declared once, queried back
    check("sub-slot placas declarado", CARGO.Items.GetSubSlot(vest, "plates") ~= nil)
    check("sub-slot inexistente es nil", CARGO.Items.GetSubSlot(vest, "nope") == nil)

    -- equip rules: filter + narrowing + class
    check("chaleco entra en body", CARGO.Slots.CanEquip(vest, "body"))
    check("chaleco no entra en head", not CARGO.Slots.CanEquip(vest, "head"))
    check("stackable nunca equipa", not CARGO.Slots.CanEquip(plate, "body"))
    local pistol = CARGO.Items.Get("cargo_dev_pistol")
    check("equip_slots restringe (pistola no es primary)", not CARGO.Slots.CanEquip(pistol, "primary"))
    check("equip_slots permite (pistola es sidearm)", CARGO.Slots.CanEquip(pistol, "sidearm"))

    -- tool slots (§15.2 #21): class-restricted circles
    local pgDef = { id = "st_pg", name = "x", weight = 1, class = "unique",
        category = "weapons", weapon_class = "weapon_physgun" }
    check("tool slot acepta su clase exacta", CARGO.Slots.CanEquip(pgDef, "tool_physgun"))
    check("tool slot rechaza otra arma", not CARGO.Slots.CanEquip({
        id = "st_rifle", name = "x", weight = 1, class = "unique",
        category = "weapons", weapon_class = "weapon_ar2",
    }, "tool_physgun"))
    check("la physgun sigue equipable en slots de arma",
        CARGO.Slots.CanEquip(pgDef, "secondary"))

    -- throwable stack slot (§4 amendment, wheel block 2026-07-13): the ONE
    -- slot that takes stackables — and only its own category. The frag is
    -- the REAL item since roadmap #32 (canonical face of the "Grenade" type)
    local frag = CARGO.Items.Get("cargo_throw_frag")
    check("frag entra en throwable", CARGO.Slots.CanEquip(frag, "throwable"))
    check("throwable rechaza uniques", not CARGO.Slots.CanEquip(pistol, "throwable"))
    check("throwable rechaza stacks de otra categoría",
        not CARGO.Slots.CanEquip(plate, "throwable"))
    check("frag no entra en slots de arma", not CARGO.Slots.CanEquip(frag, "primary"))
    check("intent 8 del wheel mapea a throwable",
        CARGO.Slots.WheelSlots[8] == "throwable" and CARGO.Slots.ById.throwable ~= nil)

    -- STALKER weapon order (roadmap #22): keys 1-7, each naming a real slot
    local hkCount, hkOk = 0, true
    for n, slotId in pairs(CARGO.Slots.Hotkeys) do
        hkCount = hkCount + 1
        if not isnumber(n) or n < 1 or n > 7
            or CARGO.Slots.ById[slotId] == nil then hkOk = false end
    end
    check("hotkeys 1-7 mapean a slots reales", hkOk and hkCount == 7)
    local melee = CARGO.Items.Get("cargo_dev_melee")
    check("melee dev entra en el slot melee", CARGO.Slots.CanEquip(melee, "melee"))

    -- weight curve: anchors + monotonicity
    local mult = CARGO.Weight.SpeedMultiplier
    check("curva: sin carga = 1", mult(0, 54) == 1)
    check("curva: mitad de capacidad = 1", mult(27, 54) == 1)
    check("curva: en el límite = 0.65", math.abs(mult(54, 54) - 0.65) < 0.001)
    check("curva: piso duro 0.15", mult(200, 54) == 0.15)
    local prev, mono = 2, true
    for f = 0, 2, 0.05 do
        local m = mult(f, 1)
        if m > prev + 0.0001 then mono = false end
        prev = m
    end
    check("curva: monótona decreciente", mono)

    -- capacity breakdown
    local back = CARGO.Items.Get("cargo_dev_backpack")
    local total, base, bonus = CARGO.Weight.Capacity(back)
    check("capacidad = base + mochila", total == base + 18 and bonus == 18)

    -- HL2 supplies + generic backpacks (#34): the base framework's default set
    local hk = CARGO.Items.Get("cargo_hl2_healthkit")
    check("suministros HL2 registrados", istable(hk)
        and CARGO.Items.Get("cargo_hl2_healthvial") ~= nil
        and CARGO.Items.Get("cargo_hl2_battery") ~= nil)
    check("suministros HL2: onUse presente en este realm (COR-12)",
        isfunction((hk or {}).onUse)
            and isfunction((CARGO.Items.Get("cargo_hl2_battery") or {}).onUse))
    local bpS = CARGO.Items.Get("cargo_backpack_small")
    local bpL = CARGO.Items.Get("cargo_backpack_large")
    check("mochilas default: equipables en Back con bonus de capacidad",
        istable(bpS) and istable(bpL)
            and CARGO.Slots.CanEquip(bpS, "back") and CARGO.Slots.CanEquip(bpL, "back")
            and bpS.capacity_bonus == 12 and bpL.capacity_bonus == 24)
    -- deliberately NO model (author call 2026-07-23): they drop as the box
    -- until a content addon substitutes one via Items.SetModel
    check("mochilas default sin modelo propio (caen a la caja)",
        (CARGO.Items._modelOverrides.cargo_backpack_small ~= nil
            or CARGO.Items.ResolveModel(bpS) == nil)
        and (CARGO.Items._modelOverrides.cargo_backpack_large ~= nil
            or CARGO.Items.ResolveModel(bpL) == nil))

    -- model substitution point (#34): order-independent, survives re-register
    CARGO.Items.SetModel("st_model_a", "models/st_pre.mdl")
    local mA = CARGO.Items.Register({
        id = "st_model_a", name = "x", weight = 1, class = "stackable" })
    check("SetModel antes del registro aplica al registrar",
        mA.model == "models/st_pre.mdl")
    local mB = CARGO.Items.Register({
        id = "st_model_b", name = "x", weight = 1, class = "stackable",
        model = "models/st_own.mdl" })
    CARGO.Items.SetModel("st_model_b", "models/st_sub.mdl")
    check("SetModel después del registro sustituye el declarado",
        mB.model == "models/st_sub.mdl")
    check("re-registro no resucita el modelo original", CARGO.Items.Register({
        id = "st_model_b", name = "x", weight = 1, class = "stackable",
        model = "models/st_own.mdl" }).model == "models/st_sub.mdl")
    CARGO.Items._defs.st_model_a = nil
    CARGO.Items._defs.st_model_b = nil
    CARGO.Items._modelOverrides.st_model_a = nil
    CARGO.Items._modelOverrides.st_model_b = nil

    -- numeric-key normalization after a JSON round-trip (Corpus.Data
    -- contract: key types are NOT preserved)
    local round = util.JSONToTable(util.TableToJSON({ ["1"] = "a", ["3"] = "b" }))
    local norm = CARGO.Util.NumberKeys(round)
    check("claves numéricas re-normalizadas", norm[1] == "a" and norm[3] == "b")

    if SERVER then
        -- instance blob generic minimum + weight aggregation + delete
        local uid, blob = CARGO.Instances.Create("cargo_dev_vest")
        check("blob: zonas inicializadas a 100", blob.zones and blob.zones.torso == 100)
        check("blob: subslots inicializados", istable(blob.subslots))
        blob.subslots.plates = { { id = "cargo_dev_plate", condition = 100 } }
        local w = CARGO.Instances.WeightOf(uid)
        check("peso instancia = def + placas", math.abs(w - (6.8 + 1.2)) < 0.001)
        CARGO.Instances.Delete(uid)
        check("instancia borrada", CARGO.Instances._live[uid] == nil)

        -- money provider registry: external replaces, usd restores
        local prevActive = CARGO.Money._active
        CARGO.Money.RegisterProvider("st_fake", {
            get = function() return 1 end, add = function() end,
            take = function() return true end, format = function(a) return "F" .. a end,
        })
        check("provider externo pasa a activo", select(2, CARGO.Money.Active()) == "st_fake")
        check("format delega en el activo", CARGO.Money.Format(5) == "F5")
        CARGO.Money._providers.st_fake = nil
        CARGO.Money._active = prevActive
        check("fallback usd restaurado", CARGO.Money._providers[CARGO.Money._active] ~= nil)

        -- ------------------------------------------------------------------
        -- El id de ítem de una CLASE de arma (CRG-70). Acá se mide la mitad
        -- SIN EFECTOS: acuñar una def escribe en `autogen_defs`, que es
        -- config del server, y un selftest que corre en una partida real no
        -- puede dejar ítems fantasma atrás. La mitad que ACUÑA se mide
        -- offline, donde el padrón de SWEPs es una tabla nuestra —
        -- dev/harness_cargo.py, bloque CRG-70.
        -- ------------------------------------------------------------------
        -- Se compara el MOTIVO EXACTO, no "rechazó con algo": un check que
        -- no mira cuál de los gates contestó no juzga ninguno en particular
        -- —lo aprueba el de al lado—, y eso ya pasó acá (ver el aviso del
        -- bloque CRG-70 de dev/harness_cargo.py, 2026-08-18).
        local Cap = CARGO.Capture
        local function motivoDe(clase)
            local wid, motivo = Cap.ItemIdFor(clase)
            return wid == nil and isstring(motivo) and motivo or nil
        end
        check("ItemIdFor: argumento inválido se rechaza CON su motivo",
            motivoDe(nil) == "invalid class" and motivoDe("") == "invalid class"
                and motivoDe(42) == "invalid class")
        -- `corpus_cargo_hands` y no `weapon_fists`: las manos de Cargo SÍ son
        -- un SWEP registrado, así que si el gate `Ignore` no estuviera, la
        -- clase pasaría el de existencia y este check lo vería. Con una clase
        -- del engine (GetStored nil) el gate de abajo la taparía.
        check("ItemIdFor: una clase de la lista Ignore se rechaza POR ESO, existiendo en el padrón",
            motivoDe("corpus_cargo_hands") == "ignored class")
        -- una clase inventada no puede dejar una def fantasma: un id que
        -- nadie puede spawnear persistiría en autogen_defs para siempre
        local claseFalsa = "st_clase_de_arma_inexistente"
        check("ItemIdFor: clase inexistente se rechaza con su motivo",
            motivoDe(claseFalsa) == "unknown weapon class")
        check("ItemIdFor: y NO deja una def fantasma acuñada",
            CARGO.Items.Get("wpn_" .. claseFalsa) == nil)
        -- frag/SLAM ya tienen cara canónica (roadmap #32): ésa es la
        -- respuesta, y no una def autogen nueva
        check("ItemIdFor: una clase con cara canónica devuelve ESA, no una wpn_ nueva",
            Cap.ItemIdFor("weapon_frag") == "cargo_throw_frag"
                and CARGO.Items.Get("wpn_weapon_frag") == nil)
    end

    -- icon system, pure surface only (CLIENT realm — Cargo_ItemImages §2/§5/§7);
    -- the render pipeline and the editor are in-game verification
    if CARGO.Icons ~= nil then
        local fp = CARGO.Icons.QuantizeFootprint(44, 10, "weapons")
        check("icons: rifle largo cuantiza a 6x2", fp.w == 6 and fp.h == 2)
        fp = CARGO.Icons.QuantizeFootprint(40, 10, "ammo")
        check("icons: techo de ammo respeta 2x1", fp.w <= 2 and fp.h <= 1)
        fp = CARGO.Icons.QuantizeFootprint(10, 14, "plates")
        check("icons: placa vertical cae a 2x3", fp.w == 2 and fp.h == 3)

        -- category floor (calibración 1.ª pasada fullscreen): nada de armas
        -- más chatas que 3x2, ni en cuantización ni sobre metas persistidas
        fp = CARGO.Icons.QuantizeFootprint(20, 10, "weapons")
        check("icons: piso de weapons en cuantización", fp.w >= 3 and fp.h >= 2)
        fp = CARGO.Icons.ClampFootprintMin({ w = 3, h = 1 }, "weapons")
        check("icons: meta 3x1 de rifle clampea a 6x2", fp.w == 6 and fp.h == 2)
        fp = CARGO.Icons.ClampFootprintMin({ w = 2, h = 1 }, "weapons")
        check("icons: meta 2x1 de pistola clampea a 4x2", fp.w == 4 and fp.h == 2)
        fp = CARGO.Icons.ClampFootprintMin({ w = 2, h = 1 }, "ammo")
        check("icons: el piso no toca categorías sin mínimo", fp.w == 2 and fp.h == 1)

        local src = CARGO.Icons.ResolveIconSource
        check("icons: icon explícito gana", src({ icon = "x", model = "models/y.mdl" }) == "icon")
        check("icons: modelo resoluble renderea", src({ model = "models/y.mdl" }) == "render")
        check("icons: sin icon ni modelo cae a letra", src({}) == "letter")

        local defA = { id = "st_icons", model = "models/a.mdl", size = { 2, 1 } }
        local k1 = CARGO.Icons.IconCacheKey(defA)
        check("icons: clave estable con misma entrada", CARGO.Icons.IconCacheKey(defA) == k1)
        check("icons: cam distinta cambia la clave", CARGO.Icons.IconCacheKey({
            id = "st_icons", model = "models/a.mdl", size = { 2, 1 },
            icon_cam = { pos = { x = 1, y = 2, z = 3 }, ang = { p = 0, y = 0, r = 0 }, fov = 30 },
        }) ~= k1)
        check("icons: footprint distinto cambia la clave", CARGO.Icons.IconCacheKey({
            id = "st_icons", model = "models/a.mdl", size = { 3, 2 },
        }) ~= k1)
        check("icons: modelo distinto cambia la clave", CARGO.Icons.IconCacheKey({
            id = "st_icons", model = "models/b.mdl", size = { 2, 1 },
        }) ~= k1)
    end

    -- ammo map (§16, roadmap #19): the pure surface of "the belt IS the pool".
    -- The mirror itself needs a live player, so it is verified by the offline
    -- harness and in game — here we only pin the map that the mirror reads.
    if CARGO.Ammo ~= nil then
        -- 14 = 9 de cinturón HL2 + 2 con cara lanzable + los 3 del roadmap #57
        check("ammo: los 14 tipos de engine registrados", #CARGO.Ammo.TYPES == 14)
        check("ammo: los tres pools del #57 resuelven a su ítem",
            CARGO.Ammo.ItemForType("SniperPenetratedRound") == "cargo_ammo_sniperpenetratedround"
            and CARGO.Ammo.ItemForType("SniperRound") == "cargo_ammo_sniperround"
            -- el ítem se llama Winchester y el pool debajo es AirboatGun
            and CARGO.Ammo.ItemForType("AirboatGun") == "cargo_ammo_airboatgun")

        local pistolId = CARGO.Ammo.ItemForType("Pistol")
        check("ammo: el tipo resuelve a su ítem", pistolId == "cargo_ammo_pistol")
        -- ARC9 spells it "pistol", HL2 spells it "Pistol", and GetAmmoCount
        -- takes either: the map must too, or ARC9 weapons feed nothing
        check("ammo: la resolución es case-insensitive",
            CARGO.Ammo.ItemForType("pistol") == pistolId)
        check("ammo: un tipo ajeno no es nuestro", CARGO.Ammo.ItemForType("xen_goo") == nil)
        check("ammo: Managed sigue a ItemForType",
            CARGO.Ammo.Managed("BUCKSHOT") and not CARGO.Ammo.Managed("xen_goo"))

        check("ammo: el ítem declara su tipo de engine",
            CARGO.Ammo.TypeOfDef(CARGO.Items.Get("cargo_ammo_pistol")) == "Pistol")
        -- a WEAPON def carries def.ammo too, but only as a display label — if it
        -- leaked into the pool key, every weapon would be a stack of ammunition
        check("ammo: el def de un arma no declara tipo de pool",
            CARGO.Ammo.TypeOfDef(CARGO.Items.Get("cargo_dev_smg")) == nil)

        -- two DIFFERENT items on ONE engine type: the author's point 4 (two
        -- weapons of "different" calibers eating the same HL2 pool)
        check("ammo: dos ítems distintos comparten un pool",
            CARGO.Ammo.TypeOfDef(CARGO.Items.Get("cargo_dev_ammo_9mm")) == "Pistol")

        -- grenade taxonomy (roadmap #32): the canonical face of "Grenade" and
        -- "slam" is the THROWABLE, never belt ammo; SMG1_Grenade stays ammo
        check("ammo: la cara canónica de Grenade es el lanzable",
            CARGO.Ammo.ItemForType("Grenade") == "cargo_throw_frag")
        check("ammo: la cara canónica de slam es el lanzable",
            CARGO.Ammo.ItemForType("slam") == "cargo_throw_slam")
        check("ammo: la granada del SMG1 sigue siendo munición",
            (CARGO.Items.Get(CARGO.Ammo.ItemForType("SMG1_Grenade")) or {}).category == "ammo")
        check("ammo: el mapa clase->throwable resuelve el weapon_frag",
            CARGO.Ammo.ThrowableClass.weapon_frag == "cargo_throw_frag")

        local complete = true
        for _, hl2 in ipairs(CARGO.Ammo.TYPES) do
            local def = CARGO.Items.Get(CARGO.Ammo.ItemForType(hl2))
            -- max_stack is what makes six belt slots a decision; a model is
            -- what keeps the item off the letter-placeholder fallback. A
            -- throwable face additionally needs its SWEP class (roadmap #32).
            local okCat = istable(def) and (def.category == "ammo"
                or (def.category == "throwables" and isstring(def.weapon_class)))
            if not okCat or def.class ~= "stackable"
                or not isnumber(def.max_stack) or not isstring(def.model) then
                complete = false
            end
        end
        check("ammo: todo tipo trae modelo, tope de stack y categoría", complete)
    end

    Corpus.Log("cargo", string.format("selftest %s: %d OK, %d fallas (realm %s)",
        fail == 0 and "PASÓ" or "FALLÓ", pass, fail, SERVER and "server" or "client"))
    return fail == 0
end

concommand.Add("cargo_selftest", function()
    CARGO._SelfTest()
end, nil, "Cargo primitives self-test (runs in the invoking realm)")

-- CLIENT-only alias, same reason as corpus_selftest_cl: this file is shared, so
-- `cargo_selftest` is registered in BOTH realms and on a listen server the
-- SERVER one wins — typing it at the host console never reaches the client, and
-- `lua_run_cl` is gated by sv_allowcslua (0). Without its own name the CLIENT
-- realm of this module was unverifiable in game, which is how 4.413 missing
-- client defs survived two full map loads with the log green (2026-08-08).
if CLIENT then
    concommand.Add("cargo_selftest_cl", function()
        CARGO._SelfTest()
    end, nil, "Cargo primitives self-test, CLIENT realm (listen server: cargo_selftest wins the server one)")
end
