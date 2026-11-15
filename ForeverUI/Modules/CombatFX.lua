local addonName, ns = ...
local CombatFX = {}
ns.CombatFX = CombatFX

local fxCanvas = CreateFrame("Frame", "ForeverUI_FXCanvas", UIParent)
fxCanvas:SetAllPoints(UIParent)
fxCanvas:SetFrameStrata("HIGH")
fxCanvas:EnableMouse(false)

-- ============================================================================
-- 1. POOLED BAR SHATTER SPARKS & DEBRIS SHARDS
--    Anchored directly to the target frame via SetPoint("CENTER", anchorFrame, "CENTER", dx, dy)
--    so we NEVER call Frame:GetCenter() on Restricted Regions!
-- ============================================================================
local sparkPool = {}
local activeSparks = {}

local function AcquireSpark()
    local sp = table.remove(sparkPool)
    if not sp then
        local tex = fxCanvas:CreateTexture(nil, "OVERLAY")
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        sp = { tex = tex }
    end
    sp.tex:Show()
    return sp
end

local function ReleaseSpark(sp)
    sp.tex:Hide()
    sp.anchorFrame = nil
    if sp.tex.SetRotation then
        sp.tex:SetRotation(0)
    end
    table.insert(sparkPool, sp)
end

local function EnsureSparkTicker()
    ns.Events:RegisterTicker("CombatFX_Sparks", function(dt)
        for i = #activeSparks, 1, -1 do
            local sp = activeSparks[i]
            sp.age = sp.age + dt
            if sp.age >= sp.duration then
                ReleaseSpark(sp)
                table.remove(activeSparks, i)
            else
                local t = sp.age / sp.duration
                sp.x = sp.x + sp.vx * dt
                if sp.waveAmp and sp.waveAmp ~= 0 then
                    sp.x = sp.x + math.sin(sp.age * sp.waveFreq + sp.wavePhase) * sp.waveAmp * dt
                end
                sp.y = sp.y + sp.vy * dt
                sp.vy = sp.vy - sp.gravity * dt

                local maxA = sp.maxAlpha or 1.0
                local alpha = (1.0 - t) * maxA
                if sp.elem == "FIRE" then
                    -- Embers burn white-gold -> fiery scarlet -> deep crimson
                    local r = 1.0
                    local g = math.max(0.08, 0.76 - t * 0.68)
                    local b = math.max(0.01, 0.18 - t * 0.18)
                    sp.tex:SetVertexColor(r, g, b, alpha)
                else
                    sp.tex:SetAlpha(alpha)
                end

                sp.tex:ClearAllPoints()
                sp.tex:SetPoint("CENTER", sp.anchorFrame or fxCanvas, "CENTER", sp.x, sp.y)
                if sp.vRot ~= 0 then
                    sp.rot = sp.rot + sp.vRot * dt
                    if sp.tex.SetRotation then
                        sp.tex:SetRotation(sp.rot)
                    end
                end
            end
        end
        return #activeSparks > 0
    end)
end

