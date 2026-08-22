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

-- What ONE click transfers, per direction — the loot view's adapter onto the
-- module's single gradation (CARGO.Grid.ClickAmount, CRG-74, roadmap #69).
-- Same shape as CARGO.Trade.ClickAmount and for the same reason: all an
-- adapter adds is WHICH LIST the aggregate is counted over — the container for
-- a take, the player's grid for a put — while the three amounts and the keys
-- live in one place for the whole module.
--
-- This is the half the loot view did not have: until now M1 sent
-- `entry.count or 1`, the whole stack of the cell, with no SHIFT and no ALT,
-- so the same gesture meant one thing here and another at the trader. The cost
-- of closing that, and the author was told before the pass: a bare M1 now
-- moves a quarter, so a full stack is four clicks — or one SHIFT+M1.
--
-- There is NO M3 here, and that is a decision and not an omission (author,
-- 2026-08-19): a loot transfer is immediate, so there is no basket and nothing
-- to deselect. The inverse transfer was the other reading and he turned it
-- down as counter-intuitive — it is already reachable as M1 on the other
-- column, which is where every inventory puts it.
function CARGO.Transfer.ClickAmount(dir, entry)
    local list
    if dir == "take" then
        list = contState and contState.items or {}
    else
        list = CARGO.ClientState and CARGO.ClientState.items or {}
    end
    return CARGO.Grid.ClickAmount(entry, CARGO.Grid.Aggregate(list, entry))
end

function CARGO.Transfer.TakeAll(dir)
    if contState == nil then return end
    net.Start(NET_TAKEALL)
    net.WriteUInt(contState.contId, 16)
    net.WriteString(dir)
    net.SendToServer()
end

-- The transfer verbs ALONE, as rows on a menu somebody else owns (roadmap
-- #76). The player's grid inside the loot no longer opens a menu of its own:
-- it opens THE item menu (CARGO.UI.ItemMenu) and this is the section that menu
-- asks for, so "Move" keeps living in the file that owns the transfer wire
-- while the favorite and the drop keep living in the one that owns them.
--
-- The verb is the AUTHOR'S RULE and not a per-window label (2026-08-21):
-- «"drop" es siempre tirar al piso, al contenedor es "mover"». The two verbs
-- share the loot menu without ambiguity because they name different
-- DESTINATIONS, not the same action in two contexts.
function CARGO.Transfer.AddVerbs(menu, dir, entry)
    local verb = dir == "take" and "Take" or "Move"
    menu:AddOption(verb .. " 1", function()
        CARGO.Transfer.Send(dir, CARGO.Grid.RefOf(entry), 1)
    end)
    if (entry.count or 1) > 1 then
        -- partial amount (author ask, first fullscreen pass): prompt for N
        menu:AddOption(verb .. " amount...", function()
            CARGO.Theme.Prompt(verb .. " how many?",
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
end

-- The CONTAINER column's menu (right click on the loot side). It stays a menu
-- of its own and stays transfer-only on purpose: what is in the crate is not
-- yours yet, so there is nothing there to favorite and nothing to drop — the
-- ref those two intents take names a cell of YOUR record.
function CARGO.Transfer.Menu(dir, entry)
    local menu = CARGO.Theme.Menu()
    CARGO.Transfer.AddVerbs(menu, dir, entry)
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

-- The loot column can show an item this client never held — a captured
-- weapon's def is minted server-side, so it rides the snapshot or the cell
-- draws blank and 1×1 (in-game report 2026-07-26, a persisted crate).
net.Receive(NET_CONT_OPEN, function()
    contState = CARGO.Util.ReadBlob()
    if contState == nil then return end
    CARGO.Items.AbsorbDefs(contState)
    CARGO.UI.OpenLoot()
end)

net.Receive(NET_CONT_SYNC, function()
    local snap = CARGO.Util.ReadBlob()
    if snap == nil or contState == nil then return end
    if snap.contId == contState.contId then
        CARGO.Items.AbsorbDefs(snap)
        contState = snap
        CARGO.UI.RefreshLoot()
    end
end)
