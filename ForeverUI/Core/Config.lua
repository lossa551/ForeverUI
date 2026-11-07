local addonName, ns = ...
ns.Config = {}

-- WoW 12.0+ / Forever (16001) Secret Value Guard:
-- UnitHealth, UnitHealthMax, and UNIT_COMBAT amounts return opaque "secret number values"
-- that cannot be compared (<, >, ==) or used in Lua arithmetic (+, -, *, /),
-- but CAN be passed directly into C++ widgets (StatusBar:SetValue, StatusBar:SetMinMaxValues, FontString:SetText).
function ns.IsSecret(val)
    if issecretvalue then
        return issecretvalue(val)
    end
    return false
end

local DEFAULTS = {
    version = "1.0.0",
    unitBars = {
        enabled = true,
        smoothSpeed = 18.0,
        trailSpeed = 5.5,
        trailHoldNormal = 0.24,
        trailHoldCrit = 0.38,
        traumaScale = 1.0,
        critTraumaMultiplier = 1.75,
        barPunchNormal = 1.18,
        barPunchCrit = 1.48,
        barPunchMega = 1.65,
        executeThreshold = 0.20,
    },
    nameplates = {
        enabled = true,
        targetHighlight = true,
        deflectCallouts = true,
        interruptShatter = true,
        deathShatterEnabled = true,
        hideNameAndLevelOnDeath = true,
        deathTiltDegrees = -11.5,
        deathHoldTime = 0.85,
        deathFadeTime = 0.45,
    },
    combatFX = {
        enabled = true,
        sparksEnabled = true,
        lowHpVignette = true,
        lowHpThreshold = 0.30,
    },
    combatText = {
        enabled = true,
        hideVanillaDamage = true,
        anchorToNameplate = true,
        baseOffsetY = 26,
        critOffsetY = 34,
        normalFontSize = 17,
        critFontSize = 24,
        megaFontSize = 28,
        durationNormal = 1.15,
        durationCrit = 1.50,
        critShockwave = true,
        fountainLanes = true,
        flurryEscalation = true,
        flurryWindow = 1.45,
    },
    stateEngine = {
        enabled = true,
        fadeHUD = true,
        fadeUnitFrames = true,
        wakeOnTarget = true,
        wakeOnMouseover = true,
        alphaCombat = 1.0,
        alphaExploring = 0.35,
        alphaTravelling = 0.25,
        alphaResting = 0.20,
        alphaHarvesting = 0.30,
    },
}

local function DeepCopy(src)
    if type(src) ~= "table" then
        return src
    end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

local function MergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = DeepCopy(v)
            else
                MergeDefaults(target[k], v)
            end
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

function ns.Config:Initialize()
    if type(ForeverUIDB) ~= "table" then
        ForeverUIDB = DeepCopy(DEFAULTS)
    else
        -- Migrate pre-HUD-fade SavedVariables where fadeUnitFrames defaulted to false
        if type(ForeverUIDB.stateEngine) == "table" and ForeverUIDB.stateEngine.fadeHUD == nil then
            ForeverUIDB.stateEngine.fadeHUD = true
            ForeverUIDB.stateEngine.fadeUnitFrames = true
            ForeverUIDB.stateEngine.wakeOnTarget = true
            ForeverUIDB.stateEngine.alphaCombat = DEFAULTS.stateEngine.alphaCombat
            ForeverUIDB.stateEngine.alphaExploring = DEFAULTS.stateEngine.alphaExploring
            ForeverUIDB.stateEngine.alphaTravelling = DEFAULTS.stateEngine.alphaTravelling
            ForeverUIDB.stateEngine.alphaResting = DEFAULTS.stateEngine.alphaResting
            ForeverUIDB.stateEngine.alphaHarvesting = DEFAULTS.stateEngine.alphaHarvesting
        end
        MergeDefaults(ForeverUIDB, DEFAULTS)
    end
    self.db = ForeverUIDB
end

function ns.Config:Reset()
    ForeverUIDB = DeepCopy(DEFAULTS)
    self.db = ForeverUIDB
end

function ns.Config:Get(section, key)
    if not self.db then
        return DEFAULTS[section] and DEFAULTS[section][key]
    end
    if key == nil then
        return self.db[section]
    end
    return self.db[section] and self.db[section][key]
end
