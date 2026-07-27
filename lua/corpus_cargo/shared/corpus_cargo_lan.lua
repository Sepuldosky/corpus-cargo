-- corpus_cargo_lan.lua — carrying a player record between servers (SHARED)
-- Cargo_Architecture.md §12 (CRG-61). Block B5 of dev/PLAN_cargo_persistencia_gc.md.
--
-- This is the ONE place in the module where data goes from a CLIENT into the
-- SERVER. Every other net receiver of Cargo is protected by CRG-6 — the server
-- owns the inventory and a client only sends intents, so a hostile intent is
-- validated against real state and can fabricate nothing. Here the client sends
-- STATE, so CRG-6 is INVERTED, in a single point and under lock:
--
--   1. cargo_import_enabled is 0 by default        -- the door is shut
--   2. admin gate (cargo_import_admin, 1)          -- who may knock
--   3. SteamID64 whitelist, EMPTY means NOBODY     -- never "empty = everyone"
--   4. rate limit per player                       -- an import is expensive
--   5. only then: bounded read, format, signature, sanitising, re-mint
--
-- The convar, the whitelist and the gate are not decoration: they are what
-- makes the inversion acceptable (CRG-61). If the inversion existed and the
-- lock did not, this file would be a hole.
--
-- WHY THE RECEIVER IS ALWAYS REGISTERED, EVEN WITH THE CONVAR AT 0. Not
-- registering would be the stronger form, but util.AddNetworkString runs at
-- boot, so a convar flipped mid-game could not take effect without a map
-- change — and, decisively, a receiver that does not exist has nowhere to
-- print WHY it rejected. Every rejection here logs its motive: an import that
-- "did nothing" and does not say why is the defect that costs three rounds
-- (B4, planilla R, the log line that never printed).
--
-- WHY THERE IS NO CHUNKING. Measured offline, not assumed (§3.b of the PROMPT):
-- a heavy but realistic record — 60 uniques each with a nested sub-slot, plus
-- 40 stacks — renders to 15.770 bytes of JSON, and 200 uniques + 100 stacks to
-- 51.310. Compressed by Util.WriteBlob it is a fraction of that, well inside
-- one net message. So chunking would be decoration; what the payload needs is
-- a CEILING that rejects with a motive, which is what MAX_JSON is. The harness
-- asserts the measurement, so the day a blob grows fat the check goes red
-- offline instead of an import failing silently in someone's game.
--
-- SHARED because the import has two halves: the server owns the lock and the
-- sanitising, and the client owns nothing but reading its own file and sending
-- it. Same shape as corpus_cargo_dev.lua.

local CARGO = Corpus.GetModule("cargo")

CARGO.Lan = CARGO.Lan or {}

local NET_IMPORT = Corpus.Net.Register("cargo", "import")

-- Format number. NOT a migration path (D2 of the plan: no migrations) — it
-- exists so an old file is REJECTED with a readable motive instead of being
-- accepted as garbage from another era.
CARGO.Lan.FORMAT = 1

-- Ceilings. MAX_WIRE bounds the compressed read before a single byte is
-- decompressed; MAX_JSON bounds the result, which is what stops a small
-- payload from expanding into a huge one. MAX_DEPTH bounds the scrub walk:
-- a record's real depth is about 7 (record → instances → blob → subslots →
-- slot → list → entry), so 12 is generous and still finite.
local MAX_WIRE  = 65536
local MAX_JSON  = 131072
local MAX_DEPTH = 12

-- Money is the one field whose MAGNITUDE nothing else bounds. Past 2^31 it
-- stops being a number the UI can format, so that is where it clamps.
local MAX_MONEY = 2147483647

-- ------------------------------------------------------------------
-- Compatibility signature (§3.d of the PROMPT)
--
-- What it can and cannot promise, said out loud — a signature that promises
-- what it cannot keep is worse than none:
--
--   modules  STABLE. Which Corpus modules registered. Note that corpus-stalker
--            is a CONTENT addon and registers no module, so this half does not
--            see it.
--   defs     STABLE, and it is the half that does see content addons: every
--            non-autogen def is registered at boot by a shared file, so the
--            sorted id list is a function of the mounted addons and nothing
--            else. This is the half worth hashing.
--   autogen  NOT STABLE, and it travels as a bare count for exactly that
--            reason: autogen_defs accumulates over a server's LIFE (read from
--            capture.lua, not assumed — a def survives unmounting its pack),
--            so two servers with identical mods today can hold different sets
--            depending on what each one ever captured.
--
-- Therefore the signature is a WARNING, never a gate. What actually protects
-- the destination is the per-entry sanitising: a def this server does not know
-- drops that entry with a log and the rest survives (COR-5). The format number
-- is the half that DOES reject.
-- ------------------------------------------------------------------

