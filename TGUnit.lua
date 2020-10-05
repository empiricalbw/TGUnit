-- Whether or not to enable this experimental library.
local TGU_LIB_ENABLED = true

-- TGUnit is a class that is used to monitor a unit ID and to emit events when
-- that unit ID's state changes
TGUnit = {}
TGUnit.__index = TGUnit

-- The timestamp when we last polled all units.
TGUnit.lastPoll = 0

-- The set of TGUnits that have been instantiated.  This is keyed by unit ID
-- and if the same unit is "instantiated" twice the second instance will be
-- the same as the first.
TGUnit.unitList = {}

-- A mapping of unit GUIDs to a table of TGUnits keyed by TGUnit.  For
-- instance you could have this if a player was targeting themselves:
--
--      TGUnit.guidList = {
--          ["1234-5678-ABCD"] = {
--              TGUnit("target") = TGUnit("target"),
--              TGUnit("player") = TGUnit("player"),
--          }
--      }
--
-- This list is mainly used for parsing the combat log for spellcast started
-- events.  Since the combat log doesn't include spellcast stop events, we just
-- parse the start event and allow the client to "pulse" the spell name for a
-- second or two.
TGUnit.guidList = {}

-- The frame that we will use to listen to events and updates.
TGUnit.tguFrame = nil

-- The time at which we entered the world.
TGUnit.enteredWorldTime = nil

-- The spell we should use to detect if units are in healing range or not.
TGUnit.healingRangeSpell = nil

-- A mapping of roster (party and raid unit ids) to GUIDs, uniquely identifying
-- members of the raid and party.
TGUnit.rosterGUIDs = {}

-- Utility function for bitmasks.
local function btst(mask1,mask2)
    return bit.band(mask1,mask2) ~= 0
end

-- Utility function for printing events.
local function TGEvt(str)
    --TGDbg(str)
end

-- Meta-getters for many unit properties we care about.
local function UnitIsPlayerTarget(unitId)
    return UnitIsUnit(unitId, "target")
end

local function UnitGetReaction(unitId)
    if UnitIsFriend(unitId, "player") then
        return TGU.REACTION_FRIENDLY
    elseif UnitIsEnemy(unitId, "player") then
        return TGU.REACTION_HOSTILE
    end
    return TGU.REACTION_NEUTRAL
end

local function UnitIsNPC(unitId)
    return not UnitIsPlayer(unitId)
end

local function UnitGetPVPStatus(unitId)
    -- These return false if the unit doesn't exist, so we do an existence
    -- check first.
    if UnitIsPVPFreeForAll(unitId) then
        return TGU.PVP_FFA_FLAGGED
    elseif UnitIsPVP(unitId) then
        return TGU.PVP_FLAGGED
    end
    return TGU.PVP_NONE
end

local function UnitGetLivingStatus(unitId)
    if UnitIsGhost(unitId) then
        return TGU.LIVING_GHOST
    elseif UnitIsDead(unitId) then
        return TGU.LIVING_DEAD
    end
    return TGU.LIVING_ALIVE
end

local function UnitGetIsVisible(unitId)
    return UnitIsVisible(unitId) == true
end

local function UnitGetInHealingRange(unitId)
    if not TGUnit.healingRangeSpell then
        return nil
    end

    return IsSpellInRange(TGUnit.healingRangeSpell, unitId) == 1
end

-- Instantiate a new TGUnit.  If the unit already exists, return it instead.
function TGUnit:new(id)
    assert(id)
    if id == "template" then
        return TGU.TEMPLATE_UNIT
    end
    if TGUnit.unitList[id] then
        return TGUnit.unitList[id]
    end

    local unit = {}
    setmetatable(unit, self)
    unit:TGUnit(id)
    TGUnit.unitList[id] = unit
    return unit
end

