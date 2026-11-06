local addonName, ns = ...
_G.ForeverUI = ns

local function PrintMsg(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffb833ForeverUI:|r " .. tostring(msg))
end
ns.Print = PrintMsg

local demoBar = nil
local demoEnhancer = nil
local demoNameLabel = nil

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

        demoEnhancer = ns.UnitBars:CreateBarEnhancer(demoBar, nil, true)

        demoNameLabel = demoEnhancer.container:CreateFontString(nil, "OVERLAY")
        demoNameLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        demoNameLabel:SetPoint("BOTTOM", demoEnhancer.container, "TOP", 0, 3)
        demoNameLabel:SetTextColor(1.0, 0.18, 0.18, 1.0)
        demoNameLabel:SetText("Enemy Target (Demo)")
    end
    demoBar:Show()
    demoBar:SetAlpha(1.0)
    demoEnhancer.container:Show()
    demoEnhancer.container:SetAlpha(1.0)
    if demoNameLabel then
        demoNameLabel:Show()
    end
    return demoBar, demoEnhancer
end

function ns:RunInGameDemo(mode)
    local bar, enhancer = nil, nil
    if ns.Nameplates then
        bar, enhancer = ns.Nameplates:GetAnyActiveEnemyPlate()
    end
    local usingDemoBar = false
    if not bar or not enhancer then
        bar, enhancer = GetOrCreateDemoBar()
        usingDemoBar = true
    end

    if mode == "kill" then
        ns.CombatFX:SpawnDeathShatterBar(bar)
        if usingDemoBar then
            if demoNameLabel then
                demoNameLabel:Hide()
            end
            demoBar:SetAlpha(0.0)
            demoEnhancer.container:SetAlpha(0.0)
        else
            enhancer.deathTriggered = false
            ns.Nameplates:TriggerDeathForEnhancer(enhancer)
        end
        ns.CombatText:SpawnNumber({
            text = "1420",
            r = 1.0, g = 0.82, b = 0.0,
            isCrit = true,
            isMega = true,
            anchorFrame = bar,
            side = "right",
        })
        PrintMsg("Triggered Killing Blow (bare cracked gray tilted bar + shatter shards).")
        return
    end

    -- Reset bar to 100% and run 3-stage impact combo (Normal -> Mega Crit -> Bare Cracked Death Bar)
    enhancer.deathTriggered = false
    enhancer.displayFrac = 1.0
    enhancer.trailFrac = 1.0
    enhancer.targetFrac = 0.78
    enhancer.statusBar:SetAlpha(1.0)
    enhancer.container:SetAlpha(1.0)
    if usingDemoBar then
        demoBar:SetValue(78)
    end
    ns.UnitBars:TriggerDamageImpact(enhancer, 0.22, false, false)
    ns.CombatText:SpawnNumber({
        text = "245",
        r = 1.0, g = 1.0, b = 1.0,
        isCrit = false,
        anchorFrame = bar,
        side = "right",
    })

    if C_Timer and C_Timer.After then
        C_Timer.After(0.55, function()
            enhancer.targetFrac = 0.32
            if usingDemoBar then
                demoBar:SetValue(32)
            end
            ns.UnitBars:TriggerDamageImpact(enhancer, 0.46, true, true)
            ns.CombatText:SpawnNumber({
                text = "984",
                r = 1.0, g = 0.50, b = 0.0,
                isCrit = true,
                isMega = true,
                anchorFrame = bar,
                side = "right",
            })
        end)

        C_Timer.After(1.20, function()
            ns.CombatFX:SpawnDeathShatterBar(bar)
            if usingDemoBar then
                if demoNameLabel then
                    demoNameLabel:Hide()
                end
                demoBar:SetAlpha(0.0)
                demoEnhancer.container:SetAlpha(0.0)
            else
                enhancer.deathTriggered = false
                ns.Nameplates:TriggerDeathForEnhancer(enhancer)
            end
            ns.CombatText:SpawnNumber({
                text = "1350",
                r = 1.0, g = 0.82, b = 0.0,
                isCrit = true,
                isMega = true,
                anchorFrame = bar,
                side = "right",
            })
        end)

        C_Timer.After(2.70, function()
            if usingDemoBar and demoBar then
                demoBar:Hide()
                demoEnhancer.container:Hide()
            elseif enhancer then
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
            end
        end)
    end

    if usingDemoBar then
        PrintMsg("No enemy nameplate visible on screen — running demo on simulated Enemy Target bar (right of center).")
    else
        PrintMsg("Running 3-stage impact combo on active enemy overhead nameplate!")
    end
end

local function HandleSlashCommand(msg)
    local cmd, arg = string.match(string.lower(msg or ""), "^(%S*)%s*(.-)$")
    if cmd == "test" or cmd == "" then
        ns:RunInGameDemo("combo")
    elseif cmd == "kill" then
        ns:RunInGameDemo("kill")
    elseif cmd == "status" then
        local count = ns.Nameplates and ns.Nameplates:ScanExistingNameplates() or 0
        local cvarVal = GetCVar and GetCVar("nameplateShowEnemies") or "?"
        PrintMsg("Active enemy nameplates hooked: " .. tostring(count) .. " (nameplateShowEnemies=" .. tostring(cvarVal) .. ")")
    elseif cmd == "state" then
        local upper = string.upper(arg or "")
        if ns.StateEngine.STATES[upper] then
            ns.StateEngine:SetOverrideState(upper)
            PrintMsg("State override set to " .. upper)
        else
            ns.StateEngine:SetOverrideState(nil)
            PrintMsg("State override cleared (current: " .. tostring(ns.StateEngine.currentState) .. ")")
        end
    elseif cmd == "statefade" then
        local seCfg = ns.Config:Get("stateEngine")
        if seCfg then
            seCfg.fadeUnitFrames = not seCfg.fadeUnitFrames
            ns.StateEngine:RefreshState()
            PrintMsg("Context state unit-frame fade: " .. (seCfg.fadeUnitFrames and "ON" or "OFF"))
        end
    elseif cmd == "reset" then
        ns.Config:Reset()
        PrintMsg("Configuration reset to defaults.")
    else
        PrintMsg("Commands:")
        PrintMsg("  /fui test   - Preview Normal Hit -> Mega Crit -> Bare Cracked Death Bar")
        PrintMsg("  /fui kill   - Preview Killing Blow bare cracked/tilted gray death bar")
        PrintMsg("  /fui status - Check how many enemy nameplates are currently hooked")
        PrintMsg("  /fui statefade - Toggle out-of-combat state fading")
        PrintMsg("  /fui reset  - Reset settings to defaults")
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
