-- corpus_cargo_icons.lua — item icon pipeline (CLIENT)
-- Cargo_ItemImages_Arquitectura.md. Generates the item image from its 3D
-- model (ClientsideModel -> RT -> PNG in data/ -> Material), frames it with
-- a 3-level camera hierarchy and quantizes its cell footprint. Cosmetic and
-- client-side pure: zero net cost, every client builds its own disk cache.
--
-- Source hierarchy (§2), strict order: def.icon (hand art, always wins) ->
-- generated render (this file) -> first letter (LAST resort — an error
-- signal, not an expected state).
--
-- Engine APIs verified against live code (project rule, spec header):
--   PositionSpawnIcon(ent, pos, noAngles) -> view {fov, origin, znear,
--     zfar, angles}          gmod lua/includes/util/client.lua:224
--   model draw in PostRender sandbox duplicator stool icon.lua —
--     render.Model + SetModelLighting inside cam.Start; the ONLY recipe
--     that proved to draw here (panel-context DrawModel tricks rendered
--     nothing into the RT, first gate pass 2026-07-11)
--   alpha capture            render.SetWriteDepthToDestAlpha + capture
--     alpha=true ("enhanced playermodel selector", dev/other/)
--   Material("data/x.png")   ARC9 cl_presets.lua:432 (dev/other/)

local CARGO = Corpus.GetModule("cargo")

CARGO.Icons = CARGO.Icons or {}
local Icons = CARGO.Icons

local cvBudget = CreateClientConVar("cargo_icon_budget", "2", true, false,
    "Icon renders processed per frame (lazy queue budget)")
local cvBakeBg = CreateClientConVar("cargo_icon_bake_bg", "0", true, false,
    "0 = real alpha capture (Plan A), 1 = bake the slot color into the PNG (Plan B)")

local DIR = "corpus/cargo/icons" -- data/ root; inside the Corpus.Data namespace
local CELL_PX = 64               -- render resolution per grid cell (§6)
local RT_SIZE = 512              -- one reusable work RT, cropped on capture (§6)

-- footprint auto-quantization tuning (§5: "se afinan empíricamente")
local UNITS_PER_CELL = 8    -- world units of projected OBB per grid cell
local LEN_WEIGHT     = 0.18 -- score weight per cell of long-side mismatch

-- Bump when the render recipe or the auto framing changes: the version is
-- part of the cache key, so every stale icon orphans and re-renders lazily —
-- no manual regen_all needed after a global style change shipped in code.
local RECIPE_VERSION = "r2"