-- Construct a TGUnit.
function TGUnit:TGUnit(id)
    self.id             = id
    self.allFlags       = TGU.ALLFLAGS[id] or TGU.ALL_NONPLAYER_FLAGS
    self.pollFlags      = TGU.POLLFLAGS[id] or TGU.ALL_NONPLAYER_FLAGS
    self.exists         = false
    self.isPlayerTarget = nil
    self.name           = nil
    self.class          = {localizedClass=nil,englishClass=nil}
    self.creatureType   = nil
    self.health         = {current=nil,max=nil}
    self.power          = {type=nil,current=nil,max=nil}
    self.playerCastInfo = {}
    self.logCastInfo    = {}
    self.level          = nil
    self.combat         = nil
    self.leader         = nil
    self.lootMaster     = (TGU_MASTER_LOOTER_UNIT == unit)
    self.raidIcon       = nil
    self.role           = nil
    self.model          = nil
    self.npc            = nil
    self.reaction       = nil
    self.classification = nil
    self.pvpStatus      = nil
    self.living         = nil
    self.tapped         = nil
    self.comboPoints    = nil
    self.isVisible      = nil
    self.inHealingRange = nil
    self.threat         = {isTanking=nil,status=nil,threatPct=nil,
                           rawThreatPct=nil,threatValue=nil}
    self.buffs          = {}
    self.buffCounts     = {Magic=0,Curse=0,Disease=0,Posion=0}
    self.debuffs        = {}
    self.debuffCounts   = {Magic=0,Curse=0,Disease=0,Poison=0}
    self.indirectUnits  = {}
    self.listeners      = {}

    for i=1,32 do
        self.buffs[i]   = {}
        self.debuffs[i] = {}
    end

    if id ~= "target" and string.find(id,"^target") then
        TGUnit:new("target").indirectUnits[self] = self
    end

    for k in pairs(TGU.FLAGS) do
        self.listeners["UPDATE_"..k] = {}
    end

    self:Poll(self.allFlags)
end

-- Add a listener that can handle updates when state tracked by a given TGUnit
-- flag changes.  All methods on the client object of the form UPDATE_FOO,
-- where "FOO" is one of the TGU.FLAGS names, will be invoked when any of the
-- state monitored by flag FOO changes.
--
-- For instance, to receive events when the unit's health changes, your client
-- object should have a method named UPDATE_HEALTH that takes a TGUnit as a
-- parameter.
--
-- When a listener is initially registered, all of its UPDATE handlers will be
-- immediately invoked to set initial state.
function TGUnit:AddListener(obj)
    for k, v in pairs(self.listeners) do
        if obj[k] then
            v[obj] = obj
            obj[k](obj,self)
        end
    end
end

-- Remove a listener from the unit.
function TGUnit:RemoveListener(obj)
    for k, v in pairs(self.listeners) do
        if v[obj] then
            v[obj] = nil
        end
    end
end

-- Notify everyone registered for the set of flags that their state has changed.
function TGUnit:NotifyListeners(changedFlags)
    if changedFlags == 0 then
        return
    end

    for handler, mask in pairs(TGU.FLAG_HANDLERS) do
        if btst(changedFlags, mask) then
            for obj in pairs(self.listeners[handler]) do
                obj[handler](obj, self)
            end
        end
    end
end

-- Called internally to poll the specified flags.  This is carefully designed
-- so as to not allocate memory since it will be called very frequently and we
-- don't want to stress the garbage collector.
function TGUnit:Poll(flags)
    -- The set of flags that changed and therefore require update calls.  We
    -- initially populate this with the unconditional existence check since
    -- many others rely on it being up to date.
    local changedFlags = self:Poll_EXISTS()

    -- Update everything.  Note that the string concatenation does not appear
    -- to allocate memory, probably because the strings already exist.
    flags = bit.band(flags, bit.bnot(TGU.FLAGS.EXISTS))
    for flagName, bitmask in pairs(TGU.FLAGS) do
        if btst(flags, bitmask) then
            assert(bitmask ~= TGU.FLAGS.EXISTS)
            changedFlags = bit.bor(changedFlags,
                                   TGUnit["Poll_"..flagName](self))
        end
    end

    -- Notify listeners.
    self:NotifyListeners(changedFlags)
