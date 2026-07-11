-- corpus_cargo_transfer.lua — container transfer panel (CLIENT)
-- Cargo_Architecture.md §8: same grid, side by side (container | own
-- inventory), Take all / Move all — spec taken from STALKER Anomaly.
-- Opens when the server answers a container USE with a snapshot.

local CARGO = Corpus.GetModule("cargo")

CARGO.Transfer = CARGO.Transfer or {}
local T = CARGO.Theme

local NET_CONT_OPEN  = Corpus.Net.Register("cargo", "container_open")
local NET_CONT_SYNC  = Corpus.Net.Register("cargo", "container_sync")
local NET_CONT_CLOSE = Corpus.Net.Register("cargo", "container_close")
local NET_TRANSFER   = Corpus.Net.Register("cargo", "transfer")
local NET_TAKEALL    = Corpus.Net.Register("cargo", "takeall")

local frame, contState, contGrid, ownGrid

local function SendTransfer(dir, ref, count)
    if contState == nil then return end
    net.Start(NET_TRANSFER)
    net.WriteUInt(contState.contId, 16)
    net.WriteString(dir)
    net.WriteUInt(math.min(count or 1, 65535), 16)
    CARGO.Util.WriteBlob(ref)
    net.SendToServer()
end

local function SendTakeAll(dir)
    if contState == nil then return end
    net.Start(NET_TAKEALL)
    net.WriteUInt(contState.contId, 16)
    net.WriteString(dir)
    net.SendToServer()
end

local function TransferMenu(dir, entry)
    local menu = DermaMenu()
    local verb = dir == "take" and "Take" or "Move"
    menu:AddOption(verb .. " 1", function()
        SendTransfer(dir, CARGO.Grid.RefOf(entry), 1)
    end)
    if (entry.count or 1) > 1 then
        menu:AddOption(verb .. " whole stack (x" .. entry.count .. ")", function()
            SendTransfer(dir, CARGO.Grid.RefOf(entry), entry.count)
        end)
    end
    menu:Open()
end

