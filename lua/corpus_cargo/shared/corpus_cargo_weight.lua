-- corpus_cargo_weight.lua — pure weight -> movement curve (SHARED)
-- Cargo_Architecture.md §5. NATIVE consequence: works with zero soft-deps
-- mounted. Pure math, no hooks — the application to walk/run speed lives in
-- server/corpus_cargo_movement.lua; the client reuses the same curve for the
-- footer display. Deterministic on purpose: cargo_selftest asserts it.

local CARGO = Corpus.GetModule("cargo")

CARGO.Weight = CARGO.Weight or {}

-- Overweight hard cap: past fraction 2.0 (double the capacity) nothing more
-- can be picked up. Between 1.0 and 2.0 you can still move, painfully.
CARGO.Weight.MAX_FRACTION = 2.0

-- Continuous curve fraction-of-capacity -> speed multiplier:
--   f <= 0.5        -> 1.0                        (light load, no penalty)
--   0.5 < f <= 1.0  -> 1 - 0.35*t^2, t=(f-.5)/.5  (smooth ramp to 0.65)
--   f > 1.0         -> 0.65 - 0.5*(f-1)           (overload, floor 0.15)
-- C0-continuous at both joints (1.0 at 0.5, 0.65 at 1.0), monotonically
-- decreasing. Tuning belongs here and only here.
function CARGO.Weight.SpeedMultiplier(weight, capacity)
    if not isnumber(weight) or not isnumber(capacity) or capacity <= 0 then
        return 1
    end

    local f = math.max(weight, 0) / capacity
    if f <= 0.5 then return 1 end
    if f <= 1 then
        local t = (f - 0.5) / 0.5
        return 1 - 0.35 * t * t
    end
    return math.max(0.65 - 0.5 * (f - 1), 0.15)
end

-- Carry capacity = player base (convar) + Back item bonus (§5). The Back
-- slot is exactly "a capacity modifier", nothing else.
CARGO.Weight.cvBase = CreateConVar("cargo_capacity_base", "54",
    bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
    "Player base carry capacity (kg)", 1, 500)

-- backDef: def of the item equipped in Back, or nil.
-- Returns total, base, backBonus (the footer shows the breakdown).
function CARGO.Weight.Capacity(backDef)
    local base = CARGO.Weight.cvBase:GetFloat()
    local back = 0
    if istable(backDef) and isnumber(backDef.capacity_bonus) then
        back = backDef.capacity_bonus
    end
    return base + back, base, back
end
