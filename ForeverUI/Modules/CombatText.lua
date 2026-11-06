local addonName, ns = ...
local CombatText = {}
ns.CombatText = CombatText

local sctCanvas = CreateFrame("Frame", "ForeverUI_SCTCanvas", UIParent)
sctCanvas:SetAllPoints(UIParent)
sctCanvas:SetFrameStrata("HIGH")
sctCanvas:EnableMouse(false)

local textPool = {}
local activeTexts = {}

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

local function AcquireTextEntry()
    local entry = table.remove(textPool)
    if not entry then
        local holder = CreateFrame("Frame", nil, sctCanvas)
        holder:SetSize(200, 40)
        local fs = holder:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER", holder, "CENTER", 0, 0)
        fs:SetShadowOffset(1.5, -1.5)
        fs:SetShadowColor(0, 0, 0, 0.95)
        entry = { holder = holder, fs = fs }
    end
    entry.holder:Show()
    entry.holder:SetAlpha(1.0)
    entry.holder:SetScale(1.0)
    return entry
end

local function ReleaseTextEntry(entry)
    entry.holder:Hide()
    table.insert(textPool, entry)
end

local function GetFrameTopCenterInUIParent(frame)
    if not frame or not frame:GetCenter() then
        return nil, nil
    end
    local fScale = frame:GetEffectiveScale()
    local uScale = UIParent:GetEffectiveScale()
    local ratio = fScale / uScale
    local cx = frame:GetCenter() * ratio
    local top = (frame:GetTop() or 0) * ratio
    return cx, top
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
                ft.x = ft.x + ft.vx * dt
                ft.y = ft.y + ft.vy * dt
                ft.vy = ft.vy - ft.gravity * dt

                -- Elastic Crit Pop-In scale curve
                local scale = 1.0
                if ft.isCrit then
                    local peak = ft.isMega and 1.95 or 1.68
                    local settle = ft.isMega and 1.38 or 1.24
                    if ft.age < 0.08 then
                        scale = 0.55 + (ft.age / 0.08) * (peak - 0.55)
                    elseif ft.age < 0.22 then
                        scale = peak - ((ft.age - 0.08) / 0.14) * (peak - settle)
                    else
                        scale = settle
                    end
                end

                local alpha = 1.0
                if t > 0.70 then
                    alpha = math.max(0, 1.0 - (t - 0.70) / 0.30)
                end

                ft.holder:ClearAllPoints()
                ft.holder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ft.x, ft.y)
                ft.holder:SetScale(scale)
                ft.holder:SetAlpha(alpha)
            end
        end
        return #activeTexts > 0
    end)
end

-- Pure text-only combat number spawn (no icons)
function CombatText:SpawnNumber(opts)
    local cfg = ns.Config:Get("combatText")
    if not cfg or not cfg.enabled then
        return
    end

    local entry = AcquireTextEntry()
    local isCrit = not not opts.isCrit
    local isMega = not not opts.isMega

    local fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local fontSize = isMega and (cfg.megaFontSize or 27)
        or (isCrit and (cfg.critFontSize or 23) or (cfg.normalFontSize or 16))
    local fontFlags = isCrit and "THICKOUTLINE" or "OUTLINE"
    entry.fs:SetFont(fontPath, fontSize, fontFlags)
    entry.fs:SetText(tostring(opts.text or ""))
    entry.fs:SetTextColor(opts.r or 1.0, opts.g or 1.0, opts.b or 1.0, 1.0)

    local startX, startY
    if opts.anchorFrame and opts.anchorFrame:IsVisible() then
        startX, startY = GetFrameTopCenterInUIParent(opts.anchorFrame)
    end
    if not startX or not startY then
        local uiW = UIParent:GetWidth() or 1280
        local uiH = UIParent:GetHeight() or 720
        if opts.side == "left" then
            startX = uiW * 0.36
            startY = uiH * 0.54
        else
            startX = uiW * 0.62
            startY = uiH * 0.56
        end
    end

    local dir = (opts.side == "left") and -1 or (math.random() > 0.5 and 1 or -1)
    entry.x = startX + (math.random() * 22 - 11)
    entry.y = startY + 6 + (math.random() * 8 - 4)
    entry.vx = dir * (isCrit and (12 + math.random() * 20) or (26 + math.random() * 28))
    entry.vy = isCrit and (82 + math.random() * 18) or (88 + math.random() * 22)
    entry.gravity = isCrit and 48 or 120
    entry.isCrit = isCrit
    entry.isMega = isMega
    entry.age = 0
    entry.duration = isCrit and (cfg.durationCrit or 1.50) or (cfg.durationNormal or 1.15)

    entry.holder:ClearAllPoints()
    entry.holder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", entry.x, entry.y)
    table.insert(activeTexts, entry)
    EnsureSCTTicker()
