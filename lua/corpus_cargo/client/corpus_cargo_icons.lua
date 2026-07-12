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
local RECIPE_VERSION = "r5"

-- Read a SWEP field climbing the Base chain via GetStored. weapons.GetStored
-- returns the RAW registered table WITHOUT inherited base fields (verified in
-- garrysmod weapons.lua: only weapons.Get merges the base) — and ARC9 /
-- MirrorVMWM live on `arc9_base`, so a leaf weapon's GetStored table doesn't
-- carry them. We climb `.Base` ourselves (cheaper than weapons.Get, which
-- deep-copies the whole SWEP incl. its attachment tables just to read a flag).
local function SwepField(class, field, depth)
    local s = weapons.GetStored(class)
    if not istable(s) then return nil end
    if s[field] ~= nil then return s[field] end
    local base = s.Base
    if isstring(base) and base ~= class and (depth or 0) < 10 then
        return SwepField(base, field, (depth or 0) + 1)
    end
    return nil
end

local modelForCache = {} -- defid -> resolved model | false (nil sentinel)

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
-- Memoized per defid: the base-chain walk runs at most once per weapon.
function Icons.ModelFor(def)
    if not istable(def) then return nil end
    -- explicit escape hatch, always wins (for when even the viewmodel is off)
    if isstring(def.icon_model) and def.icon_model ~= "" then return def.icon_model end
    if isstring(def.model) and def.model ~= "" then return def.model end

    local defid = def.id
    if defid ~= nil and modelForCache[defid] ~= nil then
        return modelForCache[defid] or nil
    end

    local result
    if isstring(def.weapon_class) and def.weapon_class ~= "" then
        -- MirrorVMWM (climbed from the base) means the WorldModel is a
        -- collision placeholder and the real picture is the viewmodel
        if SwepField(def.weapon_class, "MirrorVMWM") then
            local vm = SwepField(def.weapon_class, "WorldModelMirror")
            if not (isstring(vm) and vm ~= "") then
                vm = SwepField(def.weapon_class, "ViewModel")
            end
            if isstring(vm) and vm ~= "" then result = vm end
        end
    end
    if result == nil then result = CARGO.Items.ResolveModel(def) end

    if defid ~= nil then modelForCache[defid] = result or false end
    return result
end

-- ARC9 re-applies DefaultSkin + DefaultBodygroups on every model rebuild
-- (arc9_base sh_bodygroups.lua DoBodygroups) — a bare ClientsideModel keeps
-- the .mdl defaults instead, so packs that pick their variant through
-- bodygroups render the wrong gun. Fields climbed from the base like the
-- rest of the SWEP appearance data. Public: the drop entity dresses its
-- visual override model with it too.
function Icons.ApplyDefaultAppearance(ent, class)
    if not isstring(class) or class == "" then return end
    local skin = SwepField(class, "DefaultSkin")
    if isnumber(skin) then ent:SetSkin(skin) end
    local bg = SwepField(class, "DefaultBodygroups")
    if isstring(bg) and bg ~= "" then ent:SetBodyGroups(bg) end
end

-- ------------------------------------------------------------------
-- Tight LOCAL bounds for a model. Viewmodels animate around the camera and
-- their render/sequence bounds span the whole swing (±60+ units), not the
-- gun (~30): framing with GetRenderBounds put the camera so far back that
-- every EFT icon came out uniformly tiny (in-game report 2026-07-11).
-- Chain: real mesh (util.GetModelMeshes — heavy, so computed once per model
-- path EVER: persisted to disk; walking a big EFT viewmodel caused a
-- visible hitch) -> static model hull (GetModelBounds — honest for props
-- and attachment models, and unlike the mesh it never fails to read) ->
-- render bounds as the last resort.
-- ------------------------------------------------------------------

local MESH_CACHE = DIR .. "/mesh_bounds.json"
-- model path -> {mnx,mny,mnz,mxx,mxy,mxz} | false (mesh unreadable)
local meshBounds = util.JSONToTable(file.Read(MESH_CACHE, "DATA") or "") or {}

local function SaveMeshCache()
    file.CreateDir(DIR)
    file.Write(MESH_CACHE, util.TableToJSON(meshBounds))
end

-- static hull, cheap and never sequence-inflated
local function StaticBounds(ent)
    if isfunction(ent.GetModelBounds) then
        local mn, mx = ent:GetModelBounds()
        if mn ~= nil and mx ~= nil then return mn, mx end
    end
    return ent:GetRenderBounds()
end

