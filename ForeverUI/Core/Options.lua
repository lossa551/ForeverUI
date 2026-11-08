local addonName, ns = ...
ns.Options = {}

-- Guard secret value inspection for WoW 12.0+ / Forever (16001) engine rules
local function IsSecret(val)
    if ns.IsSecret then
        return ns.IsSecret(val)
    end
    if issecretvalue then
        return issecretvalue(val)
    end
    return false
end

local optionsFrame = nil
local minimapButton = nil
local currentTab = 1
local tabFrames = {}
local tabButtons = {}
local refreshCallbacks = {}

-- ============================================================================
-- MINIMAP BUTTON
-- ============================================================================
local function UpdateMinimapButtonPosition()
    if not minimapButton then
        return
    end
    local cfg = ns.Config:Get("minimap") or {}
    if cfg.hide then
        minimapButton:Hide()
        return
    end
    minimapButton:Show()

    local angle = cfg.angle or 225
    local radius = cfg.radius or 80
    local rad = math.rad(angle)
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
    if minimapButton then
        return minimapButton
    end

    minimapButton = CreateFrame("Button", "ForeverUI_MinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetToplevel(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForClicks("AnyUp")
    minimapButton:RegisterForDrag("LeftButton")

    -- Background disc
    local bg = minimapButton:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(21, 21)
    bg:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetVertexColor(0.12, 0.12, 0.14, 1.0)
    minimapButton.bg = bg

    -- Core Icon (Fiery kinetic weapon emblem)
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\Spell_Fire_FlameBlades")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    minimapButton.icon = icon

    -- Circular border ring
    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    minimapButton.border = border

    -- Highlight ring
    local highlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(32, 32)
    highlight:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    minimapButton.highlight = highlight

    -- Dragging without restricted frame measurement calls (tangent delta algorithm)
    minimapButton:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self.dragStartX, self.dragStartY = GetCursorPosition()
        local cfg = ns.Config:Get("minimap") or {}
        self.dragStartAngle = cfg.angle or 225
        self.lastX, self.lastY = self.dragStartX, self.dragStartY
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        self.isDragging = false
    end)

    minimapButton:SetScript("OnUpdate", function(self)
        if not self.isDragging then
            return
        end
        local curX, curY = GetCursorPosition()
        if curX == self.lastX and curY == self.lastY then
            return
        end

        local dx = curX - self.lastX
        local dy = curY - self.lastY
        self.lastX, self.lastY = curX, curY

        local cfg = ns.Config:Get("minimap") or {}
        local curAngle = cfg.angle or 225
        local rad = math.rad(curAngle)

        -- Tangent projection: Tx = -sin(theta), Ty = cos(theta)
        local dTheta = (-dx * math.sin(rad) + dy * math.cos(rad)) * 0.45
        local newAngle = (curAngle + dTheta) % 360
        cfg.angle = newAngle
        UpdateMinimapButtonPosition()
    end)

    minimapButton:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if ns.RunInGameDemo then
                ns:RunInGameDemo("showcase")
            end
        elseif IsShiftKeyDown() then
            local seCfg = ns.Config:Get("stateEngine")
            if seCfg then
                local newState = not (seCfg.fadeHUD ~= false and seCfg.fadeUnitFrames ~= false)
                seCfg.fadeHUD = newState
                seCfg.fadeUnitFrames = newState
                if ns.StateEngine and ns.StateEngine.RefreshState then
                    ns.StateEngine:RefreshState(false)
                end
                ns.Print("Context state HUD fade: " .. (newState and "ON" or "OFF"))
            end
        else
            ns.Options:Toggle()
        end
    end)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffffb833Forever|r|cffffffffUI|r", 1.0, 0.85, 0.3)
        GameTooltip:AddLine("Combat Kinetic Feedback & UI Enhancements", 0.75, 0.75, 0.75)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("|cffffd100Left-Click:|r", "Open Settings & Presets", 1, 1, 1, 0.9, 0.9, 0.9)
        GameTooltip:AddDoubleLine("|cffffd100Right-Click:|r", "6-Element Combat Showcase", 1, 1, 1, 0.9, 0.9, 0.9)
        GameTooltip:AddDoubleLine("|cffffd100Shift-Click:|r", "Toggle Out-of-Combat HUD Fade", 1, 1, 1, 0.9, 0.9, 0.9)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff888888Drag to move around minimap|r", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdateMinimapButtonPosition()
    return minimapButton