function CombatFX:SpawnBarSparks(anchorFrame, cutFraction, count, r, g, b, isShards, elementKey, intensity)
    local cfg = ns.Config:Get("combatFX")
    if not cfg or not cfg.enabled or not cfg.sparksEnabled or not anchorFrame then
        return
    end

    local elem = elementKey or "PHYSICAL"
    local scale = math.max(0.22, math.min(1.0, intensity or 0.85))
    local sizeMult = 0.56 + 0.44 * scale
    local speedMult = 0.52 + 0.48 * scale
    local maxAlpha = math.min(1.0, 0.48 + 0.52 * scale)

    local prof = ns.Elements and ns.Elements:GetProfile(elem) or nil
    local barW = anchorFrame.fuiWidth or 118
    local baseX = 0
    if not isShards and cutFraction and not ns.IsSecret(cutFraction) and barW > 12 then
        baseX = (cutFraction - 0.5) * barW
    end

    count = count or 8
    r = r or (prof and prof.spark[1]) or 1.0
    g = g or (prof and prof.spark[2]) or 0.78
    b = b or (prof and prof.spark[3]) or 0.20
    local altR = (prof and prof.sparkAlt and prof.sparkAlt[1]) or 0.95
    local altG = (prof and prof.sparkAlt and prof.sparkAlt[2]) or 0.95
    local altB = (prof and prof.sparkAlt and prof.sparkAlt[3]) or 0.98

    local useWow = cfg.wowSpellColors and true or false
    local barH = anchorFrame.fuiHeight or 12
    local spreadW = barW * 0.92

    for i = 1, count do
        local sp = AcquireSpark()
        local spawnX = baseX
        if isShards or not cutFraction then
            spawnX = (math.random() - 0.5) * spreadW
        else
            spawnX = baseX + (math.random() * 8 - 4) * sizeMult
        end
        local spawnY = (math.random() - 0.5) * (barH * 0.85)

        local angle = -math.pi * 0.1 + math.random() * math.pi * 1.2
        local speed = (55 + math.random() * 135) * speedMult
        local size = (isShards and (2.8 + math.random() * 3.0) or (2.1 + math.random() * 2.1)) * sizeMult

        sp.anchorFrame = anchorFrame
        sp.elem = elem
        sp.maxAlpha = maxAlpha
        sp.x = spawnX
        sp.y = spawnY
        sp.vx = math.cos(angle) * speed * (math.random() > 0.5 and 1 or -1)
        sp.vy = math.abs(math.sin(angle)) * speed + 22 * speedMult
        sp.gravity = 280
        sp.waveAmp = 0
        sp.waveFreq = 0
        sp.wavePhase = 0
        sp.age = 0
        sp.duration = (isShards and (0.52 + math.random() * 0.34) or (0.30 + math.random() * 0.22)) * (0.72 + 0.28 * scale)
        sp.rot = math.random() * 6.28
        sp.vRot = isShards and ((math.random() - 0.5) * 14) or 0

        if useWow and not isShards and elem ~= "EARTH" then
            sp.tex:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        else
            sp.tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        end

        if elem == "FIRE" then
            -- Buoyant rising fire embers that curl upward off the burning bar
            sp.vx = (math.random() - 0.5) * 26 * speedMult
            sp.vy = (20 + math.random() * 44) * speedMult
            sp.gravity = -185 * speedMult
            sp.waveAmp = (24 + math.random() * 20) * speedMult
            sp.waveFreq = 9 + math.random() * 7
            sp.wavePhase = math.random() * 6.28
            sp.duration = (0.44 + math.random() * 0.34) * (0.68 + 0.32 * scale)
            sp.vRot = (math.random() - 0.5) * 8
            sp.tex:SetBlendMode("ADD")
            local fSize = (useWow and not isShards) and (size * 2.4) or (size * 1.25)
            sp.tex:SetSize(fSize, fSize)
        elseif elem == "LIGHTNING" then
            -- High-voltage darting electric sparks
            local fastSpeed = (95 + math.random() * 175) * speedMult
            sp.vx = math.cos(angle) * fastSpeed * (math.random() > 0.5 and 1 or -1)
            sp.vy = (math.random() - 0.35) * fastSpeed
            sp.gravity = 75
            sp.duration = (0.20 + math.random() * 0.18) * (0.72 + 0.28 * scale)
            sp.vRot = (math.random() - 0.5) * 18
            sp.tex:SetBlendMode("ADD")
            sp.tex:SetSize(size * (useWow and 2.2 or 1.6), size * (useWow and 1.25 or 0.75))
        elseif elem == "EARTH" then
            -- Solid opaque dark-umber & sandstone rock boulders plummeting straight down (never additive orange!)
            sp.vx = (math.random() - 0.5) * 68 * speedMult
            sp.vy = (28 + math.random() * 54) * speedMult
            sp.gravity = 620
            sp.duration = (0.44 + math.random() * 0.28) * (0.74 + 0.26 * scale)
            sp.vRot = (math.random() - 0.5) * 22
            sp.tex:SetBlendMode("BLEND")
            sp.tex:SetSize(size * 1.85, size * 1.40)
        elseif elem == "FROST" then
            -- Crystalline spinning ice shards shattering downward
            sp.vx = (math.random() - 0.5) * 110 * speedMult
            sp.vy = (18 + math.random() * 56) * speedMult
            sp.gravity = 390
            sp.duration = (0.40 + math.random() * 0.26) * (0.74 + 0.26 * scale)
            sp.vRot = (math.random() - 0.5) * 16
            sp.tex:SetBlendMode("ADD")
            sp.tex:SetSize(size * (useWow and 2.3 or 1.85), size * (useWow and 1.1 or 0.65))
        elseif elem == "SHADOW" or elem == "NATURE" or elem == "HOLY" or elem == "ARCANE" then
            -- Hovering/drifting school motes
            sp.vx = (math.random() - 0.5) * 32 * speedMult
            sp.vy = (8 + math.random() * 24) * speedMult
            sp.gravity = (elem == "HOLY") and (-40 * speedMult) or (-25 * speedMult)
            sp.waveAmp = (16 + math.random() * 14) * speedMult
            sp.waveFreq = 6 + math.random() * 5
            sp.wavePhase = math.random() * 6.28
            sp.duration = (0.46 + math.random() * 0.30) * (0.70 + 0.30 * scale)
            sp.tex:SetBlendMode("ADD")
            local mSize = (useWow and not isShards) and (size * 2.4) or (size * 1.35)
            sp.tex:SetSize(mSize, mSize)
        elseif isShards then
            sp.tex:SetBlendMode("BLEND")
            sp.tex:SetSize(size * 1.4, size * 0.9)
        else
            sp.tex:SetBlendMode("ADD")
            local pSize = (useWow and not isShards) and (size * 2.1) or size
            sp.tex:SetSize(pSize, pSize)
        end

        if sp.vRot ~= 0 and sp.tex.SetRotation then
            sp.tex:SetRotation(sp.rot)
        end

        if math.random() > 0.35 then
            sp.tex:SetVertexColor(r, g, b, maxAlpha)
        else
            sp.tex:SetVertexColor(altR, altG, altB, maxAlpha)
        end

        sp.tex:ClearAllPoints()
        sp.tex:SetPoint("CENTER", anchorFrame, "CENTER", sp.x, sp.y)
        table.insert(activeSparks, sp)
    end

    EnsureSparkTicker()
