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

-- ============================================================================
-- ELEMENTAL COMBAT PROFILES & SPELL CLASSIFIER
-- ============================================================================
ns.Elements = {
    ORDER = { "LIGHTNING", "FIRE", "EARTH", "FROST", "SHADOW", "PHYSICAL" },
    PROFILES = {
        PHYSICAL = {
            key = "PHYSICAL",
            label = "PHYSICAL",
            demoSpell = "MORTAL STRIKE",
            flash = { 1.00, 0.95, 0.85 },
            cut = { 1.00, 0.95, 0.80 },
            trailHold = { 1.00, 0.90, 0.55 },
            trailFade = { 1.00, 0.32, 0.08 },
            border = { 1.00, 0.82, 0.38 },
            spark = { 1.00, 0.72, 0.18 },
            sparkAlt = { 0.98, 0.96, 0.92 },
            text = { 1.00, 1.00, 1.00 },
            critText = { 1.00, 0.82, 0.00 },
            punchNormal = 1.24,
            punchCrit = 1.48,
            punchMega = 1.65,
            trailHoldNormal = 0.24,
            trailHoldCrit = 0.38,
            glowDuration = 0.16,
            deathFill = { 0.32, 0.33, 0.38 },
            deathTrim = { 0.78, 0.74, 0.66 },
            deathCrack = { 1.00, 0.94, 0.78 },
            deathDark = { 0.03, 0.03, 0.04 },
            deathFlash = { 1.00, 0.95, 0.82 },
            deathShard = { 0.88, 0.84, 0.76 },
            deathStyle = "Clean Cleave & Buckle Snap",
        },
        LIGHTNING = {
            key = "LIGHTNING",
            label = "LIGHTNING",
            demoSpell = "LIGHTNING BOLT",
            flash = { 0.38, 0.88, 1.00 },
            cut = { 0.85, 0.98, 1.00 },
            trailHold = { 0.58, 0.94, 1.00 },
            trailFade = { 0.12, 0.52, 1.00 },
            border = { 0.25, 0.84, 1.00 },
            spark = { 0.22, 0.82, 1.00 },
            sparkAlt = { 0.88, 0.98, 1.00 },
            text = { 0.32, 0.88, 1.00 },
            critText = { 0.52, 0.95, 1.00 },
            punchNormal = 1.34,
            punchCrit = 1.56,
            punchMega = 1.74,
            trailHoldNormal = 0.22,
            trailHoldCrit = 0.36,
            glowDuration = 0.34,
            deathFill = { 0.12, 0.24, 0.42 },
            deathTrim = { 0.36, 0.86, 1.00 },
            deathCrack = { 0.78, 0.98, 1.00 },
            deathDark = { 0.02, 0.06, 0.16 },
            deathFlash = { 0.62, 0.96, 1.00 },
            deathShard = { 0.38, 0.90, 1.00 },
            deathStyle = "High-Voltage Overload & Magnetic Rip",
        },
        FIRE = {
            key = "FIRE",
            label = "FIRE",
            demoSpell = "FLAME SHOCK",
            flash = { 1.00, 0.26, 0.03 },
            cut = { 1.00, 0.85, 0.22 },
            trailHold = { 1.00, 0.48, 0.05 },
            trailFade = { 0.88, 0.10, 0.01 },
            border = { 1.00, 0.28, 0.02 },
            spark = { 1.00, 0.34, 0.03 },
            sparkAlt = { 1.00, 0.88, 0.18 },
            text = { 1.00, 0.38, 0.08 },
            critText = { 1.00, 0.52, 0.10 },
            punchNormal = 1.12,
            punchCrit = 1.24,
            punchMega = 1.36,
            trailHoldNormal = 0.34,
            trailHoldCrit = 0.50,
            glowDuration = 0.82,
            deathFill = { 0.24, 0.06, 0.02 },
            deathTrim = { 1.00, 0.38, 0.04 },
            deathCrack = { 1.00, 0.82, 0.18 },
            deathDark = { 0.06, 0.01, 0.00 },
            deathFlash = { 1.00, 0.48, 0.06 },
            deathShard = { 1.00, 0.38, 0.04 },
            deathStyle = "Molten Detonation & Ash Burn-Away",
        },
        EARTH = {
            key = "EARTH",
            label = "EARTH",
            demoSpell = "EARTH SHOCK",
            flash = { 0.64, 0.48, 0.28 },
            cut = { 0.86, 0.72, 0.46 },
            trailHold = { 0.72, 0.56, 0.34 },
            trailFade = { 0.38, 0.26, 0.14 },
            border = { 0.54, 0.38, 0.20 },
            spark = { 0.44, 0.30, 0.15 },
            sparkAlt = { 0.78, 0.64, 0.40 },
            text = { 0.82, 0.66, 0.40 },
            critText = { 0.92, 0.76, 0.48 },
            punchNormal = 1.64,
            punchCrit = 1.92,
            punchMega = 2.15,
            trailHoldNormal = 0.28,
            trailHoldCrit = 0.42,
            glowDuration = 0.44,
            deathFill = { 0.30, 0.21, 0.12 },
            deathTrim = { 0.68, 0.52, 0.30 },
            deathCrack = { 0.95, 0.80, 0.52 },
            deathDark = { 0.06, 0.04, 0.02 },
            deathFlash = { 0.85, 0.68, 0.42 },
            deathShard = { 0.56, 0.40, 0.22 },
            deathStyle = "Tectonic Crush & Avalanche Collapse",
        },
        FROST = {
            key = "FROST",
            label = "FROST",
            demoSpell = "FROST SHOCK",
            flash = { 0.42, 0.88, 1.00 },
            cut = { 0.90, 0.98, 1.00 },
            trailHold = { 0.74, 0.95, 1.00 },
            trailFade = { 0.22, 0.68, 0.98 },
            border = { 0.48, 0.90, 1.00 },
            spark = { 0.46, 0.90, 1.00 },
            sparkAlt = { 0.92, 0.98, 1.00 },
            text = { 0.45, 0.86, 1.00 },
            critText = { 0.68, 0.95, 1.00 },
            punchNormal = 1.26,
            punchCrit = 1.50,
            punchMega = 1.66,
            trailHoldNormal = 0.48,
            trailHoldCrit = 0.66,
            glowDuration = 0.68,
            deathFill = { 0.18, 0.38, 0.56 },
            deathTrim = { 0.64, 0.94, 1.00 },
            deathCrack = { 0.92, 0.99, 1.00 },
            deathDark = { 0.03, 0.10, 0.18 },
            deathFlash = { 0.78, 0.97, 1.00 },
            deathShard = { 0.68, 0.95, 1.00 },
            deathStyle = "Flash-Freeze & Crystalline Glass Shatter",
        },
        SHADOW = {
            key = "SHADOW",
            label = "SHADOW",
            demoSpell = "SHADOW BOLT",
            flash = { 0.68, 0.25, 1.00 },
            cut = { 0.92, 0.55, 1.00 },
            trailHold = { 0.76, 0.35, 1.00 },
            trailFade = { 0.38, 0.08, 0.68 },
            border = { 0.72, 0.28, 1.00 },
            spark = { 0.72, 0.28, 1.00 },
            sparkAlt = { 0.92, 0.58, 1.00 },
            text = { 0.76, 0.44, 1.00 },
            critText = { 0.88, 0.58, 1.00 },
            punchNormal = 1.28,
            punchCrit = 1.52,
            punchMega = 1.70,
            trailHoldNormal = 0.32,
            trailHoldCrit = 0.48,
            glowDuration = 0.58,
            deathFill = { 0.18, 0.07, 0.28 },
            deathTrim = { 0.74, 0.30, 1.00 },
            deathCrack = { 0.94, 0.58, 1.00 },
            deathDark = { 0.04, 0.01, 0.08 },
            deathFlash = { 0.82, 0.36, 1.00 },
            deathShard = { 0.74, 0.30, 0.98 },
            deathStyle = "Void Rift Pop & Singularity Implosion",
        },
    },
    lastPlayerElement = nil,
    lastPlayerElementTime = 0,
    lastPlayerDotElement = nil,
    lastPlayerDotDuration = 0,
    lastPlayerDotTime = 0,
    lastPlayerInterruptTime = 0,
    lastCastStartTime = 0,
    pendingDirectHitTime = 0,
    pendingDirectHitWeight = 0,
}

