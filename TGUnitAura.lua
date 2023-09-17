-- Anatomy of a spellcast.  Here's Eye of Kilrogg, which starts with a cast and
-- then switches to channeling:
--
--  Frame   Event                           Valid
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_START            castGUID, spellID
--  1       UNIT_SPELLCAST_DELAYED          castGUID, spellID (on damage)
--          (Note: no UNIT_SPELLCAST_STOP)
--  2       UNIT_SPELLCAST_CHANNEL_START    spellID
--  2       UNIT_SPELLCAST_SUCCEEDED        castGUID, spellID
--  2       CLEU_SPELL_CAST_SUCCESS         sourceGUID, targetGUID, spellName
--  3       UNIT_SPELLCAST_CHANNEL_STOP     spellID
--
-- Here's Drain Soul, which is purely channeled:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_CHANNEL_START    spellID
--  0       UNIT_SPELLCAST_SUCCEEDED        castGUID, spellID
--  0       CLEU_SPELL_CAST_SUCCESS         sourceGUID, targetGUID, spellName
--  1       UNIT_SPELLCAST_CHANNEL_UPDATE   spellID (on damage)
--  2       UNIT_SPELLCAST_CHANNEL_STOP     spellID
--
-- Here's Soul Fire, which is purely cast:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_START            castGUID, spellID
--  1       UNIT_SPELLCAST_DELAYED          castGUID, spellID (on damage)
--  2       UNIT_SPELLCAST_SUCCEEDED        castGUID, spellID
--  2       UNIT_SPELLCAST_STOP             castGUID, spellID
--  2       CLEU_SPELL_CAST_SUCCESS         sourceGUID, targetGUID, spellName
--
-- Here's Fireball, which is cast, has travel time and then finally applies a
-- debuff and damages the target:
--
--  0       UNIT_SPELLCAST_SENT
--  0       UNIT_SPELLCAST_START
--  0       CLEU_SPELL_CAST_START
--  1       UNIT_SPELLCAST_SUCCEEDED
--  1       UNIT_SPELLCAST_STOP
--  1       CLEU_SPELL_CAST_SUCCESS
--  2       CLEU_SPELL_AURA_APPLIED
--  2       CLEU_SPELL_CAST_DAMAGE
--
-- Here's Shadow Word: Pain, which is instant cast, has no travel time and then
-- finally applies a debuff but no direct damage to the target:
--
--  0       UNIT_SPELLCAST_SENT
--  0       UNIT_SPELLCAST_SUCCEEDED
--  0       CLEU_SPELL_CAST_SUCCESS
--  0       CLEU_SPELL_AURA_APPLIED
--
-- Here's Shadow Word: Pain, but when the aura already exists on the target:
--
--  0       UNIT_SPELLCAST_SENT
--  0       UNIT_SPELLCAST_SUCCEEDED
--  0       CLEU_SPELL_CAST_SUCCESS
--  0       CLEU_SPELL_AURA_REFRESH
--
-- Here's Shadow Word: Pain, but when it is resisted.
--
--  0       UNIT_SPELLCAST_SENT
--  0       UNIT_SPELLCAST_SUCCEEDED
--  0       CLEU_SPELL_CAST_SUCCESS
--  0       CLEU_SPELL_MISSED
--
-- The difference here is that CLEU_SPELL_AURA_APPLIED/REFRESH is replaced with
-- CLEU_SPELL_MISSED.
--
-- Here's Summon Imp, which is purely cast with no offensive component:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_START            castGUID, spellID
--  1       UNIT_SPELLCAST_SUCCEEDED        castGUID, spellID
--  1       UNIT_SPELLCAST_STOP             castGUID, spellID
--  1       CLEU_SPELL_CAST_SUCCESS         sourceGUID, spellName
--
-- Here's Summon Imp, but interrupt by moving before it completes:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_START            castGUID, spellID
--  1       UNIT_SPELLCAST_INTERRUPTED      castGUID, spellID
--  1       UNIT_SPELLCAST_STOP             castGUID, spellID
--  2       UNIT_SPELLCAST_INTERRUPTED      castGUID, spellID
--  2       UNIT_SPELLCAST_INTERRUPTED      castGUID, spellID
--  2       UNIT_SPELLCAST_INTERRUPTED      castGUID, spellID
--
-- Here's Create Healthstone (Greater), which doesn't even have a visible non-
-- player component:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_START            castGUID, spellID
--  1       UNIT_SPELLCAST_SUCCEEDED        castGUID, spellID
--  1       UNIT_SPELLCAST_STOP             castGUID, spellID
--  1       CLEU_SPELL_CAST_SUCCESS         sourceGUID, spellName
--
-- Here's Create Healthstone (Greater) when you already have one in your
-- inventory:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_FAILED           castGUID, spellID (different!?)
--  0       UNIT_SPELLCAST_FAILED_QUIET     castGUID, spellID
--
-- Here's Siphon Life, which is an instant cast with a DoT component:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_SUCCEEDED        castGUID, spellID
--  0       CLEU_SPELL_CAST_SUCCESS         sourceGUID, targetGUID, spellName
--  0       CLEU_SPELL_AURA_APPLIED         sourceGUID, targetGUID, spellName
--
-- Here's Drain Soul, which is a channeled spell with a DoT component:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_CHANNEL_START    spellID
--  0       CLEU_SPELL_AURA_APPLIED         (self Drain Soul BUFF)
--  0       UNIT_SPELLCAST_SUCCEEDED        castGUID, spellID
--  0       CLEU_SPELL_CAST_SUCCESS         sourceGUID, targetGUID, spellName
--  1       CLEU_SPELL_AURA_APPLIED         sourceGUID, targetGUID, spellName
--  2       UNIT_SPELLCAST_CHANNEL_STOP     spellID
--
-- Here's what we get when a Defias Rogue Wizard hits me with a Frostbolt:
--
--  0       CLEU_SPELL_CAST_START           sourceGUID, spellName
--  1       CLEU_SPELL_CAST_SUCCESS         sourceGUID, targetGUID, spellName
--  2       CLEU_SPELL_DAMAGE               sourceGUID, targetGUID, spellName
--
-- And when he misses:
--
--  0       CLEU_SPELL_CAST_START           sourceGUID, spellName
--  1       CLEU_SPELL_CAST_SUCCESS         sourceGUID, targetGUID, spellName
--  2       CLEU_SPELL_MISSED               sourceGUID, targetGUID, spellName
--
-- So for mob spell notification, we should just watch for SPELL_CAST_START and
-- SPELL_CAST_SUCCESS.  Note that if I fear the mob while it is casting, there
-- is no CLEU notification that the mob's cast failed.
--
-- For reference, UnitAura() returns something like this:
--
--      /dump UnitAura("target", 3)
--      [1] = "Power Word: Fortitude", -- name
--      [2] = 135987,     -- icon
--      [3] = 0,          -- count
--      [4] = "Magic",    -- dispelType
--      [5] = 3600,       -- duration
--      [6] = 112994.871, -- expirationTime 
--      [7] = "player",   -- source
--      [8] = false,      -- isStealable
--      [9] = false,      -- nameplateShowPersonal
--      [10] = 21562,     -- spellID
--      [11] = true,      -- canApplyAura
--      [12] = false,     -- isBossDebuff
--      [13] = true,      -- castByPlayer
--      [14] = false,     -- nameplateShowAll
--      [15] = 1,         -- timeMod
--
-- source can be nil and probably we shouldn't keep track of anything except
-- if the source was "player".

