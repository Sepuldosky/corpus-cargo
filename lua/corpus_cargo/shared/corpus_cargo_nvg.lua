-- corpus_cargo_nvg.lua — [VManip] Neosun's Cooler Nightvision compat: the DEFS
-- (SHARED — COR-12: the client grid renders from defs, so the derivation runs
-- identically in both realms). Roadmap #47; map + wants:
-- dev/Cargo_NVG_Neosun_Referencia.md. Every mod API name below was verified
-- against the live code in dev/other/[vmanip] neosun's cooler nightvision
-- (CRG-24), never from memory:
--
--   ArcticNVGs                  global array, 61 entries, declared shared in
--                               the mod's lua/autorun/sh_arctic_nvg.lua:9
--   ArcticNVGs_ShortNameToID    reverse index built at sh:2583-2587
--   entry.ShortName             the STABLE key ("nvg_pvs14_g")
--   entry.Entity                world entity class ("arctic_nvg_pvs14_green")
--   entry.Model                 world model — six for sixty-one variants
--   entry.ThermalVision / FullColor / NoBrightenWorld   display flags
--
-- WHY DERIVED AND NOT CATALOGUED (CRG-41/CRG-42, and CRG-63 which this file
-- coins). Writing 61 defs by hand is exactly the work those norms exist to
-- avoid, and this mod has two naming traps that a hand-written map gets
-- wrong: in the five NVG families `_t` means TEAL, but in the aviators
-- `shades_t` is the THERMAL one and the teal is `shades_teal`; and `_hp`
-- displays as "Ruby". Derived, neither trap can be typed. A mod patch that
-- adds a variant becomes a def on its own, and one that retires a variant
-- stops registering — no edit here.
--
-- WHAT IS CATALOGUED BY HAND: one table, the SIX families (weight, value,
-- footprint). Six real models for sixty-one variants — the colour is
-- post-processing, not a different model — so six rows is the honest size of
-- the hand-written part. The numbers are starting values, to calibrate in
-- game like every other value of the set.
--
-- WHAT IS NEVER PERSISTED: the ORDINAL. ply:GetNWInt("nvg") stores the index
-- `i` of the mod's array, not a name; a patch that inserts a variant in the
-- middle shifts every later index and a stored pair would wake up being
-- other goggles. The def carries the ShortName and the ordinal is resolved
-- at equip time, against the live table (CRG-63).
--
-- OFF-LIMITS: the mod is COMPAT-RUNTIME and is never modified, forked or
-- copied (mods_workshop_mapa.md §3-§4). Referencing its world models BY PATH
-- at runtime is not copying an asset — it is what Cargo already does with
-- ARC9 models and with the Zone props.

local CARGO = Corpus.GetModule("cargo")

CARGO.NVG = CARGO.NVG or {}

-- Read ONCE, at boot, when the defs are registered: flipping it mid-session
-- does not unregister a catalogue. Replicated so a client and its server
-- agree on whether the 61 defs exist — a def the server has and the client
-- does not renders as an error letter, since PackDefs only ships autogen
-- defs (items.lua:280-290) and these are not autogen.
local cvRegister = CreateConVar("cargo_nvg_register", "1",
    bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
    "Register the Neosun nightvision variants as Cargo items (0 = leave them to the mod)")