end

-- Static method to schedule unit polling.
function TGUnit.OnUpdate()
    local currTime = GetTime()
    if currTime - TGUnit.lastPoll <= TGU.POLL_RATE then
        return
    end

    -- Poll only poll-required flags for all units.
    for _, unit in pairs(TGUnit.unitList) do
        unit:Poll(unit.pollFlags)
    end

    TGUnit.lastPoll = currTime
end

-- Do a standard poll operation.
function TGUnit:StandardPoll(flag, field, func)
    local val
    if self.exists then
        val = func(self.id)
    end
    if val ~= self[field] then
        self[field] = val
        return flag
    end

    return 0
end

-- Update the existence property and return a flag if it changed.
function TGUnit:Poll_EXISTS()
    local exists = UnitExists(self.id)
    if exists ~= self.exists then
        self.exists = exists
        return TGU.FLAGS.EXISTS
    end

    return 0
end

-- Update the GUID property and return a flag if it changed.
function TGUnit:Poll_GUID()
    -- UnitGUID returns nil if the unit doesn't exist.
    local guid = UnitGUID(self.id)
    if guid == self.guid then
        return 0
    end

    local guidUnits
    if self.guid ~= nil then
        guidUnits = TGUnit.guidList[self.guid]
        guidUnits[self] = nil
        if next(guidUnits) == nil then
            TGUnit.guidList[self.guid] = nil
        end
    end

    if guid ~= nil then
        guidUnits = TGUnit.guidList[guid]
        if guidUnits == nil then
            guidUnits = {}
            TGUnit.guidList[guid] = guidUnits
        end
        guidUnits[self] = self
    end

    self.guid = guid
    return TGU.FLAGS.GUID
end

-- Update the health property and return a flag if it changed.  We update both
-- current and max health here.
function TGUnit:Poll_HEALTH()
    -- UnitHealth and UnitHealthMax both return 0 if the target is not set.
    local current, max

    if self.exists then
        current = UnitHealth(self.id)
        max     = UnitHealthMax(self.id)
    end

    if self.health.current == current and self.health.max == max then
        return 0
    end

    self.health.current = current
    self.health.max     = max
    return TGU.FLAGS.HEALTH
end

-- Update the power property and return a flag if it changed.  We update all
-- parts of the power (current, max, type) here.
function TGUnit:Poll_POWER()
    -- UnitPowerType, UnitPower and UnitPowerMax all return 0 if the target is
    -- not set.
    local current, max, typ

    if self.exists then
        current = UnitPower(self.id)
        max     = UnitPowerMax(self.id)
        typ     = UnitPowerType(self.id)
    end

    if (self.power.current == current and
        self.power.max == max and
        self.power.type == typ)
    then
        return 0
    end

    self.power.type    = typ
    self.power.current = current
    self.power.max     = max
    return TGU.FLAGS.POWER
end