-- ------------------------------------------------------------------
-- Model to RENDER for the icon. Diverges on purpose from
-- CARGO.Items.ResolveModel (which the DROP entity uses for a physics prop):
-- ARC9 weapons with MirrorVMWM set their WorldModel to a cheap CSS/HL2
-- COLLISION placeholder — verified against the ARC9 base: the WorldModel
-- comment recommends "Css/hl2 weapon worldmodels ... like w_rif_m4a1.mdl"
-- (shared.lua) and DrawWorldModel draws the viewmodel on top when
-- MirrorVMWM (cl_wm.lua). So the WorldModel is the WRONG picture (the AK-ish
-- CSS model in the icon). For the icon we want the real geometry:
-- WorldModelMirror or the ViewModel. Drops keep the WorldModel (they need a
-- collision prop; ARC9's own dropped entity has the same placeholder shadow).
function Icons.ModelFor(def)
    if not istable(def) then return nil end
    -- explicit escape hatch, always wins (for when even the viewmodel is off)
    if isstring(def.icon_model) and def.icon_model ~= "" then return def.icon_model end
    if isstring(def.model) and def.model ~= "" then return def.model end

    if isstring(def.weapon_class) then
        local stored = weapons.GetStored(def.weapon_class)
        if istable(stored) and stored.ARC9 and stored.MirrorVMWM then
            local vm = stored.WorldModelMirror
            if not (isstring(vm) and vm ~= "") then vm = stored.ViewModel end
            if isstring(vm) and vm ~= "" then return vm end
        end
    end
    return CARGO.Items.ResolveModel(def)
end

-- ------------------------------------------------------------------
-- Pure logic (offline-harness covered — no engine calls beyond stubs)
-- ------------------------------------------------------------------

-- Where the icon for this def comes from (§2): "icon" | "render" | "letter".
-- def.icon may be a material path string or an IMaterial (ARC9 atts).
function Icons.ResolveIconSource(def)
    if not istable(def) then return "letter" end
    if def.icon ~= nil and (not isstring(def.icon) or def.icon ~= "") then
        return "icon"
    end
    if Icons.ModelFor(def) ~= nil then return "render" end
    return "letter"
end

-- Projected OBB extents (world units) + category -> footprint from the
-- closed allowed set, under the per-category ceiling (§5). Never returns
-- an arbitrary size: that would break the tiered-grid flow.
function Icons.QuantizeFootprint(projW, projH, category)
    projW = isnumber(projW) and projW > 0 and projW or 1
    projH = isnumber(projH) and projH > 0 and projH or 1

    local caps = CARGO.Items.ICON_CATEGORY_CAPS
    local cap = caps[category] or caps.default
    local aspect = projW / projH
    local targetLong = math.max(projW, projH) / UNITS_PER_CELL

    local best, bestScore
    for _, fp in ipairs(CARGO.Items.ICON_FOOTPRINTS) do
        if fp[1] <= cap[1] and fp[2] <= cap[2] then
            -- closest aspect wins; the long-side term separates same-aspect
            -- candidates (3x1 vs 6x2) by projected physical length
            local score = math.abs(math.log((fp[1] / fp[2]) / aspect))
                + LEN_WEIGHT * math.abs(math.max(fp[1], fp[2]) - targetLong)
            if best == nil or score < bestScore - 1e-9
                or (math.abs(score - bestScore) <= 1e-9
                    and fp[1] * fp[2] < best[1] * best[2]) then
                best, bestScore = fp, score
            end
        end
    end
    -- {1,1} always passes every cap, so best is never nil
    return { w = best[1], h = best[2] }
end

-- effective camera as a stable string for the cache key: data override ->
-- def.icon_cam -> "auto" (§4 order). Numbers rounded so float noise never
-- renames the file.
local function CamKeyString(def)
    local ovr = istable(def.icon_override) and def.icon_override.cam or nil
    local cam = ovr or (istable(def.icon_cam) and def.icon_cam or nil)
    if cam == nil then return "auto" end
    local p, a = istable(cam.pos) and cam.pos or {}, istable(cam.ang) and cam.ang or {}
    return string.format("%.2f,%.2f,%.2f;%.2f,%.2f,%.2f;%.1f",
        tonumber(p.x) or 0, tonumber(p.y) or 0, tonumber(p.z) or 0,
        tonumber(a.p) or 0, tonumber(a.y) or 0, tonumber(a.r) or 0,
        tonumber(cam.fov) or 0)
end

-- Filename IS the invalidation key (§7): <defid>_<hash(model + effective
-- cam + effective footprint)>.png — change any input and the name changes,
-- forcing a re-render (Material() caches by path, never reuse a name).
function Icons.IconCacheKey(def)
    local model = Icons.ModelFor(def) or "none"
    local fp = Icons.GetFootprint(def)
    local input = RECIPE_VERSION .. "|" .. model .. "|" .. CamKeyString(def)
        .. "|" .. fp.w .. "x" .. fp.h
    local san = string.gsub(string.lower(def.id or "unknown"), "[^%w_%-]", "_")
    return san .. "_" .. util.CRC(input) .. ".png"
end

-- ------------------------------------------------------------------
-- Footprint resolution (§5): data override -> def.size -> auto (projected
-- OBB quantized). The auto path touches the engine (model bounds) and is
-- cached per defid.
-- ------------------------------------------------------------------

local fpCache = {}

-- OBB corners projected on the camera's right/up axes -> width/height in
-- world units as the icon camera actually sees the model
local function ProjectedExtents(ent, view)
    local mn, mx = ent:GetRenderBounds()
    local right, up = view.angles:Right(), view.angles:Up()
    local minR, maxR, minU, maxU
    for i = 0, 7 do
        local corner = Vector(
            bit.band(i, 1) == 0 and mn.x or mx.x,
            bit.band(i, 2) == 0 and mn.y or mx.y,
            bit.band(i, 4) == 0 and mn.z or mx.z)
        local r, u = corner:Dot(right), corner:Dot(up)
        if minR == nil or r < minR then minR = r end
        if maxR == nil or r > maxR then maxR = r end
        if minU == nil or u < minU then minU = u end
        if maxU == nil or u > maxU then maxU = u end
    end
    return maxR - minR, maxU - minU
end

-- accepts a defid or a def table (the table form keeps the pure paths
-- registry-independent for the offline harness)
function Icons.GetFootprint(defidOrDef)
    local def = istable(defidOrDef) and defidOrDef or CARGO.Items.Get(defidOrDef)
    if not istable(def) then return { w = 1, h = 1 } end

    -- 1) runtime data override (editor, §8) — the only channel autogen defs have
    local ovr = istable(def.icon_override) and def.icon_override.size or nil
    if istable(ovr) then
        local w, h = tonumber(ovr.w or ovr[1]), tonumber(ovr.h or ovr[2])
        if w and h then return { w = w, h = h } end
    end
    -- 2) explicit def.size in code
    if istable(def.size) then
        local w, h = tonumber(def.size.w or def.size[1]), tonumber(def.size.h or def.size[2])
        if w and h then return { w = w, h = h } end
    end
    -- 3) auto: projected OBB, quantized (engine path, cached)
    local cached = def.id and fpCache[def.id] or nil
    if cached ~= nil then return cached end

    local fp = { w = 1, h = 1 }
    local model = Icons.ModelFor(def)
    if isstring(model) and util.IsValidModel(model) then
        local ent = ClientsideModel(model, RENDERGROUP_OTHER)
        if IsValid(ent) then
            ent:SetNoDraw(true)
            local view = Icons.ResolveCam(def, ent)
            local pw, ph = ProjectedExtents(ent, view)
            ent:Remove()
            fp = Icons.QuantizeFootprint(pw, ph, def.category)
        end
    end
    if def.id then fpCache[def.id] = fp end
    return fp
