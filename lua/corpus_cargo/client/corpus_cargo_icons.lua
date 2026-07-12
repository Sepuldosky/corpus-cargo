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
--   ARC9 select icon         SWEP:DoIconCapture(true) writes
--     data/<PresetPath><base>_icon.<PresetIconFormat> (cl_hud.lua:763,
--     PresetPath "arc9_presets/", format "arc9.png" — sh_common.lua:105);
--     256x256 RGBA on <=1100px screens, x2 above (cl_presets.lua:227)
--   customize state          wep:GetCustomize() (cl_customize_ui.lua:269)
--   pixel readback           render.CapturePixels + render.ReadPixel
--     inside a pushed RT (gmod wiki; alpha return needs x86-64 — the
--     luminance fallback below covers builds where it comes back nil)

local CARGO = Corpus.GetModule("cargo")

CARGO.Icons = CARGO.Icons or {}
local Icons = CARGO.Icons

local cvBudget = CreateClientConVar("cargo_icon_budget", "2", true, false,
    "Icon renders processed per frame (lazy queue budget)")
local cvBakeBg = CreateClientConVar("cargo_icon_bake_bg", "0", true, false,
    "0 = real alpha capture (Plan A), 1 = bake the slot color into the PNG (Plan B)")

local DIR = "corpus/cargo/icons" -- data/ root; inside the Corpus.Data namespace
local CELL_PX = 128              -- render resolution per grid cell (§6; 64
                                 -- upscaled ugly on big cells/tooltip zoom —
                                 -- in-game report 2026-07-11, 8.ª pasada)
local RT_SIZE = 1024             -- one reusable work RT, cropped on capture
                                 -- (§6; must fit the widest footprint at
                                 -- CELL_PX: 6 cells * 128 = 768)

-- GetRenderTarget caches by NAME for the whole engine session (survives lua
-- refresh): the size goes in the name so an old 512 RT never serves the
-- 1024 recipe after a refresh mid-session
local RT_NAME = "corpus_cargo_icons_rt_" .. RT_SIZE

-- footprint auto-quantization tuning (§5: "se afinan empíricamente")
local UNITS_PER_CELL = 8    -- world units of projected OBB per grid cell
local LEN_WEIGHT     = 0.18 -- score weight per cell of long-side mismatch

-- Bump when the render recipe or the auto framing changes: the version is
-- part of the cache key, so every stale icon orphans and re-renders lazily —
-- no manual regen_all needed after a global style change shipped in code.
local RECIPE_VERSION = "r6"

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

-- ------------------------------------------------------------------
-- ARC9 source icon. MirrorVMWM guns are MODULAR: stock, handguard, mag —
-- even on the "bare" gun — are attachment MODELS mounted by ARC9, so a lone
-- ClientsideModel render shows a stripped receiver. Re-photographing the
-- assembly ourselves (SetupModel + DrawCustomModel, recipes r3-r5) kept
-- RACING ARC9's part positioning, which settles across FRAMES, not draw
-- calls: captures came out partial or with parts far from the gun (in-game
-- reports 2026-07-11, up to the 8.ª pasada). Pivot (author call, plan C of
-- the handoff): ARC9's own select-icon capture is that same photo taken by
-- the code that owns the state — always assembled, always framed — so the
-- icon SOURCE for these guns is ARC9's PNG on disk, re-cropped in 2D below.
-- Fresh sources come from the customize-menu watcher at the end of file.
-- ------------------------------------------------------------------

-- defid -> { path, stamp, nextPoll } (path nil = no source on disk yet).
-- File stats are polled at most every 3 s — Get() runs inside Paint. The
-- stamp folds into the cache key, so a fresh ARC9 capture RENAMES our PNG:
-- Material() caches by path and would otherwise serve the stale pixels.
local arc9Src = {}

-- MirrorVMWM def (climbed from the base) -> its weapon class, else nil.
-- Memoized per defid like ModelFor: this runs from IconCacheKey, i.e. every
-- Paint frame per cell — the base-chain climb must not repeat there.
local arc9ClassCache = {} -- defid -> class | false

local function Arc9IconClass(def)
    if not istable(def) then return nil end
    local defid = def.id
    if defid ~= nil and arc9ClassCache[defid] ~= nil then
        return arc9ClassCache[defid] or nil
    end
    local class = def.weapon_class
    if not isstring(class) or class == ""
        or not SwepField(class, "MirrorVMWM") then class = nil end
    if defid ~= nil then arc9ClassCache[defid] = class or false end
    return class
end

