local addonName, ns = ...
local StateEngine = {}
ns.StateEngine = StateEngine

local QuestTracker = {}
ns.QuestTracker = QuestTracker

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
-- Note: ObjectiveTrackerFrame / WatchFrame / QuestWatchFrame are managed per-quest by ns.QuestTracker.
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

local TRACKER_FRAME_NAMES = {
    ObjectiveTrackerFrame = true,
    WatchFrame = true,
    QuestWatchFrame = true,
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
}

StateEngine.currentState = StateEngine.STATES.EXPLORING
StateEngine.isHarvesting = false
StateEngine.overrideState = nil
StateEngine.isMouseHovered = false
StateEngine.unhoverTimer = 0
StateEngine.hoverCheckAccum = 0
StateEngine.currentAlpha = 1.0
StateEngine.targetAlpha = 1.0

local function SafeNumber(val)
    if val == nil or ns.IsSecret(val) or type(val) ~= "number" then
        return nil
    end
    return val
end

local function SafeString(val)
    if val == nil or ns.IsSecret(val) or type(val) ~= "string" then
        return nil
    end
    return val
end

local function SafeBool(val)
    if val == nil or ns.IsSecret(val) then
        return false
    end
    return val == true
end

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
        local name = HUD_FRAME_NAMES[i]
        if not TRACKER_FRAME_NAMES[name] then
            local f = _G[name]
            if f then
                hudSet[f] = true
            end
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
    local skipTracker = ns.Config:Get("questTracker", "enabled") ~= false
    local fadedSet = {}
    for i = 1, #HUD_FRAME_NAMES do
        local name = HUD_FRAME_NAMES[i]
        if not (skipTracker and TRACKER_FRAME_NAMES[name]) then
            local f = _G[name]
            if f then
                fadedSet[f] = true
            end
        end
    end

    for i = 1, #HUD_FRAME_NAMES do
        local name = HUD_FRAME_NAMES[i]
        if not (skipTracker and TRACKER_FRAME_NAMES[name]) then
            local f = _G[name]
            if f and f.SetAlpha then
                -- Skip child frames whose parent is already in fadedSet so effective alpha is never multiplied twice
                local parent = f.GetParent and f:GetParent()
                if not (parent and fadedSet[parent]) then
                    pcall(f.SetAlpha, f, clamped)
                end
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
    self:RefreshState(false)
end

-- ============================================================================
-- PROXIMITY QUEST OBJECTIVE TRACKER (CLOSE = 100% SOLID, NEARBY = FADED, FAR = QUEST BOOK ONLY)
-- ============================================================================
QuestTracker.TIERS = {
    CLOSE = "CLOSE",
    NEARBY = "NEARBY",
    FAR = "FAR",
}

local TRACKER_MODULE_GLOBALS = {
    "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker",
    "WorldQuestObjectiveTracker",
    "BonusObjectiveTracker",
    "ScenarioObjectiveTracker",
    "AchievementObjectiveTracker",
    "ProfessionsRecipeTracker",
    "MonthlyActivitiesObjectiveTracker",
    "AdventureObjectiveTracker",
    "UIWidgetObjectiveTracker",
    "QUEST_TRACKER_MODULE",
    "CAMPAIGN_QUEST_TRACKER_MODULE",
    "WORLD_QUEST_TRACKER_MODULE",
    "BONUS_OBJECTIVE_TRACKER_MODULE",
}

QuestTracker.questTierByID = {}
QuestTracker.questDistYardsByID = {}
QuestTracker.questReasonByID = {}
QuestTracker.questTitleByID = {}
QuestTracker.questIDByTitle = {}
QuestTracker.targetAlphaByID = {}
QuestTracker.displayAlphaByID = {}
QuestTracker.hasAnyCloseQuest = false
QuestTracker.closestCloseQuestID = nil
QuestTracker.isMouseHovered = false
QuestTracker.unhoverTimer = 0
QuestTracker.isUpdatingWatches = false
QuestTracker.pendingWatchSync = false
QuestTracker.scanAccum = 0
QuestTracker.alphaAccum = 0
QuestTracker.headerDisplayAlpha = 0.35

local function NormalizeZoneName(text)
    local s = SafeString(text)
    if not s or s == "" then
        return nil
    end
    return string.lower(s)
end

local function HeaderMatchesCurrentZone(headerTitle, zoneLower, subZoneLower, minimapZoneLower)
    local h = NormalizeZoneName(headerTitle)
    if not h then
        return false
    end
    if zoneLower and (h == zoneLower or string.find(zoneLower, h, 1, true) or string.find(h, zoneLower, 1, true)) then
        return true
    end
    if subZoneLower and (h == subZoneLower or string.find(subZoneLower, h, 1, true) or string.find(h, subZoneLower, 1, true)) then
        return true
    end
    if minimapZoneLower and (h == minimapZoneLower or string.find(minimapZoneLower, h, 1, true) or string.find(h, minimapZoneLower, 1, true)) then
        return true
    end
    return false
