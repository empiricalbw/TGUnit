-- Whether or not to enable this experimental library.
local TGUF_LIB_ENABLED = true

--[[
    TGUnit is a class that is used to monitor a unit ID and to emit events when
    that unit ID's state changes
]]
TGUnit = {}
TGUnit.__index = TGUnit
TGUnit.lastPoll = 0

--[[
    The set of TGUnits that have been instantiated.  This is keyed by unit ID
    and if the same unit is "instantiated" twice the second instance will be
    the same as the first.
]]
local TGUNIT_LIST = {}

-- Utility function for bitmasks.
local function btst(mask1,mask2)
    return bit.band(mask1,mask2) ~= 0
end

-- Instantiate a new TGUnit.  If the unit already exists, return it instead.
function TGUnit:new(id)
    assert(id)
    if (id == "template") then
        return TGUF.TEMPLATE_UNIT
    end
    if (TGUNIT_LIST[id]) then
        return TGUNIT_LIST[id]
    end

    local unit = {}
    setmetatable(unit,TGUnit)
    unit:TGUnit(id)
    TGUNIT_LIST[id] = unit
    return unit
end

-- Construct a TGUnit.
function TGUnit:TGUnit(id)
    self.id             = id
    self.pollFlags      = TGUF.POLLFLAGS[id] or TGUF.ALLFLAGS
    self.exists         = false
    self.isPlayerTarget = nil
    self.name           = nil
    self.class          = {localizedClass=nil,englishClass=nil}
    self.creatureType   = nil
    self.health         = {current=nil,max=nil}
    self.mana           = {type=nil,current=nil,max=nil}
    self.spell          = {}
    self.level          = nil
    self.combat         = nil
    self.leader         = nil
    self.lootMaster     = (TGUF_MASTER_LOOTER_UNIT == unit)
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
    if (id ~= "focus" and string.find(id,"^focus")) then
        TGUnit:new("focus").indirectUnits[self] = self
    end

    for k in pairs(TGUF.FLAGS) do
        self.listeners["UPDATE_"..k] = {}
    end

    self:Poll(TGUF.ALLFLAGS)
end

function TGUnit:AddListener(obj)
    for k in pairs(obj) do
        if string.find(k,"^UPDATE_") then
            self.listeners[k][obj] = obj
            obj[k](obj,self)
        end
    end
end

function TGUnit:RemoveListener(flag,obj)
    for k in pairs(obj) do
        if string.upper(k) == k then
            self.listeners[k][obj] = nil
        end
    end
end

function TGUnit:Poll(flags)
    -- The set of flags to poll and any changes observed.
    local changedFlags = 0
    local changed
    flags = flags or self.pollFlags

    -- Existence check is special - we always do it.
    local exists = UnitExists(self.id)
    changed = (exists ~= self.exists)
    if changed then
        changedFlags = bit.bor(changedFlags,TGUF.FLAGS.EXISTS)
        self.exists = exists
    end

    -- Update name
    if btst(flags,TGUF.FLAGS.NAME) then
        local name = UnitName(self.id)
        changed = (name ~= self.name)
        if changed then
            changedFlags = bit.bor(changedFlags,TGUF.FLAGS.NAME)
            self.name = name
        end
    end

    -- Notify listeners
    for handler,mask in pairs(TGUF.FLAG_HANDLERS) do
        if btst(changedFlags,mask) then
            for obj in pairs(self.listeners[handler]) do
                obj[handler](obj,self)
            end
        end
    end
end

function TGUnit.OnEvent(frame,event,...)
    TGUnit[event](...)
end

function TGUnit.OnUpdate()
    local currTime = GetTime()
    if currTime - TGUnit.lastPoll <= TGUF.POLL_RATE then
        return
    end

    for _,unit in pairs(TGUNIT_LIST) do
        unit:Poll()
    end

    TGUnit.lastPoll = currTime
end

local firstTime = true
function TGUnit.PLAYER_ENTERING_WORLD()
    TGDbg("PLAYER_ENTERING_WORLD")
    for _,unit in pairs(TGUNIT_LIST) do
        unit:Poll(TGUF.ALLFLAGS)
    end

    if firstTime then
        local l = {}
        function l:UPDATE_NAME(unit)
            TGDbg(unit.id.." is now "..tostring(unit.name))
        end
        TGUnit:new("player"):AddListener(l)
        TGUnit:new("target"):AddListener(l)
        TGUnit:new("targettarget"):AddListener(l)
        firstTime = false
    end
end

function TGUnit.PLAYER_TARGET_CHANGED()
    local target = TGUNIT_LIST["target"]
    if target == nil then
        return
    end

    target:Poll(TGUF.ALLFLAGS)
    for u in pairs(target.indirectUnits) do
        u:Poll(TGUF.ALLFLAGS)
    end
end

if TGUF_LIB_ENABLED then
    -- A dummy frame to get us the events we are interested in.
    local TGUF_EV_FRAME = CreateFrame("Frame")
    TGUF_EV_FRAME:SetScript("OnEvent",TGUnit.OnEvent)
    TGUF_EV_FRAME:SetScript("OnUpdate",TGUnit.OnUpdate)
    for k in pairs(TGUnit) do
        if string.upper(k) == k then
            TGUF_EV_FRAME:RegisterEvent(k)
        end
    end
end
