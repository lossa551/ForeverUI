local addonName, ns = ...
local CombatText = {}
ns.CombatText = CombatText

-- TOOLTIP strata + high FrameLevel guarantees damage numbers ALWAYS render in front of
-- all enemy nameplates, health bars, sparks, and death bars!
local sctCanvas = CreateFrame("Frame", "ForeverUI_SCTCanvas", UIParent)
sctCanvas:SetAllPoints(UIParent)
sctCanvas:SetFrameStrata("TOOLTIP")
sctCanvas:SetFrameLevel(200)
sctCanvas:EnableMouse(false)

local textPool = {}
local activeTexts = {}

-- Smart Anti-Overlap Fountain Lanes (cycles 1 -> 2 -> 3 -> 4 so rapid hits never stack)
local FOUNTAIN_LANES = {
    { x = -22, y = 0, vx = -46, vy = 78 }, -- Lane 1: Left outer fountain arc
    { x =  22, y = 0, vx =  46, vy = 78 }, -- Lane 2: Right outer fountain arc
    { x = -11, y = 7, vx = -22, vy = 92 }, -- Lane 3: Left high inner arc
    { x =  11, y = 7, vx =  22, vy = 92 }, -- Lane 4: Right high inner arc
}
local laneCursor = 0
local critSideToggle = 1

-- Rapid-Hit "Flurry" Escalation state
local flurryCount = 0
local lastHitTime = 0

-- Authentic WoW Spell School Colors
local SCHOOL_COLORS = {
    [1]  = { 1.00, 0.82, 0.00 }, -- Physical ability (Classic Yellow/Gold)
    [2]  = { 1.00, 0.90, 0.50 }, -- Holy
    [4]  = { 1.00, 0.50, 0.00 }, -- Fire
    [8]  = { 0.30, 1.00, 0.30 }, -- Nature
    [16] = { 0.40, 0.80, 1.00 }, -- Frost
    [32] = { 0.72, 0.45, 1.00 }, -- Shadow
    [64] = { 1.00, 0.55, 1.00 }, -- Arcane
}

local function SetFontStringTextSafe(fs, textVal)
    if ns.IsSecret(textVal) then
        fs:SetText(textVal)
    else
        fs:SetText(tostring(textVal or ""))
    end
end

local function AcquireTextEntry()
    local entry = table.remove(textPool)
    if not entry then
        -- Outer holder stays at scale 1.0 so SetPoint offsets never get multiplied by SetScale!
        local holder = CreateFrame("Frame", nil, sctCanvas)
        holder:SetSize(1, 1)
        holder:SetFrameStrata("TOOLTIP")
        holder:SetFrameLevel(210)

        -- Expanding Shockwave Echo frame (behind main zoomFrame on Crits)
        local echoZoom = CreateFrame("Frame", nil, holder)
        echoZoom:SetSize(240, 50)
        echoZoom:SetPoint("CENTER", holder, "CENTER", 0, 0)
        echoZoom:SetFrameLevel(210)

        local echoFs = echoZoom:CreateFontString(nil, "BACKGROUND")
        echoFs:SetPoint("CENTER", echoZoom, "CENTER", 0, 0)

        local echoBangFs = echoZoom:CreateFontString(nil, "BACKGROUND")
        echoBangFs:SetPoint("LEFT", echoFs, "RIGHT", 1, 0)

        -- Inner zoomFrame sits at (0, 0) center of holder and handles elastic Crit Pop-In scaling
        local zoomFrame = CreateFrame("Frame", nil, holder)
        zoomFrame:SetSize(240, 50)
        zoomFrame:SetPoint("CENTER", holder, "CENTER", 0, 0)
        zoomFrame:SetFrameLevel(212)

        local fs = zoomFrame:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER", zoomFrame, "CENTER", 0, 0)
        fs:SetShadowOffset(1.8, -1.8)
        fs:SetShadowColor(0, 0, 0, 0.96)

        -- Separate "!" / "!!" FontString anchored to the right of fs (100% Secret-Value compatible!)
        local bangFs = zoomFrame:CreateFontString(nil, "OVERLAY")
        bangFs:SetPoint("LEFT", fs, "RIGHT", 1, 0)
        bangFs:SetShadowOffset(1.8, -1.8)
        bangFs:SetShadowColor(0, 0, 0, 0.96)

        entry = {
            holder = holder,
            echoZoom = echoZoom,
            echoFs = echoFs,
            echoBangFs = echoBangFs,
            zoomFrame = zoomFrame,
            fs = fs,
            bangFs = bangFs,
        }
    end
    entry.holder:Show()
    entry.holder:SetAlpha(1.0)
    entry.zoomFrame:SetScale(1.0)
    entry.echoZoom:SetScale(1.0)
    entry.echoZoom:Hide()
    entry.bangFs:Hide()
    entry.echoBangFs:Hide()
    return entry
