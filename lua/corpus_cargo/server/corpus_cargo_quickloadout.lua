-- corpus_cargo_quickloadout.lua — Quick Loadouts compat (SERVER)
-- Author request 2026-07-23 (map + wants: dev/Cargo_QuickLoadouts_Referencia.md;
-- scope: functional compat only, NO UI integration). Every mod API name below
-- was verified against the live code (dev/other/quick loadouts/lua/quickloadout/
-- sv_loadout.lua, CRG-24), never from memory.
--
-- THE PROBLEM. The mod's PlayerLoadout hook ("QuickLoadoutLoadout" = the
-- GLOBAL QuickLoadout(), sv:59) does two things Cargo cannot survive:
--   * ply:StripWeapons() + ply:RemoveAllAmmo() UNCONDITIONALLY (sv:63-64) —
--     even with an EMPTY loadout: the "client disabled" net message leaves
--     ply.quickloadout = {} (sv:29), which passes the nil-only guard (sv:62).
--     The entities of every equipped Cargo weapon die with their live
--     magazines, and the pool wipe reads as consumption to the §16 mirror,
--     which then drains the belt stacks — real item loss (the author's
--     reported bug: persisted weapons "disappear" with the loadout off).
--   * with an active loadout it returns true (sv:100-102), cutting the
--     PlayerLoadout chain — whether Cargo's restore hooks ran at all was a
--     hook-insertion-order lottery. And the mod re-runs the WHOLE chain
--     MID-ROUND from its net receive (sv:42), not just on spawn.
--
-- THE TAKEOVER. QL's hook is removed and this file re-registers the same
-- function wrapped, LAST in Cargo's manifest order. That one move makes the
-- chain deterministic: every Cargo PlayerLoadout hook — inventory re-give +
-- its 0.1 s reconcile, ammopool ready-gate + 0.5 s belt rebuild, holster
-- hands at 0.25 s — has already run AND scheduled its heals before the strip
-- fires. So the mirror is suppressed during the window (ready=nil), the
-- reconcile re-gives every stripped equipped class, and the wrapper banks
-- the live magazines into the instance blobs beforehand: nothing of Cargo's
-- rides the strip into the void, on spawn or mid-round, loadout or not.
--
-- WHAT THE LOADOUT BECOMES. The gives are untouched: the weapons QL hands
-- out at tick 0 land on the existing WeaponEquip capture like any anonymous
-- engine give — a new class is captured to the grid as an item, a class
-- already owned is dropped (the same dedup that stops the gamemode loadout
-- from minting a pistol per respawn), an equipped class is kept as the
-- equipped entity. The reserve ammo QL gifts dies in the ammopool spawn
-- rebuild (StripAmmo + Push from the belt), same rule as ARC9's free-ammo
-- takeover: no ether. Net effect — the author's want verbatim: the loadout
-- is an item DELIVERY that Cargo administers; Cargo stays the source of
-- truth. Known edge, accepted: a loadout class that is ALSO equipped lands
-- on "keep", so QL's SetClip1(max) hands that one weapon a full magazine.

local CARGO = Corpus.GetModule("cargo")

local cvCompat = CreateConVar("cargo_quickloadout_compat", "1", FCVAR_ARCHIVE,
    "Quick Loadouts compat: the loadout is delivered through the Cargo inventory and never destroys items (0 = stock mod behavior)")

-- capture.lua loads earlier in the manifest: the convar object exists
local cvCapture = GetConVar("cargo_capture_weapons")

-- Detection, never assumption (contract #9): the mod registers the global at
-- autorun include time and Cargo boots at Initialize, after every autorun
-- file, so a mounted mod is always visible here. Absent mod = inert file.
if not isfunction(QuickLoadout) then
    Corpus.Log("cargo", "quick loadouts no montado — compat inactiva")
    return
end

local QL_HOOK = "QuickLoadoutLoadout"

-- Idempotent, re-run before every pass: a lua refresh of the mod re-adds its
-- hook, and the unwrapped strip must never sneak back into the chain.
local function Takeover()
    hook.Remove("PlayerLoadout", QL_HOOK)
end
Takeover()

-- Our own spawn stamp: tells a spawn pass apart from the mid-round re-runs
-- the net receive fires (sv:42). On spawn the author's call is deploy Hands
-- (roadmap #4); mid-round the player keeps what he was holding.
hook.Add("PlayerSpawn", "corpus_cargo_ql_spawnstamp", function(ply)
    ply.CargoQLSpawnStamp = CurTime()
end)

hook.Add("PlayerLoadout", "corpus_cargo_ql_compat", function(ply)
    Takeover()
    if not IsValid(ply) or not ply:IsPlayer() then return end

    -- compat off / capture off (no Cargo weapon management to protect):
    -- pass-through, stock mod behavior — pcall'd so a third-party error is
    -- never attributed to Cargo's chain (contract #9)
    if not cvCompat:GetBool() or cvCapture == nil or not cvCapture:GetBool() then
        local okRaw, retRaw = pcall(QuickLoadout, ply)
        if not okRaw then
            Corpus.Log("cargo", "QuickLoadout() falló: " .. tostring(retRaw))
            return
        end
        return retRaw
    end

    -- bank every live magazine into its instance blob BEFORE the strip
    -- destroys the entities: the 0.1 s reconcile re-gives from the blob
    -- (RestoreClip), so the loaded rounds survive the round trip
    local rec = CARGO.Inventory.GetRecord(ply)
    for _, val in pairs(rec.equip) do
        -- stack slots (throwable) hold an entry table: no blob, no clip
        if isstring(val) then
            local blob = CARGO.Instances.Get(val)
            local def = blob and CARGO.Items.Get(blob.id) or nil
            local class = def and def.weapon_class or nil
            if isstring(class) and class ~= "" and ply:HasWeapon(class) then
                CARGO.Inventory.StoreClip(val, ply:GetWeapon(class))
            end
        end
    end

    -- mid-round: remember the hand. The loadout is a delivery, not a swap.
    local activeClass
    if CurTime() - (ply.CargoQLSpawnStamp or 0) > 1 then
        local active = ply:GetActiveWeapon()
        if IsValid(active) then activeClass = active:GetClass() end
    end

    -- the original runs untouched: strip + timered gives + its return-true
    -- semantics toward GM:PlayerLoadout (an active loadout still suppresses
    -- the engine handout, exactly as the mod intends)
    local ok, ret = pcall(QuickLoadout, ply)
    if not ok then
        Corpus.Log("cargo", "QuickLoadout() falló: " .. tostring(ret))
        ret = nil
    end

    -- after the dust settles — QL gives at tick 0, the capture eats them a
    -- tick later, the reconcile re-gives at 0.1, hands deploy at 0.25 —
    -- put back in hand what was there before the pass
    if activeClass ~= nil then
        timer.Simple(0.35, function()
            if not IsValid(ply) or not ply:Alive() then return end
            if not ply:HasWeapon(activeClass) then return end
            local cur = ply:GetActiveWeapon()
            if IsValid(cur) and cur:GetClass() == activeClass then return end
            ply:SelectWeapon(activeClass)
        end)
    end

    return ret
end)

Corpus.Log("cargo", "quick loadouts detectado — compat activa (takeover de su PlayerLoadout)")
