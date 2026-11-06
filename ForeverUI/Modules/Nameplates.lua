local addonName, ns = ...
local Nameplates = {}
ns.Nameplates = Nameplates

Nameplates.byUnit = {}
Nameplates.byGUID = {}

local function IsPlayerUnitSafe(unitToken)
    if not unitToken then
        return false
    end
    local isPlayer = UnitIsUnit(unitToken, "player")
    if ns.IsSecret(isPlayer) then
        return false
    end
    return isPlayer and true or false
end

local function IsUnitDeadSafe(unitToken)
    if not unitToken or not UnitExists(unitToken) then
        return false
    end
    local dead = UnitIsDead(unitToken)
    if ns.IsSecret(dead) then
        return false
    end
    return dead and true or false
end

local function GetUnitGUIDSafe(unitToken)
    if not unitToken or not UnitExists(unitToken) then
        return nil
    end
    local guid = UnitGUID(unitToken)
    if not guid or ns.IsSecret(guid) then
        return nil
    end
    return guid
end

local function IsHealthStatusBar(candidate, parentFrame)
    if not candidate or not candidate.GetObjectType then
        return false
    end
    if candidate:GetObjectType() ~= "StatusBar" then
        return false
    end
    if parentFrame then
        if candidate == parentFrame.castBar
            or candidate == parentFrame.CastBar
            or candidate == parentFrame.SpellCastBar
            or candidate == parentFrame.manaBar
            or candidate == parentFrame.powerBar
        then
            return false
        end
    end
    local name = string.lower(candidate:GetName() or "")
    if string.find(name, "cast", 1, true)
        or string.find(name, "mana", 1, true)
        or string.find(name, "power", 1, true)
        or string.find(name, "resource", 1, true)
    then
        return false
    end
    return true
end

local function FindHealthStatusBarRecursive(frame, depth)
    if not frame or depth > 5 then
        return nil, nil
    end

    if IsHealthStatusBar(frame.healthBar, frame) then
        return frame.healthBar, frame
    end
    if IsHealthStatusBar(frame.HealthBar, frame) then
        return frame.HealthBar, frame
    end
    if IsHealthStatusBar(frame.healthbar, frame) then
        return frame.healthbar, frame
    end
    if frame.HealthBarsContainer then
        local hbc = frame.HealthBarsContainer
        if IsHealthStatusBar(hbc.healthBar, frame) then
            return hbc.healthBar, frame
        end
        if IsHealthStatusBar(hbc.HealthBar, frame) then
            return hbc.HealthBar, frame
        end
        if IsHealthStatusBar(hbc.healthbar, frame) then
            return hbc.healthbar, frame
        end
    end

    local ok, children = pcall(function()
        return { frame:GetChildren() }
    end)
    if not ok or not children then
        return nil, nil
    end

    for i = 1, #children do
        local child = children[i]
        if child == frame.HealthBarsContainer then
            local bar, owner = FindHealthStatusBarRecursive(child, depth + 1)
            if bar then
                return bar, owner
            end
        end
    end

    for i = 1, #children do
        local child = children[i]
        if IsHealthStatusBar(child, frame) then
            return child, frame
        end
    end

    for i = 1, #children do
        local bar, ownerFrame = FindHealthStatusBarRecursive(children[i], depth + 1)
        if bar then
            return bar, ownerFrame
        end
    end

    return nil, nil
end

local function ResolveNameplateHealthBar(namePlate)
    if not namePlate then
        return nil, nil
    end
    if namePlate.UnitFrame then
        local bar = FindHealthStatusBarRecursive(namePlate.UnitFrame, 0)
        if bar then
            return bar, namePlate.UnitFrame
        end
    end
    return FindHealthStatusBarRecursive(namePlate, 0)
end

local function SetNameplateExtrasAlpha(uf, statusBar, container, isDead)
    local alpha = isDead and 0.0 or 1.0
    if uf then
        if uf.name and uf.name.SetAlpha then
            uf.name:SetAlpha(alpha)
        end
        if uf.Name and uf.Name.SetAlpha then
            uf.Name:SetAlpha(alpha)
        end
        if uf.LevelFrame and uf.LevelFrame.SetAlpha then
            uf.LevelFrame:SetAlpha(alpha)
        end
        if uf.ClassificationFrame and uf.ClassificationFrame.SetAlpha then
            uf.ClassificationFrame:SetAlpha(alpha)
        end
    end
    if statusBar and statusBar.SetAlpha then
        statusBar:SetAlpha(alpha)
    end
    if container and container.SetAlpha then
        container:SetAlpha(alpha)
    end
