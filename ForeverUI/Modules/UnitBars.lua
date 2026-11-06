local addonName, ns = ...
local UnitBars = {}
ns.UnitBars = UnitBars

UnitBars.enhancers = {}
local activeAnimEnhancers = {}

local function GetUnitBarColor(unit, bar, isNameplate)
    if bar and bar.GetStatusBarColor then
        local r, g, b = bar:GetStatusBarColor()
        if r and (r > 0.05 or g > 0.05 or b > 0.05) then
            return r, g, b
        end
    end
    if unit and UnitExists(unit) then
        if UnitReaction then
            local reaction = UnitReaction(unit, "player")
            if reaction then
                if reaction <= 3 then
                    return 0.90, 0.12, 0.12
                elseif reaction == 4 then
                    return 0.95, 0.80, 0.10
                else
                    return 0.10, 0.85, 0.15
                end
            end
        end
    end
    if isNameplate then
        return 0.90, 0.12, 0.12
    end
    return 0.10, 0.85, 0.15
end

local function CreateBorderFrame(parent, r, g, b, thickness)
    local border = CreateFrame("Frame", nil, parent)
    border:SetAllPoints(parent)
    border:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)
    thickness = thickness or 2

    local top = border:CreateTexture(nil, "OVERLAY", nil, 5)
    top:SetTexture("Interface\\Buttons\\WHITE8X8")
    top:SetPoint("TOPLEFT", border, "TOPLEFT", -thickness, thickness)
    top:SetPoint("TOPRIGHT", border, "TOPRIGHT", thickness, thickness)
    top:SetHeight(thickness)

    local bottom = border:CreateTexture(nil, "OVERLAY", nil, 5)
    bottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", -thickness, -thickness)
    bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", thickness, -thickness)
    bottom:SetHeight(thickness)

    local left = border:CreateTexture(nil, "OVERLAY", nil, 5)
    left:SetTexture("Interface\\Buttons\\WHITE8X8")
    left:SetPoint("TOPLEFT", border, "TOPLEFT", -thickness, thickness)
    left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", -thickness, -thickness)
    left:SetWidth(thickness)

    local right = border:CreateTexture(nil, "OVERLAY", nil, 5)
    right:SetTexture("Interface\\Buttons\\WHITE8X8")
    right:SetPoint("TOPRIGHT", border, "TOPRIGHT", thickness, thickness)
    right:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", thickness, -thickness)
    right:SetWidth(thickness)

    border.edges = { top, bottom, left, right }
    function border:SetBorderColor(cr, cg, cb, ca)
        for i = 1, 4 do
            local edge = self.edges[i]
            edge:SetBlendMode("ADD")
            edge:SetVertexColor(cr, cg, cb, ca or 1.0)
        end
    end
    border:SetBorderColor(r or 1, g or 0.2, b or 0.2, 0.9)
    border:Hide()
    return border
end

local function EnsureEnhancerTicker()
    ns.Events:RegisterTicker("UnitBars_Update", function(dt, now)
        local cfg = ns.Config:Get("unitBars")
        local smoothSpeed = (cfg and cfg.smoothSpeed) or 18.0
        local trailSpeed = (cfg and cfg.trailSpeed) or 5.5
        local anyActive = false

        for enhancer in pairs(activeAnimEnhancers) do
            if not enhancer.statusBar or not enhancer.statusBar:IsShown() then
                enhancer.trauma = 0
                enhancer.flashAlpha = 0
                enhancer.cutAlpha = 0
                enhancer.barPunchY = 1.0
                activeAnimEnhancers[enhancer] = nil
            else
                local stillAnimating = UnitBars:StepEnhancer(enhancer, dt, now, smoothSpeed, trailSpeed)
                if stillAnimating then
                    anyActive = true
                else
                    activeAnimEnhancers[enhancer] = nil
                end
            end
        end

        return anyActive
    end)
end

