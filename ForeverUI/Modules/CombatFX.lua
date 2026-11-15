local addonName, ns = ...
local CombatFX = {}
ns.CombatFX = CombatFX

local fxCanvas = CreateFrame("Frame", "ForeverUI_FXCanvas", UIParent)
fxCanvas:SetAllPoints(UIParent)
fxCanvas:SetFrameStrata("HIGH")
fxCanvas:EnableMouse(false)

-- ============================================================================
-- 1. POOLED BAR SHATTER SPARKS, EMBERS, SPELL MOTES & DEBRIS SHARDS
--    Uses two-layer WoW particle textures (outer radial/streak halo + inner
--    star4 / starburst / spark / orb / crystal core) with dynamic velocity
--    alignment, thermal flicker, and multi-tone WoW spell-school palettes.
--    Anchored directly to the target frame via SetPoint("CENTER", anchorFrame, "CENTER", dx, dy)
--    so we NEVER call Frame:GetCenter() on Restricted Regions!
-- ============================================================================
local TEX_STAR4     = "Interface\\Cooldown\\star4"
local TEX_STARBURST = "Interface\\Cooldown\\starburst"
local TEX_SPARK     = "Interface\\CastingBar\\UI-CastingBar-Spark"
local TEX_ORB       = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
local TEX_RING      = "Interface\\Cooldown\\ping4"
local TEX_SHARD     = "Interface\\TargetingFrame\\UI-StatusBar"

local sparkPool = {}
local activeSparks = {}

local function Clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function AcquireSpark()
    local sp = table.remove(sparkPool)
    if not sp then
        local glowTex = fxCanvas:CreateTexture(nil, "OVERLAY", nil, 4)
        glowTex:SetTexture(TEX_ORB)
        glowTex:SetBlendMode("ADD")

        local tex = fxCanvas:CreateTexture(nil, "OVERLAY", nil, 6)
        tex:SetTexture(TEX_STAR4)
        tex:SetBlendMode("ADD")

        sp = {
            glowTex = glowTex,
            tex = tex,
        }
    end
    sp.tex:SetTexCoord(0, 1, 0, 1)
    sp.glowTex:SetTexCoord(0, 1, 0, 1)
    sp.tex:Show()
    sp.glowTex:Show()
    return sp
end