end

-- ============================================================================
-- 1B. POOLED JAGGED LIGHTNING CRACKLE ARCS
--     Uses a pooled holder Frame + rotated additive segment Textures so it
--     NEVER triggers Line:SetStartPoint Frame dependency errors on nameplates,
--     and hiding bolt.holder guarantees all segments vanish cleanly!
-- ============================================================================
local BOLT_SEGMENTS = 5
local boltPool = {}
local activeBolts = {}

local function AcquireLightningBolt()
    local bolt = table.remove(boltPool)
    if not bolt then
        local holder = CreateFrame("Frame", nil, fxCanvas)
        holder:SetSize(120, 14)

        local glowLines = {}
        local coreLines = {}
        for i = 1, BOLT_SEGMENTS do
            local glow = holder:CreateTexture(nil, "OVERLAY", nil, 5)
            glow:SetTexture("Interface\\Buttons\\WHITE8X8")
            glow:SetBlendMode("ADD")

            local core = holder:CreateTexture(nil, "OVERLAY", nil, 7)
            core:SetTexture("Interface\\Buttons\\WHITE8X8")
            core:SetBlendMode("ADD")

            glowLines[i] = glow
            coreLines[i] = core
        end
        bolt = {
            holder = holder,
            glowLines = glowLines,
            coreLines = coreLines,
        }
    end
    bolt.holder:Show()
    bolt.holder:SetAlpha(1.0)
    for i = 1, BOLT_SEGMENTS do
        bolt.glowLines[i]:Show()
        bolt.coreLines[i]:Show()
    end
    return bolt
end

local function ReleaseLightningBolt(bolt)
    for i = 1, BOLT_SEGMENTS do
        bolt.glowLines[i]:Hide()
        bolt.coreLines[i]:Hide()
    end
    bolt.holder:Hide()
    bolt.holder:ClearAllPoints()
    bolt.anchorFrame = nil
    table.insert(boltPool, bolt)
end