local INTERRUPT_KEYWORDS = {
    "earth shock", "wind shear", "kick", "pummel", "shield bash", "counterspell",
    "rebuke", "silence", "mind freeze", "skull bash", "solar beam", "quell",
    "muzzle", "counter shot", "silencing shot", "spear hand", "disrupt",
    "spell lock", "optical blast", "axe toss", "avenger's shield", "strangulate",
    "arcane torrent", "war stomp", "quaking palm", "haymaker", "bull rush",
    "hammer of justice", "fist of justice", "repentance", "blinding light",
    "cheap shot", "kidney shot", "gouge", "blind", "sap", "between the eyes",
    "concussion blow", "shockwave", "storm bolt", "intimidating shout", "charge", "intercept",
    "bash", "mighty bash", "maim", "cyclone", "typhoon", "incapacitating roar", "feral charge",
    "psychic scream", "psychic horror", "mind bomb", "chastise",
    "death coil", "mortal coil", "shadowfury", "fear", "howl of terror", "banish",
    "scatter shot", "wyvern sting", "intimidation", "freezing trap",
    "asphyxiate", "gnaw", "death grip", "blinding sleet",
    "leg sweep", "paralysis", "ring of peace",
    "chaos nova", "fel eruption", "imprison", "sigil of silence", "sigil of misery",
    "dragon's breath", "polymorph", "supernova", "ring of frost",
    "hex", "sundering", "capacitor", "grounding", "tail swipe", "wing buffet",
}

