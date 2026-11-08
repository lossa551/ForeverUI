local addonName, ns = ...
ns.Castbars = {}
local Castbars = ns.Castbars

local DEFAULT_WIDTH = 220
local DEFAULT_HEIGHT = 18
local ICON_SIZE = 20

local castbars = {}
local activeCastbarCount = 0

-- Resolve elemental school profile from spell name
local function ResolveSpellSchool(spellName)
    if not spellName or ns.IsSecret(spellName) or type(spellName) ~= "string" then
        return "PHYSICAL", { 1.00, 0.78, 0.20 }, { 1.00, 0.95, 0.75 }
    end
    local lower = string.lower(spellName)

    -- Nature / Lightning (Shaman Lightning Bolt, Chain Lightning, Lightning Shield, Purge)
    if string.find(lower, "lightning", 1, true) or string.find(lower, "nature", 1, true)
       or string.find(lower, "purge", 1, true) or string.find(lower, "chain", 1, true) and not string.find(lower, "heal", 1, true) then
        return "LIGHTNING", { 0.38, 0.88, 1.00 }, { 0.75, 0.96, 1.00 }
    end

    -- Frost / Water (Shaman Healing Wave, Lesser Healing Wave, Chain Heal, Frost Shock)
    if string.find(lower, "heal", 1, true) or string.find(lower, "frost", 1, true)
       or string.find(lower, "wave", 1, true) or string.find(lower, "water", 1, true)
       or string.find(lower, "riptide", 1, true) or string.find(lower, "spring", 1, true) then
        return "FROST", { 0.35, 0.85, 0.95 }, { 0.78, 0.96, 1.00 }
    end

    -- Fire (Shaman Flame Shock, Fire Nova, Lava Burst, Magma Totem)
    if string.find(lower, "flame", 1, true) or string.find(lower, "fire", 1, true)
       or string.find(lower, "lava", 1, true) or string.find(lower, "magma", 1, true)
       or string.find(lower, "scorch", 1, true) or string.find(lower, "immolate", 1, true) then
        return "FIRE", { 1.00, 0.58, 0.12 }, { 1.00, 0.92, 0.65 }
    end

    -- Earth (Shaman Earth Shock, Stoneskin, Tremor)
    if string.find(lower, "earth", 1, true) or string.find(lower, "stone", 1, true)
       or string.find(lower, "rock", 1, true) or string.find(lower, "boulder", 1, true) then
        return "EARTH", { 0.92, 0.65, 0.22 }, { 1.00, 0.88, 0.55 }
    end

    -- Shadow
    if string.find(lower, "shadow", 1, true) or string.find(lower, "curse", 1, true)
       or string.find(lower, "dark", 1, true) or string.find(lower, "void", 1, true) then
        return "SHADOW", { 0.75, 0.40, 1.00 }, { 0.92, 0.75, 1.00 }
    end

    return "PHYSICAL", { 1.00, 0.78, 0.20 }, { 1.00, 0.95, 0.75 }
end

local function CreateBorder(parent, w, h)
    local border = CreateFrame("Frame", nil, parent)
    border:SetAllPoints(parent)
    border:EnableMouse(false)

    local function MakeLine(point1, rel1, ox1, oy1, point2, rel2, ox2, oy2, r, g, b, a)
        local line = border:CreateTexture(nil, "OVERLAY")
        line:SetTexture("Interface\\Buttons\\WHITE8X8")
        line:SetVertexColor(r, g, b, a)
        line:SetPoint(point1, parent, rel1, ox1, oy1)
        line:SetPoint(point2, parent, rel2, ox2, oy2)
        return line
    end

    -- Outer weathered stone-bronze frame
    MakeLine("TOPLEFT", "TOPLEFT", -2, 2, "TOPRIGHT", "TOPRIGHT", 2, 2, 0.12, 0.11, 0.10, 0.95)
    MakeLine("BOTTOMLEFT", "BOTTOMLEFT", -2, -2, "BOTTOMRIGHT", "BOTTOMRIGHT", 2, -2, 0.12, 0.11, 0.10, 0.95)
    MakeLine("TOPLEFT", "TOPLEFT", -2, 2, "BOTTOMLEFT", "BOTTOMLEFT", -2, -2, 0.12, 0.11, 0.10, 0.95)
    MakeLine("TOPRIGHT", "TOPRIGHT", 2, 2, "BOTTOMRIGHT", "BOTTOMRIGHT", 2, -2, 0.12, 0.11, 0.10, 0.95)

    -- Inner brass bevel highlights
    MakeLine("TOPLEFT", "TOPLEFT", -1, 1, "TOPRIGHT", "TOPRIGHT", 1, 1, 0.42, 0.38, 0.30, 0.85)
    MakeLine("BOTTOMLEFT", "BOTTOMLEFT", -1, -1, "BOTTOMRIGHT", "BOTTOMRIGHT", 1, -1, 0.22, 0.20, 0.16, 0.85)
    MakeLine("TOPLEFT", "TOPLEFT", -1, 1, "BOTTOMLEFT", "BOTTOMLEFT", -1, -1, 0.36, 0.32, 0.25, 0.85)
    MakeLine("TOPRIGHT", "TOPRIGHT", 1, 1, "BOTTOMRIGHT", "BOTTOMRIGHT", 1, -1, 0.24, 0.22, 0.18, 0.85)

    return border
