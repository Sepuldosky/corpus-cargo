-- corpus_cargo_pickupanim.lua — the offhand "reach out and take it" gesture
-- for Cargo's WALK+USE take (SHARED). Recycled from [GCAL] Improved Manual
-- Pickup (3722869921) on top of GCAL (3727245204); credits in docs/CREDITOS.md.
--
-- WHAT WAS RECYCLED AND WHAT WAS DROPPED. The source pack is a whole manual
-- pickup SYSTEM for HL2 items: it vetoes AllowPlayerPickup, keeps its own
-- inclusion table of item_ammo_* classes, teleports the entity to the player,
-- juggles m_bPreventWeaponPickup with a fallback timer, and draws a green NMRIH
-- halo over whatever you look at. Cargo ALREADY OWNS every one of those jobs —
-- the world gate in corpus_cargo_capture.lua is the manual pickup system, and
-- it is older, wider (weapons, item drops, cash, ammo boxes, third-party
-- pickups) and already says WALK+USE takes / USE carries. So none of that
-- crossed over. What crossed over is ONE THING: the animation, and the tuning
-- table that makes it read as a pickup rather than a generic use.
--
-- The halo was declined by the author explicitly (2026-08-25): the interaction
-- menu (corpus/docs/Corpus_Interaccion_Arquitectura.md) is what tells you what
-- a world object is and whether it is worth taking — a second look-at outline
-- would answer a question the menu already answers better. The same call the
-- pickup feed already recorded in corpus_cargo_pickup.lua:3-4. The item model
-- riding the hand was declined too: the gesture is wanted for what it COSTS
-- (you cannot hoover a room one press at a time) and as the tell that the take
-- landed, not as a second inventory readout.
--
-- WHY THE SEQUENCE IS DECLARED AND NOT INFERRED (verified against the live
-- code of gcal_core.lua:824-845, CRG-24). GCAL resolves which sequence of the
-- model to play by NAME: the anim's own name is candidate #1, and the source
-- pack got away with calling its anim "interactslower" precisely because that
-- string contains the token "interact", which IS the sequence name inside
-- c_vmanipinteract.mdl. Ours is called "cargo_pickup" and contains no such
-- token — with no `sequence` field it would miss every candidate and fall
-- through to GCAL's surrogate/pose-only path, which is a SILENT degradation:
-- a wrong-looking gesture, not an error. `sequence` is candidate #2 and
-- explicit, so the resolution cannot drift with the name.
--
-- WHO SEES IT: THE TAKER, AND ONLY THE TAKER. GCAL's server-side Play writes
-- `name` and `trackID` into the net message and NOTHING ELSE — no player
-- (gcal_core.lua:2841-2860, and the receiver at :2822 plays it on ITSELF).
-- So the message means "you, play this", never "player X gestured": a
-- broadcast would make every client animate their own arm. Hence the explicit
-- `recipients = ply` below — without it this would fire the gesture on
-- everyone in the server every time anybody picked something up. The flip
-- side is the honest limit: in multiplayer the OTHER players do not see the
-- take. That is fine for what the gesture is for here (the tell that YOUR
-- take landed, and its cost), and a third-person tell would be a different
-- feature on GCAL's TPIK, not a parameter of this one.
--
-- GCAL IS A SOFT DEPENDENCY, LIKE NEOSUN'S NVG. Without it the global is nil,
-- nothing registers, the gate never calls Play, and Cargo behaves exactly as
-- it did before this file existed. There is deliberately NO fallback to a
-- stock VManip install: GCAL is a full replacement for VManip and warns about
-- coexisting installs itself, so a second path would only add a way to be
-- half-wired.

local CARGO = Corpus.GetModule("cargo")

CARGO.PickupAnim = CARGO.PickupAnim or {}

-- The name is ours; the pack's "interactslower" is left alone so both can be
-- mounted at once while the author still has the original subscribed.
local ANIM = "cargo_pickup"