function UnitBars:CreateBarEnhancer(statusBar, unitToken, isNameplate)
    if not statusBar then
        return nil
    end
    -- Always keep the native statusBar visible while alive so it never turns black or empty!
    statusBar:SetAlpha(1.0)

    if self.enhancers[statusBar] then
        local existing = self.enhancers[statusBar]
        existing.unit = unitToken
        existing.isNameplate = isNameplate
        existing.container:Show()
        existing.container:SetAlpha(1.0)
        return existing
    end

    local baseLevel = math.max(1, (statusBar:GetFrameLevel() or 1) + 2)

    -- Overlay container sits directly over statusBar without hiding statusBar
    local container = CreateFrame("Frame", nil, statusBar)
    container:SetAllPoints(statusBar)
    container:SetFrameLevel(baseLevel)
    container:EnableMouse(false)

    -- 1. Molten Damage Trail Chunk Texture: spans from current HP (displayFrac) to old HP (trailFrac)
    local trailTex = container:CreateTexture(nil, "ARTWORK", nil, 3)
    trailTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    trailTex:SetVertexColor(1.0, 0.65, 0.15, 0.95)
    trailTex:Hide()

    -- 2. Violent Recoil & Vertical Swell Bar (only shown during impact jolt/swell so the bar physically punches outward!)
    local recoilBar = CreateFrame("StatusBar", nil, container)
    recoilBar:SetAllPoints(container)
    recoilBar:SetFrameLevel(baseLevel + 1)
    recoilBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    recoilBar:SetMinMaxValues(0, 1000)
    recoilBar:SetValue(1000)
    recoilBar:Hide()

    -- 3. FX Overlay (Hit-Flash, White-Hot Cleavage Cut-Line, <20% Execute Pulse Border)
    local fxOverlay = CreateFrame("Frame", nil, container)
    fxOverlay:SetAllPoints(container)
    fxOverlay:SetFrameLevel(baseLevel + 2)

    local hitFlash = fxOverlay:CreateTexture(nil, "OVERLAY", nil, 4)
    hitFlash:SetTexture("Interface\\Buttons\\WHITE8X8")
    hitFlash:SetBlendMode("ADD")
    hitFlash:SetVertexColor(1.0, 0.95, 0.85, 0.0)
    hitFlash:SetAllPoints(fxOverlay)
    hitFlash:Hide()

    local cutLine = fxOverlay:CreateTexture(nil, "OVERLAY", nil, 6)
    cutLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    cutLine:SetBlendMode("ADD")
    cutLine:SetVertexColor(1.0, 0.95, 0.80, 0.0)
    cutLine:SetWidth(3.5)
    cutLine:Hide()

    local executeBorder = CreateBorderFrame(fxOverlay, 1.0, 0.15, 0.15, isNameplate and 2 or 2.5)

    local enhancer = {
        statusBar = statusBar,
        container = container,
        trailTex = trailTex,
        recoilBar = recoilBar,
        fxOverlay = fxOverlay,
        hitFlash = hitFlash,
        cutLine = cutLine,
        executeBorder = executeBorder,
        unit = unitToken,
        isNameplate = isNameplate,
        lastHp = nil,
        maxHp = 1,
        targetFrac = 1.0,
        displayFrac = 1.0,
        trailFrac = 1.0,
        trailHoldTimer = 0,
        flashAlpha = 0,
        cutAlpha = 0,
        trauma = 0,
        barPunchY = 1.0,
        isExecute = false,
        lastImpactTime = 0,
    }

    self.enhancers[statusBar] = enhancer
    return enhancer
end