TGUA_TRACKED_AURAS_DB = {version = 1, realms = {}}

local TGUA = {
    -- tracked_spells is a two-level hash.  The first key is a target GUID,
    -- and the second key is a spell name.
    tracked_spells = {},
    cast_frame     = nil,
    spell_frames   = {},
    log_level      = 1,
    log            = TGLog:new(1, 2),
    log_timestamp  = nil,

    event_casts    = {},
    cleu_casts     = {},
    aura_updates   = {},
}
TGUnit.AuraTracker = TGUA

-- A type to keep track of casts generated via UNIT_SPELLCAST events.
local TGUnitEventCast = {}
TGUnitEventCast.__index = TGUnitEventCast
TGUnitEventCast.free_casts = {}

function TGUnitEventCast:new(timestamp, castGUID, spellID)
    -- Event cast timestamps are as returned from GetTime().
    local cast
    if #TGUnitEventCast.free_casts > 0 then
        cast = table.remove(TGUnitEventCast.free_casts)
        assert(cast.allocated == false)
    else
        cast = {}
        setmetatable(cast, self)
    end

    cast.allocated  = true
    cast.timestamp  = timestamp
    cast.castGUID   = castGUID
    cast.spellID    = spellID
    cast.spellName  = GetSpellInfo(spellID)
    cast.duration   = TGUnit.AuraDB.AuraDurations[spellID]

    return cast
