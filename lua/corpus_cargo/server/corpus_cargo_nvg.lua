-- corpus_cargo_nvg.lua — [VManip] Neosun's Cooler Nightvision compat: the
-- BEHAVIOUR (SERVER). Roadmap #47, second half of shared/corpus_cargo_nvg.lua,
-- which owns the defs. Map + wants: dev/Cargo_NVG_Neosun_Referencia.md.
--
-- WHAT THIS FILE IS. The single listener of the generic equipment signal
-- (CRG-62): Cargo broadcasts that a slot changed, and the meaning of that
-- change for THIS mod — writing its networked var — lives here and nowhere
-- else (CRG-1). Two signals, not one, because the goggles come in by two
-- routes (author's call, route C): the helmet's optic sub-slot, or the Head
-- slot directly.
--
-- WHY IT WRITES THE NW AND NEVER CALLS ArcticNVGs_SetPlayerGoggles. That
-- function DROPS THE PREVIOUS PAIR INTO THE WORLD (sv:14-25) — correct for a
-- mod where a player owns one pair, a DUPLICATOR for a caller that already
-- owns the item: the player would end up with the goggles in the inventory
-- and a copy on the floor. Writing the var is idempotent: no entity, no
-- sound, no side effect. The var is the mod's public surface (TLS reads it,
-- and ARC9 reads its twin `nvg_on` to switch its lights to IR), so writing
-- it from the server is interoperating, not modifying: OFF-LIMITS forbids
-- forking the mod, not talking to it.
--
-- AND IT VALIDATES FIRST. The mod does not: an unknown short name leaves its
-- `id` nil and the call lands on SetNWInt("nvg", nil), an argument error.
-- NVG.OrdinalOf answers nil instead, and nil means 0 here.
--
-- WHAT COMES FOR FREE, AND IS NOT ASSUMED. The mod's HUDPaintBackground
-- (cl:107-113) compares the current ordinal against the previous one and, if
-- it changed, turns its own effect off and tells the server. So taking the
-- goggles off while they are ON should extinguish without a line from us.
-- Verified in game (planilla U), not taken on faith.
--
-- WHAT THIS FILE DOES NOT DO: switch the goggles on. Owning and operating
-- are two different verbs; the wheel toggle is roadmap #46 with its own doc.

local CARGO = Corpus.GetModule("cargo")

-- Detection, never assumption (COR-5). The shared half already logged why it
-- is inactive — with no defs of ours there is nothing to reconcile and no
-- entity of the mod's to intercept.
if not istable(CARGO.NVG) or not CARGO.NVG.Active() then return end

-- ------------------------------------------------------------------
-- Who owns "what you lose when you die": Cargo.
--
-- sh_arctic_nvg_losegoggles ships at 1 and its PlayerSpawn hook does
-- SetNWInt("nvg", 0) without dropping anything (sv:5-9). Cargo has its own
-- rule (cargo_lose_on_death, default 0) and its own respawn reconcile, so
-- the two would be disputing the same var.
--
-- The hook order FAVOURS the reconcile, and that is exactly why it is not
-- the argument: depending on hook order is the bug Quick Loadouts already
-- cost this repo. The convar goes to 0 and there is nothing to discuss.
-- Never in silence, though — one line saying it was moved.
-- ------------------------------------------------------------------
do
    local cvLose = GetConVar("sh_arctic_nvg_losegoggles")
    if cvLose ~= nil and cvLose:GetInt() ~= 0 then
        cvLose:SetInt(0)
        Corpus.Log("cargo", "neosun nvg: sh_arctic_nvg_losegoggles pasado a 0 — "
            .. "Cargo es el dueño de qué se pierde al morir (cargo_lose_on_death)")
    end
end

