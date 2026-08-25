-- corpus_cargo_item.lua — dropped item entity (SHARED single-file)
-- Spawned by the drop action and by container/sub-slot ejection into the
-- world. Carries a single grid entry (stack or unique instance ref).
-- WALK+USE returns it to the activator's inventory; plain USE carries it
-- like an HL2 prop. The gate lives in the PlayerUse hook of
-- server/corpus_cargo_capture.lua (roadmap #27), which blocks the engine
-- from reaching ENT:Use unless the take is deliberate.
--
-- IT IS A ONE-ENTRY OWNER (CRG-60). The entry is flat data and a savegame
-- brings it back on its own; the instance it names does not. So the blob
-- travels next to it (`CargoInstances`, rendered by the same routine the two
-- files use) and is minted again with a fresh uid when the entry comes back
-- from another session. The world drop is still ephemeral across a MAP CHANGE
-- (CRG-59, §12): surviving a save is not the same as reaching disk.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Cargo Item"
ENT.Author = "Corpus"
ENT.Category = "Corpus"
ENT.Spawnable = false

if SERVER then

    -- Look and blob, both derived FROM the entry. Split out of Initialize on
    -- purpose: a savegame lands the flat fields AFTER the constructor (measured
    -- in game, B3 round 3), so the restore below has to be able to re-run this.
    function ENT:CargoApplyEntry()
        local model = "models/props_junk/cardboard_box004a.mdl"
        local CARGO = Corpus and Corpus.GetModule and Corpus.GetModule("cargo")
        if CARGO and istable(self.CargoEntry) then
            local def = CARGO.Items.Get(self.CargoEntry.id)
            -- shared chain (CARGO.Items.ResolveModel, CHANGELOG #3): def.model
            -- -> SWEP WorldModel -> engine map; cardboard box is last resort.
            -- ModelUsable, not util.IsValidModel alone: a mounted-but-unprecached
            -- prop reads as invalid and silently fell back to the box.
            local resolved = CARGO.Items.ResolveModel(def)
            if CARGO.Items.ModelUsable(resolved) then
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

            -- THE BLOB TRAVELS WITH THE ENTRY (CRG-60). Without this the entry
            -- rides into the savegame naming a uid and nothing else, which is
            -- exactly the ghost the owner files discard on load.
            self.CargoInstances = CARGO.Instances.RenderEntry(self.CargoEntry)
        end

        self:SetModel(model)
    end

    function ENT:CargoBuild()
        self:CargoApplyEntry()
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end

    function ENT:Initialize()
        self:CargoBuild()
    end

    -- The savegame side (CRG-60). The entry comes back as flat data, but the
    -- instance it names died with the map: it is minted again from the blob
    -- that travelled alongside it.
    --
    -- VALUE test, never a timing one (B3's lesson, six rounds): it asks whether
    -- the uid is possible in THIS session, not when the duplicator wrote the
    -- field — an order nobody here controls. That makes it idempotent (once the
    -- uid is live it returns on the first line) and safe to call from anywhere,
    -- which is why the paste hook and the take both go through it instead of
    -- one of them being "the" moment.
    function ENT:CargoRestore()
        local entry = self.CargoEntry
        if not istable(entry) or entry.uid == nil then return end
        local CARGO = Corpus and Corpus.GetModule and Corpus.GetModule("cargo")
        if CARGO == nil or CARGO.Instances.Get(entry.uid) ~= nil then return end

        local revived = CARGO.Instances.Remint({ entry }, self.CargoInstances)
        if revived[1] == nil then
            -- honest degradation (cites COR-5), the same discard both owner
            -- files apply: an entry with a uid and no blob is a ghost, and a
            -- ghost is not handed to a player — the drop goes with it.
            Corpus.Log("cargo", "corpus_cargo_item: drop sin blob tras cargar, descartado")
            self:Remove()
            return
        end

        self.CargoEntry = revived[1]
        self:CargoBuild() -- the def may resolve a model the constructor could not
    end

    function ENT:PostEntityPaste()
        self:CargoRestore()
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        self:CargoRestore()
        if not IsValid(self) then return end -- a ghost drop removes itself
        local CARGO = Corpus and Corpus.GetModule and Corpus.GetModule("cargo")
        if CARGO == nil or not istable(self.CargoEntry) then return end

        local ok, err = CARGO.Inventory.GiveEntry(activator, self.CargoEntry)
        if not ok then
            CARGO.Inventory.Notice(activator, err or "You can't carry that.")
            return
        end
        CARGO.Inventory.Touch(activator)
        CARGO.Inventory.NotifyPickup(activator, self.CargoEntry.id, self.CargoEntry.count or 1)
        -- The world gate stepped aside for us (WALK+USE on an item drop), so
        -- the pickup gesture is armed and this is its success path. A Use that
        -- did NOT come through the gate never armed it and animates nothing.
        if CARGO.PickupAnim then CARGO.PickupAnim.Play(activator) end
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
            or not CARGO.Items.ModelUsable(model) then
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
