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
            sp.tex:SetSize(size * 1.25, size * 1.25)
        elseif elem == "LIGHTNING" then
            -- High-voltage darting electric sparks
            local fastSpeed = (95 + math.random() * 175) * speedMult
            sp.vx = math.cos(angle) * fastSpeed * (math.random() > 0.5 and 1 or -1)
            sp.vy = (math.random() - 0.35) * fastSpeed
            sp.gravity = 75
            sp.duration = (0.20 + math.random() * 0.18) * (0.72 + 0.28 * scale)
            sp.vRot = (math.random() - 0.5) * 18
            sp.tex:SetBlendMode("ADD")
            sp.tex:SetSize(size * 1.6, size * 0.75)
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
            sp.tex:SetSize(size * 1.85, size * 0.65)
        elseif elem == "SHADOW" then
            -- Zero-gravity hovering dark void motes
            sp.vx = (math.random() - 0.5) * 32 * speedMult
            sp.vy = (8 + math.random() * 24) * speedMult
            sp.gravity = -25 * speedMult
            sp.waveAmp = (16 + math.random() * 14) * speedMult
            sp.waveFreq = 6 + math.random() * 5
            sp.wavePhase = math.random() * 6.28
            sp.duration = (0.46 + math.random() * 0.30) * (0.70 + 0.30 * scale)
            sp.tex:SetBlendMode("ADD")
            sp.tex:SetSize(size * 1.35, size * 1.35)
        elseif isShards then
            sp.tex:SetBlendMode("BLEND")
            sp.tex:SetSize(size * 1.4, size * 0.9)
        else
            sp.tex:SetBlendMode("ADD")
            sp.tex:SetSize(size, size)
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
-- 2. PREMIUM "POP & BREAK" ELEMENTAL DEATH SHATTER BAR
--    2-Stage Choreography:
--      Stage 1 (The Pop): High-energy hit-stop swell + bevel sheen + spiderwebbing
--                         fracture seams & cleave slash building internal pressure.
--      Stage 2 (The Break): 5 articulated, beveled bar segments physically snap apart
--                         with glowing broken edges and signature elemental physics:
--        * PHYSICAL  : Diagonal sword-cleave bisection & V-buckle snap
--        * FIRE      : Molten detonation & buoyant upward cinder burn-away
--        * FROST     : Flash-freeze crystal lock & 5-shard brittle glass shatter
--        * LIGHTNING : High-voltage strobe seizure & horizontal magnetic rip with live arc tethers
--        * EARTH     : Massive vertical tectonic crush, stone slab avalanche & floor bounce
--        * SHADOW    : Outward rift pop -> zero-G suspension -> central Void Singularity implosion
--    Anchored directly to barFrame via SetPoint("CENTER", db.anchorFrame, "CENTER", cx, cy)
--    so we NEVER call Frame:GetCenter() on Restricted Regions!
-- ============================================================================
local NUM_DEATH_CHUNKS = 5

local ELEMENT_CHUNK_FRACS = {
    PHYSICAL  = { 0.24, 0.21, 0.10, 0.21, 0.24 },
    FIRE      = { 0.19, 0.22, 0.18, 0.23, 0.18 },
    FROST     = { 0.18, 0.21, 0.22, 0.21, 0.18 },
    LIGHTNING = { 0.20, 0.20, 0.20, 0.20, 0.20 },
    EARTH     = { 0.23, 0.17, 0.20, 0.17, 0.23 },
    SHADOW    = { 0.21, 0.19, 0.20, 0.19, 0.21 },
}

-- 12 fracture crack segments mapped to specific breakable chunks (1..5)
local CRACK_SEGMENTS = {
    { chunk = 1, u1 =  0.46, v1 =  0.48, u2 =  0.04, v2 =  0.08, w = 1.6 },
    { chunk = 1, u1 =  0.04, v1 =  0.08, u2 = -0.32, v2 = -0.38, w = 1.4 },
    { chunk = 2, u1 = -0.46, v1 =  0.22, u2 =  0.02, v2 = -0.18, w = 1.7 },
    { chunk = 2, u1 =  0.02, v1 = -0.18, u2 =  0.44, v2 =  0.36, w = 1.6 },
    { chunk = 3, u1 = -0.38, v1 =  0.50, u2 =  0.05, v2 =  0.02, w = 2.1 },
    { chunk = 3, u1 =  0.05, v1 =  0.02, u2 =  0.38, v2 = -0.50, w = 2.1 },
    { chunk = 3, u1 =  0.05, v1 =  0.02, u2 = -0.40, v2 = -0.34, w = 1.4 },
    { chunk = 3, u1 =  0.05, v1 =  0.02, u2 =  0.42, v2 =  0.34, w = 1.4 },
    { chunk = 4, u1 = -0.44, v1 = -0.36, u2 = -0.02, v2 =  0.18, w = 1.7 },
    { chunk = 4, u1 = -0.02, v1 =  0.18, u2 =  0.46, v2 = -0.24, w = 1.6 },
    { chunk = 5, u1 = -0.46, v1 = -0.46, u2 = -0.05, v2 = -0.06, w = 1.6 },
    { chunk = 5, u1 = -0.05, v1 = -0.06, u2 =  0.34, v2 =  0.40, w = 1.4 },
}

local deathBarPool = {}
local activeDeathBars = {}

local function CreateShockwaveRing(holder)
    local edges = {}
    for i = 1, 4 do
        local tex = holder:CreateTexture(nil, "BACKGROUND", nil, -1)
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetBlendMode("ADD")
        tex:Hide()
        edges[i] = tex
    end
    return edges
end

local function UpdateShockwaveRing(edges, holder, w, h, thick, r, g, b, alpha)
    if alpha <= 0.01 then
        for i = 1, 4 do
            edges[i]:Hide()
        end
        return
    end
    local hw = w * 0.5
    local hh = h * 0.5

    local top = edges[1]
    top:ClearAllPoints()
    top:SetPoint("CENTER", holder, "CENTER", 0, hh)
    top:SetSize(w + thick * 2, thick)
    top:SetVertexColor(r, g, b, alpha)
    top:Show()

    local bot = edges[2]
    bot:ClearAllPoints()
    bot:SetPoint("CENTER", holder, "CENTER", 0, -hh)
    bot:SetSize(w + thick * 2, thick)
    bot:SetVertexColor(r, g, b, alpha)
    bot:Show()

    local left = edges[3]
    left:ClearAllPoints()
    left:SetPoint("CENTER", holder, "CENTER", -hw, 0)
    left:SetSize(thick, h)
    left:SetVertexColor(r, g, b, alpha)
    left:Show()

    local right = edges[4]
    right:ClearAllPoints()
    right:SetPoint("CENTER", holder, "CENTER", hw, 0)
    right:SetSize(thick, h)
    right:SetVertexColor(r, g, b, alpha)
    right:Show()
end

