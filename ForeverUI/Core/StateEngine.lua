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

-- Direct bounding-box hover check list (excludes wide/tall empty layout containers like ObjectiveTrackerFrame)
local HOVER_FRAME_NAMES = {
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
    "BagsBar",
    "MicroMenuContainer",
    "MicroMenu",
    "MicroButtonAndBagsBar",
}

local HOVER_NAME_PREFIXES = {
    "PlayerFrame",
    "PetFrame",
    "TargetFrame",
    "FocusFrame",
    "Party",
    "Compact",
    "ActionButton",
    "MultiBar",
    "MainMenu",
    "MainActionBar",
    "Stance",
    "Shapeshift",
    "PetAction",
    "Possess",
    "StatusTracking",
    "Reputation",
    "BagsBar",
    "CharacterBag",
    "KeyRing",
    "Micro",
    "Buff",
    "Debuff",
    "TempEnchant",
    "ObjectiveTracker",
    "WatchFrame",
    "Quest",
}

StateEngine.currentState = StateEngine.STATES.EXPLORING
StateEngine.isHarvesting = false
StateEngine.overrideState = nil
StateEngine.isMouseHovered = false
StateEngine.unhoverTimer = 0
StateEngine.hoverCheckAccum = 0
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

local function MatchesHoverPrefix(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    for i = 1, #HOVER_NAME_PREFIXES do
        if string.find(name, HOVER_NAME_PREFIXES[i], 1, true) == 1 then
            return true
        end
    end
    return false
end

function StateEngine:IsMouseOverHUD()
    local hudSet = {}
    for i = 1, #HUD_FRAME_NAMES do
        local f = _G[HUD_FRAME_NAMES[i]]
        if f then
            hudSet[f] = true
        end
    end

    -- 1. Check active mouse focus frames (GetMouseFoci in 16001, GetMouseFocus fallback)
    local foci = nil
    if GetMouseFoci then
        local ok, res = pcall(GetMouseFoci)
        if ok and type(res) == "table" then
            foci = res
        end
    elseif GetMouseFocus then
        local ok, res = pcall(GetMouseFocus)
        if ok and res then
            foci = { res }
        end
    end

    if foci then
        for i = 1, #foci do
            local focus = foci[i]
            if focus and focus ~= WorldFrame and focus ~= UIParent then
                local cur = focus
                local depth = 0
                local isNameplate = false
                local matchedHUD = false
                while cur and cur ~= UIParent and cur ~= WorldFrame and depth < 14 do
                    if hudSet[cur] then
                        matchedHUD = true
                        break
                    end
                    local okN, fName = pcall(cur.GetName, cur)
                    if okN and type(fName) == "string" then
                        if string.find(fName, "NamePlate", 1, true) == 1 then
                            isNameplate = true
                            break
                        end
                        if MatchesHoverPrefix(fName) then
                            matchedHUD = true
                            break
                        end
                    end
                    local okP, parent = pcall(cur.GetParent, cur)
                    cur = okP and parent or nil
                    depth = depth + 1
                end
                if matchedHUD and not isNameplate then
                    return true
                end
            end
        end
    end

    -- 2. Check bounding-box IsMouseOver on visible unit frames & action bars (catches gaps/bars with EnableMouse(false))
    for i = 1, #HOVER_FRAME_NAMES do
        local f = _G[HOVER_FRAME_NAMES[i]]
        if f and f.IsShown and f.IsMouseOver then
            local okS, shown = pcall(f.IsShown, f)
            if okS and shown then
                local okM, over = pcall(f.IsMouseOver, f)
                if okM and over then
                    return true
                end
            end
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
    -- Wake HUD to 100% normal opacity whenever mousing over any HUD element
    if self.isMouseHovered and cfg.wakeOnMouseover ~= false then
        return 1.0
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

    -- Lightweight hover watcher: restores HUD to 100% normal opacity on mouseover and smoothly fades back out after leaving
    ns.Events:RegisterTicker("StateEngineHoverWatcher", function(dt)
        self.hoverCheckAccum = (self.hoverCheckAccum or 0) + dt
        if self.hoverCheckAccum < 0.06 then
            return true
        end
        local stepDt = self.hoverCheckAccum
        self.hoverCheckAccum = 0

        local cfg = ns.Config:Get("stateEngine")
        if not cfg or (cfg.fadeHUD == false and cfg.fadeUnitFrames == false) or cfg.wakeOnMouseover == false then
            if self.isMouseHovered then
                self.isMouseHovered = false
                self.unhoverTimer = 0
                self:RefreshState(false)
            end
            return true
        end

        if InCombatLockdown() or UnitAffectingCombat("player") then
            self.isMouseHovered = false
            self.unhoverTimer = 0
            return true
        end

        local overNow = self:IsMouseOverHUD()
        if overNow then
            self.unhoverTimer = 0.16
            if not self.isMouseHovered then
                self.isMouseHovered = true
                self:RefreshState(false)
            end
        elseif self.isMouseHovered then
            self.unhoverTimer = (self.unhoverTimer or 0) - stepDt
            if self.unhoverTimer <= 0 then
                self.isMouseHovered = false
                self.unhoverTimer = 0
                self:RefreshState(false)
            end
        end

        return true
    end)

    self:RefreshState(false)
end