end

-- ============================================================================
-- WIDGET HELPERS (SAFE FROM RESTRICTED-REGION CALLS)
-- ============================================================================
local function CreateSectionHeader(parent, x, y, title)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    header:SetText("|cffffb833" .. title .. "|r")

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetSize(460, 1)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    line:SetColorTexture(0.7, 0.5, 0.2, 0.4)

    return header
end

local function CreateCheckbox(parent, x, y, labelText, tooltipText, getFunc, setFunc)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetSize(24, 24)

    local text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(labelText)
    cb.label = text

    local function Refresh()
        cb:SetChecked(getFunc() and true or false)
    end
    table.insert(refreshCallbacks, Refresh)
    Refresh()

    cb:SetScript("OnClick", function(self)
        local val = self:GetChecked() and true or false
        setFunc(val)
    end)

    if tooltipText then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(labelText, 1, 0.82, 0)
            GameTooltip:AddLine(tooltipText, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return cb
end

local function CreateSlider(parent, x, y, labelText, tooltipText, minVal, maxVal, step, getFunc, setFunc, formatFunc)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetSize(190, 16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local title = slider:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 3)
    title:SetText(labelText)

    local valText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 3)

    local function Refresh()
        local v = getFunc() or minVal
        slider:SetValue(v)
        valText:SetText(formatFunc and formatFunc(v) or string.format("%.2f", v))
    end
    table.insert(refreshCallbacks, Refresh)
    Refresh()

    slider:SetScript("OnValueChanged", function(self, val)
        valText:SetText(formatFunc and formatFunc(val) or string.format("%.2f", val))
        setFunc(val)
    end)

    if tooltipText then
        slider:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(labelText, 1, 0.82, 0)
            GameTooltip:AddLine(tooltipText, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        slider:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return slider
end

local function CreateStyledButton(parent, x, y, width, height, text, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetSize(width, height)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

-- ============================================================================
-- TAB 1: ART PRESETS & THEMES
-- ============================================================================
local function BuildPresetsTab(panel)
    CreateSectionHeader(panel, 16, -14, "Art Direction & Kinetic Presets")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -42)
    desc:SetText("Choose a curated art preset below to instantly reconfigure bar recoil, death bar tilt, delayed trail speeds, and font sizes. Any manual tweaks made in other tabs will be preserved.")
    desc:SetJustifyH("LEFT")

    local activeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    activeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -78)

    local function RefreshActivePresetLabel()
        local activeKey = ns.Config:Get("activePreset") or "DEFAULT"
        local p = ns.Config.PRESETS[activeKey]
        local nameStr = p and p.name or "Custom User Configuration"
        activeLabel:SetText("Current Preset: |cffffd100" .. nameStr .. "|r")
    end
    table.insert(refreshCallbacks, RefreshActivePresetLabel)
    RefreshActivePresetLabel()

    local presetKeys = { "DEFAULT", "BRUTAL", "CLEAN", "ARCADE", "CINEMATIC" }
    local yOfs = -110

    for _, key in ipairs(presetKeys) do
        local p = ns.Config.PRESETS[key]
        local btn = CreateStyledButton(panel, 16, yOfs, 160, 26, p.name, function()
            ns.Config:ApplyPreset(key)
            ns.Options:RefreshAll()
            if ns.StateEngine and ns.StateEngine.RefreshState then
                ns.StateEngine:RefreshState(false)
            end
            ns.Print("Applied Art Preset: |cffffd100" .. p.name .. "|r")
        end)

        local pDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        pDesc:SetPoint("TOPLEFT", panel, "TOPLEFT", 186, yOfs - 4)
        pDesc:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
        pDesc:SetText(p.desc)
        pDesc:SetJustifyH("LEFT")

        yOfs = yOfs - 52
    end

    local noteHeader = CreateSectionHeader(panel, 16, yOfs - 10, "Future Art Presets & Skins")
    local noteDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    noteDesc:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, yOfs - 38)
    noteDesc:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    noteDesc:SetText("The preset system is built to expand with texture packs, custom border shaders, sound profiles, and community art presets in future updates.")
    noteDesc:SetJustifyH("LEFT")