local function BuildFrame()
    if IsValid(frame) then frame:Remove() end

    local W = math.min(ScrW() - 120, 940)
    local H = math.min(ScrH() - 120, 560)

    frame = vgui.Create("DFrame")
    frame:SetSize(W, H)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(true)
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(false)
    frame.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, T.Colors.bg)
        surface.SetDrawColor(T.Colors.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    frame.OnClose = function()
        CARGO.Tooltip.Hide()
        if contState then
            net.Start(NET_CONT_CLOSE)
            net.WriteUInt(contState.contId, 16)
            net.SendToServer()
        end
        contState = nil
        surface.PlaySound("backpack/inv_close.wav")
    end

    -- ---------------- container half ----------------
    local leftHalf = vgui.Create("Panel", frame)
    leftHalf:Dock(LEFT)
    leftHalf:SetWide(W / 2 - 14)
    leftHalf:DockMargin(10, 28, 4, 10)

    local contHeader = vgui.Create("DPanel", leftHalf)
    contHeader:Dock(TOP)
    contHeader:SetTall(34)
    contHeader.Paint = function(_, w, h)
        T.PaintPanel(w, h)
        if contState == nil then return end
        draw.SimpleText(contState.name or "Container", "CargoHeading", 10, 8, T.Colors.text)
        local capText = contState.capacity == nil and "∞"
            or string.format("%.1f kg", contState.capacity)
        local wTxt = string.format("%.1f kg / %s", contState.weight or 0, capText)
        draw.SimpleText(wTxt, "CargoText", w - 10, 9, T.Colors.textDim, TEXT_ALIGN_RIGHT)
    end

    local takeAll = vgui.Create("DButton", leftHalf)
    takeAll:Dock(BOTTOM)
    takeAll:SetTall(28)
    takeAll:DockMargin(0, 6, 0, 0)
    takeAll:SetText("")
    takeAll.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h,
            self:IsHovered() and T.Colors.cellHover or T.Colors.panelAlt)
        draw.SimpleText("Take all →", "CargoText", w / 2, h / 2,
            T.Colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    takeAll.DoClick = function() SendTakeAll("take") end

    contGrid = CARGO.Grid.Create(leftHalf, {
        getEntries = function() return contState and contState.items or {} end,
        dragSource = "cont",
        onLeftClick = function(entry)
            SendTransfer("take", CARGO.Grid.RefOf(entry), entry.count or 1)
        end,
        onRightClick = function(entry) TransferMenu("take", entry) end,
        -- dropping an own-inventory cell here puts it into the container
        onReceiveDrop = function(cell)
            if cell.cargoSource == "own" and cell.cargoEntry then
                SendTransfer("put", CARGO.Grid.RefOf(cell.cargoEntry),
                    cell.cargoEntry.count or 1)
            end
        end,
    })
    contGrid.panel:Dock(FILL)
    contGrid.panel:DockMargin(0, 6, 0, 0)

    -- ---------------- own inventory half ----------------
    local rightHalf = vgui.Create("Panel", frame)
    rightHalf:Dock(FILL)
    rightHalf:DockMargin(4, 28, 10, 10)

    local ownHeader = vgui.Create("DPanel", rightHalf)
    ownHeader:Dock(TOP)
    ownHeader:SetTall(34)
    ownHeader.Paint = function(_, w, h)
        T.PaintPanel(w, h)
        draw.SimpleText("Your inventory", "CargoHeading", 10, 8, T.Colors.text)
        local snap = CARGO.ClientState
        if snap == nil then return end
        local frac = snap.capacity > 0 and snap.weight / snap.capacity or 0
        draw.SimpleText(string.format("%.1f kg / %.1f kg", snap.weight, snap.capacity),
            "CargoText", w - 10, 9, T.WeightColor(frac), TEXT_ALIGN_RIGHT)
    end

    local moveAll = vgui.Create("DButton", rightHalf)
    moveAll:Dock(BOTTOM)
    moveAll:SetTall(28)
    moveAll:DockMargin(0, 6, 0, 0)
    moveAll:SetText("")
    moveAll.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h,
            self:IsHovered() and T.Colors.cellHover or T.Colors.panelAlt)
        draw.SimpleText("← Move all", "CargoText", w / 2, h / 2,
            T.Colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    moveAll.DoClick = function() SendTakeAll("put") end

    ownGrid = CARGO.Grid.Create(rightHalf, {
        getEntries = function()
            local snap = CARGO.ClientState
            return snap and snap.items or {}
        end,
        dragSource = "own",
        onLeftClick = function(entry)
            SendTransfer("put", CARGO.Grid.RefOf(entry), entry.count or 1)
        end,
        onRightClick = function(entry) TransferMenu("put", entry) end,
        -- dropping a container cell here takes it
        onReceiveDrop = function(cell)
            if cell.cargoSource == "cont" and cell.cargoEntry then
                SendTransfer("take", CARGO.Grid.RefOf(cell.cargoEntry),
                    cell.cargoEntry.count or 1)
            end
        end,
    })
    ownGrid.panel:Dock(FILL)
    ownGrid.panel:DockMargin(0, 6, 0, 0)

    contGrid.Refresh()
    ownGrid.Refresh()
    surface.PlaySound("backpack/inv_open.wav")
end

-- the ui file calls this on every inventory sync while the panel is open
function CARGO.Transfer.RefreshOwn()
    if IsValid(frame) and ownGrid then ownGrid.Refresh() end
end

net.Receive(NET_CONT_OPEN, function()
    contState = CARGO.Util.ReadBlob()
    if contState then BuildFrame() end
end)

net.Receive(NET_CONT_SYNC, function()
    local snap = CARGO.Util.ReadBlob()
    if snap == nil then return end
    if contState and snap.contId == contState.contId and IsValid(frame) then
        contState = snap
        contGrid.Refresh()
    end
end)
