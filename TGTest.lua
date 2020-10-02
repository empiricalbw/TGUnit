TGTEST_UNIT_LIST = {"target"}

TGTestObject = {}

function TGTestObject:UPDATE_EXISTS(unit)
    if unit.exists then
        TGDbg(unit.id.." now exists")
    else
        TGDbg(unit.id.." no longer exists")
    end
end

function TGTestObject:UPDATE_GUID(unit)
    TGDbg(unit.id..":GUID is now "..tostring(unit.guid))
end

function TGTestObject:UPDATE_NAME(unit)
    TGDbg(unit.id..":name is now "..tostring(unit.name))
end

function TGTestObject:UPDATE_HEALTH(unit)
    TGDbg(unit.id..":health is now ["..tostring(unit.health.current).."/"..
          tostring(unit.health.max).."]")
end

function TGTestObject:UPDATE_POWER(unit)
    TGDbg(unit.id..":power is now "..tostring(unit.power.type).."["..
          tostring(unit.power.current).."/"..tostring(unit.power.max).."]")
end

function TGTestObject:UPDATE_LEVEL(unit)
    TGDbg(unit.id..":level is now "..tostring(unit.level))
end

function TGTestObject:UPDATE_ISPLAYERTARGET(unit)
    if unit.isPlayerTarget then
        TGDbg(unit.id..": is player target")
    else
        TGDbg(unit.id..": is no longer player target")
    end
end

TGTest = {}

function TGTest.PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
    TGDbg("PLAYER_ENTERING_WORLD isInitialLogin "..tostring(isInitialLogin)..
          " isReloadingUi "..tostring(isReloadingUi))

    if isInitialLogin or isReloadingUi then
        for _, u in ipairs(TGTEST_UNIT_LIST) do
            TGUnit:new(u):AddListener(TGTestObject)
        end
    end
end

TGEventHandler.Register(TGTest)