function ns.Elements:ClassifyInterruptSpell(spellName)
    if not spellName or ns.IsSecret(spellName) or type(spellName) ~= "string" then
        return false
    end
    local lower = string.lower(spellName)
    for i = 1, #INTERRUPT_KEYWORDS do
        if string.find(lower, INTERRUPT_KEYWORDS[i], 1, true) then
            return true
        end
    end
    return false
end

function ns.Elements:HasRecentPlayerInterrupt()
    local now = GetTime and GetTime() or 0
    return (now - (self.lastPlayerInterruptTime or 0)) <= 1.6
end

local DOT_SPELL_PATTERNS = {
    -- FIRE DoTs
    { pattern = "flame shock", elem = "FIRE", dur = 12.0 },
    { pattern = "immolate", elem = "FIRE", dur = 15.0 },
    { pattern = "fireball", elem = "FIRE", dur = 8.0 },
    { pattern = "pyroblast", elem = "FIRE", dur = 12.0 },
    { pattern = "living bomb", elem = "FIRE", dur = 12.0 },
    { pattern = "ignite", elem = "FIRE", dur = 4.0 },
    { pattern = "combustion", elem = "FIRE", dur = 10.0 },
    { pattern = "flamestrike", elem = "FIRE", dur = 8.0 },
    { pattern = "conflagrate", elem = "FIRE", dur = 6.0 },
    { pattern = "holy fire", elem = "FIRE", dur = 10.0 },
    { pattern = "sunfire", elem = "FIRE", dur = 12.0 },
    -- SHADOW DoTs
    { pattern = "corruption", elem = "SHADOW", dur = 18.0 },
    { pattern = "shadow word: pain", elem = "SHADOW", dur = 18.0 },
    { pattern = "agony", elem = "SHADOW", dur = 24.0 },
    { pattern = "curse of doom", elem = "SHADOW", dur = 60.0 },
    { pattern = "vampiric touch", elem = "SHADOW", dur = 15.0 },
    { pattern = "devouring plague", elem = "SHADOW", dur = 24.0 },
    { pattern = "siphon life", elem = "SHADOW", dur = 30.0 },
    { pattern = "unstable affliction", elem = "SHADOW", dur = 15.0 },
    { pattern = "drain soul", elem = "SHADOW", dur = 12.0 },
    { pattern = "mind flay", elem = "SHADOW", dur = 3.0 },
    -- FROST DoTs / Chills
    { pattern = "frost shock", elem = "FROST", dur = 8.0 },
    { pattern = "frost fever", elem = "FROST", dur = 15.0 },
    { pattern = "frostbolt", elem = "FROST", dur = 8.0 },
    { pattern = "chains of ice", elem = "FROST", dur = 8.0 },
    { pattern = "cone of cold", elem = "FROST", dur = 8.0 },
    -- LIGHTNING / ARCANE DoTs
    { pattern = "moonfire", elem = "LIGHTNING", dur = 12.0 },
    { pattern = "stormstrike", elem = "LIGHTNING", dur = 12.0 },
    { pattern = "thunder clap", elem = "LIGHTNING", dur = 10.0 },
    { pattern = "thunderclap", elem = "LIGHTNING", dur = 10.0 },
    { pattern = "electrocute", elem = "LIGHTNING", dur = 8.0 },
    { pattern = "static", elem = "LIGHTNING", dur = 8.0 },
    -- EARTH / NATURE DoTs
    { pattern = "serpent sting", elem = "EARTH", dur = 15.0 },
    { pattern = "insect swarm", elem = "EARTH", dur = 12.0 },
    { pattern = "earthbind", elem = "EARTH", dur = 6.0 },
    { pattern = "earthquake", elem = "EARTH", dur = 8.0 },
    { pattern = "deadly poison", elem = "EARTH", dur = 12.0 },
    -- PHYSICAL Bleeds
    { pattern = "rend", elem = "PHYSICAL", dur = 15.0 },
    { pattern = "deep wounds", elem = "PHYSICAL", dur = 12.0 },
    { pattern = "garrote", elem = "PHYSICAL", dur = 18.0 },
    { pattern = "rupture", elem = "PHYSICAL", dur = 12.0 },
    { pattern = "rake", elem = "PHYSICAL", dur = 9.0 },
    { pattern = "rip", elem = "PHYSICAL", dur = 12.0 },
    { pattern = "lacerate", elem = "PHYSICAL", dur = 15.0 },
}

