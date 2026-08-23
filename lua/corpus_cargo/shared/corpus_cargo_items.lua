-- corpus_cargo_items.lua — item contract + generic sub-slot primitive (SHARED)
-- Cargo_Architecture.md §3 (two item classes) and §4 (sub-slots).
--
-- Cargo owns the base schema, how an item is stored and how it renders.
-- The OWNER module keeps the semantics: what onUse does, how condition
-- degrades, what an instance blob means. Cargo transports those fields
-- without interpreting them (cardinal rule of the ecosystem).

local CARGO = Corpus.GetModule("cargo")

CARGO.Items = CARGO.Items or {}
CARGO.Items._defs = CARGO.Items._defs or {}
CARGO.Items._categories = CARGO.Items._categories or {}
CARGO.Items._modelOverrides = CARGO.Items._modelOverrides or {}

-- ------------------------------------------------------------------
-- Categories. Open set: owner modules can register their own; unknown
-- categories referenced by an item def are auto-registered so the UI
-- always has a tab/label for them.
-- ------------------------------------------------------------------

-- Every category is born with its own price knob, `cargo_value_mult_<id>`
-- (roadmap #61). It is created HERE, from the registration itself, and not
-- from a list somewhere else: the category set is OPEN (any addon can call
-- RegisterCategory, and Items.Register auto-registers an unknown one), so a
-- fixed list of convars would cover exactly the categories that existed the
-- day it was written. This way a category registered tomorrow gets its knob
-- for free and nobody maintains a table.
--
-- ARCHIVE + REPLICATED, and the REPLICATED half is not optional: the client
-- paints the price with the same pure function the server charges with
-- (Cargo_Trade §4). A server-only convar would leave the cell showing one
-- number and the Confirm charging another, and the player reads that as the
-- trader stealing from him.
--
-- This side only BUILDS the knob and hands the object over; the reader is
-- Trade.ValueMult, which is where the composition with the global one lives.
-- Handing the ConVar over (instead of the name) keeps the convar name written
-- in exactly ONE place — a second site rebuilding it by hand is how a reader
-- and a writer drift apart without an error.
local MULT_PREFIX = "cargo_value_mult_"

local function MakeMultCvar(id)
    -- A category id becomes part of a console command name. An id the console
    -- cannot type would be a knob nobody can turn, so it gets none and its
    -- category prices at x1 — said out loud, because a silent absence reads
    -- like "the multiplier does not work".
    if id:find("[^%w_]") ~= nil then
        Corpus.Log("cargo", "Items.RegisterCategory: la categoria '" .. id
            .. "' no puede tener perilla de precio (un nombre de convar solo admite"
            .. " letras, numeros y guion bajo); esa categoria multiplica x1")
        return nil
    end
    return CreateConVar(MULT_PREFIX .. id, "1",
        bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
        "Price multiplier for the '" .. id .. "' category (0 = not for sale)", 0)
end

function CARGO.Items.RegisterCategory(id, label, order)
    if not isstring(id) or id == "" then
        error("Cargo.Items.RegisterCategory: 'id' must be a non-empty string", 2)
    end
    -- Re-registering (lua refresh, an addon relabelling one of ours) reuses
    -- the ConVar object already built. No offline test can tell this branch
    -- apart from calling CreateConVar again — and it is kept for exactly that
    -- reason: it makes the outcome independent of what CreateConVar returns
    -- for a name that already exists. The value an operator set has to
    -- survive a refresh, and this way it does either way.
    local prev = CARGO.Items._categories[id]
    CARGO.Items._categories[id] = {
        id = id,
        label = label or (id:sub(1, 1):upper() .. id:sub(2)),
        order = order or 100,
        cvValueMult = prev and prev.cvValueMult or MakeMultCvar(id),
    }
end

-- The price knob of a category, as a ConVar — nil if the category was never
-- registered, or if its id is not console-typeable. Only reader:
-- Trade.ValueMult.
function CARGO.Items.CategoryMultCvar(category)
    local cat = isstring(category) and CARGO.Items._categories[category] or nil
    return cat and cat.cvValueMult or nil
end

-- Base set matching the mockup tab row (InventarioCargo.png). Equipment
-- categories get high order so consumable tabs stay first, like the mock.
-- Labels in English: the mod's player-facing language. Deliberately NO
-- pda/detector categories — those are STALKER-specific; Corpus stays
-- setting-agnostic with a generic "accessories" category (author call,
-- first in-game pass 2026-07-10).
CARGO.Items.RegisterCategory("weapons",     "Weapons",     10)
CARGO.Items.RegisterCategory("ammo",        "Ammo",        20)
CARGO.Items.RegisterCategory("medical",     "Medical",     30)
CARGO.Items.RegisterCategory("food",        "Food",        40)
CARGO.Items.RegisterCategory("attachments", "Attachments", 50)
CARGO.Items.RegisterCategory("optics",      "Optics",      55)
CARGO.Items.RegisterCategory("plates",      "Plates",      60)
CARGO.Items.RegisterCategory("helmets",     "Helmets",     70)
CARGO.Items.RegisterCategory("armor",       "Armor",       71)
CARGO.Items.RegisterCategory("backpacks",   "Backpacks",   72)
CARGO.Items.RegisterCategory("melee",       "Melee",       73)
CARGO.Items.RegisterCategory("accessories", "Accessories", 74)
CARGO.Items.RegisterCategory("throwables",  "Throwables",  75)
CARGO.Items.RegisterCategory("misc",        "Misc",        90)

function CARGO.Items.GetCategories()
    local out = {}
    for _, cat in pairs(CARGO.Items._categories) do out[#out + 1] = cat end
    table.sort(out, function(a, b)
        if a.order == b.order then return a.id < b.id end
        return a.order < b.order
    end)
    return out
end

-- ------------------------------------------------------------------
-- Display tabs (roadmap #23, set closed with the author 2026-07-13).
--
-- The CATEGORY set above stays OPEN and untouched: the "category:a,b"
-- filter grammar of equipment slots and sub-slots (contract #3) leans on
-- it. What is CLOSED is the DISPLAY layer on top of it — a FIXED row of
-- tabs the UI never populates dynamically, so registering a category can no
-- longer add one (the tab row wrapped once "Backpacks" was registered).
--
-- ⚠ THIS COMMENT USED TO CLAIM THE ROW "CAN NO LONGER GROW A SECOND LINE"
-- AND THAT WAS FALSE — measured, roadmap #77, instrument saved as
-- dev/medir_fila_de_tabs.py. Freezing the SET stopped it from growing with
-- the catalog; it did not make the eight fit. They sum 454 px (412 of
-- buttons plus seven 6 px gaps) against a bar of `colR - 16`, which scales
-- with ScrH: 424 at 720p, 453 at 768p, 644 at 1080p. So "Misc" DOES fall to
-- a second row at 1280x720 (by 30 px) and at 1366x768 (by ONE pixel).
--
-- What decides it is the COUNT of tabs and never the length of a name:
-- T.UIScale leaves the fonts fixed on purpose (VGUI fonts cannot be resized
-- per frame), so the tabs measure the SAME at every resolution and only the
-- bar moves. Shortening "Misc" or "Weapons" fixes nothing anywhere.
--
-- Left as it is BY DECISION and not by omission: the wrap already exists as
-- a safety net and the bar grows with it (`bar:SetTall(rowY + 26)`), so the
-- second row is visible and nothing is clipped or lost. Two rows at 720p is
-- fine. What was NOT fine was a comment promising what the code does not
-- do — the next person to add a tab would have believed it.
--
-- Grouping only, never renaming: several internal categories fold into one
-- tab, and a category NOT mapped here (a sibling module registering, say,
-- "artifacts") falls into the "misc" umbrella. An item is therefore always
-- reachable — under All and under its tab — but a foreign category can
-- never mint a tab of its own.
-- ------------------------------------------------------------------

CARGO.Items.TAB_MISC = "misc"

local TABS = {
    { id = "all",     label = "All" },
    { id = "weapons", label = "Weapons" },
    { id = "ammo",    label = "Ammo" },
    { id = "gear",    label = "Gear" },
    { id = "mods",    label = "Mods" },
    { id = "meds",    label = "Meds" },
    { id = "food",    label = "Food" },
    { id = "misc",    label = "Misc" },
}

local CATEGORY_TAB = {
    weapons     = "weapons",
    melee       = "weapons",
    throwables  = "weapons",
    ammo        = "ammo",
    helmets     = "gear",
    armor       = "gear",
    plates      = "gear",
    backpacks   = "gear",
    accessories = "gear",
    attachments = "mods",
    optics      = "mods",
    medical     = "meds",
    food        = "food",
    misc        = "misc",
}

-- fixed row, in row order (fresh copies: the UI must not mutate the set)
function CARGO.Items.GetTabs()
    local out = {}
    for i, tab in ipairs(TABS) do
        out[i] = { id = tab.id, label = tab.label }
    end
    return out
end

function CARGO.Items.TabOf(category)
    if not isstring(category) then return CARGO.Items.TAB_MISC end
    return CATEGORY_TAB[category] or CARGO.Items.TAB_MISC
end

-- "all" takes everything; an entry with no def at all still shows under Misc
-- rather than vanishing from every tab but All
function CARGO.Items.MatchesTab(def, tabId)
    if tabId == nil or tabId == "all" then return true end
    if not istable(def) then return tabId == CARGO.Items.TAB_MISC end
    return CARGO.Items.TabOf(def.category) == tabId
end

-- ------------------------------------------------------------------
-- Can this def be marked as a favorite? (roadmap #43, CRG-76)
--
-- SHARED, and that is the point of it being here rather than an `if` in each
-- realm: the server is the rule and the client is the feedback (CRG-6), so the
-- two of them have to agree on WHICH items are eligible or the context menu
-- offers an option the server then refuses — which is exactly the dead button
-- CRG-6 exists to prevent.
--
-- AMMUNITION IS EXCLUDED, by the author's call and with his reason: "la data de
-- la municion es muy cambiante y dudosamente alguien haria favorito una caja de
-- 120 balas de 9mm". Asked through TabOf and NOT by comparing `category` to the
-- string "ammo": TabOf is the one house of that grouping, so a sibling module
-- registering a second ammo-ish category that folds into the Ammo tab is
-- excluded too, with no second list to keep in step (the list-pasted-by-hand
-- failure mode: it covers the cases that existed the day it was written).
--
-- An entry whose def never registered is NOT eligible: the favorite is a
-- promise that five gates will refuse to move the thing, and a promise made
-- about an item nobody can describe is one the gates cannot keep.
function CARGO.Items.CanFavorite(def)
    if not istable(def) then return false end
    return CARGO.Items.TabOf(def.category) ~= "ammo"
end

-- ------------------------------------------------------------------
-- Stack ceiling and auto-sort criterion (roadmap #67).
--
-- Both live HERE, shared, for the same reason: each is read from the two
-- realms and from four files. A ceiling re-typed at the call site is how the
-- container ended up merging without one while the inventory split by it; a
-- criterion re-typed on the client is how the grid would drift from the order
-- the server stamped. Neither drift raises a single error.
-- ------------------------------------------------------------------

-- Sane ceiling. NO max_stack declared = unlimited, which is what every reader
-- meant by `def.max_stack or math.huge`. A DECLARED ceiling under 1 is a def
-- bug and floors at 1: 0 would spin the split loops of the inventory and the
-- container forever, and a hang is a worse answer than a stack of one.
function CARGO.Items.MaxStack(def)
    if not istable(def) then return math.huge end
    local m = tonumber(def.max_stack)
    if m == nil then return math.huge end
    return math.max(math.floor(m), 1)
end

local UNKNOWN_ORDER = 999

local function CatOrder(def)
    if not istable(def) then return UNKNOWN_ORDER end
    local cat = CARGO.Items._categories[def.category]
    return cat and cat.order or UNKNOWN_ORDER
end

-- Strict weak order over ENTRIES (not defs), and the ONE house of the
-- criterion: the server seeds and rewrites `ord` with it (roadmap #67) and the
-- client falls back to it for the lists that carry no `ord` — the container and
-- the trader stock, which are not the player's to arrange.
--
-- The last three keys are not decoration. `table.sort` in Lua is quicksort and
-- is NOT stable: two entries that tie in every key it compares are free to swap
-- places on every single refresh. That is what made the x120 and the x80 of the
-- same ammo trade places between syncs with nothing having changed, and it is
-- why the order has to be TOTAL over everything the player can tell apart on
-- screen. Two entries that tie even in count are interchangeable by
-- construction: their swap is invisible.
function CARGO.Items.AutoSortLess(a, b)
    if not istable(a) or not istable(b) then return false end

    local da, db = CARGO.Items.Get(a.id), CARGO.Items.Get(b.id)

    local oa, ob = CatOrder(da), CatOrder(db)
    if oa ~= ob then return oa < ob end

    local na = da and da.name or tostring(a.id)
    local nb = db and db.name or tostring(b.id)
    if na ~= nb then return na < nb end

    if a.id ~= b.id then return tostring(a.id) < tostring(b.id) end

    local ua, ub = a.uid or "", b.uid or ""
    if ua ~= ub then return ua < ub end

    -- better condition first, then the bigger pile first
    local ca = isnumber(a.condition) and a.condition or -1
    local cb = isnumber(b.condition) and b.condition or -1
    if ca ~= cb then return ca > cb end

    return (a.count or 1) > (b.count or 1)
end

-- ------------------------------------------------------------------
-- Item registration.
--
-- Base schema (Cargo owns — Cargo_Architecture.md §3):
--   id       string, unique
--   name     string
--   weight   number (kg; per unit for stackables)
--   class    "stackable" | "unique"
--   category string (auto-registered if unknown)
--   icon     optional material path
--   value    optional number — BASE PRICE in the active money provider's
--            currency (Cargo_Trade §4: price = value x condition x spread).
--            An item WITHOUT value is not tradeable: it shows no price tag and
--            the server refuses to move it across a trade. Absence is the
--            honest default — it is not "free", it is "not for sale".
--   display_stats  optional { <statKey> = signedPercent } — manual fallback
--                  when ARC9 is absent (§9); values ARE the deltas shown
--   trivia   optional string — the flavour paragraph. For a captured weapon it
--            is the SWEP's own SWEP.Description (ARC9 packs write one per gun);
--            Capture.WeaponTrivia overrides it where the pack wrote none.
--   trivia_rows  optional { { label = "Caliber", value = "5.45x39mm" }, ... } —
--            ordered spec rows under the stats. Read off the SWEP's SWEP.Trivia
--            block; the order is the one the pack declares, not pairs() order.
--
-- Extended optional fields transported by Cargo (owner module semantics):
--   model          world model for drops (default cardboard box; content
--                  addons may substitute it via Items.SetModel — see below)
--   max_stack      stack ceiling (default: unlimited)
--   onUse          function(ply, ctx) -> true to consume one unit. The closure
--                  only RUNS on SERVER, but def + onUse must be registered in
--                  BOTH realms (shared): the UI gates on isfunction(def.onUse)
--                  client-side (cites COR-12)
--   weapon_class   engine weapon given/stripped on equip/unequip
--   equip_slots    { "primary", ... } narrows which matching slots accept it
--   capacity_bonus kg added to carry capacity while equipped in Back
--   quick_slots    quick slots unlocked while equipped in Body (0-4)
--   has_condition  instance/sub-slot entries start with condition = 100
--   uses           optional integer >= 1 (roadmap #66, CRG-71) — the DISPLAY
--                  UNIT of that condition. With it declared, everywhere Cargo
--                  prints condition prints "n / uses" instead of a percent.
--                  Nothing else changes: the stored number is still the 0-100
--                  condition, the price is still value x condition x spread,
--                  and persistence is untouched. UNIQUE ONLY, and declaring it
--                  IMPLIES has_condition (see Register).
--   condition_zones { "torso", ... } instance starts zones table at 100 each
--   ammo           { caliber = "9x19", hl2 = "Pistol" } — `hl2` is the ENGINE
--                  ammo type and it is the pool key (§16: the belt IS the
--                  reserve). `caliber` is a display label only; it is what the
--                  A/B belt badge groups on. On a WEAPON def, ammo carries the
--                  caliber label alone — a weapon's real type comes from its
--                  entity, never from the def.
--   effect_icon    small overlay tag drawn bottom-left ("hemostatic",
--                  "radiation", "battery" — free string, UI maps known ones)
--   material       display label for plate-like items (e.g. "Cerámica IV")
--
-- Icon system fields (Cargo_ItemImages §4/§5 — consumed client-side):
--   icon_model     optional model path to render for the icon, overriding
--                  the resolved one — escape hatch for weapons whose auto
--                  model (e.g. an ARC9 viewmodel) still frames badly
--   icon_cam       { pos = {x,y,z}, ang = {p,y,r}, fov = n } code-level
--                  camera override for the generated icon
--   size           { w, h } explicit cell footprint (allowed set, §5)
--   icon_override  runtime data override { cam = {...}, size = {w,h} },
--                  written by the dev editor (§8), persisted server-side
--                  and synced with the def snapshot (§10). Beats icon_cam
--                  and size: it exists to fix autogen defs with no code.
-- ------------------------------------------------------------------

local ITEM_CLASSES = { stackable = true, unique = true }

-- Precache the declared model: a prop the map never used is NOT in the
-- precache table, and the drop entity / icon gate then read it as invalid
-- (see Items.ModelUsable). Precaching also networks it to clients.
local function PrecacheDeclared(model)
    if SERVER and isstring(model) and model ~= ""
        and file.Exists(model, "GAME") then
        util.PrecacheModel(model)
    end
end

-- Stored and returned BY REFERENCE (same spirit as the Corpus registry
-- invariant): the owner module may keep populating its own def table.
function CARGO.Items.Register(def)
    if not istable(def) then
        error("Cargo.Items.Register: 'def' must be a table", 2)
    end
    if not isstring(def.id) or def.id == "" then
        error("Cargo.Items.Register: 'id' must be a non-empty string", 2)
    end
    if not isstring(def.name) or def.name == "" then
        error("Cargo.Items.Register: 'name' must be a non-empty string (item '" .. def.id .. "')", 2)
    end
    if not isnumber(def.weight) or def.weight < 0 then
        error("Cargo.Items.Register: 'weight' must be a number >= 0 (item '" .. def.id .. "')", 2)
    end
    if not ITEM_CLASSES[def.class] then
        error("Cargo.Items.Register: 'class' must be \"stackable\" or \"unique\" (item '" .. def.id .. "')", 2)
    end

    -- USES (roadmap #66, CRG-71). Two gates, and both exist because the
    -- failure they stop is SILENT:
    --
    --   · UNIQUE ONLY. A stack carries ONE condition for its N units (that is
    --     what CRG-7 is about), so spending "one use" on it would spend it for
    --     every unit at once. There is no shape of that which is not a bug.
    --   · DECLARING IT TURNS has_condition ON. Without it, Instances.Create
    --     never seeds blob.condition, ConditionOf answers nil and the item
    --     renders NOTHING — no bar, no number, no error anywhere. Requiring
    --     both fields buys nothing and leaves that no-op reachable (author
    --     vote 2026-08-19: implying it is harder to use wrong).
    if def.uses ~= nil then
        if not isnumber(def.uses) or def.uses < 1 or def.uses ~= math.floor(def.uses) then
            error("Cargo.Items.Register: 'uses' must be an integer >= 1 (item '"
                .. def.id .. "')", 2)
        end
        if def.class ~= "unique" then
            error("Cargo.Items.Register: 'uses' is unique-only (item '" .. def.id
                .. "'): a stack holds ONE condition for its N units, so one use"
                .. " would spend them all", 2)
        end
        def.has_condition = true
    end

    def.category = def.category or "misc"
    if CARGO.Items._categories[def.category] == nil then
        CARGO.Items.RegisterCategory(def.category)
    end

    if CARGO.Items._defs[def.id] ~= nil and CARGO.Items._defs[def.id] ~= def then
        -- expected on lua refresh; replace so the newest table wins
        Corpus.Log("cargo", "Items.Register: '" .. def.id .. "' re-registered; replacing previous def")
    end

    -- a stored substitution (Items.SetModel) beats the declared model, and it
    -- must re-apply here: autogen defs and lua refreshes re-register their
    -- table, which would otherwise resurrect the original model
    if CARGO.Items._modelOverrides[def.id] ~= nil then
        def.model = CARGO.Items._modelOverrides[def.id]
    end
    PrecacheDeclared(def.model)

    -- persisted icon overrides re-attach on (re-)register: autogen defs are
    -- rebuilt every session, but their editor adjustments must survive
    -- (Cargo_ItemImages §4.3). Server-only: clients receive the field with
    -- the def snapshot (§10).
    if SERVER and istable(CARGO.Items._iconOverrides)
        and CARGO.Items._iconOverrides[def.id] ~= nil then
        def.icon_override = CARGO.Items._iconOverrides[def.id]
    end

    CARGO.Items._defs[def.id] = def
    return def
end

function CARGO.Items.Get(id)
    return CARGO.Items._defs[id]
end

-- ------------------------------------------------------------------
-- USES — condition read as a UNIT (roadmap #66, CRG-71).
--
-- The author's ask, textual: "un solo item pero con x usos mas que varios
-- items en un stack (...) el tooltip deberia decir cuantos usos le queda".
-- The bar he describes was already drawn — what was missing is the UNIT: the
-- cell said 67 % where a jar of pills should say 2/3.
--
-- SO THIS IS A PRESENTATION LAYER AND NOTHING ELSE. There is no second stored
-- number: the blob still holds the 0-100 condition, the price still comes out
-- of `value x condition x spread` (Cargo_Trade §4) — which is why a half-used
-- jar already resold at half without a line of code — and persistence does not
-- change. Take `uses` off a def and every one of those keeps working.
--
-- THE ROUNDING IS CEILING, and it was a vote (author, 2026-08-19). The rule it
-- buys is the only line Cargo and the owner module can agree on without
-- talking to each other: **0 uses if and only if condition 0**. Under floor, an
-- item at condition 33,3 with uses = 3 reads "0 uses" while it still works
-- once, and the player throws away a working item — the expensive lie. Ceiling
-- can only err the other way (say 3 when 2 remain) and ONLY if the owner
-- module subtracts by hand, which is what ConditionForUses is here to prevent.
--
-- SPENDING A USE IS THE OWNER'S (CRG-1) BUT THE ARITHMETIC IS OURS, because
-- the unit is ours. The owner spends one with:
--
--     local left = Cargo.Items.UsesLeft(def, blob.condition)
--     blob.condition = Cargo.Items.ConditionForUses(def, left - 1)
--
-- and never by subtracting 33 — that is the drift the paragraph above
-- describes, and it accumulates: three "33" off 100 leaves 1, which ceiling
-- reads as one use that does not exist. The two functions ROUND-TRIP by
-- construction (UsesLeft(def, ConditionForUses(def, n)) == n for every n), and
-- the harness asserts exactly that over every n of every size up to 10.
--
-- AT ZERO THE ITEM STAYS (author vote 2026-08-19). Cargo does not delete it,
-- does not hide it and does not refuse it: CRG-1 says what a spent item means
-- belongs to the owner, which may want an empty jar to be sellable, refillable
-- or thrown away by hand. It paints red at 0/3, the same way it already paints
-- "Broken". Anyone consuming this will assume the opposite, so it is written
-- here, in Cargo_Architecture.md §3 and in the contract block of the init.
-- ------------------------------------------------------------------

-- How many uses the def declares, or nil for the 99 % of defs that declare
-- none. EVERY function below answers nil for those, and that nil is what keeps
-- the conversion from leaking onto items that never asked for it.
function CARGO.Items.UsesOf(def)
    if not istable(def) or not isnumber(def.uses) then return nil end
    if def.uses < 1 then return nil end
    return math.floor(def.uses)
end

-- Uses left at a given condition. nil condition = the def tracks none yet, and
-- an untouched item is full. The epsilon is not cosmetic: n/total*100 does not
-- come back through /100*total as an exact integer in floating point, and
-- without it ConditionForUses(def, 2) could read back as 3 — the exact "the
-- item lies" this whole block exists to prevent.
function CARGO.Items.UsesLeft(def, condition)
    local total = CARGO.Items.UsesOf(def)
    if total == nil then return nil end
    local cond = tonumber(condition)
    if cond == nil then return total end
    if cond <= 0 then return 0 end
    return math.Clamp(math.ceil(cond / 100 * total - 1e-9), 1, total)
end

-- The condition that reads as exactly n uses — the inverse, and the ONLY way
-- the owner module should write one back.
function CARGO.Items.ConditionForUses(def, n)
    local total = CARGO.Items.UsesOf(def)
    if total == nil then return nil end
    n = math.Clamp(math.floor(tonumber(n) or 0), 0, total)
    return n * 100 / total
end

-- ------------------------------------------------------------------
-- ENUMERATING THE CATALOGUE (CRG-69). `Items.Get` answers for ONE def by id
-- and there was no public way to WALK them: the three loops that exist
-- (dev.lua, lan.lua, iconeditor.lua) read `_defs` straight because they live
-- INSIDE the module. A consumer from outside had no door — and the first one
-- is already knocking: the food trader of corpus-stalker sells "everything
-- that declares category = food" as a RULE, not as a list, precisely so a
-- food registered by a future addon joins on its own. That rule cannot be
-- written without walking the registry, and STK-1 forbids that addon from
-- adding the accessor itself. So it is added here, where the registry lives.
--
-- STABLE ORDER, and it is HALF the contract, not decoration. `_defs` is a
-- hash and `pairs` order is not reproducible across sessions. A trader that
-- seeds its stock in that order builds a DIFFERENT catalogue every boot
-- without anyone having rolled for it, and a bug that depends on the order
-- never reproduces twice — the worst shape a defect can take, because it
-- reads as a bad roll. Both accessors return their list sorted by id, so the
-- only randomness a caller sees is the randomness the caller asked for.
--
-- THE LIST IS FRESH, THE DEFS ARE BY REFERENCE. The array belongs to the
-- caller and may be mutated; the defs inside it are the same tables
-- `Items.Get` hands out (the owner module keeps writing them — see the
-- by-reference note on Register). Mutating the registry itself is NOT part
-- of this surface: there is no public way to unregister, and this does not
-- open one.
--
-- TWO THINGS A CALLER HAS TO KNOW, because neither is guessable:
--   · THE TWO REALMS HOLD DIFFERENT CATALOGUES (COR-12). Autogen defs are
--     minted server-side and only reach a client through the snapshot that
--     needs them, so the same call answers with different sets on each side.
--     Measured 2026-08-08: 4.413 defs server, 51 non-bulk client.
--   · AN EMPTY RESULT IS AMBIGUOUS AND THIS API CANNOT DISAMBIGUATE IT. A
--     category nobody registered and a category with zero items are the same
--     answer, and so is a typo in the category name. It is not a defect to
--     fix here — categories auto-register off the first def that names one,
--     so the two states are genuinely identical in the registry. A caller who
--     needs to tell them apart asks `GetCategories()`, which lists what was
--     registered; and one who seeds stock off this should LOG the count, or
--     "the pack is not mounted" and "my filter matches nothing" look alike.
--
-- NOT A HOT PATH: both walk the whole registry and sort. With the captured
-- arsenal registered that is thousands of entries — fine at spawn or on a
-- restock timer, wrong inside a Think.
-- ------------------------------------------------------------------

local function SortedDefs(acepta)
    local out = {}
    for _, def in pairs(CARGO.Items._defs) do
        if acepta == nil or acepta(def) then out[#out + 1] = def end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- Every registered def of THIS realm, id-ordered. Includes the bulk catalogue
-- (ARC9 attachments, captured `wpn_*` weapons, the NVG variants): hiding them
-- is a DISPLAY decision and it stays in dev.lua, where the listing that wants
-- it lives. An accessor that silently dropped entries would be lying about
-- what is registered.
function CARGO.Items.GetAll()
    return SortedDefs(nil)
end

-- The defs of one category, id-ordered. The category set is OPEN (any addon
-- may register one), so this takes the id as data and knows nothing about
-- which categories exist.
function CARGO.Items.ByCategory(category)
    if not isstring(category) or category == "" then return {} end
    return SortedDefs(function(def) return def.category == category end)
end

-- ------------------------------------------------------------------
-- Def piggyback (Cargo_ItemImages §10) — ONE routine, every snapshot.
--
-- Autogen defs (captured engine weapons) are minted SERVER-side and the
-- client has no registry of its own for them: it learns each one from the
-- first snapshot that carries it. So ANY snapshot that can show an item the
-- viewer never held has to bring the def along — otherwise the cell resolves
-- to nil and renders as an unknown def: blank, 1×1, not even the placeholder
-- letter (grid.lua PaintCell bails, Icons.GetFootprint falls back to 1×1).
--
-- The inventory did this inline and the container and the trader did not,
-- which stayed invisible while a persisted crate could not return a unique at
-- all. It surfaced the moment it could: in-game report 2026-07-26 — a crate
-- reopened after a map reload showed its two captured weapons as empty 1×1
-- cells, while the dev ammo next to them (a SHARED def, registered in both
-- realms) drew fine.
-- ------------------------------------------------------------------

-- SERVER: fills snap.defs with the defs `entries` needs the client to know.
-- Only autogen defs and defs carrying an icon override travel: everything
-- else is registered in a shared file and already exists on both sides.
function CARGO.Items.PackDefs(snap, entries)
    if not istable(snap) or not istable(entries) then return snap end
    for _, entry in pairs(entries) do
        local def = istable(entry) and CARGO.Items.Get(entry.id or "") or nil
        if def ~= nil and (def.autogen or def.icon_override ~= nil) then
            snap.defs = snap.defs or {}
            snap.defs[def.id] = def
        end
    end
    return snap
end

-- CLIENT: registers what arrived. Engine names travel as localization tokens
-- ("#HL2_Pistol") and resolve here, once, on first sight.
function CARGO.Items.AbsorbDefs(snap)
    if not CLIENT then return end
    if not istable(snap) or not istable(snap.defs) then return end

    for id, def in pairs(snap.defs) do
        local known = CARGO.Items.Get(id)
        if known == nil then
            if isstring(def.name) and def.name:sub(1, 1) == "#" then
                def.name = language.GetPhrase(def.name:sub(2))
            end
            CARGO.Items.Register(def)
        elseif known ~= def then
            -- def-level icon override data rides this same channel: merge in
            -- place (by-ref invariant) and drop that def's icon caches only
            -- if it actually changed
            local before = known.icon_override and util.TableToJSON(known.icon_override) or ""
            local after = def.icon_override and util.TableToJSON(def.icon_override) or ""
            if before ~= after then
                known.icon_override = def.icon_override
                if CARGO.Icons and isfunction(CARGO.Icons.Invalidate) then
                    CARGO.Icons.Invalidate(id)
                end
            end
        end
    end
end

-- ------------------------------------------------------------------
-- Model substitution point (CHANGELOG #34, author call 2026-07-23).
--
-- A def registered WITHOUT a model is the honest default for
-- setting-agnostic items (Coagulant's medical set, the generic backpacks):
-- it drops as the cardboard box and its icon falls back to the letter
-- placeholder. A CONTENT addon (corpus_stalker) re-skins those defs from
-- outside without owning them: the override is stored and applied either
-- right now or whenever the def (re-)registers, so the call order between
-- addons never matters (COR-5: no addon may assume another already loaded).
-- It also beats a def-declared model, so any item can be re-skinned. A
-- path that is not mounted is harmless: ModelUsable gates the drop and the
-- icon render, both fall back exactly as if no model were set.
-- ------------------------------------------------------------------

function CARGO.Items.SetModel(id, model)
    if not isstring(id) or id == "" then
        error("Cargo.Items.SetModel: 'id' must be a non-empty string", 2)
    end
    if not isstring(model) or model == "" then
        error("Cargo.Items.SetModel: 'model' must be a non-empty model path (item '" .. id .. "')", 2)
    end
    CARGO.Items._modelOverrides[id] = model
    local def = CARGO.Items._defs[id]
    if def ~= nil then
        def.model = model
        PrecacheDeclared(model)
    end
end

-- ------------------------------------------------------------------
-- Model resolution chain (CHANGELOG #3). Started life inside the drop
-- entity (corpus_cargo_item.lua); extracted here SHARED because the icon
-- system (Cargo_ItemImages §3) reuses the exact same chain client-side.
-- Returns a candidate model path or nil — the CALLER validates it against
-- the engine (util.IsValidModel) because validity is realm/content-bound.
-- ------------------------------------------------------------------

-- engine (HL2/base gmod) weapons are not scripted SWEPs, so their world
-- model can't be looked up — small known map so drops/icons look like the gun
local ENGINE_WMODELS = {
    weapon_pistol     = "models/weapons/w_pistol.mdl",
    weapon_357        = "models/weapons/w_357.mdl",
    weapon_smg1       = "models/weapons/w_smg1.mdl",
    weapon_ar2        = "models/weapons/w_irifle.mdl",
    weapon_shotgun    = "models/weapons/w_shotgun.mdl",
    weapon_crossbow   = "models/weapons/w_crossbow.mdl",
    weapon_frag       = "models/weapons/w_grenade.mdl",
    weapon_rpg        = "models/weapons/w_rocket_launcher.mdl",
    weapon_crowbar    = "models/weapons/w_crowbar.mdl",
    weapon_stunstick  = "models/weapons/w_stunbaton.mdl",
    weapon_physcannon = "models/weapons/w_physics.mdl",
    weapon_physgun    = "models/weapons/w_physics.mdl",
    weapon_slam       = "models/weapons/w_slam.mdl",
    gmod_tool         = "models/weapons/w_toolgun.mdl",
    gmod_camera       = "models/maxofs2d/camera.mdl",
}

-- def.model wins; then the scripted SWEP's WorldModel; then the engine map
function CARGO.Items.ResolveModel(def)
    if not istable(def) then return nil end
    if isstring(def.model) and def.model ~= "" then return def.model end
    if isstring(def.weapon_class) then
        local stored = weapons.GetStored(def.weapon_class)
        if stored and isstring(stored.WorldModel) and stored.WorldModel ~= "" then
            return stored.WorldModel
        end
        return ENGINE_WMODELS[def.weapon_class]
    end
    return nil
end

-- Can the engine actually show this model? `util.IsValidModel` ALONE is not a
-- sufficient gate: it answers false for models that exist in mounted content
-- but were never precached on the current map. In-game report 2026-07-12:
-- models/props_junk/garbage_takeoutcarton001a.mdl (a real HL2 prop, verified
-- present in hl2_misc_dir.vpk) silently fell back to the letter icon and to
-- the cardboard drop, while models/items/healthkit.mdl — precached because
-- HL2 registers item_healthkit — worked. The file check covers the
-- mounted-but-unprecached case; both together never let a bogus path through.
function CARGO.Items.ModelUsable(model)
    if not isstring(model) or model == "" then return false end
    if util.IsValidModel(model) then return true end
    return file.Exists(model, "GAME")
end

-- ------------------------------------------------------------------
-- Icon footprint data (Cargo_ItemImages §5). The footprint LOGIC lives in
-- the icon system (client); the allowed set and per-category ceilings live
-- here SHARED because the server validates editor overrides against them
-- (they are def-level data, synced like any def field — §10). Values are
-- the starting candidates from the spec; calibrated empirically in game.
-- ------------------------------------------------------------------

CARGO.Items.ICON_FOOTPRINTS = {
    { 1, 1 }, { 2, 1 }, { 1, 2 }, { 2, 2 }, { 3, 1 }, { 3, 2 },
    { 2, 3 }, { 4, 2 }, { 5, 2 }, { 6, 2 }, { 3, 3 }, { 4, 3 }, { 3, 4 },
}

-- per-category footprint ceiling {maxW, maxH}: keeps a badly scaled model
-- from inflating its cell. Categories not listed use "default".
CARGO.Items.ICON_CATEGORY_CAPS = {
    ammo    = { 2, 1 },
    medical = { 2, 2 },
    weapons = { 6, 2 },
    armor   = { 4, 4 },
    default = { 3, 3 },
}

-- per-category footprint FLOOR {minW, minH} (author calibration, first
-- fullscreen in-game pass 2026-07-12): flat weapon tiles (ARC9 crops
-- measured down to 3x1) read wrong in the tiered grid — a weapon occupies
-- at least a pistol's volume. Enforced in quantization and over persisted
-- footprint metas; explicit def.size / editor overrides stay authoritative.
CARGO.Items.ICON_CATEGORY_MINS = {
    weapons = { 3, 2 },
}

function CARGO.Items.IsAllowedFootprint(w, h)
    if not isnumber(w) or not isnumber(h) then return false end
    for _, fp in ipairs(CARGO.Items.ICON_FOOTPRINTS) do
        if fp[1] == w and fp[2] == h then return true end
    end
    return false
end

-- ------------------------------------------------------------------
-- Category filters. One tiny grammar shared by sub-slots (§4) and
-- equipment slots (corpus_cargo_slots.lua): "category:a,b" accepts any
-- item whose category is listed. Implemented ONCE — optic on Head,
-- exo/shield on Body and plate slots on Body all go through here.
-- ------------------------------------------------------------------

local function ParseFilter(filter)
    if not isstring(filter) then return nil end
    local kind, rest = filter:match("^(%w+):(.+)$")
    if kind ~= "category" or rest == nil then return nil end
    local set = {}
    for cat in rest:gmatch("[^,%s]+") do set[cat] = true end
    return set
end

function CARGO.Items.MatchesFilter(def, filter)
    if not istable(def) then return false end
    local set = ParseFilter(filter)
    if set == nil then return false end
    return set[def.category] == true
end

-- ------------------------------------------------------------------
-- Sub-slot primitive (Cargo_Architecture.md §4). An item def declares
-- N sub-slots, each with a category filter. The same primitive serves
-- Head->optic, Body->exo/shield and Body->plates; no ad-hoc variants.
--
-- Occupied sub-slots live in the instance blob as
--   blob.subslots[spec.id] = { { id = <itemId>, uid = ?, condition = ? }, ... }
-- and are ALWAYS ejected back to an inventory before the host instance
-- is destroyed (mandatory ejection rule, enforced server-side).
-- ------------------------------------------------------------------

function CARGO.Items.DeclareSubSlot(def, spec)
    if isstring(def) then def = CARGO.Items._defs[def] end
    if not istable(def) then
        error("Cargo.Items.DeclareSubSlot: 'def' must be a registered def table or item id", 2)
    end
    if not istable(spec) or not isstring(spec.id) or spec.id == "" then
        error("Cargo.Items.DeclareSubSlot: 'spec.id' must be a non-empty string", 2)
    end
    if ParseFilter(spec.filter) == nil then
        error("Cargo.Items.DeclareSubSlot: 'spec.filter' must look like \"category:a,b\" (sub-slot '" .. spec.id .. "')", 2)
    end

    def.subslots = def.subslots or {}
    for _, existing in ipairs(def.subslots) do
        if existing.id == spec.id then
            error("Cargo.Items.DeclareSubSlot: sub-slot '" .. spec.id .. "' already declared on '" .. tostring(def.id) .. "'", 2)
        end
    end

    def.subslots[#def.subslots + 1] = {
        id = spec.id,
        filter = spec.filter,
        maxItems = spec.maxItems or 1,
        label = spec.label or spec.id,
    }
    return def
end

function CARGO.Items.GetSubSlot(def, subId)
    if not istable(def) or not istable(def.subslots) then return nil end
    for _, spec in ipairs(def.subslots) do
        if spec.id == subId then return spec end
    end
    return nil
end