end

function Nameplates:GetBarForGUID(guid)
    if not guid or ns.IsSecret(guid) then
        return nil, nil
    end
    local enhancer = self.byGUID[guid]
    if enhancer and enhancer.container and enhancer.statusBar and enhancer.statusBar:IsShown() then
        return enhancer.container, enhancer
    end

    self:ScanExistingNameplates()
    enhancer = self.byGUID[guid]
    if enhancer and enhancer.container and enhancer.statusBar and enhancer.statusBar:IsShown() then
        return enhancer.container, enhancer
    end
    return nil, nil
end

function Nameplates:GetAnyActiveEnemyPlate()
    if UnitExists("target") then
        local targetGUID = GetUnitGUIDSafe("target")
        local bar, enhancer = self:GetBarForGUID(targetGUID)
        if bar and enhancer then
            return bar, enhancer
        end
    end
    self:ScanExistingNameplates()
    for unitToken, enhancer in pairs(self.byUnit) do
        if enhancer and enhancer.container and enhancer.statusBar and enhancer.statusBar:IsShown() then
            if not IsPlayerUnitSafe(unitToken) then
                return enhancer.container, enhancer
            end
        end
    end
    return nil, nil
end

function Nameplates:OnNamePlateAdded(unitToken)
    local cfg = ns.Config:Get("nameplates")
    if not cfg or not cfg.enabled or not unitToken then
        return
    end
    if IsPlayerUnitSafe(unitToken) then
        return
    end
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
        return
    end
    local namePlate = C_NamePlate.GetNamePlateForUnit(unitToken)
    local healthBar, unitFrame = ResolveNameplateHealthBar(namePlate)
    if not healthBar then
        return
    end

    local enhancer = ns.UnitBars:CreateBarEnhancer(healthBar, unitToken, true)
    enhancer.unitFrame = unitFrame
    enhancer.deathTriggered = false
    enhancer.initializedSecret = false
    enhancer.lastDamagedTime = 0
    enhancer.lastImpactTime = 0
    enhancer.guid = GetUnitGUIDSafe(unitToken)

    SetNameplateExtrasAlpha(unitFrame, healthBar, enhancer.container, false)

    self.byUnit[unitToken] = enhancer
    if enhancer.guid then
        self.byGUID[enhancer.guid] = enhancer
    end

    ns.UnitBars:SyncUnitState(enhancer, true)
end

function Nameplates:OnNamePlateRemoved(unitToken)
    local enhancer = self.byUnit[unitToken]
    if not enhancer then
        return
    end

    if not enhancer.deathTriggered then
        local now = GetTime()
        local recentHit = ((now - (enhancer.lastDamagedTime or 0)) <= 0.85)
            or ((now - (enhancer.lastImpactTime or 0)) <= 0.85)
        if IsUnitDeadSafe(unitToken) or recentHit then
            self:TriggerDeathForEnhancer(enhancer)
        end
    end

    if enhancer.guid and self.byGUID[enhancer.guid] == enhancer then
        self.byGUID[enhancer.guid] = nil
    end
    self.byUnit[unitToken] = nil
    enhancer.unit = nil
    enhancer.guid = nil
end

function Nameplates:TriggerDeathForEnhancer(enhancer)
    if not enhancer or enhancer.deathTriggered then
        return
    end
    enhancer.deathTriggered = true

    local barAnchor = enhancer.container or enhancer.statusBar
    if ns.CombatFX and barAnchor then
        ns.CombatFX:SpawnDeathShatterBar(barAnchor)
    end

    local npCfg = ns.Config:Get("nameplates")
    if npCfg and npCfg.hideNameAndLevelOnDeath then
        SetNameplateExtrasAlpha(enhancer.unitFrame, enhancer.statusBar, enhancer.container, true)
    end
end

function Nameplates:OnUnitHealth(unitToken)
    local enhancer = self.byUnit[unitToken]
    if not enhancer then
        self:OnNamePlateAdded(unitToken)
        enhancer = self.byUnit[unitToken]
        if not enhancer then
            return
        end
    end

    if not enhancer.guid then
        local guid = GetUnitGUIDSafe(unitToken)
        if guid then
            enhancer.guid = guid
            self.byGUID[guid] = enhancer
        end
    end

    ns.UnitBars:SyncUnitState(enhancer, false)

    if IsUnitDeadSafe(unitToken) then
        self:TriggerDeathForEnhancer(enhancer)
    end
