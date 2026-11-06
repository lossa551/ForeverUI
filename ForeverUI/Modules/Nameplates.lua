local addonName, ns = ...
local Nameplates = {}
ns.Nameplates = Nameplates

Nameplates.byUnit = {}
Nameplates.byGUID = {}

local function ResolveNameplateHealthBar(namePlate)
    if not namePlate then
        return nil, nil
    end
    local uf = namePlate.UnitFrame
    if uf then
        if uf.healthBar then
            return uf.healthBar, uf
        end
        if uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar then
            return uf.HealthBarsContainer.healthBar, uf
        end
    end
    local children = { namePlate:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
            return child, namePlate
        end
        if child and child.healthBar then
            return child.healthBar, child
        end
    end
    return nil, nil
end

local function SetNameplateExtrasAlpha(uf, alpha)
    if not uf then
        return
    end
    if uf.name and uf.name.SetAlpha then
        uf.name:SetAlpha(alpha)
    end
    if uf.LevelFrame and uf.LevelFrame.SetAlpha then
        uf.LevelFrame:SetAlpha(alpha)
    end
    if uf.ClassificationFrame and uf.ClassificationFrame.SetAlpha then
        uf.ClassificationFrame:SetAlpha(alpha)
    end
    if uf.healthBar and uf.healthBar.SetAlpha then
        uf.healthBar:SetAlpha(alpha)
    end
end

function Nameplates:GetBarForGUID(guid)
    if not guid then
        return nil, nil
    end
    local enhancer = self.byGUID[guid]
    if enhancer and enhancer.statusBar and enhancer.statusBar:IsVisible() then
        return enhancer.statusBar, enhancer
    end

    -- Fallback: scan active nameplates in case /reload occurred with plates already visible
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        if plates then
            for i = 1, #plates do
                local plate = plates[i]
                local unitToken = plate and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
                if unitToken and UnitGUID(unitToken) == guid then
                    self:OnNamePlateAdded(unitToken)
                    enhancer = self.byGUID[guid]
                    if enhancer and enhancer.statusBar then
                        return enhancer.statusBar, enhancer
                    end
                end
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
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
        return
    end
    local namePlate = C_NamePlate.GetNamePlateForUnit(unitToken)
    local healthBar, unitFrame = ResolveNameplateHealthBar(namePlate)
    if not healthBar then
        return
    end

    SetNameplateExtrasAlpha(unitFrame, 1.0)

    local enhancer = ns.UnitBars:CreateBarEnhancer(healthBar, unitToken, true)
    enhancer.unitFrame = unitFrame
    enhancer.deathTriggered = false
    enhancer.guid = UnitGUID(unitToken)

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
        SetNameplateExtrasAlpha(enhancer.unitFrame, 1.0)
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

    if ns.CombatFX and enhancer.statusBar then
        ns.CombatFX:SpawnDeathShatterBar(enhancer.statusBar)
    end

    local npCfg = ns.Config:Get("nameplates")
    if npCfg and npCfg.hideNameAndLevelOnDeath and enhancer.unitFrame then
        SetNameplateExtrasAlpha(enhancer.unitFrame, 0.0)
    end
end

function Nameplates:OnUnitHealth(unitToken)
    local enhancer = self.byUnit[unitToken]
    if not enhancer then
        return
    end
    ns.UnitBars:SyncUnitState(enhancer, false)

    local curHp = UnitHealth(unitToken) or 0
    if (curHp <= 0 or UnitIsDead(unitToken)) and not enhancer.deathTriggered then
        self:TriggerDeathForEnhancer(enhancer)
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
    local isMega = isCrit and (pctLost >= 0.28)
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
        return
    end
    local plates = C_NamePlate.GetNamePlates()
    if not plates then
        return
    end
    for i = 1, #plates do
        local plate = plates[i]
        local unitToken = plate and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
        if unitToken then
            self:OnNamePlateAdded(unitToken)
        end
    end
end

function Nameplates:OnEnable()
    ns.Events:Register("NAME_PLATE_UNIT_ADDED", function(_, _, unitToken)
        self:OnNamePlateAdded(unitToken)
    end, self)

    ns.Events:Register("NAME_PLATE_UNIT_REMOVED", function(_, _, unitToken)
        self:OnNamePlateRemoved(unitToken)
    end, self)

    ns.Events:Register("UNIT_HEALTH", function(_, _, unitToken)
        if self.byUnit[unitToken] then
            self:OnUnitHealth(unitToken)
        end
    end, self)

    ns.Events:Register("PLAYER_ENTERING_WORLD", function()
        self:ScanExistingNameplates()
    end, self)

    self:ScanExistingNameplates()
end
