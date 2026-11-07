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
    { x = -22, y = 0, vx = -46, vy = 82, dir = -1 }, -- Lane 1: Left outer fountain arc
    { x =  22, y = 0, vx =  46, vy = 82, dir =  1 }, -- Lane 2: Right outer fountain arc
    { x = -11, y = 7, vx = -22, vy = 96, dir = -1 }, -- Lane 3: Left high inner arc
    { x =  11, y = 7, vx =  22, vy = 96, dir =  1 }, -- Lane 4: Right high inner arc
}
local laneCursor = 0
local critSideToggle = 1
local dotSideToggle = 1

-- Rapid-Hit "Flurry" Escalation & Dynamic Hit-Magnitude Baseline state
local flurryCount = 0
local lastHitTime = 0
CombatText.rollingAvgHit = nil

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

-- Computes a 0.0..1.0 hit weight so a 25 hit at level 11 is visibly much larger than an 11 hit!
function CombatText:ComputeHitWeight(numericAmount, isCrit, baseWeight, isDot)
    if isDot then
        return 0.12
    end
    local weight = baseWeight or 0.32
    if numericAmount and not ns.IsSecret(numericAmount) and type(numericAmount) == "number" and numericAmount > 0 then
        if not self.rollingAvgHit or self.rollingAvgHit <= 0 then
            local lvl = (UnitLevel and UnitLevel("player")) or 11
            if ns.IsSecret(lvl) or type(lvl) ~= "number" or lvl <= 0 then
                lvl = 11
            end
            -- At level 11, baseline is ~15.4 (right between an 11 white hit and a 25 spell/ability hit)
            self.rollingAvgHit = math.max(8, lvl * 1.40)
        end
        local ref = self.rollingAvgHit
        if not isCrit then
            self.rollingAvgHit = ref * 0.80 + numericAmount * 0.20
        end
        local ratio = numericAmount / math.max(1, ref)
        -- ratio 0.65 (e.g. 11 at lvl 11) -> ~0.22 weight
        -- ratio 1.55 (e.g. 25 at lvl 11) -> ~0.95 weight
        local amountWeight = math.max(0.14, math.min(1.0, (ratio - 0.42) / 1.12))
        weight = math.max(weight, amountWeight)
    end
    return math.max(0.10, math.min(1.0, weight))
end

local function AcquireTextEntry()
    local entry = table.remove(textPool)
    if not entry then
        -- Outer holder stays at scale 1.0 so SetPoint offsets never get multiplied by SetScale!
        local holder = CreateFrame("Frame", nil, sctCanvas)
        holder:SetSize(1, 1)
        holder:SetFrameStrata("TOOLTIP")
        holder:SetFrameLevel(210)

        -- Expanding Shockwave Echo frame (behind main zoomFrame on Crits & Killing Blows)
        local echoZoom = CreateFrame("Frame", nil, holder)
        echoZoom:SetSize(260, 60)
        echoZoom:SetPoint("CENTER", holder, "CENTER", 0, 0)
        echoZoom:SetFrameLevel(210)

        local echoFs = echoZoom:CreateFontString(nil, "BACKGROUND")
        echoFs:SetPoint("CENTER", echoZoom, "CENTER", 0, 0)

        local echoBangFs = echoZoom:CreateFontString(nil, "BACKGROUND")
        echoBangFs:SetPoint("LEFT", echoFs, "RIGHT", 1, 0)

        -- Inner zoomFrame sits at (0, 0) center of holder and handles elastic Pop-In scaling
        local zoomFrame = CreateFrame("Frame", nil, holder)
        zoomFrame:SetSize(260, 60)
        zoomFrame:SetPoint("CENTER", holder, "CENTER", 0, 0)
        zoomFrame:SetFrameLevel(212)

        local fs = zoomFrame:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER", zoomFrame, "CENTER", 0, 0)
        fs:SetShadowOffset(2.0, -2.0)
        fs:SetShadowColor(0, 0, 0, 0.96)

        -- Separate "!" / "!!" FontString anchored to the right of fs (100% Secret-Value compatible!)
        local bangFs = zoomFrame:CreateFontString(nil, "OVERLAY")
        bangFs:SetPoint("LEFT", fs, "RIGHT", 1, 0)
        bangFs:SetShadowOffset(2.0, -2.0)
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
    entry.active = true
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
    entry.active = false
    entry.holder:Hide()
    entry.echoZoom:Hide()
    entry.bangFs:Hide()
    entry.echoBangFs:Hide()
    entry.anchorFrame = nil
    entry.woundAnchor = nil
    table.insert(textPool, entry)