-- ------------------------------------------------------------------
-- Resolution: which pair is this player wearing, by its STABLE name.
--
-- Deterministic on purpose. rec.equip is a hash and pairs() over it has no
-- order, so a player wearing two pairs would get whichever the hash felt
-- like. Slots.List is walked in its declared order (Head first) and each
-- host's sub-slots in the order the def declares them, so the answer to
-- "which goggles" is the same on every call.
--
-- Generic on purpose too: nothing here says "head". A pair is whatever
-- equipped def carries nvg_shortname, in a slot or in a sub-slot of a slot.
-- That is one loop instead of two special cases, and it is what makes the
-- author's route C (helmet sub-slot OR Head direct) a single code path.
-- ------------------------------------------------------------------

local function ShortNameInSubSlots(blob)
    if not istable(blob) or not istable(blob.subslots) then return nil end
    local hostDef = CARGO.Items.Get(blob.id or "")
    if not istable(hostDef) or not istable(hostDef.subslots) then return nil end
    for _, spec in ipairs(hostDef.subslots) do
        local entries = blob.subslots[spec.id]
        if istable(entries) then
            for _, entry in ipairs(entries) do
                local short = istable(entry) and CARGO.NVG.ShortNameOf(entry.id) or nil
                if short ~= nil then return short end
            end
        end
    end
    return nil
end

function CARGO.NVG.EquippedShortName(ply)
    if not IsValid(ply) then return nil end
    local rec = CARGO.Inventory.GetRecord(ply)
    for _, slot in ipairs(CARGO.Slots.List) do
        local val = rec.equip[slot.id]
        -- a stack slot (throwable) holds an entry table, never an instance,
        -- and no stackable carries a short name — skip it whole
        if isstring(val) then
            local blob = CARGO.Instances.Get(val)
            if istable(blob) then
                local short = CARGO.NVG.ShortNameOf(blob.id)
                if short ~= nil then return short end
                short = ShortNameInSubSlots(blob)
                if short ~= nil then return short end
            end
        end
    end
    return nil
end

-- ------------------------------------------------------------------
-- The commit. Idempotent, and the ONLY place that writes the mod's var.
-- ------------------------------------------------------------------

function CARGO.NVG.Reconcile(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local short = CARGO.NVG.EquippedShortName(ply)
    -- ordinal resolved HERE, against the live index, never read off disk
    -- (CRG-63). An unknown name resolves to nil and nil means "none".
    local ordinal = short ~= nil and CARGO.NVG.OrdinalOf(short) or nil
    ply:SetNWInt("nvg", ordinal or 0)
    return ordinal or 0
end

-- Both doors of route C land on the same recompute: the goggles can arrive
-- through the Head slot or through a helmet's optic sub-slot, and neither
-- signal is enough on its own. slotId nil (a re-give) is the respawn door
-- and needs no special case — the recompute reads the whole record anyway.
hook.Add("Corpus_Cargo_EquipChanged", "corpus_cargo_nvg_equip", function(ply)
    CARGO.NVG.Reconcile(ply)
end)

hook.Add("Corpus_Cargo_SubSlotChanged", "corpus_cargo_nvg_subslot", function(ply)
    CARGO.NVG.Reconcile(ply)
end)

-- ------------------------------------------------------------------
-- The world entities. Today E on a pair reaches the mod's ENT:Use, which
-- writes the var and deletes the entity — the inventory never finds out.
-- Registering each class in the world pickup gate gives them the same
-- semantics as everything else on the floor: WALK+USE takes it to the grid,
-- plain USE carries it like a prop, and too heavy leaves it where it is.
--
-- The drop needs nothing: a Cargo unique falls as corpus_cargo_item with its
-- blob beside it. Spawning the mod's own entity would be an object with two
-- owners.
-- ------------------------------------------------------------------
do
    local n = 0
    for class, itemId in pairs(CARGO.NVG.ByEntity) do
        CARGO.Capture.RegisterWorldPickup(class, { id = itemId })
        n = n + 1
    end
    Corpus.Log("cargo", "neosun nvg: " .. n .. " entidades de mundo enrutadas al inventario")
end