local function AcquireDeathBar()
    local db = table.remove(deathBarPool)
    if not db then
        local holder = CreateFrame("Frame", nil, fxCanvas)
        holder:SetSize(120, 14)
        holder:SetFrameLevel(35)

        -- Soft backdrop impact halo behind the bar during Pop & Break
        local backGlowTex = holder:CreateTexture(nil, "BACKGROUND", nil, -2)
        backGlowTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        backGlowTex:SetBlendMode("ADD")

        local shockEdges = CreateShockwaveRing(holder)

        -- Phase-1 Seamless Whole-Bar Outer Casing (used while swelling before the break)
        local wholeBorderTex = holder:CreateTexture(nil, "BACKGROUND", nil, 0)
        wholeBorderTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        wholeBorderTex:SetVertexColor(0.04, 0.04, 0.06, 0.96)

        local wholeTrimTex = holder:CreateTexture(nil, "BORDER", nil, 1)
        wholeTrimTex:SetTexture("Interface\\Buttons\\WHITE8X8")

        -- 5 Articulated Breakable Bar Segments
        local chunks = {}
        for k = 1, NUM_DEATH_CHUNKS do
            local shadowTex = holder:CreateTexture(nil, "BACKGROUND", nil, 1)
            shadowTex:SetTexture("Interface\\Buttons\\WHITE8X8")
            shadowTex:SetVertexColor(0.03, 0.03, 0.05, 0.96)

            local trimTex = holder:CreateTexture(nil, "BORDER", nil, 2)
            trimTex:SetTexture("Interface\\Buttons\\WHITE8X8")

            local fillTex = holder:CreateTexture(nil, "ARTWORK", nil, 1)
            fillTex:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")

            local innerShadowTex = holder:CreateTexture(nil, "ARTWORK", nil, 2)
            innerShadowTex:SetTexture("Interface\\Buttons\\WHITE8X8")
            innerShadowTex:SetVertexColor(0.0, 0.0, 0.0, 0.32)

            local bevelTex = holder:CreateTexture(nil, "ARTWORK", nil, 3)
            bevelTex:SetTexture("Interface\\Buttons\\WHITE8X8")
            bevelTex:SetVertexColor(1.0, 1.0, 1.0, 0.28)

            local emberEdgeLeft = holder:CreateTexture(nil, "OVERLAY", nil, 3)
            emberEdgeLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
            emberEdgeLeft:SetBlendMode("ADD")

            local emberEdgeRight = holder:CreateTexture(nil, "OVERLAY", nil, 3)
            emberEdgeRight:SetTexture("Interface\\Buttons\\WHITE8X8")
            emberEdgeRight:SetBlendMode("ADD")

            local flashTex = holder:CreateTexture(nil, "OVERLAY", nil, 4)
            flashTex:SetTexture("Interface\\Buttons\\WHITE8X8")
            flashTex:SetBlendMode("ADD")

            chunks[k] = {
                shadowTex = shadowTex,
                trimTex = trimTex,
                fillTex = fillTex,
                innerShadowTex = innerShadowTex,
                bevelTex = bevelTex,
                emberEdgeLeft = emberEdgeLeft,
                emberEdgeRight = emberEdgeRight,
                flashTex = flashTex,
                restX = 0,
                baseW = 24,
                x = 0,
                y = 0,
                vx = 0,
                vy = 0,
                gravity = 380,
                rot = 0,
                vRot = 0,
                sx = 1.0,
                sy = 1.0,
                alpha = 1.0,
                flashAlpha = 0,
                waveAmp = 0,
                waveFreq = 0,
                wavePhase = 0,
                bouncesLeft = 0,
                bounceFloorY = -30,
            }
        end

        -- 12 Fracture Cracks (CreateLine) mapped onto the 5 chunks
        local cracks = {}
        for i = 1, #CRACK_SEGMENTS do
            local spec = CRACK_SEGMENTS[i]
            local highlightLine = holder:CreateLine(nil, "OVERLAY", nil, 5)
            highlightLine:SetTexture("Interface\\Buttons\\WHITE8X8")
            highlightLine:SetThickness(spec.w + 0.9)

            local darkLine = holder:CreateLine(nil, "OVERLAY", nil, 6)
            darkLine:SetTexture("Interface\\Buttons\\WHITE8X8")
            darkLine:SetThickness(spec.w)

            cracks[i] = {
                spec = spec,
                highlight = highlightLine,
                dark = darkLine,
            }
        end

        -- 4 Inter-Chunk Seam Tethers / Fracture Faults (CreateLine)
        local tethers = {}
        for i = 1, NUM_DEATH_CHUNKS - 1 do
            local glowLine = holder:CreateLine(nil, "OVERLAY", nil, 6)
            glowLine:SetTexture("Interface\\Buttons\\WHITE8X8")
            glowLine:SetBlendMode("ADD")
            glowLine:SetThickness(3.2)

            local coreLine = holder:CreateLine(nil, "OVERLAY", nil, 7)
            coreLine:SetTexture("Interface\\Buttons\\WHITE8X8")
            coreLine:SetBlendMode("ADD")
            coreLine:SetThickness(1.5)

            tethers[i] = {
                glow = glowLine,
                core = coreLine,
            }
        end

        -- Signature Killing-Blow Slash / Cleave Line (CreateLine)
        local cleaveGlow = holder:CreateLine(nil, "OVERLAY", nil, 7)
        cleaveGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
        cleaveGlow:SetBlendMode("ADD")
        cleaveGlow:SetThickness(4.8)

        local cleaveCore = holder:CreateLine(nil, "OVERLAY", nil, 7)
        cleaveCore:SetTexture("Interface\\Buttons\\WHITE8X8")
        cleaveCore:SetBlendMode("ADD")
        cleaveCore:SetThickness(2.0)

        -- Central Starburst Flare / Void Singularity Event Horizon
        local voidRingTex = holder:CreateTexture(nil, "OVERLAY", nil, 6)
        voidRingTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        voidRingTex:SetBlendMode("ADD")

        local voidCoreTex = holder:CreateTexture(nil, "OVERLAY", nil, 7)
        voidCoreTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        voidCoreTex:SetBlendMode("BLEND")

        db = {
            holder = holder,
            backGlowTex = backGlowTex,
            shockEdges = shockEdges,
            wholeBorderTex = wholeBorderTex,
            wholeTrimTex = wholeTrimTex,
            chunks = chunks,
            cracks = cracks,
            tethers = tethers,
            cleaveGlow = cleaveGlow,
            cleaveCore = cleaveCore,
            voidRingTex = voidRingTex,
            voidCoreTex = voidCoreTex,
        }
    end
    db.holder:Show()
    db.holder:SetAlpha(1.0)
    return db
end

local function ReleaseDeathBar(db)
    db.holder:Hide()
    db.anchorFrame = nil
    for i = 1, 4 do
        db.shockEdges[i]:Hide()
    end
    db.voidRingTex:Hide()
    db.voidCoreTex:Hide()
    db.cleaveGlow:Hide()
    db.cleaveCore:Hide()
    for i = 1, #db.tethers do
        db.tethers[i].glow:Hide()
        db.tethers[i].core:Hide()
    end
    table.insert(deathBarPool, db)
