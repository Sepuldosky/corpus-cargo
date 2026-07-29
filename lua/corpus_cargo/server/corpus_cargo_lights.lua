-- corpus_cargo_lights.lua — the ONE net message of the lights group (SERVER)
-- Roadmap #46. This receiver is the whole file on purpose: it is the single
-- exception the CRG-30 amendment allows, and keeping it alone makes the
-- exception auditable at a glance.
--
-- WHY A NET AT ALL (author's call, option b of the design doc §9.4):
-- ply:Flashlight(bool) is server-only — the only one of the group's three
-- legs that needs a channel. Option (a), RunConsoleCommand("impulse 100"),
-- was MEASURED and discarded: with any toggleable ARC9 device in hand,
-- arc9/shared/sh_move.lua:360-369 HIJACKS the impulse and rewrites it to
-- IMPULSE_TOGGLEATTS — the torch stays dark and the device changes mode
-- instead. The same key doing different things depending on what you hold is
-- worse than amending a written norm.
--
-- WHY IT KEEPS CRG-6 INTACT: no payload, no state, no persistence — there is
-- nothing a hostile intent can fabricate. The server flips its OWN truth
-- (FlashlightIsOn) and the chip reads it back through the mirror below. What
-- the norm protected — no parallel inventory routes — stays whole; the
-- amendment and its rationale live in Cargo_Architecture.md §17.1 and
-- ids.yaml (CRG-30).
--
-- THE MIRROR, AND WHY IT EXISTS (2nd pass, planilla V ronda 2 — the first
-- pass shipped without it and the chip never painted ON):
-- ply:Flashlight is server-only in BOTH directions. The first pass MEASURED
-- that writing it needs a channel and ASSUMED that reading it did not — the
-- exact shape of mistake CRG-24 exists to prevent, committed against an
-- engine API instead of a mod's. Measured in game, with the beam visibly
-- painting a wall and no ARC9 weapon in hand:
--     lua_run    print(Entity(1):FlashlightIsOn())  -> true
--     lua_run_cl print(LocalPlayer():FlashlightIsOn()) -> false
-- So the client cannot read it and the server has to publish it. NW2Bool,
-- the same vehicle the weight multiplier already uses for the same reason
-- (server/corpus_cargo_movement.lua, roadmap #34) — engine replication, not
-- a second net message: the CRG-30 amendment stays at ONE intent.
--
-- WHY A MIRROR AND NOT A PUBLISH-ON-OUR-TOGGLE: the engine flashlight key is
-- deliberately NEVER intercepted (§17.4), so Cargo is not the only writer —
-- the player's own key writes it, and so does ARC9 (sh_attach.lua:143-145,
-- server PostModify kills the torch when the weapon carries a ToggleOnF
-- attachment). A chip fed only by our own toggles would drift the moment
-- anyone else wrote, which is CRG-64's sin in the other tense. The mirror
-- reads the real state, so every writer is covered by construction. 4 Hz is
-- the module's established rate for exactly this shape of mirror (§16.3-16.5,
-- the belt<->pool mirror) and the receiver publishes immediately besides, so
-- our own toggle never waits for a tick.
--
-- FRONTIER, measured and NOT fought (Cargo_Architecture.md §13): with an
-- ARC9 weapon that has a device DEPLOYED, the engine torch turns on and its
-- beam is NOT drawn — it comes back on switching to a weapon without one,
-- with the server state true throughout. That is the mod's business (two
-- flashlights at once is what it is avoiding); the chip reports the truth it
-- has, which is that the torch is on.
--
-- Known third-party interplay, verified against dev/other/ (CRG-24), not
-- fought here: ARC9's server-side PostModify turns the engine flashlight OFF
-- when the weapon in hand has a ToggleOnF attachment (sh_attach.lua:143-145)
-- — toggling a weapon device while the torch is on switches the torch off.
-- That is the mod's own rule about the shared F key, and it is measured in
-- game (planilla V), never patched.

local CARGO = Corpus.GetModule("cargo")

CARGO.Lights = CARGO.Lights or {}

local NET_TORCH = Corpus.Net.Register("cargo", "torch")

-- same literal in client/corpus_cargo_lights.lua (the chip reads it); the two
-- realms never share a file, exactly like NET_TORCH above
local NW_TORCH = "cargo_torch"

-- Publishes the REAL state, whoever wrote it. Exported so the offline harness
-- can drive it against a stub that actually holds state (§0.bis 3: a stub that
-- does not invert makes what it measures indemonstrable).
function CARGO.Lights.PublishTorch(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local on = ply:FlashlightIsOn() and true or false
    if ply:GetNW2Bool(NW_TORCH, false) ~= on then
        ply:SetNW2Bool(NW_TORCH, on)
    end
end

net.Receive(NET_TORCH, function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    ply:Flashlight(not ply:FlashlightIsOn())
    -- immediate, so our own toggle never waits for the mirror tick
    CARGO.Lights.PublishTorch(ply)
end)

-- the other writers (the engine key, ARC9's PostModify) land here
timer.Create("corpus_cargo_torch_mirror", 0.25, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        CARGO.Lights.PublishTorch(ply)
    end
end)