function CARGO.Lan.Signature()
    local mods = {}
    -- The framework exposes HasModule/GetModule but no enumeration primitive,
    -- and adding one would make this a cross-repo pass, which B5 explicitly is
    -- not. Read-only introspection of the registry, guarded.
    for name in pairs(istable(Corpus._modules) and Corpus._modules or {}) do
        mods[#mods + 1] = name
    end
    table.sort(mods)

    local ids, autogen = {}, 0
    for id, def in pairs(CARGO.Items._defs) do
        if istable(def) and def.autogen then
            autogen = autogen + 1
        else
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)

    return {
        modules = mods,
        defs = #ids,
        defs_hash = util.CRC(table.concat(ids, "\n")),
        autogen = autogen,
    }
end

-- Human-readable differences, for the log. Returns a list of strings; empty
-- means the two sides look alike as far as this can tell.
function CARGO.Lan.SignatureDiff(theirs, ours)
    local out = {}
    if not istable(theirs) then
        out[#out + 1] = "el archivo no trae firma de compatibilidad"
        return out
    end

    local mine, yours = {}, {}
    for _, m in ipairs(istable(ours.modules) and ours.modules or {}) do mine[m] = true end
    for _, m in ipairs(istable(theirs.modules) and theirs.modules or {}) do yours[m] = true end
    for m in SortedPairs(yours) do
        if not mine[m] then out[#out + 1] = "el origen tenía el módulo '" .. m .. "' y este servidor no" end
    end
    for m in SortedPairs(mine) do
        if not yours[m] then out[#out + 1] = "este servidor tiene el módulo '" .. m .. "' y el origen no" end
    end

    if theirs.defs_hash ~= ours.defs_hash then
        out[#out + 1] = string.format(
            "el catálogo de defs difiere (origen %s defs, destino %s) — los ítems que este servidor no conozca se descartan uno por uno",
            tostring(theirs.defs), tostring(ours.defs))
    end
    return out
end

-- ------------------------------------------------------------------
-- SERVER
-- ------------------------------------------------------------------

if SERVER then

local cvEnabled = CreateConVar("cargo_import_enabled", "0", FCVAR_ARCHIVE,
    "Allow players to import a character record sent from their client. OFF by default: this is the only point where client data enters the server")
local cvAdmin = CreateConVar("cargo_import_admin", "1", FCVAR_ARCHIVE,
    "Require the importing player to be an admin. Turning this off leaves the whitelist as the only gate")
local cvWhitelist = CreateConVar("cargo_import_whitelist", "", FCVAR_ARCHIVE,
    "SteamID64s allowed to import, separated by spaces or commas. EMPTY MEANS NOBODY")
local cvCooldown = CreateConVar("cargo_import_cooldown", "30", FCVAR_ARCHIVE,
    "Seconds a player must wait between imports", 0, 3600)

-- sid64 -> CurTime() of the last accepted import. A DURATION, never a moment
-- somebody else has to observe (§0.bis 3 of the PROMPT).
CARGO.Lan._lastImport = CARGO.Lan._lastImport or {}

local function Sid(ply)
    return IsValid(ply) and ply:SteamID64() or nil
end

-- Corpus.Data errors on a key outside [a-z0-9_-], which would blow up a
-- console command. Sanitise here and reject with a motive instead.
local function SafeKey(name)
    if not isstring(name) or name == "" then return nil end
    if name:match("^[%w_%-]+$") == nil then return nil end
    return name:lower()
end

function CARGO.Lan.ExportKey(sid, name)
    return "export_" .. (SafeKey(name) or tostring(sid))
end

-- ------------------------------------------------------------------
-- EXPORT (§4) — the easy side, and the one with no enemy.
--
-- The record, rendered by the routine of B3 (RenderOwner), plus a header. It
-- is self-contained by construction (CRG-56): entries plus `instances`, with
-- nested sub-slots inside.
--
-- What it does NOT write:
--   · anything indexed by Player, and no Entity — the record holds neither by
--     construction, and the harness asserts flat, acyclic data (the guard the
--     entry 46 built for the savegame, pointed at this payload)
--   · any deadline derived from CurTime(). `created` is a wall clock stamp for
--     a human reading the file, never something the import counts down from
--   · the wallet, unless the NATIVE money provider is active. Money is an
--     interface with providers (§6): exporting a wallet another provider owns
--     is fabricating cash at the destination. Author's call 2026-07-26 — the
--     wallet travels ONLY when `usd` is active on BOTH sides.
-- ------------------------------------------------------------------

function CARGO.Lan.Export(ply, name)
    if not IsValid(ply) or not ply:IsPlayer() then
        return nil, "el export corre sobre un jugador: no hay ninguno en este contexto"
    end
    if name ~= nil and SafeKey(name) == nil then
        return nil, "nombre de archivo inválido: se aceptan letras, números, '_' y '-'"
    end

    local sid = Sid(ply)
    if sid == nil then
        return nil, "el jugador no tiene SteamID64 (¿un bot?), no hay record que exportar"
    end

    local rec = CARGO.Inventory.GetRecord(ply)
    CARGO.Instances.RenderOwner(rec)

    -- A COPY on purpose, and it is the one place where copying is right: this
    -- is dead data on its way to a file, so trimming it must not touch the
    -- live record. CRG-57's by-reference rule governs the RUNTIME path, not
    -- this one.
    local snapshot = table.Copy(rec)

    local _, provider = CARGO.Money.Active()
    if provider ~= "usd" then
        snapshot.wallet = nil
        Corpus.Log("cargo", "export: el provider de dinero activo es '" .. tostring(provider)
            .. "' y no el nativo — el wallet NO viaja (§4.2: exportarlo fabricaría plata en el destino)")
    end

    local payload = {
        format = CARGO.Lan.FORMAT,
        created = os.time(),
        origin = sid,
        origin_name = ply:Nick(),
        money_provider = provider,
        signature = CARGO.Lan.Signature(),
        record = snapshot,
    }

    -- SCOPE, and it is left DELIBERATELY at the default. COR-19 has two:
    -- "config" (server catalogue, outlives deleting a save) and "save" (game
    -- state, dies with it). An export file is honestly NEITHER — it is a
    -- transport artifact whose whole purpose is to cross profiles and servers.
    -- Today both scopes resolve to the same folder, so nothing moves either
    -- way; the day B6 splits them, an export sitting under
    -- saves/<perfil>/cargo/ would die with the campaign it was meant to
    -- outlive. That is B6's call to make, not a norm to invent here — declared
    -- in §12.1 so it is a decision waiting, not a landmine.
    local key = CARGO.Lan.ExportKey(sid, name)
    Corpus.Data.Save("cargo", key, payload)
    return key, nil
end

-- ------------------------------------------------------------------
-- SANITISING (§5.2) — nothing that arrives is believed.
--
-- The precedent in shape is the icon override sanitiser (CRG-46): an unknown
-- def is ignored, a value outside the allowed set is discarded. What is new
-- here is the volume, so every drop carries its MOTIVE into the report the
-- caller logs.
--
-- Cargo TRANSPORTS blobs without interpreting them (CRG-1), so an owner
-- module's own fields ride through untouched — but only after Scrub has
-- proved they are flat data. What Cargo DOES own it validates: condition,
-- zones, sub-slots and ammo group are the generic minimum of §3.
-- ------------------------------------------------------------------

-- JSON can only produce strings, numbers, booleans and tables, so this is not
-- guarding against a Material arriving; it guards against DEPTH and against
-- the numbers JSON can express and Lua arithmetic cannot survive.
local function Scrub(value, depth)
    local t = type(value)
    if t == "string" or t == "boolean" then return value end
    if t == "number" then
        -- NaN and ±inf: a parser can produce them out of 1e999 and every
        -- comparison downstream then silently answers false
        if value ~= value or value == math.huge or value == -math.huge then return nil end
        return value
    end
    if t ~= "table" or depth >= MAX_DEPTH then return nil end

    local out = {}
    for k, v in pairs(value) do
        local kt = type(k)
        if kt == "string" or kt == "number" then
            local clean = Scrub(v, depth + 1)
            if clean ~= nil then out[k] = clean end
        end
    end
    return out
end

local function Clamp01to100(v, fallback)
    if not isnumber(v) then return fallback end
    return math.Clamp(math.floor(v), 0, 100)
end

-- A stack entry: { id, count, condition? }. Counts are cut to the max_stack of
-- the REAL def, never to the one that arrived.
local function CleanStack(entry, report, where)
    if not istable(entry) or not isstring(entry.id) then
        report[#report + 1] = where .. ": entrada que no es un stack, descartada"
        return nil
    end
    local def = CARGO.Items.Get(entry.id)
    if def == nil then
        report[#report + 1] = where .. ": def desconocida '" .. entry.id .. "', descartada"
        return nil
    end
    if def.class ~= "stackable" then
        report[#report + 1] = where .. ": '" .. entry.id .. "' no es apilable y llegó como stack, descartada"
        return nil
    end

    local maxStack = isnumber(def.max_stack) and def.max_stack or 1
    local count = isnumber(entry.count) and math.floor(entry.count) or 1
    if count < 1 then
        report[#report + 1] = where .. ": '" .. entry.id .. "' con count " .. tostring(entry.count) .. ", descartada"
        return nil
    end
    if count > maxStack then
        report[#report + 1] = where .. ": '" .. entry.id .. "' traía " .. count
            .. " y el max_stack real es " .. maxStack .. " — recortada"
        count = maxStack
    end

    -- condition on a stack is legal (a worn plate returned from a sub-slot is
    -- a stack of its own — CRG-7) but only on a def that HAS condition
    local condition = nil
    if def.has_condition and entry.condition ~= nil then
        condition = Clamp01to100(entry.condition, nil)
    end
    return { id = entry.id, count = count, condition = condition }
end

-- One arrived blob. Returns the cleaned blob or nil + motive.
local function CleanBlob(uid, blob, report)
    if not isstring(uid) or not istable(blob) or not isstring(blob.id) then
        report[#report + 1] = "blob '" .. tostring(uid) .. "' malformado, descartado"
        return nil
    end
    local def = CARGO.Items.Get(blob.id)
    if def == nil then
        report[#report + 1] = "blob '" .. uid .. "': def desconocida '" .. blob.id .. "', descartado"
        return nil
    end
    if def.class ~= "unique" then
        report[#report + 1] = "blob '" .. uid .. "': '" .. blob.id .. "' no es un unique, descartado"
        return nil
    end

    -- Everything the owner module put in rides along (CRG-1); what Cargo owns
    -- is re-derived from the DEF, never from what arrived.
    local clean = table.Copy(blob)
    clean.id = blob.id

    if def.has_condition then
        clean.condition = Clamp01to100(clean.condition, 100)
    else
        clean.condition = nil
    end

    if istable(def.condition_zones) then
        local zones = {}
        for _, zone in ipairs(def.condition_zones) do
            zones[zone] = Clamp01to100(istable(clean.zones) and clean.zones[zone] or nil, 100)
        end
        clean.zones = zones
    else
        clean.zones = nil
    end

    if clean.ammo_group ~= nil and clean.ammo_group ~= "A" and clean.ammo_group ~= "B" then
        report[#report + 1] = "blob '" .. uid .. "': ammo_group '" .. tostring(clean.ammo_group)
            .. "' fuera del set permitido, descartado el campo"
        clean.ammo_group = nil
    end

    -- Sub-slots: the DEF's declaration rules. A slot the def does not declare
    -- dies; an item the filter does not accept dies; anything past maxItems is
    -- cut. Nothing is EJECTED here because nothing has been given to anyone
    -- yet — CRG-9 governs destroying an item a player owns, and at this point
    -- the payload owns itself.
    if istable(clean.subslots) then
        local kept = {}
        for slotId, list in pairs(clean.subslots) do
            local spec = CARGO.Items.GetSubSlot(def, slotId)
            if spec == nil then
                report[#report + 1] = "blob '" .. uid .. "': sub-slot '" .. tostring(slotId)
                    .. "' que '" .. blob.id .. "' no declara, descartado"
            else
                local out = {}
                for _, e in ipairs(istable(list) and list or {}) do
                    local subDef = istable(e) and isstring(e.id) and CARGO.Items.Get(e.id) or nil
                    if subDef == nil then
                        report[#report + 1] = "blob '" .. uid .. "' sub-slot '" .. slotId
                            .. "': def desconocida '" .. tostring(istable(e) and e.id) .. "', descartada"
                    elseif not CARGO.Items.MatchesFilter(subDef, spec.filter) then
                        report[#report + 1] = "blob '" .. uid .. "' sub-slot '" .. slotId
                            .. "': '" .. e.id .. "' no pasa el filtro '" .. spec.filter .. "', descartada"
                    elseif #out >= (spec.maxItems or 1) then
                        report[#report + 1] = "blob '" .. uid .. "' sub-slot '" .. slotId
                            .. "': más entradas que maxItems (" .. (spec.maxItems or 1) .. "), recortado"
                    elseif e.uid ~= nil then
                        out[#out + 1] = { id = e.id, uid = e.uid }
                    else
                        local stack = CleanStack(e, report, "blob '" .. uid .. "' sub-slot '" .. slotId .. "'")
                        if stack ~= nil then out[#out + 1] = stack end
                    end
                end
                kept[slotId] = out
            end
        end
        clean.subslots = kept
    end

    return clean
end

-- The whole record. Returns clean, report — clean is nil only when the payload
-- is unusable as a whole; every other failure is a line in the report and a
-- missing entry, which is honest degradation (COR-5), not a rejection.
function CARGO.Lan.SanitizeRecord(raw, allowWallet)
    local report = {}

    raw = Scrub(raw, 0)
    if not istable(raw) then
        return nil, { "el record no es una tabla" }
    end

    -- (1) blobs first, so the entries can be checked against what survived.
    -- Order-independent by construction: the entry pass asks "does this uid
    -- exist in the surviving set", never "did the blob arrive before me".
    local blobs = {}
    for uid, blob in pairs(istable(raw.instances) and raw.instances or {}) do
        local clean = CleanBlob(uid, blob, report)
        if clean ~= nil then blobs[uid] = clean end
    end

    -- (2) a uid may be reachable exactly ONCE across the whole record. Two
    -- entries naming the same blob is the duplication this block exists to
    -- avoid, not a quirk to tolerate — and Remint, called twice on the same
    -- uid, would happily mint it twice.
    local claimed = {}
    local function Claim(uid, where)
        if not isstring(uid) then return false end
        if blobs[uid] == nil then
            report[#report + 1] = where .. ": uid '" .. uid .. "' sin blob en el archivo, descartada"
            return false
        end
        if claimed[uid] then
            report[#report + 1] = where .. ": uid '" .. uid .. "' ya reclamado por otra entrada, descartada"
            return false
        end
        claimed[uid] = true
        -- whatever hangs in its sub-slots is claimed with it, recursively
        local blob = blobs[uid]
        if istable(blob.subslots) then
            for slotId, list in pairs(blob.subslots) do
                for i = #list, 1, -1 do
                    local e = list[i]
                    if istable(e) and e.uid ~= nil
                        and not Claim(e.uid, where .. " sub-slot '" .. slotId .. "'") then
                        table.remove(list, i)
                    end
                end
            end
        end
        return true
    end

    -- (3) grid entries
    local items = {}
    for _, entry in ipairs(istable(raw.items) and raw.items or {}) do
        if not istable(entry) or not isstring(entry.id) then
            report[#report + 1] = "grid: entrada malformada, descartada"
        elseif CARGO.Items.Get(entry.id) == nil then
            report[#report + 1] = "grid: def desconocida '" .. entry.id .. "', descartada"
        elseif entry.uid ~= nil then
            if Claim(entry.uid, "grid '" .. entry.id .. "'") then
                items[#items + 1] = { id = entry.id, uid = entry.uid }
            end
        else
            local stack = CleanStack(entry, report, "grid")
            if stack ~= nil then items[#items + 1] = stack end
        end
    end

    -- (4) equipment. A STACK slot (throwable, §4 amendment) holds an entry
    -- table and every other slot holds a uid — the same branch on istable()
    -- that every rec.equip consumer makes.
    --
    -- An item that does not fit the slot it arrived in FALLS TO THE GRID
    -- instead of dying. That is not leniency, it is the module's own
    -- precedent: ReconcileEquipSlots does exactly this at spawn when a def
    -- stops fitting, and it is the shape CRG-9 asks for — nothing is lost as a
    -- side effect of a rule it failed.
    local equip = {}
    for slotId, val in pairs(istable(raw.equip) and raw.equip or {}) do
        local slot = isstring(slotId) and CARGO.Slots.ById[slotId] or nil
        if slot == nil then
            report[#report + 1] = "equipo: slot desconocido '" .. tostring(slotId) .. "', descartado"
        elseif slot.stack then
            local stack = istable(val) and CleanStack(val, report, "equipo '" .. slotId .. "'") or nil
            if stack == nil then
                if not istable(val) then
                    report[#report + 1] = "equipo '" .. slotId .. "': el slot es de stack y no llegó un stack, descartado"
                end
            elseif not CARGO.Slots.CanEquip(CARGO.Items.Get(stack.id), slotId) then
                report[#report + 1] = "equipo '" .. slotId .. "': '" .. stack.id
                    .. "' no entra en ese slot, va al grid"
                items[#items + 1] = stack
            else
                equip[slotId] = stack
            end
        elseif not isstring(val) then
            report[#report + 1] = "equipo '" .. slotId .. "': se esperaba un uid, descartado"
        elseif Claim(val, "equipo '" .. slotId .. "'") then
            local blob = blobs[val]
            if not CARGO.Slots.CanEquip(CARGO.Items.Get(blob.id), slotId) then
                report[#report + 1] = "equipo '" .. slotId .. "': '" .. blob.id
                    .. "' no entra en ese slot, va al grid"
                items[#items + 1] = { id = blob.id, uid = val }
            else
                equip[slotId] = val
            end
        end
    end

    -- (5) belt. JSON does not preserve key types (COR-8), so the numeric keys
    -- are re-normalised before anything else looks at them.
    local belt = {}
    for n, entry in pairs(CARGO.Util.NumberKeys(raw.belt)) do
        if n < 1 or n > CARGO.Slots.BELT_COUNT or n ~= math.floor(n) then
            report[#report + 1] = "cinturón: slot " .. tostring(n) .. " fuera de rango, descartado"
        else
            local stack = CleanStack(entry, report, "cinturón " .. n)
            local def = stack and CARGO.Items.Get(stack.id) or nil
            if stack == nil then
                -- CleanStack already reported the motive
            elseif not istable(def) or def.category ~= "ammo" then
                report[#report + 1] = "cinturón " .. n .. ": '" .. stack.id
                    .. "' no es munición y el cinturón solo lleva munición, descartada"
            else
                belt[n] = stack
            end
        end
    end

    -- (6) quick binds: ids, not entries
    local quick = {}
    for n, id in pairs(CARGO.Util.NumberKeys(raw.quick)) do
        if n < 1 or n > CARGO.Slots.QUICK_COUNT or n ~= math.floor(n) then
            report[#report + 1] = "quick: slot " .. tostring(n) .. " fuera de rango, descartado"
        elseif not isstring(id) or CARGO.Items.Get(id) == nil then
            report[#report + 1] = "quick " .. n .. ": def desconocida '" .. tostring(id) .. "', descartado"
        else
            quick[n] = id
        end
    end

    -- (7) wallet — only under the native provider on BOTH sides
    local wallet = nil
    if allowWallet and istable(raw.wallet) then
        local usd = raw.wallet.usd
        if isnumber(usd) then
            wallet = { usd = math.Clamp(math.floor(usd), 0, MAX_MONEY) }
            if wallet.usd ~= math.floor(usd) then
                report[#report + 1] = "wallet: saldo fuera de rango, clampeado a " .. wallet.usd
            end
        else
            report[#report + 1] = "wallet: el saldo no es un número, descartado"
        end
    end

    return {
        items = items, equip = equip, belt = belt, quick = quick,
        wallet = wallet, instances = blobs,
    }, report
end

-- ------------------------------------------------------------------
-- APPLY — the record is REPLACED, not merged (author's call 2026-07-26).
--
-- "I am bringing my character" is literal, and replacing is the exact inverse
-- of the export. Merging is the road to infinite duplication: importing twice
-- would double everything and weight would stop meaning anything.
--
-- The destination record is written to a BACKUP file first — one write, before
-- anything is touched, which is the same destination-first ordering as CRG-58,
-- where duplicating is the safe failure mode.
--
-- The teardown is the shape WipeOnDeath already uses for a record that stops
-- having an owner: strip the equipped weapon CLASSES and drop the outgoing
-- blobs from _live. Without it the player keeps the previous record's rifle in
-- his hands and the old blobs leak in the live table for the rest of the map.
-- ------------------------------------------------------------------

local function ApplyRecord(ply, clean)
    local sid = Sid(ply)
    local rec = CARGO.Inventory.GetRecord(ply)

    -- (1) backup. It obeys cargo_persistence: with persistence off NOTHING of
    -- Cargo's reaches disk (planilla P4), and a backup would be the exception
    -- that makes that sentence false.
    local persist = GetConVar("cargo_persistence")
    if persist ~= nil and persist:GetBool() then
        CARGO.Instances.RenderOwner(rec)
        Corpus.Data.Save("cargo", "import_backup_" .. sid, rec)
        Corpus.Log("cargo", "import: el record anterior de " .. sid
            .. " quedó respaldado en import_backup_" .. sid)
    else
        Corpus.Log("cargo", "import: cargo_persistence está en 0 — no se escribe respaldo (nada de Cargo toca el disco en ese modo)")
    end

    -- (2) teardown of what leaves
    for _, val in pairs(rec.equip) do
        local id = istable(val) and val.id or (CARGO.Instances.Get(val) or {}).id
        local def = id and CARGO.Items.Get(id) or nil
        if def and isstring(def.weapon_class) and def.weapon_class ~= "" then
            ply:StripWeapon(def.weapon_class)
        end
    end
    for uid in pairs(CARGO.Inventory.CollectInstances(rec)) do
        CARGO.Instances.Delete(uid)
    end

    -- (3) re-mint. Instances.Remint is the re-uid the entry 46 wrote and the
    -- planilla R confirmed in game: a new uid, recursive through sub-slots,
    -- with the honest degradation of COR-5. Two records from different servers
    -- can carry colliding uids — a uid is unique per BOOT, not globally — so
    -- reusing one is a collision waiting to happen. Writing a SECOND re-mint
    -- here would fabricate exactly the duplication B3 killed with the single
    -- writer, so this reuses it.
    --
    -- Called once per uid-bearing list because Remint answers with a LIST and
    -- drops what fails: mapping old to new by index would be guesswork the
    -- moment one entry drops. The sanitiser already proved every uid is
    -- claimed exactly once, so no blob is minted twice.
    local items = CARGO.Instances.Remint(clean.items, clean.instances)

    local equip = {}
    for slotId, val in pairs(clean.equip) do
        if istable(val) then
            equip[slotId] = val
        else
            local out = CARGO.Instances.Remint({ { id = clean.instances[val].id, uid = val } },
                clean.instances)
            if out[1] ~= nil and out[1].uid ~= nil then
                equip[slotId] = out[1].uid
            else
                Corpus.Log("cargo", "import saneo: equipo '" .. slotId
                    .. "' — el re-acuñado no pudo crear la instancia, descartado")
            end
        end
    end

    -- (4) assignment
    rec.items, rec.equip, rec.quick, rec.belt = items, equip, clean.quick, clean.belt
    if clean.wallet ~= nil then rec.wallet = clean.wallet end

    -- (5) the belt IS the pool (§16). Push assigns the reserve from the NEW
    -- belt; without it the 4 Hz reconciler would read the old engine pool as
    -- truth and drag the previous record's ammunition into the new belt. It
    -- runs BEFORE the weapons arrive, so a gun that asks for its reserve on
    -- deploy finds the imported one and not the previous record's.
    if CARGO.AmmoPool then CARGO.AmmoPool.Push(ply) end

    -- (6) the weapons themselves, through the module's ONE re-give route —
    -- the same `Inventory.RegiveEquipped` the spawn hook runs. Without this a
    -- player who imports while standing there gets a wheel full of weapons he
    -- cannot draw until he next respawns (measured in game, planilla S1). A
    -- dead player is not skipped as an omission: the spawn hook is about to
    -- call this very function for him.
    if ply:Alive() then CARGO.Inventory.RegiveEquipped(ply) end

    -- (7) Save + Sync + movement refresh, the closing move of every mutation
    CARGO.Inventory.Touch(ply)
end

-- ------------------------------------------------------------------
-- IMPORT — the lock, in order, and each layer logs its motive.
-- ------------------------------------------------------------------

local function Whitelisted(sid)
    local raw = cvWhitelist:GetString()
    if not isstring(raw) or string.Trim(raw) == "" then return false end -- empty = NOBODY
    for entry in raw:gmatch("[^%s,]+") do
        if entry == sid then return true end
    end
    return false
end

CARGO.Lan.Whitelisted = Whitelisted

-- The bounded read. It deliberately does NOT go through Util.ReadBlob: that
-- helper is shared by the 21 receivers CRG-6 already protects and has no
-- reason to grow a ceiling. This is the one hostile channel, so it reads the
-- same wire format (UInt(24) length + data, see corpus_cargo_util.lua) and
-- refuses anything oversized BEFORE decompressing.
local function ReadBounded()
    local len = net.ReadUInt(24)
    if not isnumber(len) or len <= 0 then return nil, "el mensaje llegó vacío" end
    if len > MAX_WIRE then
        return nil, "el payload comprimido pesa " .. len .. " bytes y el tope es " .. MAX_WIRE
    end

    local raw = net.ReadData(len)
    local json = util.Decompress(raw)
    if not isstring(json) or json == "" then return nil, "el payload no descomprime" end
    if #json > MAX_JSON then
        return nil, "el payload descomprime a " .. #json .. " bytes y el tope es " .. MAX_JSON
    end

    local tbl = util.JSONToTable(json)
    if not istable(tbl) then return nil, "el payload no es JSON válido" end
    return tbl, nil
end

net.Receive(NET_IMPORT, function(_, ply)
    local sid = Sid(ply)
    local who = (IsValid(ply) and ply:Nick() or "?") .. " (" .. tostring(sid) .. ")"

    -- The MOTIVE goes to the server console in full (§0.bis 4: a rejection
    -- that does not say why is the defect that costs three rounds). The player
    -- gets a short English line — CRG-48 keeps Spanish off the screen, and a
    -- lock has no business narrating its internals to whoever is knocking.
    local function Reject(motive)
        Corpus.Log("cargo", "import RECHAZADO — " .. who .. ": " .. motive)
        if IsValid(ply) then
            CARGO.Inventory.Notice(ply, "Import rejected. The server console says why.")
        end
    end

    -- 1. the door
    if not cvEnabled:GetBool() then
        return Reject("el import está apagado en este servidor (cargo_import_enabled 0)")
    end
    if sid == nil then
        return Reject("sin SteamID64 no hay a quién autorizar")
    end
    -- 2. admin
    if cvAdmin:GetBool() and not ply:IsAdmin() then
        return Reject("hace falta ser admin (cargo_import_admin 1)")
    end
    -- 3. whitelist — empty means nobody, never everybody
    if not Whitelisted(sid) then
        return Reject("el SteamID64 no está en cargo_import_whitelist")
    end
    -- 4. rate limit
    local last = CARGO.Lan._lastImport[sid]
    local wait = cvCooldown:GetInt()
    if last ~= nil and CurTime() - last < wait then
        return Reject("hay que esperar " .. math.ceil(wait - (CurTime() - last)) .. " s entre imports")
    end

    -- 5. only now, the transport
    local payload, err = ReadBounded()
    if payload == nil then return Reject(err) end

    if payload.format ~= CARGO.Lan.FORMAT then
        -- the format number REJECTS, it does not convert (D2: no migrations)
        return Reject("formato " .. tostring(payload.format) .. " y este servidor habla el "
            .. CARGO.Lan.FORMAT .. " — no hay migración, se rechaza")
    end
    if payload.origin ~= sid then
        return Reject("el archivo es del SteamID64 " .. tostring(payload.origin)
            .. " y lo manda " .. sid .. " — un import trae TU personaje, no el de otro")
    end

    -- the signature WARNS, it does not gate: what protects the destination is
    -- the per-entry sanitising below
    for _, line in ipairs(CARGO.Lan.SignatureDiff(payload.signature, CARGO.Lan.Signature())) do
        Corpus.Log("cargo", "import AVISO — " .. who .. ": " .. line)
    end

    local _, provider = CARGO.Money.Active()
    local allowWallet = provider == "usd" and payload.money_provider == "usd"
    if not allowWallet and istable(payload.record) and payload.record.wallet ~= nil then
        Corpus.Log("cargo", "import: el wallet NO viaja — provider de origen '"
            .. tostring(payload.money_provider) .. "', de destino '" .. tostring(provider)
            .. "'; solo viaja con el nativo en ambos lados")
    end

    local clean, report = CARGO.Lan.SanitizeRecord(payload.record, allowWallet)
    if clean == nil then
        return Reject(report[1] or "el record no se pudo sanear")
    end

    for _, line in ipairs(report) do
        Corpus.Log("cargo", "import saneo — " .. who .. ": " .. line)
    end

    ApplyRecord(ply, clean)
    CARGO.Lan._lastImport[sid] = CurTime()

    Corpus.Log("cargo", "import ACEPTADO — " .. who .. ": " .. #clean.items
        .. " entrada(s) de grid, " .. table.Count(clean.equip) .. " equipada(s), "
        .. #report .. " descarte(s) de saneo")
    CARGO.Inventory.Notice(ply, ply:Alive() and "Character imported."
        or "Character imported. Equipped weapons return on your next respawn.")
end)

-- ------------------------------------------------------------------
-- Console. No admin gate on the EXPORT: it writes a file out of the caller's
-- own record and reads nothing hostile — same standing as the rest of the kit
-- (CRG-45, still waiting on the Corpus permissions primitive).
-- ------------------------------------------------------------------

concommand.Add("cargo_export", function(ply, _, args)
    local key, err = CARGO.Lan.Export(ply, istable(args) and args[1] or nil)
    if key == nil then
        Corpus.Log("cargo", "export: " .. tostring(err))
        return
    end
    Corpus.Log("cargo", "export: record escrito en data/corpus/cargo/" .. key
        .. ".json — para traerlo a otro servidor: cargo_import "
        .. (istable(args) and args[1] or ""))
end, nil, "Writes your character record to data/corpus/cargo/export_<steamid64>.json so it can be carried to another server. Optional argument: a file name")

end -- SERVER

-- ------------------------------------------------------------------
-- CLIENT — it owns nothing. It reads its own file and sends it; every
-- decision about that file is taken on the server.
-- ------------------------------------------------------------------

if CLIENT then

concommand.Add("cargo_import", function(_, _, args)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local name = istable(args) and args[1] or nil
    local key = "export_" .. ((isstring(name) and name:match("^[%w_%-]+$")) and name:lower()
        or tostring(ply:SteamID64()))

    local payload = Corpus.Data.Load("cargo", key)
    if not istable(payload) then
        Corpus.Log("cargo", "import: no existe data/corpus/cargo/" .. key
            .. ".json en tu máquina — corré cargo_export en el servidor donde vive tu personaje")
        return
    end

    Corpus.Log("cargo", "import: mandando " .. key .. ".json al servidor (formato "
        .. tostring(payload.format) .. ")")
    net.Start(NET_IMPORT)
    CARGO.Util.WriteBlob(payload)
    net.SendToServer()
end, nil, "Sends a character record exported with cargo_export to this server. Optional argument: the file name. The server decides whether to accept it")

end -- CLIENT
