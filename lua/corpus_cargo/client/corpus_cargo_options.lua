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

    p:CheckBox("Quick slots on F1-F4 (intercepts gm_showhelp/showteam/spare1/spare2)", "cargo_quick_f")
    p:CheckBox("On-screen pickup feed (what you just picked up)", "cargo_pickup_feed")
    p:CheckBox("Demo bars (health/HL2 armor) on the status panel", "cargo_dev_bars")

    p:Help("Server (replicated convars; changing them needs server rights)")
    p:Help("cargo_capacity_base — base carry capacity in kg (54). cargo_quick_base — quick slots with no suit (2). cargo_arc9_bridge — ARC9 attachment bridge (1). cargo_capture_weapons — engine-given weapons go to the inventory (1).")

    p:Help("Icon editor (dev) — pick an item to frame its icon and footprint")
    p:AddItem(CARGO.IconEditor.BuildBrowser(p))
    p:Help("Console: cargo_icon_edit <defid> · cargo_icon_regen_all — rebuild the whole icon cache")

    p:Help("Verification")
    p:Help("cargo_selftest — primitives self-test in this realm. cargo_dev_give — test item kit (server). cargo_dev_money — +$1000 (server). cargo_dev_atts [n] [filter] — bridged ARC9 attachments (server).")
end

Corpus.UI.RegisterTab("cargo", "Cargo", BuildCargoTab)
