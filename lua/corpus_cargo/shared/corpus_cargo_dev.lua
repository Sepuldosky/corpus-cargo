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

CARGO.Items.Register({
    id = "cargo_dev_helmet", name = "Sphere-08 Helmet (dev)",
    weight = 1.9, class = "unique", category = "helmets",
    size = { 3, 3 },
    has_condition = true,
    trivia = "Sealed military helmet with a standard front mount. Framework test item.",
})
CARGO.Items.DeclareSubSlot("cargo_dev_helmet", {
    id = "optic", filter = "category:optics", maxItems = 1, label = "optic",
})

CARGO.Items.Register({
    id = "cargo_dev_nvg", name = "PNV-10T NVG (dev)",
    weight = 0.6, class = "unique", category = "optics",
    size = { 2, 1 },
    has_condition = true, effect_icon = "battery",
    trivia = "Test night vision goggles. Mount them on the helmet's optic sub-slot.",
})

local devVest = CARGO.Items.Register({
    id = "cargo_dev_vest", name = "CS-3a Vest (dev)",
    weight = 6.8, class = "unique", category = "armor",
    size = { 3, 4 },
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
    size = { 3, 3 },
    has_condition = true, capacity_bonus = 18,
    trivia = "Three-zip assault pack, 40 L. Adds +18 kg of carry capacity while equipped on Back.",
})

CARGO.Items.Register({
    id = "cargo_dev_plate", name = "Ceramic Plate IV (dev)",
    weight = 1.2, class = "stackable", category = "plates",
    size = { 2, 3 },
    has_condition = true, material = "Ceramic IV",
    trivia = "Test ballistic plate. What a plate does is Caliber's call; Cargo only stores and shows it.",
})

CARGO.Items.Register({
    id = "cargo_dev_medkit", name = "Field Medkit (dev)",
    weight = 0.4, class = "stackable", category = "medical",
    size = { 2, 2 },
    effect_icon = "hemostatic",
    trivia = "Test consumable for the onUse flow. Real medicine is Coagulant's domain.",
    -- onUse is the OWNER-module side of the contract (CORPUS_Architecture
    -- §5): this dev item plays that role for verification only.
    onUse = function(ply)
        ply:SetHealth(math.min(ply:Health() + 25, ply:GetMaxHealth()))
        return true -- consume one unit
    end,
})

CARGO.Items.Register({
    id = "cargo_dev_food", name = "Canned Food (dev)",
    weight = 0.3, class = "stackable", category = "food",
    size = { 2, 2 },
    trivia = "Test food. Real hunger is Craving's domain.",
    onUse = function(ply)
        local cargoMod = Corpus.GetModule("cargo")
        cargoMod.Inventory.Notice(ply, "You eat the canned food. (Craving is not mounted: no hunger effect.)")
        return true
    end,
})

CARGO.Items.Register({
    id = "cargo_dev_ammo_9mm", name = "9x19 FMJ (dev)",
    weight = 0.012, class = "stackable", category = "ammo",
    size = { 2, 1 },
    ammo = { caliber = "9x19", types = { "FMJ", "AP", "HP" } },
    trivia = "Test ammunition for caliber overlays and large stacks.",
})

CARGO.Items.Register({
    id = "cargo_dev_smg", name = "Tactical SMG (dev)",
    weight = 3.0, class = "unique", category = "weapons",
    size = { 4, 2 },
    weapon_class = "weapon_smg1", equip_slots = { "primary", "secondary" },
    has_condition = true,
    ammo = { caliber = "4.6x30", types = { "FMJ" } },
    display_stats = { accuracy = -8, handling = -21, damage = -11, firerate = -9 },
    trivia = "Test weapon (HL2 SMG). Manual stats via display_stats — the ARC9 route uses GetProcessedValue.",
})

CARGO.Items.Register({
    id = "cargo_dev_pistol", name = "Service Pistol (dev)",
    weight = 0.9, class = "unique", category = "weapons",
    size = { 3, 2 },
    weapon_class = "weapon_pistol", equip_slots = { "sidearm" },
    has_condition = true,
    ammo = { caliber = "9x19", types = { "FMJ" } },
    trivia = "Test sidearm (HL2 pistol).",
})

CARGO.Items.Register({
    id = "cargo_dev_melee", name = "Crowbar (dev)",
    weight = 2.5, class = "unique", category = "melee",
    size = { 3, 1 },
    weapon_class = "weapon_crowbar",
    trivia = "Test melee weapon (HL2 crowbar).",
})

-- generic accessories: the accessory slots are setting-agnostic (no PDA/
-- detector STALKER furniture in the base framework)
CARGO.Items.Register({
    id = "cargo_dev_pda", name = "Datapad (dev)",
    weight = 0.5, class = "unique", category = "accessories",
    size = { 2, 2 },
    trivia = "Minor test accessory for the accessory slots.",
})

CARGO.Items.Register({
    id = "cargo_dev_detector", name = "Scanner (dev)",
    weight = 0.4, class = "unique", category = "accessories",
    size = { 2, 1 },
    has_condition = true,
    trivia = "Minor test accessory for the accessory slots.",
})

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
        { "cargo_dev_ammo_9mm", 120 }, { "cargo_dev_smg" },
        { "cargo_dev_pistol" }, { "cargo_dev_melee" },
        { "cargo_dev_pda" }, { "cargo_dev_detector" },
    }

    concommand.Add("cargo_dev_give", function(ply)
        if not IsValid(ply) then ply = player.GetAll()[1] end
        if not IsValid(ply) then return end
        for _, it in ipairs(KIT) do
            CARGO.Inventory.GiveItem(ply, it[1], it[2])
        end
        Corpus.Log("cargo", "kit dev entregado a " .. ply:Nick())
    end, nil, "Gives the Cargo test item kit")

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

    Corpus.Log("cargo", string.format("selftest %s: %d OK, %d fallas (realm %s)",
        fail == 0 and "PASÓ" or "FALLÓ", pass, fail, SERVER and "server" or "client"))
    return fail == 0
end

concommand.Add("cargo_selftest", function()
    CARGO._SelfTest()
end, nil, "Cargo primitives self-test (runs in the invoking realm)")