local function JitterLightningBoltGeometry(bolt, alpha)
    local anchor = bolt.anchorFrame or fxCanvas
    bolt.holder:ClearAllPoints()
    bolt.holder:SetPoint("CENTER", anchor, "CENTER", 0, 0)

    local scale = bolt.scale or 0.85
    local currentW = (anchor and anchor.fuiWidth) or bolt.width or 118
    local currentH = (anchor and anchor.fuiHeight) or bolt.height or 12
    local effAlpha = alpha * (bolt.maxAlpha or 1.0)

    if bolt.mode == "EARTH" then
        -- Matte stone tectonic fault crack running diagonally/vertically across the remaining HP bar
        local centerX = (bolt.crackBiasX or 0) * (currentW * 0.70)
        local prevX = centerX + (math.random() * 4 - 2) * scale
        local prevY = -currentH * 0.52
        local glowThick = 1.6 + 1.4 * scale
        local coreThick = 1.1 + 1.1 * scale

        for i = 1, BOLT_SEGMENTS do
            local frac = i / BOLT_SEGMENTS
            local nextX = centerX + (math.random() * 9 - 4.5) * scale
            local nextY = (-0.52 + frac * 1.04) * currentH

            local dx = nextX - prevX
            local dy = nextY - prevY
            local segLen = math.max(1.8, math.sqrt(dx * dx + dy * dy))
            local midX = (prevX + nextX) * 0.5
            local midY = (prevY + nextY) * 0.5
            local angle = math.atan2(dy, dx)

            local glow = bolt.glowLines[i]
            glow:SetBlendMode("BLEND")
            glow:ClearAllPoints()
            glow:SetPoint("CENTER", bolt.holder, "CENTER", midX + 0.6, midY)
            glow:SetSize(segLen + 1.0, glowThick)
            glow:SetVertexColor(0.84, 0.70, 0.44, effAlpha * 0.90)
            if glow.SetRotation then
                glow:SetRotation(angle)
            end

            local core = bolt.coreLines[i]
            core:SetBlendMode("BLEND")
            core:ClearAllPoints()
            core:SetPoint("CENTER", bolt.holder, "CENTER", midX, midY)
            core:SetSize(segLen + 0.6, coreThick)
            core:SetVertexColor(0.08, 0.05, 0.02, effAlpha)
            if core.SetRotation then
                core:SetRotation(angle)
            end

            prevX = nextX
            prevY = nextY
        end
        return
    end

    local w = currentW * (0.38 + 0.56 * scale)
    local h = currentH * (0.45 + 0.45 * scale)
    local glowThick = 1.0 + 1.3 * scale
    local coreThick = 0.6 + 0.6 * scale

    local prevX = -w * 0.46 + (math.random() * 4 - 2) * scale
    local prevY = (math.random() - 0.5) * (h * 0.85)

    for i = 1, BOLT_SEGMENTS do
        local frac = i / BOLT_SEGMENTS
        local nextX = (-0.46 + frac * 0.92) * w + (math.random() * 6 - 3) * scale
        local nextY = (math.random() - 0.5) * (h * 1.15)

        local dx = nextX - prevX
        local dy = nextY - prevY
        local segLen = math.max(1.8, math.sqrt(dx * dx + dy * dy))
        local midX = (prevX + nextX) * 0.5
        local midY = (prevY + nextY) * 0.5
        local angle = math.atan2(dy, dx)

        local glow = bolt.glowLines[i]
        glow:SetBlendMode("ADD")
        glow:ClearAllPoints()
        glow:SetPoint("CENTER", bolt.holder, "CENTER", midX, midY)
        glow:SetSize(segLen + 1.0, glowThick)
        glow:SetVertexColor(0.18, 0.76, 1.00, effAlpha * 0.65)
        if glow.SetRotation then
            glow:SetRotation(angle)
        end

        local core = bolt.coreLines[i]
        core:SetBlendMode("ADD")
        core:ClearAllPoints()
        core:SetPoint("CENTER", bolt.holder, "CENTER", midX, midY)
        core:SetSize(segLen + 0.6, coreThick)
        core:SetVertexColor(0.88, 0.98, 1.00, effAlpha * 0.85)
        if core.SetRotation then
            core:SetRotation(angle)
        end

        prevX = nextX
        prevY = nextY
    end
end

local function EnsureLightningTicker()
    ns.Events:RegisterTicker("CombatFX_Lightning", function(dt)
        for i = #activeBolts, 1, -1 do
            local bolt = activeBolts[i]
            bolt.age = bolt.age + dt
            bolt.reCrackleTimer = bolt.reCrackleTimer - dt
            local anchorGone = (not bolt.anchorFrame)
                or (bolt.anchorFrame.IsShown and not bolt.anchorFrame:IsShown())
            if bolt.age >= bolt.duration or anchorGone then
                ReleaseLightningBolt(bolt)
                table.remove(activeBolts, i)
            else
                local alpha = math.max(0, 1.0 - (bolt.age / bolt.duration) * 0.85)
                if bolt.reCrackleTimer <= 0 then
                    bolt.reCrackleTimer = 0.036
                    JitterLightningBoltGeometry(bolt, alpha)
                else
                    local effAlpha = alpha * (bolt.maxAlpha or 1.0)
                    bolt.holder:SetAlpha(effAlpha)
                end
            end
        end
        return #activeBolts > 0
    end)
end

function CombatFX:SpawnBarLightning(anchorFrame, boltCount, duration, intensity)
    local cfg = ns.Config:Get("combatFX")
    if not cfg or not cfg.enabled or not anchorFrame then
        return
    end
    boltCount = boltCount or 2
    duration = duration or 0.30
    local scale = math.max(0.22, math.min(1.0, intensity or 0.85))
    local barW = anchorFrame.fuiWidth or 118
    local barH = anchorFrame.fuiHeight or 12

    for i = 1, boltCount do
        local bolt = AcquireLightningBolt()
        bolt.mode = "LIGHTNING"
        bolt.anchorFrame = anchorFrame
        bolt.width = barW
        bolt.height = barH
        bolt.scale = scale
        bolt.maxAlpha = math.min(0.82, 0.28 + 0.54 * scale)
        bolt.age = 0
        bolt.duration = duration + (i - 1) * 0.03
        bolt.reCrackleTimer = 0
        table.insert(activeBolts, bolt)
        JitterLightningBoltGeometry(bolt, 1.0)
    end

    EnsureLightningTicker()
end