-- Measured, not guessed: c_vmanipinteract.mdl carries two sequences and the
-- `interact` one runs 46 frames at 55 fps = 0.818 s (read straight out of the
-- .mdl's animdesc, 2026-08-25). At speed 1 that IS the gesture's length, so the
-- gate's debounce is raised to cover it — otherwise a second take fires while
-- the arm is still moving and restarts the animation mid-swing. Cargo's stock
-- 0.4 s debounce stays the floor for everything that does not animate.
local cvGesture = CreateConVar("cargo_pickup_gesture", "1",
    bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
    "Play the GCAL offhand pickup animation on a WALK+USE take (needs GCAL mounted)")
local cvGestureTime = CreateConVar("cargo_pickup_gesture_time", "0.8",
    bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
    "Seconds a WALK+USE take is held off while the pickup gesture plays (0 = keep Cargo's stock 0.4s debounce)")

if CLIENT then

    -- The tuning table recycled from the source pack's vmanip/anims/pickup_anim.lua
    -- (lerp peak/speed/curve), which is the part of that addon that took taste
    -- rather than code: it is the stock VManip "use" gesture slowed down and
    -- eased out so it reads as picking something up off the floor instead of
    -- slapping a button.
    local function Register()
        if not GCAL or not isfunction(GCAL.RegisterAnim) then return false end
        GCAL:RegisterAnim(ANIM, {
            model         = "c_vmanipinteract.mdl",
            sequence      = "interact",  -- explicit; see the header
            lerp_peak     = 0.7,
            lerp_speed_in = 1,
            lerp_speed_out = 0.8,
            lerp_curve    = 2.5,
            speed         = 1,
            startcycle    = 0,
            sounds        = {},
            loop          = false,
            addon_name    = "Corpus Cargo",
        })
        return true
    end

    -- Cargo defers its boot to "Initialize", which is after every autorun, so
    -- GCAL is normally already there. The InitPostEntity retry is for the case
    -- it is not (a mount order we have not seen); registering twice is a plain
    -- overwrite in GCAL.Anims, so the retry is free.
    if not Register() then
        hook.Add("InitPostEntity", "corpus_cargo_pickupanim_register", Register)
    end

    -- ------------------------------------------------------------------
    -- The instrument. It exists because the ONE thing that can go wrong here
    -- goes wrong SILENTLY: if GCAL resolves a sequence other than `interact`
    -- (or none, and falls to pose-only) the gesture is simply the wrong
    -- gesture, with nothing in console. `sequence` is only READ while a track
    -- is alive, so `play` reproduces it and reports what the track actually
    -- resolved — the question cannot be answered without playing it.
    --
    -- A concommand and not a lua_run_cl one-liner on purpose: the GMod console
    -- splits its argument on ( ) ' : { } and truncates at 255, so a check whose
    -- command carries a Lua call is a check that can silently measure nothing.
    -- ------------------------------------------------------------------
    concommand.Add("cargo_pickupanim_diag", function(_, _, args)
        local W, G, R = Color(236, 242, 255), Color(120, 230, 150), Color(240, 120, 120)
        local function line(c, s) MsgC(c, s .. "\n") end

        if not GCAL then
            line(R, "[cargo pickupanim] GCAL NO ESTA MONTADO -- el gesto esta inerte y Cargo anda igual que antes.")
            return
        end
        line(W, "[cargo pickupanim] GCAL presente.")

        local anim = isfunction(GCAL.GetAnim) and GCAL:GetAnim(ANIM) or nil
        line(anim and G or R, "  anim '" .. ANIM .. "' registrada: " .. tostring(anim ~= nil))
        if anim then
            line(W, "  model=" .. tostring(anim.model) .. "  sequence declarada=" .. tostring(anim.sequence))
        end
        -- %.2f y no tostring: el float suelta "0.80000001192093" (r1, 2026-08-25),
        -- que se lee como un valor raro cuando es el 0.8 del default
        line(W, "  cargo_pickup_gesture=" .. tostring(cvGesture:GetInt())
            .. "  cargo_pickup_gesture_time=" .. string.format("%.2f", cvGestureTime:GetFloat()))

        if (args[1] or "") ~= "play" then
            line(W, "  (agregar el argumento  play  para reproducirlo y medir que secuencia resolvio)")
            return
        end

        if not anim then return end
        GCAL:Play(ANIM)
        timer.Simple(0.05, function()
            local track = isfunction(GCAL.GetTrack) and GCAL:GetTrack("default") or nil
            if track == nil then
                line(R, "  REPRODUCCION: no hay track vivo -- el Play fue rechazado (mirar si la anim esta apagada en el menu de GCAL).")
                return
            end
            local seq = tostring(track.sequenceName)
            local ok = (seq == "interact") and not track.poseOnlyLegacy
            line(ok and G or R, "  secuencia resuelta: " .. seq
                .. "   poseOnly=" .. tostring(track.poseOnlyLegacy == true)
                .. "   seqID=" .. tostring(track.seqID))
            line(ok and G or R, "  duracion medida: " .. string.format("%.3f", track.duration or 0) .. " s"
                .. "   (esperado ~0.818 s leido del .mdl)")
            if not ok then
                line(R, "  ^ ESTE ES EL DEFECTO SILENCIOSO: GCAL cayo a otra secuencia. El gesto se ve mal y no hay error.")
            end
        end)
    end)

    return
end

-- ------------------------------------------------------------------
-- SERVER
-- ------------------------------------------------------------------

-- Armed by the world gate the moment it commits to a DELIBERATE take (the
-- WALK branch), consumed by Play on the success path. The flag is what keeps
-- the gesture off every OTHER route into the inventory — a trader purchase, a
-- loadout give, a grid move all reach the same give functions and none of them
-- is the player reaching for something on the floor. It is stamped with
-- CurTime because the delegated takes (corpus_cargo_item / corpus_cargo_cash
-- reach ENT:Use in the same engine call as the gate) must still see it, while
-- a stale flag from an earlier frame must not.
-- The pair is also the extension point for anything that grows a NEW way of
-- taking something off the floor — the interaction menu's `interaction` branch
-- (corpus/docs/Corpus_Interaccion_Arquitectura.md), which is going to let
-- plain props be picked up, is the one that will want it: Arm when the take is
-- committed, Play where it landed. Nothing else needs to be wired.
function CARGO.PickupAnim.Arm(ply)
    if not IsValid(ply) then return end
    ply.CargoTakeArmed = CurTime()
end

-- Call ONLY where the take actually landed (author call 2026-08-25: a take
-- refused for weight leaves the item on the floor and must not animate).
function CARGO.PickupAnim.Play(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if ply.CargoTakeArmed ~= CurTime() then return end
    ply.CargoTakeArmed = nil

    if not cvGesture:GetBool() then return end
    if not GCAL or not isfunction(GCAL.Play) then return end

    GCAL:Play(ANIM, nil, ply)

    -- Hold the gate for the length of the gesture. Both halves of what the
    -- author wants out of this live here: the animation is the tell that the
    -- take landed, and its cost is what stops a room being hoovered one press
    -- at a time.
    local hold = cvGestureTime:GetFloat()
    if hold > 0 then
        ply.CargoNextWorldUse = math.max(ply.CargoNextWorldUse or 0, CurTime() + hold)
    end
end
