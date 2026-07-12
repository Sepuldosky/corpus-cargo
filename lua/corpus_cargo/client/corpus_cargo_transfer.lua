-- corpus_cargo_transfer.lua — container/loot wire state (CLIENT)
-- Cargo_Architecture.md §8 + §15.1: the old side-by-side transfer frame is
-- gone — using a container opens the single fullscreen frame in its Loot
-- state (left column = container, right = own inventory). This file owns
-- the container snapshot and the transfer intents; corpus_cargo_ui.lua
-- owns every panel and calls back into these senders.

local CARGO = Corpus.GetModule("cargo")

CARGO.Transfer = CARGO.Transfer or {}

local NET_CONT_OPEN  = Corpus.Net.Register("cargo", "container_open")
local NET_CONT_SYNC  = Corpus.Net.Register("cargo", "container_sync")
local NET_CONT_CLOSE = Corpus.Net.Register("cargo", "container_close")
local NET_TRANSFER   = Corpus.Net.Register("cargo", "transfer")
local NET_TAKEALL    = Corpus.Net.Register("cargo", "takeall")

local contState

-- read-only access for the loot column (items/name/weight/capacity)
function CARGO.Transfer.State()
    return contState
end

-- dir: "take" (container -> player) | "put" (player -> container)
function CARGO.Transfer.Send(dir, ref, count)
    if contState == nil then return end
    net.Start(NET_TRANSFER)
    net.WriteUInt(contState.contId, 16)
    net.WriteString(dir)
    net.WriteUInt(math.min(count or 1, 65535), 16)
    CARGO.Util.WriteBlob(ref)
    net.SendToServer()
end

function CARGO.Transfer.TakeAll(dir)
    if contState == nil then return end
    net.Start(NET_TAKEALL)
    net.WriteUInt(contState.contId, 16)
    net.WriteString(dir)
    net.SendToServer()
end

-- transfer amount menu (right click on either grid while looting)
function CARGO.Transfer.Menu(dir, entry)
    local menu = DermaMenu()
    local verb = dir == "take" and "Take" or "Move"
    menu:AddOption(verb .. " 1", function()
        CARGO.Transfer.Send(dir, CARGO.Grid.RefOf(entry), 1)
    end)
    if (entry.count or 1) > 1 then
        -- partial amount (author ask, first fullscreen pass): prompt for N
        menu:AddOption(verb .. " amount...", function()
            Derma_StringRequest(verb .. " how many?",
                "1 - " .. entry.count, "",
                function(txt)
                    local n = math.floor(tonumber(txt) or 0)
                    if n >= 1 then
                        CARGO.Transfer.Send(dir, CARGO.Grid.RefOf(entry),
                            math.min(n, entry.count))
                    end
                end)
        end)
        menu:AddOption(verb .. " whole stack (x" .. entry.count .. ")", function()
            CARGO.Transfer.Send(dir, CARGO.Grid.RefOf(entry), entry.count)
        end)
    end
    menu:Open()
end

-- the frame calls this when the loot view closes, so the server drops us
-- from the container's viewer list
function CARGO.Transfer.NotifyClosed()
    if contState == nil then return end
    net.Start(NET_CONT_CLOSE)
    net.WriteUInt(contState.contId, 16)
    net.SendToServer()
    contState = nil
end

net.Receive(NET_CONT_OPEN, function()
    contState = CARGO.Util.ReadBlob()
    if contState then CARGO.UI.OpenLoot() end
end)

net.Receive(NET_CONT_SYNC, function()
    local snap = CARGO.Util.ReadBlob()
    if snap == nil or contState == nil then return end
    if snap.contId == contState.contId then
        contState = snap
        CARGO.UI.RefreshLoot()
    end
end)