end

-- In WoW 16001: Usage: local isOnQuest = C_QuestLog.IsUnitOnQuest(unit, questID)
local function IsUnitRelatedToQuest(unitToken, questID)
    if not unitToken or not questID or not UnitExists then
        return false
    end
    local okE, exists = pcall(UnitExists, unitToken)
    if not okE or not SafeBool(exists) then
        return false
    end
    if C_QuestLog and C_QuestLog.IsUnitOnQuest then
        local okU, onQuest = pcall(C_QuestLog.IsUnitOnQuest, unitToken, questID)
        if okU and SafeBool(onQuest) then
            return true
        end
    end
    return false
end

local function IsAnyVisibleUnitOnQuest(questID)
    if IsUnitRelatedToQuest("target", questID) then
        return true
    end
    if IsUnitRelatedToQuest("mouseover", questID) then
        return true
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local okP, plates = pcall(C_NamePlate.GetNamePlates)
        if okP and type(plates) == "table" then
            for i = 1, #plates do
                local plate = plates[i]
                local unitToken = plate and plate.namePlateUnitToken
                if not unitToken and plate and plate.UnitFrame then
                    unitToken = plate.UnitFrame.unit
                end
                if SafeString(unitToken) and IsUnitRelatedToQuest(unitToken, questID) then
                    return true
                end
            end
        end
    end
    return false
end

local function IsPlayerInsideQuestBlob(questID)
    if C_Minimap and C_Minimap.IsInsideQuestBlob then
        local okB, inside = pcall(C_Minimap.IsInsideQuestBlob, questID)
        if okB and SafeBool(inside) then
            return true
        end
    end
    return false
end

function QuestTracker:IsMouseOverTracker()
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

    if not foci then
        return false
    end

    local rootTracker = _G.ObjectiveTrackerFrame
    local watchFrame = _G.WatchFrame
    local questWatchFrame = _G.QuestWatchFrame

    for i = 1, #foci do
        local cur = foci[i]
        local depth = 0
        while cur and cur ~= UIParent and cur ~= WorldFrame and depth < 14 do
            if cur == rootTracker or cur == watchFrame or cur == questWatchFrame then
                return true
            end
            if cur.GetName then
                local okN, fName = pcall(cur.GetName, cur)
                local safeName = SafeString(fName)
                if safeName then
                    if string.find(safeName, "ObjectiveTracker", 1, true) == 1
                        or string.find(safeName, "QuestObjective", 1, true) == 1
                        or string.find(safeName, "CampaignQuestObjective", 1, true) == 1
                        or string.find(safeName, "WatchFrame", 1, true) == 1
                    then
                        return true
                    end
                end
            end
            local okP, parent = pcall(cur.GetParent, cur)
            cur = okP and parent or nil
            depth = depth + 1
        end
    end

    return false
end

local function IsQuestCurrentlyWatched(questID)
    if C_QuestLog and C_QuestLog.GetQuestWatchType then
        local ok, watchType = pcall(C_QuestLog.GetQuestWatchType, questID)
        if ok and watchType ~= nil and not ns.IsSecret(watchType) then
            return true
        end
        return false
    end
    if C_QuestLog and C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex then
        local okN, numWatches = pcall(C_QuestLog.GetNumQuestWatches)
        local count = SafeNumber(numWatches) or 0
        for i = 1, count do
            local okQ, watchedID = pcall(C_QuestLog.GetQuestIDForQuestWatchIndex, i)
            if okQ and SafeNumber(watchedID) == questID then
                return true
            end
        end
    end
    return false
end

