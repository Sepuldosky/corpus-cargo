-- corpus_cargo_crate.lua — test/field container entity (SHARED single-file)
-- Cargo_Architecture.md §8. Spawnable from the entities tab (category
-- Corpus) so the transfer panel can be verified in game without waiting
-- for map content. Finite capacity on purpose: it exercises the
-- per-container capacity branch; a base stash would pass capacity = nil.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Cargo Crate"
ENT.Author = "Corpus"
ENT.Category = "Corpus"
ENT.Spawnable = true

if SERVER then

    function ENT:Initialize()
        self:SetModel("models/props_junk/wood_crate001a.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        -- Lazy wiring: entity files load outside the module manifest, so the
        -- module is resolved at use time, never at file scope (detection,
        -- never assumption).
        local CARGO = Corpus and Corpus.GetModule and Corpus.GetModule("cargo")
        if CARGO == nil then return end

        CARGO.Containers.Attach(self, {
            name = "Field Crate",
            capacity = 50,
            -- Session-only as shipped (CRG-59: world state does not reach
            -- disk). No entity of this module declares a persistKey, which
            -- would leave the owner-file path unreachable in game — the dev
            -- convar is that route, and it is empty by default.
            persistKey = CARGO.Containers.DevPersistKey("crate"),
        })
        CARGO.Containers.OpenFor(activator, self)
    end

end
