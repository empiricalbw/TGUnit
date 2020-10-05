TGTEST_UNIT_LIST = {"target",
                    "player",
                    "pet",
                    "party1",
                    "partypet1",
                }

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

if false then
    function TGTestObject:UPDATE_HEALTH(unit)
        TGDbg(unit.id..":health is now ["..tostring(unit.health.current).."/"..
              tostring(unit.health.max).."]")
    end

    function TGTestObject:UPDATE_POWER(unit)
        TGDbg(unit.id..":power is now "..tostring(unit.power.type).."["..
              tostring(unit.power.current).."/"..tostring(unit.power.max).."]")
    end
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

function TGTestObject:UPDATE_PLAYER_SPELL(unit)
    TGDbg(unit.id..": player cast is now "..tostring(unit.playerCastInfo.spell))
end

function TGTestObject:UPDATE_COMBAT_SPELL(unit)
    TGDbg(unit.id..": log cast is now "..tostring(unit.logCastInfo.spell))
end

function TGTestObject:UPDATE_REACTION(unit)
    local str
    if unit.reaction == TGU.REACTION_FRIENDLY then
        str = "Friendly"
    elseif unit.reaction == TGU.REACTION_NEUTRAL then
        str = "Neutral"
    elseif unit.reaction == TGU.REACTION_HOSTILE then
        str = "Hostile"
    end
    TGDbg(unit.id..": reaction is "..tostring(str))
end

function TGTestObject:UPDATE_LEADER(unit)
    if unit.leader then
        TGDbg(unit.id..": is group leader")
    else
        TGDbg(unit.id..": is not group leader")
    end
end

function TGTestObject:UPDATE_RAIDICON(unit)
    TGDbg(unit.id..": raid icon is "..tostring(unit.raidIcon))
end

function TGTestObject:UPDATE_NPC(unit)
    if unit.npc then
        TGDbg(unit.id..": is an npc")
    elseif unit.npc ~= nil then
        TGDbg(unit.id..": is a pc")
    end
end

function TGTestObject:UPDATE_CLASSIFICATION(unit)
    if unit.classification ~= nil then
        TGDbg(unit.id..": classification is "..unit.classification)
    end
end

function TGTestObject:UPDATE_PVPSTATUS(unit)
    if unit.pvpStatus == TGU.PVP_NONE then
        TGDbg(unit.id..": pvp disabled")
    elseif unit.pvpStatus == TGU.PVP_FLAGGED then
        TGDbg(unit.id..": pvp flagged")
    elseif unit.pvpStatus == TGU.PVP_FFA_FLAGGED then
        TGDbg(unit.id..": pvp free-for-all")
    end
end

function TGTestObject:UPDATE_AFKSTATUS(unit)
    TGDbg(unit.id..": afk is "..tostring(unit.afkStatus))
end

function TGTestObject:UPDATE_LIVING(unit)
    if unit.living == TGU.LIVING_ALIVE then
        TGDbg(unit.id..": is alive")
    elseif unit.living == TGU.LIVING_DEAD then
        TGDbg(unit.id..": is dead")
    elseif unit.living == TGU.LIVING_GHOST then
        TGDbg(unit.id..": is a ghost")
    end
end

function TGTestObject:UPDATE_TAPPED(unit)
    TGDbg(unit.id..": tapped is "..tostring(unit.tapped))
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