function ns.Elements:ClassifyDotSpell(spellName)
    if not spellName or ns.IsSecret(spellName) or type(spellName) ~= "string" then
        return nil, nil
    end
    local lower = string.lower(spellName)
    for i = 1, #DOT_SPELL_PATTERNS do
        local entry = DOT_SPELL_PATTERNS[i]
        if string.find(lower, entry.pattern, 1, true) then
            return entry.elem, entry.dur
        end
    end
    return nil, nil
end

local LIGHTNING_KEYWORDS = {
    "lightning", "thunder", "stormstrike", "storm", "overload", "static", "electr", "arc ", "chain lightning", "shock",
}
local EARTH_KEYWORDS = {
    "earth", "rock", "stone", "quake", "boulder", "seismic", "tremor", "landslide", "shatter", "stomp", "maul", "slam",
}
local FIRE_KEYWORDS = {
    "fire", "flame", "lava", "pyro", "scorch", "immolat", "conflag", "incinerat", "magma", "searing", "combust", "hellfire", "meteor", "inferno", "molten", "burn", "ember",
}
local FROST_KEYWORDS = {
    "frost", "ice", "icy", "blizzard", "cold", "freez", "frozen", "glacial", "chill", "hail", "snow",
}
local SHADOW_KEYWORDS = {
    "shadow", "void", "dark", "corruption", "agony", "pain", "mind ", "vampiric", "death coil", "drain", "haunt", "plague", "curse", "doom", "unholy", "necrotic",
}

