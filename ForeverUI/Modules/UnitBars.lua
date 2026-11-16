local addonName, ns = ...
local UnitBars = {}
ns.UnitBars = UnitBars

UnitBars.enhancers = {}
local activeAnimEnhancers = {}

local function GetUnitBarColor(unit)
    if unit and UnitExists(unit) then
        if UnitIsTapDenied then
            local tapped = UnitIsTapDenied(unit)
            if tapped and not ns.IsSecret(tapped) then
                return 0.48, 0.48, 0.52 -- Tap-denied weathered slate grey
            end
        end
        if UnitReaction then
            local reaction = UnitReaction(unit, "player")
            if reaction and not ns.IsSecret(reaction) then
                if reaction <= 3 then
                    return 0.86, 0.13, 0.12 -- Rich Crimson Hostile
                elseif reaction == 4 then
                    return 0.94, 0.74, 0.14 -- Warm Amber-Gold Neutral
                else
                    return 0.16, 0.82, 0.24 -- Lush Emerald Friendly
                end
            end
        end
    end
    return 0.86, 0.13, 0.12
end

local function CreateBorderFrame(parent, r, g, b, thickness)
    local border = CreateFrame("Frame", nil, parent)
    border:SetAllPoints(parent)
    border:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)
    thickness = thickness or 2

    local top = border:CreateTexture(nil, "OVERLAY", nil, 5)
    top:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    top:SetPoint("TOPLEFT", border, "TOPLEFT", -thickness, thickness)
    top:SetPoint("TOPRIGHT", border, "TOPRIGHT", thickness, thickness)
    top:SetHeight(thickness)

    local bottom = border:CreateTexture(nil, "OVERLAY", nil, 5)
    bottom:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", -thickness, -thickness)
    bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", thickness, -thickness)
    bottom:SetHeight(thickness)

    local left = border:CreateTexture(nil, "OVERLAY", nil, 5)
    left:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    left:SetPoint("TOPLEFT", border, "TOPLEFT", -thickness, thickness)
    left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", -thickness, -thickness)
    left:SetWidth(thickness)

    local right = border:CreateTexture(nil, "OVERLAY", nil, 5)
    right:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
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