end

local function ReleaseTextEntry(entry)
    entry.holder:Hide()
    entry.echoZoom:Hide()
    entry.bangFs:Hide()
    entry.echoBangFs:Hide()
    entry.anchorFrame = nil
    table.insert(textPool, entry)
end

local function EnsureSCTTicker()
    ns.Events:RegisterTicker("CombatText_Update", function(dt)
        for i = #activeTexts, 1, -1 do
            local ft = activeTexts[i]
            ft.age = ft.age + dt
            if ft.age >= ft.duration then
                ReleaseTextEntry(ft)
                table.remove(activeTexts, i)
            else
                local t = ft.age / ft.duration
                ft.offsetX = ft.offsetX + ft.vx * dt
                ft.offsetY = ft.offsetY + ft.vy * dt
                ft.vy = ft.vy - ft.gravity * dt

                local scale = ft.flurryScale or 1.0
                local shakeX, shakeY = 0, 0

                if ft.isCrit then
                    local peak = (ft.isMega and 2.05 or 1.75) * (ft.flurryScale or 1.0)
                    local settle = (ft.isMega and 1.42 or 1.26) * (ft.flurryScale or 1.0)
                    if ft.age < 0.08 then
                        scale = 0.55 + (ft.age / 0.08) * (peak - 0.55)
                    elseif ft.age < 0.22 then
                        scale = peak - ((ft.age - 0.08) / 0.14) * (peak - settle)
                    else
                        scale = settle
                    end

                    -- High-energy Crit Impact Micro-Shudder at peak pop-in
                    if ft.hasShockwave and ft.age >= 0.04 and ft.age <= 0.24 then
                        local damper = 1.0 - ((ft.age - 0.04) / 0.20)
                        local mag = (ft.isMega and 4.2 or 3.0) * damper
                        shakeX = math.sin(ft.age * 145.0) * mag
                        shakeY = math.cos(ft.age * 165.0) * (mag * 0.65)
                    end

                    -- Crit Heat-Burn Color Gradient: White-Hot flash (0..0.09s) -> Molten Gold/Fiery Orange
                    if ft.hasShockwave then
                        local cr, cg, cb = ft.baseR, ft.baseG, ft.baseB
                        if ft.age < 0.09 then
                            cr, cg, cb = 1.0, 0.98, 0.90
                        elseif ft.age < 0.30 then
                            local burnT = (ft.age - 0.09) / 0.21
                            cr = 1.0 + (ft.baseR - 1.0) * burnT
                            cg = 0.98 + (ft.baseG - 0.98) * burnT
                            cb = 0.90 + (ft.baseB - 0.90) * burnT
                        end
                        ft.fs:SetTextColor(cr, cg, cb, 1.0)
                        ft.bangFs:SetTextColor(cr, cg, cb, 1.0)
                    end

                    -- Expanding Shockwave Echo ring behind the crit number
                    if ft.hasShockwave and ft.age <= 0.34 then
                        local echoT = ft.age / 0.34
                        local echoScale = scale * (1.0 + echoT * 1.15)
                        local echoAlpha = math.max(0, (1.0 - echoT) * 0.68)
                        ft.echoZoom:SetScale(echoScale)
                        ft.echoZoom:SetAlpha(echoAlpha)
                    elseif ft.hasShockwave then
                        ft.echoZoom:Hide()
                    end
                else
                    -- Subtle crisp pop-in for normal hits (amplified by Flurry escalation)
                    if ft.age < 0.06 then
                        local peak = (ft.flurryScale or 1.0) * 1.16
                        scale = 0.80 + (ft.age / 0.06) * (peak - 0.80)
                    elseif ft.age < 0.14 then
                        local peak = (ft.flurryScale or 1.0) * 1.16
                        local settle = ft.flurryScale or 1.0
                        scale = peak - ((ft.age - 0.06) / 0.08) * (peak - settle)
                    end
                end

                local alpha = 1.0
                if t > 0.72 then
                    alpha = math.max(0, 1.0 - (t - 0.72) / 0.28)
                end

                ft.holder:ClearAllPoints()
                if ft.anchorFrame then
                    ft.holder:SetPoint("CENTER", ft.anchorFrame, "TOP", ft.offsetX + shakeX, ft.offsetY + shakeY)
                else
                    ft.holder:SetPoint("CENTER", UIParent, "CENTER", ft.baseCenterX + ft.offsetX + shakeX, ft.baseCenterY + ft.offsetY + shakeY)
                end

                ft.zoomFrame:SetScale(scale)
                ft.holder:SetAlpha(alpha)
            end
        end
        return #activeTexts > 0
    end)