-- Poll the set of auras using the specified filter and return a bitmask of any
-- that have changed.  Also return a flag if any counts have changed.
local auraCountsCache = {Magic=0,Curse=0,Disease=0,Poison=0};
function TGUnit:PollAuras(auras, auraCounts, filter)
    -- UnitAura() returns nil if the unit doesn't exist or the aura doesn't
    -- exist.
    local changedAuras = 0
    auraCountsCache.Magic   = 0
    auraCountsCache.Curse   = 0
    auraCountsCache.Disease = 0
    auraCountsCache.Poison  = 0
    for i, aura in ipairs(auras) do
        name,
        texture,
        applications,
        auraType,
        duration,
        expirationTime = UnitAura(self.id, i, filter)

        if (aura.name           ~= name or
            aura.texture        ~= texture or
            aura.applications   ~= applications or
            aura.auraType       ~= auraType or
            aura.duration       ~= duration or
            aura.expirationTime ~= expirationTime)
        then
            aura.name           = name
            aura.texture        = texture
            aura.applications   = applications
            aura.auraType       = auraType
            aura.duration       = duration
            aura.expirationTime = expirationTime
            changedAuras        = bit.bor(changedAuras, bit.lshift(1, i))

            -- Auras such as "Well Fed" or "Blood Pact" have types of nil.  It
            -- could also be nil if the aura just doesn't exist.
            if aura.auraType ~= nil then
                auraCountsCache[auraType] = auraCountsCache[auraType] + 1
            end
        end
    end

    local changedAuraCounts = (auraCounts.Magic   ~= auraCountsCache.Magic or
                               auraCounts.Curse   ~= auraCountsCache.Curse or
                               auraCounts.Disease ~= auraCountsCache.Disease or
                               auraCounts.Poison  ~= auraCountsCache.Poison)
    if changedAuraCounts then
        auraCounts.Magic   = auraCountsCache.Magic
        auraCounts.Curse   = auraCountsCache.Curse
        auraCounts.Disease = auraCountsCache.Disease
        auraCounts.Poison  = auraCountsCache.Poison
    end

    return changedAuras, changedAuraCounts
end

function TGUnit:PollAurasSimplified(auras, auraCounts, filter, flag)
    local changedAuras, changedAuraCounts =
        self:PollAuras(auras, auraCounts, filter)

    if changedAuras ~= 0 or changedAuraCounts then
        return flag
    end

    return 0
end

-- Update buffs and return a bitmask of all buffs that have changed.
function TGUnit:Poll_BUFFS()
    return self:PollAurasSimplified(self.buffs, self.buffCounts, "HELPFUL",
                                    TGU.FLAGS.BUFFS)
end

-- Update debuffs and return a bitmask of all debuffs that have changed.
function TGUnit:Poll_DEBUFFS()
    return self:PollAurasSimplified(self.debuffs, self.debuffCounts, "HARMFUL",
                                    TGU.FLAGS.DEBUFFS)
end

-- Update all auras.
function TGUnit:HandleAurasChanged()
    return bit.bor(self:Poll_BUFFS(),
                   self:Poll_DEBUFFS())
end

-- Update the player's spellcast.  In Classic, only the player's spellcast can
-- be queried programatically.  We do receive events in the combat log for when
-- other units start casting and if their casts caused damage but we don't get
-- events for all ways in which units can stop casting, so we split the player's
-- queryable cast info out from combat log cast info.
function TGUnit:Poll_PLAYER_SPELL()
    assert(self.id == "player")

    local spell, _, texture, startTime, endTime, _, castGUID = CastingInfo()

    if spell ~= nil then
        spellType = "Casting"
    else
        -- Note that displayName for a channeled spell just returns
        -- "Channeling" instead of the spell name - this is because the
        -- Blizzard UI only displays the spell name for a casted spell and just
        -- displays "Channeling" for a channeled spell.  So we probably want
        -- to use the spell name instead of the display name.
        castGUID = nil
        spell, _, texture, startTime, endTime = ChannelInfo()

        if spell ~= nil then
            spellType = "Channeling"
        end
    end

    if startTime ~= nil then
        startTime = startTime / 1000.0
    end
    if endTime ~= nil then
        endTime = endTime / 1000.0
    end

    local changed = (spellType    ~= self.playerCastInfo.spellType or
                     spell        ~= self.playerCastInfo.spell or
                     texture      ~= self.playerCastInfo.texture or
                     startTime    ~= self.playerCastInfo.startTime or
                     endTime      ~= self.playerCastInfo.endTime or
                     castGUID     ~= self.playerCastInfo.castGUID)
    if changed then
        self.playerCastInfo.spellType    = spellType
        self.playerCastInfo.spell        = spell
        self.playerCastInfo.texture      = texture
        self.playerCastInfo.startTime    = startTime
        self.playerCastInfo.endTime      = endTime
        self.playerCastInfo.castGUID     = castGUID
        return TGU.FLAGS.PLAYER_SPELL
    end

    return 0