end

-- ------------------------------------------------------------------
-- Camera resolution (§4), most specific wins: data override (editor) ->
-- def.icon_cam (code) -> auto (PositionSpawnIcon over the render bounds).
-- Returns a native view table {origin, angles, fov, znear, zfar}.
-- ------------------------------------------------------------------

local function ViewFromCamTable(cam, ent)
    local p = istable(cam.pos) and cam.pos or {}
    local a = istable(cam.ang) and cam.ang or {}
    local origin = Vector(tonumber(p.x) or 0, tonumber(p.y) or 0, tonumber(p.z) or 0)
    local angles = Angle(tonumber(a.p) or 0, tonumber(a.y) or 0, tonumber(a.r) or 0)
    -- far plane from the model bounds so a hand-placed camera never clips
    local mn, mx = ent:GetRenderBounds()
    local size = math.max(1, mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
    local center = (mn + mx) * 0.5
    return {
        origin = origin, angles = angles,
        fov = math.Clamp(tonumber(cam.fov) or 45, 1, 170),
        znear = 1, zfar = origin:Distance(center) + size * 2 + 64,
    }
end

-- Elongated gear reads side-on in the reference (STALKER icons are parallel
-- profiles, not the engine's isometric 3/4 — author call, gate pass
-- 2026-07-11). w_ weapon models lie along +X, so the profile camera sits on
-- +Y looking back. Everything else keeps the engine spawnicon framing.
local SIDE_VIEW_CATS = { weapons = true, melee = true }

local function SideProfileView(ent)
    local mn, mx = ent:GetRenderBounds()
    local center = (mn + mx) * 0.5
    local len = math.max(mx.x - mn.x, 1)
    local tall = math.max(mx.z - mn.z, 1)
    local fov = 20
    -- fit the long axis (or a tall silhouette) inside the fov with margin
    local halfSpan = math.max(len, tall * 1.6) * 0.5 * 1.15
    local dist = halfSpan / math.tan(math.rad(fov) * 0.5)
    return {
        origin = center + Vector(0, dist, 0),
        angles = Angle(0, 270, 0),
        fov = fov, znear = 1, zfar = dist + len * 2 + 64,
    }
end

-- auto framing (§4 level 3) — also what the editor's "Auto frame" seeds from
function Icons.AutoView(def, ent)
    if SIDE_VIEW_CATS[def.category] then return SideProfileView(ent) end
    -- engine spawnicon framing (verified signature — entity in, view out)
    local view = PositionSpawnIcon(ent, vector_origin, false)
    view.znear = view.znear or 1
    view.zfar = view.zfar or 4096
    return view
end

function Icons.ResolveCam(def, ent)
    local ovr = istable(def.icon_override) and def.icon_override.cam or nil
    local cam = ovr or (istable(def.icon_cam) and def.icon_cam or nil)
    if istable(cam) then return ViewFromCamTable(cam, ent) end
    return Icons.AutoView(def, ent)
end

-- ------------------------------------------------------------------
-- Render pipeline (§3): ClientsideModel -> reusable 512 RT -> PNG in
-- data/corpus/cargo/icons/ -> Material("data/...", "smooth").
--
-- TRANSPARENCY GATE (§9): Plan A captures real alpha (transparent RT +
-- depth-to-dest-alpha two-pass, playermodel-selector recipe). Plan B bakes
-- the slot color as an opaque background. One-line switch: convar
-- cargo_icon_bake_bg (0 = A, 1 = B). The author decides after the in-game
-- gate; flipping the convar regenerates the whole cache.
-- ------------------------------------------------------------------

local matCache = {}   -- defid -> { key = filename, mat = IMaterial | false | nil }
                      -- mat false = resolved to letter (error signal)
                      -- mat nil   = queued, waiting for its render
local queue, queued = {}, {}
local qHead, qTail = 1, 0

local workRT -- lazy: only allocated if something actually renders

local function Enqueue(defid, key)
    -- pending marker (letter meanwhile); refreshed even if already queued
    -- so Get() stops probing the disk for a key that changed mid-queue
    matCache[defid] = { key = key, mat = nil }
    if queued[defid] then return end
    queued[defid] = true
    qTail = qTail + 1
    queue[qTail] = defid
end

local function RenderIconToFile(def)
    local model = Icons.ModelFor(def)
    if not isstring(model) or not util.IsValidModel(model) then return false end

    local key = Icons.IconCacheKey(def)
    local fp = Icons.GetFootprint(def)
    -- render at the footprint's aspect, 64 px per cell (§6); caps keep both
    -- dimensions <= 384, inside the 512 work RT
    local w = math.min(fp.w * CELL_PX, RT_SIZE)
    local h = math.min(fp.h * CELL_PX, RT_SIZE)

    local ent = ClientsideModel(model, RENDERGROUP_OTHER)
    if not IsValid(ent) then return false end
    ent:SetNoDraw(true)

    local view = Icons.ResolveCam(def, ent)
    local bake = cvBakeBg:GetBool()
    local bg = CARGO.Theme.Colors.cell

    workRT = workRT or GetRenderTarget("corpus_cargo_icons_rt", RT_SIZE, RT_SIZE)

    -- Single normal pass with render.Model + SetModelLighting — the sandbox
    -- duplicator-icon recipe, the one PROVEN inside PostRender (first in-game
    -- gate 2026-07-11: the two-pass DrawModel trick from panel-context addons
    -- drew nothing here — background captured, model absent). Plan A alpha
    -- comes from depth-to-dest-alpha during the pass: opaque pixels write
    -- depth, depth writes the destination alpha, the silhouette is the mask.
    render.PushRenderTarget(workRT)
        render.SuppressEngineLighting(true)
        -- neutral boxed lighting (duplicator recipe, toned down)
        render.SetModelLighting(0, 1.1, 1.1, 1.1) -- front
        render.SetModelLighting(1, 0.4, 0.4, 0.4)
        render.SetModelLighting(2, 0.6, 0.6, 0.6)
        render.SetModelLighting(3, 0.6, 0.6, 0.6)
        render.SetModelLighting(4, 1.3, 1.3, 1.3) -- top
        render.SetModelLighting(5, 0.15, 0.15, 0.15)

        -- THE Plan A/B switch: transparent clear vs baked slot color (§9)
        if bake then
            render.Clear(bg.r, bg.g, bg.b, 255, true, true)
        else
            render.Clear(0, 0, 0, 0, true, true)
        end

        render.OverrideAlphaWriteEnable(true, true)
        render.SetWriteDepthToDestAlpha(not bake) -- Plan A: silhouette -> alpha
        render.SetColorModulation(1, 1, 1)
        render.SetBlend(1)

        cam.Start3D(view.origin, view.angles, view.fov, 0, 0, w, h, view.znear, view.zfar)
            render.Model({
                model = model,
                pos = ent:GetPos(),
                angle = ent:GetAngles(),
            }, ent)
        cam.End3D()

        render.SetWriteDepthToDestAlpha(false)
        render.OverrideAlphaWriteEnable(false)
        render.SuppressEngineLighting(false)

        local png = render.Capture({
            format = "png", x = 0, y = 0, w = w, h = h, alpha = not bake,
        })
    render.PopRenderTarget()

    ent:Remove() -- clean the ClientsideModel after capturing (§3)

    if not isstring(png) or png == "" then return false end
    file.CreateDir(DIR)
    file.Write(DIR .. "/" .. key, png)

    local mat = Material("data/" .. DIR .. "/" .. key, "smooth")
    if mat:IsError() then return false end
    matCache[def.id] = { key = key, mat = mat }
    return true
end

-- Lazy generation with a per-frame budget (§3): never render a whole
-- inventory in the frame it opens. Consumers get nil (letter placeholder)
-- while queued and the cell hot-swaps when the render lands, because every
-- Paint re-asks Get() each frame.
hook.Add("PostRender", "corpus_cargo_icon_queue", function()
    if qHead > qTail then return end
    local budget = math.max(1, cvBudget:GetInt())
    for _ = 1, budget do
        if qHead > qTail then break end
        local defid = queue[qHead]
        queue[qHead] = nil
        qHead = qHead + 1
        queued[defid] = nil

        local def = CARGO.Items.Get(defid)
        if istable(def) and Icons.ResolveIconSource(def) == "render" then
            local ok, ret = pcall(RenderIconToFile, def)
            if not ok or ret == false then
                -- letter stays as the error signal; keep the key so Get()
                -- does not re-queue in a loop
                matCache[defid] = { key = Icons.IconCacheKey(def), mat = false }
                if not ok then
                    Corpus.Log("cargo", "icons: render falló para '" .. defid .. "': " .. tostring(ret))
                end
            end
        end
    end
end)

-- ------------------------------------------------------------------
-- Public surface (§10): every item-drawing consumer (grid, equipment
-- slots, quick slots, tooltip zoom) asks here and receives an IMaterial —
-- or nil, meaning "paint the letter" (queued placeholder or error signal).
-- ------------------------------------------------------------------

function Icons.Get(defid)
    local def = CARGO.Items.Get(defid)
    if not istable(def) then return nil end

    local source = Icons.ResolveIconSource(def)
    if source == "letter" then return nil end

    -- hand-made art always wins (§2.1); IMaterial (ARC9 atts) passes by ref
    if source == "icon" then
        if not isstring(def.icon) then return def.icon end
        local hit = matCache[defid]
        if hit and hit.key == def.icon and hit.mat ~= nil then
            return hit.mat or nil
        end
        local mat = Material(def.icon)
        matCache[defid] = { key = def.icon, mat = not mat:IsError() and mat or false }
        return matCache[defid].mat or nil
    end

    -- generated render: filename = invalidation key (§7)
    local key = Icons.IconCacheKey(def)
    local hit = matCache[defid]
    if hit and hit.key == key then
        if hit.mat ~= nil then return hit.mat or nil end
        return nil -- queued: letter placeholder until its render lands
    end

    -- next session (or already rendered): straight from disk, no re-render
    local path = DIR .. "/" .. key
    if file.Exists(path, "DATA") then
        local mat = Material("data/" .. path, "smooth")
        matCache[defid] = { key = key, mat = not mat:IsError() and mat or false }
        return matCache[defid].mat or nil
    end

    Enqueue(defid, key)
    return nil
end

-- drop caches for one def (an override arrived over the def snapshot, §10)
function Icons.Invalidate(defid)
    matCache[defid] = nil
    fpCache[defid] = nil
    -- if it sits in the queue it renders with fresh inputs anyway
end

-- Regenerate-everything (§7/§8): wipe the disk cache and every in-memory
-- cache; icons re-queue lazily as cells repaint, so the per-frame budget
-- holds and a big inventory never hitches.
function Icons.RegenAll()
    local files = file.Find(DIR .. "/*.png", "DATA") or {}
    for _, f in ipairs(files) do
        file.Delete(DIR .. "/" .. f)
    end
    matCache, fpCache, queue, queued = {}, {}, {}, {}
    qHead, qTail = 1, 0
    Corpus.Log("cargo", "icons: caché invalidada (" .. #files
        .. " png borrados); re-render lazy con presupuesto " .. cvBudget:GetInt() .. "/frame")
end

-- global style parameters changed -> every icon must re-bake (§7). The
-- A/B background gate is exactly that kind of parameter.
cvars.AddChangeCallback("cargo_icon_bake_bg", function()
    Icons.RegenAll()
end, "corpus_cargo_icons")
