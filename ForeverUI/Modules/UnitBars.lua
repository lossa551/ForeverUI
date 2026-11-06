local addonName, ns = ...
local UnitBars = {}
ns.UnitBars = UnitBars

UnitBars.enhancers = {}
local activeAnimEnhancers = {}

local function GetUnitBarColor(unit, bar)
    if unit and UnitExists(unit) then
        if UnitReaction then
            local reaction = UnitReaction(unit, "player")
            if reaction then
                if reaction <= 3 then
                    return 0.90, 0.12, 0.12 -- Hostile Red
                elseif reaction == 4 then
                    return 0.95, 0.80, 0.10 -- Neutral Yellow
                else
                    return 0.10, 0.85, 0.15 -- Friendly Green
                end
            end
        end
    end
    if bar and bar.GetStatusBarColor then
        local r, g, b = bar:GetStatusBarColor()
        if r and (r > 0.05 or g > 0.05 or b > 0.05) then
            return r, g, b
        end
    end
    return 0.90, 0.12, 0.12
end

local function ReadBarHealth(enhancer)
    local bar = enhancer.statusBar
    local unit = enhancer.unit
    local curHp, maxHp = 0, 0

    if unit and UnitExists(unit) then
        curHp = UnitHealth(unit) or 0
        maxHp = UnitHealthMax(unit) or 0
    end

    if (maxHp <= 0 or (curHp <= 0 and (not unit or not UnitIsDead(unit)))) and bar and bar.GetValue then
        local minV, maxV = bar:GetMinMaxValues()
        local val = bar:GetValue()
        if maxV and maxV > (minV or 0) and val then
            curHp = val - (minV or 0)
            maxHp = maxV - (minV or 0)
        end
    end

    if maxHp <= 0 then
        return 100, 100, 1.0, false
    end

    local isDead = (curHp <= 0) or (unit and UnitIsDead(unit)) or false
    local frac = math.max(0.0, math.min(1.0, curHp / maxHp))
    return curHp, maxHp, frac, isDead
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
    -- Always keep statusBar frame alpha at 1.0 while alive so child frames (container) stay 100% visible!
    statusBar:SetAlpha(1.0)

    if self.enhancers[statusBar] then
        local existing = self.enhancers[statusBar]
        existing.unit = unitToken
        existing.isNameplate = isNameplate
        existing.container:Show()
        existing.container:SetAlpha(1.0)
        self:RefreshBarColor(existing)
        return existing
    end

    -- Parent container directly to statusBar (proven 100% visible in WoW Forever!)
    local baseLevel = math.max(2, (statusBar:GetFrameLevel() or 1) + 2)
    local container = CreateFrame("Frame", nil, statusBar)
    container:SetAllPoints(statusBar)
    container:SetFrameLevel(baseLevel)
    container:EnableMouse(false)

    -- 1. Dark background inside container
    local bgTex = container:CreateTexture(nil, "BACKGROUND", nil, 0)
    bgTex:SetAllPoints(container)
    bgTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    bgTex:SetVertexColor(0.07, 0.07, 0.08, 0.94)

    -- 2. Molten Damage Trail StatusBar (Level + 1, 0..1000 integer range)
    local trailBar = CreateFrame("StatusBar", nil, container)
    trailBar:SetAllPoints(container)
    trailBar:SetFrameLevel(baseLevel + 1)
    trailBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    trailBar:SetStatusBarColor(1.0, 0.65, 0.12, 0.98)
    trailBar:SetMinMaxValues(0, 1000)
    trailBar:SetValue(1000)

    -- 3. Smooth Main Health StatusBar (Level + 2, 0..1000 integer range)
    local mainBar = CreateFrame("StatusBar", nil, container)
    mainBar:SetAllPoints(container)
    mainBar:SetFrameLevel(baseLevel + 2)
    mainBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    mainBar:SetStatusBarColor(0.90, 0.12, 0.12, 1.0)
    mainBar:SetMinMaxValues(0, 1000)
    mainBar:SetValue(1000)
    AddClassicBarBevel(mainBar)

    -- 4. FX Overlay (Level + 3: Border, Hit-Flash, White-Hot Cleavage Cut-Line, <20% Execute Glow)
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
    local mainFillTexture = mainBar:GetStatusBarTexture()
    if mainFillTexture then
        cutLine:SetPoint("TOP", mainFillTexture, "TOPRIGHT", 0, 3)
        cutLine:SetPoint("BOTTOM", mainFillTexture, "BOTTOMRIGHT", 0, -3)
    end
    cutLine:Hide()

    local executeBorder = CreateBorderFrame(fxOverlay, 1.0, 0.15, 0.15, 2)

    local enhancer = {
        statusBar = statusBar,
        container = container,
        bgTex = bgTex,
        trailBar = trailBar,
        mainBar = mainBar,
        fxOverlay = fxOverlay,
        hitFlash = hitFlash,
        cutLine = cutLine,
        executeBorder = executeBorder,
        unit = unitToken,
        isNameplate = isNameplate,
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
    }

    if statusBar.HookScript then
        statusBar:HookScript("OnValueChanged", function()
            if enhancer.unit and UnitExists(enhancer.unit) then
                self:SyncUnitState(enhancer, false)
            end
        end)
        statusBar:HookScript("OnSizeChanged", function()
            self:RenderEnhancer(enhancer, 0, 0)
        end)
    end

    self.enhancers[statusBar] = enhancer
    self:RefreshBarColor(enhancer)
    return enhancer