function ns.Elements:GetProfile(elementKey)
    if elementKey and not ns.IsSecret(elementKey) then
        local upper = string.upper(tostring(elementKey))
        if self.PROFILES[upper] then
            return self.PROFILES[upper]
        end
    end
    return self.PROFILES.PHYSICAL
end

function ns.Elements:ClassifyBySpellName(spellName)
    if not spellName or ns.IsSecret(spellName) or type(spellName) ~= "string" then
        return nil
    end
    local lower = string.lower(spellName)
    -- Check specific elemental shocks first before generic "shock"
    for i = 1, #FIRE_KEYWORDS do
        if string.find(lower, FIRE_KEYWORDS[i], 1, true) then
            return "FIRE"
        end
    end
    for i = 1, #FROST_KEYWORDS do
        if string.find(lower, FROST_KEYWORDS[i], 1, true) then
            return "FROST"
        end
    end
    for i = 1, #EARTH_KEYWORDS do
        if string.find(lower, EARTH_KEYWORDS[i], 1, true) then
            return "EARTH"
        end
    end
    for i = 1, #SHADOW_KEYWORDS do
        if string.find(lower, SHADOW_KEYWORDS[i], 1, true) then
            return "SHADOW"
        end
    end
    for i = 1, #LIGHTNING_KEYWORDS do
        if string.find(lower, LIGHTNING_KEYWORDS[i], 1, true) then
            return "LIGHTNING"
        end
    end
    return nil
end

function ns.Elements:RecordPlayerCastStart(spellID, spellName)
    local now = GetTime and GetTime() or 0
    self.lastCastStartTime = now
    self:RecordPlayerSpell(spellID, spellName, true)
end

function ns.Elements:RecordPlayerSpell(spellID, spellName, isCastStart)
    if not spellName and spellID and not ns.IsSecret(spellID) then
        if C_Spell and C_Spell.GetSpellName then
            local ok, res = pcall(C_Spell.GetSpellName, spellID)
            if ok then
                spellName = res
            end
        elseif GetSpellInfo then
            local ok, res = pcall(GetSpellInfo, spellID)
            if ok then
                spellName = res
            end
        end
    end
    local now = GetTime and GetTime() or 0
    local elem = self:ClassifyBySpellName(spellName)
    if elem then
        self.lastPlayerElement = elem
        self.lastPlayerElementTime = now
    end
    local dotElem, dotDur = self:ClassifyDotSpell(spellName)
    if dotElem and not isCastStart then
        self.lastPlayerDotElement = dotElem
        self.lastPlayerDotDuration = dotDur or 8.0
        self.lastPlayerDotTime = now
    end
    if not isCastStart and self:ClassifyInterruptSpell(spellName) then
        self.lastPlayerInterruptTime = now
    end
    if not isCastStart then
        local wasHardCast = (now - (self.lastCastStartTime or 0)) <= 4.2
        self.pendingDirectHitTime = now
        self.pendingDirectHitWeight = wasHardCast and 0.92 or 0.80
    end
    return elem, dotElem, dotDur
end

function ns.Elements:ConsumePendingDirectHit()
    local now = GetTime and GetTime() or 0
    if (now - (self.pendingDirectHitTime or 0)) <= 1.25 then
        local w = self.pendingDirectHitWeight or 0.82
        self.pendingDirectHitTime = 0
        return true, w
    end
    return false, 0
end