end

-- Update a unit's combat log spellcast.  Since we can't actually poll anything
-- from the Classic client about non-player units, this method needs to take
-- the spell state as method arguments.
function TGUnit:Update_COMBAT_SPELL(timestamp, spell)
    local changed = (timestamp ~= self.logCastInfo.timestamp or
                     spell ~= self.logCastInfo.spell)
    if changed then
        self.logCastInfo.timestamp = timestamp
        self.logCastInfo.spell     = spell
        return TGU.FLAGS.COMBAT_SPELL
    end

    return 0
end
function TGUnit:Poll_COMBAT_SPELL()
    return self:Update_COMBAT_SPELL(nil, nil)
end

-- Update threat.
function TGUnit:Poll_THREAT()
    local isTanking, status, threatPct, rawThreatPct, threatValue
    if self.exists then
        isTanking, status, threatPct, rawThreatPt, threatValue =
            UnitDetailedThreatSituation("player", self.id)
    end

    if (isTanking    ~= self.threat.isTanking or
        status       ~= self.threat.status or
        threatPct    ~= self.threat.threatPct or
        rawThreatPct ~= self.threat.rawThreatPct or
        threatValue  ~= self.threat.threatValue)
    then
        self.threat.isTanking    = isTanking
        self.threat.status       = status
        self.threat.threatPct    = threatPct
        self.threat.rawThreatPct = rawThreatPct
        self.threat.threatValue  = threatValue
        return TGU.FLAGS.THREAT
    end

    return 0
end

-- Update player flags.  This include at least PVP, AFK, DND.
function TGUnit:HandlePlayerFlagsChanged()
    return bit.bor(self:Poll_PVPSTATUS(),
                   self:Poll_AFKSTATUS())
end

-- Standard event handler for events that just need to call one method and
-- notify listeners.
function TGUnit.StandardEvent(unitId, func)
    local unit = TGUnit.unitList[unitId]
    if unit ~= nil then
        unit:NotifyListeners(func(unit))
    end
end

-- Handle PLAYER_ENTERING_WORLD event.
function TGUnit.PLAYER_ENTERING_WORLD()
    -- Record when we entered the world.
    TGUnit.enteredWorldTime = GetTime()

    -- Figure out what spell to use for healing range detection.
    local _, englishClass    = UnitClass("player")
    TGUnit.healingRangeSpell = TGU.HEALING_RANGE_TABLE[englishClass]

    -- Poll all flags for all units.
    for _, unit in pairs(TGUnit.unitList) do
        unit:Poll(unit.allFlags)
    end
end

-- Handle PLAYER_TARGET_CHANGED event.  When the player's target changes, we
-- need to poll all flags for target-derived units manually (target,
-- targettarget, etc), including things like the name which we would normally
-- get a UNIT_NAME_UPDATE event for.
--
-- We also have to update ISPLAYERTARGET on all units.  This leads to some
-- minor duplication since we will be polling everything on the target-derived
-- units already, but it's not a big deal.
function TGUnit.PLAYER_TARGET_CHANGED()
    for _, unit in pairs(TGUnit.unitList) do
        unit:Poll(TGU.FLAGS.ISPLAYERTARGET)
    end

    -- The "target" unit object will exist if anyone is watching "target" or
    -- anything derived from it (even if no one is explicitly watching
    -- "target").
    local target = TGUnit.unitList["target"]
    if target == nil then
        return
    end

    target:Poll(target.allFlags)
    for u in pairs(target.indirectUnits) do
        u:Poll(u.allFlags)
    end
end

-- Handle UNIT_PET event.  This fires when a unit's pet changes (is summoned or
-- dismissed); much like when the player target changes we just need to poll
-- everything.
function TGUnit.UNIT_PET(unitId)
    local petUnit = TGUnit.unitList[TGU.PETMAP[unitId]]
    if petUnit ~= nil then
        TGEvt("UNIT_PET unitId "..unitId)
        petUnit:Poll(petUnit.allFlags)
    end
