local addonName, ns = ...
local UnitBars = {}
ns.UnitBars = UnitBars

UnitBars.enhancers = {}
local activeAnimEnhancers = {}

local function GetUnitBarColor(unit)
    if unit and UnitExists(unit) and UnitReaction then
        local reaction = UnitReaction(unit, "player")
        if reaction and not ns.IsSecret(reaction) then
            if reaction <= 3 then
                return 0.92, 0.12, 0.12 -- Hostile Red
            elseif reaction == 4 then
                return 0.95, 0.80, 0.10 -- Neutral Yellow
            else
                return 0.12, 0.85, 0.15 -- Friendly Green
            end
        end
    end
    return 0.92, 0.12, 0.12
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

local function AddClassicBarBevel(statusBar)
    local sheen = statusBar:CreateTexture(nil, "OVERLAY", nil, 1)
    sheen:SetTexture("Interface\\Buttons\\WHITE8X8")
    sheen:SetVertexColor(1.0, 1.0, 1.0, 0.22)
    sheen:SetPoint("TOPLEFT", statusBar, "TOPLEFT", 0, 0)
    sheen:SetPoint("BOTTOMRIGHT", statusBar, "RIGHT", 0, 0)

    local shadow = statusBar:CreateTexture(nil, "OVERLAY", nil, 1)
    shadow:SetTexture("Interface\\Buttons\\WHITE8X8")
    shadow:SetVertexColor(0.0, 0.0, 0.0, 0.28)
    shadow:SetPoint("TOPLEFT", statusBar, "LEFT", 0, 0)
    shadow:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT", 0, 0)
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

    local defaultW = isNameplate and 118 or 156
    local defaultH = isNameplate and 12 or 14
    statusBar.fuiWidth = defaultW
    statusBar.fuiHeight = defaultH
    statusBar:SetAlpha(1.0)

    if self.enhancers[statusBar] then
        local existing = self.enhancers[statusBar]
        existing.unit = unitToken
        existing.isNameplate = isNameplate
        existing.baseWidth = defaultW
        existing.baseHeight = defaultH
        existing.container.fuiWidth = defaultW
        existing.container.fuiHeight = defaultH
        existing.container:Show()
        existing.container:SetAlpha(1.0)
        self:RefreshBarColor(existing)
        return existing
    end

    local baseLevel = math.max(2, (statusBar:GetFrameLevel() or 1) + 2)
    local container = CreateFrame("Frame", nil, statusBar)
    container:SetAllPoints(statusBar)
    container:SetFrameLevel(baseLevel)
    container:EnableMouse(false)
    container.fuiWidth = defaultW
    container.fuiHeight = defaultH

    local bgTex = container:CreateTexture(nil, "BACKGROUND", nil, 0)
    bgTex:SetAllPoints(container)
    bgTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    bgTex:SetVertexColor(0.06, 0.06, 0.07, 0.96)

    local trailBar = CreateFrame("StatusBar", nil, container)
    trailBar:SetAllPoints(container)
    trailBar:SetFrameLevel(baseLevel + 1)
    trailBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    trailBar:SetStatusBarColor(1.0, 0.65, 0.12, 0.98)
    trailBar:SetMinMaxValues(0, 1000)
    trailBar:SetValue(1000)

    local mainBar = CreateFrame("StatusBar", nil, container)
    mainBar:SetAllPoints(container)
    mainBar:SetFrameLevel(baseLevel + 2)
    mainBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    mainBar:SetStatusBarColor(0.92, 0.12, 0.12, 1.0)
    mainBar:SetMinMaxValues(0, 1000)
    mainBar:SetValue(1000)
    AddClassicBarBevel(mainBar)

    local fxOverlay = CreateFrame("Frame", nil, container)
    fxOverlay:SetAllPoints(container)
    fxOverlay:SetFrameLevel(baseLevel + 3)

    local bTop = fxOverlay:CreateTexture(nil, "BORDER")
    bTop:SetTexture("Interface\\Buttons\\WHITE8X8")
    bTop:SetVertexColor(0.08, 0.07, 0.06, 0.96)
    bTop:SetPoint("TOPLEFT", container, "TOPLEFT", -1, 1)
    bTop:SetPoint("TOPRIGHT", container, "TOPRIGHT", 1, 1)
    bTop:SetHeight(1)

    local bBot = fxOverlay:CreateTexture(nil, "BORDER")
    bBot:SetTexture("Interface\\Buttons\\WHITE8X8")
    bBot:SetVertexColor(0.08, 0.07, 0.06, 0.96)
    bBot:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", -1, -1)
    bBot:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 1, -1)
    bBot:SetHeight(1)

    local bLeft = fxOverlay:CreateTexture(nil, "BORDER")
    bLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
    bLeft:SetVertexColor(0.08, 0.07, 0.06, 0.96)
    bLeft:SetPoint("TOPLEFT", container, "TOPLEFT", -1, 1)
    bLeft:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", -1, -1)
    bLeft:SetWidth(1)

    local bRight = fxOverlay:CreateTexture(nil, "BORDER")
    bRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    bRight:SetVertexColor(0.08, 0.07, 0.06, 0.96)
    bRight:SetPoint("TOPRIGHT", container, "TOPRIGHT", 1, 1)
    bRight:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 1, -1)
    bRight:SetWidth(1)

    local hitFlash = fxOverlay:CreateTexture(nil, "OVERLAY", nil, 3)
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
    cutLine.fuiWidth = 4
    cutLine.fuiHeight = defaultH
    local mainFillTexture = mainBar:GetStatusBarTexture()
    if mainFillTexture then
        cutLine:SetPoint("TOP", mainFillTexture, "TOPRIGHT", 0, 3)
        cutLine:SetPoint("BOTTOM", mainFillTexture, "BOTTOMRIGHT", 0, -3)
    end
    cutLine:Hide()

    local executeBorder = CreateBorderFrame(fxOverlay, 1.0, 0.15, 0.15, 2)

    local enhancer = {
        statusBar = statusBar,
        unit = unitToken,
        isNameplate = isNameplate,
        baseWidth = defaultW,
        baseHeight = defaultH,
        container = container,
        bgTex = bgTex,
        trailBar = trailBar,
        mainBar = mainBar,
        fxOverlay = fxOverlay,
        hitFlash = hitFlash,
        cutLine = cutLine,
        executeBorder = executeBorder,
        isSecretHealth = false,
        initializedSecret = false,
        secretCurHp = nil,
        secretMaxHp = nil,
        secretTrailPending = false,
        secretTrailEaseTimer = 0,
        lastHp = nil,
        maxHp = 100,
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
        lastDamagedTime = 0,
        deathTriggered = false,
    }

    self.enhancers[statusBar] = enhancer
    self:RefreshBarColor(enhancer)
    self:RenderEnhancer(enhancer, 0, 0)
    return enhancer