function UnitBars:SyncUnitState(enhancer, forceReset)
    local unit = enhancer.unit
    if not unit or not UnitExists(unit) then
        return
    end

    local curHp = UnitHealth(unit) or 0
    local maxHp = UnitHealthMax(unit) or 1
    if maxHp <= 0 then
        maxHp = 1
    end
    local newFrac = math.max(0, math.min(1.0, curHp / maxHp))

    if forceReset or enhancer.lastHp == nil then
        enhancer.lastHp = curHp
        enhancer.maxHp = maxHp
        enhancer.targetFrac = newFrac
        enhancer.displayFrac = newFrac
        enhancer.trailFrac = newFrac
        enhancer.trauma = 0
        enhancer.barPunchY = 1.0
        enhancer.flashAlpha = 0
        enhancer.cutAlpha = 0
        enhancer.trailTex:Hide()
        enhancer.recoilBar:Hide()
        enhancer.cutLine:Hide()
        enhancer.hitFlash:Hide()
        self:UpdateExecuteState(enhancer, newFrac, curHp)
        self:RenderEnhancer(enhancer, 0, 0)
        return
    end

    local prevHp = enhancer.lastHp
    enhancer.lastHp = curHp
    enhancer.maxHp = maxHp
    enhancer.targetFrac = newFrac

    if curHp < prevHp then
        local dmg = prevHp - curHp
        local pctLost = dmg / maxHp
        local now = GetTime()
        if (now - (enhancer.lastImpactTime or 0)) > 0.05 then
            local isHeavy = pctLost >= 0.14
            self:TriggerDamageImpact(enhancer, pctLost, isHeavy, pctLost >= 0.28)
            if enhancer.isNameplate and ns.CombatText then
                ns.CombatText:SpawnNumber({
                    text = tostring(dmg),
                    r = 1.0,
                    g = isHeavy and 0.82 or 1.0,
                    b = isHeavy and 0.0 or 1.0,
                    isCrit = isHeavy,
                    isMega = pctLost >= 0.28,
                    anchorFrame = enhancer.statusBar,
                    side = "right",
                })
            end
        else
            activeAnimEnhancers[enhancer] = true
            EnsureEnhancerTicker()
        end
    elseif curHp > prevHp then
        enhancer.barPunchY = math.max(enhancer.barPunchY, 1.16)
        activeAnimEnhancers[enhancer] = true
        EnsureEnhancerTicker()
    end

    self:UpdateExecuteState(enhancer, newFrac, curHp)
end

function UnitBars:TriggerDamageImpact(enhancer, pctLost, isCrit, isMega)
    local cfg = ns.Config:Get("unitBars")
    if not cfg or not cfg.enabled then
        return
    end

    enhancer.lastImpactTime = GetTime()
    enhancer.trailHoldTimer = isCrit and (cfg.trailHoldCrit or 0.38) or (cfg.trailHoldNormal or 0.24)
    enhancer.flashAlpha = isCrit and 0.95 or 0.72
    enhancer.cutAlpha = 1.0

    local mult = isCrit and (cfg.critTraumaMultiplier or 1.75) or 1.05
    local rawTrauma = math.min(1.0, (pctLost / 0.22) * mult * (cfg.traumaScale or 1.0))
    if isCrit and rawTrauma < 0.65 then
        rawTrauma = 0.65
    elseif rawTrauma < 0.30 then
        rawTrauma = 0.30
    end
    enhancer.trauma = math.min(1.0, math.max(enhancer.trauma, rawTrauma))

    local punch = isMega and (cfg.barPunchMega or 1.65)
        or (isCrit and (cfg.barPunchCrit or 1.48) or (cfg.barPunchNormal or 1.22))
    enhancer.barPunchY = math.max(enhancer.barPunchY, punch)

    if ns.CombatFX and enhancer.statusBar then
        if isCrit or pctLost >= 0.10 then
            local count = isMega and 16 or (isCrit and 11 or 6)
            ns.CombatFX:SpawnBarSparks(enhancer.statusBar, enhancer.targetFrac, count, 1.0, 0.65, 0.15, false)
        else
            ns.CombatFX:SpawnBarSparks(enhancer.statusBar, enhancer.targetFrac, 4, 1.0, 0.82, 0.25, false)
        end
    end

    activeAnimEnhancers[enhancer] = true
    EnsureEnhancerTicker()
end