end

-- ============================================================================
-- TAB 2: UNIT BARS & TRAUMA
-- ============================================================================
local function BuildUnitBarsTab(panel)
    CreateSectionHeader(panel, 16, -14, "Unit Bars & Violent Damage Trauma")

    CreateCheckbox(panel, 16, -42, "Enable Health Bar Enhancements", "Enable kinetic trauma shake, delayed damage trail bars, and scale punches on unit frames.",
        function() return ns.Config:Get("unitBars", "enabled") end,
        function(v) ns.Config:Set("unitBars", "enabled", v) end
    )

    -- Column 1
    CreateSlider(panel, 16, -88, "Bar Trauma Recoil Scale", "Multiplier for horizontal/vertical bar shudder recoil on taking damage.",
        0.0, 2.0, 0.05,
        function() return ns.Config:Get("unitBars", "traumaScale") end,
        function(v) ns.Config:Set("unitBars", "traumaScale", v) end,
        function(v) return string.format("%.2fx", v) end
    )

    CreateSlider(panel, 16, -136, "Crit Trauma Multiplier", "Extra camera and bar trauma scale applied on critical strikes.",
        1.0, 3.0, 0.1,
        function() return ns.Config:Get("unitBars", "critTraumaMultiplier") end,
        function(v) ns.Config:Set("unitBars", "critTraumaMultiplier", v) end,
        function(v) return string.format("%.1fx", v) end
    )

    CreateSlider(panel, 16, -184, "Primary Bar Smooth Speed", "Interpolation speed for the main health bar as health decreases or increases.",
        6.0, 32.0, 1.0,
        function() return ns.Config:Get("unitBars", "smoothSpeed") end,
        function(v) ns.Config:Set("unitBars", "smoothSpeed", v) end,
        function(v) return string.format("%.0f", v) end
    )

    CreateSlider(panel, 16, -232, "Damage Trail Catchup Speed", "Speed at which the delayed amber/white damage trail drains down.",
        1.5, 14.0, 0.5,
        function() return ns.Config:Get("unitBars", "trailSpeed") end,
        function(v) ns.Config:Set("unitBars", "trailSpeed", v) end,
        function(v) return string.format("%.1f", v) end
    )

    CreateSlider(panel, 16, -280, "Execute Glow Range", "Health percentage threshold below which the red pulsing execute vignette triggers.",
        0.05, 0.40, 0.05,
        function() return ns.Config:Get("unitBars", "executeThreshold") end,
        function(v) ns.Config:Set("unitBars", "executeThreshold", v) end,
        function(v) return string.format("%.0f%%", v * 100) end
    )

    -- Column 2
    CreateSlider(panel, 250, -88, "Scale Punch (Normal Hits)", "Instant scale expansion punch on normal hits.",
        1.0, 1.40, 0.02,
        function() return ns.Config:Get("unitBars", "barPunchNormal") end,
        function(v) ns.Config:Set("unitBars", "barPunchNormal", v) end,
        function(v) return string.format("%.2fx", v) end
    )

    CreateSlider(panel, 250, -136, "Scale Punch (Critical Hits)", "Instant scale expansion punch on critical strikes.",
        1.1, 1.80, 0.02,
        function() return ns.Config:Get("unitBars", "barPunchCrit") end,
        function(v) ns.Config:Set("unitBars", "barPunchCrit", v) end,
        function(v) return string.format("%.2fx", v) end
    )

    CreateSlider(panel, 250, -184, "Scale Punch (Mega Crits)", "Instant scale expansion punch on massive hits (>30% HP lost).",
        1.2, 2.20, 0.02,
        function() return ns.Config:Get("unitBars", "barPunchMega") end,
        function(v) ns.Config:Set("unitBars", "barPunchMega", v) end,
        function(v) return string.format("%.2fx", v) end
    )

    CreateSlider(panel, 250, -232, "Trail Hold Time (Normal)", "Seconds the amber trail lingers before beginning to drain down.",
        0.05, 0.80, 0.02,
        function() return ns.Config:Get("unitBars", "trailHoldNormal") end,
        function(v) ns.Config:Set("unitBars", "trailHoldNormal", v) end,
        function(v) return string.format("%.2fs", v) end
    )

    CreateSlider(panel, 250, -280, "Trail Hold Time (Crits)", "Seconds the amber trail lingers on critical hits.",
        0.10, 1.20, 0.05,
        function() return ns.Config:Get("unitBars", "trailHoldCrit") end,
        function(v) ns.Config:Set("unitBars", "trailHoldCrit", v) end,
        function(v) return string.format("%.2fs", v) end
    )
