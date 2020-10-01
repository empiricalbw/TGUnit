TGTestObject = {}

function TGTestObject:UPDATE_NAME(unit)
    TGDbg(unit.id.." is now "..tostring(unit.name))
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