function QuestTracker:EvaluateQuestDistances(forceWatchSync)
    local cfg = ns.Config:Get("questTracker")
    if not cfg or cfg.enabled == false then
        return
    end
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then
        return
    end

    local closeYards = cfg.closeDistanceYards or 180
    local nearbyYards = cfg.nearbyDistanceYards or 600
    local closeEnterSq = closeYards * closeYards
    local closeExitSq = (closeYards + 25) * (closeYards + 25)
    local nearbyEnterSq = nearbyYards * nearbyYards
    local nearbyExitSq = (nearbyYards + 60) * (nearbyYards + 60)
    local alphaClose = cfg.alphaClose or 1.0
    local alphaNearby = cfg.alphaNearby or 0.35

    local mapID = nil
    local playerMapX, playerMapY = nil, nil
    local questsOnCurrentMap = {}
    local worldMapOpen = _G.WorldMapFrame and _G.WorldMapFrame.IsShown and _G.WorldMapFrame:IsShown()

    if C_Map and C_Map.GetBestMapForUnit then
        local okM, bestMap = pcall(C_Map.GetBestMapForUnit, "player")
        mapID = okM and SafeNumber(bestMap) or nil
    end

    if mapID then
        if not worldMapOpen and C_QuestLog.SetMapForQuestPOIs then
            pcall(C_QuestLog.SetMapForQuestPOIs, mapID)
        end
        if C_QuestLog.GetQuestsOnMap then
            local okQ, mapQuests = pcall(C_QuestLog.GetQuestsOnMap, mapID)
            if okQ and type(mapQuests) == "table" then
                for i = 1, #mapQuests do
                    local qInfo = mapQuests[i]
                    local qID = qInfo and SafeNumber(qInfo.questID)
                    if qID then
                        questsOnCurrentMap[qID] = qInfo
                    end
                end
            end
        end
        if C_Map and C_Map.GetPlayerMapPosition then
            local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
            if okPos and pos and pos.GetXY then
                local okXY, px, py = pcall(pos.GetXY, pos)
                if okXY then
                    playerMapX = SafeNumber(px)
                    playerMapY = SafeNumber(py)
                end
            end
        end
    end

    local zoneLower = NormalizeZoneName(GetRealZoneText and GetRealZoneText() or nil)
    local subZoneLower = NormalizeZoneName(GetSubZoneText and GetSubZoneText() or nil)
    local minimapZoneLower = NormalizeZoneName(GetMinimapZoneText and GetMinimapZoneText() or nil)

    local okNum, numShownEntries = pcall(C_QuestLog.GetNumQuestLogEntries)
    local numEntries = okNum and SafeNumber(numShownEntries) or 0

    local seenQuests = {}
    local currentHeaderTitle = nil
    local anyClose = false
    local closestCloseID = nil
    local closestCloseDistSq = nil
    local watchChanged = false
    local inCombat = InCombatLockdown and InCombatLockdown() or false

    for i = 1, numEntries do
        local okInfo, info = pcall(C_QuestLog.GetInfo, i)
        if okInfo and type(info) == "table" then
            if SafeBool(info.isHeader) then
                currentHeaderTitle = SafeString(info.title)
            else
                local questID = SafeNumber(info.questID)
                local isHidden = SafeBool(info.isHidden)
                local isBounty = SafeBool(info.isBounty)
                if questID and questID > 0 and not isHidden and not isBounty then
                    seenQuests[questID] = true
                    local title = SafeString(info.title)
                    if title and title ~= "" then
                        self.questTitleByID[questID] = title
                        self.questIDByTitle[title] = questID
                        self.questIDByTitle[string.lower(title)] = questID
                    end

                    local prevTier = self.questTierByID[questID]
                    local closeThreshSq = (prevTier == self.TIERS.CLOSE) and closeExitSq or closeEnterSq
                    local nearbyThreshSq = (prevTier == self.TIERS.CLOSE or prevTier == self.TIERS.NEARBY) and nearbyExitSq or nearbyEnterSq

                    -- 1. Check native C_Minimap.IsInsideQuestBlob(questID)
                    local insideBlob = IsPlayerInsideQuestBlob(questID)

                    -- 2. Check visible nameplates / target / mouseover via C_QuestLog.IsUnitOnQuest(unit, questID)
                    local unitRightHere = IsAnyVisibleUnitOnQuest(questID)

                    -- 3. Check C_QuestLog.GetDistanceSqToQuest(questID)
                    local distSq = nil
                    local onContinent = true
                    if C_QuestLog.GetDistanceSqToQuest then
                        local okD, dSq, onCont = pcall(C_QuestLog.GetDistanceSqToQuest, questID)
                        if okD then
                            distSq = SafeNumber(dSq)
                            if onCont ~= nil and not ns.IsSecret(onCont) then
                                onContinent = (onCont == true)
                            end
                        end
                    end

                    -- 4. Check C_QuestLog.IsOnMap(questID) and normalized map-pin distance
                    local onMap, hasLocalPOI = false, false
                    if C_QuestLog.IsOnMap then
                        local okOM, om, poi = pcall(C_QuestLog.IsOnMap, questID)
                        if okOM then
                            onMap = SafeBool(om)
                            hasLocalPOI = SafeBool(poi)
                        end
                    end

                    local mapPinDistSq = nil
                    local mapPin = questsOnCurrentMap[questID]
                    if mapPin and playerMapX and playerMapY then
                        local pinX = SafeNumber(mapPin.x)
                        local pinY = SafeNumber(mapPin.y)
                        if pinX and pinY then
                            local dx = pinX - playerMapX
                            local dy = pinY - playerMapY
                            mapPinDistSq = dx * dx + dy * dy
                        end
                    end

                    if distSq ~= nil then
                        self.questDistYardsByID[questID] = math.sqrt(math.max(0, distSq))
                    else
                        self.questDistYardsByID[questID] = nil
                    end

                    local tier = self.TIERS.FAR
                    local reason = "far"

                    if insideBlob then
                        tier = self.TIERS.CLOSE
                        reason = "inside quest area blob"
                        distSq = distSq or 0
                    elseif unitRightHere then
                        tier = self.TIERS.CLOSE
                        reason = "quest unit nearby"
                        distSq = 0
                    elseif SafeBool(info.isTask) then
                        tier = self.TIERS.CLOSE
                        reason = "active area objective"
                        distSq = distSq or 0
                    elseif distSq ~= nil and onContinent and distSq <= closeThreshSq then
                        tier = self.TIERS.CLOSE
                        reason = string.format("%.0f yds <= %d yds", math.sqrt(distSq), closeYards)
                    elseif mapPinDistSq ~= nil and mapPinDistSq <= 0.0064 then
                        -- Within ~8% of zone map width of the quest pin on the current map
                        tier = self.TIERS.CLOSE
                        reason = "on map quest area pin"
                    elseif not onContinent then
                        tier = self.TIERS.FAR
                        reason = "other continent"
                    elseif distSq ~= nil then
                        if distSq <= nearbyThreshSq then
                            tier = self.TIERS.NEARBY
                            reason = string.format("%.0f yds", math.sqrt(distSq))
                        else
                            tier = self.TIERS.FAR
                            reason = string.format("%.0f yds > %d yds", math.sqrt(distSq), nearbyYards)
                        end
                    else
                        -- Fallback when distSq is nil
                        if mapPinDistSq ~= nil then
                            if mapPinDistSq <= 0.1200 then
                                tier = self.TIERS.NEARBY
                                reason = "same zone map"
                            else
                                tier = self.TIERS.FAR
                                reason = "far on zone map"
                            end
                        elseif hasLocalPOI then
                            tier = self.TIERS.CLOSE
                            reason = "local POI area"
                        elseif onMap or HeaderMatchesCurrentZone(currentHeaderTitle, zoneLower, subZoneLower, minimapZoneLower) then
                            tier = self.TIERS.NEARBY
                            reason = "current zone"
                        else
                            tier = self.TIERS.FAR
                            reason = "other zone"
                        end
                    end

                    self.questTierByID[questID] = tier
                    self.questReasonByID[questID] = reason

                    if tier == self.TIERS.CLOSE then
                        self.targetAlphaByID[questID] = alphaClose
                        anyClose = true
                        local sortDist = distSq or 0
                        if closestCloseID == nil or sortDist < closestCloseDistSq then
                            closestCloseID = questID
                            closestCloseDistSq = sortDist
                        end
                    elseif tier == self.TIERS.NEARBY then
                        self.targetAlphaByID[questID] = alphaNearby
                    else
                        self.targetAlphaByID[questID] = 0.0
                    end

                    if self.displayAlphaByID[questID] == nil then
                        self.displayAlphaByID[questID] = self.targetAlphaByID[questID]
                    end

                    -- Manage Quest Book vs Right-Hand Objective Tracker visibility:
                    -- CLOSE and NEARBY quests are watched in the Objective Tracker;
                    -- FAR quests are unwatched so they remain in the Quest Book only.
                    if cfg.autoManageWatches ~= false then
                        local shouldWatch = (tier == self.TIERS.CLOSE or tier == self.TIERS.NEARBY)
                        local isWatched = IsQuestCurrentlyWatched(questID)
                        if shouldWatch ~= isWatched then
                            if inCombat then
                                self.pendingWatchSync = true
                            elseif not self.isUpdatingWatches or forceWatchSync then
                                self.isUpdatingWatches = true
                                if shouldWatch and C_QuestLog.AddQuestWatch then
                                    pcall(C_QuestLog.AddQuestWatch, questID)
                                    watchChanged = true
                                elseif not shouldWatch and C_QuestLog.RemoveQuestWatch then
                                    pcall(C_QuestLog.RemoveQuestWatch, questID)
                                    watchChanged = true
                                end
                                self.isUpdatingWatches = false
                            end
                        end
                    end
                end
            end
        end
    end

    -- Clean up removed/turned-in quests
    for qID in pairs(self.questTierByID) do
        if not seenQuests[qID] then
            self.questTierByID[qID] = nil
            self.questDistYardsByID[qID] = nil
            self.questReasonByID[qID] = nil
            self.targetAlphaByID[qID] = nil
            self.displayAlphaByID[qID] = nil
            local oldTitle = self.questTitleByID[qID]
            if oldTitle then
                self.questIDByTitle[oldTitle] = nil
                self.questIDByTitle[string.lower(oldTitle)] = nil
                self.questTitleByID[qID] = nil
            end
        end
    end

    self.hasAnyCloseQuest = anyClose
    self.closestCloseQuestID = closestCloseID

    if not inCombat then
        if watchChanged and SortQuestWatches then
            self.isUpdatingWatches = true
            pcall(SortQuestWatches)
            self.isUpdatingWatches = false
        end

        if cfg.autoSuperTrackClose ~= false and closestCloseID and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
            local currentSuper = C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
            if SafeNumber(currentSuper) ~= closestCloseID then
                pcall(C_SuperTrack.SetSuperTrackedQuestID, closestCloseID)
            end
        end
    end