end

-- ============================================================================
-- TAB 3: OVERHEAD NAMEPLATES & DEATH FX
-- ============================================================================
local function BuildNameplatesTab(panel)
    CreateSectionHeader(panel, 16, -14, "Overhead Nameplates & Killing Blow FX")

    CreateCheckbox(panel, 16, -42, "Enable Nameplate Enhancements", "Enable target brackets, elemental border glows, and killing blow death bars.",
        function() return ns.Config:Get("nameplates", "enabled") end,
        function(v) ns.Config:Set("nameplates", "enabled", v) end
    )

    CreateCheckbox(panel, 16, -72, "Bare Cracked Death Bar & Shatter", "On enemy death, morph nameplate into a bare tilted corpse bar with fracture cracks and flying shards.",
        function() return ns.Config:Get("nameplates", "deathShatterEnabled") end,
        function(v) ns.Config:Set("nameplates", "deathShatterEnabled", v) end
    )

    CreateCheckbox(panel, 16, -102, "Strip Clutter On Death (Hide Name & Level)", "Hide name and level text on death to leave a clean, cinematic cracked death bar.",
        function() return ns.Config:Get("nameplates", "hideNameAndLevelOnDeath") end,
        function(v) ns.Config:Set("nameplates", "hideNameAndLevelOnDeath", v) end
    )

    CreateCheckbox(panel, 16, -132, "Deflect / Parry Ricochet Callouts", "Show metallic silver ricochets when enemies deflect, block, or parry attacks.",
        function() return ns.Config:Get("nameplates", "deflectCallouts") end,
        function(v) ns.Config:Set("nameplates", "deflectCallouts", v) end
    )

    CreateCheckbox(panel, 16, -162, "Cyan Interrupt Shatter Callouts", "Show sharp electric cyan fracture arcs when the player successfully interrupts a spellcast.",
        function() return ns.Config:Get("nameplates", "interruptShatter") end,
        function(v) ns.Config:Set("nameplates", "interruptShatter", v) end
    )

    CreateSlider(panel, 16, -214, "Death Bar Tilt Angle", "Degrees the cracked corpse bar tilts on killing blows (negative tilts left).",
        -25.0, 25.0, 0.5,
        function() return ns.Config:Get("nameplates", "deathTiltDegrees") end,
        function(v) ns.Config:Set("nameplates", "deathTiltDegrees", v) end,
        function(v) return string.format("%.1f deg", v) end
    )

    CreateSlider(panel, 250, -214, "Death Hold Duration", "Duration the cracked corpse bar stays frozen before fading out.",
        0.20, 2.50, 0.05,
        function() return ns.Config:Get("nameplates", "deathHoldTime") end,
        function(v) ns.Config:Set("nameplates", "deathHoldTime", v) end,
        function(v) return string.format("%.2fs", v) end
    )

    CreateSlider(panel, 16, -266, "Death Fadeout Duration", "Duration of the alpha fadeout transition as the death bar disappears.",
        0.10, 1.50, 0.05,
        function() return ns.Config:Get("nameplates", "deathFadeTime") end,
        function(v) ns.Config:Set("nameplates", "deathFadeTime", v) end,
        function(v) return string.format("%.2fs", v) end
    )
