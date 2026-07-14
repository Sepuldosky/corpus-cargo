-- corpus_cargo_trader.lua — example NPC trader (SHARED single-file)
-- Cargo_Trade_Arquitectura.md §10. Spawnable from the entities tab (category
-- Corpus) so the whole trade subsystem can be verified in game without waiting
-- for Cortex to bring real traders: it validates the price/spread/basket AND
-- the inventory-on-entity primitive underneath (which is the container one).
--
-- Deliberately NOT an NPC (Type = "anim", no AI): the trade block owes nothing
-- to behaviour. When Cortex brings a real trader with a brain, it calls the
-- same Trade.AttachTrader on its own entity — that is the whole contract.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Cargo Trader (demo)"
ENT.Author = "Corpus"
ENT.Category = "Corpus"
ENT.Spawnable = true

if SERVER then

    -- Demo stock (§10): a bit of everything the dev kit prices, so the tabs,
    -- the condition curve and the weight guard all get exercised in one visit.
    local DEMO_STOCK = {
        { id = "cargo_dev_pistol",   count = 1 },
        { id = "cargo_dev_smg",      count = 1 },
        { id = "cargo_dev_helmet",   count = 1 },
        { id = "cargo_dev_vest",     count = 1 },
        { id = "cargo_dev_plate",    count = 2 },
        { id = "cargo_dev_backpack", count = 1 },
        { id = "cargo_dev_medkit",   count = 4 },
        { id = "cargo_dev_food",     count = 6 },
        { id = "cargo_dev_ammo_9mm", count = 120 },
    }

    function ENT:Initialize()
        self:SetModel("models/humans/group01/male_07.mdl")
        self:PhysicsInit(SOLID_BBOX)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_BBOX)
        self:SetUseType(SIMPLE_USE)
        self:DrawShadow(true)

        -- a bare "anim" entity plays no animation on its own: without this it
        -- stands in the T-pose (bind pose), which reads as a broken model
        local seq = self:LookupSequence("idle_subtle")
        if seq and seq > 0 then
            self:ResetSequence(seq)
            self:SetPlaybackRate(1)
        end
    end

    -- keeps the idle looping (ResetSequence alone plays it once)
    function ENT:Think()
        if self:GetCycle() >= 0.99 then self:SetCycle(0) end
        self:NextThink(CurTime() + 0.5)
        return true
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        -- Lazy wiring (same rule as the crate): entity files load outside the
        -- module manifest, so the module is resolved at use time.
        local CARGO = Corpus and Corpus.GetModule and Corpus.GetModule("cargo")
        if CARGO == nil or CARGO.Trade == nil then return end

        CARGO.Trade.AttachTrader(self, {
            name = "Sidorovich (demo)",
            buy_mult = 0.5,   -- pays half of value
            sell_mult = 1.0,  -- charges full value
            money = 50000,    -- a finite wallet: he CAN be drained (§3 check)
            stock = DEMO_STOCK,
            -- session-only on purpose: a persistent demo trader would carry
            -- the leftovers of every test session into the next map load
        })
        CARGO.Trade.OpenFor(activator, self)
    end

end
