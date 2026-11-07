local addonName, ns = ...
_G.ForeverUI = ns

local function PrintMsg(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffb833ForeverUI:|r " .. tostring(msg))
end
ns.Print = PrintMsg

local demoBar = nil
local demoEnhancer = nil
local demoNameLabel = nil
local demoKillCursor = 0
local demoGeneration = 0

local ELEMENT_HEX = {
    LIGHTNING = "|cff48dcff",
    FIRE      = "|cffff751a",
    EARTH     = "|cfff09933",
    FROST     = "|cff70e0ff",
    SHADOW    = "|cffbf66ff",
    PHYSICAL  = "|cffffe6b3",
}

local function GetOrCreateDemoBar()
    if not demoBar then
        -- Offset to the right (+185, +35) so the simulated enemy nameplate never sits over the player's own head
        demoBar = CreateFrame("StatusBar", "ForeverUI_DemoNameplateBar", UIParent)
        demoBar:SetSize(156, 14)
        demoBar:SetPoint("CENTER", UIParent, "CENTER", 185, 35)
        demoBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        demoBar:SetStatusBarColor(0.88, 0.12, 0.12, 1.0)
        demoBar:SetMinMaxValues(0, 100)
        demoBar:SetValue(100)
        demoBar.fuiWidth = 156
        demoBar.fuiHeight = 14

        demoEnhancer = ns.UnitBars:CreateBarEnhancer(demoBar, nil, false)

        demoNameLabel = demoEnhancer.container:CreateFontString(nil, "OVERLAY")
        demoNameLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        demoNameLabel:SetPoint("BOTTOM", demoEnhancer.container, "TOP", 0, 3)
        demoNameLabel:SetTextColor(1.0, 0.18, 0.18, 1.0)
        demoNameLabel:SetText("Enemy Target (Demo)")
    end
    demoBar:Show()
    demoBar:SetAlpha(1.0)
    demoEnhancer.isSecretHealth = false
    demoEnhancer.mainBar:SetMinMaxValues(0, 1000)
    demoEnhancer.trailBar:SetMinMaxValues(0, 1000)
    demoEnhancer.container:Show()
    demoEnhancer.container:SetAlpha(1.0)
    if demoEnhancer.targetBrackets then
        demoEnhancer.targetBrackets:Show()
    end
    if demoNameLabel then
        demoNameLabel:SetText("Enemy Target (Demo)")
        demoNameLabel:Show()
    end
    return demoBar, demoEnhancer
end

local function RestoreEnhancerAfterDemo(enhancer, usingDemoBar)
    if enhancer then
        ns.UnitBars:SetDotState(enhancer, nil, 0)
    end
    if usingDemoBar and demoBar then
        demoBar:Hide()
        demoEnhancer.container:Hide()
    elseif enhancer then
        enhancer.deathTriggered = false
        enhancer.statusBar:SetAlpha(1.0)
        enhancer.container:SetAlpha(1.0)
        if enhancer.unitFrame then
            if enhancer.unitFrame.name then
                enhancer.unitFrame.name:SetAlpha(1.0)
            end
            if enhancer.unitFrame.Name then
                enhancer.unitFrame.Name:SetAlpha(1.0)
            end
            if enhancer.unitFrame.LevelFrame then
                enhancer.unitFrame.LevelFrame:SetAlpha(1.0)
            end
        end
        if enhancer.unit and UnitExists(enhancer.unit) then
            enhancer.initializedSecret = false
            ns.UnitBars:SyncUnitState(enhancer, true)
        end
    end
end

local function FireElementStage(bar, enhancer, usingDemoBar, elemKey, targetFrac, dmgText, isCrit, isDot)
    local prof = ns.Elements:GetProfile(elemKey)
    enhancer.deathTriggered = false
    enhancer.isSecretHealth = false
    enhancer.mainBar:SetMinMaxValues(0, 1000)
    enhancer.trailBar:SetMinMaxValues(0, 1000)
    enhancer.statusBar:SetAlpha(1.0)
    enhancer.container:SetAlpha(1.0)
    if enhancer.targetBrackets then
        enhancer.targetBrackets:Show()
    end

    local prevFrac = enhancer.targetFrac or 1.0
    if prevFrac <= targetFrac or prevFrac <= 0.18 then
        enhancer.displayFrac = 1.0
        enhancer.trailFrac = 1.0
        prevFrac = 1.0
    end
    enhancer.targetFrac = targetFrac
    if usingDemoBar then
        demoBar:SetValue(math.floor(targetFrac * 100 + 0.5))
        if demoNameLabel then
            demoNameLabel:SetText("Enemy Target — [" .. prof.label .. "]")
            demoNameLabel:Show()
        end
    end

    local pctLost = math.max(0.03, prevFrac - targetFrac)
    local isMega = isCrit and (pctLost >= 0.30)
    local hitWeight = isDot and 0.12 or math.max(0.20, math.min(1.0, (pctLost - 0.03) / 0.11))
    ns.UnitBars:TriggerDamageImpact(enhancer, pctLost, isCrit, isMega, prof.key, hitWeight, isDot)

    local col = isCrit and prof.critText or prof.text
    ns.CombatText:SpawnNumber({
        text = dmgText,
        hitWeight = hitWeight,
        hitWeightComputed = true,
        r = col[1],
        g = col[2],
        b = col[3],
        elementKey = prof.key,
        isCrit = isCrit,
        isMega = isMega,
        isDot = isDot,
        anchorFrame = enhancer.statusBar or bar,
        woundAnchor = enhancer.steadyWoundAnchor or enhancer.statusBar or bar,
        side = "right",
    })
end

local function FireElementKillStage(bar, enhancer, usingDemoBar, elemKey, dmgText)
    local prof = ns.Elements:GetProfile(elemKey)
    enhancer.lastElement = prof.key
    if enhancer.targetBrackets then
        enhancer.targetBrackets:Hide()
    end
    if enhancer.elemBorder then
        enhancer.elemBorder:Hide()
    end

    if usingDemoBar then
        ns.CombatFX:SpawnDeathShatterBar(bar, prof.key)
        if demoNameLabel then
            demoNameLabel:Hide()
        end
        demoBar:SetAlpha(0.0)
        demoEnhancer.container:SetAlpha(0.0)
    else
        enhancer.deathTriggered = false
        ns.Nameplates:TriggerDeathForEnhancer(enhancer, prof.key)
    end

    local col = prof.critText or { 1.0, 0.82, 0.0 }
    ns.CombatText:SpawnNumber({
        text = dmgText or "1640",
        r = col[1],
        g = col[2],
        b = col[3],
        elementKey = prof.key,
        isCrit = true,
        isMega = true,
        isKill = true,
        anchorFrame = bar,
        side = "right",
    })
end

function ns:RunElementSingleDemo(elemKey)
    demoGeneration = demoGeneration + 1
    local myGen = demoGeneration

    local bar, enhancer = nil, nil
    if ns.Nameplates then
        bar, enhancer = ns.Nameplates:GetAnyActiveEnemyPlate()
    end
    local usingDemoBar = false
    if not bar or not enhancer then
        bar, enhancer = GetOrCreateDemoBar()
        usingDemoBar = true
    end

    local prof = ns.Elements:GetProfile(elemKey)
    local hex = ELEMENT_HEX[prof.key] or "|cffffd100"

    enhancer.displayFrac = 1.0
    enhancer.trailFrac = 1.0
    enhancer.targetFrac = 1.0

    -- Step 1 (0.00s): Subtle Low-Damage Hit (-5% HP, non-crit)
    FireElementStage(bar, enhancer, usingDemoBar, prof.key, 0.95, "112", false)

    if C_Timer and C_Timer.After then
        -- Step 2 (0.62s): Moderate Normal Hit (-13% HP, non-crit)
        C_Timer.After(0.62, function()
            if demoGeneration ~= myGen then
                return
            end
            FireElementStage(bar, enhancer, usingDemoBar, prof.key, 0.82, "285", false)
        end)

        -- Step 3 (1.32s): Heavy Critical Hit (-40% HP, CRIT) + Continuous DoT Burn/Crackle for 2.4s!
        C_Timer.After(1.32, function()
            if demoGeneration ~= myGen then
                return
            end
            FireElementStage(bar, enhancer, usingDemoBar, prof.key, 0.42, prof.demoSpell .. " 940", true)
            ns.UnitBars:SetDotState(enhancer, prof.key, 2.4)
        end)

        C_Timer.After(3.80, function()
            if demoGeneration ~= myGen then
                return
            end
            RestoreEnhancerAfterDemo(enhancer, usingDemoBar)
        end)
    end

    PrintMsg("Previewing " .. hex .. prof.label .. "|r escalation + DoT burn/crackle! Try |cffffd100/fui dot " .. string.lower(prof.key) .. "|r or |cffffd100/fui kill " .. string.lower(prof.key) .. "|r.")
end

function ns:RunInGameDemo(mode, arg)
    demoGeneration = demoGeneration + 1
    local myGen = demoGeneration

    local bar, enhancer = nil, nil
    if ns.Nameplates then
        bar, enhancer = ns.Nameplates:GetAnyActiveEnemyPlate()
    end
    local usingDemoBar = false
    if not bar or not enhancer then
        bar, enhancer = GetOrCreateDemoBar()
        usingDemoBar = true
    end

    if mode == "interrupt" then
        enhancer.lastInterruptTime = 0
        ns.Nameplates:TriggerInterruptForEnhancer(enhancer)
        PrintMsg("Triggered Interrupt Shatter (electric cyan shockwave + arcane sparks).")
        return
    elseif mode == "parry" then
        ns.Nameplates:TriggerDeflectForEnhancer(enhancer, "PARRY")
        PrintMsg("Triggered Metallic Deflect Callout (sideways ricochet PARRY! + silver glint sparks).")
        return
    elseif mode == "dot" then
        local elemKey = (arg and arg ~= "") and string.upper(arg) or "FIRE"
        if elemKey == "BOLT" then
            elemKey = "LIGHTNING"
        end
        if not ns.Elements.PROFILES[elemKey] then
            elemKey = "FIRE"
        end
        local prof = ns.Elements:GetProfile(elemKey)
        local hex = ELEMENT_HEX[prof.key] or "|cffffd100"

        enhancer.displayFrac = 1.0
        enhancer.trailFrac = 1.0
        enhancer.targetFrac = 1.0
        FireElementStage(bar, enhancer, usingDemoBar, prof.key, 0.82, prof.demoSpell .. " 240", false)
        ns.UnitBars:SetDotState(enhancer, prof.key, 6.0)

        if C_Timer and C_Timer.After then
            local ticks = {
                { t = 1.5, frac = 0.72, dmg = "95" },
                { t = 3.0, frac = 0.62, dmg = "98" },
                { t = 4.5, frac = 0.50, dmg = "102" },
            }
            for i = 1, #ticks do
                local tk = ticks[i]
                C_Timer.After(tk.t, function()
                    if demoGeneration ~= myGen then
                        return
                    end
                    FireElementStage(bar, enhancer, usingDemoBar, prof.key, tk.frac, tk.dmg, false, true)
                end)
            end
            C_Timer.After(6.2, function()
                if demoGeneration ~= myGen then
                    return
                end
                RestoreEnhancerAfterDemo(enhancer, usingDemoBar)
            end)
        end
        PrintMsg("Triggered 6s continuous " .. hex .. prof.label .. " DoT|r burning/crackling on remaining health!")
        return
    elseif mode == "kill" then
        local order = ns.Elements.ORDER
        local elemKey = nil
        if arg and arg ~= "" then
            elemKey = string.upper(arg)
            if elemKey == "BOLT" then
                elemKey = "LIGHTNING"
            end
        end
        if not elemKey or not ns.Elements.PROFILES[elemKey] then
            demoKillCursor = (demoKillCursor % #order) + 1
            elemKey = order[demoKillCursor]
        end
        local prof = ns.Elements:GetProfile(elemKey)
        local hex = ELEMENT_HEX[prof.key] or "|cffffd100"

        FireElementKillStage(bar, enhancer, usingDemoBar, prof.key, prof.label .. " KILL 1640")
        if C_Timer and C_Timer.After then
            C_Timer.After(1.65, function()
                if demoGeneration ~= myGen then
                    return
                end
                RestoreEnhancerAfterDemo(enhancer, usingDemoBar)
            end)
        end
        PrintMsg("Triggered " .. hex .. prof.label .. "|r Killing Blow shatter bar! (Run |cffffd100/fui kill|r again to cycle elements)")
        return
    end

    -- Full 6-Element Showcase (Each element shows a subtle Light Hit followed by a Heavy Crit, ending with an Elemental Kill!)
    enhancer.displayFrac = 1.0
    enhancer.trailFrac = 1.0
    enhancer.targetFrac = 1.0

    -- 1. LIGHTNING: Subtle light hit (0.00s) -> Heavy Crit (0.45s)
    FireElementStage(bar, enhancer, usingDemoBar, "LIGHTNING", 0.95, "118", false)

    if C_Timer and C_Timer.After then
        C_Timer.After(0.45, function()
            if demoGeneration ~= myGen then
                return
            end
            FireElementStage(bar, enhancer, usingDemoBar, "LIGHTNING", 0.82, "LIGHTNING 540", true)
        end)

        -- 2. FIRE: Subtle light hit (1.20s) -> Heavy Crit (1.65s)
        C_Timer.After(1.20, function()
            if demoGeneration ~= myGen then
                return
            end
            FireElementStage(bar, enhancer, usingDemoBar, "FIRE", 0.77, "96", false)
        end)
        C_Timer.After(1.65, function()
            if demoGeneration ~= myGen then
                return
            end
            FireElementStage(bar, enhancer, usingDemoBar, "FIRE", 0.63, "FIRE 615", true)
        end)

        -- 3. EARTH: Subtle light hit (2.40s) -> Heavy Crit (2.85s)
        C_Timer.After(2.40, function()
            if demoGeneration ~= myGen then
                return
            end
            FireElementStage(bar, enhancer, usingDemoBar, "EARTH", 0.58, "134", false)
        end)
        C_Timer.After(2.85, function()
            if demoGeneration ~= myGen then
                return
            end
            FireElementStage(bar, enhancer, usingDemoBar, "EARTH", 0.42, "EARTH 780", true)
        end)

        -- 4. FROST: Subtle light hit (3.60s) -> Heavy Crit (4.05s)
        C_Timer.After(3.60, function()
            if demoGeneration ~= myGen then
                return
            end
            FireElementStage(bar, enhancer, usingDemoBar, "FROST", 0.37, "105", false)
        end)
        C_Timer.After(4.05, function()
            if demoGeneration ~= myGen then
                return
            end
            FireElementStage(bar, enhancer, usingDemoBar, "FROST", 0.24, "FROST 590", true)
        end)

        -- 5. SHADOW: Subtle light hit (4.80s) -> Heavy Crit (5.25s)
        C_Timer.After(4.80, function()
            if demoGeneration ~= myGen then
                return
            end
            FireElementStage(bar, enhancer, usingDemoBar, "SHADOW", 0.19, "88", false)
        end)
        C_Timer.After(5.25, function()
            if demoGeneration ~= myGen then
                return
            end
            FireElementStage(bar, enhancer, usingDemoBar, "SHADOW", 0.08, "SHADOW 740", true)
        end)

        -- 6. ELEMENTAL KILLING BLOW (6.05s)
        C_Timer.After(6.05, function()
            if demoGeneration ~= myGen then
                return
            end
            local order = ns.Elements.ORDER
            demoKillCursor = (demoKillCursor % #order) + 1
            local killElem = order[demoKillCursor]
            FireElementKillStage(bar, enhancer, usingDemoBar, killElem, killElem .. " 1850")
        end)

        -- Restore after showcase completes
        C_Timer.After(7.70, function()
            if demoGeneration ~= myGen then
                return
            end
            RestoreEnhancerAfterDemo(enhancer, usingDemoBar)
        end)
    end

    PrintMsg("Running Elemental Showcase (Light Subtle Hit -> Heavy Crit per element): |cff48dcffLIGHTNING|r -> |cffff751aFIRE|r -> |cfff09933EARTH|r -> |cff70e0ffFROST|r -> |cffbf66ffSHADOW|r -> |cffffd100KILL|r!")
end

local function HandleSlashCommand(msg)
    local cmd, arg = string.match(string.lower(msg or ""), "^(%S*)%s*(.-)$")
    if cmd == "test" or cmd == "showcase" or cmd == "elements" or cmd == "" then
        ns:RunInGameDemo("showcase")
    elseif cmd == "lightning" or cmd == "bolt" then
        ns:RunElementSingleDemo("LIGHTNING")
    elseif cmd == "fire" then
        ns:RunElementSingleDemo("FIRE")
    elseif cmd == "earth" then
        ns:RunElementSingleDemo("EARTH")
    elseif cmd == "frost" then
        ns:RunElementSingleDemo("FROST")
    elseif cmd == "shadow" then
        ns:RunElementSingleDemo("SHADOW")
    elseif cmd == "physical" then
        ns:RunElementSingleDemo("PHYSICAL")
    elseif cmd == "dot" then
        ns:RunInGameDemo("dot", arg)
    elseif cmd == "kill" then
        ns:RunInGameDemo("kill", arg)
    elseif cmd == "interrupt" then
        ns:RunInGameDemo("interrupt")
    elseif cmd == "parry" or cmd == "deflect" then
        ns:RunInGameDemo("parry")
    elseif cmd == "status" then
        local count = ns.Nameplates and ns.Nameplates:ScanExistingNameplates() or 0
        local cvarVal = GetCVar and GetCVar("nameplateShowEnemies") or "?"
        local stateStr = tostring(ns.StateEngine and ns.StateEngine.currentState or "?")
        local alphaStr = string.format("%.2f", ns.StateEngine and ns.StateEngine.currentAlpha or 1.0)
        PrintMsg("Active enemy nameplates hooked: " .. tostring(count) .. " (nameplateShowEnemies=" .. tostring(cvarVal) .. ") | State: " .. stateStr .. " (HUD alpha=" .. alphaStr .. ")")
    elseif cmd == "state" then
        local upper = string.upper(arg or "")
        if ns.StateEngine.STATES[upper] then
            ns.StateEngine:SetOverrideState(upper)
            PrintMsg("State override set to " .. upper .. " (target alpha=" .. string.format("%.2f", ns.StateEngine.targetAlpha or 1.0) .. ")")
        else
            ns.StateEngine:SetOverrideState(nil)
            PrintMsg("State override cleared (current: " .. tostring(ns.StateEngine.currentState) .. ", target alpha=" .. string.format("%.2f", ns.StateEngine.targetAlpha or 1.0) .. ")")
        end
    elseif cmd == "statefade" then
        local seCfg = ns.Config:Get("stateEngine")
        if seCfg then
            local newState = not (seCfg.fadeHUD ~= false and seCfg.fadeUnitFrames ~= false)
            seCfg.fadeHUD = newState
            seCfg.fadeUnitFrames = newState
            ns.StateEngine:RefreshState(false)
            PrintMsg("Context state HUD fade: " .. (newState and "ON" or "OFF") .. " (target alpha=" .. string.format("%.2f", ns.StateEngine.targetAlpha or 1.0) .. ")")
        end
    elseif cmd == "quests" or cmd == "quest" then
        if ns.QuestTracker and ns.QuestTracker.PrintQuestStatus then
            ns.QuestTracker:PrintQuestStatus()
        end
    elseif cmd == "questfade" then
        local qtCfg = ns.Config:Get("questTracker")
        if qtCfg then
            local newState = not (qtCfg.enabled ~= false)
            qtCfg.enabled = newState
            if newState then
                ns.QuestTracker:EvaluateQuestDistances(true)
                ns.QuestTracker:ApplyTrackerAlphas(1.0)
            else
                ns.QuestTracker:RestoreAllAlphas()
            end
            ns.StateEngine:RefreshState(false)
            PrintMsg("Proximity Quest Objective Tracker: " .. (newState and "ON" or "OFF"))
        end
    elseif cmd == "reset" then
        ns.Config:Reset()
        PrintMsg("Configuration reset to defaults.")
    else
        PrintMsg("Commands:")
        PrintMsg("  /fui showcase  - Run full 6-Element Showcase (Lightning -> Fire -> Earth -> Frost -> Shadow -> Physical -> Kill)")
        PrintMsg("  /fui lightning - Preview Lightning Bolt crackle arcs + electric blue bar jolt")
        PrintMsg("  /fui fire      - Preview Fire burning glow + heat shimmer + rising embers")
        PrintMsg("  /fui earth     - Preview Earth high-punch brown/orange slam + falling rock debris")
        PrintMsg("  /fui frost     - Preview Frost frozen trail + ice rim + shattering ice shards")
        PrintMsg("  /fui shadow    - Preview Shadow void purple dread wave + hovering shadow motes")
        PrintMsg("  /fui dot [el]  - Preview continuous 6s DoT burning/crackling (e.g. /fui dot fire, /fui dot lightning)")
        PrintMsg("  /fui kill [el] - Preview Elemental Killing Blow (e.g. /fui kill fire, /fui kill lightning)")
        PrintMsg("  /fui interrupt - Preview Electric Cyan Interrupt Shatter")
        PrintMsg("  /fui parry     - Preview Metallic Deflect Ricochet (PARRY!)")
        PrintMsg("  /fui quests    - Show quest distances & tracker tier (Close / Nearby / Far)")
        PrintMsg("  /fui questfade - Toggle proximity-based Quest Objective Tracker opacity & filter")
    end
end

SLASH_FOREVERUI1 = "/fui"
SLASH_FOREVERUI2 = "/foreverui"
SlashCmdList["FOREVERUI"] = HandleSlashCommand

ns.Events:Register("ADDON_LOADED", function(_, _, loadedName)
    if loadedName ~= addonName then
        return
    end
    ns.Config:Initialize()
end, ns)

ns.Events:Register("PLAYER_LOGIN", function()
    if ns.StateEngine and ns.StateEngine.OnEnable then
        ns.StateEngine:OnEnable()
    end
    if ns.CombatFX and ns.CombatFX.OnEnable then
        ns.CombatFX:OnEnable()
    end
    if ns.UnitBars and ns.UnitBars.OnEnable then
        ns.UnitBars:OnEnable()
    end
    if ns.Nameplates and ns.Nameplates.OnEnable then
        ns.Nameplates:OnEnable()
    end
    if ns.CombatText and ns.CombatText.OnEnable then
        ns.CombatText:OnEnable()
    end
    PrintMsg("Loaded (v1.0.0). Type |cffffd100/fui test|r or |cffffd100/fui kill|r to preview effects.")
end, ns)