end

function UnitBars:RefreshBarColor(enhancer)
    local r, g, b = GetUnitBarColor(enhancer.unit, enhancer.statusBar)
    enhancer.mainBar:SetStatusBarColor(r, g, b, 1.0)
end

function UnitBars:SyncUnitState(enhancer, forceReset)
    self:RefreshBarColor(enhancer)

    local curHp, maxHp, newFrac, isDead = ReadBarHealth(enhancer)

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
    local prevMax = enhancer.maxHp or maxHp
    enhancer.lastHp = curHp
    enhancer.maxHp = maxHp
    enhancer.targetFrac = newFrac

    if maxHp ~= prevMax and curHp == maxHp then
        enhancer.displayFrac = newFrac
        enhancer.trailFrac = newFrac
        self:RenderEnhancer(enhancer, 0, 0)
        return
    end

    if curHp < prevHp then
        local dmg = prevHp - curHp
        local pctLost = dmg / math.max(1, maxHp)
        local now = GetTime()
        if (now - (enhancer.lastImpactTime or 0)) > 0.05 then
            local isHeavy = pctLost >= 0.14
            self:TriggerDamageImpact(enhancer, pctLost, isHeavy, pctLost >= 0.28)
            if enhancer.isNameplate and ns.CombatText then
                ns.CombatText:SpawnNumber({
                    text = tostring(math.floor(dmg + 0.5)),
                    r = 1.0,
                    g = isHeavy and 0.82 or 1.0,
                    b = isHeavy and 0.0 or 1.0,
                    isCrit = isHeavy,
                    isMega = pctLost >= 0.28,
                    anchorFrame = enhancer.container,
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

    if isDead and enhancer.isNameplate and ns.Nameplates and not enhancer.deathTriggered then
        ns.Nameplates:TriggerDeathForEnhancer(enhancer)
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
    enhancer.flashAlpha = isCrit and 0.95 or 0.75
    enhancer.cutAlpha = 1.0

    local mult = isCrit and (cfg.critTraumaMultiplier or 1.75) or 1.10
    local rawTrauma = math.min(1.0, (pctLost / 0.20) * mult * (cfg.traumaScale or 1.0))
    if isCrit and rawTrauma < 0.68 then
        rawTrauma = 0.68
    elseif rawTrauma < 0.34 then
        rawTrauma = 0.34
    end
    enhancer.trauma = math.min(1.0, math.max(enhancer.trauma, rawTrauma))

    local punch = isMega and (cfg.barPunchMega or 1.65)
        or (isCrit and (cfg.barPunchCrit or 1.48) or (cfg.barPunchNormal or 1.24))
    enhancer.barPunchY = math.max(enhancer.barPunchY, punch)

    local sparkAnchor = enhancer.container or enhancer.statusBar
    if ns.CombatFX and sparkAnchor then
        if isCrit or pctLost >= 0.10 then
            local count = isMega and 16 or (isCrit and 11 or 6)
            ns.CombatFX:SpawnBarSparks(sparkAnchor, enhancer.targetFrac, count, 1.0, 0.65, 0.15, false)
        else
            ns.CombatFX:SpawnBarSparks(sparkAnchor, enhancer.targetFrac, 4, 1.0, 0.82, 0.25, false)
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
    local h = bar:GetHeight()
    if not h or h <= 0 then
        h = 12
    end

    local container = enhancer.container
    local punchedH = h * enhancer.barPunchY
    local yPad = (punchedH - h) * 0.5

    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", bar, "TOPLEFT", dx, yPad + dy)
    container:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", dx, -yPad + dy)

    -- Hide ONLY the internal StatusBar fill texture (NEVER bar:SetAlpha(0) which hides child frames!)
    local nativeTex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if nativeTex and nativeTex.SetAlpha then
        if enhancer.trauma > 0.01 or enhancer.barPunchY > 1.01 then
            nativeTex:SetAlpha(0.0)
        else
            nativeTex:SetAlpha(1.0)
        end
    end

    enhancer.mainBar:SetValue(math.floor(enhancer.displayFrac * 1000 + 0.5))
    enhancer.trailBar:SetValue(math.floor(enhancer.trailFrac * 1000 + 0.5))

    if enhancer.trailHoldTimer > 0.12 then
        enhancer.trailBar:SetStatusBarColor(1.0, 0.90, 0.55, 0.98)
    else
        enhancer.trailBar:SetStatusBarColor(1.0, 0.32, 0.08, 0.96)
    end

    if enhancer.cutAlpha > 0.01 and enhancer.displayFrac > 0.01 and enhancer.displayFrac < 0.99 then
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
    -- Leave PlayerFrame and TargetFrame portrait bars 100% native WoW!
    -- Overhead enemy health bars are enhanced by Nameplates.lua using UnitBars:CreateBarEnhancer.
end
