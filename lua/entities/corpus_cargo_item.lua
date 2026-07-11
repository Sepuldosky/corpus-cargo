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

    -- engine (HL2/base gmod) weapons are not scripted SWEPs, so their world
    -- model can't be looked up — small known map so drops look like the gun
    local ENGINE_WMODELS = {
        weapon_pistol     = "models/weapons/w_pistol.mdl",
        weapon_357        = "models/weapons/w_357.mdl",
        weapon_smg1       = "models/weapons/w_smg1.mdl",
        weapon_ar2        = "models/weapons/w_irifle.mdl",
        weapon_shotgun    = "models/weapons/w_shotgun.mdl",
        weapon_crossbow   = "models/weapons/w_crossbow.mdl",
        weapon_frag       = "models/weapons/w_grenade.mdl",
        weapon_rpg        = "models/weapons/w_rocket_launcher.mdl",
        weapon_crowbar    = "models/weapons/w_crowbar.mdl",
        weapon_stunstick  = "models/weapons/w_stunbaton.mdl",
        weapon_physcannon = "models/weapons/w_physics.mdl",
        weapon_physgun    = "models/weapons/w_physics.mdl",
        weapon_slam       = "models/weapons/w_slam.mdl",
        gmod_tool         = "models/weapons/w_toolgun.mdl",
        gmod_camera       = "models/maxofs2d/camera.mdl",
    }

    -- def.model wins; then the scripted SWEP's WorldModel; then the engine
    -- map; the cardboard box is the last resort only
    local function ResolveModel(def)
        if not istable(def) then return nil end
        if isstring(def.model) and def.model ~= "" then return def.model end
        if isstring(def.weapon_class) then
            local stored = weapons.GetStored(def.weapon_class)
            if stored and isstring(stored.WorldModel) and stored.WorldModel ~= "" then
                return stored.WorldModel
            end
            return ENGINE_WMODELS[def.weapon_class]
        end
        return nil
    end

    function ENT:Initialize()
        local model = "models/props_junk/cardboard_box004a.mdl"
        local CARGO = Corpus and Corpus.GetModule and Corpus.GetModule("cargo")
        if CARGO and istable(self.CargoEntry) then
            local def = CARGO.Items.Get(self.CargoEntry.id)
            local resolved = ResolveModel(def)
            if isstring(resolved) and util.IsValidModel(resolved) then
                model = resolved
            end
            if istable(def) then
                self:SetNWString("cargo_label",
                    def.name .. ((self.CargoEntry.count or 1) > 1
                        and (" x" .. self.CargoEntry.count) or ""))
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

    -- floating label so drops are findable without a HUD of their own
    function ENT:Draw()
        self:DrawModel()

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

end
