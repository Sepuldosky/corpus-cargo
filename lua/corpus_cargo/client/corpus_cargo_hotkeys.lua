-- corpus_cargo_hotkeys.lua — STALKER weapon order, client side (CLIENT)
-- Roadmap #22: the number row maps to equipment slots (1 melee, 2 sidearm,
-- 3 primary, 4 secondary, 5 physgun, 6 toolgun, 7 camera — data in
-- CARGO.Slots.Hotkeys) and replaces the GMod bucket bar for those keys.
-- The key only reports an intent; the server (corpus_cargo_holster.lua)
-- resolves it against the equipment record: select the slot's weapon,
-- holster if it is already in hand, ignore if the slot is empty.

local CARGO = Corpus.GetModule("cargo")

local NET_SLOTKEY = Corpus.Net.Register("cargo", "slotkey")

local cvSlots = CreateClientConVar("cargo_weapon_slots", "1", true, false,
    "STALKER weapon keys: 1 melee, 2 sidearm, 3 primary, 4 secondary, 5-7 sandbox tools; the active slot's key holsters")

-- userinfo: the server reads the holster style with ply:GetInfoNum
CreateClientConVar("cargo_holster_hands", "1", true, true,
    "Holster to the Hands SWEP (1) or to nothing at all (0)")

local function SendSlotKey(n)
    net.Start(NET_SLOTKEY)
    net.WriteUInt(n, 4)
    net.SendToServer()
end

hook.Add("PlayerBindPress", "corpus_cargo_hotkeys", function(_, bind, pressed)
    if not pressed or not cvSlots:GetBool() then return end
    local n = tonumber(string.match(bind, "^slot(%d+)$") or "")
    if n == nil or CARGO.Slots.Hotkeys[n] == nil then return end -- 8/9/0: stock GMod
    SendSlotKey(n)
    return true -- the bucket bar never opens for a mapped key
end)

concommand.Add("cargo_holster", function()
    SendSlotKey(0)
end, nil, "Holsters the current weapon (Hands SWEP or nothing, per cargo_holster_hands)")

-- Drop key (roadmap #17): a bindable key that drops the weapon in hand,
-- same input-polling pattern as the inventory key (PlayerButtonDown does not
-- fire client-side in singleplayer). Default 0 = unbound; set it with the
-- binder in the Q tab or `bind <key> cargo_drop`. The command itself and the
-- reconciliation live server-side (corpus_cargo_capture.lua).
local cvDropKey = CreateClientConVar("cargo_key_drop", "0", true, false,
    "Key (KEY_* enum) that drops the weapon in hand (0 = unbound; console: cargo_drop)")

local dropKeyWasDown = false
hook.Add("Think", "corpus_cargo_drop_key", function()
    local key = cvDropKey:GetInt()
    if key <= 0 then dropKeyWasDown = false return end

    local down = input.IsButtonDown(key)
    if down and not dropKeyWasDown
        and not gui.IsGameUIVisible()
        and vgui.GetKeyboardFocus() == nil then
        RunConsoleCommand("cargo_drop")
    end
    dropKeyWasDown = down
end)