end

function CombatText:OnCombatLogEvent()
    if not CombatLogGetCurrentEventInfo then
        return
    end
    local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21 = CombatLogGetCurrentEventInfo()
    local playerGUID = UnitGUID("player")
    if not playerGUID then
        return
    end

    local isOutgoing = (sourceGUID == playerGUID) and (destGUID ~= playerGUID)
    local isIncoming = (destGUID == playerGUID)
    if not isOutgoing and not isIncoming then
        return
    end

    local amount, overkill, school, critical
    local isHeal = false
    local isAutoAttack = false

    if subEvent == "SWING_DAMAGE" then
        amount, overkill, school, _, _, _, critical = arg12, arg13, arg14, arg15, arg16, arg17, arg18
        isAutoAttack = true
    elseif subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
        -- arg12=spellId, arg13=spellName, arg14=spellSchool, arg15=amount, arg16=overkill, ..., arg21=critical
        school = arg14
        amount = arg15
        overkill = arg16
        critical = arg21
        isAutoAttack = (subEvent == "RANGE_DAMAGE")
    elseif subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL" then
        -- arg15=amount, arg16=overhealing, arg17=absorbed, arg18=critical
        amount = arg15
        critical = arg18
        isHeal = true
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

    if not amount or amount <= 0 then
        return
    end

    local isKill = (overkill and overkill >= 0) or false

    if isOutgoing and not isHeal then
        -- Notify Nameplates & UnitBars so the overhead bar shakes violently on crits or shatters on death
        if ns.Nameplates then
            ns.Nameplates:OnCombatLogImpact(destGUID, amount, not not critical, isKill)
        end

        local anchorBar = nil
        local cfg = ns.Config:Get("combatText")
        if cfg and cfg.anchorToNameplate and ns.Nameplates then
            anchorBar = ns.Nameplates:GetBarForGUID(destGUID)
        end
        if not anchorBar and ns.UnitBars and ns.UnitBars.targetEnhancer then
            anchorBar = ns.UnitBars.targetEnhancer.statusBar
        end

        local r, g, b = 1.0, 1.0, 1.0
        if not isAutoAttack then
            local sc = SCHOOL_COLORS[school or 1] or SCHOOL_COLORS[1]
            r, g, b = sc[1], sc[2], sc[3]
        elseif critical then
            r, g, b = 1.0, 0.82, 0.0
        end

        self:SpawnNumber({
            text = tostring(amount),
            r = r, g = g, b = b,
            isCrit = critical,
            isMega = critical and isKill,
            anchorFrame = anchorBar,
            side = "right",
        })
    elseif isIncoming then
        local playerBar = ns.UnitBars and ns.UnitBars.playerEnhancer and ns.UnitBars.playerEnhancer.statusBar
        if isHeal then
            self:SpawnNumber({
                text = "+" .. tostring(amount),
                r = 0.15, g = 1.0, b = 0.15,
                isCrit = critical,
                anchorFrame = playerBar,
                side = "left",
            })
        else
            if ns.UnitBars and ns.UnitBars.playerEnhancer and critical then
                local maxHp = UnitHealthMax("player") or 1
                ns.UnitBars:TriggerDamageImpact(ns.UnitBars.playerEnhancer, amount / math.max(1, maxHp), true, false)
            end
            self:SpawnNumber({
                text = "-" .. tostring(amount),
                r = 1.0, g = 0.15, b = 0.15,
                isCrit = critical,
                anchorFrame = playerBar,
                side = "left",
            })
        end
    end
end

function CombatText:OnEnable()
    ns.Events:Register("COMBAT_LOG_EVENT_UNFILTERED", function()
        self:OnCombatLogEvent()
    end, self)
end