function CombatFX:SpawnBarEarthCracks(anchorFrame, crackCount, duration, intensity)
    local cfg = ns.Config:Get("combatFX")
    if not cfg or not cfg.enabled or not anchorFrame then
        return
    end
    crackCount = crackCount or 2
    duration = duration or 0.38
    local scale = math.max(0.28, math.min(1.0, intensity or 0.85))
    local barW = anchorFrame.fuiWidth or 118
    local barH = anchorFrame.fuiHeight or 12

    for i = 1, crackCount do
        local bolt = AcquireLightningBolt()
        bolt.mode = "EARTH"
        bolt.anchorFrame = anchorFrame
        bolt.width = barW
        bolt.height = barH
        bolt.scale = scale
        bolt.maxAlpha = math.min(0.95, 0.50 + 0.45 * scale)
        bolt.age = 0
        bolt.duration = duration + (i - 1) * 0.05
        bolt.reCrackleTimer = 999
        if crackCount <= 1 then
            bolt.crackBiasX = (math.random() - 0.5) * 0.35
        else
            bolt.crackBiasX = ((i - 1) / (crackCount - 1) - 0.5) * 0.65
        end
        table.insert(activeBolts, bolt)
        JitterLightningBoltGeometry(bolt, 1.0)
    end

    EnsureLightningTicker()
end

-- ============================================================================
-- 2. VANILLA+ CRACKED & TILTED DEATH BAR
--    Clean, grounded Warcraft aesthetic:
--      - Strips clutter to leave a bare weathered stone-gray bar (UI-StatusBar)
--      - Brief subtle impact flash + tactile 1.15x micro-punch
--      - Crisp CreateLine fracture fissures that etch across the bar
--      - Left-hinged damped spring tilt (honoring npCfg.deathTiltDegrees)
--      - Gentle gravity settle and smooth alpha fadeout
--    Anchored directly to barFrame via SetPoint("CENTER", db.anchorFrame, "CENTER", cx, cy)
--    so we NEVER call Frame:GetCenter() on Restricted Regions!
-- ============================================================================
local CRACK_SEGMENTS = {
    { x1 = 0.22, y1 =  0.48, x2 = 0.25, y2 =  0.10, w = 1.4 },
    { x1 = 0.25, y1 =  0.10, x2 = 0.22, y2 = -0.22, w = 1.4 },
    { x1 = 0.22, y1 = -0.22, x2 = 0.27, y2 = -0.48, w = 1.3 },
    { x1 = 0.51, y1 =  0.48, x2 = 0.47, y2 =  0.15, w = 1.8 },
    { x1 = 0.47, y1 =  0.15, x2 = 0.54, y2 = -0.12, w = 1.8 },
    { x1 = 0.54, y1 = -0.12, x2 = 0.49, y2 = -0.48, w = 1.7 },
    { x1 = 0.47, y1 =  0.15, x2 = 0.39, y2 = -0.04, w = 1.1 },
    { x1 = 0.54, y1 = -0.12, x2 = 0.63, y2 =  0.10, w = 1.1 },
    { x1 = 0.79, y1 = -0.48, x2 = 0.76, y2 = -0.06, w = 1.4 },
    { x1 = 0.76, y1 = -0.06, x2 = 0.81, y2 =  0.24, w = 1.4 },
    { x1 = 0.81, y1 =  0.24, x2 = 0.77, y2 =  0.48, w = 1.3 },
}

local deathBarPool = {}
local activeDeathBars = {}

local function AcquireDeathBar()
    local db = table.remove(deathBarPool)
    if not db then
        local holder = CreateFrame("Frame", nil, fxCanvas)
        holder:SetSize(120, 14)
        holder:SetFrameLevel(35)

        local borderTex = holder:CreateTexture(nil, "BACKGROUND", nil, 0)
        borderTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        borderTex:SetVertexColor(0.06, 0.06, 0.07, 0.96)

        local trimTex = holder:CreateTexture(nil, "BORDER", nil, 1)
        trimTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        trimTex:SetVertexColor(0.36, 0.34, 0.30, 0.95)

        local fillTex = holder:CreateTexture(nil, "ARTWORK", nil, 1)
        fillTex:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        fillTex:SetVertexColor(0.30, 0.30, 0.34, 1.0)

        local bevelTex = holder:CreateTexture(nil, "ARTWORK", nil, 2)
        bevelTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        bevelTex:SetVertexColor(1.0, 1.0, 1.0, 0.12)

        local innerShadowTex = holder:CreateTexture(nil, "ARTWORK", nil, 2)
        innerShadowTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        innerShadowTex:SetVertexColor(0.0, 0.0, 0.0, 0.22)

        local flashTex = holder:CreateTexture(nil, "OVERLAY", nil, 1)
        flashTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        flashTex:SetBlendMode("ADD")
        flashTex:SetVertexColor(1.0, 0.96, 0.88, 0.52)

        local cracks = {}
        for i = 1, #CRACK_SEGMENTS do
            local spec = CRACK_SEGMENTS[i]
            local highlightLine = holder:CreateLine(nil, "OVERLAY", nil, 2)
            highlightLine:SetTexture("Interface\\Buttons\\WHITE8X8")
            highlightLine:SetVertexColor(0.80, 0.80, 0.84, 0.78)
            highlightLine:SetThickness(spec.w + 0.7)

            local darkLine = holder:CreateLine(nil, "OVERLAY", nil, 3)
            darkLine:SetTexture("Interface\\Buttons\\WHITE8X8")
            darkLine:SetVertexColor(0.03, 0.03, 0.04, 0.96)
            darkLine:SetThickness(spec.w)

            cracks[i] = {
                spec = spec,
                highlight = highlightLine,
                dark = darkLine,
            }
        end

        db = {
            holder = holder,
            borderTex = borderTex,
            trimTex = trimTex,
            fillTex = fillTex,
            bevelTex = bevelTex,
            innerShadowTex = innerShadowTex,
            flashTex = flashTex,
            cracks = cracks,
        }
    end
    db.holder:Show()
    db.holder:SetAlpha(1.0)
    return db