end

local function MatchQuestIDFromText(text, questIDByTitle, questTitleByID)
    local safeText = SafeString(text)
    if not safeText or safeText == "" then
        return nil
    end
    local direct = questIDByTitle[safeText] or questIDByTitle[string.lower(safeText)]
    if direct then
        return direct
    end
    local lowerText = string.lower(safeText)
    for qID, title in pairs(questTitleByID) do
        local lowerTitle = string.lower(title)
        if lowerTitle ~= "" and string.find(lowerText, lowerTitle, 1, true) then
            return qID
        end
    end
    return nil
end

local function ExtractQuestIDFromBlock(block, questIDByTitle, questTitleByID)
    if type(block) ~= "table" then
        return nil
    end
    local id = SafeNumber(block.id) or SafeNumber(block.questID)
    if id and id > 0 then
        return id
    end
    if type(block.poiButton) == "table" then
        local poiQuestID = SafeNumber(block.poiButton.questID)
        if poiQuestID and poiQuestID > 0 then
            return poiQuestID
        end
    end
    if block.HeaderText and block.HeaderText.GetText then
        local okT, text = pcall(block.HeaderText.GetText, block.HeaderText)
        if okT then
            local matched = MatchQuestIDFromText(text, questIDByTitle, questTitleByID)
            if matched then
                return matched
            end
        end
    end
    -- Scan FontString regions on block to match quest title
    if block.GetRegions then
        local okR, regions = pcall(function()
            return { block:GetRegions() }
        end)
        if okR and type(regions) == "table" then
            for i = 1, #regions do
                local reg = regions[i]
                if reg and reg.GetText then
                    local okT, text = pcall(reg.GetText, reg)
                    if okT then
                        local matched = MatchQuestIDFromText(text, questIDByTitle, questTitleByID)
                        if matched then
                            return matched
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function ApplyBlockAndSiblingsAlpha(block, alpha)
    if not block or not block.SetAlpha then
        return
    end
    pcall(block.SetAlpha, block, alpha)
    if block.poiButton and block.poiButton.SetAlpha then
        pcall(block.poiButton.SetAlpha, block.poiButton, alpha)
    end
    if block.itemButton and block.itemButton.SetAlpha then
        pcall(block.itemButton.SetAlpha, block.itemButton, alpha)
    end
    if block.ItemButton and block.ItemButton.SetAlpha then
        pcall(block.ItemButton.SetAlpha, block.ItemButton, alpha)
    end
    if block.rightEdgeFrame and block.rightEdgeFrame.SetAlpha then
        pcall(block.rightEdgeFrame.SetAlpha, block.rightEdgeFrame, alpha)
    end