end

function Castbars:CreateCastbar(unit, name, customWidth, customHeight)
    local w = customWidth or DEFAULT_WIDTH
    local h = customHeight or DEFAULT_HEIGHT

    local container = CreateFrame("Frame", name, UIParent)
    container:SetSize(w, h)
    container:EnableMouse(false)
    container.fuiWidth = w
    container.fuiHeight = h
    container.unit = unit

    -- Dark slate background
    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(container)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.05, 0.05, 0.06, 0.94)

    -- Status bar fill
    local bar = CreateFrame("StatusBar", nil, container)
    bar:SetAllPoints(container)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1.00, 0.78, 0.20, 1.0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.fuiWidth = w
    bar.fuiHeight = h

    -- Top/bottom inner shade on the bar fill for classic sculpted look
    local topShade = bar:CreateTexture(nil, "BORDER", nil, 1)
    topShade:SetTexture("Interface\\Buttons\\WHITE8X8")
    topShade:SetVertexColor(1.0, 1.0, 1.0, 0.16)
    topShade:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    topShade:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    topShade:SetHeight(2)

    local botShade = bar:CreateTexture(nil, "BORDER", nil, 1)
    botShade:SetTexture("Interface\\Buttons\\WHITE8X8")
    botShade:SetVertexColor(0.0, 0.0, 0.0, 0.40)
    botShade:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    botShade:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    botShade:SetHeight(2)

    -- Latency Safe-Zone Slivers (positioned at the tail end of the bar)
    local latencySliver = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    latencySliver:SetTexture("Interface\\Buttons\\WHITE8X8")
    latencySliver:SetVertexColor(0.95, 0.25, 0.15, 0.55)
    latencySliver:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    latencySliver:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    latencySliver:SetWidth(1)
    latencySliver:Hide()

    -- Shaman Pushback Recoil Flash Bar (shows delayed portion on pushback)
    local recoilSliver = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    recoilSliver:SetTexture("Interface\\Buttons\\WHITE8X8")
    recoilSliver:SetVertexColor(1.00, 0.22, 0.10, 0.75)
    recoilSliver:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    recoilSliver:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    recoilSliver:SetWidth(1)
    recoilSliver:Hide()

    -- Lead Spark (rides the head of the fill bar)
    local spark = bar:CreateTexture(nil, "OVERLAY", nil, 4)
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(20, h * 2.1)
    spark:SetVertexColor(1.00, 0.90, 0.65, 0.95)
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    spark:Hide()

    -- Spell Icon Frame
    local iconFrame = CreateFrame("Frame", nil, container)
    iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
    iconFrame:SetPoint("RIGHT", container, "LEFT", -5, 0)

    local iconBg = iconFrame:CreateTexture(nil, "BACKGROUND")
    iconBg:SetAllPoints(iconFrame)
    iconBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    iconBg:SetVertexColor(0.05, 0.05, 0.06, 1.0)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    CreateBorder(iconFrame, ICON_SIZE, ICON_SIZE)
    CreateBorder(container, w, h)

    -- Full-bar completion flash overlay
    local flashOverlay = bar:CreateTexture(nil, "OVERLAY", nil, 5)
    flashOverlay:SetAllPoints(bar)
    flashOverlay:SetTexture("Interface\\Buttons\\WHITE8X8")
    flashOverlay:SetBlendMode("ADD")
    flashOverlay:SetVertexColor(1.0, 1.0, 1.0, 0.0)

    -- Typography: Spell Name & Time Remaining
    local nameText = bar:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    nameText:SetPoint("LEFT", bar, "LEFT", 6, 0)
    nameText:SetPoint("RIGHT", bar, "RIGHT", -55, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetTextColor(1.0, 0.96, 0.88, 1.0)

    local timeText = bar:CreateFontString(nil, "OVERLAY")
    timeText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    timeText:SetJustifyH("RIGHT")
    timeText:SetTextColor(1.0, 0.86, 0.40, 1.0)

    local castbar = {
        container = container,
        bar = bar,
        icon = icon,
        iconFrame = iconFrame,
        spark = spark,
        latencySliver = latencySliver,
        recoilSliver = recoilSliver,
        flashOverlay = flashOverlay,
        nameText = nameText,
        timeText = timeText,
        unit = unit,
        baseWidth = w,
        baseHeight = h,
        casting = false,
        startTime = 0,
        endTime = 0,
        duration = 0,
        currentSpell = nil,
        trauma = 0,
        traumaTime = 0,
        recoilTimer = 0,
        flashTimer = 0,
        isDemo = false,
    }

    container:Hide()
    castbars[unit] = castbar
    return castbar
end

local function EnsureTicker()
    if activeCastbarCount > 0 then
        ns.Events:RegisterTicker("ForeverUI_Castbars", function(dt, now)
            return Castbars:OnUpdate(dt, now)
        end)
    else
        ns.Events:UnregisterTicker("ForeverUI_Castbars")
    end
end

function Castbars:StartCast(unit, spellName, texture, startTimeMS, endTimeMS, isDemo)
    local cb = castbars[unit]
    if not cb then
        return
    end

    local cfg = ns.Config:Get("castbars")
    if cfg and cfg.enabled == false then
        return
    end

    local startSec = (startTimeMS or 0) / 1000
    local endSec = (endTimeMS or 0) / 1000
    if endSec <= startSec then
        endSec = startSec + 1.0
    end
    local dur = endSec - startSec

    cb.casting = true
    cb.startTime = startSec
    cb.endTime = endSec
    cb.duration = dur
    cb.currentSpell = spellName
    cb.isDemo = isDemo or false
    cb.trauma = 0
    cb.recoilTimer = 0
    cb.flashTimer = 0

    local elemKey, barColor, sparkColor = ResolveSpellSchool(spellName)
    cb.bar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], 1.0)
    cb.spark:SetVertexColor(sparkColor[1], sparkColor[2], sparkColor[3], 0.95)

    if cb.icon and texture then
        cb.icon:SetTexture(texture)
        cb.iconFrame:Show()
    else
        cb.iconFrame:Hide()
    end

    if ns.IsSecret(spellName) then
        cb.nameText:SetText(spellName)
    else
        cb.nameText:SetText(tostring(spellName or "Casting"))
    end

    cb.bar:SetMinMaxValues(0, dur)
    cb.bar:SetValue(0)
    cb.spark:Show()
    cb.recoilSliver:Hide()
    cb.flashOverlay:SetAlpha(0)

    -- Dynamic Latency Safe-Zone Slivers (lag compensation / spell queuing)
    if cfg and cfg.showLatency ~= false and not cb.isDemo then
        local pingMS = select(4, GetNetStats()) or 0
        local pingSec = pingMS / 1000
        if pingSec > 0 and dur > 0 then
            local latFrac = math.min(0.40, pingSec / dur)
            local latW = math.max(2, math.floor(cb.baseWidth * latFrac))
            cb.latencySliver:SetWidth(latW)
            cb.latencySliver:Show()
        else
            cb.latencySliver:Hide()
        end
    else
        cb.latencySliver:Hide()
    end

    cb.container:ClearAllPoints()
    cb.container:SetPoint(cb.point or "CENTER", cb.relFrame or UIParent, cb.relPoint or "CENTER", cb.offsetX or 0, cb.offsetY or -180)
    cb.container:Show()
    cb.container:SetAlpha(1.0)

    activeCastbarCount = activeCastbarCount + 1
    EnsureTicker()