end

function Nameplates:OnUnitCombat(unitToken, action, flagText, amount)
    local enhancer = self.byUnit[unitToken]
    if not enhancer then
        self:OnNamePlateAdded(unitToken)
        enhancer = self.byUnit[unitToken]
    end
    if not enhancer or ns.IsSecret(action) or action ~= "WOUND" or not amount then
        return
    end
    if not ns.IsSecret(amount) and amount <= 0 then
        return
    end

    local isCrit = false
    if not ns.IsSecret(flagText) then
        isCrit = (flagText == "CRITICAL" or flagText == "CRUSHING")
    end

    local pctLost = isCrit and 0.28 or 0.14
    if not ns.IsSecret(amount) and not ns.IsSecret(enhancer.maxHp) and (enhancer.maxHp or 0) > 0 then
        pctLost = amount / math.max(1, enhancer.maxHp)
    end
    local isMega = isCrit and (pctLost >= 0.25)

    ns.UnitBars:TriggerDamageImpact(enhancer, pctLost, isCrit, isMega)

    if ns.CombatText then
        local displayText = ns.IsSecret(amount) and amount or tostring(math.floor(amount + 0.5))
        ns.CombatText:SpawnNumber({
            text = displayText,
            r = 1.0,
            g = isCrit and 0.82 or 1.0,
            b = isCrit and 0.0 or 1.0,
            isCrit = isCrit,
            isMega = isMega,
            anchorFrame = enhancer.container or enhancer.statusBar,
            side = "right",
        })
    end
end

function Nameplates:OnCombatLogImpact(destGUID, amount, isCrit, isKill)
    if not destGUID or ns.IsSecret(destGUID) then
        return
    end
    local _, enhancer = self:GetBarForGUID(destGUID)
    if not enhancer then
        return
    end
    local pctLost = isCrit and 0.28 or 0.14
    if amount and not ns.IsSecret(amount) and not ns.IsSecret(enhancer.maxHp) and (enhancer.maxHp or 0) > 0 then
        pctLost = amount / math.max(1, enhancer.maxHp)
    end
    local isMega = isCrit and (pctLost >= 0.25)
    ns.UnitBars:TriggerDamageImpact(enhancer, pctLost, isCrit, isMega)

    if isKill then
        self:TriggerDeathForEnhancer(enhancer)
    end
end

function Nameplates:ScanExistingNameplates()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then
        return 0
    end
    local plates = C_NamePlate.GetNamePlates()
    if not plates then
        return 0
    end
    local count = 0
    for i = 1, #plates do
        local plate = plates[i]
        local unitToken = plate and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
        if not unitToken then
            for idx = 1, 40 do
                local tok = "nameplate" .. idx
                if C_NamePlate.GetNamePlateForUnit(tok) == plate then
                    unitToken = tok
                    break
                end
            end
        end
        if unitToken and not IsPlayerUnitSafe(unitToken) then
            if not self.byUnit[unitToken] then
                self:OnNamePlateAdded(unitToken)
            end
            if self.byUnit[unitToken] then
                count = count + 1
            end
        end
    end
    return count
end

function Nameplates:OnEnable()
    ns.Events:Register("NAME_PLATE_UNIT_ADDED", function(_, _, unitToken)
        self:OnNamePlateAdded(unitToken)
    end, self)

    ns.Events:Register("NAME_PLATE_UNIT_REMOVED", function(_, _, unitToken)
        self:OnNamePlateRemoved(unitToken)
    end, self)

    local function OnHealthEvent(_, _, unitToken)
        if unitToken and not ns.IsSecret(unitToken) and string.find(unitToken, "^nameplate") then
            self:OnUnitHealth(unitToken)
        end
    end

    ns.Events:Register("UNIT_HEALTH", OnHealthEvent, self)
    ns.Events:Register("UNIT_HEALTH_FREQUENT", OnHealthEvent, self)

    ns.Events:Register("UNIT_COMBAT", function(_, _, unitToken, action, flagText, amount)
        if unitToken and not ns.IsSecret(unitToken) and string.find(unitToken, "^nameplate") then
            self:OnUnitCombat(unitToken, action, flagText, amount)
        end
    end, self)

    ns.Events:Register("PLAYER_TARGET_CHANGED", function()
        self:ScanExistingNameplates()
    end, self)

    ns.Events:Register("PLAYER_ENTERING_WORLD", function()
        self:ScanExistingNameplates()
    end, self)

    self:ScanExistingNameplates()
end
