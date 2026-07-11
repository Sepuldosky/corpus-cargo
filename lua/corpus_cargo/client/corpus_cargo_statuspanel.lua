-- corpus_cargo_statuspanel.lua — registrable stat-bars panel (CLIENT)
-- Cargo_Architecture.md §11. Cargo owns the panel, NOT the content: modules
-- register bars (Craving: hambre/hidratación, Coagulant: vital/sangre,
-- Caliber B3: protección) and absent modules simply never register —
-- honest degradation, the panel just shows fewer rows.

local CARGO = Corpus.GetModule("cargo")

CARGO.StatusPanel = CARGO.StatusPanel or {}
CARGO.StatusPanel._bars = CARGO.StatusPanel._bars or {}

local T = CARGO.Theme

-- Public contract. spec: { id = string, label = string, getValue =
-- function(ply) -> 0..100, color = Color? }. Re-registering module+id
-- replaces in place (lua refresh friendly).
function CARGO.StatusPanel.RegisterBar(module, spec)
    if not isstring(module) or module == "" then
        error("Cargo.StatusPanel.RegisterBar: 'module' must be a non-empty string", 2)
    end
    if not istable(spec) or not isstring(spec.id) or not isfunction(spec.getValue) then
        error("Cargo.StatusPanel.RegisterBar: spec needs id (string) and getValue (function)", 2)
    end

    local bar = {
        module = module,
        id = spec.id,
        label = spec.label or spec.id,
        color = spec.color or T.Colors.green,
        getValue = spec.getValue,
    }

    for i, existing in ipairs(CARGO.StatusPanel._bars) do
        if existing.module == module and existing.id == spec.id then
            CARGO.StatusPanel._bars[i] = bar
            return
        end
    end
    CARGO.StatusPanel._bars[#CARGO.StatusPanel._bars + 1] = bar
end

-- Builds the panel section. Values refresh in place on a throttle: the
-- rows keep references to their bar tables, nothing is rebuilt per frame
-- (the SetValue-re-entrancy trap does not apply — there are no inputs).
function CARGO.StatusPanel.Build(parent)
    local panel = vgui.Create("DPanel", parent)
    panel.Paint = function(_, w, h) T.PaintPanel(w, h) end

    local ROW_H, PAD = 22, 10

    panel.PaintOver = function(_, w)
        draw.SimpleText("Status", "CargoHeading", PAD, 8, T.Colors.textDim)
        draw.SimpleText("registrable stat-bars", "CargoSmall", w - PAD, 12,
            T.Colors.textDim, TEXT_ALIGN_RIGHT)

        local y = 36
        for _, bar in ipairs(CARGO.StatusPanel._bars) do
            local frac = (bar._value or 0) / 100
            surface.SetDrawColor(bar.color)
            surface.DrawRect(PAD, y + 7, 8, 8)
            T.DrawBar(PAD + 16, y + 6, w * 0.5, 9, frac, bar.color)
            draw.SimpleText(bar.label, "CargoSmall", w - PAD, y + 4,
                T.Colors.textDim, TEXT_ALIGN_RIGHT)
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
            bar._value = ok and math.Clamp(tonumber(v) or 0, 0, 100) or 0
        end
    end

    return panel
end
