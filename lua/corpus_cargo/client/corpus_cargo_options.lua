-- corpus_cargo_options.lua — Q menu entry (CLIENT)
-- Single entry through the Corpus.UI primitive (Utilities → Corpus →
-- Cargo), same pattern as Caliber's options tab: stacked convar controls
-- on the spawnmenu form panel.

local CARGO = Corpus.GetModule("cargo")

local function BuildCargoTab(p)
    p:Help("Cargo — inventory: uniform grid, weight, equipment slots, containers.")

    p:Button("Open inventory (key I by default)").DoClick = function()
        RunConsoleCommand("cargo_inventory")
    end

    p:Help("Client")

    -- click the binder, press the desired key (writes cargo_key_inventory)
    p:Help("Inventory key:")
    local binder = vgui.Create("DBinder", p)
    binder:SetTall(30)
    local cvInvKey = GetConVar("cargo_key_inventory")
    if cvInvKey then binder:SetValue(cvInvKey:GetInt()) end
    binder.OnChange = function(_, num)
        RunConsoleCommand("cargo_key_inventory", tostring(num))
    end
    p:AddItem(binder)
    p:Help("Console alternative: bind <key> cargo_inventory")

    -- drop the weapon in hand (roadmap #17); writes cargo_key_drop
    p:Help("Drop weapon key:")
    local dropBinder = vgui.Create("DBinder", p)
    dropBinder:SetTall(30)
    local cvDropKey = GetConVar("cargo_key_drop")
    if cvDropKey then dropBinder:SetValue(cvDropKey:GetInt()) end
    dropBinder.OnChange = function(_, num)
        RunConsoleCommand("cargo_key_drop", tostring(num))
    end
    p:AddItem(dropBinder)
    p:Help("Console alternative: bind <key> cargo_drop (the 'Drop Weapon' mod's +drop takes precedence if mounted)")

    -- weapon wheel (#31): enable + key + chip anchors, all in one place
    -- (author ask: changing the key must be easy and live where the rest
    -- of Cargo's options already live)
    p:CheckBox("Weapon wheel (hold the key, release to commit)", "cargo_wheel")
    p:Help("Wheel key:")
    local wheelBinder = vgui.Create("DBinder", p)
    wheelBinder:SetTall(30)
    local cvWheelKey = GetConVar("cargo_key_wheel")
    if cvWheelKey then wheelBinder:SetValue(cvWheelKey:GetInt()) end
    wheelBinder.OnChange = function(_, num)
        RunConsoleCommand("cargo_key_wheel", tostring(num))
    end
    p:AddItem(wheelBinder)
    p:Help("Console alternative: bind <key> +cargo_wheel")

    local quickAnchor = p:ComboBox("Wheel quick-chips anchor", "cargo_wheel_quick_anchor")
    quickAnchor:AddChoice("bottom")
    quickAnchor:AddChoice("top")
    quickAnchor:AddChoice("left")
    quickAnchor:AddChoice("right")
    local toolsAnchor = p:ComboBox("Wheel tool-chips anchor", "cargo_wheel_tools_anchor")
    toolsAnchor:AddChoice("right")
    toolsAnchor:AddChoice("left")
    toolsAnchor:AddChoice("bottom")
    toolsAnchor:AddChoice("top")
    p:Help("If both groups pick the same side, the tool chips fall back to the nearest free one.")

    p:CheckBox("Quick slots on F1-F4 (intercepts gm_showhelp/showteam/spare1/spare2)", "cargo_quick_f")
    p:CheckBox("STALKER weapon keys (1 melee, 2 sidearm, 3 primary, 4 secondary, 5-7 tools)", "cargo_weapon_slots")
    p:Help("Pressing the key of the weapon you are holding holsters it. Console: cargo_holster.")
    p:CheckBox("Holster to Hands (uncheck to holster to nothing at all)", "cargo_holster_hands")
    p:CheckBox("On-screen pickup feed (what you just picked up)", "cargo_pickup_feed")
    p:CheckBox("Demo bars (health/HL2 armor) on the status panel", "cargo_dev_bars")

    p:CheckBox("Sandbox tool circles (physgun/toolgun/camera) in the inventory and wheel", "cargo_ui_tools")
    local alignCombo = p:ComboBox("Tool circles alignment", "cargo_ui_tools_align")
    alignCombo:AddChoice("left")
    alignCombo:AddChoice("center")

    p:Help("Server (replicated convars; changing them needs server rights)")
    p:Help("cargo_capacity_base — base carry capacity in kg (54). cargo_quick_base — quick slots with no suit (2). cargo_arc9_bridge — ARC9 attachment bridge (1). cargo_capture_weapons — engine-given weapons go to the inventory (1).")

    p:Help("Icon editor (dev) — pick an item to frame its icon and footprint")
    p:AddItem(CARGO.IconEditor.BuildBrowser(p))
    p:Help("Console: cargo_icon_edit <defid> · cargo_icon_regen_all — rebuild the whole icon cache")

    p:Help("Verification")
    p:Help("cargo_selftest — primitives self-test in this realm. cargo_dev_give — test item kit (server). cargo_dev_money — +$1000 (server). cargo_dev_atts [n] [filter] — bridged ARC9 attachments (server).")
end

Corpus.UI.RegisterTab("cargo", "Cargo", BuildCargoTab)