end

local function ApplyTextEntryAnchors(ft, shakeX, shakeY)
    ft.holder:ClearAllPoints()
    local ox = ft.offsetX + (ft.waveOffsetX or 0) + shakeX
    local oy = ft.offsetY + shakeY
    -- B. Spawn at the exact health bar wound (fillOverlay TOPRIGHT seam) for live hits,
    --    and center on anchorFrame TOP for Killing Blows / Interrupts / Deflects!
    if ft.useWoundAnchor and ft.woundAnchor and (not ft.woundAnchor.IsShown or ft.woundAnchor:IsShown()) and not ft.isKill then
        ft.holder:SetPoint("CENTER", ft.woundAnchor, "TOPRIGHT", ox, oy)
    elseif ft.anchorFrame then
        ft.holder:SetPoint("CENTER", ft.anchorFrame, "TOP", ox, oy)
    else
        ft.holder:SetPoint("CENTER", UIParent, "CENTER", ft.baseCenterX + ox, ft.baseCenterY + oy)
    end
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
                local elem = ft.elementKey or "PHYSICAL"

                -- ============================================================
                -- A. ELEMENT-SPECIFIC PHYSICS & MOTION TRAJECTORIES
                -- ============================================================
                if ft.useElementPhysics and not ft.isDeflect and not ft.isInterrupt and not ft.isDot and not ft.isKill then
                    if elem == "LIGHTNING" then
                        -- Electric snap-bolt deceleration + continuous high-voltage jitter
                        local drag = math.max(0, 1.0 - 5.6 * dt)
                        ft.vx = ft.vx * drag
                        ft.vy = ft.vy * drag
                        ft.offsetX = ft.offsetX + ft.vx * dt
                        ft.offsetY = ft.offsetY + ft.vy * dt
                    elseif elem == "FIRE" then
                        -- Buoyant rising flame (negative gravity accelerates smoothly upward)
                        ft.offsetX = ft.offsetX + ft.vx * dt
                        ft.offsetY = ft.offsetY + ft.vy * dt
                        ft.vy = ft.vy - ft.gravity * dt
                    elseif elem == "EARTH" then
                        -- Heavy seismic arc that slams onto an invisible rock ledge & bounces!
                        ft.offsetX = ft.offsetX + ft.vx * dt
                        ft.offsetY = ft.offsetY + ft.vy * dt
                        ft.vy = ft.vy - ft.gravity * dt
                        if ft.bouncesLeft > 0 and ft.vy < 0 and ft.offsetY <= ft.bounceFloorY then
                            ft.offsetY = ft.bounceFloorY
                            ft.vy = math.abs(ft.vy) * 0.54
                            ft.vx = ft.vx * 0.72
                            ft.bouncesLeft = ft.bouncesLeft - 1
                            ft.bounceShakeTimer = 0.12
                        end
                    elseif elem == "FROST" then
                        -- Crystalline freeze-lock at apex (0.16s..0.56s), then icicle shatter drop!
                        if ft.age >= 0.16 and ft.age <= 0.56 then
                            ft.offsetX = ft.offsetX + (ft.vx * 0.08) * dt
                            ft.offsetY = ft.offsetY + (ft.vy * 0.08) * dt
                        elseif ft.age > 0.56 then
                            ft.dropVy = (ft.dropVy or 0) - 245 * dt
                            ft.offsetX = ft.offsetX + (ft.vx * 0.20) * dt
                            ft.offsetY = ft.offsetY + ft.dropVy * dt
                        else
                            ft.offsetX = ft.offsetX + ft.vx * dt
                            ft.offsetY = ft.offsetY + ft.vy * dt
                            ft.vy = ft.vy - ft.gravity * dt
                        end
                    else
                        ft.offsetX = ft.offsetX + ft.vx * dt
                        ft.offsetY = ft.offsetY + ft.vy * dt
                        ft.vy = ft.vy - ft.gravity * dt
                    end
                else
                    ft.offsetX = ft.offsetX + ft.vx * dt
                    ft.offsetY = ft.offsetY + ft.vy * dt
                    ft.vy = ft.vy - ft.gravity * dt
                end

                local scale = ft.settleScale or 1.0
                local shakeX, shakeY = 0, 0

                if ft.isKill then
                    -- D. KILLING BLOW FINISHER: Massive slam-in (2.35x -> 1.56x) + extended seismic shudder
                    local peak = ft.peakScale or 2.35
                    local settle = ft.settleScale or 1.56
                    if ft.age < 0.09 then
                        scale = 0.50 + (ft.age / 0.09) * (peak - 0.50)
                    elseif ft.age < 0.26 then
                        scale = peak - ((ft.age - 0.09) / 0.17) * (peak - settle)
                    else
                        scale = settle
                    end
                    if ft.age >= 0.03 and ft.age <= 0.32 then
                        local damper = 1.0 - ((ft.age - 0.03) / 0.29)
                        local mag = 5.2 * damper
                        shakeX = math.sin(ft.age * 155.0) * mag
                        shakeY = math.cos(ft.age * 175.0) * (mag * 0.70)
                    end
                elseif ft.isCrit then
                    local peak = ft.peakScale or 1.85
                    local settle = ft.settleScale or 1.32
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
                else
                    -- Dynamic pop-in for normal & DoT hits: heavy normal hits (25 at lvl 11) punch much harder than light hits (11)!
                    local peak = ft.peakScale or 1.15
                    local settle = ft.settleScale or 1.0
                    if ft.age < 0.07 then
                        scale = (settle * 0.78) + (ft.age / 0.07) * (peak - settle * 0.78)
                    elseif ft.age < 0.16 then
                        scale = peak - ((ft.age - 0.07) / 0.09) * (peak - settle)
                    else
                        scale = settle
                    end

                    -- Brief impact-only vibration right when the hit or DoT tick lands (0.00s..0.13s), then 100% steady!
                    if ft.age <= 0.13 then
                        local damper = 1.0 - (ft.age / 0.13)
                        local mag = (ft.isDot and 1.1 or (1.2 + (ft.hitWeight or 0.3) * 1.4)) * damper
                        shakeX = math.sin(ft.age * 165.0) * mag
                        shakeY = math.cos(ft.age * 185.0) * (mag * 0.65)
                    end
                end

                -- Brief secondary impact vibration ONLY on Earth's bounce thud (never continuous while floating)
                if ft.useElementPhysics and elem == "EARTH" and (ft.bounceShakeTimer or 0) > 0 then
                    ft.bounceShakeTimer = ft.bounceShakeTimer - dt
                    local bFade = math.max(0, ft.bounceShakeTimer / 0.12)
                    shakeX = shakeX + math.sin(ft.age * 140.0) * 2.4 * bFade
                    shakeY = shakeY + math.cos(ft.age * 160.0) * 1.8 * bFade
                    scale = scale * (1.0 + 0.12 * bFade)
                end

                -- Color heat/element gradients
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
                elseif ft.useElementPhysics and elem == "FIRE" and not ft.isDot then
                    -- Rising fire numbers cool from molten gold-orange into deep scarlet-orange as they climb
                    local coolT = math.min(1.0, t * 1.15)
                    local cr = 1.0
                    local cg = math.max(0.24, ft.baseG * (1.0 - coolT * 0.42))
                    local cb = math.max(0.02, ft.baseB * (1.0 - coolT * 0.65))
                    ft.fs:SetTextColor(cr, cg, cb, 1.0)
                    ft.bangFs:SetTextColor(cr, cg, cb, 1.0)
                elseif ft.useElementPhysics and elem == "FROST" and ft.age >= 0.16 and ft.age <= 0.56 then
                    -- Crystalline white-cyan glint while frozen at apex
                    ft.fs:SetTextColor(0.86, 0.98, 1.00, 1.0)
                    ft.bangFs:SetTextColor(0.86, 0.98, 1.00, 1.0)
                elseif ft.useElementPhysics and elem == "FROST" and ft.age > 0.56 then
                    ft.fs:SetTextColor(ft.baseR, ft.baseG, ft.baseB, 1.0)
                    ft.bangFs:SetTextColor(ft.baseR, ft.baseG, ft.baseB, 1.0)
                end

                -- Expanding Shockwave Echo ring behind Crits & Killing Blows
                if ft.hasShockwave then
                    local echoDur = ft.isKill and 0.44 or 0.34
                    if ft.age <= echoDur then
                        local echoT = ft.age / echoDur
                        local echoScale = scale * (1.0 + echoT * (ft.isKill and 1.35 or 1.15))
                        local echoAlpha = math.max(0, (1.0 - echoT) * (ft.isKill and 0.80 or 0.68))
                        ft.echoZoom:SetScale(echoScale)
                        ft.echoZoom:SetAlpha(echoAlpha)
                    else
                        ft.echoZoom:Hide()
                    end
                end

                local fadeStart = ft.isKill and 0.76 or 0.72
                local alpha = 1.0
                if t > fadeStart then
                    alpha = math.max(0, 1.0 - (t - fadeStart) / (1.0 - fadeStart))
                end

                ApplyTextEntryAnchors(ft, shakeX, shakeY)
                ft.zoomFrame:SetScale(scale)
                ft.holder:SetAlpha(alpha)
            end
        end
        return #activeTexts > 0
    end)