local function ReleaseSpark(sp)
    sp.tex:Hide()
    sp.glowTex:Hide()
    sp.anchorFrame = nil
    if sp.tex.SetRotation then
        sp.tex:SetRotation(0)
        sp.glowTex:SetRotation(0)
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
                local waveVx = 0
                if sp.waveAmp and sp.waveAmp ~= 0 then
                    waveVx = math.sin(sp.age * sp.waveFreq + sp.wavePhase) * sp.waveAmp
                end
                local curVx = sp.vx + waveVx
                local curVy = sp.vy

                sp.x = sp.x + curVx * dt
                sp.y = sp.y + curVy * dt
                sp.vy = sp.vy - sp.gravity * dt

                -- Pop-in envelope + smooth taper + organic particle flicker
                local popEnv = (t < 0.12) and (0.45 + 0.55 * (t / 0.12)) or (1.0 - (t - 0.12) / 0.88)
                local flicker = 1.0
                if sp.flickerAmp and sp.flickerAmp > 0 then
                    flicker = 1.0 - sp.flickerAmp * 0.5 + sp.flickerAmp * (0.5 + 0.5 * math.sin(sp.age * sp.flickerFreq + sp.wavePhase))
                end

                local maxA = sp.maxAlpha or 1.0
                local alpha = Clamp01(popEnv * flicker * maxA)
                local glowAlpha = Clamp01(alpha * (sp.glowAlphaMult or 0.48))

                -- Dynamic size breathing / ember shrink over lifetime
                local scaleLife = 1.0
                if sp.scaleDecay then
                    scaleLife = math.max(0.28, (1.0 - t * sp.scaleDecay) * (0.90 + 0.20 * flicker))
                end
                local curW = (sp.baseW or 6) * scaleLife
                local curH = (sp.baseH or 6) * scaleLife
                sp.tex:SetSize(curW, curH)
                sp.glowTex:SetSize(curW * (sp.glowScaleW or 1.9), curH * (sp.glowScaleH or 1.9))

                if sp.elem == "FIRE" and not sp.isShards then
                    -- Authentic WoW Fire thermal curve: incandescent white-gold -> solar orange -> fiery scarlet -> deep crimson ember
                    local cr = Clamp01(sp.r * (1.05 - t * 0.12))
                    local cg = Clamp01(sp.g * (1.0 - t * 0.68) + (1.0 - t) * 0.18)
                    local cb = Clamp01(sp.b * (1.0 - t * 0.82))
                    local hotR = Clamp01(cr + (1.0 - cr) * (1.0 - t) * 0.55)
                    local hotG = Clamp01(cg + (0.95 - cg) * (1.0 - t) * 0.45)
                    local hotB = Clamp01(cb + (0.55 - cb) * (1.0 - t) * 0.35)
                    sp.tex:SetVertexColor(hotR, hotG, hotB, alpha)
                    sp.glowTex:SetVertexColor(cr, cg * 0.72, cb * 0.40, glowAlpha)
                else
                    sp.tex:SetVertexColor(sp.coreR or sp.r, sp.coreG or sp.g, sp.coreB or sp.b, alpha)
                    sp.glowTex:SetVertexColor(sp.r, sp.g, sp.b, glowAlpha)
                end

                local anchor = sp.anchorFrame or fxCanvas
                sp.tex:ClearAllPoints()
                sp.tex:SetPoint("CENTER", anchor, "CENTER", sp.x, sp.y)
                sp.glowTex:ClearAllPoints()
                sp.glowTex:SetPoint("CENTER", anchor, "CENTER", sp.x, sp.y)

                if sp.alignToVelocity then
                    -- Orient elongated streak texture along instantaneous velocity vector
                    local rotAngle = math.atan2(curVy, curVx) - 1.5707963
                    if sp.tex.SetRotation then
                        sp.tex:SetRotation(rotAngle)
                        sp.glowTex:SetRotation(rotAngle)
                    end
                elseif sp.vRot ~= 0 then
                    sp.rot = sp.rot + sp.vRot * dt
                    if sp.tex.SetRotation then
                        sp.tex:SetRotation(sp.rot)
                        sp.glowTex:SetRotation(-sp.rot * 0.65)
                    end
                end
            end
        end
        return #activeSparks > 0
    end)
end