end

-- ============================================================================
-- TAB 4: FLOATING COMBAT TEXT
-- ============================================================================
local function BuildCombatTextTab(panel)
    CreateSectionHeader(panel, 16, -14, "Dynamic High-Fountain Combat Text")

    CreateCheckbox(panel, 16, -42, "Enable Dynamic Combat Text", "Render pure numeric floating combat text above enemy nameplates.",
        function() return ns.Config:Get("combatText", "enabled") end,
        function(v) ns.Config:Set("combatText", "enabled", v) end
    )

    CreateCheckbox(panel, 16, -72, "Hide Vanilla Floating Combat Text", "Suppress default 3D world damage text to eliminate duplicate numbers.",
        function() return ns.Config:Get("combatText", "hideVanillaDamage") end,
        function(v) ns.Config:Set("combatText", "hideVanillaDamage", v) end
    )

    CreateCheckbox(panel, 16, -102, "Alternating Fountain Arc Lanes", "Disperse consecutive hits left and right to prevent overlapping damage numbers.",
        function() return ns.Config:Get("combatText", "fountainLanes") end,
        function(v) ns.Config:Set("combatText", "fountainLanes", v) end
    )

    CreateCheckbox(panel, 16, -132, "Critical Strike Shockwave Echo", "Trigger an expanding ghost shockwave number on critical strikes.",
        function() return ns.Config:Get("combatText", "critShockwave") end,
        function(v) ns.Config:Set("combatText", "critShockwave", v) end
    )

    CreateCheckbox(panel, 16, -162, "Flurry Escalation", "Progressively scale font size and color warmth during rapid consecutive attacks.",
        function() return ns.Config:Get("combatText", "flurryEscalation") end,
        function(v) ns.Config:Set("combatText", "flurryEscalation", v) end
    )

    -- Sliders
    CreateSlider(panel, 16, -214, "Normal Damage Font Size", "Base font size for standard non-critical hits.",
        14, 32, 1,
        function() return ns.Config:Get("combatText", "normalFontSize") end,
        function(v) ns.Config:Set("combatText", "normalFontSize", v) end,
        function(v) return string.format("%.0f pt", v) end
    )

    CreateSlider(panel, 250, -214, "Critical Strike Font Size", "Font size for critical strikes.",
        20, 48, 1,
        function() return ns.Config:Get("combatText", "critFontSize") end,
        function(v) ns.Config:Set("combatText", "critFontSize", v) end,
        function(v) return string.format("%.0f pt", v) end
    )

    CreateSlider(panel, 16, -266, "Mega Hit Font Size (>30% HP)", "Font size for massive critical hits that shave off a large portion of enemy health.",
        24, 56, 1,
        function() return ns.Config:Get("combatText", "megaFontSize") end,
        function(v) ns.Config:Set("combatText", "megaFontSize", v) end,
        function(v) return string.format("%.0f pt", v) end
    )

    CreateSlider(panel, 250, -266, "Flurry Window Duration", "Time window within which consecutive attacks build flurry heat.",
        0.5, 3.0, 0.1,
        function() return ns.Config:Get("combatText", "flurryWindow") end,
        function(v) ns.Config:Set("combatText", "flurryWindow", v) end,
        function(v) return string.format("%.1fs", v) end
    )
end

