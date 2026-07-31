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
-- blob.atts — OUR attachment tree (roadmap #53, B1). Pure, flat and ours.
--
-- Why ours and not ARC9's: its own serializer (WriteAttachmentTree,
-- cl_presets.lua) is client-only, and the slot tables it walks carry
-- Material(), Vector, Angle and cyclic references — which is exactly what
-- breaks gm_save (§13, measured in planilla R) and what the offline guard
-- rejects. Nothing here ever COPIES a slot table: it reads three fields off
-- it (Category, Installed, ToggleNum) and recurses. Strings and integers only,
-- by construction rather than by filtering afterwards.
--
-- The key is (cat, nth) and NOT the slot position — CRG-63. The position is
-- doubly unstable: a pack that inserts a slot shifts every later index, and
-- ARC9's own addresses are the offsets of a RECURSIVE FLATTEN of the current
-- build (BuildSubAttachments resets SubAttachments and rebuilds them only for
-- what is Installed, sh_subatts.lua:211-238), so they move WITHIN a session as
-- the player builds the gun. Measured on the author's AS VAL: the PEQ-2 sat at
-- address 11 only because the siderail at 10 was mounted.
--
-- `nth` exists because siblings share categories: the mod4 handguard declares
-- TWO slots taking "eft_valmod4_side" (eft_cat_mount_r and its twin), so the
-- shortname alone is not a key. PrintName is NOT a candidate: ARC9:GetPhrase
-- already localized it, so it changes with the language.
--
-- Verified against dev/other/Arc9 Base + EFT Assault Rifles, 2026-07-30
-- (CRG-24). All names below were read from that source, none from memory.
-- ------------------------------------------------------------------

