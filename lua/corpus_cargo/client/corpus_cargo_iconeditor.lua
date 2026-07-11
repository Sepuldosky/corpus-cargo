-- corpus_cargo_iconeditor.lua — dev icon cam/footprint editor (CLIENT)
-- Cargo_ItemImages §8. cargo_icon_edit <defid> opens a live model preview
-- with orbit/zoom/pan framing controls and a manual footprint picker; Save
-- persists both as the def's data override (server-side via Corpus.Data,
-- synced back over the def snapshot — §10), invalidating the icon hash so
-- it re-renders. Print Lua emits the icon_cam/size block to canonize the
-- adjustment into defs that have editable code (autogen defs stay on the
-- data override — it is their only channel).
--
-- VGUI notes: no DScrollPanel anywhere here on purpose (DNumSlider and
-- friends collapse inside one — inherited trap list in CLAUDE.md).

local CARGO = Corpus.GetModule("cargo")

local T = CARGO.Theme
local NET_ICON_OVERRIDE = Corpus.Net.Register("cargo", "icon_override")

local FRAME_W, FRAME_H = 780, 620
local PREVIEW = 430

local editor -- single instance

-- ------------------------------------------------------------------
-- Wire: save/clear the override on the server (it owns def-level data)
-- ------------------------------------------------------------------

local function SendOverride(defid, blob, clear)
    net.Start(NET_ICON_OVERRIDE)
    net.WriteString(defid)
    net.WriteBool(clear == true)
    CARGO.Util.WriteBlob(blob or {})
    net.SendToServer()
end

-- ------------------------------------------------------------------
-- Editor frame
-- ------------------------------------------------------------------

