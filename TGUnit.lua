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

-- Utility function for bitmasks.
local function btst(mask1,mask2)
    return bit.band(mask1,mask2) ~= 0
end

-- Instantiate a new TGUnit.  If the unit already exists, return it instead.
function TGUnit:new(id)
    assert(id)
    if (id == "template") then
        return TGU.TEMPLATE_UNIT
    end
    if (TGUnit.unitList[id]) then
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
    self.buffs          = {count=0,buff={}}
    self.debuffs        = {count=0,debuff={}}
    self.debuffCounts   = {Magic=0,Curse=0,Disease=0,Poison=0}
    self.indirectUnits  = {}
    self.listeners      = {}

    for i=1,32 do
        self.buffs.buff[i]     = {}
        self.debuffs.debuff[i] = {}
    end

    if (id ~= "target" and string.find(id,"^target")) then
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
    -- The set of flags to poll - all poll-required flags if nothing specified.
    flags = flags or self.pollFlags

    -- The set of flags that changed and therefore require update calls.
    local changedFlags = 0

    -- Existence check is special - we always do it.
    local exists = UnitExists(self.id)
    if exists ~= self.exists then
        changedFlags = bit.bor(changedFlags, TGU.FLAGS.EXISTS)
        self.exists  = exists
    end

    -- Update name.
    if btst(flags, TGU.FLAGS.NAME) then
        local name
        if self.exists then
            name = UnitName(self.id)
        else
            name = nil
        end
        if name ~= self.name then
            changedFlags = bit.bor(changedFlags, TGU.FLAGS.NAME)
            self.name    = name
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
        unit:Poll()
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

-- Handle PLAYER_TARGET_CHANGED event.
function TGUnit.PLAYER_TARGET_CHANGED()
    local target = TGUnit.unitList["target"]
    if target == nil then
        return
    end

    target:Poll(target.allFlags)
    for u in pairs(target.indirectUnits) do
        u:Poll(u.allFlags)
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