-- Crisp Golden L-Shaped Corner Lock-On Brackets with Dark Iron Backing for the Active Target
local function CreateTargetBrackets(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:SetFrameLevel((parent:GetFrameLevel() or 1) + 6)

    local armW = 7.5
    local armH = 4.5
    local thick = 1.5
    local segments = {}

    local function MakeSegment(point, relPoint, sx, sy, w, h)
        local bg = frame:CreateTexture(nil, "OVERLAY", nil, 6)
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetBlendMode("BLEND")
        bg:SetVertexColor(0.05, 0.04, 0.03, 0.92)
        bg:SetSize(w + 1.2, h + 1.2)

        local tex = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetBlendMode("BLEND")
        tex:SetVertexColor(1.0, 0.86, 0.30, 0.96)
        tex:SetSize(w, h)

        segments[#segments + 1] = {
            bg = bg,
            tex = tex,
            point = point,
            relPoint = relPoint,
            sx = sx,
            sy = sy,
        }
    end

    -- Top-Left L bracket
    MakeSegment("TOPLEFT", "TOPLEFT", -1, 1, armW, thick)
    MakeSegment("TOPLEFT", "TOPLEFT", -1, 1, thick, armH)
    -- Top-Right L bracket
    MakeSegment("TOPRIGHT", "TOPRIGHT", 1, 1, armW, thick)
    MakeSegment("TOPRIGHT", "TOPRIGHT", 1, 1, thick, armH)
    -- Bottom-Left L bracket
    MakeSegment("BOTTOMLEFT", "BOTTOMLEFT", -1, -1, armW, thick)
    MakeSegment("BOTTOMLEFT", "BOTTOMLEFT", -1, -1, thick, armH)
    -- Bottom-Right L bracket
    MakeSegment("BOTTOMRIGHT", "BOTTOMRIGHT", 1, -1, armW, thick)
    MakeSegment("BOTTOMRIGHT", "BOTTOMRIGHT", 1, -1, thick, armH)

    function frame:SetBracketOffset(pad)
        local p = pad or 2.5
        for i = 1, #segments do
            local s = segments[i]
            local ox = s.sx * p
            local oy = s.sy * p
            s.bg:ClearAllPoints()
            s.bg:SetPoint(s.point, self, s.relPoint, ox + s.sx * 0.5, oy + s.sy * 0.5)
            s.tex:ClearAllPoints()
            s.tex:SetPoint(s.point, self, s.relPoint, ox, oy)
        end
    end

    frame:SetBracketOffset(2.5)
    frame:Hide()
    return frame
end

local function ApplyVerticalGradient(tex, r1, g1, b1, a1, r2, g2, b2, a2)
    if tex.SetGradient and CreateColor then
        local ok = pcall(tex.SetGradient, tex, "VERTICAL", CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
        if ok then
            return true
        end
    end
    return false
end

local function AddClassicBarBevel(statusBar)
    local fillTex = statusBar:GetStatusBarTexture() or statusBar

    local topRim = statusBar:CreateTexture(nil, "OVERLAY", nil, 2)
    topRim:SetTexture("Interface\\Buttons\\WHITE8X8")
    topRim:SetBlendMode("ADD")
    topRim:SetVertexColor(1.0, 1.0, 1.0, 0.16)
    topRim:SetPoint("TOPLEFT", fillTex, "TOPLEFT", 0, 0)
    topRim:SetPoint("TOPRIGHT", fillTex, "TOPRIGHT", 0, 0)
    topRim:SetHeight(1)

    local sheen = statusBar:CreateTexture(nil, "OVERLAY", nil, 1)
    sheen:SetTexture("Interface\\Buttons\\WHITE8X8")
    sheen:SetPoint("TOPLEFT", fillTex, "TOPLEFT", 0, 0)
    sheen:SetPoint("BOTTOMRIGHT", fillTex, "RIGHT", 0, 0)
    if not ApplyVerticalGradient(sheen, 1.0, 1.0, 1.0, 0.02, 1.0, 1.0, 1.0, 0.15) then
        sheen:SetVertexColor(1.0, 1.0, 1.0, 0.11)
    end

    local shadow = statusBar:CreateTexture(nil, "OVERLAY", nil, 1)
    shadow:SetTexture("Interface\\Buttons\\WHITE8X8")
    shadow:SetPoint("TOPLEFT", fillTex, "LEFT", 0, 0)
    shadow:SetPoint("BOTTOMRIGHT", fillTex, "BOTTOMRIGHT", 0, 0)
    if not ApplyVerticalGradient(shadow, 0.0, 0.0, 0.0, 0.24, 0.0, 0.0, 0.0, 0.02) then
        shadow:SetVertexColor(0.0, 0.0, 0.0, 0.17)
    end
end

local function HideEnhancerTransientFX(enhancer)
    if enhancer.elemBorder then
        enhancer.elemBorder:Hide()
    end
    if enhancer.hitFlash then
        enhancer.hitFlash:Hide()
    end
    if enhancer.cutGlow then
        enhancer.cutGlow:Hide()
    end
    if enhancer.cutLine then
        enhancer.cutLine:Hide()
    end
    if enhancer.cutFlare then
        enhancer.cutFlare:Hide()
    end
    if enhancer.cutSubFlare then
        enhancer.cutSubFlare:Hide()
    end
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
                enhancer.bracketAnimTimer = 0
                enhancer.barPunchY = 1.0
                HideEnhancerTransientFX(enhancer)
                activeAnimEnhancers[enhancer] = nil
            else
                local stillAnimating = UnitBars:StepEnhancer(enhancer, dt, now, smoothSpeed, trailSpeed)
                if stillAnimating then
                    anyActive = true
                else
                    HideEnhancerTransientFX(enhancer)
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

    -- Recessed UI-StatusBar trough with dark inner top shadow so lost health feels carved out
    local bgTex = container:CreateTexture(nil, "BACKGROUND", nil, 0)
    bgTex:SetAllPoints(container)
    bgTex:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bgTex:SetVertexColor(0.07, 0.06, 0.08, 0.95)

    local troughShadow = container:CreateTexture(nil, "BACKGROUND", nil, 1)
    troughShadow:SetTexture("Interface\\Buttons\\WHITE8X8")
    troughShadow:SetVertexColor(0.0, 0.0, 0.0, 0.42)
    troughShadow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    troughShadow:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    troughShadow:SetHeight(2)

    local trailBar = CreateFrame("StatusBar", nil, container)
    trailBar:SetAllPoints(container)
    trailBar:SetFrameLevel(baseLevel + 1)
    trailBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    trailBar:SetStatusBarColor(1.0, 0.72, 0.24, 0.94)
    trailBar:SetMinMaxValues(0, 1000)
    trailBar:SetValue(1000)
    AddClassicBarBevel(trailBar)

    local mainBar = CreateFrame("StatusBar", nil, container)
    mainBar:SetAllPoints(container)
    mainBar:SetFrameLevel(baseLevel + 2)
    mainBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    mainBar:SetStatusBarColor(0.86, 0.13, 0.12, 1.0)
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

    -- Outer weathered iron frame (1px)
    local bTop = fxOverlay:CreateTexture(nil, "BORDER", nil, 0)
    bTop:SetTexture("Interface\\Buttons\\WHITE8X8")
    bTop:SetVertexColor(0.08, 0.07, 0.06, 0.96)
    bTop:SetPoint("TOPLEFT", container, "TOPLEFT", -2, 2)
    bTop:SetPoint("TOPRIGHT", container, "TOPRIGHT", 2, 2)
    bTop:SetHeight(1)

    local bBot = fxOverlay:CreateTexture(nil, "BORDER", nil, 0)
    bBot:SetTexture("Interface\\Buttons\\WHITE8X8")
    bBot:SetVertexColor(0.08, 0.07, 0.06, 0.96)
    bBot:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", -2, -2)
    bBot:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 2, -2)
    bBot:SetHeight(1)

    local bLeft = fxOverlay:CreateTexture(nil, "BORDER", nil, 0)
    bLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
    bLeft:SetVertexColor(0.08, 0.07, 0.06, 0.96)
    bLeft:SetPoint("TOPLEFT", container, "TOPLEFT", -2, 2)
    bLeft:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", -2, -2)
    bLeft:SetWidth(1)

    local bRight = fxOverlay:CreateTexture(nil, "BORDER", nil, 0)
    bRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    bRight:SetVertexColor(0.08, 0.07, 0.06, 0.96)
    bRight:SetPoint("TOPRIGHT", container, "TOPRIGHT", 2, 2)
    bRight:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 2, -2)
    bRight:SetWidth(1)

    -- Inner weathered stone-bronze bevel rim (1px, matching Castbars)
    local rTop = fxOverlay:CreateTexture(nil, "BORDER", nil, 1)
    rTop:SetTexture("Interface\\Buttons\\WHITE8X8")
    rTop:SetVertexColor(0.42, 0.37, 0.28, 0.80)
    rTop:SetPoint("TOPLEFT", container, "TOPLEFT", -1, 1)
    rTop:SetPoint("TOPRIGHT", container, "TOPRIGHT", 1, 1)
    rTop:SetHeight(1)

    local rBot = fxOverlay:CreateTexture(nil, "BORDER", nil, 1)
    rBot:SetTexture("Interface\\Buttons\\WHITE8X8")
    rBot:SetVertexColor(0.20, 0.18, 0.15, 0.84)
    rBot:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", -1, -1)
    rBot:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 1, -1)
    rBot:SetHeight(1)

    local rLeft = fxOverlay:CreateTexture(nil, "BORDER", nil, 1)
    rLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
    rLeft:SetVertexColor(0.35, 0.31, 0.24, 0.80)
    rLeft:SetPoint("TOPLEFT", container, "TOPLEFT", -1, 1)
    rLeft:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", -1, -1)
    rLeft:SetWidth(1)

    local rRight = fxOverlay:CreateTexture(nil, "BORDER", nil, 1)
    rRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    rRight:SetVertexColor(0.22, 0.20, 0.16, 0.84)
    rRight:SetPoint("TOPRIGHT", container, "TOPRIGHT", 1, 1)
    rRight:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 1, -1)
    rRight:SetWidth(1)

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

    -- Dual-layer in-bar dissolving elemental fragments (soft atmospheric halo + crisp core sprite)
    local trailFragments = {}
    local defaultFragTextures = {
        "Interface\\Cooldown\\star4",
        "Interface\\CastingBar\\UI-CastingBar-Spark",
        "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
        "Interface\\Cooldown\\starburst",
    }
    for i = 1, 10 do
        local glowTex = trailChunkOverlay:CreateTexture(nil, "OVERLAY", nil, 3)
        glowTex:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        glowTex:SetBlendMode("ADD")
        glowTex:SetSize(13, 13)
        glowTex:Hide()

        local frag = trailChunkOverlay:CreateTexture(nil, "OVERLAY", nil, 4)
        frag:SetTexture(defaultFragTextures[((i - 1) % 4) + 1])
        frag:SetBlendMode("ADD")
        frag:SetSize(7, 7)
        frag:Hide()

        trailFragments[i] = {
            glowTex = glowTex,
            tex = frag,
            u = (i - 0.5) / 10 - 0.5,
            v = ((i % 2 == 0) and 0.22 or -0.22),
            vx = 0,
            vy = 0,
            sizeW = 7,
            sizeH = 7,
            rot = (i * 0.62),
            vRot = ((i % 2 == 0) and 3.5 or -3.5),
            wavePhase = i * 1.15,
            waveFreq = 10.0,
            flickerSpeed = 18.0 + i * 2.5,
            palIdx = ((i - 1) % 4) + 1,
            isAlt = (i % 3 == 0),
            shapeRoll = i % 3,
        }
    end

    local hitFlash = fillOverlay:CreateTexture(nil, "OVERLAY", nil, 3)
    hitFlash:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    hitFlash:SetBlendMode("ADD")
    hitFlash:SetVertexColor(1.0, 0.95, 0.85, 0.0)
    hitFlash:SetAllPoints(fillOverlay)
    hitFlash:Hide()

    -- Multi-Layer Wound Seam: wide elemental plasma bleed + sharp core spark + dual counter-rotating starbursts
    local cutGlow = fxOverlay:CreateTexture(nil, "OVERLAY", nil, 5)
    cutGlow:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    cutGlow:SetBlendMode("ADD")
    cutGlow:SetVertexColor(1.0, 0.65, 0.20, 0.0)
    cutGlow:SetWidth(20.0)
    if mainFillTexture then
        cutGlow:SetPoint("TOP", mainFillTexture, "TOPRIGHT", 0, 6)
        cutGlow:SetPoint("BOTTOM", mainFillTexture, "BOTTOMRIGHT", 0, -6)
    end
    cutGlow:Hide()

    local cutLine = fxOverlay:CreateTexture(nil, "OVERLAY", nil, 6)
    cutLine:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    cutLine:SetBlendMode("ADD")
    cutLine:SetVertexColor(1.0, 0.95, 0.80, 0.0)
    cutLine:SetWidth(8.5)
    cutLine.fuiWidth = 12
    cutLine.fuiHeight = defaultH
    if mainFillTexture then
        cutLine:SetPoint("TOP", mainFillTexture, "TOPRIGHT", 0, 4)
        cutLine:SetPoint("BOTTOM", mainFillTexture, "BOTTOMRIGHT", 0, -4)
    end
    cutLine:Hide()

    local cutFlare = fxOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    cutFlare:SetTexture("Interface\\Cooldown\\star4")
    cutFlare:SetBlendMode("ADD")
    cutFlare:SetVertexColor(1.0, 0.96, 0.82, 0.0)
    cutFlare:SetSize(15, 15)
    cutFlare:SetPoint("CENTER", cutLine, "CENTER", 0, 0)
    cutFlare:Hide()

    local cutSubFlare = fxOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    cutSubFlare:SetTexture("Interface\\Cooldown\\starburst")
    cutSubFlare:SetBlendMode("ADD")
    cutSubFlare:SetVertexColor(1.0, 0.82, 0.45, 0.0)
    cutSubFlare:SetSize(12, 12)
    cutSubFlare:SetPoint("CENTER", cutLine, "CENTER", 0, 0)
    cutSubFlare:Hide()

    local executeBorder = CreateBorderFrame(fxOverlay, 1.0, 0.15, 0.15, 1.5)
    local elemBorder = CreateBorderFrame(fillOverlay, 1.0, 0.50, 0.10, 1.5)
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
        cutGlow = cutGlow,
        cutLine = cutLine,
        cutFlare = cutFlare,
        cutSubFlare = cutSubFlare,
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
        bracketAnimTimer = 0,
        activeElement = "PHYSICAL",
        lastElement = "PHYSICAL",
        elemGlowTimer = 0,
        elemGlowDuration = 0.25,
        trailHotColor = { 1.00, 0.98, 0.90 },
        trailHoldColor = { 1.00, 0.90, 0.55 },
        trailFadeColor = { 0.85, 0.16, 0.12 },
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
                local ubCfg = ns.Config:Get("unitBars")
                local isVanilla = ubCfg and ubCfg.vanillaBarMode
                if not isVanilla then
                    enhancer.barPunchY = math.max(enhancer.barPunchY, 1.12)
                end
                enhancer.bracketAnimTimer = 0.14
                enhancer.targetBrackets:SetBracketOffset(5.5)
                enhancer.flashR, enhancer.flashG, enhancer.flashB = 1.0, 0.95, 0.78
                enhancer.flashAlpha = math.max(enhancer.flashAlpha, isVanilla and 0.18 or 0.28)
                activeAnimEnhancers[enhancer] = true
                EnsureEnhancerTicker()
            else
                enhancer.targetBrackets:SetBracketOffset(2.5)
            end
        else
            enhancer.baseHeight = 11
            enhancer.bracketAnimTimer = 0
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
            HideEnhancerTransientFX(enhancer)
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
        HideEnhancerTransientFX(enhancer)
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

    local holdTime = isCrit and (cfg.trailHoldCrit or 0.32) or (cfg.trailHoldNormal or 0.20)
    enhancer.trailHoldTimer = math.max(enhancer.trailHoldTimer or 0, holdTime * (0.88 + 0.25 * intensity))
    local newDissolveDur = (isCrit and 0.62 or 0.44) * (0.75 + 0.25 * intensity)
    enhancer.trailDissolveDuration = math.max(enhancer.trailDissolveDuration or 0, newDissolveDur)
    enhancer.trailDissolveTimer = math.max(enhancer.trailDissolveTimer or 0, newDissolveDur)
    enhancer.trailEmitTimer = 0.14
    enhancer.lastDmgFrac = dmgFrac

    local vanillaMode = cfg.vanillaBarMode and true or false
    local elemBlend = (resolvedKey == "EARTH") and "BLEND" or "ADD"
    if enhancer.hitFlash then
        enhancer.hitFlash:SetBlendMode(elemBlend)
    end

    if prof then
        enhancer.flashR, enhancer.flashG, enhancer.flashB = prof.flash[1], prof.flash[2], prof.flash[3]
        enhancer.trailHotColor = prof.trailHot or prof.flash or prof.trailHold
        enhancer.trailHoldColor = prof.trailHold
        enhancer.trailFadeColor = prof.trailFade
        if enhancer.cutGlow then
            local glowC = prof.trailHold or prof.cut
            enhancer.cutGlow:SetVertexColor(glowC[1], glowC[2], glowC[3], 1.0)
        end
        if enhancer.cutLine then
            enhancer.cutLine:SetVertexColor(prof.cut[1], prof.cut[2], prof.cut[3], 1.0)
        end
        if enhancer.cutFlare then
            local flCol = prof.spark or prof.cut
            enhancer.cutFlare:SetVertexColor(flCol[1], flCol[2], flCol[3], 1.0)
            local fSize = 11 + 8 * enhancer.elemIntensity
            enhancer.cutFlare:SetSize(fSize, fSize)
        end
        if enhancer.cutSubFlare then
            local subCol = prof.sparkAlt or prof.trailHold or prof.cut
            enhancer.cutSubFlare:SetVertexColor(subCol[1], subCol[2], subCol[3], 1.0)
            local sSize = 9 + 6 * enhancer.elemIntensity
            enhancer.cutSubFlare:SetSize(sSize, sSize)
        end
        if enhancer.elemBorder then
            if vanillaMode then
                enhancer.elemBorder:Hide()
            elseif prof.border then
                enhancer.elemBorder:SetBorderColor(prof.border[1], prof.border[2], prof.border[3], 0.65 * enhancer.elemIntensity, elemBlend)
                if resolvedKey ~= "PHYSICAL" and enhancer.elemIntensity >= 0.45 then
                    enhancer.elemBorder:Show()
                elseif not recentImpact then
                    enhancer.elemBorder:Hide()
                end
            end
        end
    else
        enhancer.flashR, enhancer.flashG, enhancer.flashB = 1.0, 0.95, 0.85
    end

    -- Subtle remaining-health flash so the delayed damage trail stands out cleanly
    local newFlash = vanillaMode
        and (isCrit and 0.16 or (0.04 + 0.08 * intensity))
        or (isCrit and 0.26 or (0.07 + 0.14 * intensity))
    enhancer.flashAlpha = math.max(enhancer.flashAlpha or 0, newFlash)
    local newCut = vanillaMode and (0.24 + 0.32 * intensity) or (0.40 + 0.50 * intensity)
    enhancer.cutAlpha = math.max(enhancer.cutAlpha or 0, newCut)

    local traumaScale = cfg.traumaScale or 0.70
    local critMult = cfg.critTraumaMultiplier or 1.45
    local rawTrauma
    if isDot then
        rawTrauma = 0.12 * traumaScale
    elseif isMega then
        rawTrauma = 1.10 * traumaScale
    elseif isCrit then
        rawTrauma = (0.62 + 0.14 * weight) * critMult * traumaScale
    else
        rawTrauma = intensity * 0.85 * traumaScale
    end
    if not isDot then
        if resolvedKey == "EARTH" then
            rawTrauma = rawTrauma * 1.12
        elseif resolvedKey == "LIGHTNING" then
            rawTrauma = rawTrauma * 1.08
        elseif resolvedKey == "FROST" then
            rawTrauma = rawTrauma * 1.05
        end
    end
    enhancer.trauma = math.min(1.45, math.max(enhancer.trauma or 0, rawTrauma))

    local normalPunchMax = cfg.barPunchNormal or 1.08
    local critPunchMax = cfg.barPunchCrit or 1.22
    local megaPunchMax = cfg.barPunchMega or 1.32
    local scaledPunch
    if isDot then
        scaledPunch = vanillaMode and 1.00 or 1.02
    elseif isMega then
        scaledPunch = megaPunchMax
    elseif isCrit then
        scaledPunch = critPunchMax + (megaPunchMax - critPunchMax) * 0.40 * weight
    else
        local heavyTarget = normalPunchMax + (critPunchMax - normalPunchMax) * 0.35
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

    -- Seed dynamic 9-element WoW spell particles inside trailChunkOverlay
    if enhancer.trailFragments then
        local n = #enhancer.trailFragments
        for i = 1, n do
            local f = enhancer.trailFragments[i]
            f.u = ((i - 0.5) / n - 0.5) * 0.88 + (math.random() - 0.5) * 0.08
            f.v = (math.random() - 0.5) * 0.65
            f.vx = (math.random() - 0.5) * 14
            f.rot = math.random() * 6.2831853
            f.vRot = (math.random() - 0.5) * 9.5
            f.wavePhase = math.random() * 6.2831853
            f.waveFreq = 8.0 + math.random() * 8.0
            f.flickerSpeed = 16.0 + math.random() * 18.0
            f.palIdx = ((i - 1) % 4) + 1
            f.isAlt = (i % 3 == 0)
            local shapeRoll = i % 3
            f.shapeRoll = shapeRoll

            if resolvedKey == "FIRE" then
                f.vy = 15 + math.random() * 19
                if shapeRoll == 0 then
                    f.tex:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
                    f.sizeW = 4.6 + math.random() * 2.4
                    f.sizeH = 11.5 + math.random() * 5.0
                elseif shapeRoll == 1 then
                    f.tex:SetTexture("Interface\\Cooldown\\star4")
                    f.sizeW = 7.8 + math.random() * 4.2
                    f.sizeH = f.sizeW
                else
                    f.tex:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
                    f.sizeW = 6.8 + math.random() * 3.5
                    f.sizeH = f.sizeW
                end
            elseif resolvedKey == "LIGHTNING" then
                f.vy = (math.random() - 0.5) * 26
                f.vx = (math.random() - 0.5) * 28
                f.flickerSpeed = 42.0 + math.random() * 25.0
                if shapeRoll == 0 then
                    f.tex:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
                    f.sizeW = 3.8 + math.random() * 2.0
                    f.sizeH = 12.5 + math.random() * 6.5
                elseif shapeRoll == 1 then
                    f.tex:SetTexture("Interface\\Cooldown\\star4")
                    f.sizeW = 8.5 + math.random() * 4.5
                    f.sizeH = f.sizeW
                else
                    f.tex:SetTexture("Interface\\Cooldown\\starburst")
                    f.sizeW = 7.5 + math.random() * 4.0
                    f.sizeH = f.sizeW
                end
            elseif resolvedKey == "EARTH" then
                f.vy = -(15 + math.random() * 19)
                f.vx = (math.random() - 0.5) * 16
                if shapeRoll == 0 then
                    f.tex:SetTexture("Interface\\Cooldown\\star4")
                    f.sizeW = 6.8 + math.random() * 3.2
                    f.sizeH = f.sizeW
                else
                    f.tex:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
                    f.sizeW = 4.6 + math.random() * 3.0
                    f.sizeH = 3.2 + math.random() * 2.4
                end
            elseif resolvedKey == "FROST" then
                f.vy = (math.random() - 0.35) * 14
                f.vx = (math.random() - 0.5) * 16
                f.flickerSpeed = 28.0 + math.random() * 20.0
                if shapeRoll == 0 then
                    f.tex:SetTexture("Interface\\Cooldown\\starburst")
                    f.sizeW = 8.5 + math.random() * 4.5
                    f.sizeH = f.sizeW
                elseif shapeRoll == 1 then
                    f.tex:SetTexture("Interface\\Cooldown\\star4")
                    f.sizeW = 7.8 + math.random() * 4.0
                    f.sizeH = f.sizeW
                else
                    f.tex:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
                    f.sizeW = 4.0 + math.random() * 2.0
                    f.sizeH = 11.0 + math.random() * 4.5
                end
            elseif resolvedKey == "SHADOW" then
                -- Void implosion: particles spawn outward and swirl inward toward the wound core
                f.u = ((i - 0.5) / n - 0.5) * 1.15
                f.v = ((i % 2 == 0) and 1 or -1) * (0.45 + math.random() * 0.45)
                f.vx = -f.u * (14 + math.random() * 10)
                f.vy = -f.v * (10 + math.random() * 8)
                if shapeRoll == 0 then
                    f.tex:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
                    f.sizeW = 8.0 + math.random() * 4.5
                    f.sizeH = f.sizeW
                elseif shapeRoll == 1 then
                    f.tex:SetTexture("Interface\\Cooldown\\ping4")
                    f.sizeW = 7.5 + math.random() * 4.0
                    f.sizeH = f.sizeW
                else
                    f.tex:SetTexture("Interface\\Cooldown\\star4")
                    f.sizeW = 8.0 + math.random() * 4.0
                    f.sizeH = f.sizeW
                end
            elseif resolvedKey == "ARCANE" then
                f.vx = (math.random() - 0.5) * 12
                f.vy = (math.random() - 0.5) * 12
                f.vRot = ((i % 2 == 0) and 1 or -1) * (6.5 + math.random() * 4.5)
                if shapeRoll == 0 then
                    f.tex:SetTexture("Interface\\Cooldown\\ping4")
                    f.sizeW = 7.5 + math.random() * 4.5
                    f.sizeH = f.sizeW
                elseif shapeRoll == 1 then
                    f.tex:SetTexture("Interface\\Cooldown\\starburst")
                    f.sizeW = 8.5 + math.random() * 4.5
                    f.sizeH = f.sizeW
                else
                    f.tex:SetTexture("Interface\\Cooldown\\star4")
                    f.sizeW = 7.8 + math.random() * 4.0
                    f.sizeH = f.sizeW
                end
            elseif resolvedKey == "NATURE" then
                f.vy = 8 + math.random() * 12
                f.vx = (math.random() - 0.5) * 16
                f.waveFreq = 6.5 + math.random() * 5.0
                if shapeRoll == 0 then
                    f.tex:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
                    f.sizeW = 7.5 + math.random() * 4.0
                    f.sizeH = f.sizeW
                elseif shapeRoll == 1 then
                    f.tex:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
                    f.sizeW = 4.2 + math.random() * 2.0
                    f.sizeH = 9.5 + math.random() * 4.0
                else
                    f.tex:SetTexture("Interface\\Cooldown\\star4")
                    f.sizeW = 7.5 + math.random() * 3.8
                    f.sizeH = f.sizeW
                end
            elseif resolvedKey == "HOLY" then
                f.vy = 13 + math.random() * 15
                f.vx = (math.random() - 0.5) * 7
                f.rot = 0
                f.vRot = (shapeRoll == 1) and ((i % 2 == 0 and 1 or -1) * 1.8) or 0
                if shapeRoll == 0 then
                    f.tex:SetTexture("Interface\\Cooldown\\star4")
                    f.sizeW = 8.5 + math.random() * 4.5
                    f.sizeH = f.sizeW
                elseif shapeRoll == 1 then
                    f.tex:SetTexture("Interface\\Cooldown\\starburst")
                    f.sizeW = 8.0 + math.random() * 4.0
                    f.sizeH = f.sizeW
                else
                    f.tex:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
                    f.sizeW = 4.2 + math.random() * 1.8
                    f.sizeH = 12.0 + math.random() * 5.0
                end
            else
                -- PHYSICAL: diagonal cleave slash streaks + steel sparks & crimson droplets
                f.vy = 10 + math.random() * 14
                f.vx = (math.random() - 0.35) * 20
                if shapeRoll == 0 then
                    f.tex:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
                    f.sizeW = 3.8 + math.random() * 2.0
                    f.sizeH = 12.0 + math.random() * 5.0
                    f.rot = ((i % 2 == 0) and 0.66 or -0.66)
                    f.vRot = 0
                elseif shapeRoll == 1 then
                    f.tex:SetTexture("Interface\\Cooldown\\star4")
                    f.sizeW = 7.5 + math.random() * 4.0
                    f.sizeH = f.sizeW
                else
                    f.tex:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
                    f.sizeW = 6.2 + math.random() * 3.0
                    f.sizeH = f.sizeW
                end
            end
        end
    end

    if ns.CombatFX and trailAnchor and not isDot and intensity >= 0.32 then
        local spR = (prof and prof.spark and prof.spark[1]) or 1.0
        local spG = (prof and prof.spark and prof.spark[2]) or 0.72
        local spB = (prof and prof.spark and prof.spark[3]) or 0.18
        local rawCount = math.max(2, math.floor(1 + intensity * (isMega and 7 or (isCrit and 5 or 3)) + 0.5))
        local baseCount = vanillaMode and math.max(1, math.floor(rawCount * 0.55 + 0.5)) or rawCount
        local spInt = vanillaMode and (intensity * 0.58) or (intensity * 0.78)

        if resolvedKey == "LIGHTNING" then
            local boltCount = ((isMega or isCrit) and not vanillaMode) and 1 or 0
            if boltCount > 0 then
                local boltDur = (isCrit and 0.18 or 0.12) * (0.70 + 0.30 * intensity)
                ns.CombatFX:SpawnBarLightning(trailAnchor, boltCount, boltDur, spInt)
            end
            ns.CombatFX:SpawnBarSparks(trailAnchor, nil, baseCount, spR, spG, spB, false, "LIGHTNING", spInt)
        elseif resolvedKey == "FIRE" then
            ns.CombatFX:SpawnBarSparks(trailAnchor, nil, baseCount + (vanillaMode and 0 or 1), spR, spG, spB, false, "FIRE", spInt)
        elseif resolvedKey == "EARTH" then
            if intensity >= 0.45 and ns.CombatFX.SpawnBarEarthCracks and not vanillaMode then
                local crackCount = (isMega or isCrit) and 2 or 1
                local crackDur = (isCrit and 0.32 or 0.24) * (0.75 + 0.25 * intensity)
                ns.CombatFX:SpawnBarEarthCracks(trailAnchor, crackCount, crackDur, intensity * 0.80)
            end
            ns.CombatFX:SpawnBarSparks(trailAnchor, nil, baseCount, spR, spG, spB, true, "EARTH", spInt)
        else
            ns.CombatFX:SpawnBarSparks(trailAnchor, nil, baseCount, spR, spG, spB, false, resolvedKey, spInt)
        end
    end

    -- Apply immediate Frame-0 impact kick so the bar jolts cleanly on impact
    local p0 = math.pow(enhancer.trauma, 1.45)
    local kickDir = (math.random() > 0.5) and 1 or -1
    local kickScale = vanillaMode and 0.48 or 1.0
    local initDx = kickDir * 4.5 * p0 * kickScale
    local initDy = ((resolvedKey == "EARTH") and -4.0 or 2.2) * p0 * kickScale
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
        ns.CombatFX:SpawnBarSparks(enhancer.container, 0.5, 8, 0.85, 0.94, 1.0, false, "PHYSICAL", 0.85)
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
        ns.CombatFX:SpawnBarLightning(enhancer.container, 2, 0.22, 0.95)
        ns.CombatFX:SpawnBarSparks(enhancer.container, 0.5, 14, 0.22, 0.92, 1.0, false, "LIGHTNING", 1.0)
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

    -- Target lock-on bracket snap-in animation
    if (enhancer.bracketAnimTimer or 0) > 0.001 then
        enhancer.bracketAnimTimer = math.max(0, enhancer.bracketAnimTimer - dt)
        stillActive = true
        if enhancer.targetBrackets and enhancer.targetBrackets.SetBracketOffset then
            local bFrac = enhancer.bracketAnimTimer / 0.14
            enhancer.targetBrackets:SetBracketOffset(2.5 + 3.0 * bFrac * bFrac)
        end
    end

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

    -- Subtle elemental trail emission on heavy hits only
    local elem = enhancer.activeElement or "PHYSICAL"
    if (enhancer.trailDissolveTimer or 0) > 0.01 then
        enhancer.trailDissolveTimer = math.max(0, enhancer.trailDissolveTimer - dt)
        stillActive = true
        enhancer.trailEmitTimer = (enhancer.trailEmitTimer or 0) - dt
        local elemInt = enhancer.elemIntensity or 0.6
        if elemInt >= 0.52 and enhancer.trailEmitTimer <= 0 and enhancer.trailDissolveTimer > 0.14 then
            local trailAnchor = enhancer.trailChunkOverlay or enhancer.cutLine
            local prof = ns.Elements and ns.Elements:GetProfile(elem)
            local remFrac = enhancer.trailDissolveTimer / math.max(0.1, enhancer.trailDissolveDuration or 0.45)
            if ns.CombatFX and trailAnchor and prof then
                local spR = (prof.spark and prof.spark[1]) or 1.0
                local spG = (prof.spark and prof.spark[2]) or 0.6
                local spB = (prof.spark and prof.spark[3]) or 0.1
                enhancer.trailEmitTimer = 0.18
                ns.CombatFX:SpawnBarSparks(trailAnchor, nil, 1, spR, spG, spB, (elem == "EARTH"), elem, elemInt * remFrac * 0.65)
            end
        end
    else
        enhancer.trailDissolveTimer = 0
    end

    if enhancer.flashAlpha > 0.01 then
        enhancer.flashAlpha = math.max(0, enhancer.flashAlpha - dt * 4.5)
        stillActive = true
    else
        enhancer.flashAlpha = 0
    end

    if enhancer.cutAlpha > 0.01 then
        enhancer.cutAlpha = math.max(0, enhancer.cutAlpha - dt * 3.2)
        stillActive = true
    else
        enhancer.cutAlpha = 0
    end

    if math.abs(enhancer.barPunchY - 1.0) > 0.005 then
        local punchRecover = (enhancer.activeElement == "EARTH") and 9.5 or 12.0
        enhancer.barPunchY = enhancer.barPunchY + (1.0 - enhancer.barPunchY) * math.min(1.0, dt * punchRecover)
        stillActive = true
    else
        enhancer.barPunchY = 1.0
    end

    local ubCfg = ns.Config:Get("unitBars")
    local vanillaMode = ubCfg and ubCfg.vanillaBarMode and true or false

    local dx, dy = 0, 0
    if enhancer.trauma > 0.01 then
        stillActive = true
        local p = math.pow(enhancer.trauma, 1.45)
        local maxOffset = vanillaMode and 3.2 or 6.8
        if elem == "LIGHTNING" then
            dx = (math.sin(now * 165.0) * (maxOffset * 1.18) + (math.random() - 0.5) * 4.5) * p
            dy = (math.cos(now * 180.0) * (maxOffset * 0.65) + (math.random() - 0.5) * 3.0) * p
        elseif elem == "EARTH" then
            dx = (math.sin(now * 58.0) * (maxOffset * 0.70) + (math.random() - 0.5) * 2.5) * p
            dy = (math.cos(now * 52.0) * (maxOffset * 1.35) + (math.random() - 0.5) * 3.5) * p
        elseif elem == "FROST" then
            dx = (math.sin(now * 125.0) * (maxOffset * 1.02) + (math.random() - 0.5) * 2.8) * p
            dy = (math.cos(now * 112.0) * (maxOffset * 0.52)) * p
        elseif elem == "SHADOW" then
            dx = math.sin(now * 62.0) * (maxOffset * 0.90) * p
            dy = math.cos(now * 48.0) * (maxOffset * 0.70) * p
        elseif elem == "ARCANE" then
            dx = math.sin(now * 118.0) * (maxOffset * 0.88) * p
            dy = math.sin(now * 236.0) * (maxOffset * 0.48) * p
        elseif elem == "NATURE" then
            dx = math.sin(now * 68.0) * (maxOffset * 0.82) * p
            dy = math.cos(now * 54.0) * (maxOffset * 0.75) * p
        elseif elem == "HOLY" then
            dx = math.sin(now * 78.0) * (maxOffset * 0.65) * p
            dy = math.abs(math.cos(now * 84.0)) * (maxOffset * 0.85) * p
        else
            dx = (math.sin(now * 88.0) * maxOffset + (math.random() - 0.5) * 3.5) * p
            dy = (math.cos(now * 96.0) * (maxOffset * 0.60) + (math.random() - 0.5) * 2.5) * p
        end
        local decayRate = (enhancer.trauma < 0.36) and 2.80 or 2.40
        enhancer.trauma = math.max(0, enhancer.trauma - dt * decayRate)
    else
        enhancer.trauma = 0
    end

    -- Subtle Elemental Border Glow (scaled by hit intensity across all 9 elements)
    local borderShown = false
    local bestBorderAlpha = 0
    local bestBorderProf = nil
    local bestBorderElem = elem

    if (enhancer.elemGlowTimer or 0) > 0.01 then
        enhancer.elemGlowTimer = math.max(0, enhancer.elemGlowTimer - dt)
        stillActive = true
        local glowFrac = enhancer.elemGlowTimer / math.max(0.1, enhancer.elemGlowDuration or 0.35)
        local elemInt = enhancer.elemIntensity or 0.5
        local prof = ns.Elements and ns.Elements:GetProfile(elem)
        if elem == "FIRE" or elem == "HOLY" then
            enhancer.flashAlpha = math.max(enhancer.flashAlpha, glowFrac * (vanillaMode and 0.14 or 0.24) * elemInt)
        end
        if not vanillaMode and prof and prof.border and elem ~= "PHYSICAL" and elemInt >= 0.45 then
            local flicker = 1.0
            if elem == "FIRE" then
                flicker = 0.72 + 0.28 * math.sin(now * 24.0)
            elseif elem == "LIGHTNING" then
                flicker = (math.sin(now * 80.0) > 0) and 1.0 or 0.48
            elseif elem == "FROST" then
                flicker = 0.82 + 0.18 * math.cos(now * 36.0)
            elseif elem == "SHADOW" then
                flicker = 0.68 + 0.32 * math.sin(now * 16.0)
            elseif elem == "ARCANE" then
                flicker = 0.75 + 0.25 * math.sin(now * 30.0)
            elseif elem == "NATURE" then
                flicker = 0.78 + 0.22 * math.sin(now * 14.0)
            elseif elem == "HOLY" then
                flicker = 0.85 + 0.15 * math.sin(now * 20.0)
            end
            bestBorderAlpha = math.min(0.78, glowFrac * flicker * elemInt * 0.72)
            bestBorderProf = prof
            bestBorderElem = elem
            borderShown = true
        end
    else
        enhancer.elemGlowTimer = 0
    end

    -- Continuous Elemental DoT indicator over Remaining Health
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
                local smolderAlpha = (0.08 + 0.05 * math.sin(now * 10.0)) * dotFade
                if enhancer.flashAlpha < smolderAlpha then
                    enhancer.flashR, enhancer.flashG, enhancer.flashB = dotProf.flash[1], dotProf.flash[2], dotProf.flash[3]
                    if enhancer.hitFlash then
                        enhancer.hitFlash:SetBlendMode("ADD")
                    end
                    enhancer.flashAlpha = smolderAlpha
                end
                dotBorderAlpha = (0.28 + 0.16 * math.sin(now * 14.0)) * dotFade
            elseif dotElem == "LIGHTNING" then
                dotBorderAlpha = (0.22 + 0.14 * math.sin(now * 32.0)) * dotFade
            elseif dotElem == "FROST" then
                local rimeAlpha = (0.07 + 0.03 * math.sin(now * 6.0)) * dotFade
                if enhancer.flashAlpha < rimeAlpha then
                    enhancer.flashR, enhancer.flashG, enhancer.flashB = dotProf.flash[1], dotProf.flash[2], dotProf.flash[3]
                    if enhancer.hitFlash then
                        enhancer.hitFlash:SetBlendMode("ADD")
                    end
                    enhancer.flashAlpha = rimeAlpha
                end
                dotBorderAlpha = (0.26 + 0.10 * math.sin(now * 7.0)) * dotFade
            elseif dotElem == "SHADOW" or dotElem == "HOLY" or dotElem == "NATURE" or dotElem == "ARCANE" then
                local auraAlpha = (0.07 + 0.04 * math.sin(now * 8.0)) * dotFade
                if enhancer.flashAlpha < auraAlpha then
                    enhancer.flashR, enhancer.flashG, enhancer.flashB = dotProf.flash[1], dotProf.flash[2], dotProf.flash[3]
                    if enhancer.hitFlash then
                        enhancer.hitFlash:SetBlendMode("ADD")
                    end
                    enhancer.flashAlpha = auraAlpha
                end
                dotBorderAlpha = (0.25 + 0.12 * math.sin(now * 9.0)) * dotFade
            else
                dotBorderAlpha = (0.24 + 0.10 * math.sin(now * 9.0)) * dotFade
            end

            if not vanillaMode and dotProf.border and dotBorderAlpha > bestBorderAlpha then
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
                enhancer.dotEmitTimer = vanillaMode and 0.36 or 0.28
                if dotElem == "LIGHTNING" and not vanillaMode then
                    ns.CombatFX:SpawnBarLightning(fillAnchor, 1, 0.11, 0.22 * dotFade)
                end
                ns.CombatFX:SpawnBarSparks(fillAnchor, nil, 1, spR, spG, spB, false, dotElem, (vanillaMode and 0.22 or 0.30) * dotFade)
            end
        end
    else
        enhancer.dotTimer = 0
    end

    if enhancer.elemBorder then
        if not vanillaMode and borderShown and bestBorderProf and bestBorderProf.border and bestBorderAlpha > 0.02 then
            enhancer.elemBorder:SetBorderColor(
                bestBorderProf.border[1],
                bestBorderProf.border[2],
                bestBorderProf.border[3],
                math.min(0.78, bestBorderAlpha),
                (bestBorderElem == "EARTH") and "BLEND" or "ADD"
            )
            enhancer.elemBorder:Show()
        else
            enhancer.elemBorder:Hide()
        end
    end

    -- Realistic double-beat cardiac curve ("lub-dub") for Execute border
    if enhancer.isExecute then
        stillActive = true
        local beatCycle = (now * 1.35) % 1.0
        local b1 = math.exp(-math.pow((beatCycle - 0.14) / 0.065, 2))
        local b2 = 0.72 * math.exp(-math.pow((beatCycle - 0.31) / 0.080, 2))
        local heartBeat = math.min(1.0, b1 + b2)
        local pulse = 0.28 + 0.64 * heartBeat
        enhancer.executeBorder:SetBorderColor(1.0, 0.14 + 0.16 * heartBeat, 0.12, pulse)
    end

    self:RenderEnhancer(enhancer, dx, dy)
    return stillActive