-- ============================================================================
-- TAB 5: STATE ENGINE & HUD FADING
-- ============================================================================
local function BuildStateEngineTab(panel)
    CreateSectionHeader(panel, 16, -14, "State Engine & Immersive HUD Fading")

    CreateCheckbox(panel, 16, -42, "Enable State-Aware HUD Fading", "Automatically fade out-of-combat UI elements depending on current player activity.",
        function() return ns.Config:Get("stateEngine", "fadeHUD") end,
        function(v)
            ns.Config:Set("stateEngine", "fadeHUD", v)
            ns.Config:Set("stateEngine", "fadeUnitFrames", v)
            if ns.StateEngine and ns.StateEngine.RefreshState then
                ns.StateEngine:RefreshState(false)
            end
        end
    )

    CreateCheckbox(panel, 16, -72, "Wake UI on Enemy Target Selection", "Instantly restore full 100% opacity whenever an active target is selected.",
        function() return ns.Config:Get("stateEngine", "wakeOnTarget") end,
        function(v)
            ns.Config:Set("stateEngine", "wakeOnTarget", v)
            if ns.StateEngine and ns.StateEngine.RefreshState then
                ns.StateEngine:RefreshState(false)
            end
        end
    )

    CreateCheckbox(panel, 16, -102, "Wake UI on Unit Frame Mouseover", "Smoothly wake up unit frames when hovering the mouse over them.",
        function() return ns.Config:Get("stateEngine", "wakeOnMouseover") end,
        function(v) ns.Config:Set("stateEngine", "wakeOnMouseover", v) end
    )

    CreateCheckbox(panel, 16, -132, "Show Minimap Button", "Show the circular ForeverUI shortcut icon around the minimap.",
        function()
            local cfg = ns.Config:Get("minimap") or {}
            return not cfg.hide
        end,
        function(v)
            local cfg = ns.Config:Get("minimap") or {}
            cfg.hide = not v
            UpdateMinimapButtonPosition()
        end
    )

    -- Opacity Sliders
    CreateSlider(panel, 16, -184, "Combat State Opacity", "HUD opacity when actively in combat.",
        0.50, 1.00, 0.05,
        function() return ns.Config:Get("stateEngine", "alphaCombat") end,
        function(v)
            ns.Config:Set("stateEngine", "alphaCombat", v)
            if ns.StateEngine and ns.StateEngine.RefreshState then
                ns.StateEngine:RefreshState(false)
            end
        end,
        function(v) return string.format("%.0f%%", v * 100) end
    )

    CreateSlider(panel, 250, -184, "Exploring State Opacity", "HUD opacity while running or walking in the world.",
        0.10, 1.00, 0.05,
        function() return ns.Config:Get("stateEngine", "alphaExploring") end,
        function(v)
            ns.Config:Set("stateEngine", "alphaExploring", v)
            if ns.StateEngine and ns.StateEngine.RefreshState then
                ns.StateEngine:RefreshState(false)
            end
        end,
        function(v) return string.format("%.0f%%", v * 100) end
    )

    CreateSlider(panel, 16, -236, "Travelling State Opacity", "HUD opacity while mounted, flight-pathing, or taxiing.",
        0.10, 1.00, 0.05,
        function() return ns.Config:Get("stateEngine", "alphaTravelling") end,
        function(v)
            ns.Config:Set("stateEngine", "alphaTravelling", v)
            if ns.StateEngine and ns.StateEngine.RefreshState then
                ns.StateEngine:RefreshState(false)
            end
        end,
        function(v) return string.format("%.0f%%", v * 100) end
    )

    CreateSlider(panel, 250, -236, "Resting State Opacity", "HUD opacity while resting inside an inn or major city.",
        0.10, 1.00, 0.05,
        function() return ns.Config:Get("stateEngine", "alphaResting") end,
        function(v)
            ns.Config:Set("stateEngine", "alphaResting", v)
            if ns.StateEngine and ns.StateEngine.RefreshState then
                ns.StateEngine:RefreshState(false)
            end
        end,
        function(v) return string.format("%.0f%%", v * 100) end
    )
end

