-- corpus_cargo_cash.lua — dropped cash entity (SHARED single-file)
-- Cargo_Trade_Arquitectura.md §7, slice 2. Spawned by the money button in the
-- Solo state; carries ONE amount and nothing else.
--
-- Why it exists at all: "dropping money" is only expressible if cash EXISTS in
-- the world, and until this slice money was just a number in the provider
-- (§6 of Cargo_Architecture.md). So this is the smallest possible entity — no
-- def, no blob, no instance, no persistence. It is NOT a Cargo item and does
-- not go through Items.Register: an item has a def, a weight and a footprint,
-- and cash has none of the three (weight zero in v1, §7).
--
-- Pickup is the SAME gate as a dropped item: the PlayerUse hook of
-- server/corpus_cargo_capture.lua (roadmap #27). Plain USE carries it like an
-- HL2 prop, WALK+USE takes it. No second gate was written — that hook already
-- decides "deliberate take" for three shapes and this is the fourth.
--
-- EPHEMERAL BY DESIGN. It does not survive a map change and does not reach
-- disk, exactly like the item drop (CRG-59). It carries no blob, so unlike the
-- item there is nothing to remint: a savegame brings back the flat amount and
-- that is the whole entity.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Cash"
ENT.Author = "Corpus"
ENT.Category = "Corpus"
ENT.Spawnable = false

-- CS:Source, and it is MEASURED, not assumed (CRG-24): the model lives at this
-- path in cstrike_pak_dir.vpk with its .phy, .vvd and materials, and GMod
-- mounts CS:S when the player owns it. What GMod ships on its own is only the
-- SPAWNICON of this prop (fallbacks_dir.vpk) — the model is NOT included, so
-- for anyone without CS:S this path is an ERROR model. Hence the gate below.
ENT.CashModel = "models/props/cs_assault/money.mdl"

-- Same last resort the item drop uses, so a player without CS:S gets a prop he
-- can see and pick up instead of the red ERROR sign. Honest degradation, the
-- rule the sound bank and the wheel icons already follow (COR-17: assets are
-- not versioned, so nothing may ASSUME a mount).
ENT.CashFallbackModel = "models/props_junk/cardboard_box004a.mdl"

if SERVER then

    function ENT:Initialize()
        local CARGO = Corpus and Corpus.GetModule and Corpus.GetModule("cargo")
        local model = self.CashFallbackModel
        -- ModelUsable and not util.IsValidModel alone: a mounted-but-unprecached
        -- prop reads as invalid and would silently fall back (the item drop
        -- paid for that one in game).
        if CARGO and CARGO.Items.ModelUsable(self.CashModel) then
            model = self.CashModel
        end
        self:SetModel(model)

        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end

    -- amount + owner, set right after Create by Trade.DropCash. The owner key
    -- is what the quota counts by, and it comes from Inventory.OwnerKey so a
    -- bot (no SteamID64) still owns its bundles.
    function ENT:CargoSetCash(amount, ownerKey)
        local CARGO = Corpus and Corpus.GetModule and Corpus.GetModule("cargo")
        local n = math.max(math.floor(amount or 0), 0)
        self.CargoCashOwner = ownerKey
        self:SetNWInt("cargo_cash", n)
        -- The LABEL is rendered here and not on the client because
        -- `Money.Format` belongs to the active provider and providers are
        -- server-side (§6). A client formatting it on its own would print USD
        -- shape over someone else's economy — the same reason the trade screen
        -- receives `moneyText` already formatted instead of a number.
        self:SetNWString("cargo_cash_text", CARGO and CARGO.Money.Format(n) or tostring(n))
    end

    function ENT:CargoAmount()
        return math.max(self:GetNWInt("cargo_cash", 0), 0)
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        local CARGO = Corpus and Corpus.GetModule and Corpus.GetModule("cargo")
        if CARGO == nil then return end

        local amount = self:CargoAmount()
        if amount <= 0 then self:Remove() return end

        -- Whoever picks it up gets it (§7). There is deliberately no owner
        -- check: cash on the floor is cash on the floor, and that is what makes
        -- leaving money for someone else work at all.
        CARGO.Money.Add(activator, amount)
        CARGO.Inventory.Notice(activator,
            "Picked up " .. CARGO.Money.Format(amount) .. ".")
        CARGO.Inventory.Touch(activator)
        self:Remove()
    end

else

    -- Floating label, same shape as the item drop's — a bundle with no label
    -- is indistinguishable from map furniture, and this one has a number that
    -- decides whether it is worth crossing the room for.
    function ENT:Draw()
        self:DrawModel()

        local amount = self:GetNWInt("cargo_cash", 0)
        if amount <= 0 then return end
        local ply = LocalPlayer()
        if not IsValid(ply) or ply:GetPos():DistToSqr(self:GetPos()) > 200 * 200 then return end

        -- The label comes formatted from the server (see CargoSetCash). Falling
        -- back to the bare number is honest degradation, not decoration: it is
        -- what shows for the frame or two before the NW string arrives.
        local label = self:GetNWString("cargo_cash_text", "")
        if label == "" then label = tostring(amount) end

        local pos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 4)
        local ang = Angle(0, ply:EyeAngles().y - 90, 90)
        cam.Start3D2D(pos, ang, 0.15)
            draw.SimpleTextOutlined(label, "DermaDefaultBold", 0, 0,
                Color(226, 190, 92), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
                1, Color(0, 0, 0, 200))
        cam.End3D2D()
    end

end