end

function UnitBars:RenderEnhancer(enhancer, dx, dy)
    local bar = enhancer.statusBar
    if not bar then
        return
    end

    local ubCfg = ns.Config:Get("unitBars")
    local vanillaMode = ubCfg and ubCfg.vanillaBarMode and true or false

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

    -- 3-Stage Delayed Damage Trail Ramp (trailHot -> trailHold -> trailFade)
    local hotC = enhancer.trailHotColor or { 1.00, 0.98, 0.90 }
    local holdC = enhancer.trailHoldColor or { 1.00, 0.90, 0.55 }
    local fadeC = enhancer.trailFadeColor or { 0.85, 0.16, 0.12 }
    local dissolveTimer = enhancer.trailDissolveTimer or 0
    if dissolveTimer > 0.01 then
        local rem = math.max(0, math.min(1.0, dissolveTimer / math.max(0.1, enhancer.trailDissolveDuration or 0.45)))
        local t = 1.0 - rem
        local r, g, b
        if t < 0.18 then
            local k = t / 0.18
            r = hotC[1] + (holdC[1] - hotC[1]) * k
            g = hotC[2] + (holdC[2] - hotC[2]) * k
            b = hotC[3] + (holdC[3] - hotC[3]) * k
        elseif t < 0.65 then
            local k = (t - 0.18) / 0.47
            r = holdC[1] + (fadeC[1] - holdC[1]) * k
            g = holdC[2] + (fadeC[2] - holdC[2]) * k
            b = holdC[3] + (fadeC[3] - holdC[3]) * k
        else
            r, g, b = fadeC[1], fadeC[2], fadeC[3]
        end
        local barAlpha = math.pow(rem, 1.18) * 0.92
        enhancer.trailBar:SetStatusBarColor(r, g, b, barAlpha)

        if enhancer.trailFragments and enhancer.trailChunkOverlay then
            local elemInt = enhancer.elemIntensity or 0.5
            if not vanillaMode and elemInt >= 0.20 then
                local elem = enhancer.activeElement or "PHYSICAL"
                local prof = ns.Elements and ns.Elements:GetProfile(elem)
                local spC = (prof and prof.spark) or holdC
                local altC = (prof and prof.sparkAlt) or holdC
                local pal = prof and prof.sparkPalette
                local chunkW = enhancer.trailChunkOverlay.fuiWidth or 18
                local activeCount = (elemInt >= 0.48) and #enhancer.trailFragments or 6

                for i = 1, #enhancer.trailFragments do
                    local f = enhancer.trailFragments[i]
                    local tex = f.tex
                    local glowTex = f.glowTex
                    if i <= activeCount then
                        local ox, oy
                        local popIn = math.min(1.0, t / 0.12)
                        local scale = (0.68 + 0.46 * popIn) * math.max(0.24, 1.0 - t * 0.65)
                        local curRot = (f.rot or 0) + (f.vRot or 0) * t
                        local col = (pal and pal[f.palIdx or 1]) or (f.isAlt and altC or spC)
                        local flicker = 0.78 + 0.22 * math.sin(t * (f.flickerSpeed or 20.0) + (f.wavePhase or 0))
                        local blend = "ADD"
                        local glowBlend = "ADD"
                        local glowCol = col

                        if elem == "FIRE" then
                            -- Thermal buoyancy rise + S-wave curl + temperature color cooling
                            local wave = math.sin(t * (f.waveFreq or 10.0) + (f.wavePhase or 0)) * 2.8
                            ox = f.u * chunkW + f.vx * t * 0.65 + wave
                            oy = f.v * targetH + f.vy * math.pow(t, 1.55)
                            if pal then
                                local stageIdx = math.min(4, math.max(1, math.floor(t * 3.6) + 1))
                                col = pal[stageIdx] or col
                            end
                        elseif elem == "LIGHTNING" then
                            -- Quantized discrete snap-teleports + high-frequency square-wave strobe
                            local qT = math.floor(t * 14.0) / 14.0
                            local jitterX = math.sin(qT * 95.0 + (f.wavePhase or 0)) * 3.2
                            local jitterY = math.cos(qT * 110.0 + (f.wavePhase or 0)) * 2.4
                            ox = f.u * chunkW + f.vx * qT + jitterX
                            oy = f.v * targetH + f.vy * qT + jitterY
                            flicker = (math.sin(t * (f.flickerSpeed or 50.0) + (f.wavePhase or 0)) > -0.15) and 1.0 or 0.28
                        elseif elem == "FROST" then
                            -- 3-phase freeze lock & shatter drop
                            if t < 0.20 then
                                local k = t / 0.20
                                ox = f.u * chunkW + f.vx * k * 0.25
                                oy = f.v * targetH + f.vy * k * 0.25
                            elseif t < 0.65 then
                                ox = f.u * chunkW + f.vx * 0.25 + math.sin(t * 45.0 + (f.wavePhase or 0)) * 0.6
                                oy = f.v * targetH + f.vy * 0.25
                                curRot = (f.rot or 0) + (f.vRot or 0) * 0.20
                                flicker = 0.85 + 0.15 * math.sin(t * 60.0 + i)
                            else
                                local dropT = (t - 0.65) / 0.35
                                ox = f.u * chunkW + f.vx * (0.25 + dropT * 0.45)
                                oy = f.v * targetH + f.vy * 0.25 - (dropT * dropT * 24.0)
                            end
                        elseif elem == "EARTH" then
                            -- Heavy gravity stone drop + quartz glints
                            ox = f.u * chunkW + f.vx * t
                            oy = f.v * targetH + f.vy * (t * t * 1.35)
                            blend = f.isAlt and "ADD" or "BLEND"
                            glowBlend = "BLEND"
                            glowCol = { 0.14, 0.10, 0.06 }
                        elseif elem == "SHADOW" then
                            -- Inward void implosion vortex toward wound center + dark obsidian backing halo
                            local implode = math.max(0.12, 1.0 - t * 0.78)
                            local swirlX = math.cos(t * 9.0 + (f.wavePhase or 0)) * 2.5 * implode
                            local swirlY = math.sin(t * 9.0 + (f.wavePhase or 0)) * 2.0 * implode
                            ox = (f.u * chunkW) * implode + swirlX
                            oy = (f.v * targetH) * implode + swirlY
                            glowBlend = "BLEND"
                            glowCol = { 0.07, 0.01, 0.14 }
                        elseif elem == "ARCANE" then
                            -- Expanding mana rings & harmonic counter-rotating runes
                            ox = f.u * chunkW + f.vx * t * 0.55
                            oy = f.v * targetH + f.vy * t * 0.55
                            if f.shapeRoll == 0 then
                                scale = (0.55 + t * 1.05)
                            end
                        elseif elem == "NATURE" then
                            -- Swirling figure-8 bio-spores & leaf streaks
                            local figX = math.sin(t * (f.waveFreq or 8.0) + (f.wavePhase or 0)) * 3.4
                            local figY = math.sin(t * (f.waveFreq or 8.0) * 2.0 + (f.wavePhase or 0)) * 2.2
                            ox = f.u * chunkW + f.vx * t * 0.60 + figX
                            oy = f.v * targetH + f.vy * t * 0.75 + figY
                        elseif elem == "HOLY" then
                            -- Ascending golden crosses & light motes
                            ox = f.u * chunkW + math.sin(t * 6.0 + (f.wavePhase or 0)) * 1.4
                            oy = f.v * targetH + f.vy * t
                        else
                            -- PHYSICAL: diagonal cleave slash streaks + ballistic steel sparks
                            ox = f.u * chunkW + f.vx * t
                            oy = f.v * targetH + f.vy * t - (t * t * 16.0)
                        end

                        local fAlpha = math.min(0.94, rem * 0.90 * flicker)
                        if glowTex then
                            glowTex:SetBlendMode(glowBlend)
                            glowTex:ClearAllPoints()
                            glowTex:SetPoint("CENTER", enhancer.trailChunkOverlay, "CENTER", ox, oy)
                            glowTex:SetSize(f.sizeW * scale * 1.75, f.sizeH * scale * 1.75)
                            local gAlpha = (glowBlend == "BLEND") and (fAlpha * 0.65) or (fAlpha * 0.42)
                            glowTex:SetVertexColor(glowCol[1], glowCol[2], glowCol[3], gAlpha)
                            glowTex:Show()
                        end

                        tex:SetBlendMode(blend)
                        tex:ClearAllPoints()
                        tex:SetPoint("CENTER", enhancer.trailChunkOverlay, "CENTER", ox, oy)
                        tex:SetSize(f.sizeW * scale, f.sizeH * scale)
                        if tex.SetRotation then
                            tex:SetRotation(curRot)
                        end
                        tex:SetVertexColor(col[1], col[2], col[3], fAlpha)
                        tex:Show()
                    else
                        if glowTex then
                            glowTex:Hide()
                        end
                        tex:Hide()
                    end
                end
            else
                for i = 1, #enhancer.trailFragments do
                    if enhancer.trailFragments[i].glowTex then
                        enhancer.trailFragments[i].glowTex:Hide()
                    end
                    enhancer.trailFragments[i].tex:Hide()
                end
            end
        end
    else
        enhancer.trailBar:SetStatusBarColor(fadeC[1], fadeC[2], fadeC[3], 0.0)
        if enhancer.trailFragments then
            for i = 1, #enhancer.trailFragments do
                if enhancer.trailFragments[i].glowTex then
                    enhancer.trailFragments[i].glowTex:Hide()
                end
                enhancer.trailFragments[i].tex:Hide()
            end
        end
    end

    local showCut = (enhancer.cutAlpha > 0.01)
    if not enhancer.isSecretHealth then
        showCut = showCut and (enhancer.displayFrac > 0.01 and enhancer.displayFrac < 0.99)
    end
    if showCut then
        if enhancer.cutGlow then
            enhancer.cutGlow:SetAlpha(math.min(0.85, enhancer.cutAlpha * 0.62))
            enhancer.cutGlow:Show()
        end
        enhancer.cutLine:SetAlpha(enhancer.cutAlpha)
        enhancer.cutLine:Show()
        local rotProgress = (1.0 - enhancer.cutAlpha) * 2.8
        if enhancer.cutFlare then
            enhancer.cutFlare:SetAlpha(math.min(1.0, enhancer.cutAlpha * 1.15))
            if enhancer.cutFlare.SetRotation then
                enhancer.cutFlare:SetRotation(rotProgress)
            end
            enhancer.cutFlare:Show()
        end
        if enhancer.cutSubFlare then
            enhancer.cutSubFlare:SetAlpha(math.min(0.92, enhancer.cutAlpha * 0.95))
            if enhancer.cutSubFlare.SetRotation then
                enhancer.cutSubFlare:SetRotation(-rotProgress * 1.35)
            end
            enhancer.cutSubFlare:Show()
        end
    else
        if enhancer.cutGlow then
            enhancer.cutGlow:Hide()
        end
        enhancer.cutLine:Hide()
        if enhancer.cutFlare then
            enhancer.cutFlare:Hide()
        end
        if enhancer.cutSubFlare then
            enhancer.cutSubFlare:Hide()
        end
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
