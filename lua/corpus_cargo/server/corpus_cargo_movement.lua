-- corpus_cargo_movement.lua — weight applied to walk/run speed (SERVER)
-- Cargo_Architecture.md §5. The curve itself is shared and pure
-- (corpus_cargo_weight.lua); this file only applies it to the player.
--
-- NATIVE consequence: a server with only Cargo mounted already punishes
-- overload through movement speed. Coagulant, when present, stacks its own
-- stamina drain ON TOP — Cargo never depends on it for its own penalty.

local CARGO = Corpus.GetModule("cargo")

CARGO.Movement = CARGO.Movement or {}

-- Base speeds are re-captured on every spawn (the engine resets them, and
-- other addons that tune them do it around spawn too). The multiplier is
-- always applied over the captured base, never over the current value —
-- re-applying is idempotent.
local function CaptureBase(ply)
    ply.CargoBaseWalk = ply:GetWalkSpeed()
    ply.CargoBaseRun = ply:GetRunSpeed()
end

function CARGO.Movement.Refresh(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if ply.CargoBaseWalk == nil then CaptureBase(ply) end

    local frac = CARGO.Inventory.GetWeightFraction(ply)
    local mult = CARGO.Weight.SpeedMultiplier(frac, 1) -- curve takes w/cap; frac IS w/cap

    ply:SetWalkSpeed(math.max(ply.CargoBaseWalk * mult, 30))
    ply:SetRunSpeed(math.max(ply.CargoBaseRun * mult, 40))

    -- Soft-dep: Coagulant owns stamina. Expected contract (mock-first,
    -- Coagulant block pending): coagulant.OnEncumbrance(ply, fraction) —
    -- called on every weight change so it can drive drain/fatigue. Honest
    -- degradation: without Coagulant, the native speed penalty above is the
    -- whole consequence.
    local coagulant = Corpus.GetModule("coagulant")
    if coagulant and isfunction(coagulant.OnEncumbrance) then
        pcall(coagulant.OnEncumbrance, ply, frac)
    end
end

hook.Add("PlayerSpawn", "corpus_cargo_movement", function(ply)
    -- next tick: let the gamemode/other addons finish setting spawn speeds
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        CaptureBase(ply)
        CARGO.Movement.Refresh(ply)
    end)
end)