function ns.Elements:ResolveElement(schoolMask, spellName, isAutoAttack)
    if isAutoAttack then
        return "PHYSICAL"
    end
    local byName = self:ClassifyBySpellName(spellName)
    if byName then
        return byName
    end

    local now = GetTime and GetTime() or 0
    local recentCast = (self.lastPlayerElement and (now - (self.lastPlayerElementTime or 0)) <= 2.4)
        and self.lastPlayerElement or nil

    if schoolMask and not ns.IsSecret(schoolMask) and type(schoolMask) == "number" then
        if bit and bit.band then
            if bit.band(schoolMask, 4) ~= 0 then
                return "FIRE"
            elseif bit.band(schoolMask, 16) ~= 0 then
                return "FROST"
            elseif bit.band(schoolMask, 32) ~= 0 then
                return "SHADOW"
            elseif bit.band(schoolMask, 8) ~= 0 then
                -- Nature school (8): distinguish Earth Shock vs Lightning Bolt via recent cast!
                if recentCast == "EARTH" or recentCast == "LIGHTNING" then
                    return recentCast
                end
                return "LIGHTNING"
            elseif bit.band(schoolMask, 64) ~= 0 then
                return "LIGHTNING"
            elseif bit.band(schoolMask, 2) ~= 0 then
                return "FIRE"
            end
        else
            if schoolMask == 4 then
                return "FIRE"
            elseif schoolMask == 16 then
                return "FROST"
            elseif schoolMask == 32 then
                return "SHADOW"
            elseif schoolMask == 8 or schoolMask == 64 then
                if recentCast == "EARTH" or recentCast == "LIGHTNING" then
                    return recentCast
                end
                return "LIGHTNING"
            end
        end
    end

    if recentCast then
        return recentCast
    end
    return "PHYSICAL"
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
        anchorToWound = true,
        elementalPhysics = true,
        killFinisher = true,
        baseOffsetY = 24,
        critOffsetY = 34,
        dotFontSize = 16,
        normalFontSize = 21,
        critFontSize = 30,
        megaFontSize = 35,
        killFontSize = 38,
        durationDot = 0.88,
        durationNormal = 1.20,
        durationCrit = 1.55,
        durationKill = 1.95,
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
    questTracker = {
        enabled = true,
        closeDistanceYards = 180,
        nearbyDistanceYards = 600,
        alphaClose = 1.0,
        alphaNearby = 0.35,
        autoManageWatches = true,
        autoSuperTrackClose = true,
    },
    castbars = {
        enabled = true,
        player = true,
        target = true,
        showLatency = true,
        pushbackRecoil = true,
        recoilShake = true,
        leadSpark = true,
        width = 220,
        height = 18,
    },
    minimap = {
        hide = false,
        angle = 225,
        radius = 80,
    },
    activePreset = "DEFAULT",
}

