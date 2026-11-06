local addonName, ns = ...
local CombatFX = {}
ns.CombatFX = CombatFX

local fxCanvas = CreateFrame("Frame", "ForeverUI_FXCanvas", UIParent)
fxCanvas:SetAllPoints(UIParent)
fxCanvas:SetFrameStrata("HIGH")
fxCanvas:EnableMouse(false)

-- ============================================================================
-- 1. POOLED BAR SHATTER SPARKS & DEBRIS SHARDS
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
    sp.tex:SetRotation(0)
    table.insert(sparkPool, sp)
end

local function GetUIParentCoords(frame, xFraction, yFraction)
    if not frame or not frame:GetLeft() then
        return nil, nil, nil, nil
    end
    local fScale = frame:GetEffectiveScale()
    local uScale = UIParent:GetEffectiveScale()
    local ratio = fScale / uScale

    local left = frame:GetLeft() * ratio
    local bottom = frame:GetBottom() * ratio
    local width = frame:GetWidth() * ratio
    local height = frame:GetHeight() * ratio

    local x = left + width * (xFraction or 0.5)
    local y = bottom + height * (yFraction or 0.5)
    return x, y, width, height
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
                sp.x = sp.x + sp.vx * dt
                sp.y = sp.y + sp.vy * dt
                sp.vy = sp.vy - sp.gravity * dt
                local alpha = 1.0 - (sp.age / sp.duration)
                sp.tex:ClearAllPoints()
                sp.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sp.x, sp.y)
                sp.tex:SetAlpha(alpha)
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

function CombatFX:SpawnBarSparks(barFrame, cutFraction, count, r, g, b, isShards)
    local cfg = ns.Config:Get("combatFX")
    if not cfg or not cfg.enabled or not cfg.sparksEnabled then
        return
    end
    local baseX, baseY, barW, barH = GetUIParentCoords(barFrame, cutFraction, 0.5)
    if not baseX then
        return
    end

    count = count or 8
    r, g, b = r or 1.0, g or 0.78, b or 0.2

    for i = 1, count do
        local sp = AcquireSpark()
        local spawnX = baseX
        if isShards and barW then
            local leftX = GetUIParentCoords(barFrame, 0.0, 0.5)
            spawnX = (leftX or baseX) + math.random() * barW
        else
            spawnX = baseX + (math.random() * 6 - 3)
        end
        local spawnY = baseY + (math.random() * 4 - 2)

        local angle = -math.pi * 0.1 + math.random() * math.pi * 1.2
        local speed = 55 + math.random() * 135
        local size = isShards and (2.6 + math.random() * 3.0) or (2.0 + math.random() * 2.2)

        sp.x = spawnX
        sp.y = spawnY
        sp.vx = math.cos(angle) * speed * (math.random() > 0.5 and 1 or -1)
        sp.vy = math.abs(math.sin(angle)) * speed + 25
        sp.gravity = 280
        sp.age = 0
        sp.duration = isShards and (0.50 + math.random() * 0.32) or (0.30 + math.random() * 0.22)
        sp.rot = math.random() * 6.28
        sp.vRot = isShards and ((math.random() - 0.5) * 14) or 0

        if isShards then
            sp.tex:SetBlendMode("BLEND")
            sp.tex:SetSize(size * 1.4, size * 0.9)
        else
            sp.tex:SetBlendMode("ADD")
            sp.tex:SetSize(size, size)
        end

        if math.random() > 0.35 then
            sp.tex:SetVertexColor(r, g, b, 1)
        else
            sp.tex:SetVertexColor(0.95, 0.95, 0.98, 1)
        end

        sp.tex:ClearAllPoints()
        sp.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sp.x, sp.y)
        table.insert(activeSparks, sp)
    end

    EnsureSparkTicker()
end