-- ============================================================================
-- TAB 6: TEST BENCH & LIVE PREVIEW
-- ============================================================================
local function BuildTestBenchTab(panel)
    CreateSectionHeader(panel, 16, -14, "Interactive Test Bench & Elemental Previews")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -42)
    desc:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    desc:SetText("Trigger live simulated combat effects directly without needing an active enemy target or slash commands. If an enemy target exists, the preview plays on their nameplate; otherwise a simulated test target bar appears.")
    desc:SetJustifyH("LEFT")

    CreateStyledButton(panel, 16, -88, 220, 28, "|cffffd100Run 6-Element Showcase|r", function()
        if ns.RunInGameDemo then
            ns:RunInGameDemo("showcase")
        end
    end)

    CreateStyledButton(panel, 250, -88, 220, 28, "|cffff4444Preview Killing Blow|r", function()
        if ns.RunInGameDemo then
            ns:RunInGameDemo("kill")
        end
    end)

    CreateSectionHeader(panel, 16, -136, "Single Element Preview")

    local elements = {
        { key = "LIGHTNING", label = "Lightning (Crackle)", col = "48dcff" },
        { key = "FIRE",      label = "Fire (Embers)",      col = "ff751a" },
        { key = "EARTH",     label = "Earth (Rock Slam)",  col = "f09933" },
        { key = "FROST",     label = "Frost (Ice Rim)",    col = "70e0ff" },
        { key = "SHADOW",    label = "Shadow (Dread)",     col = "bf66ff" },
        { key = "PHYSICAL",  label = "Physical (Cleave)",  col = "ffe6b3" },
    }

    local colX = 16
    local rowY = -166
    for i, elem in ipairs(elements) do
        CreateStyledButton(panel, colX, rowY, 140, 24, "|cff" .. elem.col .. elem.label .. "|r", function()
            if ns.RunElementSingleDemo then
                ns:RunElementSingleDemo(elem.key)
            end
        end)
        if i % 3 == 0 then
            colX = 16
            rowY = rowY - 32
        else
            colX = colX + 148
        end
    end

    CreateSectionHeader(panel, 16, -244, "Combat Callouts")

    CreateStyledButton(panel, 16, -274, 180, 24, "Interrupt Cyan Shatter", function()
        if ns.RunInGameDemo then
            ns:RunInGameDemo("interrupt")
        end
    end)

    CreateStyledButton(panel, 206, -274, 180, 24, "Parry / Deflect Ricochet", function()
        if ns.RunInGameDemo then
            ns:RunInGameDemo("parry")
        end
    end)
end

-- ============================================================================
-- MAIN OPTIONS FRAME
-- ============================================================================
local function SelectTab(index)
    currentTab = index
    for i, frame in ipairs(tabFrames) do
        if i == index then
            frame:Show()
        else
            frame:Hide()
        end
    end
    for i, btn in ipairs(tabButtons) do
        if i == index then
            btn:LockHighlight()
            btn.indicator:Show()
        else
            btn:UnlockHighlight()
            btn.indicator:Hide()
        end
    end
end