end

local function ReleaseDeathBar(db)
    db.holder:Hide()
    db.anchorFrame = nil
    table.insert(deathBarPool, db)
end

local function UpdateDeathBarGeometry(db, thetaRad)
    local w = db.width
    local h = db.height
    local cosT = math.cos(thetaRad)
    local sinT = math.sin(thetaRad)

    -- Left-edge hinge (-w * 0.5, 0) relative to db.anchorFrame's CENTER
    local hx = (-w * 0.5) + db.shakeDx
    local hy = -db.dropY + db.shakeDy
    local cx = hx + (w * 0.5) * cosT
    local cy = hy + (w * 0.5) * sinT

    db.holder:ClearAllPoints()
    db.holder:SetPoint("CENTER", db.anchorFrame or fxCanvas, "CENTER", cx, cy)
    db.holder:SetSize(w, h)

    local punchedH = h * db.barPunchY
    local fillC = db.fillC or { 0.30, 0.30, 0.34 }
    local trimC = db.trimC or { 0.36, 0.34, 0.30 }
    local crackC = db.crackC or { 0.80, 0.80, 0.84 }
    local darkC = db.darkC or { 0.03, 0.03, 0.04 }
    local flashC = db.flashC or { 1.0, 0.96, 0.88 }

    db.borderTex:ClearAllPoints()
    db.borderTex:SetPoint("CENTER", db.holder, "CENTER", 0, 0)
    db.borderTex:SetSize(w + 4, punchedH + 4)

    db.trimTex:ClearAllPoints()
    db.trimTex:SetPoint("CENTER", db.holder, "CENTER", 0, 0)
    db.trimTex:SetSize(w + 2, punchedH + 2)
    db.trimTex:SetVertexColor(trimC[1], trimC[2], trimC[3], 0.95)

    db.fillTex:ClearAllPoints()
    db.fillTex:SetPoint("CENTER", db.holder, "CENTER", 0, 0)
    db.fillTex:SetSize(w, punchedH)
    db.fillTex:SetVertexColor(fillC[1], fillC[2], fillC[3], 1.0)

    local bevelLy = punchedH * 0.25
    db.bevelTex:ClearAllPoints()
    db.bevelTex:SetPoint("CENTER", db.holder, "CENTER", -bevelLy * sinT, bevelLy * cosT)
    db.bevelTex:SetSize(w, punchedH * 0.44)

    local innerLy = -punchedH * 0.25
    db.innerShadowTex:ClearAllPoints()
    db.innerShadowTex:SetPoint("CENTER", db.holder, "CENTER", -innerLy * sinT, innerLy * cosT)
    db.innerShadowTex:SetSize(w, punchedH * 0.44)

    db.flashTex:ClearAllPoints()
    db.flashTex:SetPoint("CENTER", db.holder, "CENTER", 0, 0)
    db.flashTex:SetSize(w, punchedH)
    if db.flashAlpha > 0.01 then
        db.flashTex:SetVertexColor(flashC[1], flashC[2], flashC[3], db.flashAlpha)
        db.flashTex:Show()
    else
        db.flashTex:Hide()
    end

    if db.fillTex.SetRotation then
        db.borderTex:SetRotation(thetaRad)
        db.trimTex:SetRotation(thetaRad)
        db.fillTex:SetRotation(thetaRad)
        db.bevelTex:SetRotation(thetaRad)
        db.innerShadowTex:SetRotation(thetaRad)
        db.flashTex:SetRotation(thetaRad)
    end

    local crackGrow = math.min(1.0, (db.age / 0.055))
    for i = 1, #db.cracks do
        local c = db.cracks[i]
        local s = c.spec
        local x2 = s.x1 + (s.x2 - s.x1) * crackGrow
        local y2 = s.y1 + (s.y2 - s.y1) * crackGrow

        local lx1 = (s.x1 - 0.5) * w
        local ly1 = s.y1 * punchedH
        local lx2 = (x2 - 0.5) * w
        local ly2 = y2 * punchedH

        local rx1 = lx1 * cosT - ly1 * sinT
        local ry1 = lx1 * sinT + ly1 * cosT
        local rx2 = lx2 * cosT - ly2 * sinT
        local ry2 = lx2 * sinT + ly2 * cosT

        c.highlight:SetVertexColor(crackC[1], crackC[2], crackC[3], 0.78)
        c.highlight:SetStartPoint("CENTER", db.holder, rx1 + 0.6, ry1)
        c.highlight:SetEndPoint("CENTER", db.holder, rx2 + 0.6, ry2)

        c.dark:SetVertexColor(darkC[1], darkC[2], darkC[3], 0.96)
        c.dark:SetStartPoint("CENTER", db.holder, rx1, ry1)
        c.dark:SetEndPoint("CENTER", db.holder, rx2, ry2)
    end