end

function TGUnitEventCast:free()
    assert(self.allocated == true)
    self.allocated = false
    table.insert(TGUnitEventCast.free_casts, self)
end

-- A type to keep track of casts generated via CLEU events.
local TGUnitCLEUCast = {}
TGUnitCLEUCast.__index = TGUnitCLEUCast
TGUnitCLEUCast.free_casts = {}

function TGUnitCLEUCast:new(timestamp, event, targetGUID, targetName, spellName)
    -- CLEU timestamps are Unix time.
    local cast
    if #TGUnitCLEUCast.free_casts > 0 then
        cast = table.remove(TGUnitCLEUCast.free_casts)
        assert(cast.allocated == false)
    else
        cast = {}
        setmetatable(cast, self)
    end

    cast.allocated    = true
    cast.timestamp    = timestamp
    cast.gt_timestamp = GetTime()
    cast.event        = event
    cast.targetGUID   = targetGUID
    cast.targetName   = targetName
    cast.spellName    = spellName

    return cast
end

function TGUnitCLEUCast:free()
    assert(self.allocated == true)
    self.allocated = false
    table.insert(TGUnitCLEUCast.free_casts, self)
end

function TGUnitCLEUCast:dump()
    assert(self.allocated == true)
    print("["..self.timestamp.."] "..self.event..": ".." "..self.spellName..
          " cast on "..self.targetName.." "..self.targetGUID)
end

-- An amalgamated type that merges information from the CLEU cast and from the
-- event cast.
local TGUnitCast = {}
TGUnitCast.__index = TGUnitCast
TGUnitCast.free_casts = {}

function TGUA.ADDON_LOADED(addOnName)
    if addOnName ~= "TGUnit" then
        return
    end

    local rf = GetRealmName()..":"..UnitFactionGroup("player")
    local ts = TGUA_TRACKED_AURAS_DB.realms[rf] or {}
    TGUA.tracked_spells = ts
    TGUA_TRACKED_AURAS_DB.realms[rf] = ts
    for targetGUID, targetCasts in pairs(ts) do
        for spellName, targetCast in pairs(targetCasts) do
            assert(TGUnitCast ~= nil)
            setmetatable(targetCast, TGUnitCast)
        end
    end
end

function TGUnitCast:new(event_cast, cleu_cast)
    assert(event_cast.timestamp == cleu_cast.gt_timestamp)

    local cast
    if #TGUnitCast.free_casts > 0 then
        cast = table.remove(TGUnitCast.free_casts)
        assert(cast.allocated == false)
    else
        cast = {}
        setmetatable(cast, self)
    end

    cast.allocated      = true
    cast.auraApplied    = false
    cast.timestamp      = event_cast.timestamp
    cast.unix_timestamp = cleu_cast.timestamp
    cast.castGUID       = event_cast.castGUID
    cast.spellID        = event_cast.spellID
    cast.spellName      = event_cast.spellName
    cast.auraDuration   = event_cast.duration
    cast.targetGUID     = cleu_cast.targetGUID
    cast.targetName     = cleu_cast.targetName

    return cast
