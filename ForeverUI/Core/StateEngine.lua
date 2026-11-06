local addonName, ns = ...
local StateEngine = {}
ns.StateEngine = StateEngine

StateEngine.STATES = {
    COMBAT = "COMBAT",
    HARVESTING = "HARVESTING",
    RESTING = "RESTING",
    TRAVELLING = "TRAVELLING",
    EXPLORING = "EXPLORING",
}

local HARVEST_KEYWORDS = {
    "herb", "mining", "skinning", "fishing", "lumber", "forag", "gather", "prospect", "disenchant",
}

StateEngine.currentState = StateEngine.STATES.EXPLORING
StateEngine.isHarvesting = false
StateEngine.overrideState = nil
StateEngine.currentAlpha = 1.0
StateEngine.targetAlpha = 1.0

local function IsHarvestSpell(spellName)
    if not spellName or type(spellName) ~= "string" then
        return false
    end
    local lower = string.lower(spellName)
    for i = 1, #HARVEST_KEYWORDS do
        if string.find(lower, HARVEST_KEYWORDS[i], 1, true) then
            return true
        end
    end
    return false
end

function StateEngine:EvaluateState()
    if self.overrideState then
        return self.overrideState
    end
    if InCombatLockdown() or UnitAffectingCombat("player") then
        return self.STATES.COMBAT
    end
    if self.isHarvesting then
        return self.STATES.HARVESTING
    end
    if IsResting and IsResting() then
        return self.STATES.RESTING
    end
    if (IsMounted and IsMounted()) or (UnitOnTaxi and UnitOnTaxi("player")) then
        return self.STATES.TRAVELLING
    end
    return self.STATES.EXPLORING
end

function StateEngine:GetTargetAlphaForState(state)
    local cfg = ns.Config:Get("stateEngine")
    if not cfg or not cfg.fadeUnitFrames then
        return 1.0
    end
    if state == self.STATES.COMBAT then
        return cfg.alphaCombat or 1.0
    elseif state == self.STATES.HARVESTING then
        return cfg.alphaHarvesting or 0.60
    elseif state == self.STATES.RESTING then
        return cfg.alphaResting or 0.42
    elseif state == self.STATES.TRAVELLING then
        return cfg.alphaTravelling or 0.65
    else
        return cfg.alphaExploring or 0.72
    end
end

function StateEngine:RefreshState()
    local nextState = self:EvaluateState()
    local prevState = self.currentState
    self.currentState = nextState
    self.targetAlpha = self:GetTargetAlphaForState(nextState)

    if nextState ~= prevState then
        ns.Events:FireCustom("FOREVERUI_STATE_CHANGED", nextState, prevState)
    end

    if math.abs(self.currentAlpha - self.targetAlpha) > 0.005 then
        ns.Events:RegisterTicker("StateEngineAlpha", function(dt)
            local diff = self.targetAlpha - self.currentAlpha
            if math.abs(diff) <= 0.005 then
                self.currentAlpha = self.targetAlpha
                if PlayerFrame and PlayerFrame.SetAlpha then
                    PlayerFrame:SetAlpha(self.currentAlpha)
                end
                return false
            end
            self.currentAlpha = self.currentAlpha + diff * math.min(1.0, dt * 6.0)
            if PlayerFrame and PlayerFrame.SetAlpha then
                PlayerFrame:SetAlpha(self.currentAlpha)
            end
            return true
        end)
    end
end

function StateEngine:SetOverrideState(state)
    if state and self.STATES[state] then
        self.overrideState = self.STATES[state]
    else
        self.overrideState = nil
    end
    self:RefreshState()
end

function StateEngine:OnEnable()
    ns.Events:Register("PLAYER_REGEN_DISABLED", function()
        self.overrideState = nil
        self:RefreshState()
    end, self)

    ns.Events:Register("PLAYER_REGEN_ENABLED", function()
        self:RefreshState()
    end, self)

    ns.Events:Register("PLAYER_UPDATE_RESTING", function()
        self:RefreshState()
    end, self)

    ns.Events:Register("PLAYER_MOUNT_DISPLAY_CHANGED", function()
        self:RefreshState()
    end, self)

    ns.Events:Register("ZONE_CHANGED_NEW_AREA", function()
        self:RefreshState()
    end, self)

    ns.Events:Register("UNIT_SPELLCAST_START", function(_, _, unitTarget, _, spellID)
        if unitTarget ~= "player" then
            return
        end
        local spellName = nil
        if C_Spell and C_Spell.GetSpellName and spellID then
            spellName = C_Spell.GetSpellName(spellID)
        elseif GetSpellInfo and spellID then
            spellName = GetSpellInfo(spellID)
        end
        if IsHarvestSpell(spellName) then
            self.isHarvesting = true
            self:RefreshState()
        end
    end, self)

    ns.Events:Register("UNIT_SPELLCAST_STOP", function(_, _, unitTarget)
        if unitTarget == "player" and self.isHarvesting then
            self.isHarvesting = false
            self:RefreshState()
        end
    end, self)

    self:RefreshState()
end
