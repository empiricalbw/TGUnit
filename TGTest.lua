TGTEST_UNIT_LIST = {"player", "pet",
                    "party1", "partypet1"}

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

function TGTestObject:UPDATE_BUFFS(unit)
    local buffStr = unit.id..":buffs are now ["
    for _, buff in ipairs(unit.buffs) do
        if buff.name then
            buffStr = buffStr..buff.name.."("..tostring(buff.auraType).."), "
        end
    end
    TGDbg(buffStr.."]")
end

function TGTestObject:UPDATE_DEBUFFS(unit)
    local debuffStr = unit.id..":debuffs are now ["
    for _, debuff in ipairs(unit.debuffs) do
        if debuff.name then
            debuffStr = debuffStr..debuff.name.."("..tostring(debuff.auraType).."), "
        end
    end
    TGDbg(debuffStr.."]")
end

function TGTestObject:UPDATE_COMBAT(unit)
    if unit.combat then
        TGDbg(unit.id..": is now in combat")
    else
        TGDbg(unit.id..": is no longer in combat")
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
