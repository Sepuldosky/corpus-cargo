-- corpus_cargo_trader.lua — example NPC trader (SHARED single-file)
-- Cargo_Trade_Arquitectura.md §10. Spawnable from the entities tab (category
-- Corpus) so the whole trade subsystem can be verified in game without waiting
-- for Cortex to bring real traders: it validates the price/spread/basket AND
-- the inventory-on-entity primitive underneath (which is the container one).
--
-- Deliberately NOT an NPC (Type = "anim", no AI): the trade block owes nothing
-- to behaviour. When Cortex brings a real trader with a brain, it calls the
-- same Trade.AttachTrader on its own entity — that is the whole contract.
--
-- PERSONA LAYER (2026-07-24): the entity reads Trade.GetDefaultPersona() — a
-- cosmetic profile a CONTENT addon registers from outside (model, plaza idle
-- rotation, voice lines for greet/wait/bye and the trade events). Cargo stays
-- generic: with no persona the trader is a silent citizen on plaza idles.
-- corpus-stalker hangs Sidorovich here without this file naming him anywhere.
-- The trade events arrive as generic entity callbacks (OnTradeOpened /
-- OnTradeDealt / OnTradeClosed) fired by server/corpus_cargo_trade.lua.

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

    -- Sidorovich in the flesh when the content addon is mounted, a citizen when
    -- it is not. The model is a ValveBiped rig with the HL2 male anim includes
    -- (male_shared/gestures/postures — read out of the .mdl), so the idles
    -- below play on either one. DETECTION, never assumption: Cargo is generic
    -- and must not hard-depend on corpus_stalker content (rule of the ecosystem).
    local TRADER_MODEL = "models/rashkinsk/sidor.mdl"
    local FALLBACK_MODEL = "models/humans/group01/male_07.mdl"

    -- Plaza idles of the HL2 citizens (the loitering set of the trainstation
    -- plaza, male_shared includes). Tried by name and kept only if the mounted
    -- model actually has the sequence — LookupSequence misses return -1, so an
    -- exotic model just falls back to idle_subtle and nothing breaks.
    local DEFAULT_IDLES = {
        "plazaidle1", "plazaidle2", "plazaidle3", "plazaidle4",
        "lineidle01", "lineidle02", "lineidle03",
        "idle_subtle", "idle01",
    }

    local DEFAULT_RADIUS = 220 -- greet/bye range (units)
    local DEFAULT_WAIT_S = 60  -- "why are you standing there" interval
    local VOICE_GAP      = 2.5 -- min seconds between ambient lines

    -- Persona resolved lazily on every use: entity files load outside the
    -- module manifest, and a content addon registers on the ready barrier.
    local function ActivePersona()
        local cargo = Corpus and Corpus.GetModule and Corpus.GetModule("cargo")
        if cargo and cargo.Trade and isfunction(cargo.Trade.GetDefaultPersona) then
            return cargo.Trade.GetDefaultPersona()
        end
        return nil
    end

    function ENT:Initialize()
        local persona = ActivePersona() or {}

        local model = isstring(persona.model) and persona.model or TRADER_MODEL
        if not file.Exists(model, "GAME") then model = FALLBACK_MODEL end
        -- a model the map never used is NOT in the precache table (same trap the
        -- item defs pay in Items.Register): precaching also networks it
        util.PrecacheModel(model)
        self:SetModel(model)
        self:PhysicsInit(SOLID_BBOX)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_BBOX)
        self:SetUseType(SIMPLE_USE)
        self:DrawShadow(true)

        -- a bare "anim" entity plays no animation on its own: without this it
        -- stands in the T-pose (bind pose), which reads as a broken model.
        -- Every plaza idle the model actually has goes into the rotation.
        self.CargoIdles = {}
        for _, name in ipairs(istable(persona.idles) and persona.idles or DEFAULT_IDLES) do
            local seq = self:LookupSequence(name)
            if seq and seq > 0 then self.CargoIdles[#self.CargoIdles + 1] = seq end
        end
        if #self.CargoIdles == 0 then
            local seq = self:LookupSequence("idle_subtle")
            if seq and seq > 0 then self.CargoIdles = { seq } end
        end
        if #self.CargoIdles > 0 then
            self:ResetSequence(self.CargoIdles[math.random(#self.CargoIdles)])
            self:SetPlaybackRate(1)
        end
        self.CargoNextIdle = CurTime() + math.Rand(12, 30)

        -- voice bookkeeping, all per map session: who is in range, who already
        -- got the first-meeting line, who already opened the trade once
        self.CargoVoice = {}
        self.CargoGreeted = {}
        self.CargoTradeGreeted = {}
        self.CargoNextSpeak = 0
    end

    -- One mouth: every line goes out on CHAN_VOICE (a new line replaces the
    -- current one on that channel) and ambient lines respect a small gap so
    -- he does not chatter over himself. Trade events pass force = true.
    function ENT:CargoSpeak(key, force)
        local persona = ActivePersona()
        local set = persona and istable(persona.sounds) and persona.sounds[key] or nil
        if not istable(set) or #set == 0 then return false end
        if not force and CurTime() < (self.CargoNextSpeak or 0) then return false end
        self:EmitSound(set[math.random(#set)], 75, 100, 1, CHAN_VOICE)
        self.CargoNextSpeak = CurTime() + VOICE_GAP
        return true
    end

    -- Proximity voice: greet on entering the radius (a first meeting has its
    -- own line), nag on standing around without trading (one line per
    -- wait_interval, never while his screen is open), farewell on leaving.
    -- Leaving needs ~15% more distance than entering (hysteresis): a player
    -- hovering right on the edge must not farm greet/bye pairs.
    function ENT:CargoVoiceThink()
        local persona = ActivePersona()
        if persona == nil or not istable(persona.sounds) then return end

        local radius = isnumber(persona.radius) and persona.radius or DEFAULT_RADIUS
        local waitEvery = isnumber(persona.wait_interval) and persona.wait_interval
            or DEFAULT_WAIT_S
        local r2in, r2out = radius * radius, (radius * 1.15) ^ 2
        local trader = self.CargoTrader
        local myPos = self:GetPos()

        self.CargoVoice = self.CargoVoice or {}
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                local st = self.CargoVoice[ply]
                local d2 = ply:GetPos():DistToSqr(myPos)
                if st == nil then
                    if d2 <= r2in then
                        local sid = ply:SteamID64() or tostring(ply)
                        if not self.CargoGreeted[sid] and self:CargoSpeak("greet_first") then
                            self.CargoGreeted[sid] = true
                        else
                            self:CargoSpeak("greet")
                        end
                        self.CargoVoice[ply] = { waitNext = CurTime() + waitEvery }
                    end
                elseif d2 > r2out then
                    self.CargoVoice[ply] = nil
                    self:CargoSpeak("bye")
                elseif CurTime() >= st.waitNext then
                    if not (trader and trader.viewers and trader.viewers[ply]) then
                        self:CargoSpeak("wait")
                    end
                    st.waitNext = CurTime() + waitEvery
                end
            end
        end
        for ply in pairs(self.CargoVoice) do
            if not IsValid(ply) then self.CargoVoice[ply] = nil end
        end
    end

    function ENT:Think()
        -- keeps the idle looping (ResetSequence alone plays it once); when a
        -- loop ends and the rotation timer is due, swap to another plaza idle
        -- so the trader reads alive instead of frozen on one pose
        if self:GetCycle() >= 0.99 then
            if #(self.CargoIdles or {}) > 1 and CurTime() >= (self.CargoNextIdle or 0) then
                self:ResetSequence(self.CargoIdles[math.random(#self.CargoIdles)])
                self.CargoNextIdle = CurTime() + math.Rand(12, 30)
            else
                self:SetCycle(0)
            end
        end

        self:CargoVoiceThink()
        self:NextThink(CurTime() + 0.5)
        return true
    end

    -- ------------------------------------------------------------------
    -- Trade-event callbacks, fired by server/corpus_cargo_trade.lua on ANY
    -- trader entity that defines them. Generic contract: the method name.
    -- ------------------------------------------------------------------

    function ENT:OnTradeOpened(ply)
        local sid = IsValid(ply) and (ply:SteamID64() or tostring(ply)) or "?"
        self.CargoTradeGreeted = self.CargoTradeGreeted or {}
        if not self.CargoTradeGreeted[sid] and self:CargoSpeak("trade_open_first", true) then
            self.CargoTradeGreeted[sid] = true
        else
            self:CargoSpeak("trade_open", true)
        end
        -- no nagging while his screen is open; the clock restarts on close
        local st = self.CargoVoice and self.CargoVoice[ply]
        if st then st.waitNext = math.huge end
    end

    function ENT:OnTradeDealt(ply)
        self:CargoSpeak("trade_done", true)
    end

    function ENT:OnTradeClosed(ply)
        local persona = ActivePersona()
        local waitEvery = persona and isnumber(persona.wait_interval) and persona.wait_interval
            or DEFAULT_WAIT_S
        local st = self.CargoVoice and self.CargoVoice[ply]
        if st then st.waitNext = CurTime() + waitEvery end
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        -- Lazy wiring (same rule as the crate): entity files load outside the
        -- module manifest, so the module is resolved at use time.
        local CARGO = Corpus and Corpus.GetModule and Corpus.GetModule("cargo")
        if CARGO == nil or CARGO.Trade == nil then return end

        local persona = ActivePersona()
        CARGO.Trade.AttachTrader(self, {
            -- the persona names the trader; the demo stays honest without one
            name = persona and isstring(persona.name) and persona.name or "Trader (demo)",
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