-- ------------------------------------------------------------------
-- The hand-written half: six families, keyed by the model each declares.
-- ------------------------------------------------------------------
--   weight kg · value base price (Cargo_Trade §4) · size cell footprint
--     (from the allowed set, Items.ICON_FOOTPRINTS)
--   label  family name for the derived trivia line
--
-- Shape of the price curve, and it is a judgement call to calibrate in
-- game: four tubes (GPNVG-18) beat a monocular (PVS-14), a dedicated
-- thermal (T-7, both variants) beats both, and the aviators are a joke item
-- that costs like sunglasses. A thermal variant that lives INSIDE a
-- non-thermal family (gpnvg_thermal, shades_thermal) is priced as its
-- family: the catalogue is per family and stays six rows.
local FAMILIES = {
    ["models/arctic_nvgs/nvg_gpnvg.mdl"] =
        { weight = 0.85, value = 22000, size = { 2, 2 }, label = "GPNVG-18" },
    ["models/arctic_nvgs/nvg_pnv.mdl"] =
        { weight = 0.90, value = 8000,  size = { 2, 2 }, label = "PNV-10T" },
    ["models/arctic_nvgs/nvg_n15.mdl"] =
        { weight = 0.70, value = 14000, size = { 2, 2 }, label = "N-15" },
    ["models/arctic_nvgs/nvg_pvs14.mdl"] =
        { weight = 0.40, value = 9000,  size = { 2, 1 }, label = "PVS-14" },
    ["models/arctic_nvgs/nvg_t7.mdl"] =
        { weight = 1.10, value = 38000, size = { 2, 2 }, label = "T-7" },
    ["models/arctic_nvgs/aviators.mdl"] =
        { weight = 0.05, value = 60,    size = { 1, 1 }, label = "Aviators" },
}

-- Fallback for a family the mod adds later: registering it with honest
-- middle-of-the-road numbers beats dropping the variant on the floor.
local FAMILY_DEFAULT = { weight = 0.60, value = 9000, size = { 2, 1 }, label = "Nightvision" }

CARGO.NVG.ID_PREFIX = "cargo_nvg_"

-- ------------------------------------------------------------------
-- Derivation (pure: reads a table, returns def tables, registers nothing).
-- Split out from Register so the offline harness can feed it a table it
-- controls — including a REORDERED one, which is the check that the ordinal
-- never leaks into an id (CRG-63).
-- ------------------------------------------------------------------

-- The entity's PrintName is the display name ("PVS-14 (Green)"): it lives on
-- the per-variant entity file, not in the shared table. scripted_ents is a
-- shared library and the mod's entity files call AddCSLuaFile(), so the
-- lookup answers in both realms — but it is asked defensively anyway, since
-- a nil name would make Items.Register error() and take the whole boot with
-- it. Absent, the ShortName is the honest fallback and the in-game check is
-- what confirms the real names read right.
local function DisplayName(entry)
    local class = isstring(entry.Entity) and entry.Entity or ""
    if class ~= "" and scripted_ents ~= nil and isfunction(scripted_ents.GetStored) then
        local ok, stored = pcall(scripted_ents.GetStored, class)
        if ok and istable(stored) and istable(stored.t)
            and isstring(stored.t.PrintName) and stored.t.PrintName ~= "" then
            return stored.t.PrintName
        end
    end
    return isstring(entry.ShortName) and entry.ShortName or class
end

-- Display label derived from the mod's own flags — never from the name
-- suffix, which is where the two traps live.
local function Trivia(entry, fam)
    local kind = "Light-intensifying night vision goggles."
    if entry.ThermalVision == true then
        kind = "Thermal imaging goggles."
    elseif entry.NoBrightenWorld == true then
        kind = "Tinted glasses: they colour the view without amplifying light."
    elseif entry.FullColor == true then
        kind = "Full-colour night vision goggles."
    end
    return fam.label .. ". " .. kind
end

