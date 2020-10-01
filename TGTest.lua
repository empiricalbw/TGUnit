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

function TGTestObject:UPDATE_POWER(unit)
    TGDbg(unit.id..":power is now "..tostring(unit.power.type).."["..
          tostring(unit.power.current).."/"..tostring(unit.power.max).."]")
end

TGTest = {}

function TGTest.PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
    TGDbg("PLAYER_ENTERING_WORLD isInitialLogin "..tostring(isInitialLogin)..
          " isReloadingUi "..tostring(isReloadingUi))

    if isInitialLogin or isReloadingUi then
        TGUnit:new("player"):AddListener(TGTestObject)
        TGUnit:new("target"):AddListener(TGTestObject)
        TGUnit:new("targettarget"):AddListener(TGTestObject)
    end
end

TGEventHandler.Register(TGTest)
