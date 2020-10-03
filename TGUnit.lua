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

-- The frame that we will use to listen to events and updates.
TGUnit.tguFrame = nil

-- The time at which we entered the world.
TGUnit.enteredWorldTime = nil

-- A mapping of roster (party and raid unit ids) to GUIDs, uniquely identifying
-- members of the raid and party.
TGUnit.rosterGUIDs = {}

-- Utility function for bitmasks.
local function btst(mask1,mask2)
    return bit.band(mask1,mask2) ~= 0
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
    self.spell          = {}
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

-- Update the existence property and return a flag if it changed.
function TGUnit:Poll_EXISTS()
    local exists = UnitExists(self.id)
    if exists == self.exists then
        return 0
    end

    self.exists = exists
    return TGU.FLAGS.EXISTS
end

-- Update the GUID property and return a flag if it changed.
function TGUnit:Poll_GUID()
    -- UnitGUID returns nil if the unit doesn't exist.
    local guid = UnitGUID(self.id)
    if guid == self.guid then
        return 0
    end

    self.guid = guid
    return TGU.FLAGS.GUID
end

-- Update the name property and return a flag if it changed.
function TGUnit:Poll_NAME()
    -- UnitName returns nil if the unit doesn't exist.
    local name = UnitName(self.id)
    if name ~= self.name then
        self.name = name
        return TGU.FLAGS.NAME
    end

    return 0
end

-- Update the health property and return a flag if it changed.  We update both
-- current and max health here.
function TGUnit:Poll_HEALTH()
    -- UnitHealth and UnitHealthMax both return 0 if the target is not set.
    local current
    local max

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
    local current
    local max
    local typ

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

-- Update the level property and return a flag if it changed.
function TGUnit:Poll_LEVEL()
    -- UnitLevel returns 0 if the target is not set.
    local level

    if self.exists then
        level = UnitLevel(self.id)
    end

    if self.level == level then
        return 0
    end

    self.level = level
    return TGU.FLAGS.LEVEL
end

-- Update the "is player target" property and return a flag if it changed.
function TGUnit:Poll_ISPLAYERTARGET()
    -- UnitIsUnit returns false if one of the units doesn't exist.
    local isPlayerTarget = (UnitExists("target") and
                            UnitIsUnit(self.id, "target"))
    if self.isPlayerTarget == isPlayerTarget then
        return 0
    end

    self.isPlayerTarget = isPlayerTarget
    return TGU.FLAGS.ISPLAYERTARGET
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
    local changedAuras
    local changedAuraCounts

    changedAuras,
    changedAuraCounts = self:PollAuras(auras, auraCounts, filter)

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

-- Called internally to poll the specified flags.  This is carefully designed
-- so as to not allocate memory since it will be called very frequently and we
-- don't want to stress the garbage collector.
function TGUnit:Poll(flags)
    -- The set of flags to poll - all poll-required flags if nothing specified.
    flags = flags or self.pollFlags

    -- The set of flags that changed and therefore require update calls.  We
    -- initially populate this with the unconditional existence check.
    local changedFlags = self:Poll_EXISTS()

    -- Update everything.
    if btst(flags, TGU.FLAGS.GUID) then
        changedFlags = bit.bor(changedFlags, self:Poll_GUID())
    end
    if btst(flags, TGU.FLAGS.NAME) then
        changedFlags = bit.bor(changedFlags, self:Poll_NAME())
    end
    if btst(flags, TGU.FLAGS.HEALTH) then
        changedFlags = bit.bor(changedFlags, self:Poll_HEALTH())
    end
    if btst(flags, TGU.FLAGS.POWER) then
        changedFlags = bit.bor(changedFlags, self:Poll_POWER())
    end
    if btst(flags, TGU.FLAGS.LEVEL) then
        changedFlags = bit.bor(changedFlags, self:Poll_LEVEL())
    end
    if btst(flags, TGU.FLAGS.ISPLAYERTARGET) then
        changedFlags = bit.bor(changedFlags, self:Poll_ISPLAYERTARGET())
    end
    if btst(flags, TGU.FLAGS.BUFFS) then
        changedFlags = bit.bor(changedFlags, self:Poll_BUFFS())
    end
    if btst(flags, TGU.FLAGS.DEBUFFS) then
        changedFlags = bit.bor(changedFlags, self:Poll_DEBUFFS())
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

