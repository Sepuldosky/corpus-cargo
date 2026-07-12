-- corpus_cargo_item.lua — dropped item entity (SHARED single-file)
-- Spawned by the drop action and by container/sub-slot ejection into the
-- world. Carries a single grid entry (stack or unique instance ref); USE
-- returns it to the activator's inventory.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Cargo Item"
ENT.Author = "Corpus"
ENT.Category = "Corpus"
ENT.Spawnable = false

if SERVER then

    function ENT:Initialize()
        local model = "models/props_junk/cardboard_box004a.mdl"
        local CARGO = Corpus and Corpus.GetModule and Corpus.GetModule("cargo")
        if CARGO and istable(self.CargoEntry) then
            local def = CARGO.Items.Get(self.CargoEntry.id)
            -- shared chain (CARGO.Items.ResolveModel, CHANGELOG #3): def.model
            -- -> SWEP WorldModel -> engine map; cardboard box is last resort
            local resolved = CARGO.Items.ResolveModel(def)
            if isstring(resolved) and util.IsValidModel(resolved) then
                model = resolved
            end
            if istable(def) then
                self:SetNWString("cargo_label",
                    def.name .. ((self.CargoEntry.count or 1) > 1
                        and (" x" .. self.CargoEntry.count) or ""))
                -- the client resolves its own visual override from the def
                -- (icon model vs collision placeholder — see Draw below)
                self:SetNWString("cargo_defid", def.id)
            end
        end

        self:SetModel(model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        local CARGO = Corpus and Corpus.GetModule and Corpus.GetModule("cargo")
        if CARGO == nil or not istable(self.CargoEntry) then return end

        local ok, err = CARGO.Inventory.GiveEntry(activator, self.CargoEntry)
        if not ok then
            CARGO.Inventory.Notice(activator, err or "You can't carry that.")
            return
        end
        CARGO.Inventory.Touch(activator)
        CARGO.Inventory.NotifyPickup(activator, self.CargoEntry.id, self.CargoEntry.count or 1)
        self:Remove()
    end

else

    -- Visual override (in-game report 2026-07-11: a dropped 9A-91 showed the
    -- CSS AK). MirrorVMWM ARC9 guns use their WorldModel as a collision
    -- placeholder and the real gun is the viewmodel — ARC9 itself draws the
    -- mirror OVER the placeholder even on the ground (MirrorVMWMHeldOnly is
    -- false by default). Same trick here: physics keeps the placeholder
    -- (viewmodels have no collision mesh), rendering swaps in the model the
    -- icon pipeline resolved (Icons.ModelFor). Decided once per entity; when
    -- there is nothing to override, Draw stays the stock DrawModel.
    local function VisualModel(self)
        if self.CargoVisualChecked then return self.CargoVisualModel end
        local CARGO = Corpus and Corpus.GetModule and Corpus.GetModule("cargo")
        if CARGO == nil then return nil end
        local defid = self:GetNWString("cargo_defid", "")
        if defid == "" then return nil end
        local def = CARGO.Items.Get(defid)
        if def == nil then return nil end -- def snapshot not here yet: retry

        self.CargoVisualChecked = true
        local model = CARGO.Icons and CARGO.Icons.ModelFor
            and CARGO.Icons.ModelFor(def) or nil
        if not isstring(model) or model == self:GetModel()
            or not util.IsValidModel(model) then
            return nil
        end

        local cs = ClientsideModel(model, RENDERGROUP_OPAQUE)
        if not IsValid(cs) then return nil end
        cs:SetNoDraw(true)
        if isfunction(CARGO.Icons.ApplyDefaultAppearance) then
            CARGO.Icons.ApplyDefaultAppearance(cs, def.weapon_class)
        end
        self.CargoVisualModel = cs
        self:DrawShadow(false) -- the placeholder's shadow would give it away
        return cs
    end

    -- floating label so drops are findable without a HUD of their own
    function ENT:Draw()
        local vis = VisualModel(self)
        if IsValid(vis) then
            -- center the override's render bounds on the physics OBB center:
            -- viewmodels are authored around the camera, their origin is far
            -- from the mesh — drawn raw they would float beside the prop
            local ang = self:GetAngles()
            vis:SetAngles(ang)
            vis:SetPos(vector_origin)
            local mn, mx = vis:GetRenderBounds()
            local centerOffset = vis:LocalToWorld((mn + mx) * 0.5)
            vis:SetPos(self:LocalToWorld(self:OBBCenter()) - centerOffset)
            vis:SetupBones()
            vis:DrawModel()
        else
            self:DrawModel()
        end

        local label = self:GetNWString("cargo_label", "")
        if label == "" then return end
        local ply = LocalPlayer()
        if not IsValid(ply) or ply:GetPos():DistToSqr(self:GetPos()) > 200 * 200 then return end

        local pos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 4)
        local ang = Angle(0, ply:EyeAngles().y - 90, 90)
        cam.Start3D2D(pos, ang, 0.15)
            draw.SimpleTextOutlined(label, "DermaDefaultBold", 0, 0,
                Color(224, 224, 224), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
                1, Color(0, 0, 0, 200))
        cam.End3D2D()
    end

    function ENT:OnRemove()
        if IsValid(self.CargoVisualModel) then self.CargoVisualModel:Remove() end
    end

end
