-- corpus_cargo_arc9.lua — ARC9 attachment bridge (SHARED, realm-guarded)
-- Cargo_Architecture.md §10. External mod integration: ARC9 is DETECTED at
-- ready time, never assumed (dev/mods_workshop_mapa.md: COMPAT-RUNTIME).
--
-- Every API name below was VERIFIED against the live code of ARC9 base +
-- Darsu's EFT pack (dev/other/, 2026-07-10) — this project does not trust
-- ARC9 names from memory:
--   * Inventory store: ply.ARC9_AttInv, gated by three overridable hooks in
--     lua/arc9/shared/sh_attinv.lua — ARC9_PlayerGetAtts (:23, return a
--     number to override), ARC9_PlayerGiveAtt (:48) and ARC9_PlayerTakeAtt
--     (:75) (return non-nil to cancel ARC9's internal store).
--   * ARC9 normalizes variant names to atttbl.InvAtt BEFORE running those
--     hooks; only canonical names reach us.
--   * arc9_free_atts (default 1!) short-circuits PlayerGetAtts to 999
--     before the hook — the bridge REQUIRES it at 0.
--   * Install/remove: SWEP:Attach(addr, att, silent) /
--     SWEP:DetachAllFromSubSlot(addr, silent) (sh_attach.lua:5/:57), meant
--     to run CLIENT-side; they replicate via SendWeapon -> net
--     "arc9_networkweapon" -> SWEP:ReceiveWeapon (server), which validates
--     against PlayerGetAtts and fires the Give/Take hooks. There is NO
--     attach/detach gamemode hook — inventory hooks ARE the reconciliation
--     channel (§10.3: ARC9 owns the mounted state, Cargo owns the storage).
--   * Stats read-only via SWEP:GetProcessedValue(key) — real keys are
--     "DamageMax"/"DamageMin", "Spread", "RPM", "ClipSize" (there is no
--     "Damage"/"Accuracy"/"Handling").

local CARGO = Corpus.GetModule("cargo")

CARGO.ARC9 = CARGO.ARC9 or {}

local ITEM_PREFIX = "arc9_" -- Cargo item id = "arc9_" .. shortname

local cvBridge = CreateConVar("cargo_arc9_bridge", "1",
    bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
    "Cargo <-> ARC9 inventory bridge (0 disables the hooks)")

if SERVER then
    CreateConVar("cargo_arc9_takeover", "1", FCVAR_ARCHIVE,
        "Force arc9_free_atts 0 on boot so Cargo becomes the attachment store")
end

function CARGO.ARC9.Available()
    return ARC9 ~= nil and cvBridge:GetBool()
end

function CARGO.ARC9.ItemId(shortname) return ITEM_PREFIX .. shortname end

function CARGO.ARC9.Shortname(itemId)
    if not isstring(itemId) or itemId:sub(1, #ITEM_PREFIX) ~= ITEM_PREFIX then return nil end
    return itemId:sub(#ITEM_PREFIX + 1)
end

-- ------------------------------------------------------------------
-- Item auto-registration (both realms — the client grid needs the defs).
-- Single source of truth (§10.3): ARC9's own att inventory is bridged out;
-- Cargo becomes the store, ARC9 keeps the mounted state and the stat math.
-- ------------------------------------------------------------------

local function RegisterAttachmentItems()
    local count = 0
    for shortname, atttbl in pairs(ARC9.Attachments or {}) do
        -- variants (InvAtt) collapse into their canonical item; Free atts
        -- are outside any economy; hidden/menu entries carry no PrintName
        if not atttbl.Free and not atttbl.InvAtt and atttbl.PrintName then
            CARGO.Items.Register({
                id = CARGO.ARC9.ItemId(shortname),
                name = atttbl.PrintName,
                -- ARC9 atts declare no mass; flat nominal weight until some
                -- pack exposes one
                weight = 0.3,
                -- flat base price (author call 2026-07-24): the packs declare
                -- no economy and mods flood the grid — one starting number
                -- makes the whole family sellable, tuned in play like the
                -- weapon tables (Cargo_Trade §11)
                value = 100,
                class = "stackable",
                category = "attachments",
                icon = atttbl.Icon, -- Material object; the cell painter accepts it
                trivia = isstring(atttbl.Description) and atttbl.Description or nil,
                arc9_att = shortname,
            })
            count = count + 1
        end
    end
    Corpus.Log("cargo", "puente ARC9: " .. count .. " attachments registrados como ítems")
end

-- ------------------------------------------------------------------
-- Inventory hooks — the verified reconciliation channel. Whether the
-- player uses Cargo's UI or ARC9's own C menu, install consumes from
-- Cargo (Take) and uninstall returns to Cargo (Give). No drift, no
-- double inventory.
-- ------------------------------------------------------------------

local function WireHooks()
    hook.Add("ARC9_PlayerGetAtts", "corpus_cargo_arc9", function(ply, att, wep)
        if not CARGO.ARC9.Available() then return end
        local itemId = CARGO.ARC9.ItemId(att)
        if CARGO.Items.Get(itemId) == nil then return end -- not bridged (Free etc.)

        if SERVER then
            return CARGO.Inventory.CountItem(ply, itemId)
        end
        -- client: count against the last synced snapshot (the ARC9 menu
        -- calls this to paint availability)
        local snap = CARGO.ClientState
        if not istable(snap) or not istable(snap.items) then return 0 end
        local n = 0
        for _, entry in ipairs(snap.items) do
            if entry.id == itemId and entry.uid == nil then n = n + (entry.count or 1) end
        end
        return n
    end)

    if CLIENT then return end

    hook.Add("ARC9_PlayerGiveAtt", "corpus_cargo_arc9", function(ply, att, amt)
        if not CARGO.ARC9.Available() then return end
        local itemId = CARGO.ARC9.ItemId(att)
        if CARGO.Items.Get(itemId) == nil then return end

        CARGO.Inventory.GiveItem(ply, itemId, amt or 1)
        return true -- suppress ARC9's internal store
    end)

    hook.Add("ARC9_PlayerTakeAtt", "corpus_cargo_arc9", function(ply, att, amt)
        if not CARGO.ARC9.Available() then return end
        local itemId = CARGO.ARC9.ItemId(att)
        if CARGO.Items.Get(itemId) == nil then return end

        -- ReceiveWeapon validated availability through PlayerGetAtts before
        -- firing this; clamp defensively anyway
        CARGO.Inventory.TakeItem(ply, itemId,
            math.min(amt or 1, CARGO.Inventory.CountItem(ply, itemId)))
        return true
    end)
end

Corpus.OnReady(function()
    if ARC9 == nil then
        Corpus.Log("cargo", "ARC9 no montado — puente de attachments inactivo")
        return
    end
    if not cvBridge:GetBool() then
        Corpus.Log("cargo", "puente ARC9 desactivado por convar cargo_arc9_bridge")
        return
    end

    RegisterAttachmentItems()
    WireHooks()

    if SERVER then
        -- arc9_free_atts=1 (its default) makes every att count read as 999
        -- BEFORE our hook runs: the bridge would be dead code. Single-source
        -- decision (§10.3) defaults to taking over; opt out via
        -- cargo_arc9_takeover 0.
        local freeAtts = GetConVar("arc9_free_atts")
        if freeAtts and freeAtts:GetBool() then
            if GetConVar("cargo_arc9_takeover"):GetBool() then
                RunConsoleCommand("arc9_free_atts", "0")
                Corpus.Log("cargo", "puente ARC9: arc9_free_atts forzado a 0 (Cargo es el almacén)")
            else
                Corpus.Log("cargo", "AVISO puente ARC9: arc9_free_atts=1 — el inventario de attachments es cosmético hasta ponerlo en 0")
            end
        end
    end
end)

-- ------------------------------------------------------------------
-- CLIENT helpers for the UI flows (§10.2): "Acoplar a..." context menu and
-- drag&drop both end here. v1 scope: attach targets are the WEAPONS THE
-- PLAYER IS HOLDING (a SWEP instance is required for slot addresses and
-- GetProcessedValue); weapons stored in the grid have no entity to mutate.
-- ------------------------------------------------------------------

if CLIENT then

    -- capability probe, not a flag: any SWEP with the two verified surfaces
    local function IsArc9Weapon(wep)
        return IsValid(wep) and isfunction(wep.GetProcessedValue)
            and istable(wep.Attachments)
    end

    function CARGO.ARC9.HeldWeapons()
        local out = {}
        local ply = LocalPlayer()
        if not IsValid(ply) then return out end
        for _, wep in ipairs(ply:GetWeapons()) do
            if IsArc9Weapon(wep) then out[#out + 1] = wep end
        end
        return out
    end

    -- Targets an attachment item can mount on: every free, compatible,
    -- addressed top-level slot of every held ARC9 weapon. (Nested
    -- SubAttachments slots: not walked in v1.)
    function CARGO.ARC9.CompatibleTargets(itemId)
        local out = {}
        local shortname = CARGO.ARC9.Shortname(itemId)
        if shortname == nil or not CARGO.ARC9.Available() then return out end

        for _, wep in ipairs(CARGO.ARC9.HeldWeapons()) do
            for _, slot in pairs(wep.Attachments) do
                if istable(slot) and slot.Address and not slot.Installed then
                    local ok, can = pcall(wep.CanAttach, wep, slot.Address, shortname, slot, true)
                    if ok and can then
                        out[#out + 1] = {
                            wep = wep,
                            addr = slot.Address,
                            label = (wep.PrintName or wep:GetClass()) .. " — "
                                .. (slot.PrintName or ("slot " .. tostring(slot.Address))),
                        }
                    end
                end
            end
        end
        return out
    end

    -- Canonical client-side path: Attach replicates itself (PostModify ->
    -- SendWeapon -> server ReceiveWeapon -> Take hook -> Cargo discounts).
    function CARGO.ARC9.Attach(wep, addr, itemId)
        local shortname = CARGO.ARC9.Shortname(itemId)
        if shortname == nil or not IsArc9Weapon(wep) then return false end
        local ok, res = pcall(wep.Attach, wep, addr, shortname)
        return ok and res == true
    end

    function CARGO.ARC9.Installed(wep)
        local out = {}
        if not IsArc9Weapon(wep) then return out end
        for _, slot in pairs(wep.Attachments) do
            if istable(slot) and slot.Address and isstring(slot.Installed) then
                local atttbl = ARC9.Attachments and ARC9.Attachments[slot.Installed]
                out[#out + 1] = {
                    addr = slot.Address,
                    shortname = slot.Installed,
                    name = (atttbl and atttbl.PrintName) or slot.Installed,
                    integral = slot.Integral ~= nil and slot.Integral ~= false,
                }
            end
        end
        return out
    end

    function CARGO.ARC9.Detach(wep, addr)
        if not IsArc9Weapon(wep) then return false end
        local ok, res = pcall(wep.DetachAllFromSubSlot, wep, addr)
        return ok and res ~= false
    end

    -- Read-only stat rows for the tooltip (§9 route 1). Absolute values —
    -- the manual display_stats route renders deltas, this one renders what
    -- ARC9 reports; both feed the same visual rows.
    function CARGO.ARC9.WeaponStats(wep)
        if not IsArc9Weapon(wep) then return nil end
        local rows = {}
        local function push(label, key, fmt)
            local ok, v = pcall(wep.GetProcessedValue, wep, key)
            if ok and isnumber(v) then
                rows[#rows + 1] = { label = label, value = string.format(fmt or "%g", v) }
            end
        end
        push("Damage", "DamageMax")
        push("Min damage", "DamageMin")
        push("Spread", "Spread", "%.4f")
        push("Fire rate", "RPM", "%d RPM")
        push("Mag size", "ClipSize", "%d")
        return rows
    end

end