-- tbl: the mod's array (nil / not a table => empty result, COR-5).
-- Returns an array of def tables, in the table's own order.
function CARGO.NVG.Derive(tbl)
    local out = {}
    if not istable(tbl) then return out end

    -- ipairs, not pairs: the mod builds its own reverse index with pairs
    -- over a sequential array (sh:2585), which is one more reason not to
    -- treat its ordinal as a contract. Here the order is only iteration.
    for _, entry in ipairs(tbl) do
        local short = istable(entry) and isstring(entry.ShortName) and entry.ShortName or nil
        if short ~= nil and short ~= "" then
            local fam = FAMILIES[entry.Model or ""] or FAMILY_DEFAULT
            local class = isstring(entry.Entity) and entry.Entity or ""
            out[#out + 1] = {
                id = CARGO.NVG.ID_PREFIX .. short,
                name = DisplayName(entry),
                class = "unique",
                category = "optics",
                weight = fam.weight,
                value = fam.value,
                size = { fam.size[1], fam.size[2] },
                -- The world model is the icon source, on purpose. The mod DOES
                -- ship one cropped PNG per variant (materials/entities/, named
                -- after the class) and the first pass used it — but in game its
                -- spawnmenu art reads wrong next to the generated renders of
                -- every other item (author's call, first pass 2026-07-26). So
                -- no `icon`: the pipeline renders def.model like it does for
                -- the rest of the grid, and the whole catalogue looks like ONE
                -- catalogue. Cost, declared: six models for sixty-one variants
                -- means the colour does not show in the cell — the NAME is what
                -- tells a Green from a Ruby. Per-def framing is still tunable
                -- with the icon editor (`cargo_icon_edit`), which writes an
                -- icon_override and survives re-registration.
                model = isstring(entry.Model) and entry.Model or nil,
                has_condition = true,
                effect_icon = "battery",
                trivia = Trivia(entry, fam),
                -- Cargo TRANSPORTS this and never interprets it (CRG-1): the
                -- compat resolves it to an ordinal at equip time (CRG-63).
                nvg_shortname = short,
                -- world entity class, for the pickup registry (server side)
                nvg_entity = class ~= "" and class or nil,
            }
        end
    end
    return out
end

-- ------------------------------------------------------------------
-- Registration. Inert without the mod: the global does not exist, Derive
-- returns nothing and not one def is registered (COR-5).
-- ------------------------------------------------------------------

CARGO.NVG.ByEntity = CARGO.NVG.ByEntity or {}   -- world class -> item id

function CARGO.NVG.Register(tbl)
    local defs = CARGO.NVG.Derive(tbl)
    for _, def in ipairs(defs) do
        CARGO.Items.Register(def)
        if def.nvg_entity ~= nil then
            CARGO.NVG.ByEntity[def.nvg_entity] = def.id
        end
    end
    return #defs
end

-- Short name of a registered def, or nil. The ONLY thing that is persisted.
function CARGO.NVG.ShortNameOf(defId)
    local def = CARGO.Items.Get(defId or "")
    return istable(def) and isstring(def.nvg_shortname) and def.nvg_shortname or nil
end

-- Short name -> the mod's ordinal, resolved against the LIVE index every
-- time (CRG-63). nil when the mod is absent or the name is not one of its
-- own — and validating here is not optional: the mod's own
-- ArcticNVGs_SetPlayerGoggles does NOT validate, and an unknown name walks
-- straight into SetNWInt("nvg", nil), which is an argument error.
function CARGO.NVG.OrdinalOf(shortName)
    if not isstring(shortName) or shortName == "" then return nil end
    if not istable(ArcticNVGs_ShortNameToID) then return nil end
    local id = ArcticNVGs_ShortNameToID[shortName]
    return isnumber(id) and id > 0 and id or nil
end

-- ------------------------------------------------------------------
-- Boot. The mod declares its globals at autorun include time and Cargo boots
-- at Initialize, after every autorun file, so a mounted mod is always
-- visible here (same reasoning as corpus_cargo_quickloadout.lua).
-- ------------------------------------------------------------------

-- ACTIVE = the mod is there AND its catalogue belongs to Cargo. The server
-- half reads this and does nothing at all when it is false: with no defs of
-- ours, writing the mod's networked var would be taking a slot machine we
-- refused to own.
CARGO.NVG._active = false

if not istable(ArcticNVGs) then
    Corpus.Log("cargo", "neosun nvg no montado — compat inactiva")
elseif not cvRegister:GetBool() then
    Corpus.Log("cargo", "neosun nvg: cargo_nvg_register en 0 — el catálogo queda del mod")
else
    local n = CARGO.NVG.Register(ArcticNVGs)
    CARGO.NVG._active = n > 0
    Corpus.Log("cargo", "neosun nvg: " .. n .. " variantes registradas como ítems")
end

function CARGO.NVG.Active()
    return CARGO.NVG._active == true
end
