-- corpus_cargo_util.lua — small shared helpers (SHARED, no domain logic)

local CARGO = Corpus.GetModule("cargo")

CARGO.Util = CARGO.Util or {}

-- Net payload helpers. Inventory snapshots are nested tables of arbitrary
-- size; compressed JSON beats net.WriteTable in size and avoids its type
-- quirks. 24 bits of length = 16 MB ceiling, far above any real payload.
function CARGO.Util.WriteBlob(tbl)
    local raw = util.Compress(util.TableToJSON(tbl))
    net.WriteUInt(#raw, 24)
    net.WriteData(raw, #raw)
end

function CARGO.Util.ReadBlob()
    local len = net.ReadUInt(24)
    local raw = net.ReadData(len)
    local json = util.Decompress(raw)
    if not json or json == "" then return nil end
    return util.JSONToTable(json)
end

-- JSON round-trips through Corpus.Data do NOT preserve key types (see
-- corpus_data.lua header): a table indexed by 1..4 can come back with string
-- keys. Every loader that uses numeric keys re-normalizes with this.
function CARGO.Util.NumberKeys(tbl)
    if not istable(tbl) then return {} end
    local out = {}
    for k, v in pairs(tbl) do
        local n = tonumber(k)
        if n ~= nil then out[n] = v end
    end
    return out
end