end

local function EnsureDeathBarTicker()
    ns.Events:RegisterTicker("CombatFX_DeathBars", function(dt, now)
        for i = #activeDeathBars, 1, -1 do
            local db = activeDeathBars[i]
            db.age = db.age + dt
            local totalDuration = db.holdTime + db.fadeTime
            if db.age >= totalDuration then
                ReleaseDeathBar(db)
                table.remove(activeDeathBars, i)
            else
                if db.flashAlpha > 0 then
                    db.flashAlpha = math.max(0, db.flashAlpha - dt * 4.2)
                end
                db.barPunchY = db.barPunchY + (1.0 - db.barPunchY) * math.min(1.0, dt * 14.0)

                if db.trauma > 0.01 then
                    local p = db.trauma * db.trauma
                    db.shakeDx = math.sin(now * 82.0) * 4.2 * p
                    db.shakeDy = math.cos(now * 92.0) * 2.8 * p
                    db.trauma = math.max(0, db.trauma - dt * 4.2)
                else
                    db.trauma = 0
                    db.shakeDx = 0
                    db.shakeDy = 0
                end

                local spring = (db.targetTiltDeg - db.tiltDeg) * 34.0
                db.tiltVel = (db.tiltVel + spring * dt) * math.max(0, 1.0 - dt * 10.5)
                db.tiltDeg = db.tiltDeg + db.tiltVel * dt

                if db.age > 0.18 then
                    db.dropY = db.dropY + (db.age - 0.18) * 18.0 * dt
                end

                if db.age > db.holdTime then
                    local fadeT = (db.age - db.holdTime) / db.fadeTime
                    db.holder:SetAlpha(math.max(0, 1.0 - fadeT))
                end

                UpdateDeathBarGeometry(db, math.rad(db.tiltDeg))
            end
        end
        return #activeDeathBars > 0
    end)
end

function CombatFX:ClearAnchorFX(...)
    local matchSet = {}
    local n = select("#", ...)
    for i = 1, n do
        local f = select(i, ...)
        if f then
            matchSet[f] = true
        end
    end
    if not next(matchSet) then
        return
    end

    for i = #activeDeathBars, 1, -1 do
        local db = activeDeathBars[i]
        if db.anchorFrame and matchSet[db.anchorFrame] then
            if db.holder then
                matchSet[db.holder] = true
            end
            ReleaseDeathBar(db)
            table.remove(activeDeathBars, i)
        end
    end

    for i = #activeBolts, 1, -1 do
        local bolt = activeBolts[i]
        if bolt.anchorFrame and matchSet[bolt.anchorFrame] then
            ReleaseLightningBolt(bolt)
            table.remove(activeBolts, i)
        end
    end

    for i = #activeSparks, 1, -1 do
        local sp = activeSparks[i]
        if sp.anchorFrame and matchSet[sp.anchorFrame] then
            ReleaseSpark(sp)
            table.remove(activeSparks, i)
        end
    end
end