end

-- D. Upgrades an active in-flight damage number into a Killing Blow Finisher when the enemy dies!
function CombatText:PromoteToKillingBlow(entry, elementKey)
    local cfg = ns.Config:Get("combatText")
    if not entry or not entry.active or entry.isKill or not cfg or (cfg.killFinisher == false) then
        return
    end

    local elem = elementKey or entry.elementKey or "PHYSICAL"
    local prof = ns.Elements and ns.Elements:GetProfile(elem)
    local col = (prof and prof.critText) or { 1.0, 0.82, 0.0 }
    local r, g, b = col[1], col[2], col[3]
    if elem == "PHYSICAL" then
        r, g, b = 1.0, 0.76, 0.12
    end

    local fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local killFontSize = cfg.killFontSize or 38

    entry.isKill = true
    entry.isCrit = true
    entry.isMega = true
    entry.isDot = false
    entry.hasShockwave = (cfg.critShockwave ~= false)
    entry.useWoundAnchor = false
    entry.elementKey = elem
    entry.baseR, entry.baseG, entry.baseB = r, g, b

    entry.fs:SetFont(fontPath, killFontSize, "THICKOUTLINE")
    entry.fs:SetTextColor(1.0, 0.98, 0.90, 1.0)

    entry.bangFs:SetFont(fontPath, killFontSize, "THICKOUTLINE")
    entry.bangFs:SetText("!!")
    entry.bangFs:SetTextColor(1.0, 0.98, 0.90, 1.0)
    entry.bangFs:Show()

    if entry.hasShockwave then
        entry.echoFs:SetFont(fontPath, killFontSize, "THICKOUTLINE")
        entry.echoFs:SetTextColor(r, g, b, 0.82)
        entry.echoBangFs:SetFont(fontPath, killFontSize, "THICKOUTLINE")
        entry.echoBangFs:SetText("!!")
        entry.echoBangFs:SetTextColor(r, g, b, 0.82)
        entry.echoBangFs:Show()
        entry.echoZoom:SetScale(1.0)
        entry.echoZoom:SetAlpha(0.80)
        entry.echoZoom:Show()
    end

    entry.peakScale = 2.35
    entry.settleScale = 1.56
    entry.age = 0
    entry.duration = cfg.durationKill or 1.95
    entry.offsetX = 0
    entry.offsetY = (cfg.critOffsetY or 34) + 6
    entry.waveOffsetX = 0
    entry.vx = 0
    entry.vy = 24
    entry.gravity = 12
