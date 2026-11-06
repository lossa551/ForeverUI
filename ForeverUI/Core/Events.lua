local addonName, ns = ...
ns.Events = {}

local eventFrame = CreateFrame("Frame", "ForeverUI_EventFrame", UIParent)
local listeners = {}
local customListeners = {}
local tickers = {}
local activeTickerCount = 0

local function OnEvent(self, event, ...)
    local bucket = listeners[event]
    if not bucket then
        return
    end
    for owner, callback in pairs(bucket) do
        if type(callback) == "function" then
            callback(owner, event, ...)
        elseif type(owner) == "table" and type(owner[callback]) == "function" then
            owner[callback](owner, event, ...)
        end
    end
end

local function OnUpdate(self, elapsed)
    local dt = elapsed
    if dt > 0.05 then
        dt = 0.05
    end
    local now = GetTime()
    for id, fn in pairs(tickers) do
        local keepRunning = fn(dt, now)
        if keepRunning == false then
            tickers[id] = nil
            activeTickerCount = activeTickerCount - 1
        end
    end
    if activeTickerCount <= 0 then
        activeTickerCount = 0
        eventFrame:SetScript("OnUpdate", nil)
    end
end

eventFrame:SetScript("OnEvent", OnEvent)

function ns.Events:Register(event, callback, owner)
    owner = owner or callback
    if not listeners[event] then
        listeners[event] = {}
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    listeners[event][owner] = callback
end

function ns.Events:Unregister(event, owner)
    local bucket = listeners[event]
    if not bucket then
        return
    end
    bucket[owner] = nil
    if not next(bucket) then
        listeners[event] = nil
        pcall(eventFrame.UnregisterEvent, eventFrame, event)
    end
end

function ns.Events:RegisterCustom(event, callback, owner)
    owner = owner or callback
    if not customListeners[event] then
        customListeners[event] = {}
    end
    customListeners[event][owner] = callback
end

function ns.Events:FireCustom(event, ...)
    local bucket = customListeners[event]
    if not bucket then
        return
    end
    for owner, callback in pairs(bucket) do
        if type(callback) == "function" then
            callback(owner, event, ...)
        elseif type(owner) == "table" and type(owner[callback]) == "function" then
            owner[callback](owner, event, ...)
        end
    end
end

function ns.Events:RegisterTicker(id, fn)
    if not tickers[id] then
        activeTickerCount = activeTickerCount + 1
    end
    tickers[id] = fn
    if activeTickerCount == 1 then
        eventFrame:SetScript("OnUpdate", OnUpdate)
    end
end

function ns.Events:UnregisterTicker(id)
    if tickers[id] then
        tickers[id] = nil
        activeTickerCount = activeTickerCount - 1
        if activeTickerCount <= 0 then
            activeTickerCount = 0
            eventFrame:SetScript("OnUpdate", nil)
        end
    end
end
