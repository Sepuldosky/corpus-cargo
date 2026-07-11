-- corpus_cargo_ui.lua — main inventory frame (CLIENT)
-- Layout frozen against docs/mockups/InventarioCargo.png: left column
-- (equipment slots, quick slots, status panel), right column (profile
-- header, category tabs, grid, weight footer). The mock is CSS — here it
-- is manual layout (Dock/SetPos/Paint), per the VGUI notes inherited from
-- ADS. All Paint closures read the last synced snapshot, so a new sync
-- refreshes in place without rebuilding the frame.

local CARGO = Corpus.GetModule("cargo")

CARGO.UI = CARGO.UI or {}
local T = CARGO.Theme

-- same names the server registered; on the client Register only builds the
-- full string (AddNetworkString is server-side)
local NET_OPEN      = Corpus.Net.Register("cargo", "open")
local NET_SYNC      = Corpus.Net.Register("cargo", "sync")
local NET_NOTICE    = Corpus.Net.Register("cargo", "notice")
local NET_EQUIP     = Corpus.Net.Register("cargo", "equip")
local NET_UNEQUIP   = Corpus.Net.Register("cargo", "unequip")
local NET_USE       = Corpus.Net.Register("cargo", "use")
local NET_DROP      = Corpus.Net.Register("cargo", "drop")
local NET_QUICKBIND = Corpus.Net.Register("cargo", "quickbind")
local NET_QUICKUSE  = Corpus.Net.Register("cargo", "quickuse")
local NET_AMMOGROUP = Corpus.Net.Register("cargo", "ammogroup")
local NET_SUB_ATT   = Corpus.Net.Register("cargo", "subslot_attach")
local NET_SUB_DET   = Corpus.Net.Register("cargo", "subslot_detach")

local cvKey = CreateClientConVar("cargo_key_inventory", tostring(KEY_I), true, false,
    "Key (KEY_* enum) that opens the Cargo inventory")
local cvQuickF = CreateClientConVar("cargo_quick_f", "1", true, false,
    "Intercept F1-F4 as Cargo quick slots")

local frame, grid, pendingOpen

local function S() return CARGO.ClientState end

-- ------------------------------------------------------------------
-- Wire helpers
-- ------------------------------------------------------------------

local function SendEquip(ref, slotId)
    net.Start(NET_EQUIP) CARGO.Util.WriteBlob(ref) net.WriteString(slotId) net.SendToServer()
end
local function SendUnequip(slotId)
    net.Start(NET_UNEQUIP) net.WriteString(slotId) net.SendToServer()
end
local function SendUse(ref)
    net.Start(NET_USE) CARGO.Util.WriteBlob(ref) net.SendToServer()
end
local function SendDrop(ref, count)
    net.Start(NET_DROP) CARGO.Util.WriteBlob(ref) net.WriteUInt(count or 1, 16) net.SendToServer()
end
local function SendQuickBind(n, itemId)
    net.Start(NET_QUICKBIND) net.WriteUInt(n, 4) net.WriteString(itemId or "") net.SendToServer()
end
local function SendQuickUse(n)
    net.Start(NET_QUICKUSE) net.WriteUInt(n, 4) net.SendToServer()
end
local function SendAmmoGroup(uid, group)
    net.Start(NET_AMMOGROUP) net.WriteString(uid) net.WriteString(group) net.SendToServer()
end
local function SendSubAttach(hostUid, subId, ref)
    net.Start(NET_SUB_ATT) net.WriteString(hostUid) net.WriteString(subId)
    CARGO.Util.WriteBlob(ref) net.SendToServer()
end
local function SendSubDetach(hostUid, subId, index)
    net.Start(NET_SUB_DET) net.WriteString(hostUid) net.WriteString(subId)
    net.WriteUInt(index, 8) net.SendToServer()
end

-- ------------------------------------------------------------------
-- Context menus
-- ------------------------------------------------------------------