end

-- Handle GROUP_ROSTER_UPDATE event.  This fires when we join a group and when
-- other members join or leave the group or raid.  We maintain a cache that
-- maps roster unit ids to GUIDs and when this event fires we compare the
-- current mapping with the cached mapping and fully poll any roster unit ids
-- that have mismatched GUIDs since those slots are now different or gone.
function TGUnit.GROUP_ROSTER_UPDATE()
    for _, unitId in ipairs(TGU.ROSTER) do
        -- Note: UnitGUID returns nil if the unit doesn't exist.
        local guid = UnitGUID(unitId)
        if guid ~= TGUnit.rosterGUIDs[unitId] then
            TGUnit.rosterGUIDs[unitId] = guid
            local unit = TGUnit.unitList[unitId]
            if unit ~= nil then
                unit:Poll(unit.allFlags)
            end
        end
    end
end

-- Handle PLAYER_REGEN_DISABLED.  This fires when we enter combat.  Do not use
-- PLAYER_ENTER_COMBAT for this which just checks if auto-attack is on.
function TGUnit.PLAYER_REGEN_DISABLED()
    local unit = TGUnit.unitList["player"]
    if unit ~= nil then
        TGEvt("PLAYER_REGEN_DISABLED")
        unit:NotifyListeners(unit:Poll_COMBAT())
    end
end

-- Handle PLAYER_REGEN_ENABLED.  This fires when we leave combat.  Do not use
-- PLAYER_LEAVE_COMBAT for this which just checks if auto-attack is off.
function TGUnit.PLAYER_REGEN_ENABLED()
    local unit = TGUnit.unitList["player"]
    if unit ~= nil then
        TGEvt("PLAYER_REGEN_ENABLED")
        unit:NotifyListeners(unit:Poll_COMBAT())
    end
end

-- Handle PARTY_LEADER_CHANGED.  This fires when the leader changes, but it
-- doesn't tell us anything about who the leader is so we have to poll
-- everybody.
function TGUnit.PARTY_LEADER_CHANGED()
    for _, unit in pairs(TGUnit.unitList) do
        unit:NotifyListeners(unit:Poll_LEADER())
    end
end

-- Handle RAID_TARGET_UPDATE.  This fires when raid icons change and apparently
-- also when players enter or leave the party.  It also apparently does not
-- fire when a raid target dies even though the icon is automatically removed
-- at that time.
function TGUnit.RAID_TARGET_UPDATE()
    for _, unit in pairs(TGUnit.unitList) do
        unit:NotifyListeners(unit:Poll_RAIDICON())
    end
end