local function CreateOptionsFrame()
    if optionsFrame then
        return optionsFrame
    end

    optionsFrame = CreateFrame("Frame", "ForeverUI_OptionsFrame", UIParent, "BackdropTemplate")
    optionsFrame:SetSize(700, 520)
    optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetToplevel(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:SetMovable(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
    optionsFrame:Hide()

    -- Standard ESC close
    table.insert(UISpecialFrames, "ForeverUI_OptionsFrame")

    -- Backdrop
    optionsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    optionsFrame:SetBackdropColor(0.06, 0.06, 0.08, 0.98)

    -- Top Header Title
    local titleIcon = optionsFrame:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(22, 22)
    titleIcon:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 18, -14)
    titleIcon:SetTexture("Interface\\Icons\\Spell_Fire_FlameBlades")
    titleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", titleIcon, "RIGHT", 8, 0)
    title:SetText("|cffffb833FOREVER|r|cffffffffUI|r  |cff888888Configuration & Art Presets|r")

    -- Close Button (Top-Right)
    local closeBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -4, -4)

    -- Tab Bar (Left Column)
    local tabDefinitions = {
        { name = "Presets & Art" },
        { name = "Unit Bars" },
        { name = "Nameplates & Death" },
        { name = "Combat Text" },
        { name = "State & HUD" },
        { name = "Test Bench" },
    }

    local tabListX = 14
    local tabListY = -54

    for i, tabDef in ipairs(tabDefinitions) do
        local tabBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
        tabBtn:SetSize(160, 30)
        tabBtn:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", tabListX, tabListY)
        tabBtn:SetText(tabDef.name)

        local ind = tabBtn:CreateTexture(nil, "OVERLAY")
        ind:SetSize(4, 26)
        ind:SetPoint("LEFT", tabBtn, "LEFT", 2, 0)
        ind:SetColorTexture(1.0, 0.72, 0.18, 1.0)
        ind:Hide()
        tabBtn.indicator = ind

        local tabIdx = i
        tabBtn:SetScript("OnClick", function()
            SelectTab(tabIdx)
        end)
        table.insert(tabButtons, tabBtn)

        tabListY = tabListY - 34
    end

    -- Vertical Divider between Tabs and Content
    local divider = optionsFrame:CreateTexture(nil, "ARTWORK")
    divider:SetSize(1, 410)
    divider:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 184, -50)
    divider:SetColorTexture(0.5, 0.4, 0.2, 0.4)

    -- Content Container Frames
    for i = 1, #tabDefinitions do
        local page = CreateFrame("Frame", nil, optionsFrame)
        page:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 194, -50)
        page:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 44)
        page:Hide()
        table.insert(tabFrames, page)
    end

    BuildPresetsTab(tabFrames[1])
    BuildUnitBarsTab(tabFrames[2])
    BuildNameplatesTab(tabFrames[3])
    BuildCombatTextTab(tabFrames[4])
    BuildStateEngineTab(tabFrames[5])
    BuildTestBenchTab(tabFrames[6])

    -- Bottom Bar: Reset to Defaults & Close
    local resetBtn = CreateStyledButton(optionsFrame, 18, -478, 150, 24, "Reset to Defaults", function()
        ns.Config:Reset()
        ns.Options:RefreshAll()
        if ns.StateEngine and ns.StateEngine.RefreshState then
            ns.StateEngine:RefreshState(false)
        end
        ns.Print("Settings reset to defaults.")
    end)

    local bottomCloseBtn = CreateStyledButton(optionsFrame, 560, -478, 110, 24, "Close", function()
        optionsFrame:Hide()
    end)

    local verLabel = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    verLabel:SetPoint("RIGHT", bottomCloseBtn, "LEFT", -16, 0)
    verLabel:SetText("v1.0.0")

    SelectTab(1)
    return optionsFrame
end

-- ============================================================================
-- BLIZZARD SETTINGS PANEL INTEGRATION
-- ============================================================================
local function RegisterBlizzardCategory()
    local canvas = CreateFrame("Frame", "ForeverUI_BlizzardCanvas", UIParent)
    canvas.name = "ForeverUI"

    local cTitle = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    cTitle:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -16)
    cTitle:SetText("|cffffb833Forever|r|cffffffffUI|r")

    local cSub = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cSub:SetPoint("TOPLEFT", cTitle, "BOTTOMLEFT", 0, -8)
    cSub:SetPoint("RIGHT", canvas, "RIGHT", -16, 0)
    cSub:SetText("High-impact violent health bar trauma, bare cracked death bars, dynamic high-fountain combat text, and context-aware HUD fading.")
    cSub:SetJustifyH("LEFT")

    local openBtn = CreateStyledButton(canvas, 16, -70, 220, 30, "|cffffd100Open ForeverUI Control Panel|r", function()
        if Settings and Settings.Close then
            Settings.Close()
        end
        ns.Options:Open()
    end)

    local tip = canvas:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    tip:SetPoint("TOPLEFT", openBtn, "BOTTOMLEFT", 0, -12)
    tip:SetText("You can also type |cffffd100/fui|r or click the minimap icon at any time.")

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(canvas, "ForeverUI")
        Settings.RegisterAddOnCategory(category)
        ns.BlizzardSettingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(canvas)
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================
function ns.Options:OnEnable()
    CreateMinimapButton()
    RegisterBlizzardCategory()
end

function ns.Options:Open()
    local f = CreateOptionsFrame()
    f:Show()
    self:RefreshAll()
end

function ns.Options:Close()
    if optionsFrame then
        optionsFrame:Hide()
    end
end

function ns.Options:Toggle()
    local f = CreateOptionsFrame()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        self:RefreshAll()
    end
end

function ns.Options:RefreshAll()
    for _, callback in ipairs(refreshCallbacks) do
        callback()
    end
end