-- ARC9's own fallback chain (cl_hud.lua DrawWeaponSelection): the shared
-- auto select icon first, then the default preset's thumbnail
local function Arc9SourceInfo(def)
    local defid = def.id
    local class = Arc9IconClass(def)
    if defid == nil or class == nil then return nil end

    local hit = arc9Src[defid]
    if hit ~= nil and CurTime() < hit.nextPoll then
        return hit.path ~= nil and hit or nil
    end

    local dir = istable(ARC9) and ARC9.PresetPath or "arc9_presets/"
    local fmt = istable(ARC9) and ARC9.PresetIconFormat or "arc9.png"
    local base = SwepField(class, "SaveBase")
    base = isstring(base) and base or class

    local path = dir .. base .. "_icon." .. fmt
    if not file.Exists(path, "DATA") then
        path = dir .. base .. "/default." .. fmt
        if not file.Exists(path, "DATA") then path = nil end
    end

    hit = {
        path = path,
        stamp = path ~= nil and (file.Time(path, "DATA") or 0) or 0,
        nextPoll = CurTime() + 3,
    }
    arc9Src[defid] = hit
    return path ~= nil and hit or nil
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
    local mins = CARGO.Items.ICON_CATEGORY_MINS[category]
    local aspect = projW / projH
    local targetLong = math.max(projW, projH) / UNITS_PER_CELL

    local best, bestScore
    for _, fp in ipairs(CARGO.Items.ICON_FOOTPRINTS) do
        if fp[1] <= cap[1] and fp[2] <= cap[2]
            and (mins == nil or (fp[1] >= mins[1] and fp[2] >= mins[2])) then
            -- closest aspect wins; the long-side term separates same-aspect
            -- candidates (3x2 vs 6x2) by projected physical length
            local score = math.abs(math.log((fp[1] / fp[2]) / aspect))
                + LEN_WEIGHT * math.abs(math.max(fp[1], fp[2]) - targetLong)
            if best == nil or score < bestScore - 1e-9
                or (math.abs(score - bestScore) <= 1e-9
                    and fp[1] * fp[2] < best[1] * best[2]) then
                best, bestScore = fp, score
            end
        end
    end
    if best == nil then
        -- min > cap for this category would empty the candidate set; the
        -- floor yields rather than break the closed-set guarantee
        return Icons.QuantizeFootprint(projW, projH, nil)
    end
    return { w = best[1], h = best[2] }
end

-- Category floor over an ALREADY-quantized footprint (persisted metas from
-- captures older than the floor, ICON_CATEGORY_MINS). Grows the short side
-- to the min and re-picks the closest allowed width for the new height so
-- the aspect suffers as little as possible: a 3x1 rifle meta lands on 6x2,
-- a 2x1 pistol meta on 4x2. Explicit def.size / editor overrides never
-- pass through here.
function Icons.ClampFootprintMin(fp, category)
    local mins = CARGO.Items.ICON_CATEGORY_MINS[category]
    if mins == nil or (fp.w >= mins[1] and fp.h >= mins[2]) then return fp end

    local caps = CARGO.Items.ICON_CATEGORY_CAPS
    local cap = caps[category] or caps.default
    local h = math.Clamp(math.max(fp.h, mins[2]), 1, cap[2])
    local targetW = math.Clamp(math.Round((fp.w / fp.h) * h), mins[1], cap[1])

    local bestW
    for _, cand in ipairs(CARGO.Items.ICON_FOOTPRINTS) do
        if cand[2] == h and cand[1] >= mins[1] and cand[1] <= cap[1] then
            if bestW == nil or math.abs(cand[1] - targetW) < math.abs(bestW - targetW)
                or (math.abs(cand[1] - targetW) == math.abs(bestW - targetW)
                    and cand[1] < bestW) then
                bestW = cand[1]
            end
        end
    end
    if bestW == nil then return fp end -- no allowed width at that height
    return { w = bestW, h = h }
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
-- cam + effective footprint [+ ARC9 source stamp])>.png — change any input
-- and the name changes, forcing a re-render (Material() caches by path,
-- never reuse a name).
function Icons.IconCacheKey(def)
    local model = Icons.ModelFor(def) or "none"
    local fp = Icons.GetFootprint(def)
    local input = RECIPE_VERSION .. "|" .. model .. "|" .. CamKeyString(def)
        .. "|" .. fp.w .. "x" .. fp.h
    -- ARC9-sourced icons fold the source capture's mtime in: every fresh
    -- capture from the menu watcher re-keys the file on its own
    local src = Arc9SourceInfo(def)
    if src ~= nil then input = input .. "|arc9:" .. src.stamp end
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
    -- it so the cache filename stays stable across sessions. The category
    -- floor applies over it: metas older than the floor carry flat weapon
    -- footprints (author calibration, first fullscreen pass)
    local m = def.id and iconMeta[def.id] or nil
    if istable(m) and isnumber(m.w) and isnumber(m.h) then
        local fp = Icons.ClampFootprintMin({ w = m.w, h = m.h }, def.category)
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