-- Handle SPELLCAST events.  The typical chain of events goes as follows for a
-- non-instant spell:
--
--      UNIT_SPELLCAST_SENT (only when unit == "player")
--      UNIT_SPELLCAST_START
--      UNIT_SPELLCAST_SUCCEEDED
--      UNIT_SPELLCAST_STOP
--
-- If the player moves to cancel the spell:
--
--      UNIT_SPELLCAST_SENT (only when unit == "player")
--      UNIT_SPELLCAST_START
--      UNIT_SPELLCAST_INTERRUPTED
--      UNIT_SPELLCAST_STOP
--      UNIT_SPELLCAST_INTERRUPTED
--      UNIT_SPELLCAST_INTERRUPTED
--      UNIT_SPELLCAST_INTERRUPTED
--
-- If the player hits escape to cancel the spell:
--
--      UNIT_SPELLCAST_SENT (only when unit == "player")
--      UNIT_SPELLCAST_START
--      UNIT_SPELLCAST_FAILED_QUIET
--      UNIT_SPELLCAST_STOP
--      UNIT_SPELLCAST_INTERRUPTED
--      UNIT_SPELLCAST_INTERRUPTED
--      UNIT_SPELLCAST_INTERRUPTED
--
-- If the player starts a cast then tries to do an instant-cast spell while
-- casting:
--
--      UNIT_SPELLCAST_SENT (only when unit == "player")
--      UNIT_SPELLCAST_START
--      UNIT_SPELLCAST_FAILED (for a new castingGUID)
--      UNIT_SPELLCAST_SUCCEEDED
--      UNIT_SPELLCAST_STOP
--
-- If the player is out of range at the start of the cast or tries to cast
-- a damage spell on a friendly target:
--
--      UNIT_SPELLCAST_FAILED
--
-- If the player performs an instant-cast spell:
--
--      UNIT_SPELLCAST_SENT (only when unit == "player")
--      UNIT_SPELLCAST_SUCCEEDED
--
-- If the player tries to dispel something but there is nothing to dispel:
--
--      UNIT_SPELLCAST_SENT (only when unit == "player")
--      UNIT_SPELLCAST_FAILED
--
-- When channeling, something like Mind Flay goes like this if the cast lands
-- (note the missing castGUIDs on the CHANNEL events):
--
--      UNIT_SPELLCAST_SENT
--      UNIT_SPELLCAST_CHANNEL_START (with castGUID == nil)
--      UNIT_SPELLCAST_SUCCEEDED (fires when the cast LANDS, not when it
--                                completes)
--      ...tick, tick, tick...
--      UNIT_SPELLCAST_CHANNEL_STOP (with castGUID == nil)
--
-- Note: None of these events seem to fire for hostile targets (tested on
-- Defias Pillager casters).  They may fire for party and raid members.  They
-- also don't fire for the Warlock imp firebolt spell (and probably other
-- spells) - even when we have the pet selected as our target while it is
-- casting.
--
-- Quirk: If the unit is "target" and the target is "player", then we get these
-- events for the "target" unit as well.  This may also be the case for other
-- units.  We discard them if they aren't for the actual player unit.
function TGUnit.HandleUnitSpellcastEvent(unitId, castGUID, spellID)
    if unitId ~= "player" then
        return
    end

    local unit = TGUnit.unitList[unitId]
    if unit ~= nil then
        unit:NotifyListeners(unit:Poll_PLAYER_SPELL())
    end
end
TGUnit.UNIT_SPELLCAST_START          = TGUnit.HandleUnitSpellcastEvent
TGUnit.UNIT_SPELLCAST_STOP           = TGUnit.HandleUnitSpellcastEvent
TGUnit.UNIT_SPELLCAST_DELAYED        = TGUnit.HandleUnitSpellcastEvent
TGUnit.UNIT_SPELLCAST_CHANNEL_START  = TGUnit.HandleUnitSpellcastEvent
TGUnit.UNIT_SPELLCAST_CHANNEL_STOP   = TGUnit.HandleUnitSpellcastEvent
TGUnit.UNIT_SPELLCAST_CHANNEL_UPDATE = TGUnit.HandleUnitSpellcastEvent

function TGUnit.COMBAT_LOG_EVENT_UNFILTERED()
    TGUnit.Parse_COMBAT_LOG_EVENT_UNFILTERED(CombatLogGetCurrentEventInfo())
end
function TGUnit.Parse_COMBAT_LOG_EVENT_UNFILTERED(...)
    local timestamp, event, _, sourceGUID, _, _, _, destGUID, _, _, _,
          _, spellName = ...

    if (event == "SPELL_CAST_START" or
        event == "SPELL_CAST_SUCCESS" or
        event == "SPELL_CAST_FAILED")
    then
        local start
        if event == "SPELL_CAST_START" then
            start = true
        elseif event == "SPELL_CAST_SUCCESS" then
            start = (TGU.CHANNELED_SPELL_NAME_TO_ID[spellName] ~= nil)
        elseif event == "SPELL_CAST_FAILED" then
            start = false
        end

        local guidUnits = TGUnit.guidList[sourceGUID]
        if guidUnits ~= nil then
            for unit in pairs(guidUnits) do
                if start then
                    unit:NotifyListeners(unit:Update_COMBAT_SPELL(timestamp,
                                                                  spellName))
                else
                    unit:NotifyListeners(unit:Update_COMBAT_SPELL(nil, nil))
                end
            end
        end
    end