local function TightModelBounds(ent)
    local model = ent.GetModel and ent:GetModel() or nil
    local hit = model and meshBounds[model] or nil
    if istable(hit) then
        return Vector(hit[1], hit[2], hit[3]), Vector(hit[4], hit[5], hit[6])
    end
    if hit == false or model == nil then return StaticBounds(ent) end

    local mn, mx
    local ok, meshes = pcall(util.GetModelMeshes, model)
    if ok and istable(meshes) then
        for _, mesh in ipairs(meshes) do
            for _, vert in ipairs(mesh.triangles or {}) do
                local p = vert.pos
                if p ~= nil then
                    if mn == nil then
                        mn = Vector(p.x, p.y, p.z)
                        mx = Vector(p.x, p.y, p.z)
                    else
                        mn.x = math.min(mn.x, p.x)
                        mn.y = math.min(mn.y, p.y)
                        mn.z = math.min(mn.z, p.z)
                        mx.x = math.max(mx.x, p.x)
                        mx.y = math.max(mx.y, p.y)
                        mx.z = math.max(mx.z, p.z)
                    end
                end
            end
        end
    end
    if mn == nil then
        meshBounds[model] = false
        SaveMeshCache()
        return StaticBounds(ent)
    end
    meshBounds[model] = { mn.x, mn.y, mn.z, mx.x, mx.y, mx.z }
    SaveMeshCache()
    return mn, mx
end

-- ------------------------------------------------------------------
-- Icon meta (persisted next to the PNGs). The ASSEMBLED capture (below)
-- measures a different footprint than the bare viewmodel, and the footprint
-- is part of the cache filename — without persisting it, the next session
-- would recompute the bare one and orphan the assembled PNG. `assembled`
-- marks defs whose icon already shows the full gun, ending the upgrade
-- probes. defid -> { w, h, assembled }.
-- ------------------------------------------------------------------

local META = DIR .. "/icons_meta.json"
-- bump when the measured meaning changes (v2: mesh bounds replaced render
-- bounds; v3: assembled captures re-arm — pre-v3 ones could be partial,
-- taken from a holstered gun; v4: ARC9 preset framing + static-hull
-- fallback) — stale entries would pin bad state forever
local META_VERSION = 4
local iconMeta = util.JSONToTable(file.Read(META, "DATA") or "") or {}
if iconMeta._v ~= META_VERSION then iconMeta = { _v = META_VERSION } end

local function SaveMeta()
    file.CreateDir(DIR)
    file.Write(META, util.TableToJSON(iconMeta))
end

-- The weapon entity in the local player's hands, if it is one of ARC9's
-- MirrorVMWM guns — the only case where the assembled capture applies and
-- the only moment it is possible (ARC9 builds display models per-SWEP).
--
-- DEPLOYED AND SETTLED only: ARC9 fills its attachment state over the first
-- moments of a deploy, and a merely-carried (holstered) gun never builds it
-- — capturing there produced PARTIAL or empty assemblies (in-game report
-- 2026-07-11; ARC9's own HUD select icons suffer the same race and heal on
-- a later regenerate). Two-step: the first sight of the gun ACTIVE arms a
-- settle window; the capture only runs once the window passed with the gun
-- still out. Until then the bare render stands in and the probe retries.
local liveReadyAt = {} -- weapon_class -> CurTime() when the deploy settled

local function LiveArc9Weapon(def)
    if not istable(def) then return nil end
    local class = def.weapon_class
    if not isstring(class) or class == "" then return nil end
    if not SwepField(class, "MirrorVMWM") then return nil end
    local lp = LocalPlayer()
    if not IsValid(lp) then return nil end
    local wep = lp:GetWeapon(class)
    if not IsValid(wep) or not wep.ARC9 then return nil end
    if not isfunction(wep.SetupModel) or not isfunction(wep.DrawCustomModel)
        or not isfunction(wep.KillModel) then return nil end

    if lp:GetActiveWeapon() ~= wep then
        liveReadyAt[class] = nil
        return nil
    end
    local ready = liveReadyAt[class]
    if ready == nil then
        liveReadyAt[class] = CurTime() + 1
        return nil
    end
    if CurTime() < ready then return nil end
    return wep
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
    local mn, mx = TightModelBounds(ent)
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

    -- a previous ASSEMBLED capture persisted its measured footprint — reuse
    -- it so the cache filename stays stable across sessions
    local m = def.id and iconMeta[def.id] or nil
    if istable(m) and isnumber(m.w) and isnumber(m.h) then
        local fp = { w = m.w, h = m.h }
        fpCache[def.id] = fp
        return fp
    end

    local fp = { w = 1, h = 1 }
    local model = Icons.ModelFor(def)
    if isstring(model) and util.IsValidModel(model) then
        local ent = ClientsideModel(model, RENDERGROUP_OTHER)
        if IsValid(ent) then
            ent:SetNoDraw(true)
            Icons.ApplyDefaultAppearance(ent, def.weapon_class)
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
    local mn, mx = TightModelBounds(ent)
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
local liveNext = {} -- defid -> next CurTime() an upgrade probe is allowed

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

