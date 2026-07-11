-- corpus_cargo_pickup.lua — on-screen pickup feed (CLIENT)
-- Signals the item just taken into the inventory (weapon capture, world
-- drop). This is Cargo's own "what did I pick up" cue — it replaces the
-- look-at highlight that external pickup mods used to give, now that the
-- capture is automatic and instant. Convar cargo_pickup_feed disables it.

local CARGO = Corpus.GetModule("cargo")

local T = CARGO.Theme
local NET_PICKUP = Corpus.Net.Register("cargo", "pickup")

local cvFeed = CreateClientConVar("cargo_pickup_feed", "1", true, false,
    "Show an on-screen feed of items picked up into the inventory")

local feed = {}                 -- { { name, count, born }, ... } newest last
local HOLD, FADE = 3.0, 1.5     -- seconds held solid, then faded
local MAX_LINES = 6

net.Receive(NET_PICKUP, function()
    local id = net.ReadString()
    local count = net.ReadUInt(16)
    if not cvFeed:GetBool() then return end

    -- name from our own registered def; captured engine weapons resolved
    -- their #token in the Sync that arrived just before this message
    local def = CARGO.Items.Get(id)
    local name = def and def.name or id
    if isstring(name) and name:sub(1, 1) == "#" then
        name = language.GetPhrase(name:sub(2))
    end

    feed[#feed + 1] = { name = name, count = count, born = CurTime() }
    while #feed > MAX_LINES do table.remove(feed, 1) end
end)

hook.Add("HUDPaint", "corpus_cargo_pickup_feed", function()
    if #feed == 0 or not cvFeed:GetBool() then return end

    local x = ScrW() * 0.5
    local y = ScrH() * 0.66
    local now = CurTime()

    -- newest at the bottom, older stacking upward; prune expired in place
    for i = #feed, 1, -1 do
        local e = feed[i]
        local age = now - e.born
        if age > HOLD + FADE then
            table.remove(feed, i)
        else
            local a = age < HOLD and 255 or (255 * (1 - (age - HOLD) / FADE))
            local label = "+ " .. e.name .. (e.count > 1 and (" x" .. e.count) or "")
            draw.SimpleText(label, "CargoText", x + 1, y + 1,
                ColorAlpha(color_black, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(label, "CargoText", x, y,
                ColorAlpha(T.Colors.green, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            y = y - 20
        end
    end
end)