end

function UnitBars:RefreshBarColor(enhancer)
    local r, g, b = GetUnitBarColor(enhancer.unit)
    enhancer.mainBar:SetStatusBarColor(r, g, b, 1.0)
end

function UnitBars:SyncUnitState(enhancer, forceReset)
    if not enhancer then
        return
    end
    self:RefreshBarColor(enhancer)

    local unit = enhancer.unit
    if not unit or not UnitExists(unit) then
        enhancer.isSecretHealth = false
        enhancer.mainBar:SetMinMaxValues(0, 1000)
        enhancer.trailBar:SetMinMaxValues(0, 1000)
        self:RenderEnhancer(enhancer, 0, 0)
        return
    end

    local curHp = UnitHealth(unit)
    local maxHp = UnitHealthMax(unit)
    if curHp == nil or maxHp == nil then
        return
    end

    -- ========================================================================
    -- PATH A: WoW 12.0+ / Forever (16001) Secret Health Values
    -- Pass secret values directly into C++ StatusBar widgets without Lua math!
    -- ========================================================================
    if ns.IsSecret(curHp) or ns.IsSecret(maxHp) then
        enhancer.isSecretHealth = true
        enhancer.secretCurHp = curHp
        enhancer.secretMaxHp = maxHp
        local interpImmediate = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0

        if forceReset or not enhancer.initializedSecret then
            enhancer.initializedSecret = true
            enhancer.trauma = 0
            enhancer.barPunchY = 1.0
            enhancer.flashAlpha = 0
            enhancer.cutAlpha = 0
            enhancer.secretTrailPending = false
            enhancer.secretTrailEaseTimer = 0
            enhancer.mainBar:SetMinMaxValues(0, maxHp)
            enhancer.mainBar:SetValue(curHp, interpImmediate)
            enhancer.trailBar:SetMinMaxValues(0, maxHp)
            enhancer.trailBar:SetValue(curHp, interpImmediate)
            self:RenderEnhancer(enhancer, 0, 0)
            return
        end

        -- Health changed: snap mainBar immediately so cutLine sits at the new HP seam
        -- while trailBar holds the previous HP chunk until trailHoldTimer expires!
        enhancer.mainBar:SetMinMaxValues(0, maxHp)
        enhancer.mainBar:SetValue(curHp, interpImmediate)
        enhancer.trailBar:SetMinMaxValues(0, maxHp)
        enhancer.secretTrailPending = true

        local now = GetTime()
        enhancer.lastDamagedTime = now
        if (now - (enhancer.lastImpactTime or 0)) > 0.06 then
            self:TriggerDamageImpact(enhancer, 0.16, false, false)
        else
            activeAnimEnhancers[enhancer] = true
            EnsureEnhancerTicker()
        end
        return
    end

    -- ========================================================================
    -- PATH B: Plain Lua Number Health Values (e.g. non-secret units / tests)
    -- ========================================================================
    enhancer.isSecretHealth = false
    enhancer.mainBar:SetMinMaxValues(0, 1000)
    enhancer.trailBar:SetMinMaxValues(0, 1000)

    if maxHp <= 0 then
        maxHp = 100
        curHp = 100
    end
    local newFrac = math.max(0.0, math.min(1.0, curHp / maxHp))

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
        enhancer.mainBar:SetValue(math.floor(newFrac * 1000))
        enhancer.trailBar:SetValue(math.floor(newFrac * 1000))
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
        local pctLost = dmg / math.max(1, maxHp)
        local now = GetTime()
        enhancer.lastDamagedTime = now
        if (now - (enhancer.lastImpactTime or 0)) > 0.06 then
            local isHeavy = pctLost >= 0.14
            self:TriggerDamageImpact(enhancer, pctLost, isHeavy, pctLost >= 0.28)
        else
            activeAnimEnhancers[enhancer] = true
            EnsureEnhancerTicker()
        end
    end

    self:UpdateExecuteState(enhancer, newFrac, curHp)
