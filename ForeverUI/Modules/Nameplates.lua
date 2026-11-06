local addonName, ns = ...
local Nameplates = {}
ns.Nameplates = Nameplates

Nameplates.byUnit = {}
Nameplates.byGUID = {}

local function FindHealthStatusBarRecursive(frame, depth)
    if not frame or depth > 5 then
        return nil, nil
    end

    local directCandidates = {
        frame.healthBar,
        frame.HealthBar,
        frame.healthbar,
        frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar,
        frame.HealthBarsContainer and frame.HealthBarsContainer.HealthBar,
    }
    for i = 1, #directCandidates do
        local c = directCandidates[i]
        if c and c.GetObjectType and c:GetObjectType() == "StatusBar" then
            return c, frame
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
        if child and child.GetObjectType then
            local objType = child:GetObjectType()
            if objType == "StatusBar" then
                local name = string.lower(child:GetName() or "")
                if not string.find(name, "cast", 1, true)
                    and not string.find(name, "mana", 1, true)
                    and not string.find(name, "power", 1, true)
                    and not string.find(name, "resource", 1, true)
                then
                    return child, frame
                end
            end
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
        local bar, owner = FindHealthStatusBarRecursive(namePlate.UnitFrame, 0)
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
        -- Keep native health bar 100% visible while alive; hide ONLY on death when replaced by DeathShatterBar!
        statusBar:SetAlpha(alpha)
    end
    if container and container.SetAlpha then
        container:SetAlpha(alpha)
    end
end

function Nameplates:GetBarForGUID(guid)
    if not guid then
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
    -- 1. Prefer current target's nameplate if visible
    if UnitExists("target") then
        local targetGUID = UnitGUID("target")
        local bar, enhancer = self:GetBarForGUID(targetGUID)
        if bar and enhancer then
            return bar, enhancer
        end
    end
    -- 2. Otherwise pick any visible enemy nameplate on screen
    self:ScanExistingNameplates()
    for unitToken, enhancer in pairs(self.byUnit) do
        if enhancer and enhancer.container and enhancer.statusBar and enhancer.statusBar:IsShown() then
            if not UnitIsUnit(unitToken, "player") then
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
    if UnitIsUnit(unitToken, "player") then
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
    enhancer.guid = UnitGUID(unitToken)

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
    if enhancer.unitFrame then
        SetNameplateExtrasAlpha(enhancer.unitFrame, enhancer.statusBar, enhancer.container, false)
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

    if not enhancer.guid and UnitGUID(unitToken) then
        enhancer.guid = UnitGUID(unitToken)
        self.byGUID[enhancer.guid] = enhancer
    end

    ns.UnitBars:SyncUnitState(enhancer, false)

    local curHp = UnitHealth(unitToken) or 0
    if (curHp <= 0 or UnitIsDead(unitToken)) and not enhancer.deathTriggered then
        self:TriggerDeathForEnhancer(enhancer)
    end
end

function Nameplates:OnUnitCombat(unitToken, action, flagText, amount)
    local enhancer = self.byUnit[unitToken]
    if not enhancer or action ~= "WOUND" or not amount or amount <= 0 then
        return
    end
    local now = GetTime()
    if (now - (enhancer.lastImpactTime or 0)) <= 0.05 then
        return
    end
    local isCrit = (flagText == "CRITICAL" or flagText == "CRUSHING")
    local maxHp = enhancer.maxHp or UnitHealthMax(unitToken) or 1
    local pctLost = amount / math.max(1, maxHp)
    local isMega = isCrit and (pctLost >= 0.25)

    ns.UnitBars:TriggerDamageImpact(enhancer, pctLost, isCrit, isMega)
    if ns.CombatText then
        ns.CombatText:SpawnNumber({
            text = tostring(amount),
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
    if not destGUID then
        return
    end
    local _, enhancer = self:GetBarForGUID(destGUID)
    if not enhancer then
        return
    end
    local maxHp = enhancer.maxHp or 1
    local pctLost = (amount or 0) / math.max(1, maxHp)
    local isMega = isCrit and (pctLost >= 0.25)
    ns.UnitBars:TriggerDamageImpact(enhancer, pctLost, isCrit, isMega)

    if ns.UnitBars.targetEnhancer and UnitGUID("target") == destGUID then
        ns.UnitBars:TriggerDamageImpact(ns.UnitBars.targetEnhancer, pctLost, isCrit, isMega)
    end

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
            -- Fallback: test nameplate1..nameplate40
            for idx = 1, 40 do
                local tok = "nameplate" .. idx
                if C_NamePlate.GetNamePlateForUnit(tok) == plate then
                    unitToken = tok
                    break
                end
            end
        end
        if unitToken and not UnitIsUnit(unitToken, "player") then
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

function Nameplates:EnsureEnemyNameplatesCVar()
    if InCombatLockdown() or not GetCVar or not SetCVar then
        return
    end
    local showEnemies = GetCVar("nameplateShowEnemies")
    if showEnemies == "0" then
        pcall(SetCVar, "nameplateShowEnemies", 1)
        if ns.Print then
            ns.Print("Enabled Enemy Nameplates (V) so overhead health bars are visible.")
        end
    end
end

function Nameplates:OnEnable()
    self:EnsureEnemyNameplatesCVar()

    ns.Events:Register("NAME_PLATE_UNIT_ADDED", function(_, _, unitToken)
        self:OnNamePlateAdded(unitToken)
    end, self)

    ns.Events:Register("NAME_PLATE_UNIT_REMOVED", function(_, _, unitToken)
        self:OnNamePlateRemoved(unitToken)
    end, self)

    local function OnHealthEvent(_, _, unitToken)
        if unitToken and string.find(unitToken, "^nameplate") then
            self:OnUnitHealth(unitToken)
        end
    end

    ns.Events:Register("UNIT_HEALTH", OnHealthEvent, self)
    ns.Events:Register("UNIT_HEALTH_FREQUENT", OnHealthEvent, self)

    ns.Events:Register("UNIT_COMBAT", function(_, _, unitToken, action, flagText, amount)
        if unitToken and string.find(unitToken, "^nameplate") then
            self:OnUnitCombat(unitToken, action, flagText, amount)
        end
    end, self)

    ns.Events:Register("PLAYER_TARGET_CHANGED", function()
        self:ScanExistingNameplates()
    end, self)

    ns.Events:Register("PLAYER_ENTERING_WORLD", function()
        self:EnsureEnemyNameplatesCVar()
        self:ScanExistingNameplates()
    end, self)

    self:ScanExistingNameplates()
end