end

function TGUnitCast:free()
    assert(self.allocated == true)
    self.allocated = false
    table.insert(TGUnitCast.free_casts, self)
end

function TGUA.TrackCast(cast)
    local targetCasts = TGUA.tracked_spells[cast.targetGUID]
    if targetCasts == nil then
        targetCasts = {}
        TGUA.tracked_spells[cast.targetGUID] = targetCasts
    end

    local targetCast = targetCasts[cast.spellName]
    if targetCast ~= nil then
        targetCast:free()
    end

    targetCasts[cast.spellName] = cast
end

function TGUA.PurgeGUID(guid)
    local targetCasts = TGUA.tracked_spells[guid]
    if targetCasts == nil then
        return
    end

    for _, v in pairs(targetCasts) do
        v:free()
    end
    TGUA.tracked_spells[guid] = nil
end

--[[
function TGUnitCast.PurgeAndFreeCast(cast)
    local targetCasts = TGUA.tracked_spells[cast.targetGUID]
    if targetCasts ~= nil then
        if targetCasts[cast.spellName] == cast then
            targetCasts[cast.spellName] = nil
            if next(targetCasts) == nil then
                TGUA.tracked_spells[cast.targetGUID] = nil
            end
        end
    end
    cast:free()
end
]]

function TGUA.PurgeExpiredCasts()
    local currTime = GetTime()
    for targetGUID, targetCasts in pairs(TGUA.tracked_spells) do
        for spellName, targetCast in pairs(targetCasts) do
            if (targetCast.timestamp + targetCast.auraDuration + 10 <= currTime)
            then
                targetCasts[spellName] = nil
                targetCast:free()
            end
        end
        if next(targetCasts) == nil then
            TGUA.tracked_spells[targetGUID] = nil
        end
    end
end

local function dbg(...)
    local timestamp = GetTime()
    if timestamp ~= TGUA.log_timestamp then
        TGUA.log_timestamp = timestamp
        TGUA.log:log(TGUA.log_level, " ")
    end
    TGUA.log:log(TGUA.log_level, "[", timestamp, "] ", ...)
end

function TGUA.PushEventCast(cast)
    dbg("Pushing event cast: "..cast.spellName)
    table.insert(TGUA.event_casts, cast)
end