function UnitBars:UpdateExecuteState(enhancer, frac, curHp)
    local cfg = ns.Config:Get("unitBars")
    local threshold = (cfg and cfg.executeThreshold) or 0.20
    local shouldExecute = (curHp > 0) and (frac <= threshold) and (enhancer.unit ~= "player")
    enhancer.isExecute = shouldExecute
    if shouldExecute then
        enhancer.executeBorder:Show()
        activeAnimEnhancers[enhancer] = true
        EnsureEnhancerTicker()
    else
        enhancer.executeBorder:Hide()
    end
end

function UnitBars:StepEnhancer(enhancer, dt, now, smoothSpeed, trailSpeed)
    local stillActive = false

    local diffMain = enhancer.targetFrac - enhancer.displayFrac
    if math.abs(diffMain) > 0.001 then
        enhancer.displayFrac = enhancer.displayFrac + diffMain * math.min(1.0, dt * smoothSpeed)
        stillActive = true
    else
        enhancer.displayFrac = enhancer.targetFrac
    end

    if enhancer.trailFrac > enhancer.displayFrac + 0.001 then
        stillActive = true
        if enhancer.trailHoldTimer > 0 then
            enhancer.trailHoldTimer = enhancer.trailHoldTimer - dt
        else
            local diffTrail = enhancer.displayFrac - enhancer.trailFrac
            enhancer.trailFrac = enhancer.trailFrac + diffTrail * math.min(1.0, dt * trailSpeed)
        end
    else
        enhancer.trailFrac = enhancer.displayFrac
    end

    if enhancer.flashAlpha > 0.01 then
        enhancer.flashAlpha = math.max(0, enhancer.flashAlpha - dt * 4.2)
        stillActive = true
    else
        enhancer.flashAlpha = 0
    end

    if enhancer.cutAlpha > 0.01 then
        enhancer.cutAlpha = math.max(0, enhancer.cutAlpha - dt * 2.8)
        stillActive = true
    else
        enhancer.cutAlpha = 0
    end

    if math.abs(enhancer.barPunchY - 1.0) > 0.005 then
        enhancer.barPunchY = enhancer.barPunchY + (1.0 - enhancer.barPunchY) * math.min(1.0, dt * 11.0)
        stillActive = true
    else
        enhancer.barPunchY = 1.0
    end

    local dx, dy = 0, 0
    if enhancer.trauma > 0.01 then
        stillActive = true
        local p = enhancer.trauma * enhancer.trauma
        local maxOffset = enhancer.isNameplate and 11.0 or 8.0
        dx = (math.sin(now * 88.0) * maxOffset + (math.random() - 0.5) * 6.0) * p
        dy = (math.cos(now * 96.0) * (maxOffset * 0.65) + (math.random() - 0.5) * 4.5) * p
        enhancer.trauma = math.max(0, enhancer.trauma - dt * 2.35)
    else
        enhancer.trauma = 0
    end

    if enhancer.isExecute then
        stillActive = true
        local pulse = 0.45 + 0.50 * (0.5 + 0.5 * math.sin(now * 8.5))
        enhancer.executeBorder:SetBorderColor(1.0, 0.15, 0.15, pulse)
    end

    self:RenderEnhancer(enhancer, dx, dy)
    return stillActive
end