-- Handle PLAYER_ENTERING_WORLD event.
function TGUnit.PLAYER_ENTERING_WORLD()
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

-- Handle UNIT_NAME_UPDATE event.  This is typically invoked if the unit's name
-- changes after the unit initially came into existence and is not invoked for
-- example when you change targets to a target with a new name.
function TGUnit.UNIT_NAME_UPDATE(unitId)
    TGDbg("UNIT_NAME_UPDATE unitId "..unitId)
    local unit = TGUnit.unitList[unitId]
    if unit ~= nil then
        unit:NotifyListeners(unit:Poll_NAME())
    end
end

-- Handle UNIT_HEALTH_FREQUENT event.
function TGUnit.UNIT_HEALTH_FREQUENT(unitId)
    local unit = TGUnit.unitList[unitId]
    if unit ~= nil then
        TGDbg("UNIT_HEALTH_UPDATE unitId "..unitId)
        unit:NotifyListeners(unit:Poll_HEALTH())
    end
end

-- Handle UNIT_MAXHEALTH event.
function TGUnit.UNIT_MAXHEALTH(unitId)
    local unit = TGUnit.unitList[unitId]
    if unit ~= nil then
        TGDbg("UNIT_MAXHEALTH unitId "..unitId)
        unit:NotifyListeners(unit:Poll_HEALTH())
    end
end

-- Handle UNIT_POWER_FREQUENT event.  This updates the current power (mana,
-- rage, energy, etc) amount and can tick frequently.  On Classic, this appears
-- to tick only every couple of seconds, but it gets called twice for each of
-- those ticks in rapid succession.
function TGUnit.UNIT_POWER_FREQUENT(unitId, powerType)
    local unit = TGUnit.unitList[unitId]
    if unit ~= nil then
        TGDbg("UNIT_POWER_UPDATE unitId "..unitId.." powerType "..powerType)
        unit:NotifyListeners(unit:Poll_POWER())
    end
end

-- Handle UNIT_MAXPOWER event.
function TGUnit.UNIT_MAXPOWER(unitId, powerType)
    local unit = TGUnit.unitList[unitId]
    if unit ~= nil then
        TGDbg("UNIT_MAXPOWER unitId "..unitId.." powerType "..powerType)
        unit:NotifyListeners(unit:Poll_POWER())
    end
end

-- Handle UNIT_DISPLAYPOWER event.
function TGUnit.UNIT_DISPLAYPOWER(unitId)
    local unit = TGUnit.unitList[unitId]
    if unit ~= nil then
        TGDbg("UNIT_DISPLAYPOWER unitId "..unitId.." powerType "..powerType)
        unit:NotifyListeners(unit:Poll_POWER())
    end
end

-- Handle UNIT_LEVEL event.
function TGUnit.UNIT_LEVEL(unitId)
    local unit = TGUnit.unitList[unitId]
    if unit ~= nil then
        TGDbg("UNIT_LEVEL unitId "..unitId)
        unit:NotifyListeners(unit:Poll_LEVEL())
    end
end

-- Handle UNIT_PET event.  This fires when a unit's pet changes (is summoned or
-- dismissed); much like when the player target changes we just need to poll
-- everything.
function TGUnit.UNIT_PET(unitId)
    local petUnit = TGUnit.unitList[TGU.PETMAP[unitId]]
    if petUnit ~= nil then
        TGDbg("UNIT_PET unitId "..unitId)
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

-- Handle UNIT_AURA event.  This fires when a buff or debuff on the unit id
-- changes.
function TGUnit.UNIT_AURA(unitId)
    local unit = TGUnit.unitList[unitId]
    if unit ~= nil then
        TGDbg("UNIT_AURA unitId "..unitId)
        unit:NotifyListeners(unit:Poll_BUFFS())
        unit:NotifyListeners(unit:Poll_DEBUFFS())
    end
end

-- Debug function to print the unit list.
function TGUnit.PrintUnitList()
    for _, unit in pairs(TGUnit.unitList) do
        TGDbg(unit.id)
    end
end

if TGU_LIB_ENABLED then
    TGEventHandler.Register(TGUnit)
end