ns.Config.PRESETS = {
    DEFAULT = {
        name = "High-Impact (Signature)",
        desc = "Visceral kinetic feedback: heavy bar trauma recoil, violent punch scale, delayed amber trail bars, -11.5 deg death bar tilt, and dynamic fountain arcs.",
        values = {
            unitBars = {
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
                deathTiltDegrees = -11.5,
                deathHoldTime = 0.85,
                deathFadeTime = 0.45,
                deathShatterEnabled = true,
                hideNameAndLevelOnDeath = true,
                deflectCallouts = true,
                interruptShatter = true,
            },
            combatFX = {
                sparksEnabled = true,
                lowHpVignette = true,
                lowHpThreshold = 0.30,
            },
            combatText = {
                fountainLanes = true,
                critShockwave = true,
                flurryEscalation = true,
                flurryWindow = 1.45,
                normalFontSize = 21,
                critFontSize = 30,
                megaFontSize = 35,
                killFontSize = 38,
            },
            stateEngine = {
                alphaCombat = 1.0,
                alphaExploring = 0.35,
                alphaTravelling = 0.25,
                alphaResting = 0.20,
                alphaHarvesting = 0.30,
            },
        },
    },
    BRUTAL = {
        name = "Brutal (Heavy Metal)",
        desc = "Exaggerated combat violence: massive scale punches (up to 1.90x), amplified trauma recoil (1.6x), steep death tilt (-16 deg), longer lingering trails, and large numbers.",
        values = {
            unitBars = {
                smoothSpeed = 16.0,
                trailSpeed = 4.0,
                trailHoldNormal = 0.35,
                trailHoldCrit = 0.55,
                traumaScale = 1.6,
                critTraumaMultiplier = 2.0,
                barPunchNormal = 1.28,
                barPunchCrit = 1.65,
                barPunchMega = 1.90,
                executeThreshold = 0.25,
            },
            nameplates = {
                deathTiltDegrees = -16.0,
                deathHoldTime = 1.10,
                deathFadeTime = 0.50,
                deathShatterEnabled = true,
                hideNameAndLevelOnDeath = true,
                deflectCallouts = true,
                interruptShatter = true,
            },
            combatFX = {
                sparksEnabled = true,
                lowHpVignette = true,
                lowHpThreshold = 0.35,
            },
            combatText = {
                fountainLanes = true,
                critShockwave = true,
                flurryEscalation = true,
                flurryWindow = 1.80,
                normalFontSize = 23,
                critFontSize = 34,
                megaFontSize = 42,
                killFontSize = 48,
            },
            stateEngine = {
                alphaCombat = 1.0,
                alphaExploring = 0.40,
                alphaTravelling = 0.25,
                alphaResting = 0.15,
                alphaHarvesting = 0.30,
            },
        },
    },
    CLEAN = {
        name = "Minimal (Clean Esports)",
        desc = "Tournament clarity: zero tilt (0 deg), snappy rapid trails, subdued bar recoil (0.25x), compact font sizes, and minimal clutter for competitive gameplay.",
        values = {
            unitBars = {
                smoothSpeed = 24.0,
                trailSpeed = 9.0,
                trailHoldNormal = 0.12,
                trailHoldCrit = 0.20,
                traumaScale = 0.25,
                critTraumaMultiplier = 1.25,
                barPunchNormal = 1.05,
                barPunchCrit = 1.12,
                barPunchMega = 1.20,
                executeThreshold = 0.20,
            },
            nameplates = {
                deathTiltDegrees = 0.0,
                deathHoldTime = 0.40,
                deathFadeTime = 0.25,
                deathShatterEnabled = false,
                hideNameAndLevelOnDeath = false,
                deflectCallouts = true,
                interruptShatter = true,
            },
            combatFX = {
                sparksEnabled = false,
                lowHpVignette = false,
                lowHpThreshold = 0.25,
            },
            combatText = {
                fountainLanes = true,
                critShockwave = false,
                flurryEscalation = false,
                flurryWindow = 1.00,
                normalFontSize = 18,
                critFontSize = 24,
                megaFontSize = 28,
                killFontSize = 32,
            },
            stateEngine = {
                alphaCombat = 1.0,
                alphaExploring = 0.60,
                alphaTravelling = 0.50,
                alphaResting = 0.40,
                alphaHarvesting = 0.50,
            },
        },
    },
    ARCADE = {
        name = "Arcade (Bouncy Pop)",
        desc = "Snappy arcade feel: bouncy scale pops, wider flurry escalation window, exaggerated fountain arcs, bright crits, and lively responsive numbers.",
        values = {
            unitBars = {
                smoothSpeed = 20.0,
                trailSpeed = 7.0,
                trailHoldNormal = 0.18,
                trailHoldCrit = 0.30,
                traumaScale = 0.85,
                critTraumaMultiplier = 1.60,
                barPunchNormal = 1.24,
                barPunchCrit = 1.55,
                barPunchMega = 1.75,
                executeThreshold = 0.20,
            },
            nameplates = {
                deathTiltDegrees = -8.0,
                deathHoldTime = 0.70,
                deathFadeTime = 0.35,
                deathShatterEnabled = true,
                hideNameAndLevelOnDeath = true,
                deflectCallouts = true,
                interruptShatter = true,
            },
            combatFX = {
                sparksEnabled = true,
                lowHpVignette = true,
                lowHpThreshold = 0.30,
            },
            combatText = {
                fountainLanes = true,
                critShockwave = true,
                flurryEscalation = true,
                flurryWindow = 2.00,
                normalFontSize = 22,
                critFontSize = 32,
                megaFontSize = 38,
                killFontSize = 42,
            },
            stateEngine = {
                alphaCombat = 1.0,
                alphaExploring = 0.40,
                alphaTravelling = 0.30,
                alphaResting = 0.25,
                alphaHarvesting = 0.35,
            },
        },
    },
    CINEMATIC = {
        name = "Cinematic (Immersive)",
        desc = "Atmospheric RPG immersion: lingering damage trails, smooth gentle trauma recoil, slow death fade, deep out-of-combat HUD fade, and dramatic killing blow pauses.",
        values = {
            unitBars = {
                smoothSpeed = 14.0,
                trailSpeed = 3.5,
                trailHoldNormal = 0.40,
                trailHoldCrit = 0.65,
                traumaScale = 0.60,
                critTraumaMultiplier = 1.40,
                barPunchNormal = 1.12,
                barPunchCrit = 1.35,
                barPunchMega = 1.50,
                executeThreshold = 0.20,
            },
            nameplates = {
                deathTiltDegrees = -6.5,
                deathHoldTime = 1.40,
                deathFadeTime = 0.80,
                deathShatterEnabled = true,
                hideNameAndLevelOnDeath = true,
                deflectCallouts = true,
                interruptShatter = true,
            },
            combatFX = {
                sparksEnabled = true,
                lowHpVignette = true,
                lowHpThreshold = 0.25,
            },
            combatText = {
                fountainLanes = true,
                critShockwave = true,
                flurryEscalation = true,
                flurryWindow = 1.50,
                normalFontSize = 19,
                critFontSize = 28,
                megaFontSize = 32,
                killFontSize = 36,
            },
            stateEngine = {
                alphaCombat = 1.0,
                alphaExploring = 0.20,
                alphaTravelling = 0.15,
                alphaResting = 0.10,
                alphaHarvesting = 0.20,
            },
        },
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
        if type(ForeverUIDB.questTracker) == "table" and (ForeverUIDB.questTracker.closeDistanceYards or 0) < 180 then
            ForeverUIDB.questTracker.closeDistanceYards = 180
            ForeverUIDB.questTracker.nearbyDistanceYards = 600
        end
        if type(ForeverUIDB.combatText) == "table" and (ForeverUIDB.combatText.normalFontSize or 0) < 21 then
            ForeverUIDB.combatText.dotFontSize = DEFAULTS.combatText.dotFontSize
            ForeverUIDB.combatText.normalFontSize = DEFAULTS.combatText.normalFontSize
            ForeverUIDB.combatText.critFontSize = DEFAULTS.combatText.critFontSize
            ForeverUIDB.combatText.megaFontSize = DEFAULTS.combatText.megaFontSize
            ForeverUIDB.combatText.killFontSize = DEFAULTS.combatText.killFontSize
            ForeverUIDB.combatText.durationKill = DEFAULTS.combatText.durationKill
        end
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

function ns.Config:Set(section, key, val)
    if not self.db then
        self:Initialize()
    end
    if not self.db[section] then
        self.db[section] = {}
    end
    self.db[section][key] = val
    self.db.activePreset = "CUSTOM"
end

function ns.Config:ApplyPreset(presetKey)
    local preset = ns.Config.PRESETS[presetKey]
    if not preset then
        return false
    end
    if not self.db then
        self:Initialize()
    end
    for secName, secValues in pairs(preset.values) do
        if type(self.db[secName]) == "table" then
            for k, v in pairs(secValues) do
                self.db[secName][k] = v
            end
        end
    end
    self.db.activePreset = presetKey
    return true
end