function CombatFX:SpawnDeathShatterBar(barFrame, elementKey)
    local npCfg = ns.Config:Get("nameplates")
    if not npCfg or not npCfg.deathShatterEnabled or not barFrame then
        return
    end

    self:ClearAnchorFX(barFrame)

    local elem = elementKey or "PHYSICAL"
    local prof = (ns.Elements and ns.Elements:GetProfile(elem)) or nil

    local db = AcquireDeathBar()
    db.anchorFrame = barFrame
    db.elem = elem
    db.width = barFrame.fuiWidth or 118
    db.height = math.max(barFrame.fuiHeight or 12, 10)
    db.holder.fuiWidth = db.width
    db.holder.fuiHeight = db.height
    db.age = 0
    db.holdTime = npCfg.deathHoldTime or 0.65
    db.fadeTime = npCfg.deathFadeTime or 0.40
    db.targetTiltDeg = (npCfg.deathTiltDegrees ~= nil) and npCfg.deathTiltDegrees or -8.5
    db.tiltDeg = 0
    db.tiltVel = 0
    db.dropY = 0
    db.barPunchY = 1.15
    db.trauma = 0.42
    db.shakeDx = 0
    db.shakeDy = 0
    db.flashAlpha = 0.52

    db.fillC  = (prof and prof.deathFill)  or { 0.30, 0.30, 0.34 }
    db.trimC  = (prof and prof.deathTrim)  or { 0.38, 0.35, 0.30 }
    db.crackC = (prof and prof.deathCrack) or { 0.80, 0.80, 0.84 }
    db.darkC  = (prof and prof.deathDark)  or { 0.03, 0.03, 0.04 }
    db.flashC = (prof and prof.deathFlash) or { 1.00, 0.96, 0.88 }
    db.shardC = (prof and prof.deathShard) or { 0.62, 0.60, 0.58 }

    UpdateDeathBarGeometry(db, 0)
    table.insert(activeDeathBars, db)

    -- Subtle small burst of stone/dust shards on death (respects sparksEnabled)
    self:SpawnBarSparks(barFrame, 0.5, 4, db.shardC[1], db.shardC[2], db.shardC[3], true, elem, 0.40)
    EnsureDeathBarTicker()
end

-- ============================================================================
-- 3. LOW-HP SCREEN EDGE VIGNETTE PULSE
-- ============================================================================
local lowHpFrame = CreateFrame("Frame", "ForeverUI_LowHPFrame", UIParent)
lowHpFrame:SetAllPoints(UIParent)
lowHpFrame:SetFrameStrata("BACKGROUND")
lowHpFrame:EnableMouse(false)
lowHpFrame:Hide()

local function CreateEdgeGradient(point1, point2, size, isHorizontal, minR, maxR)
    local tex = lowHpFrame:CreateTexture(nil, "BACKGROUND")
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetPoint(point1, lowHpFrame, point1, 0, 0)
    tex:SetPoint(point2, lowHpFrame, point2, 0, 0)
    if isHorizontal then
        tex:SetHeight(size)
    else
        tex:SetWidth(size)
    end
    if tex.SetGradient then
        local orient = isHorizontal and "VERTICAL" or "HORIZONTAL"
        if CreateColor then
            pcall(tex.SetGradient, tex, orient, CreateColor(0.85, 0.05, 0.05, minR), CreateColor(0.85, 0.05, 0.05, maxR))
        end
    else
        tex:SetVertexColor(0.85, 0.05, 0.05, 0.25)
    end
    return tex
end

CreateEdgeGradient("TOPLEFT", "TOPRIGHT", 64, true, 0.0, 0.45)
CreateEdgeGradient("BOTTOMLEFT", "BOTTOMRIGHT", 64, true, 0.45, 0.0)
CreateEdgeGradient("TOPLEFT", "BOTTOMLEFT", 64, false, 0.45, 0.0)
CreateEdgeGradient("TOPRIGHT", "BOTTOMRIGHT", 64, false, 0.0, 0.45)

function CombatFX:UpdateLowHPWarning()
    local cfg = ns.Config:Get("combatFX")
    if not cfg or not cfg.enabled or not cfg.lowHpVignette then
        lowHpFrame:Hide()
        return
    end
    local maxHp = UnitHealthMax("player")
    local curHp = UnitHealth("player")
    if not maxHp or not curHp or ns.IsSecret(maxHp) or ns.IsSecret(curHp) then
        lowHpFrame:Hide()
        return
    end
    local pct = maxHp > 0 and (curHp / maxHp) or 1.0

    local dead = UnitIsDeadOrGhost("player")
    local isDead = (not ns.IsSecret(dead)) and dead or false

    if not isDead and pct <= (cfg.lowHpThreshold or 0.30) then
        lowHpFrame:Show()
        ns.Events:RegisterTicker("CombatFX_LowHPPulse", function(_, now)
            if not lowHpFrame:IsShown() then
                return false
            end
            local pulse = 0.45 + 0.45 * math.sin(now * 5.5)
            lowHpFrame:SetAlpha(pulse)
            return true
        end)
    else
        lowHpFrame:Hide()
    end
end

function CombatFX:OnEnable()
    ns.Events:Register("UNIT_HEALTH", function(_, _, unit)
        if unit == "player" then
            self:UpdateLowHPWarning()
        end
    end, self)

    ns.Events:Register("PLAYER_ENTERING_WORLD", function()
        self:UpdateLowHPWarning()
    end, self)
end
