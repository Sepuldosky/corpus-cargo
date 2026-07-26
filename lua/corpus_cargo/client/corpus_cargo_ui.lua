-- corpus_cargo_ui.lua — fullscreen inventory frame (CLIENT)
-- Layout frozen against docs/mockups/cargo_fullscreen_ui_mock_v1.html
-- (Cargo_Architecture.md §15): one three-column implementation, three
-- states. Center (equipment, STALKER order) and right (own inventory) are
-- identical in every state; the LEFT column is contextual — absent in
-- Solo (world visible behind the scrim), container grid in Loot, trader
-- stock in Trade (separate block, Cargo_Trade_Arquitectura.md). The mock
-- is CSS — here it is manual layout (Dock/SetPos/Paint), per the VGUI
-- notes inherited from ADS. All Paint closures read the last synced
-- snapshot, so a new sync refreshes in place without rebuilding the frame.

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
local NET_BELT_SET  = Corpus.Net.Register("cargo", "belt_set")
local NET_BELT_CLR  = Corpus.Net.Register("cargo", "belt_clear")
local NET_BELT_MOVE = Corpus.Net.Register("cargo", "belt_move")
local NET_UNLOAD    = Corpus.Net.Register("cargo", "unload")
local NET_EQUIP_DROP = Corpus.Net.Register("cargo", "equip_drop")

local cvKey = CreateClientConVar("cargo_key_inventory", tostring(KEY_I), true, false,
    "Key (KEY_* enum) that opens the Cargo inventory")
local cvQuickF = CreateClientConVar("cargo_quick_f", "1", true, false,
    "Intercept F1-F4 as Cargo quick slots")

-- sandbox tool circles (§15.2 #21): the hide toggle is back (author call
-- 2026-07-13 — it had been cut in game) and the alignment is configurable.
-- The wheel's tool chips (#31) read the same show/hide convar.
local cvTools = CreateClientConVar("cargo_ui_tools", "1", true, false,
    "Show the sandbox tool circles (physgun/toolgun/camera) in the equipment column and the wheel")
local cvToolsAlign = CreateClientConVar("cargo_ui_tools_align", "left", true, false,
    "Sandbox tool circle alignment in the equipment column: left or center")

local frame, grid, lootGrid, tradeLeft, pendingOpen
local BuildFrame -- forward: the tools hide chip (BuildEquipColumn) relayouts

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
    CARGO.Sounds.Play("drop")
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
local function SendBeltSet(n, ref)
    net.Start(NET_BELT_SET) net.WriteUInt(n, 4) CARGO.Util.WriteBlob(ref) net.SendToServer()
end
local function SendBeltClear(n)
    net.Start(NET_BELT_CLR) net.WriteUInt(n, 4) net.SendToServer()
end
local function SendBeltMove(fromN, toN)
    net.Start(NET_BELT_MOVE) net.WriteUInt(fromN, 4) net.WriteUInt(toN, 4) net.SendToServer()
end
local function SendUnload()
    net.Start(NET_UNLOAD) net.SendToServer()
