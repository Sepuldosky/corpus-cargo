-- corpus_cargo_movecompat.lua — weight penalty vs speed-stomping movement mods (SHARED)
-- Roadmap #34, in-game report 2026-07-13: with "better movement v2 with
-- sprint step time" mounted, the weight->speed curve stopped biting. Read
-- against the LIVE mod (dev/other/, COMPAT-RUNTIME, never assumed): its
-- SetupMove hook (sh_bm_main.lua:231-482) re-stamps SetWalkSpeed/SetRunSpeed
-- EVERY move tick from its own convars (sv_bm_speed_walk/run × a lerped
-- fraction, lines 455-457) — the bases movement.lua captures on spawn and
-- multiplies on Refresh die one tick later.
--
-- Chosen lever, the least invasive of the handoff's three: scale the move
-- data's MaxSpeed in our own Move hook. Move runs AFTER SetupMove in the
-- prediction pipeline, so whatever the mod wrote is already in place; the
-- engine clamps wishspeed to the move data's MaxSpeed, so the penalty bites
-- without touching the mod, its convars, or the player's stored walk/run
-- speeds — and without feeding back into the mod's own math (it re-reads
-- its convars every tick, never our scaled value). SHARED because Move is
-- predicted: the client must scale the same number or a player in
-- multiplayer rubber-bands.
--
-- The multiplier travels in an NW2Float written by Movement.Refresh
-- (server owns the weight; the client only reads it inside prediction).
-- With the mod absent or disabled (sv_bm_enabled 0) this hook does nothing
-- and the vanilla path — bases captured on spawn, multiplied in Refresh —
-- remains the whole story: honest degradation in both directions.
--
-- Known cosmetic edge, declared: the mod paces footstep sounds from ITS
-- lerped speed (BmGetStepSoundTime reads BmNewMaxSpeed), which never sees
-- our scale — steps can sound a touch faster than the feet move under
-- heavy load. Display-only, not worth a hook into its internals.

local CARGO = Corpus.GetModule("cargo")

CARGO.MoveCompat = CARGO.MoveCompat or {}

local cvCompat = CreateConVar("cargo_movement_compat", "1",
    bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
    "Re-apply the weight->speed curve over speed-stomping movement mods (better movement v2) via a Move hook")

-- Pure decision (offline-harness covered): whether the Move leg runs and by
-- how much. `bmEnabled` is the live state of the mod's own master toggle —
-- respecting it means turning the mod off restores pure vanilla behavior.
function CARGO.MoveCompat.ScaleFor(bmEnabled, mult)
    if not bmEnabled then return nil end
    if not isnumber(mult) or mult >= 1 then return nil end
    return mult
end

hook.Add("Move", "corpus_cargo_movecompat", function(ply, mv)
    if not cvCompat:GetBool() then return end
    local bm = GetConVar("sv_bm_enabled") -- exists only with the mod mounted
    if bm == nil then return end
    local scale = CARGO.MoveCompat.ScaleFor(bm:GetBool(),
        ply:GetNW2Float("cargo_speed_mult", 1))
    if scale == nil then return end
    -- same absolute floor the vanilla path keeps (movement.lua): overloaded
    -- must stay slow, never immobile
    mv:SetMaxSpeed(math.max(mv:GetMaxSpeed() * scale, 30))
end)
