-- corpus_cargo_sounds.lua — UI sound bank (CLIENT)
-- Default cues come from the ecosystem sound bank hosted by the framework repo
-- (corpus/sound/corpus/cargo/..., STALKER GAMMA ports — assets unversioned,
-- COR-17). Every play goes through an Exists() gate: a tree cloned without the
-- bank stays SILENT instead of spamming console errors — the same honest
-- degradation the Zone item models use (detection, never assumption).
-- Category → set map per the author's notes in sound/corpus/cargo/items/about.txt:
-- SIDEARM = inv_items_wpn_x, PRIMARY/SECONDARY = inv_items_wpnbig_x.

local CARGO = Corpus.GetModule("cargo")

CARGO.Sounds = CARGO.Sounds or {}
local Sounds = CARGO.Sounds

local ROOT = "corpus/cargo/"

-- resolved once per path: hitting the disk on every grid click would be waste
local exists = {}
local function Playable(path)
    if exists[path] == nil then
        exists[path] = file.Exists("sound/" .. path, "GAME")
    end
    return exists[path]
end

local function PlayOne(set)
    if not istable(set) or #set == 0 then return end
    local path = set[math.random(#set)]
    if Playable(path) then surface.PlaySound(path) end
end

-- ------------------------------------------------------------------
-- Named UI cues (sound/corpus/cargo/ui/about.txt): the personal inventory
-- opens like a backpack; trader/container/trade screens open like a case.
-- ------------------------------------------------------------------

local UI = {
    open_solo  = { ROOT .. "ui/backpack_open.ogg" },
    close_solo = { ROOT .. "ui/backpack_close.ogg" },
    open_ext   = { ROOT .. "ui/inv_open.ogg" },
    close_ext  = { ROOT .. "ui/inv_close.ogg" },
    drop       = { ROOT .. "ui/inv_drop.ogg" },
}

function Sounds.Play(cue)
    PlayOne(UI[cue])
end

-- ------------------------------------------------------------------
-- Item selection by category (grid click). Sets are numbered variants of the
-- same foley — one is picked at random, STALKER style.
-- ------------------------------------------------------------------

local function Set(base, n)
    local t = {}
    for i = 1, n do t[i] = ROOT .. "items/inv_items_" .. base .. i .. ".ogg" end
    return t
end

local GENERIC = Set("generic_", 6)
local WPN     = Set("wpn_", 2)
local WPNBIG  = Set("wpnbig_", 2)

local PICK = {
    ammo        = Set("ammo_", 7),
    medical     = Set("pills_", 2),
    melee       = Set("knife_", 2),
    armor       = Set("cloth_", 6),
    helmets     = Set("cloth_", 6),
    backpacks   = Set("cloth_", 6),
    attachments = Set("parts_", 3),
    optics      = Set("parts_", 3),
    plates      = Set("parts_", 3),
    throwables  = WPN,
}

function Sounds.PickFor(def)
    if not istable(def) then return PlayOne(GENERIC) end
    if def.category == "weapons" then
        -- the wpn/wpnbig split follows the equip slot, not the category: a def
        -- restricted to Sidearm alone is the small foley (KIND_SLOTS shape)
        local slots = def.equip_slots
        local sidearmOnly = istable(slots) and #slots == 1 and slots[1] == "sidearm"
        return PlayOne(sidearmOnly and WPN or WPNBIG)
    end
    PlayOne(PICK[def.category] or GENERIC)
end