function UnitBars:RenderEnhancer(enhancer, dx, dy)
    local bar = enhancer.statusBar
    local w = bar:GetWidth()
    local h = bar:GetHeight()
    if not w or w <= 0 or not h or h <= 0 then
        return
    end

    local container = enhancer.container
    local punchedH = h * enhancer.barPunchY
    local yPad = (punchedH - h) * 0.5

    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", bar, "TOPLEFT", dx, yPad + dy)
    container:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", dx, -yPad + dy)

    local mainW = math.max(0.001, enhancer.displayFrac * w)
    local trailW = math.max(0.001, enhancer.trailFrac * w)

    -- 1. Violent Recoil & Vertical Swell Bar (only visible during active recoil/punch)
    if enhancer.barPunchY > 1.02 or enhancer.trauma > 0.02 then
        local r, g, b = GetUnitBarColor(enhancer.unit, bar, enhancer.isNameplate)
        enhancer.recoilBar:SetStatusBarColor(r, g, b, 0.95)
        enhancer.recoilBar:SetValue(math.floor(enhancer.displayFrac * 1000))
        enhancer.recoilBar:Show()
    else
        enhancer.recoilBar:Hide()
    end

    -- 2. Molten Damage Trail Chunk spanning from mainW (current HP) to trailW (pre-hit HP)
    if trailW > mainW + 0.8 then
        local chunkW = trailW - mainW
        if enhancer.trailHoldTimer > 0.12 then
            enhancer.trailTex:SetVertexColor(1.0, 0.90, 0.55, 0.98)
        else
            enhancer.trailTex:SetVertexColor(1.0, 0.32, 0.08, 0.95)
        end
        enhancer.trailTex:ClearAllPoints()
        enhancer.trailTex:SetPoint("TOPLEFT", container, "TOPLEFT", mainW, 0)
        enhancer.trailTex:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", mainW, 0)
        enhancer.trailTex:SetWidth(chunkW)
        enhancer.trailTex:Show()
    else
        enhancer.trailTex:Hide()
    end

    -- 3. White-Hot Cleavage Cut-Line at mainW
    if enhancer.cutAlpha > 0.01 and enhancer.displayFrac > 0.01 and enhancer.displayFrac < 0.99 then
        enhancer.cutLine:ClearAllPoints()
        enhancer.cutLine:SetPoint("TOP", container, "TOPLEFT", mainW, 3)
        enhancer.cutLine:SetPoint("BOTTOM", container, "BOTTOMLEFT", mainW, -3)
        enhancer.cutLine:SetAlpha(enhancer.cutAlpha)
        enhancer.cutLine:Show()
    else
        enhancer.cutLine:Hide()
    end

    -- 4. Hit-Flash Overlay
    if enhancer.flashAlpha > 0.01 then
        enhancer.hitFlash:SetAlpha(enhancer.flashAlpha)
        enhancer.hitFlash:Show()
    else
        enhancer.hitFlash:Hide()
    end
end

local function ResolveDefaultHealthBar(unitFrame, globalBarName)
    if _G[globalBarName] then
        return _G[globalBarName]
    end
    if unitFrame then
        if unitFrame.healthbar then
            return unitFrame.healthbar
        end
        if unitFrame.HealthBar then
            return unitFrame.HealthBar
        end
    end
    return nil
end

function UnitBars:OnEnable()
    local playerBar = ResolveDefaultHealthBar(PlayerFrame, "PlayerFrameHealthBar")
    if playerBar then
        self.playerEnhancer = self:CreateBarEnhancer(playerBar, "player", false)
        self:SyncUnitState(self.playerEnhancer, true)
    end

    local targetBar = ResolveDefaultHealthBar(TargetFrame, "TargetFrameHealthBar")
    if targetBar then
        self.targetEnhancer = self:CreateBarEnhancer(targetBar, "target", false)
    end

    local function OnUnitHealthChanged(_, _, unit)
        if unit == "player" and self.playerEnhancer then
            self:SyncUnitState(self.playerEnhancer, false)
        elseif unit == "target" and self.targetEnhancer then
            self:SyncUnitState(self.targetEnhancer, false)
        end
    end

    ns.Events:Register("UNIT_HEALTH", OnUnitHealthChanged, self)
    ns.Events:Register("UNIT_HEALTH_FREQUENT", OnUnitHealthChanged, self)

    ns.Events:Register("PLAYER_TARGET_CHANGED", function()
        if self.targetEnhancer and UnitExists("target") then
            self:SyncUnitState(self.targetEnhancer, true)
        end
    end, self)

    ns.Events:Register("PLAYER_ENTERING_WORLD", function()
        if self.playerEnhancer then
            self:SyncUnitState(self.playerEnhancer, true)
        end
    end, self)
end