end
local function SendEquipDrop(slotId)
    net.Start(NET_EQUIP_DROP) net.WriteString(slotId) net.SendToServer()
    CARGO.Sounds.Play("drop")
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

    -- equip targets: uniques into regular slots, stackables into stack
    -- slots (throwable) — CanEquip arbitrates both sides
    if (def.class == "unique" and entry.uid) or def.class == "stackable" then
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

    -- unload the held magazine back to the belt (roadmap #26) — only offered
    -- for the weapon actually in hand: the server acts on the active weapon
    if def and isstring(def.weapon_class) then
        local ply = LocalPlayer()
        local wep = IsValid(ply) and ply:GetActiveWeapon() or nil
        if IsValid(wep) and wep:GetClass() == def.weapon_class then
            menu:AddOption("Unload magazine", function() SendUnload() end)
        end
    end

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

    -- drop straight from the slot (roadmap #28): weapons leave as the real
    -- SWEP with their instance, gear as the item entity — server decides
    menu:AddOption("Drop", function() SendEquipDrop(slotId) end)

    menu:Open()
end

-- ------------------------------------------------------------------
-- Equipment slot cells
-- ------------------------------------------------------------------

local function SlotEntryOf(slotId)
    local snap = S()
    return snap and snap.equip and snap.equip[slotId] or nil
end

-- STALKER-order slot cell (mock §15.2): label top-left, ammo group badge
-- top-right, icon centered, name centered above the segmented condition
-- bar at the bottom. tall = the vertical weapon/body column (row 2): wide
-- weapon renders (rifle 6×2) get turned upright there.
local function MakeSlotCell(parent, slot, tall)
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
            draw.SimpleText("—", "CargoHeading", w / 2, h / 2,
                T.Colors.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        local def = CARGO.Items.Get(entry.id)
        local name = def and def.name or entry.id

        -- weapons: ammo group + caliber, top-right (mockup "A · 9mm")
        if entry.blob and entry.blob.ammo_group then
            local tag = entry.blob.ammo_group
            if def and istable(def.ammo) and def.ammo.caliber then
                tag = tag .. " · " .. def.ammo.caliber
            end
            draw.SimpleText(tag, "CargoTiny", w - 6, 4,
                T.Colors.amber, TEXT_ALIGN_RIGHT)
        end

        -- stack slots (throwable): the count IS the display — ×N badge,
        -- same corner (a stack has no blob, so the badges never collide)
        if entry.uid == nil and entry.count ~= nil then
            draw.SimpleText("×" .. entry.count, "CargoTiny", w - 6, 4,
                T.Colors.text, TEXT_ALIGN_RIGHT)
        end

        local cond = T.ConditionOf(entry)

        -- bottom-up: segmented condition bar, name row, then the icon gets
        -- whatever is left between the label row and the name
        local segY = cond ~= nil and (h - 10) or nil
        local nameCY = (segY or (h - 2)) - 12
        local iconY = 16
        local iconH = nameCY - 10 - iconY

        -- item icon (Cargo_ItemImages §10): only when the cell is tall
        -- enough to show one legibly (smallest accessory rows are name-only)
        local icon = iconH >= 20 and CARGO.Icons.Get(entry.id) or nil
        if icon ~= nil then
            local fp = def and CARGO.Icons.GetFootprint(def) or nil
            if tall and fp and fp.w > fp.h then
                T.DrawIconFitVertical(icon, 6, iconY, w - 12, iconH)
            else
                T.DrawIconFit(icon, 6, iconY, w - 12, iconH)
            end
        end

        -- the name always paints (mock); while there is no icon it doubles
        -- as the queued-placeholder / no-model signal
        draw.SimpleText(T.FitText(name, "CargoSmall", w - 12), "CargoSmall",
            w / 2, nameCY, T.Colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if segY ~= nil then
            T.DrawSegBar(6, segY, w - 12, 5, cond / 100, T.ConditionColor(cond))
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

        -- stack slots (throwable) take whole stacks; the rest need a uid
        if entry.uid or slot.stack then
            SendEquip(CARGO.Grid.RefOf(entry), slot.id)
        end
    end)

    -- dragging the slot itself back to the grid unequips (see grid receiver)
    cell:Droppable("cargo_item")
    return cell
end

-- ------------------------------------------------------------------
-- Quick slot cells
-- ------------------------------------------------------------------

-- exported: the wheel's quick chips (#31) show the same count
function CARGO.UI.QuickCount(itemId)
    local snap = S()
    if snap == nil or itemId == nil then return 0 end
    local n = 0
    for _, entry in ipairs(snap.items or {}) do
        if entry.uid == nil and entry.id == itemId then n = n + (entry.count or 1) end
    end
    return n
end
local QuickCount = CARGO.UI.QuickCount

-- exported: the wheel's quick chips commit through the SAME quick-use route
-- (roadmap #31 rule: zero new server logic — this is the existing intent)
function CARGO.UI.QuickUse(n)
    SendQuickUse(n)
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
            draw.SimpleText("F" .. n, "CargoTiny", w - 6, h - 14,
                T.Colors.textDim, TEXT_ALIGN_RIGHT)
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
        draw.SimpleText("F" .. n, "CargoTiny", w - 6, h - 14,
            T.Colors.textDim, TEXT_ALIGN_RIGHT)
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
-- Ammo belt cells (§15.2, FORM only — semantics is roadmap #19)
-- ------------------------------------------------------------------

local function BeltEntryOf(n)
    local snap = S()
    return snap and snap.belt and snap.belt[n] or nil
end

-- group letter on a belt stack: display-only derivation — the caliber
-- matches an equipped weapon's bound A/B group (mock badge). Nothing
-- feeds from it yet.
local function BeltGroupOf(def)
    local snap = S()
    if snap == nil or def == nil or not istable(def.ammo) then return nil end
    for _, slotId in ipairs({ "primary", "secondary", "sidearm" }) do
        local slotEntry = snap.equip and snap.equip[slotId]
        if slotEntry and slotEntry.blob and slotEntry.blob.ammo_group then
            local wDef = CARGO.Items.Get(slotEntry.id)
            if wDef and istable(wDef.ammo) and wDef.ammo.caliber == def.ammo.caliber then
                return slotEntry.blob.ammo_group
            end
        end
    end
    return nil
end

local function MakeBeltCell(parent, n)
    local cell = vgui.Create("DButton", parent)
    cell:SetText("")
    cell.cargoBeltSlot = n

    cell.Paint = function(self, w, h)
        local entry = BeltEntryOf(n)
        draw.RoundedBox(4, 0, 0, w, h,
            self:IsHovered() and T.Colors.cellHover or T.Colors.cell)
        surface.SetDrawColor(entry and T.Colors.borderHi or T.Colors.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        if entry == nil then return end

        local def = CARGO.Items.Get(entry.id)
        local icon = CARGO.Icons.Get(entry.id)
        if icon ~= nil then
            T.DrawIconFit(icon, 4, 4, w - 8, h - 18)
        elseif def then
            draw.SimpleText(string.upper(def.name:sub(1, 1)), "CargoHeading",
                w / 2, h / 2 - 4, T.Colors.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        draw.SimpleText("x" .. (entry.count or 1), "CargoTiny", w - 4, 2,
            T.Colors.text, TEXT_ALIGN_RIGHT)
        local grp = BeltGroupOf(def)
        if grp ~= nil then
            draw.SimpleText(grp, "CargoTiny", 4, 2, T.Colors.amber)
        end
        if def and istable(def.ammo) and def.ammo.caliber then
            draw.SimpleText(def.ammo.caliber, "CargoTiny", 4, h - 14, T.Colors.textDim)
        end
    end

    cell.OnCursorEntered = function(self)
        local entry = BeltEntryOf(n)
        if entry then CARGO.Tooltip.Show(self, entry) end
    end

    cell.DoRightClick = function()
        if BeltEntryOf(n) == nil then return end
        local menu = DermaMenu()
        menu:AddOption("Return to inventory", function() SendBeltClear(n) end)
        menu:Open()
    end

    -- drop an ammo stack from the grid to store it here (the server
    -- rejects anything that is not category "ammo"), or another belt cell
    -- to reorder (roadmap #25 — the server validates the source slot)
    cell:Receiver("cargo_item", function(_, panels, dropped)
        if not dropped or not IsValid(panels[1]) then return end
        local fromN = panels[1].cargoBeltSlot
        if fromN ~= nil then
            if fromN ~= n then SendBeltMove(fromN, n) end
            return
        end
        local entry = panels[1].cargoEntry
        if entry and entry.uid == nil then
            SendBeltSet(n, CARGO.Grid.RefOf(entry))
        end
    end)

    -- dragging the belt cell back onto the grid returns the stack
    cell:Droppable("cargo_item")
    return cell
end

-- ------------------------------------------------------------------
-- Sandbox tool circles (§15.2, roadmap #21): the three DEDICATED tool
-- slots (CARGO.Slots.Tools — class-restricted, so they never compete with
-- the weapon slots) rendered as circles. Click equips the tool from the
-- grid into its slot (the server hands out the SWEP and the capture keeps
-- equipped classes) or selects it once equipped; drag works both ways
-- like any other slot. Author calibration, first fullscreen pass.
-- ------------------------------------------------------------------

-- the tool as a grid item (captured weapons carry def.weapon_class).
-- Exported: the wheel's tool chips (#31) resolve their icon entry with it.
function CARGO.UI.FindToolItem(class)
    local snap = S()
    if snap == nil then return nil end
    for _, entry in ipairs(snap.items or {}) do
        local def = CARGO.Items.Get(entry.id)
        if def and def.weapon_class == class then return entry, def end
    end
    return nil
end
local FindToolItem = CARGO.UI.FindToolItem

-- Select or equip a sandbox tool — ONE behavior shared by the column
-- circles and the wheel's tool chips (#31): equipped -> switch to it (the
-- equip give already put the SWEP in hands); in the grid -> equip it into
-- its dedicated slot.
function CARGO.UI.SelectTool(tool)
    if SlotEntryOf(tool.slotId) ~= nil then
        local ply = LocalPlayer()
        local wep = IsValid(ply) and ply:GetWeapon(tool.class) or nil
        if IsValid(wep) then input.SelectWeapon(wep) end
        return
    end
    local entry = FindToolItem(tool.class)
    if entry and entry.uid then
        SendEquip(CARGO.Grid.RefOf(entry), tool.slotId)
    end
end

local function MakeToolCircle(parent, tool)
    local cell = vgui.Create("DButton", parent)
    cell:SetText("")
    -- dragging the circle onto the grid unequips (grid receiver contract)
    cell.cargoSlotId = tool.slotId

    cell.Paint = function(self, w, h)
        local equipped = SlotEntryOf(tool.slotId)
        local entry = equipped or FindToolItem(tool.class)

        local cx, cy, r = w / 2, h / 2, math.min(w, h) / 2 - 1
        -- Theme.DrawCircleOutlined: the ONE circle primitive (the old poly +
        -- surface.DrawCircle pair is what looked flat in game)
        T.DrawCircleOutlined(cx, cy, r,
            self:IsHovered() and T.Colors.cellHover or T.Colors.cell,
            equipped and T.Colors.borderHi or T.Colors.border, 1)

        if entry == nil then return end
        -- grid-only tools paint dim; equipping lights the circle up
        local icon = CARGO.Icons.Get(entry.id)
        if icon ~= nil then
            T.DrawIconFit(icon, w * 0.16, h * 0.24, w * 0.68, h * 0.52)
        else
            local def = CARGO.Items.Get(entry.id)
            draw.SimpleText(def and string.upper(def.name:sub(1, 1)) or "?",
                "CargoHeading", cx, cy,
                equipped and T.Colors.text or T.Colors.textDim,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- hover shows the tool item's real inspection tooltip (author ask)
    cell.OnCursorEntered = function(self)
        local entry = SlotEntryOf(tool.slotId) or FindToolItem(tool.class)
        if entry then CARGO.Tooltip.Show(self, entry) end
    end

    cell.DoClick = function() CARGO.UI.SelectTool(tool) end

    cell.DoRightClick = function()
        if SlotEntryOf(tool.slotId) == nil then return end
        local menu = DermaMenu()
        menu:AddOption("Unequip", function() SendUnequip(tool.slotId) end)
        menu:AddOption("Drop", function() SendEquipDrop(tool.slotId) end)
        menu:Open()
    end

    -- drop the matching tool item from the grid onto its circle
    cell:Receiver("cargo_item", function(_, panels, dropped)
        if not dropped or not IsValid(panels[1]) then return end
        local entry = panels[1].cargoEntry
        if entry == nil or entry.uid == nil then return end
        local def = CARGO.Items.Get(entry.id)
        if def and def.weapon_class == tool.class then
            SendEquip(CARGO.Grid.RefOf(entry), tool.slotId)
        end
    end)

    cell:Droppable("cargo_item")
    return cell
end

-- ------------------------------------------------------------------
-- Frame construction
-- ------------------------------------------------------------------

local function BuildTabs(bar)
    bar:Clear()
    local snap = S()
    if snap == nil then return end

    -- FIXED row (#23): the tab set is closed (Items.GetTabs) and always drawn
    -- WHOLE, so a tab never moves under the cursor as the inventory changes.
    -- The row no longer follows the open category set — that is what made it
    -- grow a second line. Only the dimming is dynamic: a tab with nothing in
    -- the grid paints faded (it still filters, to an empty grid).
    local present = {}
    for _, entry in ipairs(snap.items or {}) do
        local def = CARGO.Items.Get(entry.id)
        present[CARGO.Items.TabOf(def and def.category)] = true
    end

    -- The fixed set fits one row at every aspect we ship; the wrap stays as a
    -- safety net (tiny resolutions) instead of clipping the last tab.
    local barW = bar.cargoWide or bar:GetWide()
    local x, rowY = 0, 2
    for _, tab in ipairs(CARGO.Items.GetTabs()) do
        surface.SetFont("CargoSmall")
        local tw = surface.GetTextSize(tab.label)
        local bw = tw + 22
        if x > 0 and x + bw > barW then
            x, rowY = 0, rowY + 26
        end
        local hasItems = tab.id == "all" or present[tab.id] == true
        local btn = vgui.Create("DButton", bar)
        btn:SetText("")
        btn:SetPos(x, rowY)
        btn:SetSize(bw, 24)
        -- mock .tabs: flat text, active gets the accent tint + thin border
        btn.Paint = function(self, w, h)
            local activeTab = grid and grid.filter == tab.id
            if activeTab then
                surface.SetDrawColor(T.Colors.accent.r, T.Colors.accent.g,
                    T.Colors.accent.b, 16)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(T.Colors.accentDim)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
            local col
            if activeTab then
                col = T.Colors.accent
            elseif not hasItems then
                local d = T.Colors.textDim
                col = Color(d.r, d.g, d.b, 90)
            elseif self:IsHovered() then
                col = T.Colors.text
            else
                col = T.Colors.textDim
            end
            draw.SimpleText(tab.label, "CargoSmall", w / 2, h / 2, col,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            if grid then grid.SetFilter(tab.id) end
        end
        x = x + bw + 6
    end
    bar:SetTall(rowY + 26)
end

local tabsBar

-- three-column geometry from the 1080p mock (580/420/660, gap 30), scaled
-- by ScrH and clamped so narrow aspects (4:3) still fit the row
local function ColumnRects()
    local s = math.min(T.UIScale(), ScrW() / 1760)
    local gap = math.Round(30 * s)
    local colL = math.Round(580 * s)
    local colC = math.Round(420 * s)
    local colR = math.Round(660 * s)
    local x0 = math.floor((ScrW() - colL - colC - colR - gap * 2) / 2)
    local y0 = math.Round(64 * s)
    local colH = ScrH() - y0 - math.Round(48 * s)
    return s, x0, y0, colH, colL, colC, colR, gap
end

-- equipment column content, top to bottom in the §15.2 order. Returns the
-- y cursor after the quick row: the sandbox tool circles (#21) and the
-- ammo belt (#19, form) stack there; the status panel docks to the bottom.
local function BuildEquipColumn(parent, s)
    local PAD = math.Round(14 * s)
    local g8 = math.Round(8 * s)
    local innerW = parent:GetWide() - PAD * 2

    -- mock eqgrid: 1fr / 1.25fr / 1fr — the center (Body) is the widest
    local wSide = math.Round((innerW - g8 * 2) / 3.25)
    local wMid = innerW - g8 * 2 - wSide * 2
    local xs = { PAD, PAD + wSide + g8, PAD + wSide + g8 + wMid + g8 }
    local ws = { wSide, wMid, wSide }

    local rows = {
        { h = math.Round(106 * s), tall = false,
            slots = { "accessory1", "head", "accessory2" } },
        { h = math.Round(226 * s), tall = true,
            slots = { "secondary", "body", "primary" } },
    }

    local y = PAD
    for _, row in ipairs(rows) do
        for i = 1, 3 do
            local cell = MakeSlotCell(parent, CARGO.Slots.ById[row.slots[i]], row.tall)
            cell:SetPos(xs[i], y)
            cell:SetSize(ws[i], row.h)
        end
        y = y + row.h + g8
    end

    -- bottom row (§15.2 amendment — Clear Sky stacked variant, author pick
    -- 2026-07-13): three columns stay; the THIRD splits vertically into
    -- Throwable (small, on top — it reads as the minor slot it is) over
    -- Melee, the reference's grenade-over-knife pattern. Sidearm and Back
    -- keep their full width and height.
    local hRow = math.Round(108 * s)
    local g4 = math.Round(4 * s)
    local hThrow = math.Round(42 * s)
    for i, slotId in ipairs({ "sidearm", "back" }) do
        local cell = MakeSlotCell(parent, CARGO.Slots.ById[slotId], false)
        cell:SetPos(xs[i], y)
        cell:SetSize(ws[i], hRow)
    end
    local throwCell = MakeSlotCell(parent, CARGO.Slots.ById.throwable, false)
    throwCell:SetPos(xs[3], y)
    throwCell:SetSize(ws[3], hThrow)
    local meleeCell = MakeSlotCell(parent, CARGO.Slots.ById.melee, false)
    meleeCell:SetPos(xs[3], y + hThrow + g4)
    meleeCell:SetSize(ws[3], hRow - hThrow - g4)
    y = y + hRow + g8

    -- quick slots F1-F4
    local wq = math.Round((innerW - g8 * 3) / 4)
    local hq = math.Round(64 * s)
    for n = 1, CARGO.Slots.QUICK_COUNT do
        local cell = MakeQuickCell(parent, n)
        cell:SetPos(PAD + (n - 1) * (wq + g8), y)
        cell:SetSize(wq, hq)
    end
    y = y + hq + math.Round(10 * s)

    -- sandbox tool circles (#21): hide toggle RESTORED (author call
    -- 2026-07-13) + configurable alignment (cargo_ui_tools_align). Hidden,
    -- the row collapses to the chip and the status panel takes the space.
    local ct = math.Round(50 * s)
    local shown = cvTools:GetBool()
    local rowH = shown and ct or math.Round(22 * s)
    if shown then
        local rowW = #CARGO.Slots.Tools * ct + (#CARGO.Slots.Tools - 1) * g8
        local tx = cvToolsAlign:GetString() == "center"
            and PAD + math.floor((innerW - rowW) / 2) or PAD
        for i, tool in ipairs(CARGO.Slots.Tools) do
            local c = MakeToolCircle(parent, tool)
            c:SetPos(tx + (i - 1) * (ct + g8), y)
            c:SetSize(ct, ct)
        end
    end

    -- hide/show chip, right edge with clear separation from the circles
    local chipW, chipH = math.Round(42 * s), math.Round(20 * s)
    local chip = vgui.Create("DButton", parent)
    chip:SetText("")
    chip:SetPos(PAD + innerW - chipW, y + math.floor((rowH - chipH) / 2))
    chip:SetSize(chipW, chipH)
    chip.Paint = function(self, w, h)
        surface.SetDrawColor(self:IsHovered() and T.Colors.borderHi or T.Colors.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(shown and "hide" or "show", "CargoTiny", w / 2, h / 2,
            self:IsHovered() and T.Colors.text or T.Colors.textDim,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    chip.DoClick = function()
        cvTools:SetBool(not shown)
        BuildFrame(frame.cargoState) -- relayout: the row height changed
    end
    y = y + rowH + math.Round(10 * s)

    -- ammo belt: caption row + 6 stack slots (mock .beltwrap; the right
    -- caption died in the first pass — the belt explains itself)
    local cap = vgui.Create("DPanel", parent)
    cap:SetPos(PAD, y)
    cap:SetSize(innerW, 14)
    cap.Paint = function()
        draw.SimpleText("Ammo belt", "CargoTiny", 0, 1, T.Colors.textDim)
    end
    y = y + 18

    local wb = math.Round((innerW - g8 * (CARGO.Slots.BELT_COUNT - 1)) / CARGO.Slots.BELT_COUNT)
    local hb = math.Round(52 * s)
    for n = 1, CARGO.Slots.BELT_COUNT do
        local cell = MakeBeltCell(parent, n)
        cell:SetPos(PAD + (n - 1) * (wb + g8), y)
        cell:SetSize(wb, hb)
    end
    y = y + hb + math.Round(10 * s)

    -- status panel (§11): stretches to the BOTTOM of the column (author
    -- call 2026-07-13) — modules will keep registering bars and the free
    -- space is this panel's to grow into, not dead margin
    local status = CARGO.StatusPanel.Build(parent)
    status:SetPos(PAD, y)
    status:SetSize(innerW, math.max(parent:GetTall() - y - PAD, math.Round(60 * s)))

    return y, PAD, g8, innerW
end

-- state: "solo" (left column absent — world behind the scrim), "loot"
-- (container in the left column) or "trade" (trader stock + Buy strip on the
-- left, deal bar under the own grid — both built by corpus_cargo_trade.lua,
-- Cargo_Trade slice 1). The center column is identical in every state; the
-- right one is NOT: in "trade" it takes the deal bar and its grid gains
-- priceOf/basketOf, and in "loot" the footer reserves 112 px for "Move all".
-- (local, forward-declared at the top of the file)
function BuildFrame(state)
    if IsValid(frame) then frame:Remove() end
    state = state or "solo"

    local s, x0, y0, colH, colL, colC, colR, gap = ColumnRects()

    frame = vgui.Create("DFrame")
    frame:SetSize(ScrW(), ScrH())
    frame:SetPos(0, 0)
    frame:SetTitle("")
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    -- keyboard stays with the game: the inventory key toggles the frame
    -- closed and F1-F4 keep working while it is open
    frame:SetKeyboardInputEnabled(false)
    frame.cargoState = state
    frame.Paint = function(_, w, h)
        -- scrim only — the world stays visible behind (mock .scrim); the
        -- color rides the theme (#29) like everything else
        surface.SetDrawColor(T.Colors.scrim)
        surface.DrawRect(0, 0, w, h)
    end
    -- ESC closes the inventory instead of stacking the game menu on top of
    -- it (author call 2026-07-12); the next ESC opens the menu normally
    frame.Think = function(self)
        if gui.IsGameUIVisible() then
            gui.HideGameUI()
            self:Close()
        end
    end
    frame.OnClose = function(self)
        CARGO.Tooltip.Hide()
        if self.cargoState == "loot" then CARGO.Transfer.NotifyClosed() end
        -- closing the frame IS cancelling the deal: the basket is intent, it
        -- holds nothing (Cargo_Trade §3), so nothing is lost by dropping it
        if self.cargoState == "trade" then CARGO.Trade.NotifyClosed() end
        -- backpack foley for the personal inventory, case foley for the
        -- loot/trade screens (sound/corpus/cargo/ui/about.txt)
        CARGO.Sounds.Play(self.cargoState == "solo" and "close_solo" or "close_ext")
    end

    -- ---------------- left column: contextual (§15.1) ----------------
    -- solo: absent (world behind the scrim). loot: container. trade: the
    -- trader's stock + the Buy strip (corpus_cargo_trade.lua owns those panels).
    if state == "trade" then
        tradeLeft = vgui.Create("DPanel", frame)
        tradeLeft:SetPos(x0, y0)
        tradeLeft:SetSize(colL, colH)
        tradeLeft.Paint = function(_, w, h) T.PaintPanel(w, h) end
        CARGO.Trade.BuildStockColumn(tradeLeft)
    elseif state == "loot" then
        local left = vgui.Create("DPanel", frame)
        left:SetPos(x0, y0)
        left:SetSize(colL, colH)
        left.Paint = function(_, w, h) T.PaintPanel(w, h) end
        left:DockPadding(8, 8, 8, 8)

        -- container header (mock .boxhdr): name + capacity line
        local boxhdr = vgui.Create("DPanel", left)
        boxhdr:Dock(TOP)
        boxhdr:SetTall(48)
        boxhdr.Paint = function(_, w, h)
            T.PaintPanel(w, h)
            local cont = CARGO.Transfer.State()
            if cont == nil then return end
            draw.SimpleText(cont.name or "Container", "CargoTitle", 10, 6, T.Colors.text)
            local capText = cont.capacity == nil and "infinite capacity"
                or ("capacity " .. T.FormatKg(cont.capacity))
            draw.SimpleText("Container · " .. capText, "CargoSmall", 10, 28,
                T.Colors.textDim)
        end

        -- container weight + Take all (mock .foot box-only)
        local lootFoot = vgui.Create("DPanel", left)
        lootFoot:Dock(BOTTOM)
        lootFoot:SetTall(34)
        lootFoot:DockMargin(0, 8, 0, 0)
        lootFoot.Paint = function(_, w, h)
            T.PaintPanel(w, h)
            local cont = CARGO.Transfer.State()
            if cont == nil then return end
            draw.SimpleText(T.FormatKg(cont.weight or 0), "CargoHeading", 10, 8,
                T.Colors.money)
            if cont.capacity ~= nil and cont.capacity > 0 then
                T.DrawBar(90, h / 2 - 4, w - 90 - 100, 8,
                    (cont.weight or 0) / cont.capacity,
                    T.WeightColor((cont.weight or 0) / cont.capacity))
            end
        end

        local takeAll = vgui.Create("DButton", lootFoot)
        takeAll:Dock(RIGHT)
        takeAll:SetWide(88)
        takeAll:DockMargin(6, 5, 6, 5)
        takeAll:SetText("")
        takeAll.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h,
                self:IsHovered() and T.Colors.cellHover or T.Colors.panelAlt)
            surface.SetDrawColor(T.Colors.borderHi)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("Take all", "CargoText", w / 2, h / 2,
                T.Colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        takeAll.DoClick = function() CARGO.Transfer.TakeAll("take") end

        lootGrid = CARGO.Grid.Create(left, {
            getEntries = function()
                local cont = CARGO.Transfer.State()
                return cont and cont.items or {}
            end,
            dragSource = "cont",
            onLeftClick = function(entry)
                CARGO.Transfer.Send("take", CARGO.Grid.RefOf(entry), entry.count or 1)
            end,
            onRightClick = function(entry) CARGO.Transfer.Menu("take", entry) end,
            -- dropping an own-inventory cell here puts it into the container
            onReceiveDrop = function(cell)
                if cell.cargoSource == "own" and cell.cargoEntry then
                    CARGO.Transfer.Send("put", CARGO.Grid.RefOf(cell.cargoEntry),
                        cell.cargoEntry.count or 1)
                end
            end,
        })
        lootGrid.panel:Dock(FILL)
        lootGrid.panel:DockMargin(0, 8, 0, 0)
        lootGrid.Refresh()
    end

    -- ---------------- center column: equipment ----------------
    local center = vgui.Create("DPanel", frame)
    center:SetPos(x0 + colL + gap, y0)
    center:SetSize(colC, colH)
    center.Paint = function(_, w, h) T.PaintPanel(w, h) end
    BuildEquipColumn(center, s)

    -- ---------------- right column: own inventory ----------------
    local right = vgui.Create("DPanel", frame)
    right:SetPos(x0 + colL + gap + colC + gap, y0)
    right:SetSize(colR, colH)
    right.Paint = function(_, w, h) T.PaintPanel(w, h) end
    right:DockPadding(8, 8, 8, 8)

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
            -- the money button docks on the right edge: text sits left of it.
            -- No provider subtitle (author call, 2nd fullscreen pass
            -- 2026-07-12: the "native USD / provider" line was noise).
            draw.SimpleText(snap.money or "?", "CargoTitle", w - 56, 16,
                T.Colors.money, TEXT_ALIGN_RIGHT)
        end
    end

    local avatar = vgui.Create("AvatarImage", header)
    avatar:SetPos(10, 8)
    avatar:SetSize(40, 40)
    avatar:SetPlayer(LocalPlayer(), 64)

    -- money button (§15.3): the trigger is Cargo's; the mechanics (drop-money
    -- entity in Solo, money-only basket line in Trade) are Cargo_Trade §7 —
    -- SLICE 2 of the trade block, which hooks in via CARGO.Trade.MoneyButton.
    local moneyBtn = vgui.Create("DButton", header)
    moneyBtn:Dock(RIGHT)
    moneyBtn:SetWide(36)
    moneyBtn:DockMargin(0, 10, 10, 10)
    moneyBtn:SetText("")
    moneyBtn:SetTooltip("Solo: drop money · Trade: offer money")
    moneyBtn.Paint = function(self, w, h)
        local cx, cy, r = w / 2, h / 2, math.min(w, h) / 2 - 1
        T.DrawCircleOutlined(cx, cy, r,
            self:IsHovered() and T.Colors.cellHover or T.Colors.cell,
            self:IsHovered() and T.Colors.amber or T.Colors.borderHi, 1)
        draw.SimpleText("$", "CargoHeading", cx, cy, T.Colors.amber,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    moneyBtn.DoClick = function()
        if istable(CARGO.Trade) and isfunction(CARGO.Trade.MoneyButton) then
            CARGO.Trade.MoneyButton(frame.cargoState)
            return
        end
        chat.AddText(T.Colors.amber, "[Cargo] ", T.Colors.text,
            "Dropping and offering cash arrives with the next trade slice.")
    end

    tabsBar = vgui.Create("Panel", right)
    tabsBar:Dock(TOP)
    tabsBar:SetTall(28)
    tabsBar:DockMargin(0, 8, 0, 8)
    -- usable width for the tab wrap (dock layout hasn't run yet)
    tabsBar.cargoWide = colR - 16

    local footer = vgui.Create("DPanel", right)
    footer:Dock(BOTTOM)
    footer:SetTall(CARGO.Trade.WEIGHT_FOOTER_TALL)
    footer:DockMargin(0, 8, 0, 0)
    footer.Paint = function(_, w, h)
        T.PaintPanel(w, h)
        local snap = S()
        if snap == nil then return end

        -- the Move all button docks on the right while looting
        local rightEdge = w - (state == "loot" and 112 or 12)

        local frac = snap.capacity > 0 and snap.weight / snap.capacity or 0
        local col = T.WeightColor(frac)
        T.DrawBar(10, h / 2 - 4, w * 0.4, 8, frac, col)

        local txt = string.format("%.1f kg", snap.weight)
        local rest = string.format(" / %.1f kg (base %g + back %g)",
            snap.capacity, snap.capBase, snap.capBack)
        surface.SetFont("CargoText")
        local restW = surface.GetTextSize(rest)
        surface.SetFont("CargoHeading")
        local txtW = surface.GetTextSize(txt)
        draw.SimpleText(txt, "CargoHeading", rightEdge - restW - txtW, 8, col)
        draw.SimpleText(rest, "CargoText", rightEdge - restW, 10, T.Colors.textDim)
    end

    -- Sell strip + net + Cancel/Confirm. Docked BOTTOM *before* the grid takes
    -- FILL: a FILL sibling created first would eat the space (Derma docks in
    -- creation order).
    if state == "trade" then
        CARGO.Trade.BuildDealBar(right)
    end

    grid = CARGO.Grid.Create(right, {
        getEntries = function()
            local snap = S()
            return snap and snap.items or {}
        end,
        dragSource = "own",
        -- trade: the own grid shows what the trader WOULD PAY for each item
        -- (buyMult) and marks whatever is already pending in the basket
        priceOf = state == "trade"
            and function(entry) return CARGO.Trade.CellPrice("sell", entry) end or nil,
        basketOf = state == "trade"
            and function(entry) return CARGO.Trade.BasketCount("sell", entry) end or nil,
        -- while looting, clicks transfer (old side-by-side panel behavior);
        -- while trading they load the basket; solo keeps the item context menu
        onLeftClick = function(entry)
            if state == "loot" then
                CARGO.Transfer.Send("put", CARGO.Grid.RefOf(entry), entry.count or 1)
            elseif state == "trade" then
                -- a quarter of the stack ceiling per click; SHIFT+click loads it
                -- all (author call, 2nd in-game pass). Exact amounts: right click.
                CARGO.Trade.BasketAdd("sell", entry,
                    CARGO.Trade.ClickAmount("sell", entry))
            end
        end,
        onRightClick = function(entry)
            if state == "loot" then
                CARGO.Transfer.Menu("put", entry)
            elseif state == "trade" then
                CARGO.Trade.AmountMenu("sell", entry)
            else
                OpenItemMenu(entry)
            end
        end,
        -- dropping an equipment slot cell here unequips it; a belt cell
        -- returns its stack; a container cell (loot) is taken
        onReceiveDrop = function(cell)
            if cell.cargoSlotId then
                SendUnequip(cell.cargoSlotId)
            elseif cell.cargoBeltSlot then
                SendBeltClear(cell.cargoBeltSlot)
            elseif state == "loot" and cell.cargoSource == "cont" and cell.cargoEntry then
                CARGO.Transfer.Send("take", CARGO.Grid.RefOf(cell.cargoEntry),
                    cell.cargoEntry.count or 1)
            end
        end,
    })
    grid.panel:Dock(FILL)

    -- Move all (mock .foot box-only): dump the whole inventory into the
    -- container. Lives in the weight footer, loot state only.
    if state == "loot" then
        local moveAll = vgui.Create("DButton", footer)
        moveAll:Dock(RIGHT)
        moveAll:SetWide(88)
        moveAll:DockMargin(6, 5, 6, 5)
        moveAll:SetText("")
        moveAll.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h,
                self:IsHovered() and T.Colors.cellHover or T.Colors.panelAlt)
            surface.SetDrawColor(T.Colors.borderHi)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("Move all", "CargoText", w / 2, h / 2,
                T.Colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        moveAll.DoClick = function() CARGO.Transfer.TakeAll("put") end
    end

    BuildTabs(tabsBar)
    grid.Refresh()
    if state == "trade" then CARGO.Trade.RefreshStrips(tradeLeft) end
    CARGO.Sounds.Play(state == "solo" and "open_solo" or "open_ext")
end

-- ------------------------------------------------------------------
-- State + open/close
-- ------------------------------------------------------------------

function CARGO.UI.RefreshAll()
    if not IsValid(frame) then return end
    -- the inventory changed under an open basket (a sale went through, an
    -- item was used elsewhere): whatever the basket promised and no longer
    -- exists leaves it now, before anything repaints (Cargo_Trade §3)
    if frame.cargoState == "trade" then CARGO.Trade.PruneBasket() end
    BuildTabs(tabsBar)
    grid.Refresh()
    if frame.cargoState == "trade" then CARGO.Trade.RefreshStrips(tradeLeft) end
    -- equipment/quick/header/footer paint straight from the snapshot
end

-- container opened (corpus_cargo_transfer.lua): same frame, Loot state
function CARGO.UI.OpenLoot()
    BuildFrame("loot")
end

-- container snapshot changed: only the left column needs repopulating
function CARGO.UI.RefreshLoot()
    if IsValid(frame) and frame.cargoState == "loot" and lootGrid then
        lootGrid.Refresh()
    end
end

-- trader opened (corpus_cargo_trade.lua): same frame, Trade state
function CARGO.UI.OpenTrade()
    BuildFrame("trade")
end

-- trader stock or basket changed: stock grid, own grid (basket marks) and
-- both strips repaint from the same snapshot + basket
function CARGO.UI.RefreshTrade()
    if not IsValid(frame) or frame.cargoState ~= "trade" then return end
    if IsValid(tradeLeft) and tradeLeft.cargoStockGrid then
        tradeLeft.cargoStockGrid.Refresh()
    end
    if grid then grid.Refresh() end
    CARGO.Trade.RefreshStrips(tradeLeft)
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
    -- quick and belt are sparse numeric maps: the JSON hop stringifies
    -- their keys
    snap.quick = CARGO.Util.NumberKeys(snap.quick)
    snap.belt = CARGO.Util.NumberKeys(snap.belt)

    -- server-side auto-generated defs (captured engine weapons) arrive with
    -- the snapshot; the container and the trader carry them the same way
    CARGO.Items.AbsorbDefs(snap)

    CARGO.ClientState = snap
    if pendingOpen then
        pendingOpen = nil
        BuildFrame("solo")
    else
        -- also refreshes the own grid while looting — the loot column has
        -- its own sync channel (corpus_cargo_transfer.lua)
        CARGO.UI.RefreshAll()
    end
end)

net.Receive(NET_NOTICE, function()
    chat.AddText(T.Colors.amber, "[Cargo] ", T.Colors.text, net.ReadString())
end)

concommand.Add("cargo_inventory", function()
    CARGO.UI.Toggle()
end, nil, "Opens/closes the Cargo inventory")

-- bindable twin of the slot-menu option (roadmap #26)
concommand.Add("cargo_unload", function()
    SendUnload()
end, nil, "Unloads the held weapon's magazine onto the ammo belt (grid if full)")

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