end

-- Pure text-only combat number spawn (no icons).
-- Supports WoW 12.0+ / 16001 Secret Number Values directly via FontString:SetText(secretVal).
function CombatText:SpawnNumber(opts)
    local cfg = ns.Config:Get("combatText")
    if not cfg or not cfg.enabled or not opts or opts.text == nil then
        return nil
    end

    local isDeflect = not not opts.isDeflect
    local isInterrupt = not not opts.isInterrupt
    local isDot = not not opts.isDot
    local isKill = (not not opts.isKill) and (cfg.killFinisher ~= false)
    local isCrit = (not not opts.isCrit) or isKill
    local isMega = (not not opts.isMega) or isKill

    local now = GetTime()
    local flurryWindow = cfg.flurryWindow or 1.45
    if not isDeflect and not isInterrupt and not isDot then
        if (now - lastHitTime) <= flurryWindow then
            flurryCount = math.min(8, flurryCount + 1)
        else
            flurryCount = 1
        end
        lastHitTime = now
    end

    local flurryFactor = ((not isDeflect and not isInterrupt and not isDot) and cfg.flurryEscalation ~= false)
        and ((flurryCount - 1) / 7.0) or 0.0
    local flurryScale = 1.0 + flurryFactor * 0.22

    -- Compute continuous hitWeight (0.12 for DoTs, ~0.25 for white 11 hit, ~0.92 for heavy 25 ability hit)
    local hitWeight = opts.hitWeightComputed and (opts.hitWeight or 0.32)
        or self:ComputeHitWeight(opts.numericAmount, isCrit, opts.hitWeight, isDot)

    local entry = AcquireTextEntry()
    local hasShockwave = (isCrit or isKill) and (cfg.critShockwave ~= false)

    local fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local baseNormalSize = cfg.normalFontSize or 21
    local fontSize
    if isKill then
        fontSize = cfg.killFontSize or 38
    elseif isMega then
        fontSize = cfg.megaFontSize or 35
    elseif isCrit then
        fontSize = cfg.critFontSize or 30
    elseif isDeflect then
        fontSize = math.max(18, baseNormalSize)
    elseif isDot then
        fontSize = cfg.dotFontSize or 16
    else
        -- Scale normal hit font size dynamically by hitWeight:
        -- Light hit (11 at lvl 11, weight ~0.25) -> ~20pt
        -- Heavy normal hit (25 at lvl 11, weight ~0.92) -> ~27pt!
        fontSize = math.floor(baseNormalSize * (0.86 + 0.44 * hitWeight) + 0.5)
    end

    local isHeavyNormal = (not isCrit) and (not isDot) and (not isDeflect) and (hitWeight >= 0.68)
    local fontFlags = (isKill or isCrit or isDeflect or isHeavyNormal) and "THICKOUTLINE" or "OUTLINE"

    entry.fs:SetFont(fontPath, fontSize, fontFlags)
    SetFontStringTextSafe(entry.fs, opts.text)

    -- Compute base color (with Rapid-Hit Flurry & Heavy-Hit heat tint warming white hits into gold/orange!)
    local r = opts.r or 1.0
    local g = opts.g or 1.0
    local b = opts.b or 1.0
    local elementKey = opts.elementKey or "PHYSICAL"
    local hasElementalTint = elementKey ~= "PHYSICAL"

    if isKill and not hasElementalTint then
        r, g, b = 1.0, 0.78, 0.14
    elseif not isCrit and not isDeflect and not hasElementalTint and r > 0.9 and g > 0.9 and b > 0.9 then
        local warmth = math.max(flurryFactor, isHeavyNormal and ((hitWeight - 0.55) * 0.85) or 0)
        if warmth > 0.05 then
            r = 1.0
            g = 1.0 - warmth * 0.36
            b = 1.0 - warmth * 0.78
        end
    elseif isCrit and not isInterrupt and not hasElementalTint then
        r = 1.0
        g = isMega and 0.48 or math.max(0.45, (opts.g or 0.82) - flurryFactor * 0.25)
        b = 0.04
    end

    entry.baseR, entry.baseG, entry.baseB = r, g, b
    entry.elementKey = elementKey

    if hasShockwave then
        -- Start Crits & Killing Blows White-Hot on frame 0; ticker burns them into entry.baseR/G/B
        entry.fs:SetTextColor(1.0, 0.98, 0.90, 1.0)
    else
        entry.fs:SetTextColor(r, g, b, 1.0)
    end

    -- Punctuation accent ("!" on Crits, Heavy Normal Hits, or high Flurry; "!!" on Mega Crits & Killing Blows)
    local bangText = nil
    if not isDeflect and not isDot then
        if isKill or isMega or (isCrit and flurryCount >= 4 and not isInterrupt) then
            bangText = "!!"
        elseif isCrit or hitWeight >= 0.80 or flurryCount >= 5 then
            bangText = "!"
        end
    end

    if bangText then
        entry.bangFs:SetFont(fontPath, fontSize, fontFlags)
        entry.bangFs:SetText(bangText)
        entry.bangFs:SetTextColor(hasShockwave and 1.0 or r, hasShockwave and 0.98 or g, hasShockwave and 0.90 or b, 1.0)
        entry.bangFs:Show()
    else
        entry.bangFs:Hide()
    end

    -- Crit / Killing Blow Shockwave Echo Afterimage setup
    if hasShockwave then
        local echoR = isInterrupt and 0.15 or (hasElementalTint and r or 1.0)
        local echoG = isInterrupt and 0.88 or (hasElementalTint and g or (isMega and 0.35 or 0.65))
        local echoB = isInterrupt and 1.00 or (hasElementalTint and b or 0.05)
        entry.echoFs:SetFont(fontPath, fontSize, fontFlags)
        SetFontStringTextSafe(entry.echoFs, opts.text)
        entry.echoFs:SetTextColor(echoR, echoG, echoB, 0.78)
        if bangText then
            entry.echoBangFs:SetFont(fontPath, fontSize, fontFlags)
            entry.echoBangFs:SetText(bangText)
            entry.echoBangFs:SetTextColor(echoR, echoG, echoB, 0.78)
            entry.echoBangFs:Show()
        end
        entry.echoZoom:SetScale(1.0)
        entry.echoZoom:SetAlpha(isKill and 0.82 or 0.72)
        entry.echoZoom:Show()
    else
        entry.echoZoom:Hide()
    end

    entry.anchorFrame = opts.anchorFrame
    entry.woundAnchor = opts.woundAnchor
    entry.useWoundAnchor = (cfg.anchorToWound ~= false) and (opts.woundAnchor ~= nil) and (not isKill) and (not isInterrupt) and (not isDeflect)
    entry.useElementPhysics = (cfg.elementalPhysics ~= false)
    entry.baseCenterX = (opts.side == "left") and -140 or 185
    entry.baseCenterY = (opts.side == "left") and 20 or 55

    -- Compute Pop-In Peak & Settle Scales
    if isKill then
        entry.peakScale = 2.35
        entry.settleScale = 1.56
    elseif isCrit then
        entry.peakScale = (isMega and 2.12 or 1.85) * flurryScale
        entry.settleScale = (isMega and 1.46 or 1.30) * flurryScale
    elseif isDot then
        entry.peakScale = 0.96
        entry.settleScale = 0.86
    else
        -- Light hit (11 at lvl 11, weight ~0.25) -> settle ~1.00x, peak ~1.16x
        -- Heavy normal hit (25 at lvl 11, weight ~0.92) -> settle ~1.22x, peak ~1.50x!
        entry.settleScale = (0.92 + 0.32 * hitWeight) * flurryScale
        entry.peakScale = entry.settleScale * (1.14 + 0.12 * hitWeight)
    end

    local baseOffsetY = isCrit and (cfg.critOffsetY or 34) or (cfg.baseOffsetY or 24)
    local speedMult = (0.92 + 0.22 * hitWeight) + flurryFactor * 0.18

    laneCursor = (laneCursor % #FOUNTAIN_LANES) + 1
    local lane = FOUNTAIN_LANES[laneCursor]
    local laneDir = lane.dir or 1

    entry.waveOffsetX = 0
    entry.waveAmp = 0
    entry.waveFreq = 0
    entry.wavePhase = 0
    entry.bouncesLeft = 0
    entry.bounceFloorY = baseOffsetY - 4
    entry.bounceShakeTimer = 0
    entry.dropVy = 0
    entry.gravity = 52

    if isKill then
        entry.offsetX = 0
        entry.offsetY = (cfg.critOffsetY or 34) + 6
        entry.vx = 0
        entry.vy = 24
        entry.gravity = 12
    elseif isDeflect then
        -- Metallic sideways ricochet trajectory off the bar
        critSideToggle = -critSideToggle
        entry.offsetX = critSideToggle * 18
        entry.offsetY = baseOffsetY - 4
        entry.vx = critSideToggle * (92 + math.random() * 24)
        entry.vy = 54 + math.random() * 14
        entry.gravity = 115
    elseif isInterrupt then
        entry.offsetX = 0
        entry.offsetY = (cfg.critOffsetY or 34) + 6
        entry.vx = 0
        entry.vy = 78
        entry.gravity = 38
    elseif opts.side == "left" then
        entry.offsetX = -12 + (math.random() * 10 - 5)
        entry.offsetY = baseOffsetY
        entry.vx = -32 * speedMult
        entry.vy = 80 * speedMult
        entry.gravity = 52
    elseif isDot then
        -- A. Periodic DoT / Bleed Ticks peel outward & downward off the side of the wound seam
        dotSideToggle = -dotSideToggle
        entry.offsetX = dotSideToggle * (10 + math.random() * 6)
        entry.offsetY = 10 + math.random() * 4
        entry.vx = dotSideToggle * (40 + math.random() * 14)
        entry.vy = 22 + math.random() * 10
        entry.gravity = 138
    elseif entry.useElementPhysics and elementKey == "LIGHTNING" then
        -- A1. LIGHTNING: High-velocity diagonal snap-bolt that locks in mid-air & jitters
        local dir = isCrit and (-critSideToggle) or laneDir
        if isCrit then
            critSideToggle = dir
        end
        entry.offsetX = dir * (8 + math.random() * 8)
        entry.offsetY = baseOffsetY - 2
        entry.vx = dir * (50 + math.random() * 20) * speedMult
        entry.vy = (142 + math.random() * 22) * speedMult
        entry.gravity = 10
    elseif entry.useElementPhysics and elementKey == "FIRE" then
        -- A2. FIRE: Buoyant rising flame (negative gravity accelerates upward) + S-curve curl
        entry.offsetX = lane.x * 0.45 + (math.random() * 6 - 3)
        entry.offsetY = baseOffsetY - 4
        entry.vx = laneDir * (12 + math.random() * 8)
        entry.vy = (46 + math.random() * 12) * speedMult
        entry.gravity = -48 * speedMult
        entry.waveAmp = (22 + math.random() * 10) * speedMult
        entry.waveFreq = 8.2 + math.random() * 1.5
        entry.wavePhase = laneCursor * 1.57
    elseif entry.useElementPhysics and elementKey == "EARTH" then
        -- A3. EARTH: Heavy seismic arc that slams onto an invisible rock ledge & bounces once!
        entry.offsetX = lane.x * 0.55
        entry.offsetY = baseOffsetY
        entry.vx = laneDir * (28 + math.random() * 12) * speedMult
        entry.vy = (102 + math.random() * 16) * speedMult
        entry.gravity = 315
        entry.bouncesLeft = 1
        entry.bounceFloorY = baseOffsetY - 3
    elseif entry.useElementPhysics and elementKey == "FROST" then
        -- A4. FROST: Crisp launch -> mid-air crystalline freeze-lock -> icicle shatter drop
        entry.offsetX = lane.x * 0.55
        entry.offsetY = baseOffsetY - 2
        entry.vx = laneDir * (24 + math.random() * 10) * speedMult
        entry.vy = (112 + math.random() * 14) * speedMult
        entry.gravity = 36
    elseif entry.useElementPhysics and elementKey == "SHADOW" then
        -- A5. SHADOW: Zero-gravity hovering void wave
        entry.offsetX = lane.x * 0.50
        entry.offsetY = baseOffsetY - 2
        entry.vx = laneDir * (14 + math.random() * 8)
        entry.vy = (52 + math.random() * 10) * speedMult
        entry.gravity = -8
        entry.waveAmp = 20 * speedMult
        entry.waveFreq = 5.4
        entry.wavePhase = laneCursor * 1.57
    elseif isCrit then
        critSideToggle = -critSideToggle
        entry.offsetX = critSideToggle * (7 + math.random() * 5)
        entry.offsetY = baseOffsetY + (math.random() * 4)
        entry.vx = critSideToggle * (14 + math.random() * 8) * speedMult
        entry.vy = (94 + math.random() * 14) * speedMult
        entry.gravity = 36
    elseif cfg.fountainLanes ~= false then
        entry.offsetX = lane.x + (math.random() * 4 - 2)
        entry.offsetY = baseOffsetY + lane.y
        entry.vx = (lane.vx + (math.random() * 8 - 4)) * speedMult
        entry.vy = (lane.vy + (math.random() * 8 - 4)) * speedMult
        entry.gravity = 52
    else
        local dir = (math.random() > 0.5) and 1 or -1
        entry.offsetX = (math.random() * 20 - 10)
        entry.offsetY = baseOffsetY
        entry.vx = dir * (26 + math.random() * 24) * speedMult
        entry.vy = (85 + math.random() * 16) * speedMult
        entry.gravity = 52
    end

    entry.isCrit = isCrit
    entry.isMega = isMega
    entry.isKill = isKill
    entry.isDot = isDot
    entry.isDeflect = isDeflect
    entry.isInterrupt = isInterrupt
    entry.hasShockwave = hasShockwave
    entry.flurryScale = flurryScale
    entry.hitWeight = hitWeight
    entry.age = 0
    if isKill then
        entry.duration = cfg.durationKill or 1.95
    elseif isDot then
        entry.duration = cfg.durationDot or 0.88
    elseif isCrit then
        entry.duration = cfg.durationCrit or 1.55
    else
        entry.duration = (cfg.durationNormal or 1.20) * (0.95 + 0.14 * hitWeight)
    end

    ApplyTextEntryAnchors(entry, 0, 0)
    entry.zoomFrame:SetScale((isKill or isCrit) and 0.55 or (entry.settleScale * 0.78))

    table.insert(activeTexts, entry)
    EnsureSCTTicker()
    return entry
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

    local amount, overkill, school, critical, spellName
    local isHeal = false
    local isAutoAttack = false
    local isPeriodic = false

    if subEvent == "SWING_DAMAGE" then
        amount, overkill, school, _, _, _, critical = arg12, arg13, arg14, arg15, arg16, arg17, arg18
        isAutoAttack = true
    elseif subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
        spellName = arg13
        school = arg14
        amount = arg15
        overkill = arg16
        critical = arg21
        isAutoAttack = (subEvent == "RANGE_DAMAGE")
        isPeriodic = (subEvent == "SPELL_PERIODIC_DAMAGE")
    elseif subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL" then
        amount = arg15
        critical = arg18
        isHeal = true
        isPeriodic = (subEvent == "SPELL_PERIODIC_HEAL")
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
        if ns.Elements and spellName then
            ns.Elements:RecordPlayerSpell(nil, spellName)
        end
        local elementKey = (ns.Elements and ns.Elements:ResolveElement(school, spellName, isAutoAttack)) or "PHYSICAL"
        local prof = ns.Elements and ns.Elements:GetProfile(elementKey)

        if ns.Nameplates then
            ns.Nameplates:OnCombatLogImpact(destGUID, amount, isCrit, isKill, elementKey, isPeriodic)
        end

        local anchorBar, enhancer = nil, nil
        local cfg = ns.Config:Get("combatText")
        if cfg and cfg.anchorToNameplate and ns.Nameplates then
            anchorBar, enhancer = ns.Nameplates:GetBarForGUID(destGUID)
        end

        -- Avoid duplicate numbers if UNIT_COMBAT already spawned for this nameplate hit
        if anchorBar or ((GetTime() - (self.lastUnitCombatTime or 0)) < 0.15) then
            return
        end

        local r, g, b = 1.0, 1.0, 1.0
        if prof and elementKey ~= "PHYSICAL" then
            local col = isCrit and prof.critText or prof.text
            r, g, b = col[1], col[2], col[3]
        elseif not isAutoAttack then
            local schoolKey = (school and not ns.IsSecret(school)) and school or 1
            local sc = SCHOOL_COLORS[schoolKey] or SCHOOL_COLORS[1]
            r, g, b = sc[1], sc[2], sc[3]
        elseif isCrit then
            r, g, b = 1.0, 0.82, 0.0
        end

        local baseWeight = isPeriodic and 0.12 or (isAutoAttack and 0.26 or 0.82)
        local numAmt = (not ns.IsSecret(amount) and type(amount) == "number") and amount or nil

        local entry = self:SpawnNumber({
            text = ns.IsSecret(amount) and amount or tostring(amount),
            numericAmount = numAmt,
            hitWeight = baseWeight,
            r = r, g = g, b = b,
            elementKey = elementKey,
            isCrit = isCrit,
            isMega = isCrit and isKill,
            isKill = isKill,
            isDot = isPeriodic,
            anchorFrame = (enhancer and enhancer.statusBar) or anchorBar,
            woundAnchor = enhancer and (enhancer.steadyWoundAnchor or enhancer.statusBar) or nil,
            side = "right",
        })
        if enhancer and entry then
            enhancer.lastTextEntry = entry
            enhancer.lastTextTime = GetTime()
        end
    elseif isIncoming and not ns.IsSecret(amount) then
        if isHeal then
            self:SpawnNumber({
                text = "+" .. tostring(amount),
                numericAmount = type(amount) == "number" and amount or nil,
                r = 0.15, g = 1.0, b = 0.15,
                isCrit = isCrit,
                isDot = isPeriodic,
                side = "left",
            })
        else
            self:SpawnNumber({
                text = "-" .. tostring(amount),
                numericAmount = type(amount) == "number" and amount or nil,
                r = 1.0, g = 0.15, b = 0.15,
                isCrit = isCrit,
                isDot = isPeriodic,
                side = "left",
            })
        end
    end
end

function CombatText:OnEnable()
    -- Note: In WoW Forever (16001), SetCVar is a protected Blizzard-only action.
    -- All enemy damage numbers are driven directly by Nameplates:OnUnitCombat (UNIT_COMBAT).
end