end

-- Fires at the exact millisecond the Pop phase finishes (db.age >= db.breakTime)
-- and splits the overcharged bar into 5 independent elemental fragments!
local function TriggerDeathBarBreak(db)
    db.brokenYet = true
    db.breakFlashAlpha = 1.0
    db.seamGlowAlpha = 1.0
    db.shockwaveAge = 0
    db.shockwaveDuration = (db.elem == "SHADOW") and 0.42 or 0.28

    local elem = db.elem
    local w = db.width
    local popScaleX = db.currentPopX or 1.14
    local popScaleY = db.currentPopY or 1.75

    for k = 1, NUM_DEATH_CHUNKS do
        local seg = db.chunks[k]
        seg.x = seg.restX * popScaleX
        seg.y = 0
        seg.rot = 0
        seg.sx = popScaleX
        seg.sy = popScaleY * 0.90
        seg.alpha = 1.0
        seg.flashAlpha = 0.95
        seg.waveAmp = 0
        seg.waveFreq = 0
        seg.wavePhase = 0
        seg.bouncesLeft = 0
        seg.bounceFloorY = -30
    end

    if elem == "PHYSICAL" then
        -- Clean Diagonal Sword Cleave & V-Buckle Snap:
        -- Center splinter kicks high and spins fast; left & right halves buckle into a broken V and drop!
        local vxList   = { -56, -24,   8,  28,  58 }
        local vyList   = {  32,  52,  96,  48,  30 }
        local vRotList = { -2.4, -3.9, 8.2, 3.8, 2.3 }
        for k = 1, NUM_DEATH_CHUNKS do
            local seg = db.chunks[k]
            seg.vx = vxList[k]
            seg.vy = vyList[k]
            seg.vRot = vRotList[k]
            seg.gravity = 420
        end
    elseif elem == "FIRE" then
        -- Molten Detonation & Upward Cinder Burn-Away:
        -- Chunks blast outward and float UPWARD with negative gravity & heat-wave curl while charring to ash!
        local vxList    = { -68, -32,    4,   36,   70 }
        local vyList    = {  38,  60,   78,   56,   40 }
        local vRotList  = { -2.8,  3.5, -4.4, -3.2,  2.7 }
        local gravList  = { -130, -155, -175, -150, -125 }
        local ampList   = {  22,   26,   30,   26,   22 }
        for k = 1, NUM_DEATH_CHUNKS do
            local seg = db.chunks[k]
            seg.vx = vxList[k]
            seg.vy = vyList[k]
            seg.vRot = vRotList[k]
            seg.gravity = gravList[k]
            seg.waveAmp = ampList[k]
            seg.waveFreq = 8.5 + k * 0.4
            seg.wavePhase = k * 1.25
        end
    elseif elem == "FROST" then
        -- Flash-Freeze Lock -> Brittle 5-Shard Crystalline Glass Shatter:
        -- High-velocity radial shatter with fast tumbling spin & diamond specular glints!
        local vxList   = { -98, -48,   10,   54,  102 }
        local vyList   = {  64, 102,   44,   96,   60 }
        local vRotList = { -7.2, 8.8, -9.6, -7.8,  6.9 }
        for k = 1, NUM_DEATH_CHUNKS do
            local seg = db.chunks[k]
            seg.vx = vxList[k]
            seg.vy = vyList[k]
            seg.vRot = vRotList[k]
            seg.gravity = 470
        end
    elseif elem == "LIGHTNING" then
        -- High-Voltage Overload -> Electromagnetic Horizontal Rip:
        -- Violent horizontal snap-separation in mid-air with alternating shear & live electric arc tethers!
        local vxList   = { -172, -84,    4,   88,  176 }
        local vyList   = {   42, -38,   54,  -40,   44 }
        local vRotList = { -2.4,  3.1, -3.8, -2.9,  2.6 }
        local gravList = {   24, -18,   18,  -18,   24 }
        for k = 1, NUM_DEATH_CHUNKS do
            local seg = db.chunks[k]
            seg.vx = vxList[k]
            seg.vy = vyList[k]
            seg.vRot = vRotList[k]
            seg.gravity = gravList[k]
        end
    elseif elem == "EARTH" then
        -- Tectonic Crush -> Heavy Stone Slab Avalanche & Ledge Bounce:
        -- Inner keystone blocks cave straight down first while outer slabs tip and plummet onto a rock floor!
        local vxList    = { -44, -16,    2,   18,   46 }
        local vyList    = {  18, -14,  -32,  -12,   20 }
        local vRotList  = { -2.8,  3.4, -2.0, -3.5,  2.7 }
        local gravList  = { 740,  830,  880,  830,  740 }
        local floorList = { -28,  -31,  -34,  -31,  -28 }
        for k = 1, NUM_DEATH_CHUNKS do
            local seg = db.chunks[k]
            seg.vx = vxList[k]
            seg.vy = vyList[k]
            seg.vRot = vRotList[k]
            seg.gravity = gravList[k]
            seg.bouncesLeft = 1
            seg.bounceFloorY = floorList[k]
        end
    elseif elem == "SHADOW" then
        -- Void Rift Pop -> Zero-G Drift -> Central Void Singularity Implosion:
        -- Chunks float outward briefly into an orbit, then get sucked spiraling into (0, 0)!
        local vxList   = { -64, -28,   0,   30,   66 }
        local vyList   = {  30, -36,  44,  -34,   28 }
        local vRotList = { -2.2,  2.6, -3.2, -2.5, 2.3 }
        for k = 1, NUM_DEATH_CHUNKS do
            local seg = db.chunks[k]
            seg.vx = vxList[k]
            seg.vy = vyList[k]
            seg.vRot = vRotList[k]
            seg.gravity = 0
        end
    end

    -- Spawn Wave-2 Break Eruption Particles right as the bar snaps apart!
    local barFrame = db.anchorFrame
    local shardC = db.shardC
    if barFrame and shardC then
        if elem == "LIGHTNING" then
            CombatFX:SpawnBarLightning(db.holder, 3, 0.44, 1.0)
            CombatFX:SpawnBarSparks(barFrame, 0.5, 24, shardC[1], shardC[2], shardC[3], false, "LIGHTNING", 1.0)
        elseif elem == "FIRE" then
            CombatFX:SpawnBarSparks(barFrame, 0.5, 26, shardC[1], shardC[2], shardC[3], false, "FIRE", 1.0)
        elseif elem == "EARTH" then
            CombatFX:SpawnBarSparks(barFrame, 0.5, 24, shardC[1], shardC[2], shardC[3], true, "EARTH", 1.0)
        elseif elem == "FROST" then
            CombatFX:SpawnBarSparks(barFrame, 0.5, 26, shardC[1], shardC[2], shardC[3], false, "FROST", 1.0)
        elseif elem == "SHADOW" then
            CombatFX:SpawnBarSparks(barFrame, 0.5, 22, shardC[1], shardC[2], shardC[3], false, "SHADOW", 1.0)
        else
            CombatFX:SpawnBarSparks(barFrame, 0.5, 22, shardC[1], shardC[2], shardC[3], true, "PHYSICAL", 1.0)
        end
    end
