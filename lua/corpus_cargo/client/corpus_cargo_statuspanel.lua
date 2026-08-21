-- corpus_cargo_statuspanel.lua — registrable stat-bars panel (CLIENT)
-- Cargo_Architecture.md §11. Cargo owns the panel, NOT the content: modules
-- register bars (Craving: hambre/hidratación, Coagulant: vital/sangre,
-- Caliber B3: protección) and absent modules simply never register —
-- honest degradation, the panel just shows fewer rows.
--
-- OVERFILL (§11.1, CRG-68, roadmap #59). A registrant whose stat can go past
-- "full" — Craving's hunger reaches 150 and eating past 100 risks vomiting —
-- declares `softMax`/`hardMax`, and the excess is painted as hatching ON TOP of
-- the full bar plus a `+38` next to the label.
--
-- THE DEFECT IT CLOSES IS ONE LINE AND IT WAS MEASURED: the poll used to clamp
-- to 0..100, so 138 did not overflow the bar — it left it FULL AND MUTE. The
-- player saw exactly the same thing at 100 as at 149, and at 149 the next bite
-- makes him throw up. That is worse than an overflow: an overflow is visible.
--
-- CRG-68 IS THE LIMIT: the panel draws MAGNITUDE, never MEANING. `softMax` and
-- `hardMax` are data OF THE REGISTRANT — Cargo does not know what a vomit is,
-- nor that one exists. It is CRG-1 on the one surface where the temptation is
-- real, because here the number arrives with a consequence already attached.

local CARGO = Corpus.GetModule("cargo")

CARGO.StatusPanel = CARGO.StatusPanel or {}
CARGO.StatusPanel._bars = CARGO.StatusPanel._bars or {}

local T = CARGO.Theme

-- Public contract. spec: { id = string, label = string, getValue =
-- function(ply) -> 0..hardMax, color = Color?, softMax = number?,
-- hardMax = number?, overfillColor = Color? }. Re-registering module+id
-- replaces in place (lua refresh friendly).
--
-- DEGRADES IN BOTH DIRECTIONS, and that is what makes this cheap enough that
-- it never blocked Craving: a registrant that declares none of the three new
-- fields gets softMax = 100 and hardMax = softMax, which is the clamp and the
-- fill of before, to the pixel; and an OLDER Cargo receiving the three fields
-- ignores keys it does not know and paints as it always did. Neither half
-- needs to know the other's version.
function CARGO.StatusPanel.RegisterBar(module, spec)
    if not isstring(module) or module == "" then
        error("Cargo.StatusPanel.RegisterBar: 'module' must be a non-empty string", 2)
    end
    if not istable(spec) or not isstring(spec.id) or not isfunction(spec.getValue) then
        error("Cargo.StatusPanel.RegisterBar: spec needs id (string) and getValue (function)", 2)
    end

    -- A softMax of 0 or less would divide by zero in BarFrac; a hardMax under
    -- softMax would make the excess negative. Both are registrant bugs and both
    -- fall back to the no-overfill shape instead of erroring: a stat bar that
    -- refuses to exist is a worse answer than one that ignores a bad ceiling.
    local softMax = tonumber(spec.softMax) or 100
    if softMax <= 0 then softMax = 100 end
    local hardMax = tonumber(spec.hardMax) or softMax
    if hardMax < softMax then hardMax = softMax end

    local bar = {
        module = module,
        id = spec.id,
        label = spec.label or spec.id,
        color = spec.color or T.Colors.green,
        getValue = spec.getValue,
        softMax = softMax,
        hardMax = hardMax,
        -- §11.1 says T.Colors.warn; the live palette has no `warn` key — its
        -- fixed warning signal is `orange` (read in corpus_cargo_theme.lua:
        -- amber/orange/red stay fixed signal colors under ANY DGL4 tint, so
        -- they still read as warnings when everything else takes the HUD hue).
        overfillColor = spec.overfillColor or T.Colors.orange,
    }

    for i, existing in ipairs(CARGO.StatusPanel._bars) do
        if existing.module == module and existing.id == spec.id then
            CARGO.StatusPanel._bars[i] = bar
            return
        end
    end
    CARGO.StatusPanel._bars[#CARGO.StatusPanel._bars + 1] = bar
end

-- ------------------------------------------------------------------
-- The three pure readings of a bar. They are functions and not inline
-- arithmetic inside the Paint closure for the reason §11.1 exists: a Paint is
-- a closure with no name and no surface to draw on offline, so the ONE thing
-- that separates "full and mute" from "full and speaking" would be the one
-- thing no check could reach. Here 138 and 149 answer differently, in a test.
-- ------------------------------------------------------------------

-- The normal fill. RULE 1 of §11.1 and the reason nothing re-paints: the
-- value is clamped to softMax before dividing, so a bar with no softMax is
-- v/100 exactly as it was.
function CARGO.StatusPanel.BarFrac(bar)
    if not istable(bar) then return 0 end
    local soft = tonumber(bar.softMax) or 100
    if soft <= 0 then return 0 end
    return math.Clamp((tonumber(bar._value) or 0) / soft, 0, 1)
end

-- How much of the bar the hatching covers. RULE 3: the excess is a FRACTION of
-- the same width, never extra width — a bar that grew past its frame would lie
-- about what "full" means.
function CARGO.StatusPanel.OverFrac(bar)
    if not istable(bar) then return 0 end
    local soft = tonumber(bar.softMax) or 100
    local hard = tonumber(bar.hardMax) or soft
    if hard <= soft then return 0 end
    local over = (tonumber(bar._value) or 0) - soft
    if over <= 0 then return 0 end
    return math.Clamp(over / (hard - soft), 0, 1)
end

-- RULE 5: besides the hatching, the FIGURE. No signal travels by color alone
-- nor by texture alone — there is colorblindness and there are 9 px bars.
-- Returns nil when there is no excess, so the caller has nothing to draw.
function CARGO.StatusPanel.OverLabel(bar)
    if not istable(bar) then return nil end
    local soft = tonumber(bar.softMax) or 100
    local over = (tonumber(bar._value) or 0) - soft
    if over <= 0 then return nil end
    return "+" .. tostring(math.floor(over + 0.5))
end

-- Builds the panel section. Values refresh in place on a throttle: the
-- rows keep references to their bar tables, nothing is rebuilt per frame
-- (the SetValue-re-entrancy trap does not apply — there are no inputs).
function CARGO.StatusPanel.Build(parent)
    local panel = vgui.Create("DPanel", parent)
    panel.Paint = function(_, w, h) T.PaintPanel(w, h) end

    local ROW_H, PAD = 22, 10

    panel.PaintOver = function(self, w)
        draw.SimpleText("Status", "CargoHeading", PAD, 8, T.Colors.textDim)

        local y = 36
        for _, bar in ipairs(CARGO.StatusPanel._bars) do
            local bx, by, bw, bh = PAD + 16, y + 6, w * 0.5, 9

            surface.SetDrawColor(bar.color)
            surface.DrawRect(PAD, y + 7, 8, 8)
            T.DrawBar(bx, by, bw, bh, CARGO.StatusPanel.BarFrac(bar), bar.color)

            -- the excess, hatched OVER the already-full bar (rule 3/4)
            local overFrac = CARGO.StatusPanel.OverFrac(bar)
            if overFrac > 0 then
                T.DrawHatch(self, bx, by, bw, bh, overFrac, bar.overfillColor)
            end

            draw.SimpleText(bar.label, "CargoSmall", w - PAD, y + 4,
                T.Colors.textDim, TEXT_ALIGN_RIGHT)

            local overLabel = CARGO.StatusPanel.OverLabel(bar)
            if overLabel ~= nil then
                surface.SetFont("CargoSmall")
                local lw = surface.GetTextSize(bar.label)
                draw.SimpleText(overLabel, "CargoSmall", w - PAD - lw - 6, y + 4,
                    bar.overfillColor, TEXT_ALIGN_RIGHT)
            end

            y = y + ROW_H
        end

        if #CARGO.StatusPanel._bars == 0 then
            draw.SimpleText("No bars registered (absent modules)", "CargoSmall",
                PAD, 36, T.Colors.textDim)
        end
    end

    panel._nextPoll = 0
    panel.Think = function(self)
        if CurTime() < self._nextPoll then return end
        self._nextPoll = CurTime() + 0.25

        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        for _, bar in ipairs(CARGO.StatusPanel._bars) do
            -- a broken getValue from one module must not kill the panel
            local ok, v = pcall(bar.getValue, ply)
            -- RULE 2: the clamp is hardMax, which DEFAULTS to softMax — so for
            -- the four bars that exist today it is still 100. This one line is
            -- the whole defect of roadmap #59: with `0, 100` here, every
            -- reading above 100 arrived as 100 and the three functions above
            -- could not tell 138 from 149 no matter what they computed.
            bar._value = ok and math.Clamp(tonumber(v) or 0, 0, bar.hardMax or 100) or 0
        end
    end

    return panel
end