end

-- Pure text-only combat number spawn (no icons).
-- Supports WoW 12.0+ / 16001 Secret Number Values directly via FontString:SetText(secretVal).
function CombatText:SpawnNumber(opts)
    local cfg = ns.Config:Get("combatText")
    if not cfg or not cfg.enabled or not opts or opts.text == nil then
        return
    end

    local isDeflect = not not opts.isDeflect
    local isInterrupt = not not opts.isInterrupt

    local now = GetTime()
    local flurryWindow = cfg.flurryWindow or 1.45
    if not isDeflect and not isInterrupt then
        if (now - lastHitTime) <= flurryWindow then
            flurryCount = math.min(8, flurryCount + 1)
        else
            flurryCount = 1
        end
        lastHitTime = now
    end

    local flurryFactor = ((not isDeflect and not isInterrupt) and cfg.flurryEscalation ~= false)
        and ((flurryCount - 1) / 7.0) or 0.0
    local flurryScale = 1.0 + flurryFactor * 0.26

    local entry = AcquireTextEntry()
    local isCrit = not not opts.isCrit
    local isMega = not not opts.isMega
    local hasShockwave = isCrit and (cfg.critShockwave ~= false)

    local fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local fontSize = isMega and (cfg.megaFontSize or 28)
        or (isCrit and (cfg.critFontSize or 24) or (cfg.normalFontSize or 17))
    if isDeflect then
        fontSize = math.max(16, (cfg.normalFontSize or 17) + 1)
    end
    local fontFlags = (isCrit or isDeflect) and "THICKOUTLINE" or "OUTLINE"

    entry.fs:SetFont(fontPath, fontSize, fontFlags)
    SetFontStringTextSafe(entry.fs, opts.text)

    -- Compute base color (with Rapid-Hit Flurry heat tint warming white hits into gold/orange!)
    local r = opts.r or 1.0
    local g = opts.g or 1.0
    local b = opts.b or 1.0
    if not isCrit and not isDeflect and flurryFactor > 0.05 and r > 0.9 and g > 0.9 and b > 0.9 then
        r = 1.0
        g = 1.0 - flurryFactor * 0.42
        b = 1.0 - flurryFactor * 0.85
    elseif isCrit and not isInterrupt then
        r = 1.0
        g = isMega and 0.48 or math.max(0.45, (opts.g or 0.82) - flurryFactor * 0.25)
        b = 0.04
    end

    entry.baseR, entry.baseG, entry.baseB = r, g, b

    if hasShockwave then
        -- Start crits White-Hot on frame 0; ticker burns them into entry.baseR/G/B
        entry.fs:SetTextColor(1.0, 0.98, 0.90, 1.0)
    else
        entry.fs:SetTextColor(r, g, b, 1.0)
    end

    -- Punctuation accent ("!" on Crits or high Flurry >= 5; "!!" on Mega Crits)
    local bangText = nil
    if not isDeflect then
        if isMega or (isCrit and flurryCount >= 4 and not isInterrupt) then
            bangText = "!!"
        elseif isCrit or flurryCount >= 5 then
            bangText = "!"
        end
    end

    if bangText then
        entry.bangFs:SetFont(fontPath, fontSize, fontFlags)
        entry.bangFs:SetText(bangText)
        entry.bangFs:SetTextColor(r, g, b, 1.0)
        entry.bangFs:Show()
    else
        entry.bangFs:Hide()
    end

    -- Crit Shockwave Echo Afterimage setup
    if hasShockwave then
        local echoR = isInterrupt and 0.15 or 1.0
        local echoG = isInterrupt and 0.88 or (isMega and 0.35 or 0.65)
        local echoB = isInterrupt and 1.00 or 0.05
        entry.echoFs:SetFont(fontPath, fontSize, fontFlags)
        SetFontStringTextSafe(entry.echoFs, opts.text)
        entry.echoFs:SetTextColor(echoR, echoG, echoB, 0.75)
        if bangText then
            entry.echoBangFs:SetFont(fontPath, fontSize, fontFlags)
            entry.echoBangFs:SetText(bangText)
            entry.echoBangFs:SetTextColor(echoR, echoG, echoB, 0.75)
            entry.echoBangFs:Show()
        end
        entry.echoZoom:SetScale(1.0)
        entry.echoZoom:SetAlpha(0.70)
        entry.echoZoom:Show()
    else
        entry.echoZoom:Hide()
    end

    entry.anchorFrame = opts.anchorFrame
    entry.baseCenterX = (opts.side == "left") and -140 or 185
    entry.baseCenterY = (opts.side == "left") and 20 or 55

    -- Spawn high above the health bar & unit name (+26px normal, +34px crit)
    -- and fan out using Smart Anti-Overlap Fountain Lanes!
    local baseOffsetY = isCrit and (cfg.critOffsetY or 34) or (cfg.baseOffsetY or 26)
    local speedMult = 1.0 + flurryFactor * 0.22

    if isDeflect then
        -- Metallic sideways ricochet trajectory off the bar
        critSideToggle = -critSideToggle
        entry.offsetX = critSideToggle * 18
        entry.offsetY = (cfg.baseOffsetY or 26) - 4
        entry.vx = critSideToggle * (92 + math.random() * 24)
        entry.vy = 54 + math.random() * 14
    elseif isInterrupt then
        entry.offsetX = 0
        entry.offsetY = (cfg.critOffsetY or 34) + 6
        entry.vx = 0
        entry.vy = 78
    elseif opts.side == "left" then
        entry.offsetX = -12 + (math.random() * 10 - 5)
        entry.offsetY = baseOffsetY
        entry.vx = -32 * speedMult
        entry.vy = 80 * speedMult
    elseif isCrit then
        critSideToggle = -critSideToggle
        entry.offsetX = critSideToggle * (7 + math.random() * 5)
        entry.offsetY = baseOffsetY + (math.random() * 4)
        entry.vx = critSideToggle * (14 + math.random() * 8) * speedMult
        entry.vy = (92 + math.random() * 14) * speedMult
    elseif cfg.fountainLanes ~= false then
        laneCursor = (laneCursor % #FOUNTAIN_LANES) + 1
        local lane = FOUNTAIN_LANES[laneCursor]
        entry.offsetX = lane.x + (math.random() * 4 - 2)
        entry.offsetY = baseOffsetY + lane.y
        entry.vx = (lane.vx + (math.random() * 8 - 4)) * speedMult
        entry.vy = (lane.vy + (math.random() * 8 - 4)) * speedMult
    else
        local dir = (math.random() > 0.5) and 1 or -1
        entry.offsetX = (math.random() * 20 - 10)
        entry.offsetY = baseOffsetY
        entry.vx = dir * (26 + math.random() * 24) * speedMult
        entry.vy = (85 + math.random() * 16) * speedMult
    end

    -- Low upward-floating gravity so numbers NEVER drop back down across the health bar!
    entry.gravity = isDeflect and 115 or (isCrit and 36 or 52)
    entry.isCrit = isCrit
    entry.isMega = isMega
    entry.hasShockwave = hasShockwave
    entry.flurryScale = flurryScale
    entry.age = 0
    entry.duration = isCrit and (cfg.durationCrit or 1.50) or (cfg.durationNormal or 1.15)

    entry.holder:ClearAllPoints()
    if entry.anchorFrame then
        entry.holder:SetPoint("CENTER", entry.anchorFrame, "TOP", entry.offsetX, entry.offsetY)
    else
        entry.holder:SetPoint("CENTER", UIParent, "CENTER", entry.baseCenterX + entry.offsetX, entry.baseCenterY + entry.offsetY)
    end
    entry.zoomFrame:SetScale(isCrit and 0.55 or (0.80 * flurryScale))

    table.insert(activeTexts, entry)
    EnsureSCTTicker()
end

function CombatText:OnCombatLogEvent()
    if not CombatLogGetCurrentEventInfo then
        return
    end
    local _, subEvent, _, sourceGUID, _, sourceFlags, _, destGUID, _, _, _, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21 = CombatLogGetCurrentEventInfo()
    if not subEvent or ns.IsSecret(subEvent) or ns.IsSecret(sourceGUID) or ns.IsSecret(destGUID) then
        return
    end
    local playerGUID = UnitGUID("player")
    if not playerGUID or ns.IsSecret(playerGUID) then
        return
    end

    local petGUID = UnitGUID("pet")
    if ns.IsSecret(petGUID) then
        petGUID = nil
    end

    local isMine = (sourceGUID == playerGUID)
        or (petGUID and sourceGUID == petGUID)
        or (sourceFlags and not ns.IsSecret(sourceFlags) and bit and bit.band and COMBATLOG_OBJECT_AFFILIATION_MINE and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0)

    local isOutgoing = isMine and (destGUID ~= playerGUID)
    local isIncoming = (destGUID == playerGUID)
    if not isOutgoing and not isIncoming then
        return
    end

    local amount, overkill, school, critical
    local isHeal = false
    local isAutoAttack = false

    if subEvent == "SWING_DAMAGE" then
        amount, overkill, school, _, _, _, critical = arg12, arg13, arg14, arg15, arg16, arg17, arg18
        isAutoAttack = true
    elseif subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
        school = arg14
        amount = arg15
        overkill = arg16
        critical = arg21
        isAutoAttack = (subEvent == "RANGE_DAMAGE")
    elseif subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL" then
        amount = arg15
        critical = arg18
        isHeal = true
    elseif subEvent == "UNIT_DIED" or subEvent == "PARTY_KILL" then
        if ns.Nameplates and destGUID then
            local _, enhancer = ns.Nameplates:GetBarForGUID(destGUID)
            if enhancer then
                ns.Nameplates:TriggerDeathForEnhancer(enhancer)
            end
        end
        return
    else
        return
    end

    if not amount then
        return
    end
    if not ns.IsSecret(amount) and amount <= 0 then
        return
    end

    local isCrit = (not ns.IsSecret(critical)) and (not not critical) or false
    local isKill = (overkill and not ns.IsSecret(overkill) and overkill >= 0) or false

    if isOutgoing and not isHeal then
        if ns.Nameplates then
            ns.Nameplates:OnCombatLogImpact(destGUID, amount, isCrit, isKill)
        end

        local anchorBar = nil
        local cfg = ns.Config:Get("combatText")
        if cfg and cfg.anchorToNameplate and ns.Nameplates then
            anchorBar = ns.Nameplates:GetBarForGUID(destGUID)
        end

        -- Avoid duplicate numbers if UNIT_COMBAT already spawned for this nameplate hit
        if anchorBar or ((GetTime() - (self.lastUnitCombatTime or 0)) < 0.15) then
            return
        end

        local r, g, b = 1.0, 1.0, 1.0
        if not isAutoAttack then
            local schoolKey = (school and not ns.IsSecret(school)) and school or 1
            local sc = SCHOOL_COLORS[schoolKey] or SCHOOL_COLORS[1]
            r, g, b = sc[1], sc[2], sc[3]
        elseif isCrit then
            r, g, b = 1.0, 0.82, 0.0
        end

        self:SpawnNumber({
            text = ns.IsSecret(amount) and amount or tostring(amount),
            r = r, g = g, b = b,
            isCrit = isCrit,
            isMega = isCrit and isKill,
            anchorFrame = anchorBar,
            side = "right",
        })
    elseif isIncoming and not ns.IsSecret(amount) then
        if isHeal then
            self:SpawnNumber({
                text = "+" .. tostring(amount),
                r = 0.15, g = 1.0, b = 0.15,
                isCrit = isCrit,
                side = "left",
            })
        else
            self:SpawnNumber({
                text = "-" .. tostring(amount),
                r = 1.0, g = 0.15, b = 0.15,
                isCrit = isCrit,
                side = "left",
            })
        end
    end
end

function CombatText:OnEnable()
    -- Note: In WoW Forever (16001), SetCVar is a protected Blizzard-only action.
    -- All enemy damage numbers are driven directly by Nameplates:OnUnitCombat (UNIT_COMBAT).
end