end

-- Shaman Pushback Recoil Engine: fires when taking damage while casting Healing Wave or Lightning Bolt
function Castbars:ApplyPushback(unit, newEndTimeMS)
    local cb = castbars[unit]
    if not cb or not cb.casting then
        return
    end

    local cfg = ns.Config:Get("castbars")
    if cfg and cfg.pushbackRecoil == false then
        return
    end

    local prevEnd = cb.endTime
    local newEnd = (newEndTimeMS or 0) / 1000
    if newEnd <= prevEnd then
        return
    end

    local delayedDelta = newEnd - prevEnd
    cb.endTime = newEnd
    cb.duration = cb.duration + delayedDelta
    cb.bar:SetMinMaxValues(0, cb.duration)

    -- Physical trauma shake and electric recoil flash
    cb.trauma = math.min(1.00, (cb.trauma or 0) + 0.70)
    cb.recoilTimer = 0.45

    local delayFrac = math.min(0.50, delayedDelta / math.max(0.1, cb.duration))
    local recoilW = math.max(4, math.floor(cb.baseWidth * delayFrac))
    cb.recoilSliver:SetWidth(recoilW)
    cb.recoilSliver:Show()

    -- Trigger electric cyan/amber hit sparks at the bar head if CombatFX is loaded
    if ns.CombatFX and cb.spark and cb.spark:IsShown() then
        ns.CombatFX:SpawnBarSparks(cb.spark, nil, 6, 1.0, 0.45, 0.15, false, "LIGHTNING", 0.65)
    end