-- every owned host instance (equipped or in grid) with declared sub-slots
local function OwnedHosts()
    local snap = S()
    local out = {}
    if snap == nil then return out end
    for _, slotEntry in pairs(snap.equip or {}) do
        local def = CARGO.Items.Get(slotEntry.id)
        if def and istable(def.subslots) then
            out[#out + 1] = { uid = slotEntry.uid, def = def, blob = slotEntry.blob }
        end
    end
    for _, entry in ipairs(snap.items or {}) do
        if entry.uid then
            local def = CARGO.Items.Get(entry.id)
            if def and istable(def.subslots) then
                out[#out + 1] = { uid = entry.uid, def = def, blob = entry.blob }
            end
        end
    end
    return out
end

local function OpenItemMenu(entry)
    local def = CARGO.Items.Get(entry.id)
    if def == nil then return end
    local ref = CARGO.Grid.RefOf(entry)
    local menu = DermaMenu()

    -- equip targets
    if def.class == "unique" and entry.uid then
        local targets = {}
        for _, slot in ipairs(CARGO.Slots.List) do
            if CARGO.Slots.CanEquip(def, slot.id) then targets[#targets + 1] = slot end
        end
        if #targets > 0 then
            local sub = menu:AddSubMenu("Equip on...")
            for _, slot in ipairs(targets) do
                sub:AddOption(slot.label, function() SendEquip(ref, slot.id) end)
            end
        end
    end

    if isfunction(def.onUse) then
        menu:AddOption("Use", function() SendUse(ref) end)
    end

    -- mount into a sub-slot of an owned host (generic primitive, §4)
    do
        local options = {}
        for _, host in ipairs(OwnedHosts()) do
            if host.uid ~= entry.uid then
                for _, spec in ipairs(host.def.subslots) do
                    if CARGO.Items.MatchesFilter(def, spec.filter) then
                        options[#options + 1] = {
                            label = host.def.name .. " · " .. spec.label,
                            uid = host.uid, subId = spec.id,
                        }
                    end
                end
            end
        end
        if #options > 0 then
            local sub = menu:AddSubMenu("Insert into...")
            for _, opt in ipairs(options) do
                sub:AddOption(opt.label, function() SendSubAttach(opt.uid, opt.subId, ref) end)
            end
        end
    end

    -- ARC9 attach flow (§10.2 route 1: context menu). Targets: held weapons.
    if def.category == "attachments" and CARGO.ARC9.Available() then
        local targets = CARGO.ARC9.CompatibleTargets(entry.id)
        if #targets > 0 then
            local sub = menu:AddSubMenu("Attach to...")
            for _, tgt in ipairs(targets) do
                sub:AddOption(tgt.label, function()
                    CARGO.ARC9.Attach(tgt.wep, tgt.addr, entry.id)
                end)
            end
        else
            local opt = menu:AddOption("Attach to... (no compatible weapon in hands)", function() end)
            opt:SetEnabled(false)
        end
    end

    if isfunction(def.onUse) and def.class == "stackable" then
        local sub = menu:AddSubMenu("Quick bind...")
        for n = 1, CARGO.Slots.QUICK_COUNT do
            sub:AddOption("F" .. n, function() SendQuickBind(n, entry.id) end)
        end
    end

    if entry.uid and entry.blob and entry.blob.ammo_group ~= nil then
        local now = entry.blob.ammo_group
        local nxt = now == "A" and "B" or "A"
        menu:AddOption("Ammo group: " .. now .. " → " .. nxt, function()
            SendAmmoGroup(entry.uid, nxt)
        end)
    end

    menu:AddOption("Drop", function() SendDrop(ref, 1) end)
    if (entry.count or 1) > 1 then
        menu:AddOption("Drop all (x" .. entry.count .. ")", function()
            SendDrop(ref, entry.count)
        end)
    end

    menu:Open()
end

local function OpenSlotMenu(slotId)
    local snap = S()
    local slotEntry = snap and snap.equip and snap.equip[slotId]
    if slotEntry == nil then return end
    local def = CARGO.Items.Get(slotEntry.id)
    local menu = DermaMenu()

    menu:AddOption("Unequip", function() SendUnequip(slotId) end)

    -- extract mounted sub-slot entries
    if def and istable(def.subslots) and slotEntry.blob and istable(slotEntry.blob.subslots) then
        for _, spec in ipairs(def.subslots) do
            local entries = slotEntry.blob.subslots[spec.id]
            if istable(entries) then
                for i, sub in ipairs(entries) do
                    local subDef = CARGO.Items.Get(sub.id)
                    menu:AddOption("Extract " .. (subDef and subDef.name or sub.id), function()
                        SendSubDetach(slotEntry.uid, spec.id, i)
                    end)
                end
            end
        end
    end

    if slotEntry.blob and slotEntry.blob.ammo_group ~= nil then
        local now = slotEntry.blob.ammo_group
        local nxt = now == "A" and "B" or "A"
        menu:AddOption("Ammo group: " .. now .. " → " .. nxt, function()
            SendAmmoGroup(slotEntry.uid, nxt)
        end)
    end

    -- ARC9 detach (§10.2): tooltip shows what is installed; this is the action
    if def and isstring(def.weapon_class) and CARGO.ARC9.Available() then
        local ply = LocalPlayer()
        local wep = IsValid(ply) and ply:GetWeapon(def.weapon_class) or nil
        if IsValid(wep) then
            for _, att in ipairs(CARGO.ARC9.Installed(wep)) do
                if not att.integral then
                    menu:AddOption("Detach " .. att.name, function()
                        CARGO.ARC9.Detach(wep, att.addr)
                    end)
                end
            end
        end
    end

    menu:Open()
end

-- ------------------------------------------------------------------
-- Equipment slot cells
-- ------------------------------------------------------------------

local function SlotEntryOf(slotId)
    local snap = S()
    return snap and snap.equip and snap.equip[slotId] or nil
end

-- big: Head/Body/Back (icon-style). small: weapon/accessory rows.
local function MakeSlotCell(parent, slot, big)
    local cell = vgui.Create("DButton", parent)
    cell:SetText("")
    cell.cargoSlotId = slot.id

    cell.Paint = function(self, w, h)
        local entry = SlotEntryOf(slot.id)
        draw.RoundedBox(4, 0, 0, w, h,
            self:IsHovered() and T.Colors.cellHover or T.Colors.cell)
        surface.SetDrawColor(entry and T.Colors.borderHi or T.Colors.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        draw.SimpleText(slot.label, "CargoTiny", 6, 4, T.Colors.textDim)

        if entry == nil then
            draw.SimpleText("—", "CargoHeading", w / 2, h / 2 + (big and 4 or 0),
                T.Colors.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        local def = CARGO.Items.Get(entry.id)
        local name = def and def.name or entry.id

        -- weapons: ammo group + caliber, top-right (mockup "A · 9mm")
        if entry.blob and entry.blob.ammo_group and def and istable(def.ammo) then
            draw.SimpleText(entry.blob.ammo_group .. " · " .. (def.ammo.caliber or ""),
                "CargoTiny", w - 6, 4, T.Colors.amber, TEXT_ALIGN_RIGHT)
        elseif entry.blob and entry.blob.ammo_group then
            draw.SimpleText(entry.blob.ammo_group, "CargoTiny", w - 6, 4,
                T.Colors.amber, TEXT_ALIGN_RIGHT)
        end

        local cond = T.ConditionOf(entry)

        -- item icon (Cargo_ItemImages §10): aspect-fit between the label row
        -- and the condition bar; the name only paints while there is no icon
        -- (queued placeholder / no-model error signal) or the cell is too
        -- short to show one legibly (smallest accessory rows)
        local availH = h - 16 - (cond ~= nil and 16 or 6)
        local icon = availH >= 20 and CARGO.Icons.Get(entry.id) or nil
        if icon ~= nil then
            T.DrawIconFit(icon, 6, 16, w - 12, availH)
        else
            local font = big and "CargoSmall" or "CargoText"
            name = T.FitText(name, font, w - 12)
            draw.SimpleText(name, font,
                big and w / 2 or 6, h / 2 + (big and 2 or 1),
                T.Colors.text, big and TEXT_ALIGN_CENTER or TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        if cond ~= nil then
            T.DrawBar(6, h - 12, w - 12 - 34, 5, cond / 100, T.ConditionColor(cond))
            draw.SimpleText(math.Round(cond) .. "%", "CargoTiny", w - 6, h - 16,
                T.ConditionColor(cond), TEXT_ALIGN_RIGHT)
        end
    end

    cell.OnCursorEntered = function(self)
        local entry = SlotEntryOf(slot.id)
        if entry then CARGO.Tooltip.Show(self, entry) end
    end

    cell.DoRightClick = function() OpenSlotMenu(slot.id) end

    -- drag an item from the grid onto the slot -> equip; drag an
    -- attachment onto an equipped held weapon -> ARC9 attach menu
    cell:Receiver("cargo_item", function(_, panels, dropped)
        if not dropped or not IsValid(panels[1]) then return end
        local entry = panels[1].cargoEntry
        if entry == nil then return end
        local def = CARGO.Items.Get(entry.id)
        if def == nil then return end

        if def.category == "attachments" and CARGO.ARC9.Available() then
            local slotEntry = SlotEntryOf(slot.id)
            local hostDef = slotEntry and CARGO.Items.Get(slotEntry.id)
            if hostDef and isstring(hostDef.weapon_class) then
                local ply = LocalPlayer()
                local wep = IsValid(ply) and ply:GetWeapon(hostDef.weapon_class) or nil
                if IsValid(wep) then
                    local menu = DermaMenu()
                    local any = false
                    for _, tgt in ipairs(CARGO.ARC9.CompatibleTargets(entry.id)) do
                        if tgt.wep == wep then
                            any = true
                            menu:AddOption(tgt.label, function()
                                CARGO.ARC9.Attach(tgt.wep, tgt.addr, entry.id)
                            end)
                        end
                    end
                    if any then menu:Open() end
                    return
                end
            end
        end

        if entry.uid then SendEquip(CARGO.Grid.RefOf(entry), slot.id) end
    end)

    -- dragging the slot itself back to the grid unequips (see grid receiver)
    cell:Droppable("cargo_item")
    return cell
end

-- ------------------------------------------------------------------
-- Quick slot cells
-- ------------------------------------------------------------------

local function QuickCount(itemId)
    local snap = S()
    if snap == nil or itemId == nil then return 0 end
    local n = 0
    for _, entry in ipairs(snap.items or {}) do
        if entry.uid == nil and entry.id == itemId then n = n + (entry.count or 1) end
    end
    return n
end

local function MakeQuickCell(parent, n)
    local cell = vgui.Create("DButton", parent)
    cell:SetText("")

    cell.Paint = function(self, w, h)
        local snap = S()
        local unlocked = snap and n <= (snap.quickUnlocked or 0)
        local itemId = snap and snap.quick and snap.quick[n] or nil
        local def = itemId and CARGO.Items.Get(itemId) or nil

        draw.RoundedBox(4, 0, 0, w, h,
            self:IsHovered() and T.Colors.cellHover or T.Colors.cell)
        surface.SetDrawColor(T.Colors.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        if not unlocked then
            -- padlock stand-in: diagonal hatching + dim key label
            surface.SetDrawColor(T.Colors.border)
            for off = -h, w, 10 do
                surface.DrawLine(off, h, off + h, 0)
            end
            draw.SimpleText("F" .. n, "CargoTiny", w / 2, h - 12,
                T.Colors.textDim, TEXT_ALIGN_CENTER)
            return
        end

        if def then
            -- icon with letter fallback (Cargo_ItemImages §10), F label spared
            local icon = CARGO.Icons.Get(def.id)
            if icon ~= nil then
                T.DrawIconFit(icon, 4, 3, w - 8, h - 18)
            else
                draw.SimpleText(string.upper(def.name:sub(1, 1)), "CargoHeading",
                    w / 2, h / 2 - 6, T.Colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            local count = QuickCount(itemId)
            draw.SimpleText("x" .. count, "CargoTiny", w - 4, 3,
                count > 0 and T.Colors.text or T.Colors.red, TEXT_ALIGN_RIGHT)
        end
        draw.SimpleText("F" .. n, "CargoTiny", w / 2, h - 12,
            T.Colors.textDim, TEXT_ALIGN_CENTER)
    end

    cell.DoClick = function() SendQuickUse(n) end
    cell.DoRightClick = function()
        local snap = S()
        if snap == nil or snap.quick == nil or snap.quick[n] == nil then return end
        local menu = DermaMenu()
        menu:AddOption("Use", function() SendQuickUse(n) end)
        menu:AddOption("Unbind", function() SendQuickBind(n, "") end)
        menu:Open()
    end

    -- drop a usable item on the cell to bind it
    cell:Receiver("cargo_item", function(_, panels, dropped)
        if not dropped or not IsValid(panels[1]) then return end
        local entry = panels[1].cargoEntry
        if entry then SendQuickBind(n, entry.id) end
    end)

    return cell
end

-- ------------------------------------------------------------------
-- Frame construction
-- ------------------------------------------------------------------

local function BuildTabs(bar)
    bar:Clear()
    local snap = S()
    if snap == nil then return end

    -- tabs = Todo + categories present in the current grid, in category order
    local present = {}
    for _, entry in ipairs(snap.items or {}) do
        local def = CARGO.Items.Get(entry.id)
        if def then present[def.category] = true end
    end

    local tabs = { { id = "all", label = "All" } }
    for _, cat in ipairs(CARGO.Items.GetCategories()) do
        if present[cat.id] then tabs[#tabs + 1] = cat end
    end

    local x = 0
    for _, cat in ipairs(tabs) do
        surface.SetFont("CargoSmall")
        local tw = surface.GetTextSize(cat.label)
        local btn = vgui.Create("DButton", bar)
        btn:SetText("")
        btn:SetPos(x, 2)
        btn:SetSize(tw + 22, 24)
        btn.Paint = function(self, w, h)
            local activeTab = grid and grid.filter == cat.id
            draw.RoundedBox(12, 0, 0, w, h,
                activeTab and T.Colors.text or (self:IsHovered() and T.Colors.cellHover or T.Colors.panelAlt))
            draw.SimpleText(cat.label, "CargoSmall", w / 2, h / 2,
                activeTab and T.Colors.bg or T.Colors.text,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            if grid then grid.SetFilter(cat.id) end
        end
        x = x + tw + 28
    end
end

local tabsBar

local function BuildFrame()
    if IsValid(frame) then frame:Remove() end

    local W = math.min(ScrW() - 80, 1120)
    local H = math.min(ScrH() - 80, 640)

    frame = vgui.Create("DFrame")
    frame:SetSize(W, H)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    -- keyboard stays with the game: the inventory key toggles the frame
    -- closed and F1-F4 keep working while it is open
    frame:SetKeyboardInputEnabled(false)
    frame.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, T.Colors.bg)
        surface.SetDrawColor(T.Colors.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    frame.OnClose = function()
        CARGO.Tooltip.Hide()
        surface.PlaySound("backpack/inv_close.wav")
    end

    -- ---------------- left column ----------------
    local left = vgui.Create("Panel", frame)
    left:Dock(LEFT)
    left:SetWide(286)
    left:DockMargin(10, 28, 6, 10)

    local equipPanel = vgui.Create("DPanel", left)
    equipPanel:Dock(TOP)
    equipPanel:SetTall(312)
    equipPanel.Paint = function(_, w, h)
        T.PaintPanel(w, h)
        draw.SimpleText("Equipment", "CargoHeading", 10, 8, T.Colors.textDim)
    end

    do
        local PAD, y = 10, 30
        local w3 = (286 - PAD * 2 - 12) / 3
        local bigSlots = { "head", "body", "back" } -- slot ids, see corpus_cargo_slots.lua
        for i, slotId in ipairs(bigSlots) do
            local cell = MakeSlotCell(equipPanel, CARGO.Slots.ById[slotId], true)
            cell:SetPos(PAD + (i - 1) * (w3 + 6), y)
            cell:SetSize(w3, 84)
        end
        y = y + 90

        local w2 = (286 - PAD * 2 - 6) / 2
        local rows = {
            { "primary", "secondary", 54 },
            { "sidearm", "melee", 54 },
            { "accessory1", "accessory2", 40 },
        }
        for _, row in ipairs(rows) do
            for i = 1, 2 do
                local cell = MakeSlotCell(equipPanel, CARGO.Slots.ById[row[i]], false)
                cell:SetPos(PAD + (i - 1) * (w2 + 6), y)
                cell:SetSize(w2, row[3])
            end
            y = y + row[3] + 6
        end
    end

    local quickPanel = vgui.Create("DPanel", left)
    quickPanel:Dock(TOP)
    quickPanel:SetTall(96)
    quickPanel:DockMargin(0, 8, 0, 0)
    quickPanel.Paint = function(_, w, h)
        T.PaintPanel(w, h)
        draw.SimpleText("Quick slots", "CargoHeading", 10, 8, T.Colors.textDim)
    end
    do
        local w4 = (286 - 20 - 18) / 4
        for n = 1, CARGO.Slots.QUICK_COUNT do
            local cell = MakeQuickCell(quickPanel, n)
            cell:SetPos(10 + (n - 1) * (w4 + 6), 30)
            cell:SetSize(w4, 56)
        end
    end

    local status = CARGO.StatusPanel.Build(left)
    status:Dock(FILL)
    status:DockMargin(0, 8, 0, 0)

    -- ---------------- right column ----------------
    local right = vgui.Create("Panel", frame)
    right:Dock(FILL)
    right:DockMargin(4, 28, 10, 10)

    local header = vgui.Create("DPanel", right)
    header:Dock(TOP)
    header:SetTall(56)
    header.Paint = function(_, w, h)
        T.PaintPanel(w, h)
        local snap = S()
        local ply = LocalPlayer()
        local name = IsValid(ply) and ply:Nick() or "?"

        draw.SimpleText(name, "CargoHeading", 58, 9, T.Colors.text)
        surface.SetFont("CargoHeading")
        local nw = surface.GetTextSize(name)
        draw.SimpleText("Steam profile", "CargoSmall", 58 + nw + 8, 12, T.Colors.textDim)

        -- faction/rank: rendered only if the Cortex provider reported it (§6)
        if snap and istable(snap.faction) and snap.faction.name then
            local line = snap.faction.name
                .. (snap.faction.rank and (" · " .. snap.faction.rank) or "")
            draw.SimpleText(line, "CargoText", 58, 30, T.Colors.text)
            surface.SetFont("CargoText")
            local fw = surface.GetTextSize(line)
            draw.SimpleText("(provider: Cortex)", "CargoSmall", 58 + fw + 8, 32, T.Colors.textDim)
        end

        if snap then
            draw.SimpleText(snap.money or "?", "CargoTitle", w - 12, 8,
                T.Colors.text, TEXT_ALIGN_RIGHT)
            draw.SimpleText((snap.moneyLabel or "") .. " / provider", "CargoSmall",
                w - 12, 32, T.Colors.textDim, TEXT_ALIGN_RIGHT)
        end
    end

    local avatar = vgui.Create("AvatarImage", header)
    avatar:SetPos(10, 8)
    avatar:SetSize(40, 40)
    avatar:SetPlayer(LocalPlayer(), 64)

    tabsBar = vgui.Create("Panel", right)
    tabsBar:Dock(TOP)
    tabsBar:SetTall(28)
    tabsBar:DockMargin(0, 8, 0, 8)

    local footer = vgui.Create("DPanel", right)
    footer:Dock(BOTTOM)
    footer:SetTall(34)
    footer:DockMargin(0, 8, 0, 0)
    footer.Paint = function(_, w, h)
        T.PaintPanel(w, h)
        local snap = S()
        if snap == nil then return end

        local frac = snap.capacity > 0 and snap.weight / snap.capacity or 0
        local col = T.WeightColor(frac)
        T.DrawBar(10, h / 2 - 4, w * 0.5, 8, frac, col)

        local txt = string.format("%.1f kg", snap.weight)
        local rest = string.format(" / %.1f kg (base %g + back %g)",
            snap.capacity, snap.capBase, snap.capBack)
        surface.SetFont("CargoText")
        local restW = surface.GetTextSize(rest)
        surface.SetFont("CargoHeading")
        local txtW = surface.GetTextSize(txt)
        draw.SimpleText(txt, "CargoHeading", w - 12 - restW - txtW, 8, col)
        draw.SimpleText(rest, "CargoText", w - 12 - restW, 10, T.Colors.textDim)
    end

    grid = CARGO.Grid.Create(right, {
        getEntries = function()
            local snap = S()
            return snap and snap.items or {}
        end,
        dragSource = "own",
        onRightClick = function(entry) OpenItemMenu(entry) end,
        -- dropping an equipment slot cell onto the grid unequips it
        onReceiveDrop = function(cell)
            if cell.cargoSlotId then SendUnequip(cell.cargoSlotId) end
        end,
    })
    grid.panel:Dock(FILL)

    BuildTabs(tabsBar)
    grid.Refresh()
    surface.PlaySound("backpack/inv_open.wav")
end

-- ------------------------------------------------------------------
-- State + open/close
-- ------------------------------------------------------------------

function CARGO.UI.RefreshAll()
    if not IsValid(frame) then return end
    BuildTabs(tabsBar)
    grid.Refresh()
    -- equipment/quick/header/footer paint straight from the snapshot
end

function CARGO.UI.Toggle()
    if IsValid(frame) then
        frame:Close()
        return
    end
    pendingOpen = true
    net.Start(NET_OPEN)
    net.SendToServer()
end

net.Receive(NET_SYNC, function()
    local snap = CARGO.Util.ReadBlob()
    if snap == nil then return end
    -- quick is a sparse numeric map: the JSON hop stringifies its keys
    snap.quick = CARGO.Util.NumberKeys(snap.quick)

    -- server-side auto-generated defs (captured engine weapons) arrive with
    -- the snapshot; engine names come as localization tokens ("#HL2_Pistol")
    for id, def in pairs(snap.defs or {}) do
        local known = CARGO.Items.Get(id)
        if known == nil then
            if isstring(def.name) and def.name:sub(1, 1) == "#" then
                def.name = language.GetPhrase(def.name:sub(2))
            end
            CARGO.Items.Register(def)
        elseif known ~= def then
            -- def-level icon override data rides this same channel
            -- (Cargo_ItemImages §10): merge in place (by-ref invariant) and
            -- drop that def's icon caches only if it actually changed
            local before = known.icon_override and util.TableToJSON(known.icon_override) or ""
            local after = def.icon_override and util.TableToJSON(def.icon_override) or ""
            if before ~= after then
                known.icon_override = def.icon_override
                CARGO.Icons.Invalidate(id)
            end
        end
    end

    CARGO.ClientState = snap
    if pendingOpen then
        pendingOpen = nil
        BuildFrame()
    else
        CARGO.UI.RefreshAll()
    end
    -- container panel mirrors the player half when open
    if CARGO.Transfer and CARGO.Transfer.RefreshOwn then
        CARGO.Transfer.RefreshOwn()
    end
end)

net.Receive(NET_NOTICE, function()
    chat.AddText(T.Colors.amber, "[Cargo] ", T.Colors.text, net.ReadString())
end)

concommand.Add("cargo_inventory", function()
    CARGO.UI.Toggle()
end, nil, "Opens/closes the Cargo inventory")

-- Open key via input polling, NOT PlayerButtonDown: that hook does not fire
-- client-side in singleplayer (engine quirk), which made the I key feel
-- broken. input.IsButtonDown works everywhere; the edge detector + focus
-- guards keep it from firing while typing in chat or with the game menu up.
local keyWasDown = false
hook.Add("Think", "corpus_cargo_ui_key", function()
    local key = cvKey:GetInt()
    if key <= 0 then keyWasDown = false return end

    local down = input.IsButtonDown(key)
    if down and not keyWasDown
        and not gui.IsGameUIVisible()
        and vgui.GetKeyboardFocus() == nil then
        CARGO.UI.Toggle()
    end
    keyWasDown = down
end)

-- F1-F4 -> quick slots (mockup binding); convar-gated because it shadows
-- gm_showhelp/gm_showteam/gm_showspare1/gm_showspare2
local QUICK_BINDS = {
    gm_showhelp = 1, gm_showteam = 2, gm_showspare1 = 3, gm_showspare2 = 4,
}

hook.Add("PlayerBindPress", "corpus_cargo_ui_quick", function(_, bind, pressed)
    if not pressed or not cvQuickF:GetBool() then return end
    local n = QUICK_BINDS[bind]
    if n ~= nil then
        SendQuickUse(n)
        return true
    end
end)