-- A slot declares Category as a STRING or as a TABLE of strings — both shapes
-- live in the same handguard (eft_valmod4_top vs {eft_optic_small, ...}).
-- Sorted so a pack reordering its own list does not invalidate a saved tree,
-- and string-filtered so nothing but text can reach the blob.
function CARGO.ARC9.SlotCategory(slot)
    if not istable(slot) then return "" end
    local c = slot.Category
    if isstring(c) then return c end
    if not istable(c) then return "" end

    local parts = {}
    for _, v in ipairs(c) do
        if isstring(v) then parts[#parts + 1] = v end
    end
    table.sort(parts)
    return table.concat(parts, "+")
end

-- Walks the LIVE slot tree of a weapon entity. `nth` counts every sibling slot
-- of that category, occupied or not, in declaration order — the resolver counts
-- the same way, and that is what makes the pair a key.
local function HarvestLevel(slots)
    local out, seen = {}, {}
    for _, slot in ipairs(slots or {}) do
        if istable(slot) then
            local cat = CARGO.ARC9.SlotCategory(slot)
            seen[cat] = (seen[cat] or 0) + 1

            -- Installed is a string when mounted, `false` when ARC9 pruned it
            -- and nil when it never held anything
            if isstring(slot.Installed) and slot.Installed ~= "" then
                local node = { cat = cat, att = slot.Installed }
                if seen[cat] > 1 then node.nth = seen[cat] end

                local mode = tonumber(slot.ToggleNum)
                if mode and mode > 1 then node.mode = math.floor(mode) end

                local sub = HarvestLevel(slot.SubAttachments)
                if #sub > 0 then node.sub = sub end

                out[#out + 1] = node
            end
        end
    end
    return out
end

function CARGO.ARC9.HarvestTree(wep)
    if not IsValid(wep) or not istable(wep.Attachments) then return nil end
    local tree = HarvestLevel(wep.Attachments)
    if #tree == 0 then return nil end -- a bare gun stores no field at all
    return tree
end

-- A branch that could not be placed, routed node by node: what ARC9 still
-- knows comes back as an item, what it does not is dropped with a log.
--
-- The routing is PER NODE and not per branch, which is the whole point: a
-- parent whose att the pack deleted takes its slot with it, but its children
-- may be perfectly ordinary scopes and lights. Sending them to the discard
-- pile because of the parent is exactly the collateral loss CRG-9 forbids.
local function CollectLost(nodes, orphans, unknown)
    local reg = istable(ARC9) and ARC9.Attachments or nil
    for _, n in ipairs(nodes or {}) do
        if istable(n) and isstring(n.att) then
            local bucket = (reg ~= nil and reg[n.att] ~= nil) and orphans or unknown
            bucket[n.att] = (bucket[n.att] or 0) + 1
            CollectLost(n.sub, orphans, unknown)
        end
    end
end

-- Resolve blob.atts against a LIVE weapon into the dense positional array that
-- BuildSubAttachments consumes.
--
-- The iteration is over the WEAPON's slots, never over our stored list, and
-- that is the whole design: BuildSubAttachments walks its input with ipairs
-- (a hole ends the walk) and, worse, bails with `return` on the first
-- misalignment — losing the WHOLE tree, not the bad entry. Building the array
-- from the live slots makes it dense and aligned by construction; there is no
-- code path that can emit an invalid one.
--
-- Child slots come from the attachment's own declaration
-- (ARC9.GetAttTable(att).Attachments), which is where the mod takes them from
-- too (WriteAttachmentTree, cl_presets.lua:26-32).
--
-- Returns tree, orphans, unknown:
--   tree    -> for BuildSubAttachments
--   orphans -> { [shortname] = count } that found no slot; the caller gives
--              them back as items (CRG-9 / CRG-65: nothing is lost)
--   unknown -> { [shortname] = count } no longer in ARC9.Attachments; these
--              CANNOT come back as items (our def ids derive from that table),
--              so they are dropped and the caller logs it
local function ResolveLevel(nodes, slots, orphans, unknown)
    local byKey, used = {}, {}
    for i, n in ipairs(nodes or {}) do
        if istable(n) and isstring(n.cat) and isstring(n.att) then
            byKey[n.cat .. "\0" .. (tonumber(n.nth) or 1)] = i
        end
    end

    local reg = istable(ARC9) and ARC9.Attachments or nil
    local out, seen = {}, {}
    for i, slot in ipairs(slots or {}) do
        local cat = CARGO.ARC9.SlotCategory(slot)
        seen[cat] = (seen[cat] or 0) + 1

        local idx = byKey[cat .. "\0" .. seen[cat]]
        local node = idx and nodes[idx] or nil
        local placed = false

        if node ~= nil then
            used[idx] = true
            local atttbl = reg ~= nil and reg[node.att] or nil
            if atttbl ~= nil then
                placed = true
                local entry = { Installed = node.att, ToggleNum = node.mode or 1 }
                if istable(atttbl.Attachments) then
                    entry.SubAttachments =
                        ResolveLevel(node.sub, atttbl.Attachments, orphans, unknown)
                end
                out[i] = entry
            else
                -- the att is gone from the pack: it cannot come back as an
                -- item (our def ids derive from that table), but its children
                -- are judged on their own
                unknown[node.att] = (unknown[node.att] or 0) + 1
                CollectLost(node.sub, orphans, unknown)
            end
        end

        if not placed then out[i] = {} end -- explicit hole: the array stays dense
    end

    -- whatever never found a slot goes back to the player, branch and all
    for i, n in ipairs(nodes or {}) do
        if not used[i] then CollectLost({ n }, orphans, unknown) end
    end

    return out
end

-- ARC9's own preset restore fights the blob, and it fights it EXPENSIVELY
-- (roadmap #53, B4). On the client, 0.075 s after a new entity's first Think,
-- sh_think.lua:208-223 loads the "autosave" preset (arc9_autosave, default 1)
-- and sends it up; the server validates it against the store — which is us —
-- and the diff in sh_net.lua:90-122 then CHARGES the grid for whatever the
-- preset mounted. That is the "it came back with the flashlight and a spare
-- vanished" the author reported: it was never persistence, it was a per-CLASS
-- preset paid for with items.
--
-- SetNoPresets is a NetworkVar of the mod itself (shared.lua:1632) and is what
-- ARC9 uses for its own NPC weapons (sv_npc.lua:226) — no API is being
-- invented here. Set server-side, it replicates before the client's window.
--
-- UNCONDITIONAL on purpose, even for a bare gun: a weapon with no blob.atts is
-- exactly the one the autosave would dress up on the grid's tab.
--
-- Declared contracara: this also kills LoadPreset("default"), so a Cargo weapon
-- is born with the build its SWEP declares and nothing else. The C menu presets
-- keep working BY HAND — that is an ordinary attach, and it consumes from the
-- grid like any other.
function CARGO.ARC9.TakeOverPresets(wep)
    if not IsValid(wep) or not CARGO.ARC9.Available() then return end
    -- detection, never assumption (COR-5): a non-ARC9 SWEP has no such method
    if not isfunction(wep.SetNoPresets) then return end
    wep:SetNoPresets(true)
end

function CARGO.ARC9.ResolveTree(atts, wep)
    if not istable(atts) or not IsValid(wep) or not istable(wep.Attachments) then
        return nil, {}, {}
    end
    local orphans, unknown = {}, {}
    local tree = ResolveLevel(atts, wep.Attachments, orphans, unknown)
    return tree, orphans, unknown
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

    -- CRG-65: ARC9 has ALREADY pulled the attachment out of the weapon by the
    -- time this fires, and returning true tells it not to keep a copy — so a
    -- give that silently fails destroys the part. It did: GiveItem refuses on
    -- weight (inventory.lua, "too heavy") and this hook ignored the return
    -- (roadmap #53, second leak). Author call 2026-07-30: it falls to the
    -- floor, as its own item entity. Returning true stays correct either way —
    -- the object exists, here or at the player's feet.
    hook.Add("ARC9_PlayerGiveAtt", "corpus_cargo_arc9", function(ply, att, amt)
        if not CARGO.ARC9.Available() then return end
        local itemId = CARGO.ARC9.ItemId(att)
        if CARGO.Items.Get(itemId) == nil then return end

        local ok, toFloor = CARGO.Inventory.GiveOrDrop(ply, itemId, amt or 1)
        if not ok then return end -- nothing was stored: let ARC9 keep it
        if toFloor then
            CARGO.Inventory.Notice(ply, "No room — it dropped at your feet.")
        end
        -- the gun in your hands just lost a part: the blob has to follow it,
        -- or weight and price stay at whatever it said last time it was
        -- stored (planilla AB, AB8)
        CARGO.Inventory.SyncAttsSoon(ply)
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
        -- ...and the same when it GAINS one (AB8)
        CARGO.Inventory.SyncAttsSoon(ply)
        return true
    end)
end

-- Internal, for the offline harness only (same precedent as Corpus._SelfTest):
-- WireHooks runs inside OnReady, and there ARC9 is nil offline, so without a
-- way to wire them a test can only call the bridge's functions DIRECTLY —
-- which proves the function works and says nothing about whether the hook
-- calls it. Found by reverting: pulling the calls out of the hooks left the
-- whole harness green.
CARGO.ARC9._WireHooks = WireHooks

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