end

-- Debug function to print the unit list.
function TGUnit.PrintUnitList()
    for _, unit in pairs(TGUnit.unitList) do
        TGDbg(unit.id)
    end
end

-- Debug function to print the guid list.
function TGUnit.PrintGuidList()
    for guid, guidUnits in pairs(TGUnit.guidList) do
        local name = next(guidUnits).name
        local str  = guid.." ("..name.."): "
        for unit in pairs(guidUnits) do
            str = str.." "..unit.id
        end
        TGDbg(str)
    end
end

-- The set of standard-poll properties.  These don't require any special per-
-- property logic and therefore can all be generated programatically.  Other
-- properties that require more logic are special-cased later.
local TGUNIT_STANDARD_PROPERTIES = {
    {"ISPLAYERTARGET",  "isPlayerTarget",   UnitIsPlayerTarget},
    {"NAME",            "name",             UnitName},
    {"CLASS",           "class",            UnitClass},
    {"LEVEL",           "level",            UnitLevel},
    {"COMBAT",          "combat",           UnitAffectingCombat},
    {"REACTION",        "reaction",         UnitGetReaction},
    {"LEADER",          "leader",           UnitIsGroupLeader},
    {"RAIDICON",        "raidIcon",         GetRaidTargetIndex},
    {"NPC",             "npc",              UnitIsNPC},
    {"CLASSIFICATION",  "classification",   UnitClassification},
    {"PVPSTATUS",       "pvpStatus",        UnitGetPVPStatus},
    {"AFKSTATUS",       "afkStatus",        UnitIsAFK},
    {"LIVING",          "living",           UnitGetLivingStatus},
    {"TAPPED",          "tapped",           UnitIsTapDenied},
    {"ISVISIBLE",       "isVisible",        UnitGetIsVisible},
    {"INHEALINGRANGE",  "inHealingRange",   UnitGetInHealingRange},
    {"CREATURETYPE",    "creatureType",     UnitCreatureType},
}
for _, prop in ipairs(TGUNIT_STANDARD_PROPERTIES) do
    local flag, field, getter = unpack(prop)
    TGUnit["Poll_"..flag] = function(self)
        return self:StandardPoll(TGU.FLAGS[flag], field, getter)
    end
end

-- The set of standard-poll events.  These simply poll a single property and
-- then notify the appropriate listeners, so can also be generated
-- programatically.
local TGUNIT_STANDARD_EVENTS = {
    {"UNIT_NAME_UPDATE",        TGUnit.Poll_NAME},
    {"UNIT_HEALTH_FREQUENT",    TGUnit.Poll_HEALTH},
    {"UNIT_MAXHEALTH",          TGUnit.Poll_HEALTH},
    {"UNIT_POWER_FREQUENT",     TGUnit.Poll_POWER},
    {"UNIT_MAXPOWER",           TGUnit.Poll_POWER},
    {"UNIT_DISPLAYPOWER",       TGUnit.Poll_POWER},
    {"UNIT_LEVEL",              TGUnit.Poll_LEVEL},
    {"PLAYER_FLAGS_CHANGED",    TGUnit.HandlePlayerFlagsChanged},
    {"UNIT_AURA",               TGUnit.HandleAurasChanged},
}
for _, eventInfo in ipairs(TGUNIT_STANDARD_EVENTS) do
    local event, func = unpack(eventInfo)
    TGUnit[event] = function(unitId)
        return TGUnit.StandardEvent(unitId, func)
    end
end

if TGU_LIB_ENABLED then
    TGEventHandler.Register(TGUnit)
end