local matCache = {}   -- defid -> { key = filename, mat = IMaterial | false | nil,
                      --            prev = IMaterial | nil }
                      -- mat false = resolved to letter (error signal)
                      -- mat nil   = queued; prev (last good render, if any)
                      --             stands in so a re-key never letter-flashes
local queue, queued = {}, {}
local qHead, qTail = 1, 0
local liveNext = {} -- defid -> next CurTime() an upgrade probe is allowed

local workRT -- lazy: only allocated if something actually renders

local function EnsureRT()
    workRT = workRT or GetRenderTarget(RT_NAME, RT_SIZE, RT_SIZE)
    return workRT
end

local function Enqueue(defid, key, prev)
    -- pending marker (prev icon or letter meanwhile); refreshed even if
    -- already queued so Get() stops probing the disk for a key that
    -- changed mid-queue
    matCache[defid] = { key = key, mat = nil, prev = prev }
    if queued[defid] then return end
    queued[defid] = true
    qTail = qTail + 1
    queue[qTail] = defid
end

-- A bare-viewmodel PNG of a modular ARC9 gun upgrades the moment ARC9's own
-- select-icon capture exists on disk — or refreshes, when the menu watcher
-- retook it. Probed from Get() (throttled — it runs inside Paint) and
-- queued WITHOUT the Enqueue placeholder, so the cell keeps the current
-- icon until the better render lands instead of flashing back to the letter.
local function MaybeQueueUpgrade(def)
    local defid = def.id
    if defid == nil or queued[defid] then return end
    if CurTime() < (liveNext[defid] or 0) then return end
    liveNext[defid] = CurTime() + 3
    local src = Arc9SourceInfo(def)
    if src == nil then return end
    local m = iconMeta[defid]
    if istable(m) and m.assembled and m.src == src.stamp then return end
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
local function CaptureToPng(w, h, view, drawFn)
    local bake = cvBakeBg:GetBool()
    local bg = CARGO.Theme.Colors.cell

    render.PushRenderTarget(EnsureRT())
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
            format = "png", x = 0, y = 0, w = w, h = h,
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
-- ARC9-sourced icon: 2D re-crop of ARC9's own select-icon PNG (rationale
-- in the "ARC9 source icon" section above). The source is a 256x256 RGBA
-- square with the gun as a horizontal band in the middle — used raw it
-- would draw tiny inside a cell, so the silhouette's pixel bbox is scanned
-- and re-cropped into a footprint-shaped PNG of our own. Pure 2D: no model
-- state to race, works from disk without the gun in hand (boot, regen_all).
-- A cam override (editor/code) is IGNORED here on purpose: the ARC9 photo
-- IS the framing; the size override keeps working via GetFootprint.
-- ------------------------------------------------------------------

-- pixel bbox of the source drawn at (0,0,sw,sh) on the work RT. Alpha is
-- the authoritative mask; when it carries no signal (RGB source, or a
-- ReadPixel build without the alpha return) luminance over the transparent-
-- black clear stands in. Sampled every 2 px — bbox precision, not fidelity.
local function SourceBBox(mat, sw, sh)
    render.PushRenderTarget(EnsureRT())
        render.Clear(0, 0, 0, 0, true, true)
        render.OverrideAlphaWriteEnable(true, true)
        cam.Start2D()
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(0, 0, sw, sh)
        cam.End2D()
        render.OverrideAlphaWriteEnable(false)
        render.CapturePixels()

        local ax0, ay0, ax1, ay1 -- alpha bbox
        local lx0, ly0, lx1, ly1 -- luminance bbox
        local amin, amax = 255, 0
        for y = 0, sh - 1, 2 do
            for x = 0, sw - 1, 2 do
                local r, g, b, a = render.ReadPixel(x, y)
                a = a or 255
                if a < amin then amin = a end
                if a > amax then amax = a end
                if a > 12 then
                    if ax0 == nil or x < ax0 then ax0 = x end
                    if ax1 == nil or x > ax1 then ax1 = x end
                    if ay0 == nil or y < ay0 then ay0 = y end
                    if ay1 == nil or y > ay1 then ay1 = y end
                end
                if r > 12 or g > 12 or b > 12 then
                    if lx0 == nil or x < lx0 then lx0 = x end
                    if lx1 == nil or x > lx1 then lx1 = x end
                    if ly0 == nil or y < ly0 then ly0 = y end
                    if ly1 == nil or y > ly1 then ly1 = y end
                end
            end
        end
    render.PopRenderTarget()

    if amax - amin > 64 then return ax0, ay0, ax1, ay1 end
    return lx0, ly0, lx1, ly1