local function OpenEditor(defid)
    local def = CARGO.Items.Get(defid)
    if def == nil then
        Corpus.Log("cargo", "icon_edit: def desconocida '" .. tostring(defid) .. "'")
        return
    end
    -- same model source the icon uses (viewmodel for ARC9), so the preview
    -- matches the generated PNG
    local model = CARGO.Icons.ModelFor(def)
    if not isstring(model) or not util.IsValidModel(model) then
        Corpus.Log("cargo", "icon_edit: '" .. defid .. "' no tiene modelo resoluble (fuente: "
            .. CARGO.Icons.ResolveIconSource(def) .. ")")
        return
    end

    if IsValid(editor) then editor:Remove() end

    editor = vgui.Create("DFrame")
    editor:SetSize(FRAME_W, FRAME_H)
    editor:Center()
    editor:SetTitle("Cargo icon editor — " .. defid)
    editor:MakePopup()

    -- ---------------- live preview (left) ----------------
    -- slot-colored backdrop behind the model panel: centering against the
    -- real cell background instead of the frame gray (author ask, gate pass)
    local backdrop = vgui.Create("DPanel", editor)
    backdrop:SetPos(10, 30)
    backdrop:SetSize(PREVIEW, PREVIEW)
    backdrop.Paint = function(_, w, h)
        T.PaintPanel(w, h, T.Colors.cell)
    end

    local mdl = vgui.Create("DModelPanel", editor)
    mdl:SetPos(10, 30)
    mdl:SetSize(PREVIEW, PREVIEW)
    mdl:SetModel(model)
    mdl.LayoutEntity = function() end -- no auto-spin: the camera is the tool

    local ent = mdl:GetEntity()
    local chosenFp = nil        -- footprint pick (nil = auto), set below
    local RefreshSliders = nil  -- assigned after the sliders exist

    -- framing guide: a footprint-aspect box + center cross over the preview.
    -- Approximate (the capture viewport has the footprint aspect, the preview
    -- is square) — the Result panel below shows the real PNG.
    mdl.PaintOver = function(_, w, h)
        local fp = chosenFp or CARGO.Icons.GetFootprint(defid)
        local aspect = fp.w / fp.h
        local gw = w - 40
        local gh = gw / aspect
        if gh > h - 40 then
            gh = h - 40
            gw = gh * aspect
        end
        local x, y = (w - gw) / 2, (h - gh) / 2
        surface.SetDrawColor(255, 255, 255, 45)
        surface.DrawOutlinedRect(x, y, gw, gh, 1)
        surface.SetDrawColor(255, 255, 255, 20)
        surface.DrawLine(w / 2, y, w / 2, y + gh)
        surface.DrawLine(x, h / 2, x + gw, h / 2)
    end

    -- orbit-camera state; roll is deliberately not editable
    local st = { target = vector_origin * 1, dist = 60, pitch = 15, yaw = 180, fov = 45 }

    local function ApplyCam()
        local ang = Angle(st.pitch, st.yaw, 0)
        local origin = st.target - ang:Forward() * st.dist
        mdl:SetCamPos(origin)
        mdl:SetLookAng(ang)
        mdl:SetFOV(st.fov)
    end

    -- seed the state from a native view table {origin, angles, fov}
    local function SeedFromView(view)
        local mn, mx = ent:GetRenderBounds()
        local center = (mn + mx) * 0.5
        st.pitch, st.yaw = view.angles.p, view.angles.y
        st.dist = math.max(2, view.origin:Distance(center))
        st.target = view.origin + view.angles:Forward() * st.dist
        st.fov = view.fov or 45
        ApplyCam()
        if RefreshSliders then RefreshSliders() end
    end

    SeedFromView(CARGO.Icons.ResolveCam(def, ent)) -- current effective cam (§4)

    -- orbit (LMB) / pan (RMB) / zoom (wheel)
    mdl.OnMousePressed = function(self, mcode)
        self.dragMode = mcode == MOUSE_LEFT and "orbit"
            or mcode == MOUSE_RIGHT and "pan" or nil
        self.lastX, self.lastY = gui.MousePos()
        self:MouseCapture(self.dragMode ~= nil)
    end
    mdl.OnMouseReleased = function(self)
        self.dragMode = nil
        self:MouseCapture(false)
    end
    mdl.OnCursorMoved = function(self)
        if self.dragMode == nil then return end
        local x, y = gui.MousePos()
        local dx, dy = x - (self.lastX or x), y - (self.lastY or y)
        self.lastX, self.lastY = x, y

        if self.dragMode == "orbit" then
            st.yaw = st.yaw - dx * 0.5
            st.pitch = math.Clamp(st.pitch + dy * 0.5, -89, 89)
        else
            local ang = Angle(st.pitch, st.yaw, 0)
            local scale = st.dist * 0.002
            st.target = st.target - ang:Right() * (dx * scale) + ang:Up() * (dy * scale)
        end
        ApplyCam()
        if RefreshSliders then RefreshSliders() end
    end
    mdl.OnMouseWheeled = function(_, delta)
        st.dist = math.Clamp(st.dist * (1 - delta * 0.1), 2, 4096)
        ApplyCam()
        if RefreshSliders then RefreshSliders() end
        return true
    end

    local hint = vgui.Create("DLabel", editor)
    hint:SetPos(10, 32 + PREVIEW)
    hint:SetSize(PREVIEW, 40)
    hint:SetWrap(true)
    hint:SetText("LMB drag: orbit  ·  RMB drag: pan  ·  Wheel: zoom  ·  sliders for fine steps\nModel: " .. model)

    -- ---------------- controls (right) ----------------
    local RX, RW = PREVIEW + 22, FRAME_W - PREVIEW - 34
    local y = 34

    local function Label(text)
        local lbl = vgui.Create("DLabel", editor)
        lbl:SetPos(RX, y)
        lbl:SetSize(RW, 16)
        lbl:SetText(text)
        y = y + 18
        return lbl
    end

    Label("Camera (saved as data override — §4.3)")

    -- live numeric readout of what Save would persist
    local readout = vgui.Create("DLabel", editor)
    readout:SetPos(RX, y)
    readout:SetSize(RW, 34)
    readout:SetWrap(true)
    readout.Think = function(self)
        local ang = Angle(st.pitch, st.yaw, 0)
        local origin = st.target - ang:Forward() * st.dist
        self:SetText(string.format("pos %.1f %.1f %.1f\nang %.1f %.1f 0.0   fov %.1f",
            origin.x, origin.y, origin.z, st.pitch, st.yaw, st.fov))
    end
    y = y + 38

    -- fine-step sliders, two-way synced with the mouse controls (guarded so
    -- programmatic SetValue does not loop through OnValueChanged)
    local syncing = false
    local function MakeSlider(text, min, max, decimals, get, set)
        local sl = vgui.Create("DNumSlider", editor)
        sl:SetPos(RX, y)
        sl:SetSize(RW, 22)
        sl:SetText(text)
        sl:SetMin(min)
        sl:SetMax(max)
        sl:SetDecimals(decimals)
        sl:SetValue(get())
        sl.OnValueChanged = function(_, v)
            if syncing then return end
            set(v)
            ApplyCam()
        end
        y = y + 26
        return sl
    end

    local slPitch = MakeSlider("Pitch", -89, 89, 1,
        function() return st.pitch end,
        function(v) st.pitch = math.Clamp(v, -89, 89) end)
    local slYaw = MakeSlider("Yaw", -180, 540, 1,
        function() return st.yaw end,
        function(v) st.yaw = v end)
    local slDist = MakeSlider("Distance", 2, math.max(400, st.dist * 3), 1,
        function() return st.dist end,
        function(v) st.dist = math.max(2, v) end)
    local slFov = MakeSlider("FOV", 5, 120, 1,
        function() return st.fov end,
        function(v) st.fov = math.Clamp(v, 1, 170) end)

    RefreshSliders = function()
        syncing = true
        slPitch:SetValue(st.pitch)
        slYaw:SetValue(st.yaw)
        slDist:SetValue(st.dist)
        slFov:SetValue(st.fov)
        syncing = false
    end
    y = y + 6

    -- two starting views: the Cargo auto (side profile for weapons/melee,
    -- STALKER-style) and the engine's isometric spawnicon
    local autoBtn = vgui.Create("DButton", editor)
    autoBtn:SetPos(RX, y)
    autoBtn:SetSize((RW - 6) / 2, 24)
    autoBtn:SetText("Auto frame (Cargo)")
    autoBtn.DoClick = function()
        SeedFromView(CARGO.Icons.AutoView(def, ent))
    end
    local isoBtn = vgui.Create("DButton", editor)
    isoBtn:SetPos(RX + (RW + 6) / 2, y)
    isoBtn:SetSize((RW - 6) / 2, 24)
    isoBtn:SetText("Engine isometric")
    isoBtn.DoClick = function()
        SeedFromView(PositionSpawnIcon(ent, vector_origin, false))
    end
    y = y + 34

    Label("Footprint (allowed set, §5)")

    local fpCombo = vgui.Create("DComboBox", editor)
    fpCombo:SetPos(RX, y)
    fpCombo:SetSize(RW, 24)
    -- chosenFp declared next to the preview (the framing guide reads it)
    local current = CARGO.Icons.GetFootprint(defid)
    local ovrSize = istable(def.icon_override) and def.icon_override.size or nil
    fpCombo:AddChoice("auto (quantized OBB)", nil, ovrSize == nil)
    for _, fp in ipairs(CARGO.Items.ICON_FOOTPRINTS) do
        local isCurrent = istable(ovrSize) and ovrSize.w == fp[1] and ovrSize.h == fp[2]
        fpCombo:AddChoice(fp[1] .. " x " .. fp[2], { w = fp[1], h = fp[2] }, isCurrent)
    end
    fpCombo.OnSelect = function(_, _, _, data)
        chosenFp = istable(data) and data or nil
    end
    if istable(ovrSize) then chosenFp = { w = ovrSize.w, h = ovrSize.h } end
    y = y + 28

    local fpInfo = Label("effective now: " .. current.w .. " x " .. current.h)
    fpInfo.Think = function(self)
        local eff = CARGO.Icons.GetFootprint(defid)
        self:SetText("effective now: " .. eff.w .. " x " .. eff.h)
    end
    y = y + 8

    -- ---------------- result preview ----------------
    Label("Result (live cache — letter means queued or no model)")

    local result = vgui.Create("DPanel", editor)
    result:SetPos(RX, y)
    result:SetSize(RW, 130)
    result.Paint = function(_, w, h)
        T.PaintPanel(w, h, T.Colors.cell)
        local mat = CARGO.Icons.Get(defid)
        if mat ~= nil then
            T.DrawIconFit(mat, 4, 4, w - 8, h - 8)
        else
            draw.SimpleText(string.upper((def.name or defid):sub(1, 1)), "CargoTitle",
                w / 2, h / 2, T.Colors.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    y = y + 138

    -- ---------------- actions ----------------
    local function CamBlob()
        local ang = Angle(st.pitch, st.yaw, 0)
        local origin = st.target - ang:Forward() * st.dist
        return {
            pos = { x = origin.x, y = origin.y, z = origin.z },
            ang = { p = st.pitch, y = st.yaw, r = 0 },
            fov = st.fov,
        }
    end

    local function MakeButton(text, doClick)
        local btn = vgui.Create("DButton", editor)
        btn:SetPos(RX, y)
        btn:SetSize(RW, 26)
        btn:SetText(text)
        btn.DoClick = doClick
        y = y + 32
        return btn
    end

    MakeButton("Save (persist override + re-render)", function()
        local blob = { cam = CamBlob(), size = chosenFp }
        SendOverride(defid, blob, false)
        -- local echo for instant feedback; the server resync confirms it
        def.icon_override = blob
        CARGO.Icons.Invalidate(defid)
        Corpus.Log("cargo", "icon_edit: override de '" .. defid .. "' enviado")
    end)

    MakeButton("Print Lua (canonize into the def)", function()
        local cam = CamBlob()
        print("-- Cargo icon block for '" .. defid .. "' — paste into its def:")
        print(string.format(
            "icon_cam = { pos = { x = %.2f, y = %.2f, z = %.2f }, ang = { p = %.2f, y = %.2f, r = %.2f }, fov = %.1f },",
            cam.pos.x, cam.pos.y, cam.pos.z, cam.ang.p, cam.ang.y, cam.ang.r, cam.fov))
        if istable(chosenFp) then
            print(string.format("size = { %d, %d },", chosenFp.w, chosenFp.h))
        end
        Corpus.Log("cargo", "icon_edit: bloque Lua impreso en consola")
    end)

    MakeButton("Clear override (back to code/auto)", function()
        SendOverride(defid, nil, true)
        def.icon_override = nil
        CARGO.Icons.Invalidate(defid)
        Corpus.Log("cargo", "icon_edit: override de '" .. defid .. "' borrado")
    end)
end

-- ------------------------------------------------------------------
-- Public surface: the Q-menu tab (corpus_cargo_options.lua) embeds the
-- browser so editable items are picked visually instead of typing defids.
-- ------------------------------------------------------------------

CARGO.IconEditor = CARGO.IconEditor or {}
CARGO.IconEditor.Open = OpenEditor

-- Browser panel: search box + scrollable list of every def the editor can
-- frame (resolvable model). Rebuilds itself when the editable-def count
-- changes — captured weapons register after the spawnmenu was built.
function CARGO.IconEditor.BuildBrowser(parent)
    local wrap = vgui.Create("DPanel", parent)
    wrap:SetTall(340)
    wrap.Paint = function(_, w, h) T.PaintPanel(w, h, T.Colors.panelAlt) end

    local search = vgui.Create("DTextEntry", wrap)
    search:Dock(TOP)
    search:SetTall(24)
    search:DockMargin(4, 4, 4, 4)
    search:SetPlaceholderText("Filter by name or id...")

    -- docked buttons inside a DScrollPanel are safe (the inherited traps
    -- are DIconLayout/DNumSlider/DPropertySheet, see CLAUDE.md)
    local scroll = vgui.Create("DScrollPanel", wrap)
    scroll:Dock(FILL)
    scroll:DockMargin(4, 0, 4, 4)

    local function EditableRows(needle)
        local rows = {}
        for id, def in pairs(CARGO.Items._defs) do
            if CARGO.Icons.ResolveIconSource(def) == "render" then
                local name = isstring(def.name) and def.name or id
                if needle == "" or string.find(string.lower(name), needle, 1, true)
                    or string.find(string.lower(id), needle, 1, true) then
                    rows[#rows + 1] = { id = id, name = name }
                end
            end
        end
        table.sort(rows, function(a, b) return a.name < b.name end)
        return rows
    end

    local function Rebuild()
        scroll:Clear()
        local rows = EditableRows(string.lower(string.Trim(search:GetValue() or "")))

        for _, row in ipairs(rows) do
            local btn = scroll:Add("DButton")
            btn:Dock(TOP)
            btn:SetTall(24)
            btn:DockMargin(0, 0, 0, 2)
            btn:SetText("")
            btn:SetTooltip(row.id)
            btn.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h,
                    self:IsHovered() and T.Colors.cellHover or T.Colors.cell)
                draw.SimpleText(T.FitText(row.name, "CargoSmall", w - 12), "CargoSmall",
                    6, h / 2, T.Colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            btn.DoClick = function() CARGO.IconEditor.Open(row.id) end
        end

        if #rows == 0 then
            local lbl = scroll:Add("DLabel")
            lbl:Dock(TOP)
            lbl:SetTall(20)
            lbl:SetText("  (no editable items — a def needs a resolvable model)")
        end
    end

    search.OnValueChange = function() Rebuild() end

    -- dirty-check while visible: new editable defs (weapon capture) refresh
    -- the list without reopening the spawnmenu
    local lastCount, nextCheck = -1, 0
    wrap.Think = function()
        if CurTime() < nextCheck then return end
        nextCheck = CurTime() + 1
        local n = #EditableRows("")
        if n ~= lastCount then
            lastCount = n
            Rebuild()
        end
    end

    return wrap
end

-- ------------------------------------------------------------------
-- Commands. TODO: gate behind the future Corpus admin permission
-- primitive (own design session pending, roadmap #12) — same standing
-- TODO as the rest of Cargo's dev commands; open until then.
-- ------------------------------------------------------------------

concommand.Add("cargo_icon_edit", function(_, _, args)
    local defid = isstring(args and args[1]) and args[1] or ""
    if defid == "" then
        Corpus.Log("cargo", "uso: cargo_icon_edit <defid>")
        return
    end
    OpenEditor(defid)
end, function(_, argStr)
    -- autocomplete only over defs the editor can actually frame (resolvable
    -- model): hand-icon defs like the ARC9 atts are not editable and used to
    -- drown the list (first gate pass 2026-07-11)
    local needle = string.lower(string.Trim(argStr or ""))
    local out = {}
    for id, def in SortedPairs(CARGO.Items._defs) do
        if CARGO.Icons.ResolveIconSource(def) == "render"
            and (needle == "" or string.find(string.lower(id), needle, 1, true)) then
            out[#out + 1] = "cargo_icon_edit " .. id
            if #out >= 30 then break end
        end
    end
    return out
end, "Opens the icon cam/footprint editor for an item def (dev)")

concommand.Add("cargo_icon_regen_all", function()
    CARGO.Icons.RegenAll()
end, nil, "Invalidates and lazily re-renders the whole icon cache (dev)")