end

function UnitBars:TriggerDamageImpact(enhancer, pctLost, isCrit, isMega)
    local cfg = ns.Config:Get("unitBars")
    if not cfg or not cfg.enabled or not enhancer then
        return
    end

    local now = GetTime()
    enhancer.lastImpactTime = now
    enhancer.lastDamagedTime = now
    enhancer.trailHoldTimer = isCrit and (cfg.trailHoldCrit or 0.38) or (cfg.trailHoldNormal or 0.24)
    enhancer.flashAlpha = isCrit and 0.95 or 0.75
    enhancer.cutAlpha = 1.0

    local mult = isCrit and (cfg.critTraumaMultiplier or 1.75) or 1.10
    local rawTrauma = math.min(1.0, (pctLost / 0.20) * mult * (cfg.traumaScale or 1.0))
    if isCrit and rawTrauma < 0.68 then
        rawTrauma = 0.68
    elseif rawTrauma < 0.35 then
        rawTrauma = 0.35
    end
    enhancer.trauma = math.min(1.0, math.max(enhancer.trauma, rawTrauma))

    local punch = isMega and (cfg.barPunchMega or 1.65)
        or (isCrit and (cfg.barPunchCrit or 1.48) or (cfg.barPunchNormal or 1.24))
    enhancer.barPunchY = math.max(enhancer.barPunchY, punch)

    -- Anchor sparks directly to cutLine (which C++ places at the exact right edge of mainBar!)
    local sparkAnchor = enhancer.cutLine or enhancer.container
    if ns.CombatFX and sparkAnchor then
        if isCrit or pctLost >= 0.10 then
            local count = isMega and 16 or (isCrit and 11 or 6)
            ns.CombatFX:SpawnBarSparks(sparkAnchor, nil, count, 1.0, 0.65, 0.15, false)
        else
            ns.CombatFX:SpawnBarSparks(sparkAnchor, nil, 4, 1.0, 0.82, 0.25, false)
        end
    end

    activeAnimEnhancers[enhancer] = true
    EnsureEnhancerTicker()