end

local function RenderFromArc9Icon(def, src)
    local mat = Material("data/" .. src.path, "smooth")
    if mat:IsError() then return false end
    -- the material may be cached from before ARC9 rewrote the file this
    -- session: Download() makes the texture re-read its PNG (defensive —
    -- the re-keyed OUTPUT already guards our side)
    local tex = mat.GetTexture and mat:GetTexture("$basetexture") or nil
    if tex ~= nil then pcall(tex.Download, tex) end

    local sw = math.min(mat:Width(), RT_SIZE)
    local sh = math.min(mat:Height(), RT_SIZE)
    if sw <= 1 or sh <= 1 then return false end

    local bx0, by0, bx1, by1 = SourceBBox(mat, sw, sh)
    if bx0 == nil then return false end -- empty capture: keep the bare render
    -- margin so smooth-filtered edges survive the crop
    bx0, by0 = math.max(0, bx0 - 2), math.max(0, by0 - 2)
    bx1, by1 = math.min(sw, bx1 + 3), math.min(sh, by1 + 3)
    local bw, bh = bx1 - bx0, by1 - by0

    -- footprint from the silhouette. World units per source pixel come from
    -- ARC9's snapshot projection: 16:9 viewport whose center square is the
    -- source (cl_presets.lua), CustomizeSnapshotFOV across its width, gun at
    -- roughly |CustomizePos| from the camera. An approximation — quantize
    -- only needs the right bucket, and caps/override clamp the extremes.
    local class = def.weapon_class
    local fov = tonumber(SwepField(class, "CustomizeSnapshotFOV")) or 90
    local cpos = SwepField(class, "CustomizePos")
    local dist = isvector(cpos) and math.max(cpos:Length(), 8) or 24
    local worldPerPx = 2 * dist * math.tan(math.rad(fov) * 0.5) / (sw * 16 / 9)
    local autoFp = Icons.QuantizeFootprint(bw * worldPerPx, bh * worldPerPx, def.category)
    fpCache[def.id] = autoFp

    local fp = Icons.GetFootprint(def)
    local key = Icons.IconCacheKey(def)

    local w = math.min(fp.w * CELL_PX, RT_SIZE)
    local h = math.min(fp.h * CELL_PX, RT_SIZE)
    -- aspect-fit the cropped silhouette inside the footprint rect (bbox
    -- aspect never matches the quantized cells exactly)
    local scale = math.min(w / bw, h / bh)
    local dw, dh = bw * scale, bh * scale
    local dx, dy = (w - dw) / 2, (h - dh) / 2

    -- 2D sibling of CaptureToPng: same Plan A/B background gate (§9), no
    -- camera or model lighting — the source pixels are already lit
    local bake = cvBakeBg:GetBool()
    local bg = CARGO.Theme.Colors.cell
    render.PushRenderTarget(EnsureRT())
        if bake then
            render.Clear(bg.r, bg.g, bg.b, 255, true, true)
        else
            render.Clear(0, 0, 0, 0, true, true)
        end
        render.OverrideAlphaWriteEnable(true, true)
        cam.Start2D()
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(mat)
            surface.DrawTexturedRectUV(dx, dy, dw, dh,
                bx0 / sw, by0 / sh, bx1 / sw, by1 / sh)
        cam.End2D()
        render.OverrideAlphaWriteEnable(false)
        local png = render.Capture({
            format = "png", x = 0, y = 0, w = w, h = h, alpha = not bake,
        })
    render.PopRenderTarget()

    -- the def's PREVIOUS PNG sits under a key no one will compute again
    -- (stamps only move forward): sweep it
    local m = iconMeta[def.id]
    if istable(m) and isstring(m.key) and m.key ~= key then
        file.Delete(DIR .. "/" .. m.key)
    end
    if not CommitPng(def, key, png) then return false end

    -- only now is the def marked assembled: a failed capture keeps probing
    iconMeta[def.id] = { w = autoFp.w, h = autoFp.h, assembled = true,
        src = src.stamp, key = key }
    SaveMeta()
    return true