-- A bare-viewmodel PNG of a modular ARC9 gun upgrades to the assembled
-- capture the moment the player actually holds the weapon. Probed from
-- Get() (throttled — it runs inside Paint) and queued WITHOUT the Enqueue
-- placeholder, so the cell keeps the provisional icon until the better
-- render lands instead of flashing back to the letter.
local function MaybeQueueUpgrade(def)
    local defid = def.id
    if defid == nil or queued[defid] then return end
    local m = iconMeta[defid]
    if istable(m) and m.assembled then return end
    if CurTime() < (liveNext[defid] or 0) then return end
    liveNext[defid] = CurTime() + 3
    if LiveArc9Weapon(def) == nil then return end
    queued[defid] = true
    qTail = qTail + 1
    queue[qTail] = defid
end

-- Shared RT recipe for both render paths: single normal pass with
-- SetModelLighting — the sandbox duplicator-icon recipe, the one PROVEN
-- inside PostRender (first in-game gate 2026-07-11: the two-pass DrawModel
-- trick from panel-context addons drew nothing here — background captured,
-- model absent). Plan A alpha comes from depth-to-dest-alpha during the
-- pass: opaque pixels write depth, depth writes the destination alpha, the
-- silhouette is the mask.
-- crop (optional {x,y,w,h}) captures a sub-rect of the viewport — the ARC9
-- preset framing renders 16:9 like ARC9 does and cuts the icon out of it
local function CaptureToPng(w, h, view, drawFn, crop)
    local bake = cvBakeBg:GetBool()
    local bg = CARGO.Theme.Colors.cell

    workRT = workRT or GetRenderTarget("corpus_cargo_icons_rt", RT_SIZE, RT_SIZE)

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
            drawFn()
        cam.End3D()

        render.SetWriteDepthToDestAlpha(false)
        render.OverrideAlphaWriteEnable(false)
        render.SuppressEngineLighting(false)

        local png = render.Capture({
            format = "png",
            x = crop and crop.x or 0, y = crop and crop.y or 0,
            w = crop and crop.w or w, h = crop and crop.h or h,
            alpha = not bake,
        })
    render.PopRenderTarget()

    return png
end

local function CommitPng(def, key, png)
    if not isstring(png) or png == "" then return false end
    file.CreateDir(DIR)
    file.Write(DIR .. "/" .. key, png)

    local mat = Material("data/" .. DIR .. "/" .. key, "smooth")
    if mat:IsError() then return false end
    matCache[def.id] = { key = key, mat = mat }
    return true
end

-- ------------------------------------------------------------------
-- ARC9 assembled capture. MirrorVMWM guns are MODULAR: the stock, the
-- handguard, the mag — even on the "bare" gun — are attachment MODELS
-- mounted on the viewmodel, so a lone ClientsideModel render shows a
-- stripped receiver (in-game report 2026-07-11, same failure the HUD-icon
-- mods hit). Rebuilding that assembly from the def would mean
-- reimplementing ARC9's SetupModel; instead we borrow ARC9's own display
-- build on the LIVE weapon — SetupModel(true, 0, true) -> CModel +
-- DrawCustomModel(true, pos, ang), the exact DoPresetCapture recipe
-- (arc9_base cl_presets.lua) — and photograph it with OUR camera, lighting
-- and alpha so it still looks like a Cargo icon, not an ARC9 preset.
-- ------------------------------------------------------------------

-- gun pose straight from ARC9's preset-capture math: CustomizePos/Ang is
-- per-gun data that orients every weapon side-on for its customize view —
-- exactly the profile an icon wants
local function AssembledPose(wep)
    local custpos = wep:GetProcessedValue("CustomizePos", true)
        + (wep.CustomizeSnapshotPos or Vector(0, 0, 0))
    local custang = wep:GetProcessedValue("CustomizeAng", true)
        + (wep.CustomizeSnapshotAng or Angle(0, 0, 0))
    local camang = Angle(0, 0, 0)
    local pos = Vector(0, 0, 1)
        + camang:Right() * custpos[1]
        + camang:Forward() * custpos[2]
        + camang:Up() * custpos[3]
    local ang = Angle(0, 0, 0)
    ang:RotateAroundAxis(camang:Up(), custang[1])
    ang:RotateAroundAxis(camang:Right(), custang[2])
    ang:RotateAroundAxis(camang:Forward(), custang[3])
    return pos, ang
