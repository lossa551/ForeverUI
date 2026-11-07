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
    function border:SetBorderColor(cr, cg, cb, ca, blendMode)
        local mode = blendMode or "ADD"
        for i = 1, 4 do
            local edge = self.edges[i]
            edge:SetBlendMode(mode)
            edge:SetVertexColor(cr, cg, cb, ca or 1.0)
        end
    end
    border:SetBorderColor(r or 1, g or 0.2, b or 0.2, 0.9)
    border:Hide()
    return border
end

-- Crisp Golden/White L-Shaped Corner Lock-On Brackets for the Active Target
local function CreateTargetBrackets(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:SetFrameLevel((parent:GetFrameLevel() or 1) + 6)

    local armW = 8
    local armH = 5
    local thick = 2
    local padX = 3
    local padY = 2

    local function MakeSegment(point, relPoint, ox, oy, w, h)
        local tex = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetBlendMode("ADD")
        tex:SetVertexColor(1.0, 0.86, 0.28, 0.96)
        tex:SetPoint(point, frame, relPoint, ox, oy)
        tex:SetSize(w, h)
        return tex
    end

    -- Top-Left L bracket
    MakeSegment("TOPLEFT", "TOPLEFT", -padX, padY, armW, thick)
    MakeSegment("TOPLEFT", "TOPLEFT", -padX, padY, thick, armH)
    -- Top-Right L bracket
    MakeSegment("TOPRIGHT", "TOPRIGHT", padX, padY, armW, thick)
    MakeSegment("TOPRIGHT", "TOPRIGHT", padX, padY, thick, armH)
    -- Bottom-Left L bracket
    MakeSegment("BOTTOMLEFT", "BOTTOMLEFT", -padX, -padY, armW, thick)
    MakeSegment("BOTTOMLEFT", "BOTTOMLEFT", -padX, -padY, thick, armH)
    -- Bottom-Right L bracket
    MakeSegment("BOTTOMRIGHT", "BOTTOMRIGHT", padX, -padY, armW, thick)
    MakeSegment("BOTTOMRIGHT", "BOTTOMRIGHT", padX, -padY, thick, armH)

    frame:Hide()
    return frame
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
                enhancer.elemGlowTimer = 0
                enhancer.barPunchY = 1.0
                if enhancer.elemBorder then
                    enhancer.elemBorder:Hide()
                end
                if enhancer.hitFlash then
                    enhancer.hitFlash:Hide()
                end
                if enhancer.cutLine then
                    enhancer.cutLine:Hide()
                end
                activeAnimEnhancers[enhancer] = nil
            else
                local stillAnimating = UnitBars:StepEnhancer(enhancer, dt, now, smoothSpeed, trailSpeed)
                if stillAnimating then
                    anyActive = true
                else
                    if enhancer.elemBorder then
                        enhancer.elemBorder:Hide()
                    end
                    if enhancer.hitFlash then
                        enhancer.hitFlash:Hide()
                    end
                    if enhancer.cutLine then
                        enhancer.cutLine:Hide()
                    end
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

    -- Steady, non-shaking wound seam tracker anchored directly to statusBar (NOT container)
    -- so floating damage numbers erupt at the exact HP cut seam WITHOUT inheriting bar vibration!
    local steadyWoundBar = CreateFrame("StatusBar", nil, statusBar)
    steadyWoundBar:SetAllPoints(statusBar)
    steadyWoundBar:SetFrameLevel(baseLevel)
    steadyWoundBar:EnableMouse(false)
    steadyWoundBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    steadyWoundBar:SetStatusBarColor(1.0, 1.0, 1.0, 0.0)
    steadyWoundBar:SetMinMaxValues(0, 1000)
    steadyWoundBar:SetValue(1000)
    local steadyWoundAnchor = steadyWoundBar:GetStatusBarTexture()

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

    local mainFillTexture = mainBar:GetStatusBarTexture()
    local trailFillTexture = trailBar:GetStatusBarTexture()

    -- Remaining-Health Fill Overlay: anchored to mainFillTexture (for active DoT burn/crackle)
    local fillOverlay = CreateFrame("Frame", nil, fxOverlay)
    fillOverlay:SetFrameLevel(baseLevel + 4)
    if mainFillTexture then
        fillOverlay:SetPoint("TOPLEFT", mainFillTexture, "TOPLEFT", 0, 0)
        fillOverlay:SetPoint("BOTTOMRIGHT", mainFillTexture, "BOTTOMRIGHT", 0, 0)
    else
        fillOverlay:SetAllPoints(fxOverlay)
    end
    fillOverlay.fuiWidth = defaultW
    fillOverlay.fuiHeight = defaultH

    -- Fading/Damaged Health Chunk Overlay: spans STRICTLY between mainFillTexture's right edge
    -- and trailFillTexture's right edge so the lost HP chunk turns into embers/sparks/rubble/shards!
    local trailChunkOverlay = CreateFrame("Frame", nil, fxOverlay)
    trailChunkOverlay:SetFrameLevel(baseLevel + 5)
    if mainFillTexture and trailFillTexture then
        trailChunkOverlay:SetPoint("TOPLEFT", mainFillTexture, "TOPRIGHT", 0, 0)
        trailChunkOverlay:SetPoint("BOTTOMRIGHT", trailFillTexture, "BOTTOMRIGHT", 0, 0)
    else
        trailChunkOverlay:SetAllPoints(fxOverlay)
    end
    trailChunkOverlay.fuiWidth = 18
    trailChunkOverlay.fuiHeight = defaultH

    local trailFragments = {}
    for i = 1, 8 do
        local frag = trailChunkOverlay:CreateTexture(nil, "OVERLAY", nil, 4)
        frag:SetTexture("Interface\\Buttons\\WHITE8X8")
        frag:SetBlendMode("ADD")
        frag:SetSize(4, 4)
        frag:Hide()
        trailFragments[i] = {
            tex = frag,
            u = (i - 0.5) / 8 - 0.5,
            v = ((i % 2 == 0) and 0.22 or -0.22),
            vx = 0,
            vy = 0,
            sizeW = 4,
            sizeH = 4,
            isAlt = (i % 3 == 0),
        }
    end

    local hitFlash = fillOverlay:CreateTexture(nil, "OVERLAY", nil, 3)
    hitFlash:SetTexture("Interface\\Buttons\\WHITE8X8")
    hitFlash:SetBlendMode("ADD")
    hitFlash:SetVertexColor(1.0, 0.95, 0.85, 0.0)
    hitFlash:SetAllPoints(fillOverlay)
    hitFlash:Hide()

    local cutLine = fxOverlay:CreateTexture(nil, "OVERLAY", nil, 6)
    cutLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    cutLine:SetBlendMode("ADD")
    cutLine:SetVertexColor(1.0, 0.95, 0.80, 0.0)
    cutLine:SetWidth(3.5)
    cutLine.fuiWidth = 4
    cutLine.fuiHeight = defaultH
    if mainFillTexture then
        cutLine:SetPoint("TOP", mainFillTexture, "TOPRIGHT", 0, 3)
        cutLine:SetPoint("BOTTOM", mainFillTexture, "BOTTOMRIGHT", 0, -3)
    end
    cutLine:Hide()

    local executeBorder = CreateBorderFrame(fxOverlay, 1.0, 0.15, 0.15, 2)
    local elemBorder = CreateBorderFrame(fillOverlay, 1.0, 0.50, 0.10, 2)
    local targetBrackets = CreateTargetBrackets(fxOverlay)

    local enhancer = {
        statusBar = statusBar,
        unit = unitToken,
        isNameplate = isNameplate,
        isTarget = false,
        baseWidth = defaultW,
        baseHeight = defaultH,
        container = container,
        bgTex = bgTex,
        trailBar = trailBar,
        mainBar = mainBar,
        steadyWoundBar = steadyWoundBar,
        steadyWoundAnchor = steadyWoundAnchor,
        fxOverlay = fxOverlay,
        fillOverlay = fillOverlay,
        trailChunkOverlay = trailChunkOverlay,
        trailFragments = trailFragments,
        hitFlash = hitFlash,
        cutLine = cutLine,
        executeBorder = executeBorder,
        elemBorder = elemBorder,
        targetBrackets = targetBrackets,
        isSecretHealth = false,
        initializedSecret = false,
        estimatedSecretFrac = 1.0,
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
        trailDissolveTimer = 0,
        trailDissolveDuration = 0.55,
        trailEmitTimer = 0,
        lastDmgFrac = 0.10,
        flashAlpha = 0,
        flashR = 1.0,
        flashG = 0.95,
        flashB = 0.85,
        cutAlpha = 0,
        trauma = 0,
        barPunchY = 1.0,
        activeElement = "PHYSICAL",
        lastElement = "PHYSICAL",
        elemGlowTimer = 0,
        elemGlowDuration = 0.25,
        trailHoldColor = { 1.00, 0.90, 0.55 },
        trailFadeColor = { 1.00, 0.32, 0.08 },
        isExecute = false,
        lastImpactTime = 0,
        lastDamagedTime = 0,
        lastInterruptTime = 0,
        deathTriggered = false,
    }

    self.enhancers[statusBar] = enhancer
    self:RefreshBarColor(enhancer)
    self:RenderEnhancer(enhancer, 0, 0)
    return enhancer
end

function UnitBars:SetTargetState(enhancer, isTarget, hasAnyTarget, playPop)
    if not enhancer or enhancer.deathTriggered then
        return
    end
    local npCfg = ns.Config:Get("nameplates")
    local highlightEnabled = not npCfg or (npCfg.targetHighlight ~= false)
    enhancer.isTarget = isTarget and highlightEnabled

    if enhancer.isNameplate then
        if enhancer.isTarget then
            enhancer.baseHeight = 14
            enhancer.targetBrackets:Show()
            enhancer.container:SetAlpha(1.0)
            if playPop then
                enhancer.barPunchY = math.max(enhancer.barPunchY, 1.28)
                enhancer.flashR, enhancer.flashG, enhancer.flashB = 1.0, 0.95, 0.75
                enhancer.flashAlpha = math.max(enhancer.flashAlpha, 0.45)
                activeAnimEnhancers[enhancer] = true
                EnsureEnhancerTicker()
            end
        else
            enhancer.baseHeight = 11
            enhancer.targetBrackets:Hide()
            -- Subtly dim untargeted mobs (86%) when a target is selected so your target pops out!
            enhancer.container:SetAlpha(hasAnyTarget and 0.86 or 1.0)
        end
    end

    self:RenderEnhancer(enhancer, 0, 0)
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
            enhancer.estimatedSecretFrac = 1.0
            enhancer.trauma = 0
            enhancer.barPunchY = 1.0
            enhancer.flashAlpha = 0
            enhancer.cutAlpha = 0
            enhancer.elemGlowTimer = 0
            if enhancer.elemBorder then
                enhancer.elemBorder:Hide()
            end
            if enhancer.fillOverlay then
                enhancer.fillOverlay.fuiWidth = enhancer.baseWidth or 118
                enhancer.fillOverlay.fuiHeight = enhancer.baseHeight or 12
            end
            enhancer.secretTrailPending = false
            enhancer.secretTrailEaseTimer = 0
            enhancer.mainBar:SetMinMaxValues(0, maxHp)
            enhancer.mainBar:SetValue(curHp, interpImmediate)
            enhancer.trailBar:SetMinMaxValues(0, maxHp)
            enhancer.trailBar:SetValue(curHp, interpImmediate)
            if enhancer.steadyWoundBar then
                enhancer.steadyWoundBar:SetMinMaxValues(0, maxHp)
                enhancer.steadyWoundBar:SetValue(curHp, interpImmediate)
            end
            self:RenderEnhancer(enhancer, 0, 0)
            return
        end

        enhancer.mainBar:SetMinMaxValues(0, maxHp)
        enhancer.mainBar:SetValue(curHp, interpImmediate)
        enhancer.trailBar:SetMinMaxValues(0, maxHp)
        if enhancer.steadyWoundBar then
            enhancer.steadyWoundBar:SetMinMaxValues(0, maxHp)
            enhancer.steadyWoundBar:SetValue(curHp, interpImmediate)
        end
        enhancer.secretTrailPending = true
        if (enhancer.trailHoldTimer or 0) <= 0 then
            enhancer.trailHoldTimer = 0.08
        end
        activeAnimEnhancers[enhancer] = true
        EnsureEnhancerTicker()
        return
    end

    -- ========================================================================
    -- PATH B: Plain Lua Number Health Values (e.g. non-secret units / tests)
    -- ========================================================================
    enhancer.isSecretHealth = false
    enhancer.mainBar:SetMinMaxValues(0, 1000)
    enhancer.trailBar:SetMinMaxValues(0, 1000)
    if enhancer.steadyWoundBar then
        enhancer.steadyWoundBar:SetMinMaxValues(0, 1000)
    end

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
        enhancer.elemGlowTimer = 0
        if enhancer.elemBorder then
            enhancer.elemBorder:Hide()
        end
        enhancer.mainBar:SetValue(math.floor(newFrac * 1000))
        enhancer.trailBar:SetValue(math.floor(newFrac * 1000))
        if enhancer.steadyWoundBar then
            enhancer.steadyWoundBar:SetValue(math.floor(newFrac * 1000))
        end
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
        if (now - (enhancer.lastImpactTime or 0)) > 0.28 then
            local isHeavy = pctLost >= 0.14
            self:TriggerDamageImpact(enhancer, pctLost, isHeavy, pctLost >= 0.28)
        else
            activeAnimEnhancers[enhancer] = true
            EnsureEnhancerTicker()
        end
    end

    self:UpdateExecuteState(enhancer, newFrac, curHp)
end

function UnitBars:TriggerDamageImpact(enhancer, pctLost, isCrit, isMega, elementKey, hitWeight, isDot)
    local cfg = ns.Config:Get("unitBars")
    if not cfg or not cfg.enabled or not enhancer then
        return
    end

    local elem = elementKey
    if not elem and ns.Elements then
        elem = ns.Elements:ResolveElement(nil, nil, false)
    end
    local prof = (ns.Elements and ns.Elements:GetProfile(elem)) or nil
    local resolvedKey = (prof and prof.key) or "PHYSICAL"

    -- Combine actual damage hitWeight (0.12 DoT, ~0.22 light white hit, ~0.95 heavy ability hit)
    -- with percentage HP lost so higher damage ALWAYS shakes and punches the bar much harder!
    local dmgFrac = math.max(0.01, pctLost or 0.08)
    local pctWeight = math.max(0.14, math.min(1.0, (dmgFrac - 0.02) / 0.16))
    local weight = hitWeight and math.max(hitWeight, pctWeight * 0.85) or pctWeight

    local intensity
    if isDot then
        intensity = 0.16
    elseif isMega then
        intensity = 1.00
    elseif isCrit then
        intensity = math.min(1.00, 0.82 + 0.18 * weight)
    else
        -- Continuous normal-hit scaling:
        -- Light hit (11 dmg, weight ~0.22) -> ~0.30 intensity (~2.0px shake)
        -- Medium hit (18 dmg, weight ~0.55) -> ~0.55 intensity (~4.9px shake)
        -- Heavy hit (25+ dmg, weight ~0.95) -> ~0.85 intensity (~8.9px shake)
        intensity = math.max(0.20, math.min(0.88, 0.14 + 0.74 * weight))
    end

    local now = GetTime()
    local recentImpact = (now - (enhancer.lastImpactTime or 0)) <= 0.25
    enhancer.lastImpactTime = now
    enhancer.lastDamagedTime = now
    enhancer.activeElement = resolvedKey
    enhancer.lastElement = resolvedKey
    enhancer.elemIntensity = recentImpact and math.max(enhancer.elemIntensity or 0, intensity) or intensity

    local baseGlowDur = (prof and prof.glowDuration) or 0.25
    local newGlowDur = baseGlowDur * (0.38 + 0.62 * enhancer.elemIntensity)
    enhancer.elemGlowDuration = recentImpact and math.max(enhancer.elemGlowDuration or 0, newGlowDur) or newGlowDur
    enhancer.elemGlowTimer = math.max(enhancer.elemGlowTimer or 0, newGlowDur)

    local holdTime = isCrit
        and ((prof and prof.trailHoldCrit) or (cfg.trailHoldCrit or 0.38))
        or ((prof and prof.trailHoldNormal) or (cfg.trailHoldNormal or 0.24))
    enhancer.trailHoldTimer = math.max(enhancer.trailHoldTimer or 0, holdTime * (0.85 + 0.35 * intensity))
    local newDissolveDur = (isCrit and 0.72 or 0.54) * (0.72 + 0.28 * intensity)
    enhancer.trailDissolveDuration = math.max(enhancer.trailDissolveDuration or 0, newDissolveDur)
    enhancer.trailDissolveTimer = math.max(enhancer.trailDissolveTimer or 0, newDissolveDur)
    enhancer.trailEmitTimer = 0.08
    enhancer.lastDmgFrac = dmgFrac

    local elemBlend = (resolvedKey == "EARTH") and "BLEND" or "ADD"
    if enhancer.hitFlash then
        enhancer.hitFlash:SetBlendMode(elemBlend)
    end

    if prof then
        enhancer.flashR, enhancer.flashG, enhancer.flashB = prof.flash[1], prof.flash[2], prof.flash[3]
        enhancer.trailHoldColor = prof.trailHold
        enhancer.trailFadeColor = prof.trailFade
        if enhancer.cutLine then
            enhancer.cutLine:SetVertexColor(prof.cut[1], prof.cut[2], prof.cut[3], 1.0)
        end
        if enhancer.elemBorder and prof.border then
            enhancer.elemBorder:SetBorderColor(prof.border[1], prof.border[2], prof.border[3], 0.95 * enhancer.elemIntensity, elemBlend)
            -- Show full outer elemental border rim on medium-to-heavy hits (intensity >= 0.42)
            if resolvedKey ~= "PHYSICAL" and enhancer.elemIntensity >= 0.42 then
                enhancer.elemBorder:Show()
            elseif not recentImpact then
                enhancer.elemBorder:Hide()
            end
        end
    else
        enhancer.flashR, enhancer.flashG, enhancer.flashB = 1.0, 0.95, 0.85
    end

    -- Keep remaining-health flash subtle so the elemental disintegration stands out on the FADING health chunk!
    local newFlash = isCrit and 0.36 or (0.10 + 0.20 * intensity)
    enhancer.flashAlpha = math.max(enhancer.flashAlpha or 0, newFlash)
    enhancer.cutAlpha = math.max(enhancer.cutAlpha or 0, 0.55 + 0.45 * intensity)

    local traumaScale = cfg.traumaScale or 1.0
    local rawTrauma
    if isDot then
        rawTrauma = 0.18 * traumaScale
    elseif isMega then
        rawTrauma = 1.28 * traumaScale
    elseif isCrit then
        rawTrauma = (1.02 + 0.20 * weight) * traumaScale
    else
        rawTrauma = intensity * traumaScale
    end
    if not isDot then
        if resolvedKey == "EARTH" then
            rawTrauma = rawTrauma * 1.14
        elseif resolvedKey == "LIGHTNING" then
            rawTrauma = rawTrauma * 1.10
        end
    end
    enhancer.trauma = math.min(1.38, math.max(enhancer.trauma or 0, rawTrauma))

    local normalPunchMax = (prof and prof.punchNormal) or (cfg.barPunchNormal or 1.24)
    local critPunchMax = (prof and prof.punchCrit) or (cfg.barPunchCrit or 1.48)
    local megaPunchMax = (prof and prof.punchMega) or (cfg.barPunchMega or 1.65)
    local scaledPunch
    if isDot then
        scaledPunch = 1.04
    elseif isMega then
        scaledPunch = megaPunchMax
    elseif isCrit then
        scaledPunch = critPunchMax + (megaPunchMax - critPunchMax) * 0.45 * weight
    else
        -- Heavy normal hits (weight ~0.95) punch up toward the bottom of critPunchMax!
        local heavyTarget = normalPunchMax + (critPunchMax - normalPunchMax) * 0.48
        scaledPunch = 1.0 + (heavyTarget - 1.0) * math.pow(intensity, 1.18)
    end
    enhancer.barPunchY = math.max(enhancer.barPunchY or 1.0, scaledPunch)

    -- Snap mainBar immediately to targetFrac so the damaged/fading health gap (trailChunkOverlay) is exposed right away!
    if not enhancer.isSecretHealth then
        enhancer.displayFrac = enhancer.targetFrac
        local val = math.floor(enhancer.displayFrac * 1000 + 0.5)
        enhancer.mainBar:SetValue(val)
        enhancer.trailBar:SetValue(math.floor(enhancer.trailFrac * 1000 + 0.5))
        if enhancer.steadyWoundBar then
            enhancer.steadyWoundBar:SetValue(val)
        end
    end

    -- Register ticker BEFORE spawning FX so bar state cleanup is 100% guaranteed
    activeAnimEnhancers[enhancer] = true
    EnsureEnhancerTicker()

    local baseW = enhancer.baseWidth or 118
    local baseH = enhancer.baseHeight or 12

    local fillAnchor = enhancer.fillOverlay or enhancer.container
    if enhancer.fillOverlay then
        local remFrac
        if enhancer.isSecretHealth then
            enhancer.estimatedSecretFrac = math.max(0.18, (enhancer.estimatedSecretFrac or 1.0) - math.min(0.22, dmgFrac * 0.75))
            remFrac = enhancer.estimatedSecretFrac
        else
            remFrac = math.max(0.08, math.min(1.0, enhancer.displayFrac or 1.0))
        end
        enhancer.fillOverlay.fuiWidth = math.max(14, baseW * remFrac)
        enhancer.fillOverlay.fuiHeight = baseH
    end

    -- Size trailChunkOverlay to the FADING / DAMAGED part of the life (between mainBar and trailBar)
    local trailAnchor = enhancer.trailChunkOverlay or enhancer.cutLine or fillAnchor
    local lostFrac = dmgFrac
    if not enhancer.isSecretHealth then
        lostFrac = math.max(dmgFrac, (enhancer.trailFrac or 1.0) - (enhancer.displayFrac or 1.0))
    end
    local chunkW = math.max(8, baseW * math.max(0.05, lostFrac))
    if enhancer.trailChunkOverlay then
        enhancer.trailChunkOverlay.fuiWidth = chunkW
        enhancer.trailChunkOverlay.fuiHeight = baseH
    end

    -- Seed the 8 disintegrating elemental fragments inside trailChunkOverlay
    if enhancer.trailFragments then
        local n = #enhancer.trailFragments
        for i = 1, n do
            local f = enhancer.trailFragments[i]
            f.u = ((i - 0.5) / n - 0.5) * 0.88 + (math.random() - 0.5) * 0.08
            f.v = (math.random() - 0.5) * 0.65
            f.vx = (math.random() - 0.5) * 14
            if resolvedKey == "FIRE" then
                f.vy = 14 + math.random() * 20
                f.sizeW = 3.0 + math.random() * 2.5
                f.sizeH = 3.0 + math.random() * 2.5
            elseif resolvedKey == "EARTH" then
                f.vy = -(16 + math.random() * 22)
                f.sizeW = 4.2 + math.random() * 3.0
                f.sizeH = 3.4 + math.random() * 2.4
            elseif resolvedKey == "FROST" then
                f.vy = -(12 + math.random() * 18)
                f.sizeW = 4.5 + math.random() * 2.5
                f.sizeH = 2.2 + math.random() * 1.4
            elseif resolvedKey == "SHADOW" then
                f.vy = 8 + math.random() * 14
                f.sizeW = 3.8 + math.random() * 2.6
                f.sizeH = 3.8 + math.random() * 2.6
            else
                f.vy = (math.random() - 0.5) * 20
                f.sizeW = 3.5 + math.random() * 2.0
                f.sizeH = 2.2 + math.random() * 1.5
            end
        end
    end

    if ns.CombatFX and trailAnchor then
        local spR = (prof and prof.spark and prof.spark[1]) or 1.0
        local spG = (prof and prof.spark and prof.spark[2]) or 0.72
        local spB = (prof and prof.spark and prof.spark[3]) or 0.18
        local baseCount = math.max(3, math.floor(3 + intensity * (isMega and 16 or (isCrit and 12 or 8)) + 0.5))

        if resolvedKey == "LIGHTNING" then
            local boltCount = isMega and 2 or (isCrit and 2 or 1)
            local boltDur = (isCrit and 0.26 or 0.16) * (0.65 + 0.35 * intensity)
            ns.CombatFX:SpawnBarLightning(trailAnchor, boltCount, boltDur, intensity)
            ns.CombatFX:SpawnBarSparks(trailAnchor, nil, math.max(3, baseCount), spR, spG, spB, false, "LIGHTNING", intensity)
        elseif resolvedKey == "FIRE" then
            ns.CombatFX:SpawnBarSparks(trailAnchor, nil, baseCount + math.floor(intensity * 6), spR, spG, spB, false, "FIRE", intensity)
        elseif resolvedKey == "EARTH" then
            if intensity >= 0.30 and ns.CombatFX.SpawnBarEarthCracks then
                local crackCount = isMega and 3 or (isCrit and 3 or (intensity >= 0.55 and 2 or 1))
                local crackDur = (isCrit and 0.42 or 0.30) * (0.70 + 0.30 * intensity)
                ns.CombatFX:SpawnBarEarthCracks(trailAnchor, crackCount, crackDur, intensity)
            end
            ns.CombatFX:SpawnBarSparks(trailAnchor, nil, baseCount + math.floor(intensity * 4), spR, spG, spB, true, "EARTH", intensity)
        elseif resolvedKey == "FROST" then
            ns.CombatFX:SpawnBarSparks(trailAnchor, nil, baseCount + math.floor(intensity * 3), spR, spG, spB, false, "FROST", intensity)
        elseif resolvedKey == "SHADOW" then
            ns.CombatFX:SpawnBarSparks(trailAnchor, nil, baseCount + math.floor(intensity * 3), spR, spG, spB, false, "SHADOW", intensity)
        else
            ns.CombatFX:SpawnBarSparks(trailAnchor, nil, baseCount, spR, spG, spB, false, "PHYSICAL", intensity)
        end
    end

    -- Apply immediate Frame-0 impact kick so the bar jolts on the exact millisecond of impact!
    local p0 = math.pow(enhancer.trauma, 1.45)
    local kickDir = (math.random() > 0.5) and 1 or -1
    local initDx = kickDir * 7.5 * p0
    local initDy = ((resolvedKey == "EARTH") and -6.5 or 3.5) * p0
    self:RenderEnhancer(enhancer, initDx, initDy)
end

-- Metallic glint jolt when an attack is Parried, Dodged, Blocked, or Immune
function UnitBars:TriggerDeflectImpact(enhancer)
    if not enhancer then
        return
    end
    enhancer.flashR, enhancer.flashG, enhancer.flashB = 0.85, 0.92, 1.0
    enhancer.flashAlpha = math.max(enhancer.flashAlpha, 0.65)
    enhancer.barPunchY = math.max(enhancer.barPunchY, 1.18)
    enhancer.trauma = math.max(enhancer.trauma, 0.34)

    if ns.CombatFX and enhancer.container then
        ns.CombatFX:SpawnBarSparks(enhancer.container, 0.5, 7, 0.82, 0.92, 1.0, false)
    end

    activeAnimEnhancers[enhancer] = true
    EnsureEnhancerTicker()
end

-- Electric cyan shatter jolt when an enemy spellcast is Interrupted!
function UnitBars:TriggerInterruptImpact(enhancer)
    if not enhancer then
        return
    end
    enhancer.flashR, enhancer.flashG, enhancer.flashB = 0.25, 0.95, 1.0
    enhancer.flashAlpha = 0.98
    enhancer.barPunchY = math.max(enhancer.barPunchY, 1.55)
    enhancer.trauma = math.max(enhancer.trauma, 0.85)

    if ns.CombatFX and enhancer.container then
        ns.CombatFX:SpawnBarSparks(enhancer.container, 0.5, 16, 0.22, 0.92, 1.0, false)
    end

    activeAnimEnhancers[enhancer] = true
    EnsureEnhancerTicker()
end

function UnitBars:SetDotState(enhancer, elementKey, duration)
    if not enhancer then
        return
    end
    if not elementKey or (duration or 0) <= 0 then
        enhancer.dotElement = nil
        enhancer.dotTimer = 0
        enhancer.dotDuration = 0
        return
    end
    local resolvedKey = elementKey or "FIRE"
    enhancer.dotElement = resolvedKey
    enhancer.dotDuration = math.max(enhancer.dotDuration or 0, duration)
    enhancer.dotTimer = duration
    enhancer.dotEmitTimer = 0
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
            elseif (enhancer.trailDissolveTimer or 0) <= 0.14 then
                local diffTrail = enhancer.displayFrac - enhancer.trailFrac
                enhancer.trailFrac = enhancer.trailFrac + diffTrail * math.min(1.0, dt * (trailSpeed * 1.6))
            end
        else
            enhancer.trailFrac = enhancer.displayFrac
        end
    end

    -- Elemental Disintegration of the Fading/Damaged Health Chunk (turns into embers, sparks, rubble, shards!)
    local elem = enhancer.activeElement or "PHYSICAL"
    if (enhancer.trailDissolveTimer or 0) > 0.01 then
        enhancer.trailDissolveTimer = math.max(0, enhancer.trailDissolveTimer - dt)
        stillActive = true
        enhancer.trailEmitTimer = (enhancer.trailEmitTimer or 0) - dt
        if enhancer.trailEmitTimer <= 0 and enhancer.trailDissolveTimer > 0.12 then
            local trailAnchor = enhancer.trailChunkOverlay or enhancer.cutLine
            local prof = ns.Elements and ns.Elements:GetProfile(elem)
            local elemInt = enhancer.elemIntensity or 0.6
            local remFrac = enhancer.trailDissolveTimer / math.max(0.1, enhancer.trailDissolveDuration or 0.55)
            if ns.CombatFX and trailAnchor and prof then
                local spR = (prof.spark and prof.spark[1]) or 1.0
                local spG = (prof.spark and prof.spark[2]) or 0.6
                local spB = (prof.spark and prof.spark[3]) or 0.1
                if elem == "FIRE" then
                    enhancer.trailEmitTimer = 0.09
                    ns.CombatFX:SpawnBarSparks(trailAnchor, nil, 3, spR, spG, spB, false, "FIRE", elemInt * remFrac)
                elseif elem == "LIGHTNING" then
                    enhancer.trailEmitTimer = 0.13
                    ns.CombatFX:SpawnBarLightning(trailAnchor, 1, 0.11, elemInt * remFrac)
                    ns.CombatFX:SpawnBarSparks(trailAnchor, nil, 2, spR, spG, spB, false, "LIGHTNING", elemInt * remFrac)
                elseif elem == "EARTH" then
                    enhancer.trailEmitTimer = 0.11
                    ns.CombatFX:SpawnBarSparks(trailAnchor, nil, 2, spR, spG, spB, true, "EARTH", elemInt * remFrac)
                elseif elem == "FROST" then
                    enhancer.trailEmitTimer = 0.11
                    ns.CombatFX:SpawnBarSparks(trailAnchor, nil, 2, spR, spG, spB, false, "FROST", elemInt * remFrac)
                elseif elem == "SHADOW" then
                    enhancer.trailEmitTimer = 0.10
                    ns.CombatFX:SpawnBarSparks(trailAnchor, nil, 2, spR, spG, spB, false, "SHADOW", elemInt * remFrac)
                else
                    enhancer.trailEmitTimer = 0.12
                    ns.CombatFX:SpawnBarSparks(trailAnchor, nil, 2, spR, spG, spB, false, "PHYSICAL", elemInt * remFrac)
                end
            end
        end
    else
        enhancer.trailDissolveTimer = 0
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
        local punchRecover = (enhancer.activeElement == "EARTH") and 8.5 or 11.0
        enhancer.barPunchY = enhancer.barPunchY + (1.0 - enhancer.barPunchY) * math.min(1.0, dt * punchRecover)
        stillActive = true
    else
        enhancer.barPunchY = 1.0
    end

    local dx, dy = 0, 0
    if enhancer.trauma > 0.01 then
        stillActive = true
        -- Power 1.45 curve preserves a crisp ~2px nudge on light hits while scaling up to
        -- ~9px on heavy normal hits (25 dmg) and ~14-17px on Crits & Mega Crits!
        local p = math.pow(enhancer.trauma, 1.45)
        local maxOffset = 11.8
        if elem == "LIGHTNING" then
            -- High-voltage staccato electric crackle snap
            dx = (math.sin(now * 175.0) * (maxOffset * 1.25) + (math.random() - 0.5) * 9.0) * p
            dy = (math.cos(now * 190.0) * (maxOffset * 0.70) + (math.random() - 0.5) * 6.0) * p
        elseif elem == "EARTH" then
            -- Heavy low-frequency vertical ground-slam seismic thud
            dx = (math.sin(now * 58.0) * (maxOffset * 0.75) + (math.random() - 0.5) * 4.0) * p
            dy = (math.cos(now * 52.0) * (maxOffset * 1.45) + (math.random() - 0.5) * 6.0) * p
        elseif elem == "SHADOW" then
            -- Deep warping void dread wave
            dx = math.sin(now * 62.0) * (maxOffset * 0.95) * p
            dy = math.cos(now * 48.0) * (maxOffset * 0.75) * p
        else
            dx = (math.sin(now * 88.0) * maxOffset + (math.random() - 0.5) * 6.0) * p
            dy = (math.cos(now * 96.0) * (maxOffset * 0.65) + (math.random() - 0.5) * 4.5) * p
        end
        local decayRate = (enhancer.trauma < 0.36) and 2.55 or 2.10
        enhancer.trauma = math.max(0, enhancer.trauma - dt * decayRate)
    else
        enhancer.trauma = 0
    end

    -- Elemental Border Glow & Fire Heat Shimmer (scaled by hit intensity!)
    local borderShown = false
    local bestBorderAlpha = 0
    local bestBorderProf = nil
    local bestBorderElem = elem

    if (enhancer.elemGlowTimer or 0) > 0.01 then
        enhancer.elemGlowTimer = math.max(0, enhancer.elemGlowTimer - dt)
        stillActive = true
        local glowFrac = enhancer.elemGlowTimer / math.max(0.1, enhancer.elemGlowDuration or 0.4)
        local elemInt = enhancer.elemIntensity or 0.5
        local prof = ns.Elements and ns.Elements:GetProfile(elem)
        if elem == "FIRE" then
            enhancer.flashAlpha = math.max(enhancer.flashAlpha, glowFrac * 0.38 * elemInt)
        end
        if prof and prof.border and elem ~= "PHYSICAL" and elemInt >= 0.42 then
            local flicker = 1.0
            if elem == "FIRE" then
                flicker = 0.68 + 0.32 * math.sin(now * 28.0)
            elseif elem == "LIGHTNING" then
                flicker = (math.sin(now * 95.0) > 0) and 1.0 or 0.45
            elseif elem == "SHADOW" then
                flicker = 0.65 + 0.35 * math.sin(now * 18.0)
            end
            bestBorderAlpha = math.min(1.0, glowFrac * flicker * elemInt)
            bestBorderProf = prof
            bestBorderElem = elem
            borderShown = true
        end
    else
        enhancer.elemGlowTimer = 0
    end

    -- Continuous Elemental DoT Burning / Crackling / Chilling / Corrupting over Remaining Health
    if (enhancer.dotTimer or 0) > 0.01 and not enhancer.deathTriggered then
        enhancer.dotTimer = math.max(0, enhancer.dotTimer - dt)
        stillActive = true
        local dotElem = enhancer.dotElement or "FIRE"
        local dotProf = ns.Elements and ns.Elements:GetProfile(dotElem)
        local dotFade = math.min(1.0, enhancer.dotTimer / 0.60)
        local fillAnchor = enhancer.fillOverlay or enhancer.container

        if dotProf then
            local dotBorderAlpha = 0
            if dotElem == "FIRE" then
                local smolderAlpha = (0.11 + 0.07 * math.sin(now * 12.0)) * dotFade
                if enhancer.flashAlpha < smolderAlpha then
                    enhancer.flashR, enhancer.flashG, enhancer.flashB = dotProf.flash[1], dotProf.flash[2], dotProf.flash[3]
                    if enhancer.hitFlash then
                        enhancer.hitFlash:SetBlendMode("ADD")
                    end
                    enhancer.flashAlpha = smolderAlpha
                end
                dotBorderAlpha = (0.36 + 0.22 * math.sin(now * 16.0)) * dotFade
            elseif dotElem == "LIGHTNING" then
                dotBorderAlpha = (0.26 + 0.18 * math.sin(now * 38.0)) * dotFade
            elseif dotElem == "FROST" then
                local rimeAlpha = (0.09 + 0.04 * math.sin(now * 7.0)) * dotFade
                if enhancer.flashAlpha < rimeAlpha then
                    enhancer.flashR, enhancer.flashG, enhancer.flashB = dotProf.flash[1], dotProf.flash[2], dotProf.flash[3]
                    if enhancer.hitFlash then
                        enhancer.hitFlash:SetBlendMode("ADD")
                    end
                    enhancer.flashAlpha = rimeAlpha
                end
                dotBorderAlpha = (0.34 + 0.12 * math.sin(now * 8.0)) * dotFade
            elseif dotElem == "SHADOW" then
                local voidAlpha = (0.10 + 0.05 * math.sin(now * 9.0)) * dotFade
                if enhancer.flashAlpha < voidAlpha then
                    enhancer.flashR, enhancer.flashG, enhancer.flashB = dotProf.flash[1], dotProf.flash[2], dotProf.flash[3]
                    if enhancer.hitFlash then
                        enhancer.hitFlash:SetBlendMode("ADD")
                    end
                    enhancer.flashAlpha = voidAlpha
                end
                dotBorderAlpha = (0.34 + 0.20 * math.sin(now * 10.0)) * dotFade
            else
                dotBorderAlpha = (0.30 + 0.14 * math.sin(now * 10.0)) * dotFade
            end

            if dotProf.border and dotBorderAlpha > bestBorderAlpha then
                bestBorderAlpha = dotBorderAlpha
                bestBorderProf = dotProf
                bestBorderElem = dotElem
                borderShown = true
            end

            enhancer.dotEmitTimer = (enhancer.dotEmitTimer or 0) - dt
            if enhancer.dotEmitTimer <= 0 and ns.CombatFX and fillAnchor then
                local spR = (dotProf.spark and dotProf.spark[1]) or 1.0
                local spG = (dotProf.spark and dotProf.spark[2]) or 0.5
                local spB = (dotProf.spark and dotProf.spark[3]) or 0.1
                if dotElem == "FIRE" then
                    enhancer.dotEmitTimer = 0.16
                    ns.CombatFX:SpawnBarSparks(fillAnchor, nil, 2, spR, spG, spB, false, "FIRE", 0.44 * dotFade)
                elseif dotElem == "LIGHTNING" then
                    enhancer.dotEmitTimer = 0.30
                    ns.CombatFX:SpawnBarLightning(fillAnchor, 1, 0.13, 0.28 * dotFade)
                    ns.CombatFX:SpawnBarSparks(fillAnchor, nil, 1, spR, spG, spB, false, "LIGHTNING", 0.32 * dotFade)
                elseif dotElem == "SHADOW" then
                    enhancer.dotEmitTimer = 0.22
                    ns.CombatFX:SpawnBarSparks(fillAnchor, nil, 2, spR, spG, spB, false, "SHADOW", 0.40 * dotFade)
                elseif dotElem == "FROST" then
                    enhancer.dotEmitTimer = 0.26
                    ns.CombatFX:SpawnBarSparks(fillAnchor, nil, 1, spR, spG, spB, false, "FROST", 0.38 * dotFade)
                else
                    enhancer.dotEmitTimer = 0.28
                    ns.CombatFX:SpawnBarSparks(fillAnchor, nil, 1, spR, spG, spB, false, dotElem, 0.36 * dotFade)
                end
            end
        end
    else
        enhancer.dotTimer = 0
    end

    if enhancer.elemBorder then
        if borderShown and bestBorderProf and bestBorderProf.border and bestBorderAlpha > 0.02 then
            enhancer.elemBorder:SetBorderColor(
                bestBorderProf.border[1],
                bestBorderProf.border[2],
                bestBorderProf.border[3],
                math.min(1.0, bestBorderAlpha),
                (bestBorderElem == "EARTH") and "BLEND" or "ADD"
            )
            enhancer.elemBorder:Show()
        else
            enhancer.elemBorder:Hide()
        end
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
    local defaultH = enhancer.isNameplate and 12 or 14
    local targetH = enhancer.baseHeight or defaultH
    local punchedH = targetH * enhancer.barPunchY
    local yPad = (punchedH - defaultH) * 0.5

    local container = enhancer.container
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", bar, "TOPLEFT", dx, yPad + dy)
    container:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", dx, -yPad + dy)

    if not enhancer.isSecretHealth then
        local val = math.floor(enhancer.displayFrac * 1000 + 0.5)
        enhancer.mainBar:SetValue(val)
        enhancer.trailBar:SetValue(math.floor(enhancer.trailFrac * 1000 + 0.5))
        if enhancer.steadyWoundBar then
            enhancer.steadyWoundBar:SetValue(val)
        end
        if enhancer.fillOverlay then
            enhancer.fillOverlay.fuiWidth = math.max(14, (enhancer.baseWidth or 118) * math.max(0.08, enhancer.displayFrac))
            enhancer.fillOverlay.fuiHeight = targetH
        end
        if enhancer.trailChunkOverlay then
            local lostFrac = math.max(0.03, (enhancer.trailFrac or 0) - (enhancer.displayFrac or 0))
            enhancer.trailChunkOverlay.fuiWidth = math.max(6, (enhancer.baseWidth or 118) * lostFrac)
            enhancer.trailChunkOverlay.fuiHeight = targetH
        end
    end

    -- Render Fading/Damaged Health Chunk as disintegrating elemental embers/sparks/rubble/shards!
    local holdC = enhancer.trailHoldColor or { 1.00, 0.90, 0.55 }
    local fadeC = enhancer.trailFadeColor or { 1.00, 0.32, 0.08 }
    local dissolveTimer = enhancer.trailDissolveTimer or 0
    if dissolveTimer > 0.01 then
        local rem = math.max(0, math.min(1.0, dissolveTimer / math.max(0.1, enhancer.trailDissolveDuration or 0.55)))
        local t = 1.0 - rem
        local r = fadeC[1] + (holdC[1] - fadeC[1]) * rem
        local g = fadeC[2] + (holdC[2] - fadeC[2]) * rem
        local b = fadeC[3] + (holdC[3] - fadeC[3]) * rem
        -- Rapidly dissolve the solid bar background so the chunk turns into fragments & particles!
        local barAlpha = math.pow(rem, 1.85) * 0.62
        enhancer.trailBar:SetStatusBarColor(r, g, b, barAlpha)

        if enhancer.trailFragments and enhancer.trailChunkOverlay then
            local elem = enhancer.activeElement or "PHYSICAL"
            local prof = ns.Elements and ns.Elements:GetProfile(elem)
            local spC = (prof and prof.spark) or holdC
            local altC = (prof and prof.sparkAlt) or holdC
            local chunkW = enhancer.trailChunkOverlay.fuiWidth or 18
            local blend = (elem == "EARTH") and "BLEND" or "ADD"

            for i = 1, #enhancer.trailFragments do
                local f = enhancer.trailFragments[i]
                local tex = f.tex
                tex:SetBlendMode(blend)
                local ox = f.u * chunkW + f.vx * t
                local oy = f.v * targetH + f.vy * t
                if elem == "EARTH" or elem == "FROST" then
                    oy = f.v * targetH + f.vy * (t * t * 1.35)
                end
                local scale = math.max(0.25, 1.0 - t * 0.72)
                tex:ClearAllPoints()
                tex:SetPoint("CENTER", enhancer.trailChunkOverlay, "CENTER", ox, oy)
                tex:SetSize(f.sizeW * scale, f.sizeH * scale)
                local col = f.isAlt and altC or spC
                local fAlpha = math.min(1.0, rem * 1.15)
                tex:SetVertexColor(col[1], col[2], col[3], fAlpha)
                tex:Show()
            end
        end
    else
        enhancer.trailBar:SetStatusBarColor(fadeC[1], fadeC[2], fadeC[3], 0.0)
        if enhancer.trailFragments then
            for i = 1, #enhancer.trailFragments do
                enhancer.trailFragments[i].tex:Hide()
            end
        end
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
        enhancer.hitFlash:SetVertexColor(
            enhancer.flashR or 1.0,
            enhancer.flashG or 0.95,
            enhancer.flashB or 0.85,
            enhancer.flashAlpha
        )
        enhancer.hitFlash:Show()
    else
        enhancer.hitFlash:Hide()
    end
end

function UnitBars:OnEnable()
    -- PlayerFrame and TargetFrame portrait bars stay 100% untouched native WoW.
end
