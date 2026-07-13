-- corpus_cargo_ammopool.lua — the ammo belt IS the reserve pool (SERVER)
-- Cargo_Architecture.md §16 (roadmap #19). Companion of shared/corpus_cargo_ammo.lua.
--
-- INVARIANT, for every engine ammo type Cargo manages:
--     ply:GetAmmoCount(type)  ==  sum of the belt stacks of that type
--
-- Both directions are real:
--   belt -> pool   Push(): hanging a stack on the belt IS loading your reserve.
--   pool -> belt   Reconcile(): the pool is the TRUTH of consumption. Reloading
--                  drains it into a magazine, unloading feeds it back (ARC9's
--                  Unload does GiveAmmo(Clip1) — sh_reload.lua:201, verified),
--                  grenades and rockets spend it directly. The belt follows, so
--                  the count on the belt cell is the real count.
--
-- WHY A POLL AND NOT HOOKS: the pool is mutated by whatever weapon base the
-- player happens to be holding (ARC9, HL2, TFA, anything). Polling
-- GetAmmoCount is base-agnostic and costs eleven integer reads per player per
-- tick — this is the "detección, nunca asunción" contract priced honestly. No
-- ARC9 hook is required for the pool to work at all.
--
-- THE ETHER — the blocker this block exists to kill. Author, in-game
-- 2026-07-12: "la munición no puede aparecer del éter". ARC9 hands out FREE
-- RESERVE every time a weapon is given: SWEP:InitialDefaultClip (Arc9 Base
-- sh_deploy.lua:130-146) calls ply:GiveAmmo(ClipSize * arc9_mult_defaultammo),
-- fired by a timer.Simple(0.4) from its Initialize (sh_init.lua:80-86). We
-- force that convar to 0 (its default is 2) — the same takeover the attachment
-- bridge already does for arc9_free_atts.
--
-- That neutralisation is COMPLETE for the five installed ARC9 packs (grepped
-- 2026-07-12: no weapon overrides it with a non-zero SWEP.ForceDefaultAmmo —
-- only the EFT grenades set it, and they set 0). It is NOT airtight BY
-- CONSTRUCTION: ForceDefaultAmmo bypasses the convar entirely
-- (sh_deploy.lua:140), so a future pack could reopen the hole. The escalation
-- on record, if the author ever sees ammo appear in game, is a conservation
-- ledger (pool + magazines must balance; any surplus with no magazine to
-- explain it is ether and gets clamped).
--
-- Belt and braces meanwhile: the reconciler stays SUPPRESSED for a player until
-- their spawn Push has run, so nothing a weapon gifts during the spawn window
-- can be laundered into the belt by the mirror.

local CARGO = Corpus.GetModule("cargo")

CARGO.AmmoPool = CARGO.AmmoPool or {}

local cvPool = CreateConVar("cargo_ammo_pool", "1", FCVAR_ARCHIVE,
    "The ammo belt IS the player's real reserve (0 = belt is inert storage, engine pool untouched)")
local cvTakeover = CreateConVar("cargo_ammo_arc9_takeover", "1", FCVAR_ARCHIVE,
    "Force arc9_mult_defaultammo 0 on boot so ARC9 stops gifting free reserve ammo")
local cvWorldAmmo = CreateConVar("cargo_ammo_world_pickup", "1", FCVAR_ARCHIVE,
    "Map ammo pickups (item_ammo_*) become Cargo items in the grid instead of raw pool")

-- Players whose spawn Push has not run yet. Reconcile mirrors nothing for them:
-- during the spawn window a weapon base may still be gifting reserve, and the
-- mirror must not launder it into the belt (see header).
local ready = {}

-- ------------------------------------------------------------------
-- Belt <-> pool
-- ------------------------------------------------------------------

local function BeltTotals(rec)
    local totals = {}
    for _, entry in pairs(rec.belt or {}) do
        local hl2 = CARGO.Ammo.TypeOfDef(CARGO.Items.Get(entry.id))
        if hl2 ~= nil then
            totals[hl2] = (totals[hl2] or 0) + (entry.count or 1)
        end
    end
    return totals
end

CARGO.AmmoPool.BeltTotals = BeltTotals

-- belt -> pool. SetAmmo and never GiveAmmo: the pool is assigned, not added to,
-- so pushing twice cannot drift it upward.
function CARGO.AmmoPool.Push(ply)
    if not cvPool:GetBool() then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local totals = BeltTotals(CARGO.Inventory.GetRecord(ply))
    for _, hl2 in ipairs(CARGO.Ammo.TYPES) do
        ply:SetAmmo(totals[hl2] or 0, hl2)
    end
end

-- Only the types Cargo manages: another addon's custom ammo is not ours to zero.
function CARGO.AmmoPool.Clear(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    for _, hl2 in ipairs(CARGO.Ammo.TYPES) do
        ply:SetAmmo(0, hl2)
    end
end

-- Drain order is belt slot order (1..6): predictable, and it is the order the
-- player chose himself when he hung the stacks.
local function DrainType(rec, hl2, amount)
    for n = 1, CARGO.Slots.BELT_COUNT do
        if amount <= 0 then break end
        local entry = rec.belt[n]
        if entry ~= nil and CARGO.Ammo.TypeOfDef(CARGO.Items.Get(entry.id)) == hl2 then
            local take = math.min(entry.count or 1, amount)
            entry.count = (entry.count or 1) - take
            amount = amount - take
            if entry.count <= 0 then rec.belt[n] = nil end
        end
    end
end

-- Rounds coming back OUT of a magazine have to land somewhere. Top up the
-- canonical stacks already on the belt, then spill into free belt slots.
-- Returns what still did not fit — the caller sends that to the grid rather
-- than destroying it.
local function AbsorbType(rec, hl2, amount)
    local itemId = CARGO.Ammo.ItemForType(hl2)
    local def = itemId and CARGO.Items.Get(itemId) or nil
    if def == nil then return amount end
    local maxStack = def.max_stack or math.huge

    -- Merged into the CANONICAL item only, never into some other stack that
    -- merely shares the engine type: an unloaded magazine says nothing about
    -- which variant was in it, and merging would silently retype the rounds.
    -- (condition stays nil on ammo — the anti-laundering rule of §5 holds.)
    for n = 1, CARGO.Slots.BELT_COUNT do
        if amount <= 0 then break end
        local entry = rec.belt[n]
        if entry ~= nil and entry.id == itemId and entry.condition == nil then
            local put = math.min(maxStack - (entry.count or 1), amount)
            if put > 0 then
                entry.count = (entry.count or 1) + put
                amount = amount - put
            end
        end
    end

    for n = 1, CARGO.Slots.BELT_COUNT do
        if amount <= 0 then break end
        if rec.belt[n] == nil then
            local put = math.min(maxStack, amount)
            rec.belt[n] = { id = itemId, count = put }
            amount = amount - put
        end
    end

    return amount
end

-- ------------------------------------------------------------------
-- The mirror
-- ------------------------------------------------------------------

function CARGO.AmmoPool.Reconcile(ply)
    if not cvPool:GetBool() then return end
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    if not ready[ply] then return end

    local rec = CARGO.Inventory.GetRecord(ply)
    local totals = BeltTotals(rec)
    local dirty = false

    for _, hl2 in ipairs(CARGO.Ammo.TYPES) do
        local pool = ply:GetAmmoCount(hl2)
        local belt = totals[hl2] or 0

        if pool < belt then
            -- spent: loaded into a magazine, thrown, or fired straight from reserve
            DrainType(rec, hl2, belt - pool)
            dirty = true

        elseif pool > belt then
            -- returned: a magazine was unloaded back into the reserve
            local left = AbsorbType(rec, hl2, pool - belt)

            if left > 0 then
                -- Belt is full. The rounds are NOT destroyed — they go to the
                -- grid, which is what the grid is for.
                local itemId = CARGO.Ammo.ItemForType(hl2)
                local ok = itemId and CARGO.Inventory.GiveItem(ply, itemId, left) or false
                if not ok then
                    -- nowhere left to carry them: the pool cannot hold rounds
                    -- the player has no room for, or the belt count would lie
                    ply:SetAmmo(pool - left, hl2)
                    CARGO.Inventory.Notice(ply, "You cannot carry any more ammunition.")
                end
            end
            dirty = true
        end
    end

    if dirty then CARGO.Inventory.Touch(ply) end
end

-- 4 Hz. The pool only MOVES on reload / unload / grenade throw, so `dirty` is
-- rare and the Touch (save + sync) it triggers is rarer still — firing does not
-- touch the reserve, it drains the magazine.
timer.Create("corpus_cargo_ammopool", 0.25, 0, function()
    if not cvPool:GetBool() then return end
    for _, ply in ipairs(player.GetAll()) do
        CARGO.AmmoPool.Reconcile(ply)
    end
end)

-- ------------------------------------------------------------------
-- Lifecycle: the native pool does not persist, the belt does
-- ------------------------------------------------------------------

-- On every spawn the reserve is rebuilt from the belt AND FROM NOTHING ELSE:
-- StripAmmo first, so whatever the gamemode loadout or a weapon base handed out
-- during the spawn window dies right here. Deferred past ARC9's own 0.4 s gift
-- timer (sh_init.lua:80-86) so we land after it, not in a race with it.
hook.Add("PlayerLoadout", "corpus_cargo_ammopool_spawn", function(ply)
    if not cvPool:GetBool() then return end
    ready[ply] = nil

    timer.Simple(0.5, function()
        if not IsValid(ply) then return end
        ply:StripAmmo()
        CARGO.AmmoPool.Push(ply)
        ready[ply] = true
        CARGO.Inventory.Sync(ply)
    end)
end)

hook.Add("PlayerDisconnected", "corpus_cargo_ammopool_clean", function(ply)
    ready[ply] = nil
end)

-- ------------------------------------------------------------------
-- Ammo lying in the world -> a Cargo item in the GRID (author call)
--
-- "El grid es el almacén, el cinturón es el pool": you find ammo, you store it,
-- and you decide how much of it to hang on your belt. It never becomes raw
-- reserve behind your back. Amounts are HL2's own (hl2/item_ammo.cpp defaults).
--
-- Declared debt: ARC9's own pickup entities (arc9_ammo / arc9_ammo_big) give
-- ammo through their own Touch, not through PlayerCanPickupItem, so they still
-- land in the pool and the mirror absorbs them onto the BELT rather than the
-- grid. Not ether — the rounds are real and accounted for — but it skips the
-- grid. They are sandbox-spawned props, so this is left as debt, not patched
-- blind.
-- ------------------------------------------------------------------

local WORLD_AMMO = {
    item_ammo_pistol       = { "Pistol",       20 },
    item_ammo_pistol_large = { "Pistol",      100 },
    item_ammo_smg1         = { "SMG1",         45 },
    item_ammo_smg1_large   = { "SMG1",        225 },
    item_ammo_ar2          = { "AR2",          20 },
    item_ammo_ar2_large    = { "AR2",         100 },
    item_box_buckshot      = { "Buckshot",     20 },
    item_ammo_357          = { "357",           6 },
    item_ammo_357_large    = { "357",          12 },
    item_ammo_crossbow     = { "XBowBolt",      6 },
    item_rpg_round         = { "RPG_Round",     1 },
    item_ammo_smg1_grenade = { "SMG1_Grenade",  1 },
    item_ammo_ar2_altfire  = { "AR2AltFire",    1 },
}

hook.Add("PlayerCanPickupItem", "corpus_cargo_ammopool_world", function(ply, item)
    if not cvPool:GetBool() or not cvWorldAmmo:GetBool() then return end
    if not IsValid(item) or not IsValid(ply) then return end

    local spec = WORLD_AMMO[item:GetClass()]
    if spec == nil then return end

    -- the engine pickup is ALWAYS vetoed for these: this ammo never becomes raw
    -- pool. The flag guards the frames between the veto and the delayed remove,
    -- during which the touch keeps firing (a double give would be free ammo).
    if item.CargoAmmoTaken then return false end

    local itemId = CARGO.Ammo.ItemForType(spec[1])
    if itemId == nil then return false end

    if CARGO.Inventory.GiveItem(ply, itemId, spec[2]) then
        item.CargoAmmoTaken = true
        CARGO.Inventory.NotifyPickup(ply, itemId, spec[2])
        SafeRemoveEntityDelayed(item, 0)
    end
    -- too heavy: it stays on the floor, where he can come back for it
    return false
end)

-- ------------------------------------------------------------------
-- ARC9 takeover: kill the free reserve at the source (see header)
-- ------------------------------------------------------------------

Corpus.OnReady(function()
    if not cvPool:GetBool() then return end

    local cv = GetConVar("arc9_mult_defaultammo")
    if cv == nil then return end -- ARC9 not mounted: nothing to neutralise

    if cv:GetInt() == 0 then return end

    if not cvTakeover:GetBool() then
        Corpus.Log("cargo", "AVISO munición: arc9_mult_defaultammo=" .. cv:GetInt()
            .. " — ARC9 regala reserva al entregar un arma y el cinturón la absorberá."
            .. " Ponerlo en 0 o activar cargo_ammo_arc9_takeover")
        return
    end

    RunConsoleCommand("arc9_mult_defaultammo", "0")
    Corpus.Log("cargo", "munición: arc9_mult_defaultammo forzado a 0 (el cinturón es la única reserva)")
end)