end

-- merged world AABB over the placed parts (skipping ARC9's helper entries).
-- Only the BASE viewmodel needs the mesh walk (its hull lies in animation
-- space); attachment models are static props whose authored hull is honest
-- and free — keeps the one-per-model hitch down to a single mesh
local function AssembledBounds(parts)
    local mn, mx
    for _, part in ipairs(parts) do
        if IsValid(part) and not part.hidden and not part.IsAnimationProxy then
            local pmn, pmx
            if istable(part.slottbl) and part.slottbl.WMBase then
                pmn, pmx = TightModelBounds(part)
            else
                pmn, pmx = StaticBounds(part)
            end
            for i = 0, 7 do
                local corner = part:LocalToWorld(Vector(
                    bit.band(i, 1) == 0 and pmn.x or pmx.x,
                    bit.band(i, 2) == 0 and pmn.y or pmx.y,
                    bit.band(i, 4) == 0 and pmn.z or pmx.z))
                if mn == nil then
                    mn = Vector(corner.x, corner.y, corner.z)
                    mx = Vector(corner.x, corner.y, corner.z)
                else
                    mn.x = math.min(mn.x, corner.x)
                    mn.y = math.min(mn.y, corner.y)
                    mn.z = math.min(mn.z, corner.z)
                    mx.x = math.max(mx.x, corner.x)
                    mx.y = math.max(mx.y, corner.y)
                    mx.z = math.max(mx.z, corner.z)
                end
            end
        end
    end
    return mn, mx
end

-- the CModel is built and torn down here; the render body runs under pcall
-- so ARC9.PresetCam and the clientside models never leak on an error
local function DrawAssembled(def, wep, pos, ang)
    -- settle pass: DrawCustomModel positions every part as a side effect of
    -- drawing — camera and viewport are irrelevant, only the transforms are
    workRT = workRT or GetRenderTarget("corpus_cargo_icons_rt", RT_SIZE, RT_SIZE)
    render.PushRenderTarget(workRT)
        cam.Start3D(Vector(0, 0, -200), Angle(0, 0, 0), 45, 0, 0, 8, 8, 1, 4096)
            wep:DrawCustomModel(true, pos, ang)
        cam.End3D()
    render.PopRenderTarget()

    local mn, mx = AssembledBounds(wep.CModel or {})
    if mn == nil then return false end

    -- footprint from the ASSEMBLED silhouette (the bare one under-measured —
    -- that 1x2 9A-91) — persisted so next session's cache key matches
    local spanX, spanY, spanZ = mx.x - mn.x, mx.y - mn.y, mx.z - mn.z
    local autoFp = Icons.QuantizeFootprint(spanY, spanZ, def.category)
    fpCache[def.id] = autoFp

    local fp = Icons.GetFootprint(def)
    local key = Icons.IconCacheKey(def)
    local draw = function() wep:DrawCustomModel(true, pos, ang) end

    -- Camera: a data/code cam override still wins (§4). Otherwise use ARC9's
    -- OWN preset framing (author request, 7.ª pasada 2026-07-11: "el menú de
    -- ARC9 se ve justo como debería"): the gun is already posed by the
    -- per-gun CustomizePos/Ang data, and CustomizeSnapshotFOV is the camera
    -- the pack author tuned to match — same origin/angles/16:9 viewport as
    -- DoPresetCapture, no bounds measurement to get wrong. We capture the
    -- center square like ARC9 and cut it down to the footprint aspect.
    local png
    local ovrcam = (istable(def.icon_override) and def.icon_override.cam)
        or (istable(def.icon_cam) and def.icon_cam) or nil
    if istable(ovrcam) then
        local view = ViewFromCamTable(ovrcam, wep.CModel[1])
        view.zfar = view.zfar + spanX + spanY + spanZ -- parts extend past the base
        local w = math.min(fp.w * CELL_PX, RT_SIZE)
        local h = math.min(fp.h * CELL_PX, RT_SIZE)
        png = CaptureToPng(w, h, view, draw)
    else
        local fov = tonumber(wep.GetProcessedValue
            and wep:GetProcessedValue("CustomizeSnapshotFOV")) or 90
        local vpW = RT_SIZE
        local vpH = math.floor(RT_SIZE * 9 / 16) -- 16:9, like ARC9's snapshot
        local side = vpH                          -- ARC9 keeps the center square
        local cw, ch
        if fp.w >= fp.h then
            cw = side
            ch = math.max(1, math.floor(side * fp.h / fp.w))
        else
            ch = side
            cw = math.max(1, math.floor(side * fp.w / fp.h))
        end
        local crop = {
            x = math.floor((vpW - cw) / 2),
            y = math.floor((vpH - ch) / 2),
            w = cw, h = ch,
        }
        local view = {
            origin = Vector(0, 0, 0), angles = Angle(0, 0, 0),
            fov = fov, znear = 1, zfar = 1024, -- DoPresetCapture's planes
        }
        png = CaptureToPng(vpW, vpH, view, draw, crop)
    end
    if not CommitPng(def, key, png) then return false end

    -- only now is the def marked assembled: a failed capture keeps probing
    iconMeta[def.id] = { w = autoFp.w, h = autoFp.h, assembled = true }
    SaveMeta()
    return true
end

local function RenderAssembledToFile(def, wep)
    if not istable(ARC9) then return false end
    local pos, ang = AssembledPose(wep)

    -- PresetCam mode: ARC9 skips its scope-RT paths and draws translucent
    -- parts (sight glass) in the normal pass (cl_drawmodel.lua). Restored
    -- even on error; same for the CModel teardown.
    local prevPresetCam = ARC9.PresetCam
    ARC9.PresetCam = true
    wep:SetupModel(true, 0, true) -- base + every attachment, at our disposal

    local ok, done = pcall(DrawAssembled, def, wep, pos, ang)

    wep:KillModel(true) -- CModel only; the in-hands models are untouched
    ARC9.PresetCam = prevPresetCam

    if not ok then error(done, 0) end
    return done
end

local function RenderIconToFile(def)
    -- assembled capture first: only possible with the gun in hand, and only
    -- needed for the modular MirrorVMWM guns
    local wep = LiveArc9Weapon(def)
    if wep ~= nil then
        local ok, done = pcall(RenderAssembledToFile, def, wep)
        if ok and done == true then return true end
        if not ok then
            Corpus.Log("cargo", "icons: captura ensamblada falló para '"
                .. tostring(def.id) .. "': " .. tostring(done))
        end
        -- fall through: the bare viewmodel is still better than a letter
    end

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
    Icons.ApplyDefaultAppearance(ent, def.weapon_class)

    local view = Icons.ResolveCam(def, ent)
    local png = CaptureToPng(w, h, view, function()
        render.Model({
            model = model,
            pos = ent:GetPos(),
            angle = ent:GetAngles(),
        }, ent)
    end)

    ent:Remove() -- clean the ClientsideModel after capturing (§3)

    return CommitPng(def, key, png)
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
        if hit.mat ~= nil then
            MaybeQueueUpgrade(def)
            return hit.mat or nil
        end
        return nil -- queued: letter placeholder until its render lands
    end

    -- next session (or already rendered): straight from disk, no re-render
    local path = DIR .. "/" .. key
    if file.Exists(path, "DATA") then
        local mat = Material("data/" .. path, "smooth")
        matCache[defid] = { key = key, mat = not mat:IsError() and mat or false }
        MaybeQueueUpgrade(def)
        return matCache[defid].mat or nil
    end

    Enqueue(defid, key)
    return nil
end

-- drop caches for one def (an override arrived over the def snapshot, §10)
function Icons.Invalidate(defid)
    matCache[defid] = nil
    fpCache[defid] = nil
    modelForCache[defid] = nil
    liveNext[defid] = nil
    -- the assembled marker falls too: fresh inputs, fresh capture (and the
    -- upgrade probe re-arms if the weapon is not in hand right now)
    if iconMeta[defid] ~= nil then
        iconMeta[defid] = nil
        SaveMeta()
    end
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
    matCache, fpCache, queue, queued, liveNext = {}, {}, {}, {}, {}
    for k in pairs(modelForCache) do modelForCache[k] = nil end
    for k in pairs(iconMeta) do iconMeta[k] = nil end
    iconMeta._v = META_VERSION
    SaveMeta()
    qHead, qTail = 1, 0
    Corpus.Log("cargo", "icons: caché invalidada (" .. #files
        .. " png borrados); re-render lazy con presupuesto " .. cvBudget:GetInt() .. "/frame")
end

-- global style parameters changed -> every icon must re-bake (§7). The
-- A/B background gate is exactly that kind of parameter.
cvars.AddChangeCallback("cargo_icon_bake_bg", function()
    Icons.RegenAll()
end, "corpus_cargo_icons")