function TGUA.PushCLEUCast(cast)
    dbg("Pushing CLEU cast: "..cast.spellName)
    if cast.event ~= "SPELL_CAST_SUCCESS" then
        -- This means we got a SPELL_MISSED event some time after a successful
        -- cast.  A cast can be both successful and miss, so we need to replace
        -- the previously-queued cast with a miss.
        if #TGUA.cleu_casts == 0 then
            cast:dump()
        else
            local last_cast = TGUA.cleu_casts[#TGUA.cleu_casts]
            assert(last_cast.timestamp  == cast.timestamp)
            assert(last_cast.targetGUID == cast.targetGUID)
            assert(last_cast.spellName  == cast.spellName)
            print("PushCLEUCast: Replacing "..last_cast.spellName.." "..
                  last_cast.event.." with "..cast.event)
            last_cast.event = cast.event
        end
    else
        table.insert(TGUA.cleu_casts, cast)
    end
end

function TGUA.ProcessCastFIFO()
    if #TGUA.event_casts == 0 or #TGUA.cleu_casts == 0 then
        return
    end

    local event_cast = table.remove(TGUA.event_casts, 1)
    local cleu_cast  = table.remove(TGUA.cleu_casts, 1)
    if event_cast.spellName ~= cleu_cast.spellName then
        print(event_cast.spellName)
        print(cleu_cast.spellName)
    end
    assert(event_cast.spellName == cleu_cast.spellName)
    if event_cast.timestamp ~= cleu_cast.gt_timestamp then
        print("event_cast.timestamp "..event_cast.timestamp..
              " cleu_cast.timestamp "..cleu_cast.timestamp..
              " cleu_cast.gt_timestamp "..cleu_cast.gt_timestamp)
    end
    assert(event_cast.timestamp == cleu_cast.gt_timestamp)

    if cleu_cast.event ~= "SPELL_CAST_SUCCESS" then
        print("ProcessCastFIFO: CLEU event was "..cleu_cast.event)
        event_cast:free()
        cleu_cast:free()
        return
    end

    local cast = TGUnitCast:new(event_cast, cleu_cast)
    TGUA.TrackCast(cast)
    event_cast:free()
    cleu_cast:free()

    -- Notify the core that a tracked spell has changed.
    TGUnit.TrackedAurasChanged(cast.targetGUID)
end

function TGUA.DumpCastFIFO()
    print("*** Event casts ***")
    for _, v in ipairs(TGUA.event_casts) do
        print("   "..v.spellName)
    end

    print("*** CLEU casts ***")
    for _, v in ipairs(TGUA.cleu_casts) do
        print("   "..v.spellName)
    end
end

function TGUA.ProcessAuraUpdates()
    if #TGUA.aura_updates == 0 then
        return
    end

    for _, v in ipairs(TGUA.aura_updates) do
        local cast = TGUA.GetCastBySpellName(v.targetGUID, v.spellName)
        if cast ~= nil then
            if v.refresh or not cast.auraApplied then
                --print("Found cast for: ", v.spellName)
                cast.timestamp = v.timestamp
                cast.auraApplied = true
                TGUnit.TrackedAurasChanged(v.targetGUID)
            end
        else
            --print("No cast for: ", v.spellName)
        end
    end
    TGUA.aura_updates = {}
end

function TGUA.UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
    if unit ~= "player" then
        return
    end

    dbg("UNIT_SPELLCAST_SUCCEEDED unit: ", unit, " castGUID: ", castGUID,
        " spellID: ", spellID)

    -- Push the spellcast if we care about it.
    local event_cast = TGUnitEventCast:new(GetTime(), castGUID, spellID)
    if event_cast.duration then
        TGUA.PushEventCast(event_cast)
    else
        event_cast:free()
    end
end

function TGUA.CLEU_SPELL_CAST_SUCCESS(cleu_timestamp, _, sourceGUID, _, _, _,
                                       targetGUID, targetName, _, _, _,
                                       spellName, _)
    dbg("CLEU_SPELL_CAST_SUCCESS sourceGUID: ", sourceGUID, " targetGUID: ",
        targetGUID, " targetName: ", targetName, " spellName: ", spellName)
    if sourceGUID ~= UnitGUID("player") then
        return
    end

    if TGUnit.AuraDB.AuraNames[spellName] then
        local cleu_cast = TGUnitCLEUCast:new(cleu_timestamp,
                                             "SPELL_CAST_SUCCESS", targetGUID,
                                             targetName, spellName)
        TGUA.PushCLEUCast(cleu_cast)
    end
end

function TGUA.CLEU_SPELL_CAST_FAILED(cleu_timestamp, _, sourceGUID, _, _, _,
                                     targetGUID, targetName, _, _, _,
                                     spellName, _, failedType)
    dbg("CLEU_SPELL_CAST_FAILED sourceGUID: ", sourceGUID, " targetGUID: ",
        targetGUID, " targetName: ", targetName, " spellName: ", spellName,
        " failedType: ", failedType)
end

function TGUA.CLEU_SPELL_MISSED(cleu_timestamp, _, sourceGUID, _, _, _,
                                 targetGUID, targetName, _, _, _,
                                 spellName, _, missType, isOffHand,
                                 amountMissed, critical)
    dbg("CLEU_SPELL_MISSED sourceGUID: ", sourceGUID, " targetGUID: ",
        targetGUID, " targetName: ", targetName, " spellName: ", spellName,
        " missType: ", missType, " isOffHand: ", isOffHand, " amountMissed: ",
        amountMissed, " critical: ", critical)
    if sourceGUID ~= UnitGUID("player") then
        return
    end

    if TGUnit.AuraDB.AuraNames[spellName] then
        local cleu_cast = TGUnitCLEUCast:new(cleu_timestamp, "SPELL_MISSED",
                                             targetGUID, targetName, spellName)
        TGUA.PushCLEUCast(cleu_cast)
    end
end

function TGUA.CLEU_SPELL_AURA_APPLIED(cleu_timestamp, _, sourceGUID, _, _, _,
                                      targetGUID, targetName, _, _, spellId,
                                      spellName, _, auraType, amount)
    if sourceGUID ~= UnitGUID("player") then
        return
    end
    dbg("CLEU_SPELL_AURA_APPLIED sourceGUID: ", sourceGUID, " targetGUID: ",
        targetGUID, " targetName: ", targetName, " spellID: ", spellID,
        " spellName: ", spellName, " auraType: ", auraType, " amount: ", amount)

    table.insert(TGUA.aura_updates, {targetGUID = targetGUID,
                                     spellName = spellName,
                                     timestamp = GetTime(),
                                     refresh = false})
end

function TGUA.CLEU_SPELL_AURA_REFRESH(cleu_timestamp, _, sourceGUID, _, _, _,
                                      targetGUID, targetName, _, _, spellId,
                                      spellName, _, auraType, amount)
    dbg("CLEU_SPELL_AURA_REFRESH sourceGUID: ", sourceGUID, " targetGUID: ",
        targetGUID, " targetName: ", targetName, " spellID: ", spellID,
        " spellName: ", spellName, " auraType: ", auraType, " amount: ", amount)
    if sourceGUID ~= UnitGUID("player") then
        return
    end

    table.insert(TGUA.aura_updates, {targetGUID = targetGUID,
                                     spellName = spellName,
                                     timestamp = GetTime(),
                                     refresh = true})
end
                      
function TGUA.CLEU_UNIT_DIED(cleu_timestamp, _, _, _, _, _, targetGUID,
                              targetName)
    dbg("CLEU_UNIT_DIED targetGUID: ", targetGUID, " targetName: ", targetName)
    TGUA.PurgeGUID(targetGUID)
end

function TGUA.OnUpdate()
    -- Process the cast FIFO.
    TGUA.ProcessCastFIFO()

    -- Process aura updates.
    TGUA.ProcessAuraUpdates()

    -- Remove expired casts.
    TGUA.PurgeExpiredCasts()
end

function TGUA.GetCastBySpellName(targetGUID, spellName)
    local targetCasts = TGUA.tracked_spells[targetGUID]
    if targetCasts ~= nil then
        return targetCasts[spellName]
    end

    return nil
end

function TGUA.GetAuraInfoBySpellID(targetGUID, spellID)
    local targetCasts = TGUA.tracked_spells[targetGUID]
    if targetCasts == nil then
        return 0, 0
    end

    if spellID == nil then
        return 0, 0
    end

    local spellName = GetSpellInfo(spellID)
    if spellName == nil then
        return 0, 0
    end

    local cast = targetCasts[spellName]
    if cast == nil then
        return 0, 0
    end

    return cast.auraDuration, cast.timestamp + cast.auraDuration
end

function TGUA.DebugToggle()
    if TGUA.log_level == 1 then
        TGUA.log_level = 2
    else
        TGUA.log_level = 1
    end
end

function TGUA.TargetInfo()
    local guid = UnitGUID("target")
    if guid == nil then
        return
    end

    local targetCasts = TGUA.tracked_spells[guid]
    if targetCasts ~= nil then
        for name, cast in pairs(targetCasts) do
            print(name, ":", cast.timestamp + cast.auraDuration - GetTime())
        end
    end
end

TGEventManager.Register(TGUA)

SlashCmdList["TGUADBG"] = TGUA.DebugToggle
SLASH_TGUADBG1 = "/tguadbg"

SlashCmdList["TGUAINFO"] = TGUA.TargetInfo
SLASH_TGUAINFO1 = "/tguainfo"
