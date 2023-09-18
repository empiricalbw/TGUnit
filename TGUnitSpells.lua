-- This is a database of all the spells we have seen for all types of creature.
-- The first key is the creature name and then the subkey is the spell name.
TGUS_TRACKED_SPELLS_DB = {}
TGUS_TRACKED_PLAYER_SPELLS_DB = {}

local TGUS = {
    tracked_spells = {},
}
TGUnit.SpellTracker = TGUS

function TGUS.GetNPCInfo(guid, name, insert)
    local decodedGUID = {strsplit("-", guid)}
    local database
    local npcID
    if decodedGUID[1] == "Player" then
        database = TGUS_TRACKED_PLAYER_SPELLS_DB
        npcID = guid
    elseif decodedGUID[1] == "Creature" then
        database = TGUS_TRACKED_SPELLS_DB
        npcID = decodedGUID[6]
    else
        return nil
    end

    local npcInfo = database[npcID]
    if npcInfo == nil then
        if not insert then
            return nil
        end

        npcInfo = {
            name   = name,
            spells = {},
        }
        database[npcID] = npcInfo
    end

    return npcInfo
end

function TGUS.GetSpellInfo(sourceGUID, sourceName, spellName)
    local npcInfo = TGUS.GetNPCInfo(sourceGUID, sourceName, true)
    local spellInfo = npcInfo.spells[spellName]
    if spellInfo == nil then
        spellInfo = {
            name     = spellName,
            castTime = nil,
        }
        npcInfo.spells[spellName] = spellInfo
    end

    return spellInfo
end

function TGUS.GetUnitCast(unitGUID)
    if unitGUID == nil then
        return nil
    end
    return TGUS.tracked_spells[unitGUID]
end

function TGUS.TrackCast(cast)
    local oldCast = TGUS.tracked_spells[cast.sourceGUID]
    if oldCast ~= nil then
        oldCast:free()
    end

    TGUS.tracked_spells[cast.sourceGUID] = cast

    --[[
    local castTime = cast.spellInfo.castTime or "unknown"
    if cast.spellInfo.castTime ~= nil then
        print(cast.sourceName, " is casting ", cast.spellInfo.name,
              " with an expected duration of ", cast.spellInfo.castTime,
              " sec.")
    else
        print(cast.sourceName, " is casting ", cast.spellInfo.name,
              " with an unknown duration.")
    end
    ]]

    --TGUnit.TrackedSpellcastChanged(cast)
end

function TGUS.UntrackCast(cast)
    TGUS.tracked_spells[cast.sourceGUID] = nil
end

-- A type to keep track of casts generated via CLEU events.
local TGUnitCLEUCast = {}
TGUnitCLEUCast.__index = TGUnitCLEUCast
TGUnitCLEUCast.free_casts = {}

function TGUnitCLEUCast:new(cleu_timestamp, sourceGUID, sourceName, targetName,
                            spellInfo)
    -- CLEU timestamps are Unix time.
    local cast
    if #TGUnitCLEUCast.free_casts > 0 then
        cast = table.remove(TGUnitCLEUCast.free_casts)
        assert(cast.allocated == false)
    else
        cast = {}
        setmetatable(cast, self)
    end

    cast.allocated      = true
    cast.timestamp      = GetTime()
    cast.cleu_timestamp = cleu_timestamp
    cast.sourceGUID     = sourceGUID
    cast.sourceName     = sourceName
    cast.targetName     = targetName
    cast.spellInfo      = spellInfo

    return cast
end

function TGUnitCLEUCast:free()
    assert(self.allocated == true)
    self.allocated = false
    table.insert(TGUnitCLEUCast.free_casts, self)
end

function TGUS.CLEU_SPELL_CAST_START(cleu_timestamp, _, sourceGUID, sourceName,
                                    _, _, _, _, _, _, _, spellName, _)
    local spellInfo = TGUS.GetSpellInfo(sourceGUID, sourceName, spellName)
    if spellInfo == nil then
        return
    end

    --print("Cast started.)
    local cast = TGUnitCLEUCast:new(cleu_timestamp, sourceGUID, sourceName,
                                    targetName, spellInfo)
    TGUS.TrackCast(cast)
end

function TGUS.CLEU_SPELL_CAST_SUCCESS(cleu_timestamp, _, sourceGUID, _, _, _,
                                       targetGUID, targetName, _, _, _,
                                       spellName, _)
    local cast = TGUS.tracked_spells[sourceGUID]
    if cast == nil then
        --print("No cast for GUID ", sourceGUID)
        return
    end

    --print("Cast success.")
    if cast.spellInfo.name == spellName then
        --print("Cast matched.")
        local elapsed = GetTime() - cast.timestamp
        local spellInfo = cast.spellInfo
        if spellInfo.castTime == nil or elapsed < 100 then
            --print("Updating cast time to ", elapsed)
            spellInfo.castTime = elapsed
        end
    else
        print("Cast didn't match.", targetGUID, cast.spellInfo.name, spellName)
    end

    TGUS.UntrackCast(cast)
    cast:free()
end

function TGUS.CLEU_SPELL_INTERRUPT(cleu_timestamp, _, sourceGUID, _, _, _,
                                   targetGUID, targetName, _, _, _,
                                   interruptName, _, _, spellName, _)
    local cast = TGUS.tracked_spells[targetGUID]
    if cast ~= nil then
        --print("Cast interrupted.")
        TGUS.UntrackCast(cast)
        cast:free()
    end
end

function TGUS.CLEU_SPELL_CAST_FAILED(cleu_timestamp, _, sourceGUID, _, _, _,
                                     targetGUID, targetName, _, _, _,
                                     spellName, _, failedType)
    local cast = TGUS.tracked_spells[sourceGUID]
    if cast ~= nil then
        --print("Cast failed.")
        TGUS.UntrackCast(cast)
        cast:free()
    end
end

function TGUS.CLEU_UNIT_DIED(cleu_timestamp, _, _, _, _, _, unitGUID, unitName)
    local cast = TGUS.tracked_spells[unitGUID]
    if cast ~= nil then
        --print("Cast target died.")
        TGUS.UntrackCast(cast)
        cast:free()
    end
end

function TGUS.OnUpdate()
    local t = GetTime()
    for sourceGUID, cast in pairs(TGUS.tracked_spells) do
        if t - cast.timestamp > 100 then
            print("Purging cast ", cast.sourceGUID, " ", cast.spellInfo.name)
            TGUS.UntrackCast(cast)
            cast:free()
        end
    end
end

function TGUS.TargetInfo()
    local guid = UnitGUID("target")
    if guid == nil then
        return
    end

    local name = UnitName("target")
    local npcInfo = TGUS.GetNPCInfo(guid, name, false)
    if npcInfo ~= nil then
        if next(npcInfo.spells) == nil then
            print("NPC", name, "has no known spells.")
        else
            print("Spell info for NPC", name, ":")
            for k, v in pairs(npcInfo.spells) do
                print(k, ":", v.castTime)
            end
        end
    else
        print("No info for NPC", name)
    end
end

TGEventManager.Register(TGUS)

SlashCmdList["TGUSINFO"] = TGUS.TargetInfo
SLASH_TGUSINFO1 = "/tgusinfo"
