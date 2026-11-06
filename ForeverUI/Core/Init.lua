local addonName, ns = ...
_G.ForeverUI = ns

local function PrintMsg(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffb833ForeverUI:|r " .. tostring(msg))
end
ns.Print = PrintMsg

-- Optional in-game demo bar when /fui test or /fui kill is run without a visible nameplate
local demoBar = nil
local demoEnhancer = nil

local function GetOrCreateDemoBar()
    if not demoBar then
        demoBar = CreateFrame("StatusBar", "ForeverUI_DemoNameplateBar", UIParent)
        demoBar:SetSize(156, 14)
        demoBar:SetPoint("CENTER", UIParent, "CENTER", 0, 90)
        demoBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        demoBar:SetStatusBarColor(0.85, 0.12, 0.12, 1.0)
        demoBar:SetMinMaxValues(0, 100)
        demoBar:SetValue(100)

        local bg = demoBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(demoBar)
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(0.05, 0.05, 0.06, 0.92)

        demoEnhancer = ns.UnitBars:CreateBarEnhancer(demoBar, nil, true)
    end
    demoBar:Show()
    demoBar:SetAlpha(1.0)
    return demoBar, demoEnhancer
end

function ns:RunInGameDemo(mode)
    -- Prefer active target's overhead nameplate if visible, otherwise spawn center demo bar
    local targetGUID = UnitExists("target") and UnitGUID("target") or nil
    local bar, enhancer = nil, nil
    if targetGUID and ns.Nameplates then
        bar, enhancer = ns.Nameplates:GetBarForGUID(targetGUID)
    end
    local usingDemoBar = false
    if not bar or not enhancer then
        bar, enhancer = GetOrCreateDemoBar()
        usingDemoBar = true
    end

    if mode == "kill" then
        if usingDemoBar then
            demoBar:SetAlpha(0.0)
        end
        ns.CombatFX:SpawnDeathShatterBar(bar)
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

    -- Reset demo bar to 100% and run a 3-hit combo (Normal -> Heavy Crit -> Killing Blow Shatter)
    enhancer.displayFrac = 1.0
    enhancer.trailFrac = 1.0
    enhancer.targetFrac = 0.78
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
            if usingDemoBar then
                demoBar:SetAlpha(0.0)
            end
            ns.CombatFX:SpawnDeathShatterBar(bar)
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
            end
        end)
    end

    PrintMsg("Running 3-stage impact combo (Normal Hit -> Mega Crit -> Bare Cracked Death Bar)...")
end

local function HandleSlashCommand(msg)
    local cmd, arg = string.match(string.lower(msg or ""), "^(%S*)%s*(.-)$")
    if cmd == "test" or cmd == "" then
        ns:RunInGameDemo("combo")
    elseif cmd == "kill" then
        ns:RunInGameDemo("kill")
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
        PrintMsg("  /fui test  - Preview Normal Hit -> Mega Crit -> Bare Cracked Death Bar")
        PrintMsg("  /fui kill  - Preview Killing Blow bare cracked/tilted gray death bar")
        PrintMsg("  /fui statefade - Toggle out-of-combat state fading")
        PrintMsg("  /fui reset - Reset settings to defaults")
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
