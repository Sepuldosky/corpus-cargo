-- corpus_cargo_init.lua — entry point and load manifest for Cargo (SHARED)
-- Only file in lua/autorun/: registers the module and loads everything else via
-- include() in explicit order. Boot pattern taken from corpus_caliber_init.lua
-- (the ecosystem template): AddCSLuaFile always runs at autorun; the boot itself
-- is deferred to "Initialize" because gmod merges lua/autorun/ alphabetically
-- across addons and "corpus_cargo_init.lua" sorts BEFORE "corpus_registry.lua".

-- ============================================================
-- CARGO PUBLIC CONTRACT (Cargo_Architecture.md §3-§6, §11). Consumed by other
-- modules via Corpus.GetModule("cargo"). Everything else hanging off the table
-- is internal — off-contract by convention, not by technical barrier.
--
--   CARGO.Items.Register(def) -> def          -- item definition (owner module
--                                                keeps the semantics; Cargo keeps
--                                                the container). def is stored
--                                                by reference.
--   CARGO.Items.DeclareSubSlot(def, spec)     -- generic sub-slot primitive
--                                                (optic / exo-shield / plates)
--   CARGO.Items.Get(id) -> def | nil
--   CARGO.Inventory.GiveItem(ply, id, count | blob) -> ok, err|uid
--   CARGO.Inventory.TakeItem(ply, id, count) -> ok
--   CARGO.Inventory.CountItem(ply, id) -> n
--   CARGO.Inventory.GetEquipped(ply, slotId) -> instance blob | nil
--                                             -- (Cortex reads Body for disguise)
--   CARGO.Money.RegisterProvider(name, iface) -- iface: get/add/take/format
--   CARGO.Money.Get/Add/Take/Format           -- delegate to the active provider
--   CARGO.Containers.Attach(ent, opts)        -- turn any entity into a container
--   CARGO.StatusPanel.RegisterBar(module, spec)  -- CLIENT: status panel bars
--   CARGO.Icons.Get(defid) -> IMaterial | nil -- CLIENT: item icon (nil =>
--                                                letter placeholder/error)
--   CARGO.Icons.GetFootprint(defid) -> {w,h}  -- CLIENT: cell footprint
--                                                (Cargo_ItemImages §5)
-- ============================================================

-- ============================================================
-- Load manifest: explicit, deterministic order (never alphabetical autorun).
-- Sub-files live in lua/corpus_cargo/<realm>/ (outside lua/autorun/) so that
-- THIS init is the only load point. Rule: no forward calls in file scope —
-- cross-subsystem calls happen in hooks/net handlers with existence guards.
-- ============================================================
local SHARED = {
    "shared/corpus_cargo_util.lua",     -- net blob helpers, misc pure utils
    "shared/corpus_cargo_items.lua",    -- item contract + sub-slot primitive
    "shared/corpus_cargo_slots.lua",    -- equipment slot table (data, no UI)
    "shared/corpus_cargo_weight.lua",   -- pure weight -> speed curve
    "shared/corpus_cargo_arc9.lua",     -- ARC9 bridge (realm-guarded inside)
    "shared/corpus_cargo_dev.lua",      -- selftest + dev item kit (verification)
}
local SERVER_FILES = {
    "server/corpus_cargo_instances.lua",  -- unique-item instance blobs + persistence
    "server/corpus_cargo_money.lua",      -- money provider interface + native USD
    "server/corpus_cargo_inventory.lua",  -- per-player inventory, equip, net handlers
    "server/corpus_cargo_movement.lua",   -- weight -> walk/run speed application
    "server/corpus_cargo_containers.lua", -- world containers + transfer net
    "server/corpus_cargo_capture.lua",    -- engine weapons -> inventory (start unarmed)
    "server/corpus_cargo_icons.lua",      -- icon cam/footprint override registry (ItemImages §4.3/§10)
}
local CLIENT_FILES = {
    "client/corpus_cargo_theme.lua",       -- palette, fonts, shared paint helpers
    "client/corpus_cargo_icons.lua",       -- item icon pipeline (Cargo_ItemImages §2-§7)
    "client/corpus_cargo_iconeditor.lua",  -- dev icon cam/footprint editor (ItemImages §8)
    "client/corpus_cargo_statuspanel.lua", -- StatusPanel.RegisterBar + render
    "client/corpus_cargo_pickup.lua",      -- on-screen pickup feed (HUDPaint)
    "client/corpus_cargo_tooltip.lua",     -- inspection tooltip (§9)
    "client/corpus_cargo_grid.lua",        -- reusable grid + cell overlays (§7)
    "client/corpus_cargo_ui.lua",          -- main inventory frame + binds
    "client/corpus_cargo_transfer.lua",    -- container transfer panel (§8)
    "client/corpus_cargo_options.lua",     -- Corpus.UI.RegisterTab entry
}

local function inc(rel) include("corpus_cargo/" .. rel) end
local function cs(rel)  AddCSLuaFile("corpus_cargo/" .. rel) end

-- AddCSLuaFile does not depend on Corpus: always done at autorun load so the
-- client receives the files even when the boot below stays deferred.
if SERVER then
    for _, f in ipairs(SHARED)       do cs(f) end
    for _, f in ipairs(CLIENT_FILES) do cs(f) end
end

-- Hard-dep: Cargo depends on Corpus (the ecosystem's only hard dependency,
-- CORPUS_Architecture.md §2/§6). Never assumed loaded — probed. The probe covers
-- every primitive the sub-files use in file scope, not just the registry.
local function CorpusReady()
    return Corpus ~= nil and Corpus.RegisterModule ~= nil and Corpus.Data ~= nil
        and Corpus.Net ~= nil and Corpus.Log ~= nil and Corpus.OnReady ~= nil
        and (SERVER or Corpus.UI ~= nil)
end

-- Namespace: single registered table (Cargo_Architecture.md §1). Every file of
-- the module caches this same reference by side-effect
-- (local CARGO = Corpus.GetModule("cargo")). Relies on the by-ref invariant of
-- the Corpus registry (CORPUS_Architecture.md §3): same table, no copy.
local function Boot()
    Corpus.RegisterModule("cargo", {})

    if SERVER then
        for _, f in ipairs(SHARED)       do inc(f) end
        for _, f in ipairs(SERVER_FILES) do inc(f) end
    else
        for _, f in ipairs(SHARED)       do inc(f) end
        for _, f in ipairs(CLIENT_FILES) do inc(f) end
    end

    Corpus.Log("cargo", "cargado (" .. (SERVER and "server" or "client") .. ")")
end

if CorpusReady() then
    -- lua refresh or late mount: the framework is already there — boot now
    Boot()
else
    -- Normal map load: defer to "Initialize" (runs in both realms after ALL of
    -- autorun and before InitPostEntity), keeping every guarantee: UI tabs land
    -- before PopulateToolMenu, net strings before any client connects, and the
    -- InitPostEntity hooks registered during Boot run before the ready barrier.
    hook.Add("Initialize", "corpus_cargo_boot", function()
        hook.Remove("Initialize", "corpus_cargo_boot")
        if CorpusReady() then
            Boot()
        else
            -- Without the framework the module does not start (loud, not silent).
            -- Corpus.Log is not used here: Corpus does not exist.
            MsgN("[Cargo] Corpus framework no encontrado. Verificar que el addon corpus/ esté instalado y montado.")
        end
    end)
end
