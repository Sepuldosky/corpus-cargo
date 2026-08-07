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
    "World ammo boxes (item_ammo_*): no touch pickup — WALK+USE takes them to the grid, USE carries them (0 = raw engine touch pickup)")

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
    -- the equipped throwable stack IS reserve too (§4 amendment, wheel block):
    -- its def carries ammo.hl2 exactly like a belt item, so the ×N badge on
    -- the slot is the real count the engine will let the player throw
    local eq = istable(rec.equip) and rec.equip.throwable or nil
    if istable(eq) then
        local hl2 = CARGO.Ammo.TypeOfDef(CARGO.Items.Get(eq.id))
        if hl2 ~= nil then
            totals[hl2] = (totals[hl2] or 0) + (eq.count or 1)
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

-- The equipped throwable stack drains FIRST for its type: the grenade the
-- player just threw is the one in his hand, not one hanging on the belt.
-- Emptying the stack empties the slot and takes the SWEP with it — a thrown
-- last grenade leaves no launcher shell behind. Returns what is still owed.
local function DrainThrowable(ply, rec, hl2, amount)
    if amount <= 0 then return amount end
    local eq = istable(rec.equip) and rec.equip.throwable or nil
    if not istable(eq) then return amount end
    local def = CARGO.Items.Get(eq.id)
    if CARGO.Ammo.TypeOfDef(def) ~= hl2 then return amount end

    local take = math.min(eq.count or 1, amount)
    eq.count = (eq.count or 1) - take
    if eq.count <= 0 then
        rec.equip.throwable = nil
        if istable(def) and isstring(def.weapon_class) and def.weapon_class ~= ""
            and IsValid(ply) then
            ply:StripWeapon(def.weapon_class)
        end
    end
    return amount - take
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

    -- Throwable-faced type (roadmap #32): the frag is a LAUNCHABLE, not belt
    -- ammunition — the belt filter rejects its category, so the only reserve
    -- that can absorb rounds of its type is the EQUIPPED stack (top up under
    -- max_stack: this is what makes the ×N badge move when the engine grants
    -- a grenade). Whatever does not fit returns to the caller, whose overflow
    -- path sends it to the grid AND drops the pool to the belt sum — a grid
    -- grenade is storage, not reserve.
    if def.category ~= "ammo" then
        local eq = istable(rec.equip) and rec.equip.throwable or nil
        if istable(eq) and eq.id == itemId and eq.condition == nil then
            local put = math.min(maxStack - (eq.count or 1), amount)
            if put > 0 then
                eq.count = (eq.count or 1) + put
                amount = amount - put
            end
        end
        return amount
    end

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

-- THE MAGAZINE IN YOUR HANDS FOLLOWS THE GUN, at the cadence the author chose
-- (roadmap #56, 2026-07-31, with the four costs measured). The loaded rounds
-- weigh (CRG-67), and `blob.clip1` was only refreshed at the gates — so firing
-- left the ledger claiming a full magazine until the gun was put away.
--
-- This rides THE POLL THAT ALREADY RUNS. No new timer, no weapon-base hook, no
-- per-shot anything: at most four refreshes a second while the player is
-- actually shooting, and none at all when they are not, because a clip that
-- did not move sets no `dirty`. Measured before choosing: recomputing the
-- weight costs 1.5 us, but the Touch it would trigger costs 0.158 ms of disk
-- and ~1.7 KB on the wire, so what had to be rationed was the Touch and not
-- the arithmetic.
--
-- It is the SAME shape as SyncAttsSoon (entry 64) and the opposite timing, for
-- the opposite reason: there the entity was about to be replaced and we had to
-- wait a tick; here the entity is standing still and we only have to look.
local function SyncHeldClip(ply)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return false end

    local uid, blob = CARGO.Inventory.EquippedUidForClass(ply, wep:GetClass())
    if blob == nil then return false end -- an admin/console give owns no blob

    local ok, clip = pcall(wep.Clip1, wep)
    if not ok or not isnumber(clip) or clip < 0 then return false end
    if blob.clip1 == clip then return false end

    -- mutating the live blob IS the update (CRG-57)
    blob.clip1 = clip
    return true
end

CARGO.AmmoPool.SyncHeldClip = SyncHeldClip

-- Is the mirror ALLOWED to run for this player? Exposed because it is the
-- single gate that `Reconcile` and `UnloadWeapon` share, so when the belt
-- stops following the pool AND the unload refuses, one flag explains both —
-- and hasta ahora no había forma de leerlo desde afuera, así que las dos
-- hipótesis ("el espejo está apagado" y "el espejo corre y falla") eran
-- indistinguibles desde el juego. Un instrumento que no puede separar dos
-- hipótesis cuesta una ronda entera (lección de la sección AB).
function CARGO.AmmoPool.IsReady(ply)
    return ready[ply] == true
end

function CARGO.AmmoPool.Reconcile(ply)
    if not cvPool:GetBool() then return end
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    if not ready[ply] then return end

    local rec = CARGO.Inventory.GetRecord(ply)
    local totals = BeltTotals(rec)

    -- FIRST, and it is load-bearing on a reload: the belt is about to pay for
    -- the rounds the magazine just took. Reading the clip in the same pass is
    -- what makes the two halves land in ONE Touch, so the ledger is continuous
    -- across a reload instead of dipping by a magazine and recovering later.
    local dirty = SyncHeldClip(ply)

    for _, hl2 in ipairs(CARGO.Ammo.TYPES) do
        local pool = ply:GetAmmoCount(hl2)
        local belt = totals[hl2] or 0

        if pool < belt then
            -- spent: loaded into a magazine, thrown, or fired straight from
            -- reserve. The equipped throwable stack pays first (see above).
            DrainType(rec, hl2, DrainThrowable(ply, rec, hl2, belt - pool))
            dirty = true

        elseif pool > belt then
            -- returned: a magazine was unloaded back into the reserve
            local left = AbsorbType(rec, hl2, pool - belt)

            if left > 0 then
                -- Belt is full, so they go to the grid — which is what the grid
                -- is for. Either way they are no longer reserve, so the pool
                -- MUST drop to the belt sum: left at the old count, the next
                -- poll would see pool > belt again and mint the same rounds
                -- forever (dup at 4 Hz — latent in Bloque B, reachable once #26
                -- made "unload with a full belt" an ordinary move).
                --
                -- And that unconditional SetAmmo is what made this the second
                -- site of CRG-65 (roadmap #53): with the grid full too, the
                -- give failed, the pool dropped anyway and the rounds ENDED —
                -- while the line above claimed they were not destroyed. It said
                -- so from the day it was written. Now they fall to the floor.
                local itemId = CARGO.Ammo.ItemForType(hl2)
                local ok, toFloor = false, false
                if itemId then
                    ok, toFloor = CARGO.Inventory.GiveOrDrop(ply, itemId, left)
                end
                ply:SetAmmo(pool - left, hl2)
                if toFloor then
                    CARGO.Inventory.Notice(ply, "No room — the rounds dropped at your feet.")
                elseif not ok then
                    -- no item def for this ammo type: nothing to spawn either
                    CARGO.Inventory.Notice(ply, "You cannot carry any more ammunition.")
                end
            end
            dirty = true
        end
    end

    if dirty then CARGO.Inventory.Touch(ply) end
end

-- 4 Hz. The pool only MOVES on reload / unload / grenade throw, so `dirty` was
-- rare and the Touch (save + sync) it triggers rarer still — firing does not
-- touch the reserve, it drains the magazine.
--
-- AMENDED 2026-07-31 (roadmap #56): the magazine now WEIGHS, so draining it is
-- a ledger movement too and `dirty` also rises when the held clip changed. The
-- ceiling that buys is explicit and it is why this cadence was the one chosen:
-- at most FOUR Touch per second, and only while the trigger is actually being
-- pulled — a full-auto rifle at ten rounds a second still pays four, not ten,
-- and a player who is not shooting pays none. Measured cost of the difference:
-- 26 KB/s to disk and 0.63 ms/s of disk time per firing player, against the
-- 64 KB/s and 1.58 ms/s that one Touch per bullet would have cost.
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
-- Unload the held weapon (roadmap #26). The hard half already exists: the
-- magazine goes back into the pool through the same route a reload came
-- from, and the mirror absorbs it onto the belt — overflow to the grid
-- (§16.3, harness-verified). This is only the TRIGGER, plus the emptied
-- magazine persisting in the instance blob (#18).
-- ------------------------------------------------------------------

local NET_UNLOAD = Corpus.Net.Register("cargo", "unload")

-- The Cargo instance embodied by an equipped weapon entity, if any: a weapon
-- given by other means (admin, console) has no blob to persist.
local function EquippedUidOf(ply, class)
    local rec = CARGO.Inventory.GetRecord(ply)
    for _, uid in pairs(rec.equip) do
        local blob = CARGO.Instances.Get(uid)
        local def = istable(blob) and CARGO.Items.Get(blob.id) or nil
        if istable(def) and def.weapon_class == class then return uid end
    end
    return nil
end

-- The reload animation the author asked for. ARC9's viewmodel anim is played
-- ONLY when its animation entry does not declare RestoreAmmo: that flag
-- re-fills the clip FROM THE RESERVE on a timer inside PlayAnimation
-- (sh_anim.lua:130-133 -> RestoreClip, sh_reload.lua:298), which would undo
-- the unload behind our back. Checked through ARC9's own API, never assumed
-- (COMPAT-RUNTIME). DumpAmmo entries are fine: their second Unload finds an
-- empty clip.
local function PlayUnloadAnim(ply, wep)
    if wep.ARC9 then
        local entry
        local okT, anim = pcall(wep.TranslateAnimation, wep, "reload")
        if okT and isstring(anim) then
            local okE, e = pcall(wep.GetAnimationEntry, wep, anim)
            if okE and istable(e) then entry = e end
        end
        if entry ~= nil and not entry.RestoreAmmo then
            pcall(wep.PlayAnimation, wep, "reload")
        end
        pcall(wep.DoPlayerAnimationEvent, wep, ACT_HL2MP_GESTURE_RELOAD_MAGIC)
    else
        pcall(wep.SendWeaponAnim, wep, ACT_VM_RELOAD)
        if isfunction(ply.AnimRestartGesture) then
            ply:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD,
                ACT_HL2MP_GESTURE_RELOAD_MAGIC, true)
        end
    end
end

function CARGO.AmmoPool.UnloadWeapon(ply)
    if not cvPool:GetBool() then return end
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    -- spawn window: rounds returned to the pool right now would die in the
    -- StripAmmo+Push about to run — silent loss. Same gate as the reconciler.
    if not ready[ply] then
        CARGO.Inventory.Notice(ply, "You can't do that right now.")
        return
    end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end
    local okC, clip = pcall(wep.Clip1, wep)
    if not okC or not isnumber(clip) or clip <= 0 then
        CARGO.Inventory.Notice(ply, "Nothing to unload.")
        return
    end

    if wep.ARC9 then
        -- the legitimate route: SWEP:Unload does GiveAmmo(Clip1) +
        -- SetClip1(0) + SetLoadedRounds(0) (sh_reload.lua:199-205, verified)
        local okA, ammoType = pcall(wep.GetProcessedValue, wep, "Ammo")
        if not okA or not isstring(ammoType) or ammoType == "" then return end
        if not pcall(wep.Unload, wep, ammoType) then return end
    else
        local ammoName = game.GetAmmoName(wep:GetPrimaryAmmoType())
        if not isstring(ammoName) then
            CARGO.Inventory.Notice(ply, "Nothing to unload.")
            return
        end
        ply:GiveAmmo(clip, ammoName, true)
        wep:SetClip1(0)
    end

    PlayUnloadAnim(ply, wep)

    -- BEFORE the reconcile, and the order is load-bearing since the loaded
    -- rounds started weighing (roadmap #56, CRG-67). Reconcile does a Touch of
    -- its own, and that Touch computes the weight: with the blob still holding
    -- the pre-unload count, the same rounds would be counted twice — once on
    -- the belt they just landed on and once in a magazine that is already
    -- empty. And it would not be a blink: nothing Touches again after this
    -- line, so the inflated number would be the one written to disk and the
    -- one the client is shown, until something else moved the record.
    --
    -- Safe to hoist: wep:Clip1() is already 0 here — SWEP:Unload zeroed it
    -- (sh_reload.lua:199-205), and so did the manual branch above.
    --
    -- MEASURED, and it changes what this line can claim: under the chosen
    -- cadence it is REDUNDANT. SyncHeldClip runs at the head of Reconcile and
    -- reads the same zero, so reverting this hoist alone turns NOTHING red
    -- (reversión R5, 0 fails) — only dropping both guards does (R8). It stays
    -- because it is the one that survives a cadence change: if the poll ever
    -- stops re-reading the clip, this is what keeps the unload honest.
    local uid = EquippedUidOf(ply, wep:GetClass())
    if uid ~= nil then CARGO.Inventory.StoreClip(uid, wep) end

    -- no waiting on the 4 Hz poll: the rounds land on the belt (grid when
    -- the belt is full) in the same breath
    CARGO.AmmoPool.Reconcile(ply)
end

net.Receive(NET_UNLOAD, function(_, ply)
    CARGO.AmmoPool.UnloadWeapon(ply)
end)

-- ------------------------------------------------------------------
-- Ammo lying in the world -> a Cargo item in the GRID (author call)
--
-- "El grid es el almacén, el cinturón es el pool": you find ammo, you store it,
-- and you decide how much of it to hang on your belt. It never becomes raw
-- reserve behind your back. Amounts are HL2's own (hl2/item_ammo.cpp defaults).
--
-- CONTACT never takes (roadmap #32, 2nd pass 2026-07-13: spawned item_ammo_*
-- boxes were hoovered by touch — Bloque B design, now unwanted). The hook
-- below is a pure VETO; the actual take is WALK+USE through the SAME PlayerUse
-- gate weapons and dropped items use (capture.lua), which reads WorldAmmoSpec.
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

    -- TFA Base's own ammo entities (roadmap #57). NOT HL2 defaults: the counts
    -- are the mod's (tfa/modules/tfa_small_entities.lua, read out of the .gma),
    -- and they are the ONLY thing in the live arsenal that hands out AirboatGun
    -- — no weapon eats it, so without this line the Winchester item has nothing
    -- to come from but the mirror absorbing raw pool.
    -- WHY THIS TABLE AND NOT THE VETO HOOK: TFA grants through its own ENT:Use
    -- (`activator:GiveAmmo(self.AmmoCount, self.AmmoType)`), which
    -- PlayerCanPickupItem never sees. What actually closes it is the WALK+USE
    -- gate returning false, which keeps the engine from reaching ENT:Use at all
    -- — the roadmap #27 technique, same as the registered third-party pickups.
    -- Inert without TFA mounted (the class simply never exists) and it rides
    -- the existing cargo_ammo_world_pickup kill-switch.
    tfa_ammo_winchester    = { "AirboatGun",           50 },
    tfa_ammo_sniper_rounds = { "SniperPenetratedRound", 30 },
}

-- Class of a world ammo box -> { id, count } of the grid item a deliberate
-- take delivers, or nil when the class is not ours / the convars turned the
-- conversion off (0 restores the raw engine touch pickup). Consumed by the
-- WALK+USE gate in capture.lua — one gate, never a second one.
function CARGO.AmmoPool.WorldAmmoSpec(class)
    if not cvPool:GetBool() or not cvWorldAmmo:GetBool() then return nil end
    local spec = WORLD_AMMO[class or ""]
    if spec == nil then return nil end
    local itemId = CARGO.Ammo.ItemForType(spec[1])
    if itemId == nil then return nil end
    return { id = itemId, count = spec[2] }
end

hook.Add("PlayerCanPickupItem", "corpus_cargo_ammopool_world", function(ply, item)
    if not IsValid(item) or not IsValid(ply) then return end
    if CARGO.AmmoPool.WorldAmmoSpec(item:GetClass()) == nil then return end

    -- the engine pickup is ALWAYS vetoed for these: this ammo never becomes
    -- raw pool and contact never takes (roadmap #32). The give lives in the
    -- WALK+USE gate; this veto also covers the frames between that give and
    -- the delayed remove, during which the touch keeps firing.
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