end

function QuestTracker:GetAlphaForQuestID(questID, alphaClose, alphaNearby)
    if self.isMouseHovered then
        return 1.0
    end
    if not questID then
        return self.hasAnyCloseQuest and alphaClose or alphaNearby
    end
    local disp = self.displayAlphaByID[questID]
    if disp ~= nil then
        return disp
    end
    local tier = self.questTierByID[questID]
    if tier == self.TIERS.CLOSE then
        return alphaClose
    end
    return alphaNearby
end

function QuestTracker:ApplyTrackerAlphas(dt)
    local cfg = ns.Config:Get("questTracker")
    if not cfg or cfg.enabled == false then
        return
    end

    local alphaClose = cfg.alphaClose or 1.0
    local alphaNearby = cfg.alphaNearby or 0.35
    local step = math.min(1.0, (dt or 0.05) * 9.0)

    -- Smoothly interpolate per-quest display alphas
    for qID in pairs(self.targetAlphaByID) do
        local goal = self.isMouseHovered and 1.0 or (
            self.questTierByID[qID] == self.TIERS.CLOSE and alphaClose or alphaNearby
        )
        local cur = self.displayAlphaByID[qID]
        if cur == nil then
            cur = goal
        else
            local diff = goal - cur
            if math.abs(diff) <= 0.005 then
                cur = goal
            else
                cur = cur + diff * step
            end
        end
        self.displayAlphaByID[qID] = cur
    end

    local targetHeaderAlpha = (self.isMouseHovered or self.hasAnyCloseQuest) and alphaClose or alphaNearby
    local hDiff = targetHeaderAlpha - (self.headerDisplayAlpha or alphaNearby)
    if math.abs(hDiff) <= 0.005 then
        self.headerDisplayAlpha = targetHeaderAlpha
    else
        self.headerDisplayAlpha = (self.headerDisplayAlpha or alphaNearby) + hDiff * step
    end

    local rootTracker = _G.ObjectiveTrackerFrame
    if rootTracker and rootTracker.SetAlpha then
        -- Keep root ObjectiveTrackerFrame at 1.0 so child close-quest blocks render at 100% solid (1.0)
        -- while sibling nearby-quest blocks render at semi-transparent (0.35)
        pcall(rootTracker.SetAlpha, rootTracker, 1.0)
        if rootTracker.Header and rootTracker.Header.SetAlpha then
            pcall(rootTracker.Header.SetAlpha, rootTracker.Header, self.headerDisplayAlpha)
        end
        if rootTracker.HeaderMenu and rootTracker.HeaderMenu.SetAlpha then
            pcall(rootTracker.HeaderMenu.SetAlpha, rootTracker.HeaderMenu, self.headerDisplayAlpha)
        end
        if rootTracker.BlocksFrame and rootTracker.BlocksFrame.SetAlpha then
            pcall(rootTracker.BlocksFrame.SetAlpha, rootTracker.BlocksFrame, 1.0)
        end
        if rootTracker.ContentsFrame and rootTracker.ContentsFrame.SetAlpha then
            pcall(rootTracker.ContentsFrame.SetAlpha, rootTracker.ContentsFrame, 1.0)
        end
    end

    -- Collect all tracker modules
    local modules = {}
    local seenModules = {}
    local function AddModule(m)
        if type(m) == "table" and not seenModules[m] then
            seenModules[m] = true
            modules[#modules + 1] = m
        end
    end

    if rootTracker then
        if type(rootTracker.modules) == "table" then
            for i = 1, #rootTracker.modules do
                AddModule(rootTracker.modules[i])
            end
        end
        if type(rootTracker.MODULES) == "table" then
            for i = 1, #rootTracker.MODULES do
                AddModule(rootTracker.MODULES[i])
            end
        end
        if rootTracker.GetChildren then
            local okRC, rootChildren = pcall(function()
                return { rootTracker:GetChildren() }
            end)
            if okRC and type(rootChildren) == "table" then
                for i = 1, #rootChildren do
                    local rc = rootChildren[i]
                    if rc and rc ~= rootTracker.Header and rc ~= rootTracker.HeaderMenu and (rc.ContentsFrame or rc.usedBlocks or rc.Header) then
                        AddModule(rc)
                    end
                end
            end
        end
    end
    for i = 1, #TRACKER_MODULE_GLOBALS do
        AddModule(_G[TRACKER_MODULE_GLOBALS[i]])
    end

    local styledBlocks = {}

    for i = 1, #modules do
        local mod = modules[i]
        if mod.SetAlpha then
            pcall(mod.SetAlpha, mod, 1.0)
        end
        if mod.ContentsFrame and mod.ContentsFrame.SetAlpha then
            pcall(mod.ContentsFrame.SetAlpha, mod.ContentsFrame, 1.0)
        end

        local moduleHasCloseBlock = false

        local function ProcessBlock(block, explicitID)
            if type(block) ~= "table" or not block.SetAlpha or styledBlocks[block] then
                return
            end
            if block == mod.Header or block == mod.ContentsFrame then
                return
            end
            styledBlocks[block] = true

            local qID = SafeNumber(explicitID) or ExtractQuestIDFromBlock(block, self.questIDByTitle, self.questTitleByID)
            if qID and self.questTierByID[qID] == self.TIERS.CLOSE then
                moduleHasCloseBlock = true
            elseif not qID and self.hasAnyCloseQuest then
                moduleHasCloseBlock = true
            end
            local blockAlpha = self:GetAlphaForQuestID(qID, alphaClose, alphaNearby)
            ApplyBlockAndSiblingsAlpha(block, blockAlpha)
        end

        -- 1. Traverse mod.usedBlocks (supports both nested [template][id] and flat [id] tables)
        if type(mod.usedBlocks) == "table" then
            for k, v in pairs(mod.usedBlocks) do
                if type(v) == "table" then
                    if v.SetAlpha then
                        ProcessBlock(v, k)
                    else
                        for blockID, block in pairs(v) do
                            ProcessBlock(block, blockID)
                        end
                    end
                end
            end
        end

        -- 2. Traverse mod.ContentsFrame children (WoW 11.0 / 12.0 / Forever 16001)
        local container = mod.ContentsFrame or mod
        if container and container.GetChildren then
            local okC, children = pcall(function()
                return { container:GetChildren() }
            end)
            if okC and type(children) == "table" then
                for cIdx = 1, #children do
                    local child = children[cIdx]
                    if child and child ~= mod.Header and child ~= mod.ContentsFrame then
                        local childQuestID = ExtractQuestIDFromBlock(child, self.questIDByTitle, self.questTitleByID)
                        if childQuestID or child.HeaderText or child.id then
                            ProcessBlock(child, childQuestID)
                        elseif child.SetAlpha then
                            local poiQID = SafeNumber(child.questID)
                            if poiQID then
                                local poiAlpha = self:GetAlphaForQuestID(poiQID, alphaClose, alphaNearby)
                                pcall(child.SetAlpha, child, poiAlpha)
                            else
                                ProcessBlock(child, nil)
                            end
                        end
                    end
                end
            end
        end

        -- 3. Set module Header alpha ("Quests", "Campaign", etc.)
        if mod.Header and mod.Header.SetAlpha then
            local modHeaderAlpha = (self.isMouseHovered or moduleHasCloseBlock or self.hasAnyCloseQuest) and alphaClose or alphaNearby
            pcall(mod.Header.SetAlpha, mod.Header, modHeaderAlpha)
        end
    end

    -- 4. Fallback scan on ObjectiveTrackerFrame.BlocksFrame (if present)
    if rootTracker and rootTracker.BlocksFrame and rootTracker.BlocksFrame.GetChildren then
        local okB, children = pcall(function()
            return { rootTracker.BlocksFrame:GetChildren() }
        end)
        if okB and type(children) == "table" then
            for cIdx = 1, #children do
                local child = children[cIdx]
                if child and not styledBlocks[child] and child.SetAlpha then
                    local qID = ExtractQuestIDFromBlock(child, self.questIDByTitle, self.questTitleByID)
                    styledBlocks[child] = true
                    local blockAlpha = self:GetAlphaForQuestID(qID, alphaClose, alphaNearby)
                    ApplyBlockAndSiblingsAlpha(child, blockAlpha)
                end
            end
        end
    end

    -- 5. Fallback for Classic WatchFrame / QuestWatchFrame
    local fallbackAlpha = (self.isMouseHovered or self.hasAnyCloseQuest) and alphaClose or alphaNearby
    if _G.WatchFrame and _G.WatchFrame.SetAlpha then
        pcall(_G.WatchFrame.SetAlpha, _G.WatchFrame, fallbackAlpha)
    end
    if _G.QuestWatchFrame and _G.QuestWatchFrame.SetAlpha then
        pcall(_G.QuestWatchFrame.SetAlpha, _G.QuestWatchFrame, fallbackAlpha)
    end
end

function QuestTracker:RestoreAllAlphas()
    local rootTracker = _G.ObjectiveTrackerFrame
    if rootTracker and rootTracker.SetAlpha then
        pcall(rootTracker.SetAlpha, rootTracker, 1.0)
        if rootTracker.Header and rootTracker.Header.SetAlpha then
            pcall(rootTracker.Header.SetAlpha, rootTracker.Header, 1.0)
        end
    end
    for i = 1, #TRACKER_MODULE_GLOBALS do
        local mod = _G[TRACKER_MODULE_GLOBALS[i]]
        if type(mod) == "table" then
            if mod.SetAlpha then
                pcall(mod.SetAlpha, mod, 1.0)
            end
            if mod.Header and mod.Header.SetAlpha then
                pcall(mod.Header.SetAlpha, mod.Header, 1.0)
            end
            if mod.ContentsFrame and mod.ContentsFrame.GetChildren then
                local okC, children = pcall(function()
                    return { mod.ContentsFrame:GetChildren() }
                end)
                if okC and type(children) == "table" then
                    for cIdx = 1, #children do
                        local child = children[cIdx]
                        if child and child.SetAlpha then
                            ApplyBlockAndSiblingsAlpha(child, 1.0)
                        end
                    end
                end
            end
        end
    end
end

function QuestTracker:PrintQuestStatus()
    self:EvaluateQuestDistances(true)
    self:ApplyTrackerAlphas(1.0)
    local closeCount, nearbyCount, farCount = 0, 0, 0
    for qID, tier in pairs(self.questTierByID) do
        local title = self.questTitleByID[qID] or ("Quest #" .. tostring(qID))
        local reason = self.questReasonByID[qID] or "?"
        if tier == self.TIERS.CLOSE then
            closeCount = closeCount + 1
            ns.Print(string.format("  |cff44ff44[CLOSE - 100%% Solid]|r %s (%s)", title, reason))
        elseif tier == self.TIERS.NEARBY then
            nearbyCount = nearbyCount + 1
            ns.Print(string.format("  |cffffd100[NEARBY - Faded 35%%]|r %s (%s)", title, reason))
        else
            farCount = farCount + 1
            ns.Print(string.format("  |cff888888[FAR - Quest Book Only]|r %s (%s)", title, reason))
        end
    end
    ns.Print(string.format(
        "Quest Proximity Summary: %d Close (100%% opaque), %d Nearby (faded), %d Far (Quest Book only).",
        closeCount, nearbyCount, farCount
    ))
end

function QuestTracker:OnEnable()
    ns.Events:Register("PLAYER_ENTERING_WORLD", function()
        self:EvaluateQuestDistances(true)
        self:ApplyTrackerAlphas(1.0)
    end, self)

    ns.Events:Register("QUEST_LOG_UPDATE", function()
        self:EvaluateQuestDistances(false)
        self:ApplyTrackerAlphas(0.2)
    end, self)

    ns.Events:Register("QUEST_WATCH_LIST_CHANGED", function()
        if not self.isUpdatingWatches then
            self:EvaluateQuestDistances(false)
            self:ApplyTrackerAlphas(0.2)
        end
    end, self)

    ns.Events:Register("QUEST_ACCEPTED", function()
        self:EvaluateQuestDistances(true)
        self:ApplyTrackerAlphas(0.2)
    end, self)

    ns.Events:Register("QUEST_REMOVED", function()
        self:EvaluateQuestDistances(false)
        self:ApplyTrackerAlphas(0.2)
    end, self)

    ns.Events:Register("ZONE_CHANGED", function()
        self:EvaluateQuestDistances(true)
        self:ApplyTrackerAlphas(0.2)
    end, self)

    ns.Events:Register("ZONE_CHANGED_INDOORS", function()
        self:EvaluateQuestDistances(true)
        self:ApplyTrackerAlphas(0.2)
    end, self)

    ns.Events:Register("ZONE_CHANGED_NEW_AREA", function()
        self:EvaluateQuestDistances(true)
        self:ApplyTrackerAlphas(0.2)
    end, self)

    ns.Events:Register("PLAYER_TARGET_CHANGED", function()
        self:EvaluateQuestDistances(false)
        self:ApplyTrackerAlphas(0.5)
    end, self)

    ns.Events:Register("NAME_PLATE_UNIT_ADDED", function()
        self:EvaluateQuestDistances(false)
        self:ApplyTrackerAlphas(0.5)
    end, self)

    ns.Events:Register("PLAYER_REGEN_ENABLED", function()
        if self.pendingWatchSync then
            self.pendingWatchSync = false
            self:EvaluateQuestDistances(true)
        end
    end, self)

    ns.Events:RegisterTicker("QuestTrackerUpdate", function(dt)
        local cfg = ns.Config:Get("questTracker")
        if not cfg or cfg.enabled == false then
            return true
        end

        self.alphaAccum = (self.alphaAccum or 0) + dt
        self.scanAccum = (self.scanAccum or 0) + dt

        if self.alphaAccum >= 0.08 then
            local stepDt = self.alphaAccum
            self.alphaAccum = 0

            local overTracker = self:IsMouseOverTracker()
            if overTracker then
                self.unhoverTimer = 0.18
                self.isMouseHovered = true
            elseif self.isMouseHovered then
                self.unhoverTimer = (self.unhoverTimer or 0) - stepDt
                if self.unhoverTimer <= 0 then
                    self.isMouseHovered = false
                    self.unhoverTimer = 0
                end
            end

            if self.scanAccum >= 0.40 then
                self.scanAccum = 0
                self:EvaluateQuestDistances(false)
            end

            self:ApplyTrackerAlphas(stepDt)
        end

        return true
    end)

    self:EvaluateQuestDistances(true)
    self:ApplyTrackerAlphas(1.0)
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
    QuestTracker:OnEnable()
end
