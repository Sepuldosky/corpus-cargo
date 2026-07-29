-- corpus_cargo_lights.lua — the three core light sources of the wheel's
-- third chip group (CLIENT). Roadmap #46; design: dev/Cargo_TLS_Referencia.md
-- §9 (its NVG premise pre-dates #47 — the fresh facts are below); form:
-- docs/mockups/cargo_wheel_lights_mock_v1_1.html, blocks 01-05.
--
-- WHAT THIS FILE IS. The three registrants of CARGO.Wheel.RegisterLightSource
-- (§17.8): the engine torch, the Neosun NVG and the ARC9 toggleable devices
-- of the weapon in hand. The wheel owns the surface; the knowledge of each
-- third party lives HERE (CRG-1 applied to the column). TLS is the model of
-- interaction only — not a line of its code, not one of its assets (it is
-- written against TFA and its license is silent).
--
-- Every third-party name below was VERIFIED against the live code in
-- dev/other/ (CRG-24), never from memory:
--   ARC9 (Arc9 Base):
--     SWEP:GetSubSlotList()            sh_subatts.lua:44 (slottbl carries
--                                      .Installed/.Address/.ToggleNum)
--     SWEP:GetFinalAttTable(slottbl)   sh_0_stats.lua:77-92 — MERGES
--                                      ToggleStats[ToggleNum] over the att
--                                      table, so the ACTIVE mode's emitter
--                                      fields are exposed as data
--     SWEP:LocateSlotFromAddress(addr) sh_attach.lua:720 (ToggleStat's own)
--     SWEP:ToggleStat(addr, val)       sh_attach.lua:718-735 (wraps, val -1
--                                      goes backwards)
--     SWEP:PostModify()                sh_attach.lua:94 — CLIENT branch calls
--                                      SendWeapon() (:132): replicates alone,
--                                      zero new server logic (CRG-23)
--     ARC9.GetAttTable(shortname)      sh_atts.lua:230 (dot call, one arg) —
--                                      the UNMERGED table: the merge above
--                                      overwrites PrintName with the MODE's
--                                      name, so the device NAME reads here
--     ARC9.DeferFakeToggleAtts         cl_move.lua:58-61/:155 — the radial
--                                      sets it before ToggleStat; the next
--                                      CreateMove carries IMPULSE 41, which
--                                      only plays the mod's toggle sound and
--                                      viewmodel anim (sh_move.lua:55/:349)
--     ToggleStats[n].PrintName         cl_radialmenu.lua:183 (mode name, via
--                                      ARC9:GetPhrase when it answers)
--     atttbl.ToggleOnF / .ToggleStats  common/attachments/default.lua:108-109
--     atttbl.Flashlight / .Laser       default.lua:120/:129; IR flags
--     atttbl.FlashlightIR / .LaserIR   cl_light.lua:52 / cl_laser.lua:27
--   Neosun NVG ([vmanip] neosun's cooler nightvision):
--     concommand arc_vm_nvg            cl_arctic_nvg.lua:59 — client, no
--                                      args, the mod's public toggle
--     ArcticNVGs_Toggle                cl:13-57 — gates on GetNWInt("nvg")~=0,
--                                      plays the VManip anim (cl:24, VManip
--                                      is a hard dep of the MOD, unverifiable
--                                      locally) and waits the delay before
--                                      flipping the state and telling the
--                                      server. The delay is DIRECTIONAL:
--                                      EquipDelay turning ON, UnequipDelay
--                                      turning OFF. CORRECTED 2nd pass: the
--                                      1st read the GPNVG and generalised —
--                                      the 12 `shades*` (aviators) DO declare
--                                      UnequipDelay = 0.25, the tube ones do
--                                      not. Read live per direction, never
--                                      assumed (the code always did; the
--                                      DOCS were the ones that were wrong)
--     ArcticNVGs[ordinal].EquipDelay   sh_arctic_nvg.lua (per variant, 1.325;
--                                      read live, NEVER baked — CRG-63 rules
--                                      the ordinal, the mock rules the t)
--     nvg_on                           written ONLY by the mod's own net
--                                      (sv_arctic_nvg.lua:30-34)
--
-- THE NW `nvg` IS NEVER WRITTEN HERE — since #47 CARGO writes it
-- (server/corpus_cargo_nvg.lua, the single writer). This file only READS it,
-- and the chip toggles `nvg_on` through the mod's own command.
--
-- DECISION, said out loud (first page of the PROMPT): the NVG chip asks the
-- NW, not the equipped item. The NW is what arc_vm_nvg will actually act on
-- (the mod gates on it), and since #47 it IS Cargo's own server-side
-- resolution, replicated — asking the snapshot instead would re-implement
-- EquippedShortName client-side, a second route for the same truth.
--
-- CRG-64 — the transit is painted, never the stale state: the toggle is
-- asynchronous (the mod flips `nvg_on` more than a second after the command)
-- and during that window the chip asserts NEITHER state. The window tracks
-- OUR commit only — a toggle fired through the mod's own key is invisible
-- here and paints as the NW says (nothing to invent, CRG-32). The last
-- unavoidable sliver — the mod's net round-trip after its delay — is a few
-- frames of engine latency, not a painted lie.

local CARGO = Corpus.GetModule("cargo")

-- same name the server registered (client Register only builds the string)
local NET_TORCH = Corpus.Net.Register("cargo", "torch")

-- same literal as server/corpus_cargo_lights.lua, which owns the mirror
local NW_TORCH = "cargo_torch"

-- ------------------------------------------------------------------
-- The three OWN icons (§7 of the PROMPT, §0.ter b of the mock): flashlight,
-- nvg, and ONE generic device symbol shared by every weapon device — the
-- mock rejected atttbl.Icon (cost, accepted: two devices OFF in the same
-- column look identical; order and the hub tell them apart). White on
-- transparent, tinted by SetDrawColor, so the DGL4 tint re-skins them free.
-- They LIVE in this repo (materials/corpus_cargo/wheel/, own art — COR-17
-- only forbids versioning third-party assets) and are still DETECTED, never
-- assumed: without the PNG the chip falls to its letter like the rest of the
-- pipeline (COR-5/COR-17 — honest degradation, never an error).
-- ------------------------------------------------------------------
local function WheelIcon(name)
    local rel = "corpus_cargo/wheel/" .. name .. ".png"
    if not file.Exists("materials/" .. rel, "GAME") then return nil end
    return Material(rel, "smooth mips")
end

-- ------------------------------------------------------------------
-- 1 · Torch — the player's flashlight. Author's call: option (b), the ONE
-- payload-free intent of the group (ply:Flashlight is server-only). Option
-- (a), impulse 100, was MEASURED and discarded: with any toggleable ARC9
-- device in hand sh_move.lua:360-369 HIJACKS the impulse into
-- IMPULSE_TOGGLEATTS — same key, different action depending on what you
-- hold. And the impulse is NEVER intercepted either (§17.4 / TLS's paid
-- lesson): the engine flashlight key stays free and untouched.
--
-- 2nd pass (planilla V ronda 2): ply:Flashlight is server-only in BOTH
-- directions. The 1st pass measured the WRITE and assumed the READ, so this
-- chip never painted ON — the state comes from the server's mirror now
-- (server/corpus_cargo_lights.lua, which covers every writer, not just our
-- toggle). The measurement, beam visibly on a wall and no ARC9 in hand:
-- server FlashlightIsOn() true, client FlashlightIsOn() FALSE.
-- No transit is painted here (unlike the NVG): the round trip is a few
-- frames of engine latency, which this file already calls not-a-lie.
-- ------------------------------------------------------------------
CARGO.Wheel.RegisterLightSource("torch", {
    label = "Flashlight",
    icon = WheelIcon("flashlight"),
    -- the engine torch always exists as a source (no mod to detect)
    available = function() return true end,
    state = function(ply)
        -- NOT ply:FlashlightIsOn(): unreadable client-side (measured above)
        return { on = IsValid(ply) and ply:GetNW2Bool(NW_TORCH, false) or false }
    end,
    toggle = function()
        net.Start(NET_TORCH)
        net.SendToServer()
    end,
})

-- ------------------------------------------------------------------
-- 2 · NVG — asynchronous, so the transit is tracked and painted (CRG-64).
-- ------------------------------------------------------------------
local nvgTransit -- { start, duration, label } while OUR toggle is in flight

local function NvgTransitLive()
    return nvgTransit ~= nil
        and CurTime() < nvgTransit.start + nvgTransit.duration
end

CARGO.Wheel.RegisterLightSource("nvg", {
    label = "Night Vision",
    icon = WheelIcon("nvg"),
    available = function(ply)
        -- the NW, not the item — decision argued in the header
        return IsValid(ply) and ply:GetNWInt("nvg", 0) ~= 0
    end,
    state = function(ply)
        if nvgTransit ~= nil and not NvgTransitLive() then
            nvgTransit = nil -- window over: back to the mod's own truth
        end
        if nvgTransit ~= nil then
            return { transit = nvgTransit }
        end
        return { on = IsValid(ply) and ply:GetNWBool("nvg_on", false) or false }
    end,
    toggle = function(ply)
        -- mute rejection while a transit is in flight (block 07 deferred):
        -- re-entering ArcticNVGs_Toggle mid-window would queue a second
        -- timer inside the mod and double-flip it
        if NvgTransitLive() then return end
        if not IsValid(ply) then return end
        local ordinal = ply:GetNWInt("nvg", 0)
        if ordinal == 0 then return end

        -- #47 already knows which variant is worn: the ordinal IS that
        -- resolution, replicated. Reused, not re-derived. The delay is the
        -- MOD's number, read live per variant — nothing baked (the aviators
        -- differ from the tubes) and per DIRECTION: the 12 `shades*` declare
        -- UnequipDelay = 0.25 and the tube variants declare none, so OFF has
        -- a window on some and not on others. Reading it live is what makes
        -- that free — measured in game, planilla V ronda 3 (V7).
        local wasOn = ply:GetNWBool("nvg_on", false)
        local variant = istable(ArcticNVGs) and ArcticNVGs[ordinal] or nil
        local delay = 0
        if istable(variant) then
            -- one leg per direction ON PURPOSE: `wasOn and Unequip or Equip`
            -- would fall through a nil UnequipDelay into EquipDelay and paint
            -- a transit that does not exist when switching OFF
            if wasOn then
                delay = tonumber(variant.UnequipDelay) or 0
            else
                delay = tonumber(variant.EquipDelay) or 0
            end
        end

        RunConsoleCommand("arc_vm_nvg") -- the mod's public surface, client pure

        if delay > 0 then
            nvgTransit = {
                start = CurTime(),
                duration = delay,
                label = wasOn and "ON → OFF" or "OFF → ON",
            }
        end
    end,
})

-- ------------------------------------------------------------------
-- 3 · ARC9 devices — one chip per toggleable slot of the weapon in hand
-- (the case ARC9's own radial refuses: it demands >= 2). The commit is
-- literally the radial's own line and a half (cl_move.lua:153-163), client
-- side, replicating alone — the same contract CRG-23 already declared for
-- attach/detach. Cargo persists NOTHING here: the state's owner is the
-- weapon's slot (slottbl.ToggleNum) and ARC9 already resolves it — the
-- lesson TLS teaches by doing it wrong (per-player state that follows you
-- across weapons).
-- ------------------------------------------------------------------
local DEVICE_ICON = WheelIcon("device")

-- Active emitters of the MERGED att table -> bar color keys, mock lexicon
-- (block 02): visible light = accent, visible laser = green, IR illuminator
-- = orange, IR laser = red. Data, never a parse of the mode string.
local function EmittersOf(atttbl)
    local out = {}
    if atttbl.Flashlight then
        out[#out + 1] = atttbl.FlashlightIR and "orange" or "accent"
    end
    if atttbl.Laser then
        out[#out + 1] = atttbl.LaserIR and "red" or "green"
    end
    return out
end

-- Does this attachment expose emitters as data AT ALL? If no mode of it
-- declares Flashlight/Laser, the bars are NOT fabricated by parsing the
-- mode string — the mock itself calls that fragile, and inferring a third
-- party's state from its display string is what CRG-24 and CRG-63 forbid in
-- spirit. Such a device paints without bars and the mode lives in the hub.
local function HasEmitterData(base)
    if base.Flashlight ~= nil or base.Laser ~= nil then return true end
    if istable(base.ToggleStats) then
        for _, mode in ipairs(base.ToggleStats) do
            if istable(mode) and (mode.Flashlight ~= nil or mode.Laser ~= nil) then
                return true
            end
        end
    end
    return false
end

local function ModeNameOf(merged, slottbl)
    if not istable(merged.ToggleStats) then return nil end
    local mode = merged.ToggleStats[slottbl.ToggleNum or 1]
    if not istable(mode) or not isstring(mode.PrintName) then return nil end
    -- the radial's own display route: GetPhrase when it answers, raw if not
    if istable(ARC9) and isfunction(ARC9.GetPhrase) then
        local ok, phrase = pcall(ARC9.GetPhrase, ARC9, mode.PrintName)
        if ok and isstring(phrase) and phrase ~= "" then return phrase end
    end
    return mode.PrintName
end

local function DeviceChip(wep, addr, label, hasEmitters)
    return {
        label = label,
        icon = DEVICE_ICON,
        state = function()
            if not IsValid(wep) then return {} end
            local ok, slottbl = pcall(wep.LocateSlotFromAddress, wep, addr)
            if not ok or not istable(slottbl) or not slottbl.Installed then return {} end
            local okA, merged = pcall(wep.GetFinalAttTable, wep, slottbl)
            if not okA or not istable(merged) then return {} end

            local s = { mode = ModeNameOf(merged, slottbl) }
            if hasEmitters then
                local em = EmittersOf(merged)
                s.on = #em > 0
                if #em > 0 then s.emitters = em end
            end
            -- no emitter data: no bars, no ON assertion — the hub carries
            -- the mode name and nothing is invented (CRG-32)
            return s
        end,
        toggle = function()
            if not IsValid(wep) then return end
            -- the radial's exact commit (cl_move.lua:155-157), including the
            -- deferred fake impulse that makes the mod play its own click
            if istable(ARC9) then ARC9.DeferFakeToggleAtts = true end
            wep:ToggleStat(addr)
            wep:PostModify()
        end,
    }
end

CARGO.Wheel.RegisterLightSource("arc9_devices", {
    label = "Weapon Device",
    icon = DEVICE_ICON,
    available = function(_, wep)
        -- no ARC9 in hand -> the chips do not exist (CRG-32); the probe is
        -- capability, not a flag, same as the bridge's IsArc9Weapon
        return wep ~= nil and wep.ARC9 ~= nil
            and isfunction(wep.GetSubSlotList)
            and isfunction(wep.GetFinalAttTable)
    end,
    expand = function(_, wep)
        local out = {}
        local ok, slots = pcall(wep.GetSubSlotList, wep)
        if not ok or not istable(slots) then return out end
        for _, slottbl in ipairs(slots) do
            if istable(slottbl) and slottbl.Installed and slottbl.Address ~= nil then
                local okA, merged = pcall(wep.GetFinalAttTable, wep, slottbl)
                if okA and istable(merged)
                    and istable(merged.ToggleStats) and merged.ToggleOnF then
                    -- the device NAME reads from the UNMERGED table: the
                    -- merge overwrites PrintName with the active MODE's
                    local base
                    if istable(ARC9) and isfunction(ARC9.GetAttTable) then
                        local okB, b = pcall(ARC9.GetAttTable, slottbl.Installed)
                        base = (okB and istable(b)) and b or nil
                    end
                    local label = base ~= nil and isstring(base.PrintName)
                        and base.PrintName or "Weapon Device"
                    out[#out + 1] = DeviceChip(wep, slottbl.Address, label,
                        base ~= nil and HasEmitterData(base) or false)
                end
            end
        end
        return out
    end,
})