local function PickElementSparkColor(prof, fallbackR, fallbackG, fallbackB, index)
    local cr, cg, cb = fallbackR, fallbackG, fallbackB
    if prof and prof.sparkPalette and #prof.sparkPalette > 0 then
        local pal = prof.sparkPalette
        local pickIdx = ((index - 1) % #pal) + 1
        if math.random() < 0.45 then
            pickIdx = math.random(1, #pal)
        end
        local entry = pal[pickIdx]
        if entry then
            cr, cg, cb = entry[1], entry[2], entry[3]
        end
    elseif prof and prof.sparkAlt and math.random() < 0.38 then
        cr, cg, cb = prof.sparkAlt[1], prof.sparkAlt[2], prof.sparkAlt[3]
    end
    -- Subtle per-particle organic hue/luminance variation
    local jitter = (math.random() - 0.5) * 0.14
    cr = Clamp01(cr + jitter)
    cg = Clamp01(cg + jitter * 0.85)
    cb = Clamp01(cb + jitter * 0.70)
    return cr, cg, cb
end

function CombatFX:SpawnBarSparks(anchorFrame, cutFraction, count, r, g, b, isShards, elementKey, intensity)
    local cfg = ns.Config:Get("combatFX")
    if not cfg or not cfg.enabled or not cfg.sparksEnabled or not anchorFrame then
        return
    end

    local elem = elementKey or "PHYSICAL"
    local scale = math.max(0.22, math.min(1.0, intensity or 0.85))
    local sizeMult = 0.64 + 0.46 * scale
    local speedMult = 0.55 + 0.45 * scale
    local maxAlpha = math.min(1.0, 0.56 + 0.44 * scale)

    local prof = ns.Elements and ns.Elements:GetProfile(elem) or nil
    local barW = anchorFrame.fuiWidth or 118
    local baseX = 0
    if not isShards and cutFraction and not ns.IsSecret(cutFraction) and barW > 12 then
        baseX = (cutFraction - 0.5) * barW
    end

    count = count or 8
    local defR = r or (prof and prof.spark and prof.spark[1]) or 1.0
    local defG = g or (prof and prof.spark and prof.spark[2]) or 0.78
    local defB = b or (prof and prof.spark and prof.spark[3]) or 0.20

    local barH = anchorFrame.fuiHeight or 12
    local spreadW = barW * 0.92

    for i = 1, count do
        local sp = AcquireSpark()
        local spawnX = baseX
        if isShards or not cutFraction then
            spawnX = (math.random() - 0.5) * spreadW
        else
            spawnX = baseX + (math.random() * 10 - 5) * sizeMult
        end
        local spawnY = (math.random() - 0.5) * (barH * 0.88)

        local angle = -math.pi * 0.12 + math.random() * math.pi * 1.24
        local speed = (58 + math.random() * 140) * speedMult
        local size = (isShards and (3.2 + math.random() * 3.2) or (2.6 + math.random() * 2.6)) * sizeMult
        local variant = ((i + math.random(0, 2)) % 3) + 1

        local pR, pG, pB = PickElementSparkColor(prof, defR, defG, defB, i)
        -- Hot inner core leans slightly toward white-gold / white-cyan for luminous depth
        local coreR = Clamp01(pR + (1.0 - pR) * 0.38)
        local coreG = Clamp01(pG + (1.0 - pG) * 0.35)
        local coreB = Clamp01(pB + (1.0 - pB) * 0.30)

        sp.anchorFrame = anchorFrame
        sp.elem = elem
        sp.isShards = isShards and true or false
        sp.r, sp.g, sp.b = pR, pG, pB
        sp.coreR, sp.coreG, sp.coreB = coreR, coreG, coreB
        sp.maxAlpha = maxAlpha
        sp.glowAlphaMult = 0.46
        sp.glowScaleW = 1.85
        sp.glowScaleH = 1.85
        sp.scaleDecay = 0.45
        sp.flickerAmp = 0.22
        sp.flickerFreq = 14 + math.random() * 10
        sp.alignToVelocity = false
        sp.x = spawnX
        sp.y = spawnY
        sp.vx = math.cos(angle) * speed * (math.random() > 0.5 and 1 or -1)
        sp.vy = math.abs(math.sin(angle)) * speed + 24 * speedMult
        sp.gravity = 280
        sp.waveAmp = 0
        sp.waveFreq = 0
        sp.wavePhase = math.random() * 6.28
        sp.age = 0
        sp.duration = (isShards and (0.54 + math.random() * 0.34) or (0.34 + math.random() * 0.24)) * (0.72 + 0.28 * scale)
        sp.rot = math.random() * 6.28
        sp.vRot = (math.random() - 0.5) * 10

        if elem == "FIRE" and not isShards then
            -- Buoyant rising WoW fire embers & curling flame wisps (zero flat squares!)
            sp.vx = (math.random() - 0.5) * 30 * speedMult
            sp.vy = (24 + math.random() * 52) * speedMult
            sp.gravity = -(165 + math.random() * 55) * speedMult
            sp.waveAmp = (22 + math.random() * 24) * speedMult
            sp.waveFreq = 8 + math.random() * 7
            sp.duration = (0.48 + math.random() * 0.36) * (0.70 + 0.30 * scale)
            sp.flickerAmp = 0.36
            sp.flickerFreq = 18 + math.random() * 14
            sp.scaleDecay = 0.58
            sp.tex:SetBlendMode("ADD")
            sp.glowTex:SetBlendMode("ADD")

            if variant == 1 then
                -- Curling flame wisp streak oriented along rising S-curve
                sp.tex:SetTexture(TEX_SPARK)
                sp.glowTex:SetTexture(TEX_ORB)
                sp.baseW = size * 1.65
                sp.baseH = size * 3.10
                sp.alignToVelocity = true
                sp.glowScaleW = 2.1
                sp.glowScaleH = 1.4
            elseif variant == 2 then
                -- Radiant 4-point ember star flare
                sp.tex:SetTexture(TEX_STAR4)
                sp.glowTex:SetTexture(TEX_ORB)
                sp.baseW = size * 2.35
                sp.baseH = size * 2.35
                sp.vRot = (math.random() - 0.5) * 11
            else
                -- Incandescent soft cinder orb with streak halo
                sp.tex:SetTexture(TEX_ORB)
                sp.glowTex:SetTexture(TEX_SPARK)
                sp.baseW = size * 2.05
                sp.baseH = size * 2.05
                sp.vRot = (math.random() - 0.5) * 7
                sp.glowScaleW = 1.5
                sp.glowScaleH = 2.3
            end
        elseif elem == "LIGHTNING" and not isShards then
            -- High-voltage darting electric streaks & snap-flares
            local fastSpeed = (105 + math.random() * 185) * speedMult
            sp.vx = math.cos(angle) * fastSpeed * (math.random() > 0.5 and 1 or -1)
            sp.vy = (math.random() - 0.35) * fastSpeed
            sp.gravity = 65
            sp.duration = (0.22 + math.random() * 0.18) * (0.72 + 0.28 * scale)
            sp.flickerAmp = 0.48
            sp.flickerFreq = 38 + math.random() * 22
            sp.scaleDecay = 0.35
            sp.tex:SetBlendMode("ADD")
            sp.glowTex:SetBlendMode("ADD")

            if variant ~= 3 then
                -- Velocity-aligned electric discharge streak
                sp.tex:SetTexture(TEX_SPARK)
                sp.glowTex:SetTexture(TEX_SPARK)
                sp.baseW = size * 1.35
                sp.baseH = size * 3.40
                sp.alignToVelocity = true
                sp.glowScaleW = 2.2
                sp.glowScaleH = 1.35
            else
                -- Ionized starburst snap flare
                sp.tex:SetTexture((math.random() > 0.4) and TEX_STAR4 or TEX_STARBURST)
                sp.glowTex:SetTexture(TEX_ORB)
                sp.baseW = size * 2.45
                sp.baseH = size * 2.45
                sp.vRot = (math.random() - 0.5) * 24
            end
        elseif elem == "FROST" and not isShards then
            -- Crystalline spinning ice needles & diamond frost stars
            sp.vx = (math.random() - 0.5) * 115 * speedMult
            sp.vy = (20 + math.random() * 58) * speedMult
            sp.gravity = 380
            sp.duration = (0.42 + math.random() * 0.28) * (0.74 + 0.26 * scale)
            sp.flickerAmp = 0.30
            sp.flickerFreq = 20 + math.random() * 12
            sp.scaleDecay = 0.38
            sp.tex:SetBlendMode("ADD")
            sp.glowTex:SetBlendMode("ADD")

            if variant == 1 then
                -- Razor-sharp crystalline ice needle
                sp.tex:SetTexture(TEX_SPARK)
                sp.glowTex:SetTexture(TEX_STAR4)
                sp.baseW = size * 1.15
                sp.baseH = size * 3.15
                sp.alignToVelocity = true
                sp.glowScaleW = 1.9
                sp.glowScaleH = 0.95
            elseif variant == 2 then
                -- 4-point diamond rime star
                sp.tex:SetTexture(TEX_STAR4)
                sp.glowTex:SetTexture(TEX_ORB)
                sp.baseW = size * 2.40
                sp.baseH = size * 2.40
                sp.vRot = (math.random() - 0.5) * 18
            else
                -- Multi-ray frost crystal burst
                sp.tex:SetTexture(TEX_STARBURST)
                sp.glowTex:SetTexture(TEX_ORB)
                sp.baseW = size * 2.20
                sp.baseH = size * 2.20
                sp.vRot = (math.random() - 0.5) * 14
            end
        elseif (elem == "SHADOW" or elem == "NATURE" or elem == "HOLY" or elem == "ARCANE") and not isShards then
            -- Hovering/drifting WoW spell-school motes, rings & astral stars
            sp.vx = (math.random() - 0.5) * 36 * speedMult
            sp.vy = (10 + math.random() * 28) * speedMult
            sp.gravity = (elem == "HOLY") and (-48 * speedMult) or (-28 * speedMult)
            sp.waveAmp = (18 + math.random() * 16) * speedMult
            sp.waveFreq = 6 + math.random() * 6
            sp.duration = (0.48 + math.random() * 0.32) * (0.70 + 0.30 * scale)
            sp.flickerAmp = 0.32
            sp.flickerFreq = 14 + math.random() * 10
            sp.scaleDecay = 0.42
            sp.tex:SetBlendMode("ADD")
            sp.glowTex:SetBlendMode("ADD")

            if variant == 1 then
                sp.tex:SetTexture(TEX_STAR4)
                sp.glowTex:SetTexture(TEX_ORB)
                sp.baseW = size * 2.45
                sp.baseH = size * 2.45
                sp.vRot = (math.random() - 0.5) * 12
            elseif variant == 2 then
                -- Swirling void/arcane/nature ring mote
                sp.tex:SetTexture((elem == "SHADOW" or elem == "ARCANE") and TEX_RING or TEX_ORB)
                sp.glowTex:SetTexture(TEX_ORB)
                sp.baseW = size * 2.15
                sp.baseH = size * 2.15
                sp.vRot = (math.random() - 0.5) * 9
            else
                -- Rising/drifting energy wisp
                sp.tex:SetTexture(TEX_SPARK)
                sp.glowTex:SetTexture(TEX_ORB)
                sp.baseW = size * 1.50
                sp.baseH = size * 2.85
                sp.alignToVelocity = true
            end
        elseif elem == "EARTH" or isShards then
            -- Textured mineral/stone shards & quartz dust glints (uses shaded UI-StatusBar & star4, never flat WHITE8X8!)
            sp.vx = (math.random() - 0.5) * 74 * speedMult
            sp.vy = (28 + math.random() * 58) * speedMult
            sp.gravity = (elem == "EARTH") and 620 or 440
            sp.duration = (0.46 + math.random() * 0.30) * (0.74 + 0.26 * scale)
            sp.vRot = (math.random() - 0.5) * 22
            sp.scaleDecay = 0.30
            sp.flickerAmp = 0.14

            if variant == 3 and not isShards then
                -- Sunlit quartz/mineral spark glint accompanying rock impact
                sp.tex:SetTexture(TEX_STAR4)
                sp.glowTex:SetTexture(TEX_ORB)
                sp.tex:SetBlendMode("ADD")
                sp.glowTex:SetBlendMode("ADD")
                sp.baseW = size * 2.10
                sp.baseH = size * 2.10
                sp.glowAlphaMult = 0.38
            else
                -- Shaded beveled stone/crystal chip with varied aspect ratio
                sp.tex:SetTexture(TEX_SHARD)
                sp.tex:SetTexCoord(0.10, 0.90, 0.15, 0.85)
                sp.tex:SetBlendMode("BLEND")
                sp.glowTex:SetTexture(TEX_ORB)
                sp.glowTex:SetBlendMode("ADD")
                sp.glowAlphaMult = 0.22
                local aspect = 0.55 + math.random() * 0.95
                sp.baseW = size * (1.35 + aspect * 0.55)
                sp.baseH = size * (1.45 - aspect * 0.35)
                sp.coreR, sp.coreG, sp.coreB = pR, pG, pB
            end
        else
            -- PHYSICAL / Metallic cleave & ricochet sparks: velocity-aligned steel streaks + star4 glints
            sp.tex:SetBlendMode("ADD")
            sp.glowTex:SetBlendMode("ADD")
            sp.flickerAmp = 0.28
            sp.scaleDecay = 0.45
            if variant ~= 3 then
                sp.tex:SetTexture(TEX_SPARK)
                sp.glowTex:SetTexture(TEX_ORB)
                sp.baseW = size * 1.35
                sp.baseH = size * 3.00
                sp.alignToVelocity = true
                sp.glowScaleW = 1.9
                sp.glowScaleH = 1.25
            else
                sp.tex:SetTexture(TEX_STAR4)
                sp.glowTex:SetTexture(TEX_ORB)
                sp.baseW = size * 2.35
                sp.baseH = size * 2.35
                sp.vRot = (math.random() - 0.5) * 16
            end
        end

        sp.tex:SetSize(sp.baseW, sp.baseH)
        sp.glowTex:SetSize(sp.baseW * sp.glowScaleW, sp.baseH * sp.glowScaleH)

        if sp.alignToVelocity then
            local initRot = math.atan2(sp.vy, sp.vx) - 1.5707963
            if sp.tex.SetRotation then
                sp.tex:SetRotation(initRot)
                sp.glowTex:SetRotation(initRot)
            end
        elseif sp.vRot ~= 0 and sp.tex.SetRotation then
            sp.tex:SetRotation(sp.rot)
            sp.glowTex:SetRotation(-sp.rot * 0.65)
        end

        sp.tex:SetVertexColor(sp.coreR, sp.coreG, sp.coreB, maxAlpha)
        sp.glowTex:SetVertexColor(sp.r, sp.g, sp.b, maxAlpha * sp.glowAlphaMult)

        sp.tex:ClearAllPoints()
        sp.tex:SetPoint("CENTER", anchorFrame, "CENTER", sp.x, sp.y)
        sp.glowTex:ClearAllPoints()
        sp.glowTex:SetPoint("CENTER", anchorFrame, "CENTER", sp.x, sp.y)
        table.insert(activeSparks, sp)
    end

    EnsureSparkTicker()
end

-- ============================================================================
-- 1B. POOLED JAGGED LIGHTNING CRACKLE ARCS & TECTONIC FAULT LINES
--     Uses plasma-textured segment glows (UI-CastingBar-Spark) + star4 vertex
--     flares so lightning arcs crackle with authentic WoW spell depth!
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
        local jointFlares = {}
        for i = 1, BOLT_SEGMENTS do
            local glow = holder:CreateTexture(nil, "OVERLAY", nil, 5)
            glow:SetTexture(TEX_SPARK)
            glow:SetBlendMode("ADD")

            local core = holder:CreateTexture(nil, "OVERLAY", nil, 7)
            core:SetTexture(TEX_SPARK)
            core:SetBlendMode("ADD")

            local flare = holder:CreateTexture(nil, "OVERLAY", nil, 6)
            flare:SetTexture(TEX_STAR4)
            flare:SetBlendMode("ADD")

            glowLines[i] = glow
            coreLines[i] = core
            jointFlares[i] = flare
        end
        bolt = {
            holder = holder,
            glowLines = glowLines,
            coreLines = coreLines,
            jointFlares = jointFlares,
        }
    end
    bolt.holder:Show()
    bolt.holder:SetAlpha(1.0)
    for i = 1, BOLT_SEGMENTS do
        bolt.glowLines[i]:Show()
        bolt.coreLines[i]:Show()
        bolt.jointFlares[i]:Show()
    end
    return bolt
end

local function ReleaseLightningBolt(bolt)
    for i = 1, BOLT_SEGMENTS do
        bolt.glowLines[i]:Hide()
        bolt.coreLines[i]:Hide()
        if bolt.jointFlares and bolt.jointFlares[i] then
            bolt.jointFlares[i]:Hide()
        end
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
        -- Shaded stone tectonic fault crack running diagonally/vertically across the remaining HP bar
        local centerX = (bolt.crackBiasX or 0) * (currentW * 0.70)
        local prevX = centerX + (math.random() * 4 - 2) * scale
        local prevY = -currentH * 0.52
        local glowThick = 2.0 + 1.6 * scale
        local coreThick = 1.2 + 1.1 * scale

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
            glow:SetTexture(TEX_SHARD)
            glow:SetBlendMode("BLEND")
            glow:ClearAllPoints()
            glow:SetPoint("CENTER", bolt.holder, "CENTER", midX + 0.7, midY)
            glow:SetSize(segLen + 1.2, glowThick)
            glow:SetVertexColor(0.88, 0.74, 0.46, effAlpha * 0.90)
            if glow.SetRotation then
                glow:SetRotation(angle)
            end

            local core = bolt.coreLines[i]
            core:SetTexture(TEX_SHARD)
            core:SetBlendMode("BLEND")
            core:ClearAllPoints()
            core:SetPoint("CENTER", bolt.holder, "CENTER", midX, midY)
            core:SetSize(segLen + 0.6, coreThick)
            core:SetVertexColor(0.08, 0.05, 0.02, effAlpha)
            if core.SetRotation then
                core:SetRotation(angle)
            end

            local flare = bolt.jointFlares and bolt.jointFlares[i]
            if flare then
                if i % 2 == 1 then
                    flare:SetTexture(TEX_STAR4)
                    flare:SetBlendMode("ADD")
                    flare:ClearAllPoints()
                    flare:SetPoint("CENTER", bolt.holder, "CENTER", nextX, nextY)
                    local fSize = (3.5 + 2.5 * scale)
                    flare:SetSize(fSize, fSize)
                    flare:SetVertexColor(0.95, 0.80, 0.48, effAlpha * 0.55)
                    flare:Show()
                else
                    flare:Hide()
                end
            end

            prevX = nextX
            prevY = nextY
        end
        return
    end

    local w = currentW * (0.40 + 0.56 * scale)
    local h = currentH * (0.48 + 0.48 * scale)
    local glowThick = 3.2 + 3.4 * scale
    local coreThick = 1.4 + 1.5 * scale

    local prevX = -w * 0.46 + (math.random() * 4 - 2) * scale
    local prevY = (math.random() - 0.5) * (h * 0.85)

    for i = 1, BOLT_SEGMENTS do
        local frac = i / BOLT_SEGMENTS
        local nextX = (-0.46 + frac * 0.92) * w + (math.random() * 6 - 3) * scale
        local nextY = (math.random() - 0.5) * (h * 1.15)

        local dx = nextX - prevX
        local dy = nextY - prevY
        local segLen = math.max(2.0, math.sqrt(dx * dx + dy * dy))
        local midX = (prevX + nextX) * 0.5
        local midY = (prevY + nextY) * 0.5
        local angle = math.atan2(dy, dx)

        local glow = bolt.glowLines[i]
        glow:SetTexture(TEX_ORB)
        glow:SetBlendMode("ADD")
        glow:ClearAllPoints()
        glow:SetPoint("CENTER", bolt.holder, "CENTER", midX, midY)
        glow:SetSize(segLen + 3.0, glowThick)
        -- Alternate between Shaman storm-cyan and ionized blue-violet plasma
        if i % 2 == 0 then
            glow:SetVertexColor(0.24, 0.78, 1.00, effAlpha * 0.72)
        else
            glow:SetVertexColor(0.45, 0.68, 1.00, effAlpha * 0.68)
        end
        if glow.SetRotation then
            glow:SetRotation(angle)
        end

        local core = bolt.coreLines[i]
        core:SetTexture(TEX_ORB)
        core:SetBlendMode("ADD")
        core:ClearAllPoints()
        core:SetPoint("CENTER", bolt.holder, "CENTER", midX, midY)
        core:SetSize(segLen + 1.2, coreThick)
        core:SetVertexColor(0.92, 0.99, 1.00, effAlpha * 0.92)
        if core.SetRotation then
            core:SetRotation(angle)
        end

        local flare = bolt.jointFlares and bolt.jointFlares[i]
        if flare then
            flare:SetTexture(TEX_STAR4)
            flare:SetBlendMode("ADD")
            flare:ClearAllPoints()
            flare:SetPoint("CENTER", bolt.holder, "CENTER", nextX, nextY)
            local fSize = (4.5 + 4.0 * scale) * (0.8 + math.random() * 0.4)
            flare:SetSize(fSize, fSize)
            flare:SetVertexColor(0.75, 0.96, 1.00, effAlpha * 0.80)
            if flare.SetRotation then
                flare:SetRotation(math.random() * 3.14)
            end
            flare:Show()
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
        flashTex:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
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

    -- Burst of textured stone shards + elemental spell particles on killing blow
    self:SpawnBarSparks(barFrame, 0.5, 4, db.shardC[1], db.shardC[2], db.shardC[3], true, elem, 0.48)
    local elemR = (prof and prof.spark and prof.spark[1]) or db.flashC[1]
    local elemG = (prof and prof.spark and prof.spark[2]) or db.flashC[2]
    local elemB = (prof and prof.spark and prof.spark[3]) or db.flashC[3]
    self:SpawnBarSparks(barFrame, 0.5, 5, elemR, elemG, elemB, false, elem, 0.65)
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