-- ============================================================================
-- 2. BARE CRACKED & TILTED GRAY DEATH SHATTER BAR
-- ============================================================================
-- Normalized fracture crack segments (x in [0..1] along bar width, y in [-0.5..0.5] along bar height)
local CRACK_SEGMENTS = {
    -- Left fissure
    { x1 = 0.22, y1 =  0.50, x2 = 0.25, y2 =  0.10, w = 1.6 },
    { x1 = 0.25, y1 =  0.10, x2 = 0.22, y2 = -0.22, w = 1.6 },
    { x1 = 0.22, y1 = -0.22, x2 = 0.27, y2 = -0.50, w = 1.5 },
    -- Center major shatter fissure
    { x1 = 0.51, y1 =  0.50, x2 = 0.47, y2 =  0.15, w = 2.1 },
    { x1 = 0.47, y1 =  0.15, x2 = 0.54, y2 = -0.12, w = 2.1 },
    { x1 = 0.54, y1 = -0.12, x2 = 0.49, y2 = -0.50, w = 2.0 },
    -- Center branching web cracks
    { x1 = 0.47, y1 =  0.15, x2 = 0.38, y2 = -0.05, w = 1.2 },
    { x1 = 0.54, y1 = -0.12, x2 = 0.64, y2 =  0.12, w = 1.2 },
    -- Right fissure
    { x1 = 0.79, y1 = -0.50, x2 = 0.76, y2 = -0.05, w = 1.6 },
    { x1 = 0.76, y1 = -0.05, x2 = 0.81, y2 =  0.25, w = 1.6 },
    { x1 = 0.81, y1 =  0.25, x2 = 0.77, y2 =  0.50, w = 1.5 },
}

local deathBarPool = {}
local activeDeathBars = {}

local function AcquireDeathBar()
    local db = table.remove(deathBarPool)
    if not db then
        local holder = CreateFrame("Frame", nil, fxCanvas)
        holder:SetSize(120, 14)

        -- Dark iron outer border texture (rotatable)
        local borderTex = holder:CreateTexture(nil, "BACKGROUND")
        borderTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        borderTex:SetVertexColor(0.06, 0.06, 0.08, 0.96)

        -- Metallic zinc inner trim (rotatable)
        local trimTex = holder:CreateTexture(nil, "BORDER")
        trimTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        trimTex:SetVertexColor(0.34, 0.34, 0.38, 0.95)

        -- Stone-gray native WoW StatusBar texture (bare bar — no text, no level, no name!)
        local fillTex = holder:CreateTexture(nil, "ARTWORK")
        fillTex:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        fillTex:SetVertexColor(0.36, 0.36, 0.40, 1.0)

        -- White-hot killing blow impact flash
        local flashTex = holder:CreateTexture(nil, "OVERLAY")
        flashTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        flashTex:SetBlendMode("ADD")
        flashTex:SetVertexColor(1.0, 1.0, 1.0, 0.9)

        -- Create paired bevel + dark fissure lines for the fracture cracks
        local cracks = {}
        for i = 1, #CRACK_SEGMENTS do
            local spec = CRACK_SEGMENTS[i]
            local highlightLine = holder:CreateLine(nil, "OVERLAY", nil, 1)
            highlightLine:SetTexture("Interface\\Buttons\\WHITE8X8")
            highlightLine:SetVertexColor(0.86, 0.86, 0.90, 0.82)
            highlightLine:SetThickness(spec.w + 0.8)

            local darkLine = holder:CreateLine(nil, "OVERLAY", nil, 2)
            darkLine:SetTexture("Interface\\Buttons\\WHITE8X8")
            darkLine:SetVertexColor(0.02, 0.02, 0.03, 0.98)
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
    table.insert(deathBarPool, db)
end