end

function Castbars:StopCast(unit, interrupted)
    local cb = castbars[unit]
    if not cb or not cb.casting then
        return
    end

    cb.casting = false
    cb.spark:Hide()
    cb.recoilSliver:Hide()
    cb.latencySliver:Hide()

    if interrupted then
        cb.timeText:SetText("|cffff2222INTERRUPTED|r")
        cb.bar:SetStatusBarColor(0.85, 0.12, 0.12, 1.0)
        cb.trauma = 0.85
        cb.flashTimer = 0.35
    else
        cb.flashOverlay:SetAlpha(0.65)
        cb.flashTimer = 0.16
    end
end

function Castbars:OnUpdate(dt, now)
    local anyActive = false

    for unit, cb in pairs(castbars) do
        local needsRender = false

        if cb.casting then
            anyActive = true
            local curTime = now
            if curTime >= cb.endTime then
                self:StopCast(unit, false)
            else
                local progress = curTime - cb.startTime
                local rem = math.max(0, cb.endTime - curTime)
                cb.bar:SetValue(progress)

                local secStr = string.format("%.1fs", rem)
                cb.timeText:SetText(secStr)
                needsRender = true
            end
        end

        -- Recoil timer countdown
        if cb.recoilTimer and cb.recoilTimer > 0 then
            cb.recoilTimer = cb.recoilTimer - dt
            if cb.recoilTimer <= 0 then
                cb.recoilSliver:Hide()
            else
                local alpha = math.min(0.75, cb.recoilTimer / 0.45 * 0.75)
                cb.recoilSliver:SetAlpha(alpha)
                anyActive = true
            end
        end

        -- Flash overlay fadeout
        if cb.flashTimer and cb.flashTimer > 0 then
            cb.flashTimer = cb.flashTimer - dt
            anyActive = true
            if cb.flashTimer <= 0 then
                cb.flashOverlay:SetAlpha(0)
                if not cb.casting then
                    cb.container:Hide()
                end
            else
                local alpha = math.min(0.65, cb.flashTimer / 0.16 * 0.65)
                cb.flashOverlay:SetAlpha(alpha)
            end
        end

        -- Kinetic Trauma Shake Physics (recoil jolt from taking hits while casting)
        if cb.trauma and cb.trauma > 0.01 then
            anyActive = true
            cb.traumaTime = (cb.traumaTime or 0) + dt * 28
            local p = math.pow(cb.trauma, 1.35)
            local dx = math.sin(cb.traumaTime * 1.6) * 5.5 * p
            local dy = math.cos(cb.traumaTime * 2.1) * 3.2 * p
            cb.trauma = math.max(0, cb.trauma - dt * 3.8)

            cb.container:ClearAllPoints()
            cb.container:SetPoint(cb.point or "CENTER", cb.relFrame or UIParent, cb.relPoint or "CENTER", (cb.offsetX or 0) + dx, (cb.offsetY or -180) + dy)
        elseif cb.trauma and cb.trauma > 0 then
            cb.trauma = 0
            cb.container:ClearAllPoints()
            cb.container:SetPoint(cb.point or "CENTER", cb.relFrame or UIParent, cb.relPoint or "CENTER", cb.offsetX or 0, cb.offsetY or -180)
        end
    end

    if not anyActive then
        activeCastbarCount = 0
        return false
    end
    return true