end

local function RenderIconToFile(def)
    -- ARC9's own finished capture first: the modular MirrorVMWM guns can
    -- only be photographed assembled by ARC9 itself
    local src = Arc9SourceInfo(def)
    if src ~= nil then
        local ok, done = pcall(RenderFromArc9Icon, def, src)
        if ok and done == true then return true end
        if not ok then
            Corpus.Log("cargo", "icons: re-crop del icono ARC9 falló para '"
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
        -- queued: the last good render stands in (letter only if none)
        return hit.prev
    end

    -- next session (or already rendered): straight from disk, no re-render
    local path = DIR .. "/" .. key
    if file.Exists(path, "DATA") then
        local mat = Material("data/" .. path, "smooth")
        matCache[defid] = { key = key, mat = not mat:IsError() and mat or false }
        MaybeQueueUpgrade(def)
        return matCache[defid].mat or nil
    end

    -- re-key mid-session (fresh ARC9 source stamp): keep showing the old
    -- pixels while the new render is in the queue
    Enqueue(defid, key, hit and (hit.mat or hit.prev) or nil)
    return matCache[defid].prev
end

-- drop caches for one def (an override arrived over the def snapshot, §10)
function Icons.Invalidate(defid)
    matCache[defid] = nil
    fpCache[defid] = nil
    modelForCache[defid] = nil
    liveNext[defid] = nil
    arc9Src[defid] = nil
    arc9ClassCache[defid] = nil
    -- the assembled marker falls too: fresh inputs, fresh capture (and the
    -- upgrade probe re-crops from the ARC9 source on the next Paint)
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
    matCache, fpCache, queue, queued, liveNext, arc9Src = {}, {}, {}, {}, {}, {}
    for k in pairs(modelForCache) do modelForCache[k] = nil end
    for k in pairs(arc9ClassCache) do arc9ClassCache[k] = nil end
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

-- ------------------------------------------------------------------
-- Deliberate SOURCE regeneration (author flow, 8.ª pasada 2026-07-11):
-- ARC9's customize menu is the one moment the weapon is guaranteed
-- assembled, settled AND on screen — after the menu sits open a full
-- second, re-run ARC9's own select-icon capture (DoIconCapture(true)
-- writes <base>_icon.arc9.png synchronously, cl_hud.lua:763). The upgrade
-- probe then spots the fresh stamp and re-crops. So "regenerate an ARC9
-- icon" = open its customize menu, wait a beat, done. Re-arms when ARC9
-- flags the icon stale (attachment change, sh_attach.lua:140).
-- ------------------------------------------------------------------

local MENU_SETTLE = 1 -- s the menu must stay open before the recapture

local cvMenuCap = CreateClientConVar("cargo_icon_arc9_menu_capture", "1", true, false,
    "Refresh the ARC9 select icon (Cargo's icon source) after its customize menu sits open 1 s")

local menuCaptureAt -- CurTime() the armed capture fires; nil = disarmed
local menuCaptured  -- weapon already captured this menu session

hook.Add("Think", "corpus_cargo_icons_arc9_menu", function()
    if not cvMenuCap:GetBool() then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local wep = lp:GetActiveWeapon()
    if not (IsValid(wep) and wep.ARC9 and isfunction(wep.GetCustomize)
        and wep:GetCustomize()) then
        menuCaptureAt, menuCaptured = nil, nil
        return
    end
    -- one capture per menu session — unless ARC9 marked the icon stale
    if menuCaptured == wep and not wep.InvalidateSelectIcon then return end
    if menuCaptureAt == nil then
        menuCaptureAt = CurTime() + MENU_SETTLE
        return
    end
    if CurTime() < menuCaptureAt then return end
    menuCaptureAt = nil
    menuCaptured = wep
    if not isfunction(wep.DoIconCapture) then return end

    local ok, err = pcall(wep.DoIconCapture, wep, true)
    if not ok then
        Corpus.Log("cargo", "icons: DoIconCapture falló para '"
            .. wep:GetClass() .. "': " .. tostring(err))
        return
    end
    -- fresh stamp on disk: poke the def (capture.lua autogen id scheme) so
    -- the probe re-crops on the next Paint instead of in up to 3 s
    local defid = "wpn_" .. wep:GetClass()
    if CARGO.Items.Get(defid) ~= nil then
        arc9Src[defid], liveNext[defid] = nil, nil
    end
    Corpus.Log("cargo", "icons: icono ARC9 recapturado desde el menú para '"
        .. wep:GetClass() .. "'")
end)
