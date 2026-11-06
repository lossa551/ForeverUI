local addonName, ns = ...
local UnitBars = {}
ns.UnitBars = UnitBars

UnitBars.enhancers = {}
local activeAnimEnhancers = {}

local function CreateBorderFrame(parent, r, g, b, thickness)
    local border = CreateFrame("Frame", nil, parent)
    border:SetAllPoints(parent)
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
            if not enhancer.statusBar or not enhancer.statusBar:IsVisible() then
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
    if self.enhancers[statusBar] then
        local existing = self.enhancers[statusBar]
        existing.unit = unitToken
        existing.isNameplate = isNameplate
        return existing
    end

    local container = CreateFrame("Frame", nil, statusBar)
    container:SetAllPoints(statusBar)
    container:EnableMouse(false)

    -- Molten damage catch-up trail chunk (spans from displayPct to trailPct)
    local trailTex = container:CreateTexture(nil, "ARTWORK", nil, 2)
    trailTex:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    trailTex:SetVertexColor(1.0, 0.42, 0.10, 0.96)
    trailTex:Hide()

    -- Smooth main health overlay (active during recoil/punch so bar swells cleanly)
    local mainFillTex = container:CreateTexture(nil, "ARTWORK", nil, 3)
    mainFillTex:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    mainFillTex:SetVertexColor(0.0, 0.85, 0.0, 1.0)
    mainFillTex:Hide()

    -- White-hot hit flash overlay
    local hitFlash = container:CreateTexture(nil, "OVERLAY", nil, 3)
    hitFlash:SetTexture("Interface\\Buttons\\WHITE8X8")
    hitFlash:SetBlendMode("ADD")
    hitFlash:SetVertexColor(1.0, 0.95, 0.90, 0.0)
    hitFlash:SetAllPoints(container)
    hitFlash:Hide()

    -- White-hot cleavage slash at the exact HP cut line
    local cutLine = container:CreateTexture(nil, "OVERLAY", nil, 4)
    cutLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    cutLine:SetBlendMode("ADD")
    cutLine:SetVertexColor(1.0, 0.92, 0.75, 0.0)
    cutLine:SetWidth(3)
    cutLine:Hide()

    -- Execute (<20% HP) & Shockwave additive border
    local executeBorder = CreateBorderFrame(container, 1.0, 0.15, 0.15, isNameplate and 2 or 2.5)

    local enhancer = {
        statusBar = statusBar,
        container = container,
        trailTex = trailTex,
        mainFillTex = mainFillTex,
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
        -- Heuristic crit detection if combat log didn't already flag it
        local isHeavy = pctLost >= 0.16
        self:TriggerDamageImpact(enhancer, pctLost, isHeavy)
    elseif curHp > prevHp then
        -- Heal received: subtle vertical bar swell
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

    enhancer.trailHoldTimer = isCrit and (cfg.trailHoldCrit or 0.38) or (cfg.trailHoldNormal or 0.24)
    enhancer.flashAlpha = isCrit and 0.95 or 0.68
    enhancer.cutAlpha = 1.0

    local mult = isCrit and (cfg.critTraumaMultiplier or 1.75) or 0.90
    local rawTrauma = math.min(1.0, (pctLost / 0.26) * mult * (cfg.traumaScale or 1.0))
    if isCrit and rawTrauma < 0.55 then
        rawTrauma = 0.55
    end
    enhancer.trauma = math.min(1.0, math.max(enhancer.trauma, rawTrauma))

    local punch = isMega and (cfg.barPunchMega or 1.65)
        or (isCrit and (cfg.barPunchCrit or 1.48) or (cfg.barPunchNormal or 1.18))
    enhancer.barPunchY = math.max(enhancer.barPunchY, punch)

    -- Spawn shatter sparks at the exact HP cut line on crits or heavy hits
    if ns.CombatFX then
        if isCrit or pctLost >= 0.12 then
            local count = isMega and 16 or (isCrit and 11 or 6)
            ns.CombatFX:SpawnBarSparks(enhancer.statusBar, enhancer.targetFrac, count, 1.0, 0.65, 0.15, false)
        else
            ns.CombatFX:SpawnBarSparks(enhancer.statusBar, enhancer.targetFrac, 3, 1.0, 0.82, 0.25, false)
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

    -- 1. Fast smooth interpolation for main health fraction
    local diffMain = enhancer.targetFrac - enhancer.displayFrac
    if math.abs(diffMain) > 0.001 then
        enhancer.displayFrac = enhancer.displayFrac + diffMain * math.min(1.0, dt * smoothSpeed)
        stillActive = true
    else
        enhancer.displayFrac = enhancer.targetFrac
    end

    -- 2. Delayed molten catch-up trail fraction
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

    -- 3. Hit flash & cleavage cut-line decay
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

    -- 4. Vertical bar scale punch spring back to 1.0
    if math.abs(enhancer.barPunchY - 1.0) > 0.005 then
        enhancer.barPunchY = enhancer.barPunchY + (1.0 - enhancer.barPunchY) * math.min(1.0, dt * 11.0)
        stillActive = true
    else
        enhancer.barPunchY = 1.0
    end

    -- 5. Damped trauma^2 recoil shake
    local dx, dy = 0, 0
    if enhancer.trauma > 0.01 then
        stillActive = true
        local p = enhancer.trauma * enhancer.trauma
        local maxOffset = enhancer.isNameplate and 10.0 or 8.0
        dx = (math.sin(now * 88.0) * maxOffset + (math.random() - 0.5) * 5.0) * p
        dy = (math.cos(now * 96.0) * (maxOffset * 0.65) + (math.random() - 0.5) * 4.0) * p
        enhancer.trauma = math.max(0, enhancer.trauma - dt * 2.35)
    else
        enhancer.trauma = 0
    end

    -- 6. Execute (<20% HP) pulsing crimson glow
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

    -- Show smooth main fill overlay during vertical punch or recoil so the bar visually swells
    if enhancer.barPunchY > 1.01 or enhancer.trauma > 0.01 then
        local r, g, b = bar:GetStatusBarColor()
        enhancer.mainFillTex:SetVertexColor(r or 0, g or 0.85, b or 0, 1.0)
        enhancer.mainFillTex:ClearAllPoints()
        enhancer.mainFillTex:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        enhancer.mainFillTex:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
        enhancer.mainFillTex:SetWidth(mainW)
        enhancer.mainFillTex:Show()
    else
        enhancer.mainFillTex:Hide()
    end

    -- Molten trail chunk spanning from mainW to trailW
    if trailW > mainW + 1.0 then
        local chunkW = trailW - mainW
        -- Shift color from white-hot during hold to molten orange/crimson as it drains
        if enhancer.trailHoldTimer > 0.12 then
            enhancer.trailTex:SetVertexColor(1.0, 0.82, 0.45, 0.98)
        else
            enhancer.trailTex:SetVertexColor(0.96, 0.28, 0.08, 0.95)
        end
        enhancer.trailTex:ClearAllPoints()
        enhancer.trailTex:SetPoint("TOPLEFT", container, "TOPLEFT", mainW, 0)
        enhancer.trailTex:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", mainW, 0)
        enhancer.trailTex:SetWidth(chunkW)
        enhancer.trailTex:Show()
    else
        enhancer.trailTex:Hide()
    end

    -- White-hot cleavage slash at mainW
    if enhancer.cutAlpha > 0.01 and enhancer.displayFrac > 0.01 and enhancer.displayFrac < 0.99 then
        enhancer.cutLine:ClearAllPoints()
        enhancer.cutLine:SetPoint("TOP", container, "TOPLEFT", mainW, 3)
        enhancer.cutLine:SetPoint("BOTTOM", container, "BOTTOMLEFT", mainW, -3)
        enhancer.cutLine:SetAlpha(enhancer.cutAlpha)
        enhancer.cutLine:Show()
    else
        enhancer.cutLine:Hide()
    end

    -- Hit flash overlay
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

    ns.Events:Register("UNIT_HEALTH", function(_, _, unit)
        if unit == "player" and self.playerEnhancer then
            self:SyncUnitState(self.playerEnhancer, false)
        elseif unit == "target" and self.targetEnhancer then
            self:SyncUnitState(self.targetEnhancer, false)
        end
    end, self)

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