end

-- Event Multiplexing
function Castbars:OnSpellcastStart(unit)
    if not castbars[unit] then
        return
    end
    local name, text, texture, startTimeMS, endTimeMS = UnitCastingInfo(unit)
    if not name then
        return
    end
    self:StartCast(unit, name, texture, startTimeMS, endTimeMS, false)
end

function Castbars:OnSpellcastDelayed(unit)
    if not castbars[unit] then
        return
    end
    local name, text, texture, startTimeMS, endTimeMS = UnitCastingInfo(unit)
    if endTimeMS then
        self:ApplyPushback(unit, endTimeMS)
    end
end

function Castbars:OnSpellcastStop(unit)
    if not castbars[unit] then
        return
    end
    self:StopCast(unit, false)
end

function Castbars:OnSpellcastInterrupted(unit)
    if not castbars[unit] then
        return
    end
    self:StopCast(unit, true)
end

function Castbars:RunDemoCast(spellName, durationSec, pushbackDelayAt, pushbackDeltaSec)
    local cb = castbars["player"]
    if not cb then
        return
    end

    local now = GetTime()
    local name = spellName or "Lightning Bolt"
    local dur = durationSec or 2.5
    local tex = "Interface\\Icons\\Spell_Nature_Lightning"
    if string.find(string.lower(name), "heal", 1, true) then
        tex = "Interface\\Icons\\Spell_Nature_MagicImmunity"
    elseif string.find(string.lower(name), "flame", 1, true) then
        tex = "Interface\\Icons\\Spell_Fire_FlameShock"
    end

    self:StartCast("player", name, tex, now * 1000, (now + dur) * 1000, true)

    if pushbackDelayAt and pushbackDeltaSec then
        C_Timer.After(pushbackDelayAt, function()
            if cb.casting and cb.isDemo then
                local newEndMS = (cb.endTime + pushbackDeltaSec) * 1000
                self:ApplyPushback("player", newEndMS)
                ns.Print("|cffff4422Pushback Recoil!|r (Took damage during " .. name .. ": +" .. string.format("%.1fs", pushbackDeltaSec) .. ")")
            end
        end)
    end
end

function Castbars:OnEnable()
    local cfg = ns.Config:Get("castbars")
    if cfg and cfg.enabled == false then
        return
    end

    -- Create Player Castbar
    local pBar = self:CreateCastbar("player", "ForeverUI_PlayerCastBar", cfg and cfg.width or DEFAULT_WIDTH, cfg and cfg.height or DEFAULT_HEIGHT)
    pBar.point = "CENTER"
    pBar.relPoint = "CENTER"
    pBar.offsetX = 0
    pBar.offsetY = -180

    -- Suppress vanilla CastingBarFrame if present
    if _G.CastingBarFrame then
        pcall(function()
            _G.CastingBarFrame:UnregisterAllEvents()
            _G.CastingBarFrame:Hide()
        end)
    end

    -- Register Blizzard Spellcast Events
    ns.Events:Register("UNIT_SPELLCAST_START", function(_, _, unit)
        Castbars:OnSpellcastStart(unit)
    end, Castbars)

    ns.Events:Register("UNIT_SPELLCAST_DELAYED", function(_, _, unit)
        Castbars:OnSpellcastDelayed(unit)
    end, Castbars)

    ns.Events:Register("UNIT_SPELLCAST_STOP", function(_, _, unit)
        Castbars:OnSpellcastStop(unit)
    end, Castbars)

    ns.Events:Register("UNIT_SPELLCAST_FAILED", function(_, _, unit)
        Castbars:OnSpellcastStop(unit)
    end, Castbars)

    ns.Events:Register("UNIT_SPELLCAST_INTERRUPTED", function(_, _, unit)
        Castbars:OnSpellcastInterrupted(unit)
    end, Castbars)
end
