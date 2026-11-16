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
    ORDER = { "LIGHTNING", "FIRE", "EARTH", "FROST", "SHADOW", "NATURE", "ARCANE", "HOLY", "PHYSICAL" },
    PROFILES = {
        PHYSICAL = {
            key = "PHYSICAL",
            label = "PHYSICAL",
            demoSpell = "MORTAL STRIKE",
            flash = { 1.00, 0.92, 0.68 },
            cut = { 1.00, 0.96, 0.80 },
            trailHot = { 1.00, 0.97, 0.88 },
            trailHold = { 1.00, 0.84, 0.40 },
            trailFade = { 0.78, 0.14, 0.10 },
            border = { 0.94, 0.78, 0.42 },
            spark = { 1.00, 0.82, 0.32 },
            sparkAlt = { 1.00, 0.96, 0.86 },
            sparkPalette = {
                { 1.00, 0.96, 0.84 }, -- White-hot steel glint
                { 1.00, 0.82, 0.30 }, -- Classic WoW physical gold
                { 0.98, 0.60, 0.16 }, -- Warm forged bronze spark
                { 0.92, 0.24, 0.16 }, -- Arterial crimson cleave ember
            },
            text = { 1.00, 1.00, 1.00 },
            critText = { 1.00, 0.82, 0.00 },
            glowDuration = 0.20,
            deathFill = { 0.28, 0.28, 0.30 },
            deathTrim = { 0.62, 0.58, 0.50 },
            deathCrackHot = { 1.00, 0.92, 0.64 },
            deathCrack = { 0.90, 0.86, 0.74 },
            deathDark = { 0.04, 0.04, 0.05 },
            deathFlash = { 0.94, 0.88, 0.74 },
            deathShard = { 0.68, 0.64, 0.56 },
            deathStyle = "Weathered Iron Crack",
        },
        LIGHTNING = {
            key = "LIGHTNING",
            label = "LIGHTNING",
            demoSpell = "LIGHTNING BOLT",
            flash = { 0.54, 0.92, 1.00 },
            cut = { 0.92, 0.99, 1.00 },
            trailHot = { 0.94, 0.99, 1.00 },
            trailHold = { 0.48, 0.90, 1.00 },
            trailFade = { 0.16, 0.48, 0.96 },
            border = { 0.34, 0.82, 1.00 },
            spark = { 0.40, 0.88, 1.00 },
            sparkAlt = { 0.94, 0.99, 1.00 },
            sparkPalette = {
                { 0.94, 0.99, 1.00 }, -- White-hot arc core
                { 0.38, 0.88, 1.00 }, -- Shaman lightning cyan
                { 0.18, 0.62, 1.00 }, -- Deep storm-cobalt arc
                { 0.68, 0.78, 1.00 }, -- Ionized blue-violet plasma
            },
            text = { 0.45, 0.88, 1.00 },
            critText = { 0.72, 0.95, 1.00 },
            glowDuration = 0.34,
            deathFill = { 0.22, 0.28, 0.36 },
            deathTrim = { 0.48, 0.68, 0.78 },
            deathCrackHot = { 0.42, 0.92, 1.00 },
            deathCrack = { 0.80, 0.92, 0.98 },
            deathDark = { 0.04, 0.06, 0.10 },
            deathFlash = { 0.72, 0.90, 0.98 },
            deathShard = { 0.52, 0.72, 0.82 },
            deathStyle = "Storm-Slate Crack",
        },
        FIRE = {
            key = "FIRE",
            label = "FIRE",
            demoSpell = "FLAME SHOCK",
            flash = { 1.00, 0.56, 0.14 },
            cut = { 1.00, 0.92, 0.42 },
            trailHot = { 1.00, 0.96, 0.68 },
            trailHold = { 1.00, 0.56, 0.10 },
            trailFade = { 0.82, 0.14, 0.03 },
            border = { 1.00, 0.44, 0.08 },
            spark = { 1.00, 0.54, 0.08 },
            sparkAlt = { 1.00, 0.92, 0.38 },
            sparkPalette = {
                { 1.00, 0.96, 0.62 }, -- White-gold ignition core
                { 1.00, 0.74, 0.16 }, -- Solar amber flame
                { 1.00, 0.44, 0.06 }, -- Classic WoW Fire spell orange
                { 0.92, 0.18, 0.04 }, -- Deep smoldering lava crimson
            },
            text = { 1.00, 0.50, 0.04 },
            critText = { 1.00, 0.66, 0.18 },
            glowDuration = 0.72,
            deathFill = { 0.26, 0.18, 0.14 },
            deathTrim = { 0.72, 0.44, 0.26 },
            deathCrackHot = { 1.00, 0.58, 0.12 },
            deathCrack = { 0.95, 0.72, 0.36 },
            deathDark = { 0.06, 0.03, 0.02 },
            deathFlash = { 0.96, 0.62, 0.26 },
            deathShard = { 0.74, 0.44, 0.24 },
            deathStyle = "Charred Ash Crack",
        },
        EARTH = {
            key = "EARTH",
            label = "EARTH",
            demoSpell = "EARTH SHOCK",
            flash = { 0.76, 0.60, 0.36 },
            cut = { 0.92, 0.78, 0.50 },
            trailHot = { 0.95, 0.86, 0.62 },
            trailHold = { 0.76, 0.60, 0.36 },
            trailFade = { 0.38, 0.25, 0.14 },
            border = { 0.62, 0.46, 0.26 },
            spark = { 0.66, 0.50, 0.28 },
            sparkAlt = { 0.88, 0.74, 0.48 },
            sparkPalette = {
                { 0.94, 0.82, 0.56 }, -- Sunlit quartz/sandstone glint
                { 0.78, 0.62, 0.36 }, -- Warm ochre shale
                { 0.58, 0.42, 0.22 }, -- Weathered sienna boulder
                { 0.42, 0.30, 0.16 }, -- Deep tectonic umber
            },
            text = { 0.86, 0.72, 0.44 },
            critText = { 0.96, 0.82, 0.54 },
            glowDuration = 0.42,
            deathFill = { 0.28, 0.23, 0.17 },
            deathTrim = { 0.60, 0.50, 0.36 },
            deathCrackHot = { 0.96, 0.78, 0.42 },
            deathCrack = { 0.86, 0.76, 0.56 },
            deathDark = { 0.05, 0.04, 0.03 },
            deathFlash = { 0.80, 0.68, 0.48 },
            deathShard = { 0.56, 0.46, 0.32 },
            deathStyle = "Tectonic Slate Crack",
        },
        FROST = {
            key = "FROST",
            label = "FROST",
            demoSpell = "FROST SHOCK",
            flash = { 0.64, 0.92, 1.00 },
            cut = { 0.94, 0.99, 1.00 },
            trailHot = { 0.95, 0.99, 1.00 },
            trailHold = { 0.64, 0.90, 1.00 },
            trailFade = { 0.20, 0.50, 0.92 },
            border = { 0.48, 0.84, 1.00 },
            spark = { 0.54, 0.88, 1.00 },
            sparkAlt = { 0.94, 0.99, 1.00 },
            sparkPalette = {
                { 0.95, 0.99, 1.00 }, -- Diamond rime glint
                { 0.62, 0.92, 1.00 }, -- Crystalline frost cyan
                { 0.34, 0.76, 1.00 }, -- Glacial ice azure
                { 0.22, 0.54, 0.94 }, -- Deep winter sapphire
            },
            text = { 0.50, 0.84, 1.00 },
            critText = { 0.72, 0.94, 1.00 },
            glowDuration = 0.60,
            deathFill = { 0.22, 0.30, 0.38 },
            deathTrim = { 0.56, 0.74, 0.84 },
            deathCrackHot = { 0.68, 0.95, 1.00 },
            deathCrack = { 0.88, 0.95, 0.98 },
            deathDark = { 0.04, 0.07, 0.10 },
            deathFlash = { 0.76, 0.90, 0.98 },
            deathShard = { 0.62, 0.78, 0.86 },
            deathStyle = "Frosted Slate Crack",
        },
        SHADOW = {
            key = "SHADOW",
            label = "SHADOW",
            demoSpell = "SHADOW BOLT",
            flash = { 0.66, 0.42, 0.96 },
            cut = { 0.88, 0.70, 1.00 },
            trailHot = { 0.94, 0.80, 1.00 },
            trailHold = { 0.66, 0.36, 0.94 },
            trailFade = { 0.26, 0.08, 0.48 },
            border = { 0.60, 0.36, 0.90 },
            spark = { 0.66, 0.38, 0.96 },
            sparkAlt = { 0.88, 0.72, 1.00 },
            sparkPalette = {
                { 0.94, 0.78, 1.00 }, -- Pale twilight core
                { 0.76, 0.42, 1.00 }, -- Classic WoW Shadow amethyst
                { 0.56, 0.22, 0.90 }, -- Deep void violet
                { 0.86, 0.28, 0.78 }, -- Shadowflame magenta wisp
            },
            text = { 0.68, 0.46, 0.98 },
            critText = { 0.84, 0.64, 1.00 },
            glowDuration = 0.54,
            deathFill = { 0.23, 0.18, 0.28 },
            deathTrim = { 0.56, 0.42, 0.68 },
            deathCrackHot = { 0.82, 0.42, 1.00 },
            deathCrack = { 0.84, 0.72, 0.94 },
            deathDark = { 0.05, 0.03, 0.07 },
            deathFlash = { 0.74, 0.56, 0.88 },
            deathShard = { 0.58, 0.46, 0.72 },
            deathStyle = "Dusk-Slate Crack",
        },
        NATURE = {
            key = "NATURE",
            label = "NATURE",
            demoSpell = "WRATH",
            flash = { 0.56, 0.94, 0.52 },
            cut = { 0.86, 1.00, 0.78 },
            trailHot = { 0.90, 1.00, 0.80 },
            trailHold = { 0.40, 0.90, 0.40 },
            trailFade = { 0.14, 0.50, 0.20 },
            border = { 0.36, 0.84, 0.36 },
            spark = { 0.38, 0.88, 0.38 },
            sparkAlt = { 0.82, 0.98, 0.74 },
            sparkPalette = {
                { 0.88, 1.00, 0.78 }, -- Bright solar-leaf glint
                { 0.42, 0.94, 0.42 }, -- Classic WoW Nature emerald
                { 0.76, 0.96, 0.32 }, -- Wrath solar-lime mote
                { 0.20, 0.72, 0.34 }, -- Deep wildwood moss
            },
            text = { 0.32, 0.98, 0.34 },
            critText = { 0.60, 1.00, 0.58 },
            glowDuration = 0.44,
            deathFill = { 0.20, 0.27, 0.21 },
            deathTrim = { 0.44, 0.64, 0.42 },
            deathCrackHot = { 0.48, 0.98, 0.44 },
            deathCrack = { 0.78, 0.92, 0.74 },
            deathDark = { 0.04, 0.06, 0.04 },
            deathFlash = { 0.68, 0.90, 0.64 },
            deathShard = { 0.48, 0.70, 0.46 },
            deathStyle = "Verdant Slate Crack",
        },
        HOLY = {
            key = "HOLY",
            label = "HOLY",
            demoSpell = "SMITE",
            flash = { 1.00, 0.94, 0.68 },
            cut = { 1.00, 0.98, 0.84 },
            trailHot = { 1.00, 0.99, 0.92 },
            trailHold = { 1.00, 0.90, 0.50 },
            trailFade = { 0.88, 0.64, 0.20 },
            border = { 0.98, 0.86, 0.46 },
            spark = { 1.00, 0.90, 0.54 },
            sparkAlt = { 1.00, 0.98, 0.86 },
            sparkPalette = {
                { 1.00, 0.99, 0.90 }, -- Pure divine ivory
                { 1.00, 0.90, 0.50 }, -- Classic WoW Holy gold
                { 1.00, 0.78, 0.28 }, -- Radiant sunburst amber
                { 0.98, 0.94, 0.72 }, -- Blessed champagne shimmer
            },
            text = { 1.00, 0.90, 0.50 },
            critText = { 1.00, 0.96, 0.72 },
            glowDuration = 0.44,
            deathFill = { 0.29, 0.26, 0.20 },
            deathTrim = { 0.70, 0.62, 0.40 },
            deathCrackHot = { 1.00, 0.94, 0.58 },
            deathCrack = { 0.98, 0.92, 0.66 },
            deathDark = { 0.05, 0.04, 0.03 },
            deathFlash = { 0.98, 0.90, 0.60 },
            deathShard = { 0.74, 0.66, 0.44 },
            deathStyle = "Gilded Stone Crack",
        },
        ARCANE = {
            key = "ARCANE",
            label = "ARCANE",
            demoSpell = "ARCANE MISSILES",
            flash = { 0.96, 0.74, 1.00 },
            cut = { 0.98, 0.88, 1.00 },
            trailHot = { 0.98, 0.92, 1.00 },
            trailHold = { 0.94, 0.58, 0.98 },
            trailFade = { 0.50, 0.28, 0.84 },
            border = { 0.90, 0.58, 0.98 },
            spark = { 0.92, 0.60, 0.98 },
            sparkAlt = { 0.96, 0.86, 1.00 },
            sparkPalette = {
                { 0.98, 0.92, 1.00 }, -- Starlight white-violet
                { 0.96, 0.58, 1.00 }, -- Classic WoW Arcane magenta
                { 0.68, 0.52, 1.00 }, -- Ley-line mana indigo
                { 0.58, 0.86, 1.00 }, -- Astral cyan-violet flare
            },
            text = { 1.00, 0.56, 1.00 },
            critText = { 1.00, 0.78, 1.00 },
            glowDuration = 0.44,
            deathFill = { 0.26, 0.21, 0.30 },
            deathTrim = { 0.64, 0.48, 0.72 },
            deathCrackHot = { 0.96, 0.64, 1.00 },
            deathCrack = { 0.94, 0.78, 0.98 },
            deathDark = { 0.05, 0.03, 0.06 },
            deathFlash = { 0.90, 0.68, 0.96 },
            deathShard = { 0.68, 0.52, 0.76 },
            deathStyle = "Arcane Slate Crack",
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
    { pattern = "holy fire", elem = "FIRE", wowElem = "HOLY", dur = 10.0 },
    { pattern = "sunfire", elem = "FIRE", wowElem = "NATURE", dur = 12.0 },
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
    { pattern = "moonfire", elem = "LIGHTNING", wowElem = "ARCANE", dur = 12.0 },
    { pattern = "stormstrike", elem = "LIGHTNING", dur = 12.0 },
    { pattern = "thunder clap", elem = "LIGHTNING", dur = 10.0 },
    { pattern = "thunderclap", elem = "LIGHTNING", dur = 10.0 },
    { pattern = "electrocute", elem = "LIGHTNING", dur = 8.0 },
    { pattern = "static", elem = "LIGHTNING", dur = 8.0 },
    -- EARTH / NATURE DoTs
    { pattern = "serpent sting", elem = "EARTH", wowElem = "NATURE", dur = 15.0 },
    { pattern = "insect swarm", elem = "EARTH", wowElem = "NATURE", dur = 12.0 },
    { pattern = "earthbind", elem = "EARTH", dur = 6.0 },
    { pattern = "earthquake", elem = "EARTH", dur = 8.0 },
    { pattern = "deadly poison", elem = "EARTH", wowElem = "NATURE", dur = 12.0 },
    -- PHYSICAL Bleeds
    { pattern = "rend", elem = "PHYSICAL", dur = 15.0 },
    { pattern = "deep wounds", elem = "PHYSICAL", dur = 12.0 },
    { pattern = "garrote", elem = "PHYSICAL", dur = 18.0 },
    { pattern = "rupture", elem = "PHYSICAL", dur = 12.0 },
    { pattern = "rake", elem = "PHYSICAL", dur = 9.0 },
    { pattern = "rip", elem = "PHYSICAL", dur = 12.0 },
    { pattern = "lacerate", elem = "PHYSICAL", dur = 15.0 },
}

local function UseWowSpellColors()
    local fxCfg = ns.Config and ns.Config:Get("combatFX")
    return fxCfg and fxCfg.wowSpellColors and true or false
end

function ns.Elements:ClassifyDotSpell(spellName)
    if not spellName or ns.IsSecret(spellName) or type(spellName) ~= "string" then
        return nil, nil
    end
    local lower = string.lower(spellName)
    local useWow = UseWowSpellColors()
    for i = 1, #DOT_SPELL_PATTERNS do
        local entry = DOT_SPELL_PATTERNS[i]
        if string.find(lower, entry.pattern, 1, true) then
            return (useWow and entry.wowElem) or entry.elem, entry.dur
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
local HOLY_KEYWORDS = {
    "holy", "smite", "judgment", "judgement", "consecrat", "exorcism", "crusader", "penance", "flash of light", "sacred", "divine", "avenger",
}
local ARCANE_KEYWORDS = {
    "arcane", "moonfire", "starfire", "starsurge", "polymorph", "counterspell", "missiles", "supernova",
}
local NATURE_KEYWORDS = {
    "wrath", "insect swarm", "poison", "serpent sting", "wyvern sting", "healing wave", "chain heal", "rejuvenation", "regrowth", "riptide", "windfury", "entangling", "nature",
}

function ns.Elements:GetProfile(elementKey)
    local upper = "PHYSICAL"
    if elementKey and not ns.IsSecret(elementKey) then
        upper = string.upper(tostring(elementKey))
    end
    return self.PROFILES[upper] or self.PROFILES.PHYSICAL
end

function ns.Elements:ClassifyBySpellName(spellName)
    if not spellName or ns.IsSecret(spellName) or type(spellName) ~= "string" then
        return nil
    end
    local lower = string.lower(spellName)
    local useWow = UseWowSpellColors()

    if useWow then
        for i = 1, #HOLY_KEYWORDS do
            if string.find(lower, HOLY_KEYWORDS[i], 1, true) then
                return "HOLY"
            end
        end
        for i = 1, #ARCANE_KEYWORDS do
            if string.find(lower, ARCANE_KEYWORDS[i], 1, true) then
                return "ARCANE"
            end
        end
    end

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
    if useWow then
        for i = 1, #NATURE_KEYWORDS do
            if string.find(lower, NATURE_KEYWORDS[i], 1, true) then
                return "NATURE"
            end
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

    local useWow = UseWowSpellColors()
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
                if recentCast == "EARTH" or recentCast == "LIGHTNING" or (useWow and recentCast == "NATURE") then
                    return recentCast
                end
                return useWow and "NATURE" or "LIGHTNING"
            elseif bit.band(schoolMask, 64) ~= 0 then
                return useWow and "ARCANE" or "LIGHTNING"
            elseif bit.band(schoolMask, 2) ~= 0 then
                return useWow and "HOLY" or "FIRE"
            end
        else
            if schoolMask == 4 then
                return "FIRE"
            elseif schoolMask == 16 then
                return "FROST"
            elseif schoolMask == 32 then
                return "SHADOW"
            elseif schoolMask == 8 then
                if recentCast == "EARTH" or recentCast == "LIGHTNING" or (useWow and recentCast == "NATURE") then
                    return recentCast
                end
                return useWow and "NATURE" or "LIGHTNING"
            elseif schoolMask == 64 then
                return useWow and "ARCANE" or "LIGHTNING"
            elseif schoolMask == 2 then
                return useWow and "HOLY" or "FIRE"
            end
        end
    end

    if recentCast then
        return recentCast
    end
    return "PHYSICAL"
end

local DEFAULTS = {
    version = "1.3.5",
    unitBars = {
        enabled = true,
        vanillaBarMode = false,
        smoothSpeed = 20.0,
        trailSpeed = 6.5,
        trailHoldNormal = 0.20,
        trailHoldCrit = 0.32,
        traumaScale = 0.70,
        critTraumaMultiplier = 1.45,
        barPunchNormal = 1.08,
        barPunchCrit = 1.22,
        barPunchMega = 1.32,
        executeThreshold = 0.20,
    },
    nameplates = {
        enabled = true,
        targetHighlight = true,
        deflectCallouts = true,
        interruptShatter = true,
        deathShatterEnabled = true,
        hideNameAndLevelOnDeath = true,
        deathTiltDegrees = -8.5,
        deathHoldTime = 0.65,
        deathFadeTime = 0.40,
        deathElementalCracks = true,
        deathRandomTilt = false,
        deathPunchScale = 1.24,
        deathBounce = 0.45,
        deathDropSpeed = 18.0,
        deathDebrisScale = 1.00,
    },
    combatFX = {
        enabled = true,
        sparksEnabled = true,
        wowSpellColors = true,
        lowHpVignette = true,
        lowHpThreshold = 0.25,
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
        dotFontSize = 15,
        normalFontSize = 19,
        critFontSize = 27,
        megaFontSize = 31,
        killFontSize = 34,
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
        vanillaNonCombat = true,
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
        name = "Vanilla+ (Signature)",
        desc = "Grounded Blizzard aesthetic: UI-StatusBar textures, 9-element spell particles & colors, weathered stone-bronze frames, controlled trauma recoil (0.70x), and a crisp -8.5 deg cracked death bar.",
        values = {
            unitBars = {
                vanillaBarMode = false,
                smoothSpeed = 20.0,
                trailSpeed = 6.5,
                trailHoldNormal = 0.20,
                trailHoldCrit = 0.32,
                traumaScale = 0.70,
                critTraumaMultiplier = 1.45,
                barPunchNormal = 1.08,
                barPunchCrit = 1.22,
                barPunchMega = 1.32,
                executeThreshold = 0.20,
            },
            nameplates = {
                deathTiltDegrees = -8.5,
                deathHoldTime = 0.65,
                deathFadeTime = 0.40,
                deathShatterEnabled = true,
                hideNameAndLevelOnDeath = true,
                deathElementalCracks = true,
                deathRandomTilt = false,
                deathPunchScale = 1.24,
                deathBounce = 0.45,
                deathDropSpeed = 18.0,
                deathDebrisScale = 1.00,
                deflectCallouts = true,
                interruptShatter = true,
            },
            combatFX = {
                sparksEnabled = true,
                wowSpellColors = true,
                lowHpVignette = true,
                lowHpThreshold = 0.25,
            },
            combatText = {
                fountainLanes = true,
                critShockwave = true,
                flurryEscalation = true,
                flurryWindow = 1.45,
                elementalPhysics = true,
                killFinisher = true,
                baseOffsetY = 24,
                critOffsetY = 34,
                dotFontSize = 15,
                normalFontSize = 19,
                critFontSize = 27,
                megaFontSize = 31,
                killFontSize = 34,
                durationDot = 0.88,
                durationNormal = 1.20,
                durationCrit = 1.55,
                durationKill = 1.95,
            },
            castbars = {
                pushbackRecoil = true,
                recoilShake = true,
                leadSpark = true,
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
        desc = "Exaggerated combat violence: massive scale punches (up to 1.90x), heavy trauma recoil (1.6x), slow bleeding trails (3.8), steep death tilt (-16 deg) with heavy bounce & debris, and giant lingering numbers.",
        values = {
            unitBars = {
                vanillaBarMode = false,
                smoothSpeed = 15.0,
                trailSpeed = 3.8,
                trailHoldNormal = 0.38,
                trailHoldCrit = 0.60,
                traumaScale = 1.60,
                critTraumaMultiplier = 2.00,
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
                deathElementalCracks = true,
                deathRandomTilt = true,
                deathPunchScale = 1.52,
                deathBounce = 0.68,
                deathDropSpeed = 28.0,
                deathDebrisScale = 1.60,
                deflectCallouts = true,
                interruptShatter = true,
            },
            combatFX = {
                sparksEnabled = true,
                wowSpellColors = true,
                lowHpVignette = true,
                lowHpThreshold = 0.35,
            },
            combatText = {
                fountainLanes = true,
                critShockwave = true,
                flurryEscalation = true,
                flurryWindow = 1.75,
                elementalPhysics = true,
                killFinisher = true,
                baseOffsetY = 28,
                critOffsetY = 42,
                dotFontSize = 18,
                normalFontSize = 24,
                critFontSize = 36,
                megaFontSize = 44,
                killFontSize = 50,
                durationDot = 1.05,
                durationNormal = 1.40,
                durationCrit = 1.85,
                durationKill = 2.30,
            },
            castbars = {
                pushbackRecoil = true,
                recoilShake = true,
                leadSpark = true,
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
        desc = "Tournament clarity: ultra-fast bar snap (28), zero death tilt (0 deg), minimal recoil (0.20x), no screen clutter or cast shake, and compact fast-clearing numbers.",
        values = {
            unitBars = {
                vanillaBarMode = false,
                smoothSpeed = 28.0,
                trailSpeed = 11.0,
                trailHoldNormal = 0.10,
                trailHoldCrit = 0.18,
                traumaScale = 0.20,
                critTraumaMultiplier = 1.15,
                barPunchNormal = 1.03,
                barPunchCrit = 1.08,
                barPunchMega = 1.14,
                executeThreshold = 0.20,
            },
            nameplates = {
                deathTiltDegrees = 0.0,
                deathHoldTime = 0.35,
                deathFadeTime = 0.20,
                deathShatterEnabled = false,
                hideNameAndLevelOnDeath = false,
                deathElementalCracks = false,
                deathRandomTilt = false,
                deathPunchScale = 1.04,
                deathBounce = 0.10,
                deathDropSpeed = 0.0,
                deathDebrisScale = 0.00,
                deflectCallouts = true,
                interruptShatter = true,
            },
            combatFX = {
                sparksEnabled = false,
                wowSpellColors = true,
                lowHpVignette = false,
                lowHpThreshold = 0.20,
            },
            combatText = {
                fountainLanes = true,
                critShockwave = false,
                flurryEscalation = false,
                flurryWindow = 0.90,
                elementalPhysics = false,
                killFinisher = false,
                baseOffsetY = 18,
                critOffsetY = 24,
                dotFontSize = 13,
                normalFontSize = 16,
                critFontSize = 22,
                megaFontSize = 25,
                killFontSize = 28,
                durationDot = 0.65,
                durationNormal = 0.85,
                durationCrit = 1.10,
                durationKill = 1.30,
            },
            castbars = {
                pushbackRecoil = true,
                recoilShake = false,
                leadSpark = true,
            },
            stateEngine = {
                alphaCombat = 1.0,
                alphaExploring = 0.65,
                alphaTravelling = 0.55,
                alphaResting = 0.45,
                alphaHarvesting = 0.55,
            },
        },
    },
    ARCADE = {
        name = "Arcade (Bouncy Pop)",
        desc = "Snappy combo action: fast bar snap (26) & rapid trails (9.5), vertical bounce pops (1.18x-1.58x) with light sideways shake (0.45x), bouncy death hinge, and brisk poppy numbers.",
        values = {
            unitBars = {
                vanillaBarMode = false,
                smoothSpeed = 26.0,
                trailSpeed = 9.5,
                trailHoldNormal = 0.14,
                trailHoldCrit = 0.24,
                traumaScale = 0.45,
                critTraumaMultiplier = 1.35,
                barPunchNormal = 1.18,
                barPunchCrit = 1.42,
                barPunchMega = 1.58,
                executeThreshold = 0.20,
            },
            nameplates = {
                deathTiltDegrees = -6.5,
                deathHoldTime = 0.55,
                deathFadeTime = 0.30,
                deathShatterEnabled = true,
                hideNameAndLevelOnDeath = true,
                deathElementalCracks = true,
                deathRandomTilt = true,
                deathPunchScale = 1.38,
                deathBounce = 0.80,
                deathDropSpeed = 22.0,
                deathDebrisScale = 1.35,
                deflectCallouts = true,
                interruptShatter = true,
            },
            combatFX = {
                sparksEnabled = true,
                wowSpellColors = true,
                lowHpVignette = true,
                lowHpThreshold = 0.25,
            },
            combatText = {
                fountainLanes = true,
                critShockwave = true,
                flurryEscalation = true,
                flurryWindow = 2.20,
                elementalPhysics = true,
                killFinisher = true,
                baseOffsetY = 26,
                critOffsetY = 38,
                dotFontSize = 16,
                normalFontSize = 21,
                critFontSize = 30,
                megaFontSize = 35,
                killFontSize = 40,
                durationDot = 0.75,
                durationNormal = 1.00,
                durationCrit = 1.30,
                durationKill = 1.60,
            },
            castbars = {
                pushbackRecoil = true,
                recoilShake = true,
                leadSpark = true,
            },
            stateEngine = {
                alphaCombat = 1.0,
                alphaExploring = 0.45,
                alphaTravelling = 0.35,
                alphaResting = 0.25,
                alphaHarvesting = 0.40,
            },
        },
    },
    CINEMATIC = {
        name = "Cinematic (Vanilla Bars)",
        desc = "Immersive RPG & authentic Vanilla bars: rigid non-stretching healthbars, soft cut-seam glint, weighty slow trails (3.2), WoW spell-school colors, gentle -4.5 deg death bar, and deep HUD fade.",
        values = {
            unitBars = {
                vanillaBarMode = true,
                smoothSpeed = 14.0,
                trailSpeed = 3.2,
                trailHoldNormal = 0.42,
                trailHoldCrit = 0.65,
                traumaScale = 0.28,
                critTraumaMultiplier = 1.25,
                barPunchNormal = 1.00,
                barPunchCrit = 1.03,
                barPunchMega = 1.06,
                executeThreshold = 0.18,
            },
            nameplates = {
                deathTiltDegrees = -4.5,
                deathHoldTime = 1.20,
                deathFadeTime = 0.70,
                deathShatterEnabled = true,
                hideNameAndLevelOnDeath = true,
                deathElementalCracks = true,
                deathRandomTilt = false,
                deathPunchScale = 1.08,
                deathBounce = 0.18,
                deathDropSpeed = 10.0,
                deathDebrisScale = 0.65,
                deflectCallouts = true,
                interruptShatter = true,
            },
            combatFX = {
                sparksEnabled = true,
                wowSpellColors = true,
                lowHpVignette = true,
                lowHpThreshold = 0.20,
            },
            combatText = {
                fountainLanes = true,
                critShockwave = false,
                flurryEscalation = true,
                flurryWindow = 1.25,
                elementalPhysics = true,
                killFinisher = true,
                baseOffsetY = 20,
                critOffsetY = 28,
                dotFontSize = 14,
                normalFontSize = 17,
                critFontSize = 24,
                megaFontSize = 28,
                killFontSize = 31,
                durationDot = 1.00,
                durationNormal = 1.35,
                durationCrit = 1.70,
                durationKill = 2.15,
            },
            castbars = {
                pushbackRecoil = true,
                recoilShake = false,
                leadSpark = true,
            },
            stateEngine = {
                alphaCombat = 1.0,
                alphaExploring = 0.20,
                alphaTravelling = 0.12,
                alphaResting = 0.08,
                alphaHarvesting = 0.18,
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
        -- Migrate older profiles where wowSpellColors defaulted to false
        if ForeverUIDB.version ~= "1.3.5" then
            if type(ForeverUIDB.combatFX) == "table" and ForeverUIDB.combatFX.wowSpellColors == nil then
                ForeverUIDB.combatFX.wowSpellColors = true
            end
            ForeverUIDB.version = "1.3.5"
        end
        if type(ForeverUIDB.questTracker) == "table" and (ForeverUIDB.questTracker.closeDistanceYards or 0) < 180 then
            ForeverUIDB.questTracker.closeDistanceYards = 180
            ForeverUIDB.questTracker.nearbyDistanceYards = 600
        end
        if type(ForeverUIDB.combatText) == "table" and (ForeverUIDB.combatText.normalFontSize or 0) < 18 then
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
