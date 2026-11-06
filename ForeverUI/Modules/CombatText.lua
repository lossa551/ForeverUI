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
        -- Outer holder stays at scale 1.0 so SetPoint offsets never get multiplied by SetScale!
        local holder = CreateFrame("Frame", nil, sctCanvas)
        holder:SetSize(1, 1)

        -- Inner zoomFrame sits at (0, 0) center of holder and handles elastic Crit Pop-In scaling
        local zoomFrame = CreateFrame("Frame", nil, holder)
        zoomFrame:SetSize(220, 44)
        zoomFrame:SetPoint("CENTER", holder, "CENTER", 0, 0)

        local fs = zoomFrame:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER", zoomFrame, "CENTER", 0, 0)
        fs:SetShadowOffset(1.5, -1.5)
        fs:SetShadowColor(0, 0, 0, 0.95)

        entry = {
            holder = holder,
            zoomFrame = zoomFrame,
            fs = fs,
        }
    end
    entry.holder:Show()
    entry.holder:SetAlpha(1.0)
    entry.zoomFrame:SetScale(1.0)
    return entry
end

local function ReleaseTextEntry(entry)
    entry.holder:Hide()
    entry.anchorFrame = nil
    table.insert(textPool, entry)
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
                ft.offsetX = ft.offsetX + ft.vx * dt
                ft.offsetY = ft.offsetY + ft.vy * dt
                ft.vy = ft.vy - ft.gravity * dt

                -- Elastic Crit Pop-In scale curve applied ONLY to inner zoomFrame (0,0 offset)
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
                if ft.anchorFrame then
                    ft.holder:SetPoint("CENTER", ft.anchorFrame, "TOP", ft.offsetX, ft.offsetY)
                else
                    ft.holder:SetPoint("CENTER", UIParent, "CENTER", ft.baseCenterX + ft.offsetX, ft.baseCenterY + ft.offsetY)
                end

                ft.zoomFrame:SetScale(scale)
                ft.holder:SetAlpha(alpha)
            end
        end
        return #activeTexts > 0
    end)
end

-- Pure text-only combat number spawn (no icons).
-- Supports WoW 12.0+ / 16001 Secret Number Values directly via FontString:SetText(secretVal).
function CombatText:SpawnNumber(opts)
    local cfg = ns.Config:Get("combatText")
    if not cfg or not cfg.enabled or not opts or opts.text == nil then
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

    if ns.IsSecret(opts.text) then
        entry.fs:SetText(opts.text)
    else
        entry.fs:SetText(tostring(opts.text))
    end
    entry.fs:SetTextColor(opts.r or 1.0, opts.g or 1.0, opts.b or 1.0, 1.0)

    entry.anchorFrame = opts.anchorFrame
    entry.baseCenterX = (opts.side == "left") and -140 or 185
    entry.baseCenterY = (opts.side == "left") and 20 or 55

    local dir = (opts.side == "left") and -1 or (math.random() > 0.5 and 1 or -1)
    entry.offsetX = (math.random() * 20 - 10)
    entry.offsetY = 8 + (math.random() * 6 - 3)
    entry.vx = dir * (isCrit and (12 + math.random() * 20) or (26 + math.random() * 28))
    entry.vy = isCrit and (78 + math.random() * 18) or (85 + math.random() * 20)
    entry.gravity = isCrit and 48 or 120
    entry.isCrit = isCrit
    entry.isMega = isMega
    entry.age = 0
    entry.duration = isCrit and (cfg.durationCrit or 1.50) or (cfg.durationNormal or 1.15)

    entry.holder:ClearAllPoints()
    if entry.anchorFrame then
        entry.holder:SetPoint("CENTER", entry.anchorFrame, "TOP", entry.offsetX, entry.offsetY)
    else
        entry.holder:SetPoint("CENTER", UIParent, "CENTER", entry.baseCenterX + entry.offsetX, entry.baseCenterY + entry.offsetY)
    end
    entry.zoomFrame:SetScale(isCrit and 0.55 or 1.0)

    table.insert(activeTexts, entry)
    EnsureSCTTicker()
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

    local amount, overkill, school, critical
    local isHeal = false
    local isAutoAttack = false

    if subEvent == "SWING_DAMAGE" then
        amount, overkill, school, _, _, _, critical = arg12, arg13, arg14, arg15, arg16, arg17, arg18
        isAutoAttack = true
    elseif subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
        school = arg14
        amount = arg15
        overkill = arg16
        critical = arg21
        isAutoAttack = (subEvent == "RANGE_DAMAGE")
    elseif subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL" then
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

    if not amount then
        return
    end
    if not ns.IsSecret(amount) and amount <= 0 then
        return
    end

    local isCrit = (not ns.IsSecret(critical)) and (not not critical) or false
    local isKill = (overkill and not ns.IsSecret(overkill) and overkill >= 0) or false

    if isOutgoing and not isHeal then
        if ns.Nameplates then
            ns.Nameplates:OnCombatLogImpact(destGUID, amount, isCrit, isKill)
        end

        local anchorBar = nil
        local cfg = ns.Config:Get("combatText")
        if cfg and cfg.anchorToNameplate and ns.Nameplates then
            anchorBar = ns.Nameplates:GetBarForGUID(destGUID)
        end

        local r, g, b = 1.0, 1.0, 1.0
        if not isAutoAttack then
            local schoolKey = (school and not ns.IsSecret(school)) and school or 1
            local sc = SCHOOL_COLORS[schoolKey] or SCHOOL_COLORS[1]
            r, g, b = sc[1], sc[2], sc[3]
        elseif isCrit then
            r, g, b = 1.0, 0.82, 0.0
        end

        self:SpawnNumber({
            text = ns.IsSecret(amount) and amount or tostring(amount),
            r = r, g = g, b = b,
            isCrit = isCrit,
            isMega = isCrit and isKill,
            anchorFrame = anchorBar,
            side = "right",
        })
    elseif isIncoming and not ns.IsSecret(amount) then
        if isHeal then
            self:SpawnNumber({
                text = "+" .. tostring(amount),
                r = 0.15, g = 1.0, b = 0.15,
                isCrit = isCrit,
                side = "left",
            })
        else
            self:SpawnNumber({
                text = "-" .. tostring(amount),
                r = 1.0, g = 0.15, b = 0.15,
                isCrit = isCrit,
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