local function UpdateDeathBarGeometry(db, thetaRad)
    local w = db.width
    local h = db.height
    local cosT = math.cos(thetaRad)
    local sinT = math.sin(thetaRad)

    -- Center of the bar rotated around the left hinge (db.hingeX, db.hingeY - db.dropY)
    local hx = db.hingeX + db.shakeDx
    local hy = db.hingeY - db.dropY + db.shakeDy
    local cx = hx + (w * 0.5) * cosT
    local cy = hy + (w * 0.5) * sinT

    db.holder:ClearAllPoints()
    db.holder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
    db.holder:SetSize(w, h)

    local punchedH = h * db.barPunchY
    db.borderTex:ClearAllPoints()
    db.borderTex:SetPoint("CENTER", db.holder, "CENTER", 0, 0)
    db.borderTex:SetSize(w + 4, punchedH + 4)

    db.trimTex:ClearAllPoints()
    db.trimTex:SetPoint("CENTER", db.holder, "CENTER", 0, 0)
    db.trimTex:SetSize(w + 2, punchedH + 2)

    db.fillTex:ClearAllPoints()
    db.fillTex:SetPoint("CENTER", db.holder, "CENTER", 0, 0)
    db.fillTex:SetSize(w, punchedH)

    db.flashTex:ClearAllPoints()
    db.flashTex:SetPoint("CENTER", db.holder, "CENTER", 0, 0)
    db.flashTex:SetSize(w, punchedH)
    db.flashTex:SetAlpha(db.flashAlpha)

    if db.fillTex.SetRotation then
        db.borderTex:SetRotation(thetaRad)
        db.trimTex:SetRotation(thetaRad)
        db.fillTex:SetRotation(thetaRad)
        db.flashTex:SetRotation(thetaRad)
    end

    -- Rotate every fracture crack segment in locked sync with the tilted bar
    for i = 1, #db.cracks do
        local c = db.cracks[i]
        local s = c.spec
        local lx1 = (s.x1 - 0.5) * w
        local ly1 = s.y1 * punchedH
        local lx2 = (s.x2 - 0.5) * w
        local ly2 = s.y2 * punchedH

        local rx1 = lx1 * cosT - ly1 * sinT
        local ry1 = lx1 * sinT + ly1 * cosT
        local rx2 = lx2 * cosT - ly2 * sinT
        local ry2 = lx2 * sinT + ly2 * cosT

        c.highlight:SetStartPoint("CENTER", db.holder, rx1 + 0.7, ry1)
        c.highlight:SetEndPoint("CENTER", db.holder, rx2 + 0.7, ry2)

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
                -- Decay impact flash and vertical punch
                if db.flashAlpha > 0 then
                    db.flashAlpha = math.max(0, db.flashAlpha - dt * 4.0)
                end
                db.barPunchY = db.barPunchY + (1.0 - db.barPunchY) * math.min(1.0, dt * 12.0)

                -- Damped trauma recoil on the killing blow
                if db.trauma > 0.01 then
                    local p = db.trauma * db.trauma
                    db.shakeDx = math.sin(now * 85.0) * 9.0 * p
                    db.shakeDy = math.cos(now * 95.0) * 6.0 * p
                    db.trauma = math.max(0, db.trauma - dt * 2.5)
                else
                    db.trauma = 0
                    db.shakeDx = 0
                    db.shakeDy = 0
                end

                -- Left-hinge downward tilt spring physics
                local spring = (db.targetTiltDeg - db.tiltDeg) * 38.0
                db.tiltVel = (db.tiltVel + spring * dt) * math.max(0, 1.0 - dt * 10.5)
                db.tiltDeg = db.tiltDeg + db.tiltVel * dt

                -- Slight gravity drop after 0.22s
                if db.age > 0.22 then
                    db.dropY = db.dropY + (db.age - 0.22) * 38.0 * dt
                end

                -- Fade out after holding the bare cracked gray tilted bar
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

function CombatFX:SpawnDeathShatterBar(barFrame)
    local npCfg = ns.Config:Get("nameplates")
    if not npCfg or not npCfg.deathShatterEnabled then
        return
    end
    local leftX, midY, width, height = GetUIParentCoords(barFrame, 0.0, 0.5)
    if not leftX or not width or width <= 4 then
        return
    end

    local db = AcquireDeathBar()
    db.hingeX = leftX
    db.hingeY = midY
    db.width = width
    db.height = math.max(height or 12, 10)
    db.age = 0
    db.holdTime = npCfg.deathHoldTime or 0.85
    db.fadeTime = npCfg.deathFadeTime or 0.45
    db.tiltDeg = 0
    db.targetTiltDeg = npCfg.deathTiltDegrees or -11.5
    db.tiltVel = -48.0
    db.dropY = 0
    db.trauma = 1.0
    db.shakeDx = 0
    db.shakeDy = 0
    db.barPunchY = 1.65
    db.flashAlpha = 1.0

    UpdateDeathBarGeometry(db, 0)
    table.insert(activeDeathBars, db)

    -- Burst stone/metal shards across the cracked bar
    self:SpawnBarSparks(barFrame, 0.5, 20, 0.65, 0.65, 0.70, true)
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
    local maxHp = UnitHealthMax("player") or 1
    local curHp = UnitHealth("player") or 1
    local pct = maxHp > 0 and (curHp / maxHp) or 1.0

    if not UnitIsDeadOrGhost("player") and pct <= (cfg.lowHpThreshold or 0.30) then
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