end

function UnitBars:UpdateExecuteState(enhancer, frac, curHp)
    if enhancer.isSecretHealth or ns.IsSecret(frac) or ns.IsSecret(curHp) then
        return
    end
    local cfg = ns.Config:Get("unitBars")
    local threshold = (cfg and cfg.executeThreshold) or 0.20
    local shouldExecute = (curHp > 0) and (frac <= threshold)
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

    if enhancer.isSecretHealth then
        if enhancer.trailHoldTimer > 0 then
            enhancer.trailHoldTimer = enhancer.trailHoldTimer - dt
            stillActive = true
        elseif enhancer.secretTrailPending then
            local interpEase = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut or 1
            if enhancer.secretMaxHp ~= nil and enhancer.secretCurHp ~= nil then
                enhancer.trailBar:SetMinMaxValues(0, enhancer.secretMaxHp)
                enhancer.trailBar:SetValue(enhancer.secretCurHp, interpEase)
            end
            enhancer.secretTrailPending = false
            enhancer.secretTrailEaseTimer = 0.35
            stillActive = true
        elseif (enhancer.secretTrailEaseTimer or 0) > 0 then
            enhancer.secretTrailEaseTimer = enhancer.secretTrailEaseTimer - dt
            stillActive = true
        end
    else
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
        local maxOffset = 11.5
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
    if not bar then
        return
    end

    -- Never call bar:GetHeight() on Restricted Regions; use enhancer.baseHeight!
    local h = enhancer.baseHeight or 12
    local punchedH = h * enhancer.barPunchY
    local yPad = (punchedH - h) * 0.5

    local container = enhancer.container
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", bar, "TOPLEFT", dx, yPad + dy)
    container:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", dx, -yPad + dy)

    if not enhancer.isSecretHealth then
        enhancer.mainBar:SetValue(math.floor(enhancer.displayFrac * 1000 + 0.5))
        enhancer.trailBar:SetValue(math.floor(enhancer.trailFrac * 1000 + 0.5))
    end

    if enhancer.trailHoldTimer > 0.12 then
        enhancer.trailBar:SetStatusBarColor(1.0, 0.90, 0.55, 0.98)
    else
        enhancer.trailBar:SetStatusBarColor(1.0, 0.32, 0.08, 0.96)
    end

    local showCut = (enhancer.cutAlpha > 0.01)
    if not enhancer.isSecretHealth then
        showCut = showCut and (enhancer.displayFrac > 0.01 and enhancer.displayFrac < 0.99)
    end
    if showCut then
        enhancer.cutLine:SetAlpha(enhancer.cutAlpha)
        enhancer.cutLine:Show()
    else
        enhancer.cutLine:Hide()
    end

    if enhancer.flashAlpha > 0.01 then
        enhancer.hitFlash:SetAlpha(enhancer.flashAlpha)
        enhancer.hitFlash:Show()
    else
        enhancer.hitFlash:Hide()
    end
end

function UnitBars:OnEnable()
    -- PlayerFrame and TargetFrame portrait bars stay 100% untouched native WoW.
end
