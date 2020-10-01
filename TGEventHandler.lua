TGEventHandler = {}

TGEventHandler.tgehFrame       = nil
TGEventHandler.eventListeners  = {}
TGEventHandler.updateListeners = {}

function TGEventHandler.Initialize()
    -- A dummy frame to get us the events we are interested in.
    TGEventHandler.tguFrame = CreateFrame("Frame")
    TGEventHandler.tguFrame:SetScript("OnEvent",TGEventHandler.OnEvent)
    TGEventHandler.tguFrame:SetScript("OnUpdate",TGEventHandler.OnUpdate)
end

function TGEventHandler.Register(obj)
    -- All keys in obj that are completely uppercase are assumed to be event
    -- handler static methods.  If an "OnUpdate" method exists, it is also
    -- registered and assumed to be a static method.
    for k in pairs(obj) do
        if string.upper(k) == k then
            TGEventHandler.tguFrame:RegisterEvent(k)
            if TGEventHandler.eventListeners[k] == nil then
                TGEventHandler.eventListeners[k] = {}
            end
            table.insert(TGEventHandler.eventListeners[k], obj)
        end
    end

    if obj["OnUpdate"] ~= nil then
        table.insert(TGEventHandler.updateListeners, obj)
    end
end

function TGEventHandler.OnEvent(frame, event, ...)
    for _, el in ipairs(TGEventHandler.eventListeners[event]) do
        el[event](...)
    end
end

function TGEventHandler.OnUpdate()
    for _, ul in ipairs(TGEventHandler.updateListeners) do
        ul.OnUpdate()
    end
end

TGEventHandler.Initialize()
