-- corpus_cargo_icons.lua — icon cam/footprint override registry (SERVER)
-- Cargo_ItemImages §4.3/§10. Overrides are DEF-level data (not instance):
-- the server owns and persists them (Corpus.Data) and they travel to every
-- client inside the def snapshot Cargo already syncs — the same channel
-- autogen defs ride. The PNGs themselves NEVER sync: each client renders
-- its own local cache.
--
-- This is the only server surface of the icon system, and it exists solely
-- so the dev editor (§8) has somewhere to save: autogen defs have no code
-- to edit, the data override is their only adjustment channel.

local CARGO = Corpus.GetModule("cargo")

local NET_ICON_OVERRIDE = Corpus.Net.Register("cargo", "icon_override")

-- SERVER CONFIG, not game state (COR-19): a hand-framed icon is a catalog
-- decision about a def, so it outlives deleting a save. Declared here; today
-- both scopes still resolve to the same folder, so nothing moves.
local CATALOG = { scope = "config" }

-- load persisted overrides and re-attach them to every def already
-- registered; defs that register later (capture autogen) merge inside
-- Items.Register itself
CARGO.Items._iconOverrides = Corpus.Data.Load("cargo", "icon_overrides", CATALOG) or {}

for id, ovr in pairs(CARGO.Items._iconOverrides) do
    local def = CARGO.Items.Get(id)
    if def ~= nil then def.icon_override = ovr end
end

-- ------------------------------------------------------------------
-- Editor save channel. Defensive validation: overrides render on every
-- client, so a malformed table must never reach the def snapshot.
-- ------------------------------------------------------------------

local function CleanNumber(v, min, max)
    v = tonumber(v)
    if v == nil then return nil end
    return math.Clamp(v, min, max)
end

-- returns a clean override table, or nil when nothing valid remains
local function SanitizeOverride(blob)
    if not istable(blob) then return nil end
    local out = {}

    local cam = blob.cam
    if istable(cam) and istable(cam.pos) and istable(cam.ang) then
        local px = CleanNumber(cam.pos.x, -16000, 16000)
        local py = CleanNumber(cam.pos.y, -16000, 16000)
        local pz = CleanNumber(cam.pos.z, -16000, 16000)
        local ap = CleanNumber(cam.ang.p, -360, 360)
        local ay = CleanNumber(cam.ang.y, -360, 360)
        local ar = CleanNumber(cam.ang.r, -360, 360)
        local fov = CleanNumber(cam.fov, 1, 170)
        if px and py and pz and ap and ay and ar and fov then
            out.cam = {
                pos = { x = px, y = py, z = pz },
                ang = { p = ap, y = ay, r = ar },
                fov = fov,
            }
        end
    end

    local size = blob.size
    if istable(size) then
        local w, h = tonumber(size.w or size[1]), tonumber(size.h or size[2])
        if CARGO.Items.IsAllowedFootprint(w, h) then
            out.size = { w = w, h = h }
        end
    end

    if out.cam == nil and out.size == nil then return nil end
    return out
end

-- TODO: gate behind the future Corpus admin permission primitive (own
-- design session pending, roadmap #12) — same standing TODO as every
-- Cargo dev command; until then this is open like cargo_dev_give.
net.Receive(NET_ICON_OVERRIDE, function(_, ply)
    if not IsValid(ply) then return end
    local defid = net.ReadString()
    local clear = net.ReadBool()
    local blob = CARGO.Util.ReadBlob()

    local def = CARGO.Items.Get(defid)
    if def == nil then
        Corpus.Log("cargo", "icons: override para def desconocida '" .. tostring(defid) .. "' ignorado")
        return
    end

    local ovr = clear and nil or SanitizeOverride(blob)
    if not clear and ovr == nil then
        Corpus.Log("cargo", "icons: override inválido para '" .. defid .. "' ignorado")
        return
    end

    CARGO.Items._iconOverrides[defid] = ovr
    Corpus.Data.Save("cargo", "icon_overrides", CARGO.Items._iconOverrides, CATALOG)
    def.icon_override = ovr

    -- push the updated def to every client over the existing snapshot
    -- channel; each client invalidates and re-renders locally (§10)
    for _, p in ipairs(player.GetAll()) do
        CARGO.Inventory.Sync(p)
    end

    Corpus.Log("cargo", "icons: override de '" .. defid .. "' "
        .. (clear and "borrado" or "guardado") .. " por " .. ply:Nick())
end)
