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

-- HUD frames to fade out-of-combat across Classic / Forever (16001) / Modern layouts.
local HUD_FRAME_NAMES = {
    -- Unit Frames
    "PlayerFrame",
    "PetFrame",
    "TargetFrame",
    "FocusFrame",
    "PartyFrame",
    "PartyMemberFrame1",
    "PartyMemberFrame2",
    "PartyMemberFrame3",
    "PartyMemberFrame4",
    "CompactPartyFrame",
    -- Action Bars & Status Bars
    "MainMenuBar",
    "MainActionBar",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",
    "MultiBar5",
    "MultiBar6",
    "MultiBar7",
    "StanceBar",
    "StanceBarFrame",
    "ShapeshiftBarFrame",
    "PetActionBar",
    "PetActionBarFrame",
    "PossessActionBar",
    "PossessBarFrame",
    "StatusTrackingBarManager",
    "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer",
    "MainMenuExpBar",
    "ReputationWatchBar",
    -- Utility, Bags, Micro Menu, Buffs & Objective Tracker
    "BagsBar",
    "MicroMenuContainer",
    "MicroMenu",
    "MicroButtonAndBagsBar",
    "ObjectiveTrackerFrame",
    "WatchFrame",
    "QuestWatchFrame",
    "BuffFrame",
    "DebuffFrame",
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

function StateEngine:ApplyHUDAlpha(alpha)
    local clamped = math.max(0.05, math.min(1.0, alpha or 1.0))
    local fadedSet = {}
    for i = 1, #HUD_FRAME_NAMES do
        local f = _G[HUD_FRAME_NAMES[i]]
        if f then
            fadedSet[f] = true
        end
    end

    for i = 1, #HUD_FRAME_NAMES do
        local f = _G[HUD_FRAME_NAMES[i]]
        if f and f.SetAlpha then
            -- Skip child frames whose parent is already in fadedSet so effective alpha is never multiplied twice
            local parent = f.GetParent and f:GetParent()
            if not (parent and fadedSet[parent]) then
                pcall(f.SetAlpha, f, clamped)
            end
        end
    end
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
    if not cfg or (cfg.fadeHUD == false and cfg.fadeUnitFrames == false) then
        return 1.0
    end
    if state == self.STATES.COMBAT then
        return cfg.alphaCombat or 1.0
    end
    -- Wake HUD to 100% opacity when a target is actively selected (unless testing an explicit /fui state override)
    if not self.overrideState and cfg.wakeOnTarget ~= false and UnitExists and UnitExists("target") then
        return 1.0
    end
    if state == self.STATES.HARVESTING then
        return cfg.alphaHarvesting or 0.30
    elseif state == self.STATES.RESTING then
        return cfg.alphaResting or 0.20
    elseif state == self.STATES.TRAVELLING then
        return cfg.alphaTravelling or 0.25
    else
        return cfg.alphaExploring or 0.35
    end
end

function StateEngine:RefreshState(immediate)
    local nextState = self:EvaluateState()
    local prevState = self.currentState
    self.currentState = nextState
    self.targetAlpha = self:GetTargetAlphaForState(nextState)

    if nextState ~= prevState then
        ns.Events:FireCustom("FOREVERUI_STATE_CHANGED", nextState, prevState)
    end

    -- Snap immediately on combat entry or when requested
    if immediate or nextState == self.STATES.COMBAT then
        self.currentAlpha = self.targetAlpha
        ns.Events:UnregisterTicker("StateEngineAlpha")
        self:ApplyHUDAlpha(self.currentAlpha)
        return
    end

    if math.abs(self.currentAlpha - self.targetAlpha) > 0.005 then
        local fadeSpeed = (self.targetAlpha > self.currentAlpha) and 10.0 or 4.5
        ns.Events:RegisterTicker("StateEngineAlpha", function(dt)
            local diff = self.targetAlpha - self.currentAlpha
            if math.abs(diff) <= 0.005 then
                self.currentAlpha = self.targetAlpha
                self:ApplyHUDAlpha(self.currentAlpha)
                return false
            end
            self.currentAlpha = self.currentAlpha + diff * math.min(1.0, dt * fadeSpeed)
            self:ApplyHUDAlpha(self.currentAlpha)
            return true
        end)
    else
        self:ApplyHUDAlpha(self.targetAlpha)
    end
end

function StateEngine:SetOverrideState(state)
    if state and self.STATES[state] then
        self.overrideState = self.STATES[state]
    else
        self.overrideState = nil
    end
    self:RefreshState( false )
end

function StateEngine:OnEnable()
    ns.Events:Register("PLAYER_REGEN_DISABLED", function()
        self.overrideState = nil
        self:RefreshState(true)
    end, self)

    ns.Events:Register("PLAYER_REGEN_ENABLED", function()
        self:RefreshState(false)
    end, self)

    ns.Events:Register("PLAYER_TARGET_CHANGED", function()
        self:RefreshState(false)
    end, self)

    ns.Events:Register("PLAYER_UPDATE_RESTING", function()
        self:RefreshState(false)
    end, self)

    ns.Events:Register("PLAYER_MOUNT_DISPLAY_CHANGED", function()
        self:RefreshState(false)
    end, self)

    ns.Events:Register("ZONE_CHANGED_NEW_AREA", function()
        self:RefreshState(false)
    end, self)

    ns.Events:Register("PLAYER_ENTERING_WORLD", function()
        self:RefreshState(false)
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
            self:RefreshState(false)
        end
    end, self)

    ns.Events:Register("UNIT_SPELLCAST_STOP", function(_, _, unitTarget)
        if unitTarget == "player" and self.isHarvesting then
            self.isHarvesting = false
            self:RefreshState(false)
        end
    end, self)

    self:RefreshState(false)
end
