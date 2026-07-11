-- corpus_cargo_money.lua — money provider interface + native USD (SERVER)
-- Cargo_Architecture.md §6. Cargo owns the INTERFACE (get/add/take/format)
-- and one native fallback provider; it does not impose an economy. External
-- frameworks (DarkRP etc.) register against the same interface and the last
-- one registered becomes active.

local CARGO = Corpus.GetModule("cargo")

CARGO.Money = CARGO.Money or {}
CARGO.Money._providers = CARGO.Money._providers or {}
CARGO.Money._active = CARGO.Money._active or "usd"

local cvStart = CreateConVar("cargo_money_start", "1000", FCVAR_ARCHIVE,
    "Starting balance of the native USD provider", 0, 1000000)

-- iface: { get = f(ply)->number, add = f(ply, amt), take = f(ply, amt)->bool,
--          format = f(amt)->string, label = display string }
function CARGO.Money.RegisterProvider(name, iface)
    if not isstring(name) or name == "" then
        error("Cargo.Money.RegisterProvider: 'name' must be a non-empty string", 2)
    end
    if not istable(iface) or not isfunction(iface.get) or not isfunction(iface.add)
        or not isfunction(iface.take) or not isfunction(iface.format) then
        error("Cargo.Money.RegisterProvider: iface needs get/add/take/format functions ('" .. name .. "')", 2)
    end

    iface.label = iface.label or name
    CARGO.Money._providers[name] = iface

    -- An external provider replaces the native fallback the moment it
    -- registers; "usd" never displaces someone else.
    if name ~= "usd" then
        CARGO.Money._active = name
        Corpus.Log("cargo", "Money: provider activo -> '" .. name .. "'")
    end
end

function CARGO.Money.SetActive(name)
    if CARGO.Money._providers[name] == nil then
        error("Cargo.Money.SetActive: unknown provider '" .. tostring(name) .. "'", 2)
    end
    CARGO.Money._active = name
end

function CARGO.Money.Active()
    return CARGO.Money._providers[CARGO.Money._active], CARGO.Money._active
end

function CARGO.Money.Get(ply)         return CARGO.Money.Active().get(ply) end
function CARGO.Money.Add(ply, amt)    return CARGO.Money.Active().add(ply, amt) end
function CARGO.Money.Take(ply, amt)   return CARGO.Money.Active().take(ply, amt) end
function CARGO.Money.Format(amt)      return CARGO.Money.Active().format(amt) end
function CARGO.Money.Label()          return CARGO.Money.Active().label end

-- ------------------------------------------------------------------
-- Native USD provider — the fallback when nothing else registers.
-- Balance lives in the player's inventory record (wallet.usd), so it
-- persists through the same Corpus.Data file as the rest of the inventory.
-- ------------------------------------------------------------------

local function Wallet(ply)
    -- CARGO.Inventory loads after this file in the manifest; these closures
    -- only run at request time, well past boot.
    local rec = CARGO.Inventory.GetRecord(ply)
    rec.wallet = rec.wallet or {}
    if rec.wallet.usd == nil then rec.wallet.usd = cvStart:GetInt() end
    return rec.wallet
end

CARGO.Money.RegisterProvider("usd", {
    label = "native USD",
    get = function(ply)
        return Wallet(ply).usd
    end,
    add = function(ply, amt)
        local w = Wallet(ply)
        w.usd = math.max(w.usd + amt, 0)
        CARGO.Inventory.SaveRecord(ply)
    end,
    take = function(ply, amt)
        local w = Wallet(ply)
        if w.usd < amt then return false end
        w.usd = w.usd - amt
        CARGO.Inventory.SaveRecord(ply)
        return true
    end,
    format = function(amt)
        -- $1,250 — thousands separator, no decimals
        local s = tostring(math.floor(amt))
        local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return "$" .. formatted
    end,
})