end

local function UpdateDeathBarGeometry(db, now)
    local w = db.width
    local h = db.height
    local elem = db.elem
    local fillC = db.fillC
    local trimC = db.trimC
    local crackC = db.crackC
    local darkC = db.darkC
    local flashC = db.flashC

    db.holder:ClearAllPoints()
    db.holder:SetPoint("CENTER", db.anchorFrame or fxCanvas, "CENTER", db.shakeDx, db.shakeDy)
    db.holder:SetSize(w, h)

    local popScaleX = db.currentPopX or 1.0
    local popScaleY = db.currentPopY or 1.0
    local totalW = w * popScaleX
    local totalH = h * popScaleY

    -- 1. Backdrop Impact Halo
    local haloAlpha = math.max(db.flashAlpha * 0.42, (db.breakFlashAlpha or 0) * 0.55)
    if elem == "SHADOW" and db.brokenYet then
        local postAge = db.age - db.breakTime
        if postAge < 0.56 then
            haloAlpha = math.max(haloAlpha, 0.48 * (1.0 - postAge / 0.56))
        end
    end
    if haloAlpha > 0.01 then
        db.backGlowTex:ClearAllPoints()
        db.backGlowTex:SetPoint("CENTER", db.holder, "CENTER", 0, 0)
        db.backGlowTex:SetSize(totalW + 26, totalH + 18)
        db.backGlowTex:SetVertexColor(flashC[1], flashC[2], flashC[3], haloAlpha)
        db.backGlowTex:Show()
    else
        db.backGlowTex:Hide()
    end

    -- 2. Expanding Impact / Break Shockwave Ring
    local shockAge = db.shockwaveAge or 99
    local shockDur = db.shockwaveDuration or 0.28
    if shockAge < shockDur then
        local st = shockAge / shockDur
        local ease = 1.0 - (1.0 - st) * (1.0 - st)
        local ringW, ringH
        if elem == "SHADOW" and db.brokenYet and shockAge > 0.12 then
            -- Shadow ring contracts inward with the implosion!
            local contract = math.max(0.08, 1.0 - ((shockAge - 0.12) / (shockDur - 0.12)))
            ringW = (w * 1.35) * contract
            ringH = (h * 2.60) * contract
        else
            ringW = totalW + ease * 44
            ringH = totalH + ease * 26
        end
        local ringAlpha = (1.0 - st) * 0.78
        local ringThick = math.max(1.0, 2.6 * (1.0 - st * 0.6))
        UpdateShockwaveRing(db.shockEdges, db.holder, ringW, ringH, ringThick, crackC[1], crackC[2], crackC[3], ringAlpha)
    else
        UpdateShockwaveRing(db.shockEdges, db.holder, 0, 0, 1, 1, 1, 1, 0)
    end

    -- 3. Phase-1 Unified Whole-Bar Casing vs Phase-2 Individual Broken Chunk Casings
    if not db.brokenYet then
        db.wholeBorderTex:ClearAllPoints()
        db.wholeBorderTex:SetPoint("CENTER", db.holder, "CENTER", 0, 0)
        db.wholeBorderTex:SetSize(totalW + 4, totalH + 4)
        db.wholeBorderTex:Show()

        db.wholeTrimTex:ClearAllPoints()
        db.wholeTrimTex:SetPoint("CENTER", db.holder, "CENTER", 0, 0)
        db.wholeTrimTex:SetSize(totalW + 2, totalH + 2)
        db.wholeTrimTex:SetVertexColor(trimC[1], trimC[2], trimC[3], 0.98)
        db.wholeTrimTex:Show()
    else
        db.wholeBorderTex:Hide()
        db.wholeTrimTex:Hide()
    end

    -- 4. Render the 5 Articulated Breakable Bar Chunks
    local postBreakAge = db.brokenYet and (db.age - db.breakTime) or 0
    local postBreakDur = math.max(0.25, (db.holdTime + db.fadeTime) - db.breakTime)
    local postT = math.min(1.0, math.max(0.0, postBreakAge / postBreakDur))

    for k = 1, NUM_DEATH_CHUNKS do
        local seg = db.chunks[k]
        local cx, cy, cw, ch, theta
        if not db.brokenYet then
            cx = seg.restX * popScaleX
            cy = 0
            -- Slight 0.6px overlap during Phase 1 so the bar is 100% seamless until it breaks
            cw = seg.baseW * popScaleX + 0.6
            ch = h * popScaleY
            theta = 0
        else
            cx = seg.x
            cy = seg.y
            if elem == "LIGHTNING" then
                -- Continuous high-voltage micro-jitter on each broken plate
                cx = cx + math.sin(now * 185.0 + k * 2.1) * 1.8 * (1.0 - postT * 0.7)
                cy = cy + math.cos(now * 205.0 + k * 1.7) * 1.2 * (1.0 - postT * 0.7)
            end
            cw = math.max(2.0, seg.baseW * seg.sx)
            ch = math.max(2.0, h * seg.sy)
            theta = seg.rot
        end

        local cosT = math.cos(theta)
        local sinT = math.sin(theta)
        local segAlpha = seg.alpha or 1.0

        -- Compute per-element dynamic chunk color progression
        local rFill, gFill, bFill = fillC[1], fillC[2], fillC[3]
        local rTrim, gTrim, bTrim = trimC[1], trimC[2], trimC[3]
        if elem == "FIRE" and db.brokenYet then
            -- Superheated magma orange -> glowing ember red -> blackened char ash
            local charT = math.min(1.0, postT * 1.35)
            rFill = (1.0 - charT) * 0.85 + charT * 0.08
            gFill = (1.0 - charT) * 0.24 + charT * 0.03
            bFill = (1.0 - charT) * 0.03 + charT * 0.02
            rTrim = (1.0 - charT) * 1.00 + charT * 0.32
            gTrim = (1.0 - charT) * 0.48 + charT * 0.08
            bTrim = 0.02
        elseif elem == "LIGHTNING" then
            -- High-voltage cyan/white strobe oscillation
            local strobe = (math.sin(now * 140.0 + k * 1.9) > 0.25) and 1.0 or 0.0
            if strobe > 0 and postT < 0.65 then
                rFill, gFill, bFill = 0.45, 0.90, 1.00
                rTrim, gTrim, bTrim = 0.92, 0.99, 1.00
            end
        end

        if db.brokenYet then
            seg.shadowTex:ClearAllPoints()
            seg.shadowTex:SetPoint("CENTER", db.holder, "CENTER", cx, cy)
            seg.shadowTex:SetSize(cw + 3.2, ch + 3.2)
            seg.shadowTex:SetAlpha(segAlpha * 0.96)
            if seg.shadowTex.SetRotation then
                seg.shadowTex:SetRotation(theta)
            end
            seg.shadowTex:Show()

            seg.trimTex:ClearAllPoints()
            seg.trimTex:SetPoint("CENTER", db.holder, "CENTER", cx, cy)
            seg.trimTex:SetSize(cw + 1.6, ch + 1.6)
            seg.trimTex:SetVertexColor(rTrim, gTrim, bTrim, segAlpha * 0.96)
            if seg.trimTex.SetRotation then
                seg.trimTex:SetRotation(theta)
            end
            seg.trimTex:Show()
        else
            seg.shadowTex:Hide()
            seg.trimTex:Hide()
        end

        seg.fillTex:ClearAllPoints()
        seg.fillTex:SetPoint("CENTER", db.holder, "CENTER", cx, cy)
        seg.fillTex:SetSize(cw, ch)
        seg.fillTex:SetVertexColor(rFill, gFill, bFill, segAlpha)
        if seg.fillTex.SetRotation then
            seg.fillTex:SetRotation(theta)
        end
        seg.fillTex:Show()

        -- Top Specular Bevel Sheen & Bottom Inner Shadow (rotated rigidly around chunk center!)
        local bevelLy = ch * 0.26
        local bevelRx = cx - bevelLy * sinT
        local bevelRy = cy + bevelLy * cosT
        seg.bevelTex:ClearAllPoints()
        seg.bevelTex:SetPoint("CENTER", db.holder, "CENTER", bevelRx, bevelRy)
        seg.bevelTex:SetSize(cw, ch * 0.44)
        seg.bevelTex:SetVertexColor(1.0, 1.0, 1.0, segAlpha * ((elem == "FROST") and 0.42 or 0.26))
        if seg.bevelTex.SetRotation then
            seg.bevelTex:SetRotation(theta)
        end
        seg.bevelTex:Show()

        local innerLy = -ch * 0.26
        local innerRx = cx - innerLy * sinT
        local innerRy = cy + innerLy * cosT
        seg.innerShadowTex:ClearAllPoints()
        seg.innerShadowTex:SetPoint("CENTER", db.holder, "CENTER", innerRx, innerRy)
        seg.innerShadowTex:SetSize(cw, ch * 0.46)
        seg.innerShadowTex:SetVertexColor(0.0, 0.0, 0.0, segAlpha * 0.34)
        if seg.innerShadowTex.SetRotation then
            seg.innerShadowTex:SetRotation(theta)
        end
        seg.innerShadowTex:Show()

        -- Glowing Fracture Seam Edges on the broken inner sides of each chunk
        local seamA = (db.seamGlowAlpha or 0) * segAlpha
        if db.brokenYet and seamA > 0.02 then
            local edgeThick = math.max(1.8, 3.0 * seamA)
            if k > 1 then
                local lx = -cw * 0.5 + edgeThick * 0.35
                local ex = cx + lx * cosT
                local ey = cy + lx * sinT
                seg.emberEdgeLeft:ClearAllPoints()
                seg.emberEdgeLeft:SetPoint("CENTER", db.holder, "CENTER", ex, ey)
                seg.emberEdgeLeft:SetSize(edgeThick, ch + 1.0)
                seg.emberEdgeLeft:SetVertexColor(crackC[1], crackC[2], crackC[3], seamA)
                if seg.emberEdgeLeft.SetRotation then
                    seg.emberEdgeLeft:SetRotation(theta)
                end
                seg.emberEdgeLeft:Show()
            else
                seg.emberEdgeLeft:Hide()
            end

            if k < NUM_DEATH_CHUNKS then
                local rx = cw * 0.5 - edgeThick * 0.35
                local ex = cx + rx * cosT
                local ey = cy + rx * sinT
                seg.emberEdgeRight:ClearAllPoints()
                seg.emberEdgeRight:SetPoint("CENTER", db.holder, "CENTER", ex, ey)
                seg.emberEdgeRight:SetSize(edgeThick, ch + 1.0)
                seg.emberEdgeRight:SetVertexColor(crackC[1], crackC[2], crackC[3], seamA)
                if seg.emberEdgeRight.SetRotation then
                    seg.emberEdgeRight:SetRotation(theta)
                end
                seg.emberEdgeRight:Show()
            else
                seg.emberEdgeRight:Hide()
            end
        else
            seg.emberEdgeLeft:Hide()
            seg.emberEdgeRight:Hide()
        end

        -- Specular Flash Overlay (Pop Flash + Break Snap Flash + Frost Crystalline Spin Glint)
        local fAlpha = math.max(db.flashAlpha, seg.flashAlpha or 0)
        if elem == "FROST" and db.brokenYet and postT < 0.75 then
            local glint = math.max(0, math.sin(theta * 3.0 + k)) * 0.55 * (1.0 - postT)
            fAlpha = math.max(fAlpha, glint)
        end
        fAlpha = fAlpha * segAlpha
        if fAlpha > 0.01 then
            seg.flashTex:ClearAllPoints()
            seg.flashTex:SetPoint("CENTER", db.holder, "CENTER", cx, cy)
            seg.flashTex:SetSize(cw, ch)
            seg.flashTex:SetVertexColor(flashC[1], flashC[2], flashC[3], fAlpha)
            if seg.flashTex.SetRotation then
                seg.flashTex:SetRotation(theta)
            end
            seg.flashTex:Show()
        else
            seg.flashTex:Hide()
        end

        seg.renderCx = cx
        seg.renderCy = cy
        seg.renderCw = cw
        seg.renderCh = ch
        seg.renderCos = cosT
        seg.renderSin = sinT
    end

    -- 5. Update the 12 Fracture Cracks (CreateLine) anchored to their parent chunks
    local crackGrow = db.brokenYet and 1.0 or math.min(1.0, (db.age / math.max(0.04, db.breakTime)) * 1.28)
    for i = 1, #db.cracks do
        local c = db.cracks[i]
        local s = c.spec
        local seg = db.chunks[s.chunk]
        local cx = seg.renderCx or 0
        local cy = seg.renderCy or 0
        local cw = seg.renderCw or 24
        local ch = seg.renderCh or 12
        local cosT = seg.renderCos or 1
        local sinT = seg.renderSin or 0
        local segAlpha = seg.alpha or 1.0

        local u2 = s.u1 + (s.u2 - s.u1) * crackGrow
        local v2 = s.v1 + (s.v2 - s.v1) * crackGrow

        local lx1 = s.u1 * cw
        local ly1 = s.v1 * ch
        local lx2 = u2 * cw
        local ly2 = v2 * ch

        local rx1 = cx + lx1 * cosT - ly1 * sinT
        local ry1 = cy + lx1 * sinT + ly1 * cosT
        local rx2 = cx + lx2 * cosT - ly2 * sinT
        local ry2 = cy + lx2 * sinT + ly2 * cosT

        c.highlight:SetVertexColor(crackC[1], crackC[2], crackC[3], 0.92 * segAlpha)
        c.highlight:SetStartPoint("CENTER", db.holder, rx1 + 0.6, ry1)
        c.highlight:SetEndPoint("CENTER", db.holder, rx2 + 0.6, ry2)
        c.highlight:Show()

        c.dark:SetVertexColor(darkC[1], darkC[2], darkC[3], 0.98 * segAlpha)
        c.dark:SetStartPoint("CENTER", db.holder, rx1, ry1)
        c.dark:SetEndPoint("CENTER", db.holder, rx2, ry2)
        c.dark:Show()
    end

    -- 6. Update the 4 Inter-Chunk Seam Faults / Energy Tethers (CreateLine)
    for i = 1, NUM_DEATH_CHUNKS - 1 do
        local teth = db.tethers[i]
        local segA = db.chunks[i]
        local segB = db.chunks[i + 1]

        if not db.brokenYet then
            -- During Phase 1 (The Pop), draw glowing vertical fracture seams warming up to the snap!
            local popT = math.min(1.0, db.age / math.max(0.04, db.breakTime))
            local seamX = (segA.renderCx or 0) + (segA.renderCw or 24) * 0.5
            local halfH = (segA.renderCh or 12) * 0.54 * popT
            local a = popT * popT
            teth.glow:SetVertexColor(flashC[1], flashC[2], flashC[3], a * 0.85)
            teth.glow:SetStartPoint("CENTER", db.holder, seamX, -halfH)
            teth.glow:SetEndPoint("CENTER", db.holder, seamX, halfH)
            teth.glow:Show()

            teth.core:SetVertexColor(1.0, 0.98, 0.92, a * 0.95)
            teth.core:SetStartPoint("CENTER", db.holder, seamX, -halfH)
            teth.core:SetEndPoint("CENTER", db.holder, seamX, halfH)
            teth.core:Show()
        else
            local tetherDur = (elem == "LIGHTNING") and 0.44
                or ((elem == "SHADOW") and 0.48
                or ((elem == "FIRE") and 0.24 or 0.10))
            if postBreakAge <= tetherDur then
                local tt = postBreakAge / tetherDur
                local a = (1.0 - tt)
                local x1, y1, x2, y2
                if elem == "SHADOW" then
                    -- Shadow tethers pull each chunk directly into the central Void Singularity (0, 0)!
                    x1 = segA.renderCx or 0
                    y1 = segA.renderCy or 0
                    x2 = 0
                    y2 = 0
                else
                    local hwA = (segA.renderCw or 20) * 0.46
                    local hwB = (segB.renderCw or 20) * 0.46
                    x1 = (segA.renderCx or 0) + hwA * (segA.renderCos or 1)
                    y1 = (segA.renderCy or 0) + hwA * (segA.renderSin or 0)
                    x2 = (segB.renderCx or 0) - hwB * (segB.renderCos or 1)
                    y2 = (segB.renderCy or 0) - hwB * (segB.renderSin or 0)
                    if elem == "LIGHTNING" then
                        y1 = y1 + math.sin(now * 210.0 + i * 2.3) * 4.5
                        y2 = y2 + math.cos(now * 195.0 + i * 1.7) * 4.5
                    end
                end
                teth.glow:SetVertexColor(crackC[1], crackC[2], crackC[3], a * 0.85)
                teth.glow:SetStartPoint("CENTER", db.holder, x1, y1)
                teth.glow:SetEndPoint("CENTER", db.holder, x2, y2)
                teth.glow:Show()

                teth.core:SetVertexColor(1.0, 0.98, 0.95, a * 0.95)
                teth.core:SetStartPoint("CENTER", db.holder, x1, y1)
                teth.core:SetEndPoint("CENTER", db.holder, x2, y2)
                teth.core:Show()
            else
                teth.glow:Hide()
                teth.core:Hide()
            end
        end
    end

    -- 7. Signature Killing-Blow Slash / Cleave Line (CreateLine)
    local cleaveAlpha = 0
    if not db.brokenYet then
        cleaveAlpha = math.min(1.0, (db.age / math.max(0.04, db.breakTime)) * 1.4)
    elseif postBreakAge < 0.24 then
        cleaveAlpha = math.max(0, 1.0 - (postBreakAge / 0.24))
    end
    if cleaveAlpha > 0.02 then
        local sx1, sy1, sx2, sy2
        if elem == "PHYSICAL" then
            -- Long razor-sharp diagonal katana/greatsword cleave across the center!
            sx1, sy1 = -w * 0.32, -h * 1.65
            sx2, sy2 =  w * 0.32,  h * 1.65
        elseif elem == "LIGHTNING" then
            -- High-voltage horizontal plasma discharge beam across the entire bar!
            sx1, sy1 = -w * 0.64,  h * 0.15
            sx2, sy2 =  w * 0.64, -h * 0.15
        elseif elem == "FROST" then
            -- Crystalline cross-shatter fracture!
            sx1, sy1 = -w * 0.46, -h * 1.20
            sx2, sy2 =  w * 0.46,  h * 1.20
        elseif elem == "EARTH" then
            -- Steep vertical tectonic fault line!
            sx1, sy1 = -w * 0.12,  h * 1.75
            sx2, sy2 =  w * 0.12, -h * 1.75
        elseif elem == "FIRE" then
            -- Erupting magma fissure!
            sx1, sy1 = -w * 0.38, -h * 1.30
            sx2, sy2 =  w * 0.38,  h * 1.35
        else
            -- Shadow dimensional rift!
            sx1, sy1 = -w * 0.44,  h * 1.25
            sx2, sy2 =  w * 0.44, -h * 1.25
        end
        db.cleaveGlow:SetVertexColor(flashC[1], flashC[2], flashC[3], cleaveAlpha * 0.88)
        db.cleaveGlow:SetStartPoint("CENTER", db.holder, sx1, sy1)
        db.cleaveGlow:SetEndPoint("CENTER", db.holder, sx2, sy2)
        db.cleaveGlow:Show()

        db.cleaveCore:SetVertexColor(1.0, 0.99, 0.94, cleaveAlpha)
        db.cleaveCore:SetStartPoint("CENTER", db.holder, sx1, sy1)
        db.cleaveCore:SetEndPoint("CENTER", db.holder, sx2, sy2)
        db.cleaveCore:Show()
    else
        db.cleaveGlow:Hide()
        db.cleaveCore:Hide()
    end

    -- 8. Central Impact Diamond Starburst & Shadow Void Singularity Event Horizon
    if elem == "SHADOW" and db.brokenYet then
        local implosionDur = 0.62
        if postBreakAge <= implosionDur then
            local st = postBreakAge / implosionDur
            local ringSize, coreSize, ringAlpha, coreAlpha
            if st < 0.78 then
                local build = st / 0.78
                ringSize = (h * 1.35) + math.sin(build * 3.14159) * (h * 1.45)
                coreSize = ringSize * 0.58
                ringAlpha = 0.92
                coreAlpha = 0.96
            else
                -- Final singularity nova wink-out!
                local wink = (st - 0.78) / 0.22
                ringSize = (h * 2.8) * (1.0 - wink * 0.85)
                coreSize = ringSize * (1.0 - wink)
                ringAlpha = (1.0 - wink)
                coreAlpha = (1.0 - wink)
            end
            db.voidRingTex:ClearAllPoints()
            db.voidRingTex:SetPoint("CENTER", db.holder, "CENTER", 0, 0)
            db.voidRingTex:SetSize(ringSize, ringSize)
            db.voidRingTex:SetVertexColor(0.86, 0.36, 1.00, ringAlpha)
            if db.voidRingTex.SetRotation then
                db.voidRingTex:SetRotation(now * 6.5)
            end
            db.voidRingTex:Show()

            db.voidCoreTex:ClearAllPoints()
            db.voidCoreTex:SetPoint("CENTER", db.holder, "CENTER", 0, 0)
            db.voidCoreTex:SetSize(math.max(1.0, coreSize), math.max(1.0, coreSize))
            db.voidCoreTex:SetVertexColor(0.03, 0.00, 0.06, coreAlpha)
            if db.voidCoreTex.SetRotation then
                db.voidCoreTex:SetRotation(-now * 4.5)
            end
            db.voidCoreTex:Show()
        else
            db.voidRingTex:Hide()
            db.voidCoreTex:Hide()
        end
    elseif db.brokenYet and postBreakAge < 0.18 then
        -- Crisp 45-degree specular impact diamond flash at the center when the bar breaks!
        local flareT = 1.0 - (postBreakAge / 0.18)
        local flareSize = (h * 1.75) * flareT
        db.voidRingTex:ClearAllPoints()
        db.voidRingTex:SetPoint("CENTER", db.holder, "CENTER", 0, 0)
        db.voidRingTex:SetSize(flareSize, flareSize)
        db.voidRingTex:SetVertexColor(flashC[1], flashC[2], flashC[3], flareT * 0.88)
        if db.voidRingTex.SetRotation then
            db.voidRingTex:SetRotation(0.7854)
        end
        db.voidRingTex:Show()
        db.voidCoreTex:Hide()
    else
        db.voidRingTex:Hide()
        db.voidCoreTex:Hide()
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
                local elem = db.elem
                db.flashAlpha = math.max(0, db.flashAlpha - dt * 5.2)
                db.breakFlashAlpha = math.max(0, (db.breakFlashAlpha or 0) - dt * 6.0)
                db.seamGlowAlpha = math.max(0, (db.seamGlowAlpha or 0) - dt * ((elem == "FIRE") and 1.4 or 2.4))
                db.shockwaveAge = (db.shockwaveAge or 99) + dt

                -- Trauma shake (intense during the Pop hit-stop, decays after the Break)
                if db.trauma > 0.01 then
                    local p = db.trauma * db.trauma
                    local freq = (elem == "LIGHTNING") and 165.0 or ((elem == "EARTH") and 68.0 or 98.0)
                    db.shakeDx = math.sin(now * freq) * 8.5 * p
                    db.shakeDy = math.cos(now * (freq * 1.12)) * 5.5 * p
                    db.trauma = math.max(0, db.trauma - dt * 3.0)
                else
                    db.trauma = 0
                    db.shakeDx = 0
                    db.shakeDy = 0
                end

                if not db.brokenYet then
                    -- ========================================================
                    -- STAGE 1: THE "POP" (Elastic Swell & Hit-Stop Overcharge)
                    -- ========================================================
                    local popT = math.min(1.0, db.age / math.max(0.04, db.breakTime))
                    local ease = 1.0 - (1.0 - popT) * (1.0 - popT)
                    db.currentPopX = 1.0 + (db.popPeakX - 1.0) * ease
                    db.currentPopY = 1.0 + (db.popPeakY - 1.0) * ease

                    if db.age >= db.breakTime then
                        TriggerDeathBarBreak(db)
                    end
                else
                    -- ========================================================
                    -- STAGE 2: THE "BREAK" (Per-Chunk Elemental Physics!)
                    -- ========================================================
                    local postBreakAge = db.age - db.breakTime
                    local postBreakDur = math.max(0.25, totalDuration - db.breakTime)
                    local postT = math.min(1.0, postBreakAge / postBreakDur)

                    for k = 1, NUM_DEATH_CHUNKS do
                        local seg = db.chunks[k]
                        seg.flashAlpha = math.max(0, (seg.flashAlpha or 0) - dt * 5.5)

                        if elem == "SHADOW" then
                            if postBreakAge < 0.15 then
                                -- Brief zero-gravity outward suspension
                                local drag = math.max(0, 1.0 - 6.5 * dt)
                                seg.vx = seg.vx * drag
                                seg.vy = seg.vy * drag
                                seg.x = seg.x + seg.vx * dt
                                seg.y = seg.y + seg.vy * dt
                                seg.rot = seg.rot + seg.vRot * dt
                                seg.sy = seg.sy + (1.0 - seg.sy) * math.min(1.0, dt * 12.0)
                            else
                                -- Gravitational Singularity Suction & Vortex Collapse into (0, 0)!
                                local pullT = math.min(1.0, (postBreakAge - 0.15) / 0.42)
                                local pullRate = 7.5 + pullT * 24.0
                                local swirlX = -seg.y * 4.2 * dt
                                local swirlY =  seg.x * 4.2 * dt
                                seg.x = (seg.x + swirlX) * math.max(0, 1.0 - pullRate * dt)
                                seg.y = (seg.y + swirlY) * math.max(0, 1.0 - pullRate * dt)
                                seg.rot = seg.rot + (seg.vRot * (1.0 + pullT * 2.5)) * dt
                                seg.sx = math.max(0.06, 1.0 - pullT * 0.94)
                                seg.sy = math.max(0.06, 1.0 - pullT * 0.94)
                                seg.alpha = math.max(0, 1.0 - pullT * 1.08)
                            end
                        elseif elem == "LIGHTNING" then
                            -- High-velocity horizontal magnetic snap with strong air drag
                            local drag = math.max(0, 1.0 - 5.8 * dt)
                            seg.vx = seg.vx * drag
                            seg.vy = seg.vy * drag - seg.gravity * dt
                            seg.x = seg.x + seg.vx * dt
                            seg.y = seg.y + seg.vy * dt
                            seg.rot = seg.rot + seg.vRot * drag * dt
                            seg.sx = seg.sx + (1.0 - seg.sx) * math.min(1.0, dt * 14.0)
                            seg.sy = seg.sy + (1.0 - seg.sy) * math.min(1.0, dt * 14.0)
                        elseif elem == "FIRE" then
                            -- Buoyant upward cinder rise + sinusoidal heat-wave curl + thermal burn-down shrink
                            seg.x = seg.x + seg.vx * dt + math.sin(postBreakAge * seg.waveFreq + seg.wavePhase) * seg.waveAmp * dt
                            seg.y = seg.y + seg.vy * dt
                            seg.vy = seg.vy - seg.gravity * dt
                            seg.vx = seg.vx * math.max(0, 1.0 - 2.2 * dt)
                            seg.rot = seg.rot + seg.vRot * dt
                            local burnScale = math.max(0.22, 1.0 - postT * 0.78)
                            seg.sx = burnScale
                            seg.sy = burnScale
                        elseif elem == "EARTH" then
                            -- Heavy stone slab avalanche + seismic floor bounce!
                            seg.x = seg.x + seg.vx * dt
                            seg.y = seg.y + seg.vy * dt
                            seg.vy = seg.vy - seg.gravity * dt
                            seg.rot = seg.rot + seg.vRot * dt
                            seg.sx = seg.sx + (1.0 - seg.sx) * math.min(1.0, dt * 14.0)
                            seg.sy = seg.sy + (1.05 - seg.sy) * math.min(1.0, dt * 14.0)

                            if seg.bouncesLeft > 0 and seg.vy < 0 and seg.y <= seg.bounceFloorY then
                                seg.y = seg.bounceFloorY
                                seg.vy = math.abs(seg.vy) * 0.44
                                seg.vx = seg.vx * 0.74
                                seg.vRot = -seg.vRot * 0.55
                                seg.bouncesLeft = seg.bouncesLeft - 1
                                seg.flashAlpha = 0.65
                            end
                        elseif elem == "FROST" then
                            -- Brittle crystalline shards tapering slightly as they spin
                            seg.x = seg.x + seg.vx * dt
                            seg.y = seg.y + seg.vy * dt
                            seg.vy = seg.vy - seg.gravity * dt
                            seg.rot = seg.rot + seg.vRot * dt
                            seg.sx = seg.sx + (0.92 - seg.sx) * math.min(1.0, dt * 14.0)
                            seg.sy = seg.sy + (0.88 - seg.sy) * math.min(1.0, dt * 14.0)
                        else
                            -- PHYSICAL: Clean cleave & V-buckle snap
                            seg.x = seg.x + seg.vx * dt
                            seg.y = seg.y + seg.vy * dt
                            seg.vy = seg.vy - seg.gravity * dt
                            seg.rot = seg.rot + seg.vRot * dt
                            seg.sx = seg.sx + (1.0 - seg.sx) * math.min(1.0, dt * 14.0)
                            seg.sy = seg.sy + (1.0 - seg.sy) * math.min(1.0, dt * 14.0)
                        end
                    end
                end

                if db.age > db.holdTime then
                    local fadeT = (db.age - db.holdTime) / db.fadeTime
                    db.holder:SetAlpha(math.max(0, 1.0 - fadeT))
                end

                UpdateDeathBarGeometry(db, now)
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
    db.holdTime = npCfg.deathHoldTime or 0.85
    db.fadeTime = npCfg.deathFadeTime or 0.45
    db.brokenYet = false

    -- Stage 1 ("The Pop") duration & peak swell per element before Stage 2 ("The Break")
    if elem == "FROST" then
        db.breakTime = 0.140
        db.popPeakX = 1.14
        db.popPeakY = 1.82
    elseif elem == "EARTH" then
        db.breakTime = 0.100
        db.popPeakX = 1.10
        db.popPeakY = 2.25
    elseif elem == "LIGHTNING" then
        db.breakTime = 0.115
        db.popPeakX = 1.22
        db.popPeakY = 1.78
    elseif elem == "FIRE" then
        db.breakTime = 0.105
        db.popPeakX = 1.18
        db.popPeakY = 1.92
    elseif elem == "SHADOW" then
        db.breakTime = 0.110
        db.popPeakX = 1.18
        db.popPeakY = 1.88
    else
        db.breakTime = 0.095
        db.popPeakX = 1.15
        db.popPeakY = 1.85
    end

    db.currentPopX = 1.05
    db.currentPopY = 1.35
    db.trauma = 1.0
    db.shakeDx = 0
    db.shakeDy = 0
    db.flashAlpha = 1.0
    db.breakFlashAlpha = 0
    db.seamGlowAlpha = 0.85
    db.shockwaveAge = 0
    db.shockwaveDuration = 0.22

    db.fillC  = (prof and prof.deathFill)  or { 0.32, 0.33, 0.38 }
    db.trimC  = (prof and prof.deathTrim)  or { 0.78, 0.74, 0.66 }
    db.crackC = (prof and prof.deathCrack) or { 1.00, 0.94, 0.78 }
    db.darkC  = (prof and prof.deathDark)  or { 0.03, 0.03, 0.04 }
    db.flashC = (prof and prof.deathFlash) or { 1.00, 0.95, 0.82 }
    db.shardC = (prof and prof.deathShard) or { 0.88, 0.84, 0.76 }

    -- Compute rest positions & widths for the 5 articulated chunks
    local fracs = ELEMENT_CHUNK_FRACS[elem] or ELEMENT_CHUNK_FRACS.PHYSICAL
    local cursorX = -db.width * 0.5
    for k = 1, NUM_DEATH_CHUNKS do
        local cw = db.width * fracs[k]
        local seg = db.chunks[k]
        seg.baseW = cw
        seg.restX = cursorX + cw * 0.5
        seg.x = seg.restX
        seg.y = 0
        seg.vx = 0
        seg.vy = 0
        seg.rot = 0
        seg.vRot = 0
        seg.sx = 1.0
        seg.sy = 1.0
        seg.alpha = 1.0
        seg.flashAlpha = 1.0
        cursorX = cursorX + cw
    end

    local now = GetTime and GetTime() or 0
    UpdateDeathBarGeometry(db, now)
    table.insert(activeDeathBars, db)

    -- Wave 1 (The Pop): Initial impact flash sparks & pre-break crackle
    if elem == "LIGHTNING" then
        self:SpawnBarLightning(db.holder, 2, 0.16, 0.90)
        self:SpawnBarSparks(barFrame, 0.5, 10, db.shardC[1], db.shardC[2], db.shardC[3], false, "LIGHTNING", 0.85)
    elseif elem == "FIRE" then
        self:SpawnBarSparks(barFrame, 0.5, 10, db.shardC[1], db.shardC[2], db.shardC[3], false, "FIRE", 0.85)
    elseif elem == "EARTH" then
        self:SpawnBarSparks(barFrame, 0.5, 8, db.shardC[1], db.shardC[2], db.shardC[3], true, "EARTH", 0.85)
    elseif elem == "FROST" then
        self:SpawnBarSparks(barFrame, 0.5, 8, db.shardC[1], db.shardC[2], db.shardC[3], false, "FROST", 0.85)
    elseif elem == "SHADOW" then
        self:SpawnBarSparks(barFrame, 0.5, 8, db.shardC[1], db.shardC[2], db.shardC[3], false, "SHADOW", 0.85)
    else
        self:SpawnBarSparks(barFrame, 0.5, 8, db.shardC[1], db.shardC[2], db.shardC[3], false, "PHYSICAL", 0.85)
    end
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
