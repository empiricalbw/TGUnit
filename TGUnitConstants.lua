TGUF = {}

--[[
    This is the period between poll updates for units that the game interface
    doesn't automatically generate events for, and some variables that get
    polled for periodically.
]]
TGUF.POLL_RATE = 0.1 -- The delay between manual polls

-- Bitmasks defining various attributes that we can poll.
TGUF.FLAGS = {
    ISPLAYERTARGET = bit.lshift(1, 0),
    COMBOPOINTS    = bit.lshift(1, 1),
    NAME           = bit.lshift(1, 2),
    CLASS          = bit.lshift(1, 3),
    HEALTH         = bit.lshift(1, 4),
    MANA           = bit.lshift(1, 5),
    LEVEL          = bit.lshift(1, 6),
    COMBAT         = bit.lshift(1, 7),
    BUFFS          = bit.lshift(1, 8),
    DEBUFFS        = bit.lshift(1, 9),
    SPELL          = bit.lshift(1,10),
    REACTION       = bit.lshift(1,11),
    LEADER         = bit.lshift(1,12),
    RAIDICON       = bit.lshift(1,13),
    NPC            = bit.lshift(1,14),
    CLASSIFICATION = bit.lshift(1,15),
    PVPSTATUS      = bit.lshift(1,16),
    LIVING         = bit.lshift(1,17),
    TAPPED         = bit.lshift(1,18),
    ISVISIBLE      = bit.lshift(1,19),
    INHEALINGRANGE = bit.lshift(1,20),
    CREATURETYPE   = bit.lshift(1,21),
    THREAT         = bit.lshift(1,22),
    ROLE           = bit.lshift(1,23),
    EXISTS         = bit.lshift(1,24),
}
TGUF.FLAG_HANDLERS = {}
local count = 0
for k,v in pairs(TGUF.FLAGS) do
    count = count + 1
    TGUF.FLAG_HANDLERS["UPDATE_"..k] = v
end
TGUF.NUMFLAGS      = count
TGUF.LASTFLAG      = bit.lshift(1,TGUF.NUMFLAGS)
TGUF.ALLFLAGS      = TGUF.LASTFLAG - 1

--[[
    This bitmask describes the set of attributes for which the game engine
    generates events notifying us of a change.  These events are generated only
    for the player.  Note that we special-case mana here.  The game generates
    periodic mana updates every few seconds but as of 3.0.2 the UnitMana()
    updates in REAL-TIME.  This means that we need to poll it periodically to
    get the smooth mana regen the same way that the Blizzard UI does.
]]
TGUF.PLAYEREVENT_MASK = bit.bor(
    TGUF.FLAGS.ISPLAYERTARGET,
    TGUF.FLAGS.COMBOPOINTS,
    TGUF.FLAGS.NAME,
    TGUF.FLAGS.CLASS,
    TGUF.FLAGS.HEALTH,
    TGUF.FLAGS.LEVEL,
    TGUF.FLAGS.COMBAT,
    TGUF.FLAGS.BUFFS,
    TGUF.FLAGS.DEBUFFS,
    TGUF.FLAGS.THREAT)
TGUF.PLAYERPOLL_MASK = bit.bor(
    TGUF.FLAGS.MANA,
    TGUF.FLAGS.REACTION,
    TGUF.FLAGS.LEADER,
    TGUF.FLAGS.RAIDICON,
    TGUF.FLAGS.NPC,
    TGUF.FLAGS.CLASSIFICATION,
    TGUF.FLAGS.PVPSTATUS,
    TGUF.FLAGS.LIVING,
    TGUF.FLAGS.TAPPED,
    TGUF.FLAGS.ISVISIBLE,
    TGUF.FLAGS.INHEALINGRANGE,
    TGUF.FLAGS.SPELL,
    TGUF.FLAGS.CREATURETYPE,
    TGUF.FLAGS.ROLE,
    TGUF.FLAGS.EXISTS)
assert(bit.bor(TGUF.PLAYEREVENT_MASK,TGUF.PLAYERPOLL_MASK) == TGUF.ALLFLAGS)

--[[
    This bitmask describes the set of attributes for which the game engine
    generates events notifying us of a change for all of the non-player unit
    IDs which the game generates events for: target, focus, pet, mouseover,
    partyX, raidX

    See note above for information about polling mana.
]]
TGUF.NONPLAYEREVENT_MASK = bit.bor(
    TGUF.FLAGS.ISPLAYERTARGET,
    TGUF.FLAGS.NAME,
    TGUF.FLAGS.CLASS,
    TGUF.FLAGS.HEALTH,
    TGUF.FLAGS.LEVEL,
    TGUF.FLAGS.BUFFS,
    TGUF.FLAGS.DEBUFFS)
TGUF.NONPLAYERPOLL_MASK = bit.bor(
    TGUF.FLAGS.MANA,
    TGUF.FLAGS.COMBOPOINTS,
    TGUF.FLAGS.COMBAT,
    TGUF.FLAGS.REACTION,
    TGUF.FLAGS.LEADER,
    TGUF.FLAGS.RAIDICON,
    TGUF.FLAGS.NPC,
    TGUF.FLAGS.CLASSIFICATION,
    TGUF.FLAGS.PVPSTATUS,
    TGUF.FLAGS.LIVING,
    TGUF.FLAGS.TAPPED,
    TGUF.FLAGS.ISVISIBLE,
    TGUF.FLAGS.INHEALINGRANGE,
    TGUF.FLAGS.CREATURETYPE,
    TGUF.FLAGS.THREAT,
    TGUF.FLAGS.SPELL,
    TGUF.FLAGS.ROLE,
    TGUF.FLAGS.EXISTS)
assert(bit.bor(TGUF.NONPLAYEREVENT_MASK,TGUF.NONPLAYERPOLL_MASK)
        == TGUF.ALLFLAGS)

-- Table that tells us what state needs to be polled based on unit ID.  If a
-- unit ID is not present in this table, then all of its state requires
-- polling.
TGUF.POLLFLAGS = {
    ["player"]    = TGUF.PLAYERPOLL_MASK,
    ["target"]    = TGUF.NONPLAYERPOLL_MASK,
    ["focus"]     = TGUF.NONPLAYERPOLL_MASK,
    ["pet"]       = TGUF.NONPLAYERPOLL_MASK,
    ["mouseover"] = TGUF.NONPLAYERPOLL_MASK,
    ["party1"]    = TGUF.NONPLAYERPOLL_MASK,
    ["party2"]    = TGUF.NONPLAYERPOLL_MASK,
    ["party3"]    = TGUF.NONPLAYERPOLL_MASK,
    ["party4"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid1"]     = TGUF.NONPLAYERPOLL_MASK,
    ["raid2"]     = TGUF.NONPLAYERPOLL_MASK,
    ["raid3"]     = TGUF.NONPLAYERPOLL_MASK,
    ["raid4"]     = TGUF.NONPLAYERPOLL_MASK,
    ["raid5"]     = TGUF.NONPLAYERPOLL_MASK,
    ["raid6"]     = TGUF.NONPLAYERPOLL_MASK,
    ["raid7"]     = TGUF.NONPLAYERPOLL_MASK,
    ["raid8"]     = TGUF.NONPLAYERPOLL_MASK,
    ["raid9"]     = TGUF.NONPLAYERPOLL_MASK,
    ["raid10"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid11"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid12"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid13"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid14"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid15"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid16"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid17"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid18"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid19"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid20"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid21"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid22"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid23"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid24"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid25"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid26"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid27"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid28"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid29"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid30"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid31"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid32"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid33"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid34"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid35"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid36"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid37"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid38"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid39"]    = TGUF.NONPLAYERPOLL_MASK,
    ["raid40"]    = TGUF.NONPLAYERPOLL_MASK,
}

-- Reaction types.
TGUF.REACTION_FRIENDLY = 0 -- Unit is "green", won't aggro
TGUF.REACTION_NEUTRAL  = 1 -- Unit is "yellow", won't aggro unless attacked
TGUF.REACTION_HOSTILE  = 2 -- Unit is "red", will aggro

-- List of classification types.
TGUF.CLASSIFICATION_NORMAL     = 0 -- Nothing special
TGUF.CLASSIFICATION_RARE       = 1 -- Rare!
TGUF.CLASSIFICATION_ELITE      = 2
TGUF.CLASSIFICATION_RARE_ELITE = 3
TGUF.CLASSIFICATION_BOSS       = 4
TGUF.STRING_TO_CLASSIFICATION_TABLE = {
    ["normal"]    = TGUF.CLASSIFICATION_NORMAL,
    ["rare"]      = TGUF.CLASSIFICATION_RARE,
    ["elite"]     = TGUF.CLASSIFICATION_ELITE,
    ["rareelite"] = TGUF.CLASSIFICATION_RARE_ELITE,
    ["worldboss"] = TGUF.CLASSIFICATION_BOSS
}

-- List of PVP types.
TGUF.PVP_NONE        = 0   -- Not flagged
TGUF.PVP_FLAGGED     = 1   -- PVP flagged
TGUF.PVP_FFA_FLAGGED = 2   -- PVP free-for-all flagged

-- List of living types.
TGUF.LIVING_ALIVE = 0      -- Unit is alive
TGUF.LIVING_DEAD  = 1      -- Unit is dead
TGUF.LIVING_GHOST = 2      -- Unit is a ghost

-- List of tapped types.
TGUF.TAPPED_NONE   = 0     -- Unit is not tapped
TGUF.TAPPED_PLAYER = 1     -- Unit is tapped by the player
TGUF.TAPPED_OTHER  = 2     -- Unit is tapped by someone else

--[[
    This is a template unit, used when the template editor is open so that the
    user can see various made-up stats.
]]
TGUF.TEMPLATE_UNIT =
{
    id             = "template",
    listeners      = {},
    exists         = true,
    isPlayerTarget = false,
    name           = "Abracadabra",
    class          = {localizedClass="Warrior",englishClass="WARRIOR"},
    creatureType   = "Humanoid",
    health         = {current=12000,max=12345},
    mana           = {type=0,current=12000,max=12345},
    spell          = {},
    level          = 60,
    combat         = true,
    leader         = true,
    lootMaster     = true,
    raidIcon       = 1,
    role           = "TANK",
    model          = nil,
    npc            = false,
    reaction       = TGUF.REACTION_FRIENDLY,
    classification = TGUF.CLASSIFICATION_ELITE,
    pvpStatus      = TGUF.PVP_FLAGGED,
    living         = TGUF.LIVING_ALIVE,
    tapped         = false,
    comboPoints    = 5,
    isVisible      = 1,
    inHealingRange = 1,
    threat         = {isTanking=false,status=1,threatPct=90,rawThreatPct=110,
                      threatValue=123400},
    buffs =
    {
        count = 32,
        buff =
        {
            {name="Test",rank=1,applications=1,expirationTime=10,duration=-1,
             texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=2,expirationTime=10,duration=-1,
             texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=3,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=4,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=5,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=6,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=7,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=8,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=9,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=10,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=11,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=12,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=13,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=14,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=15,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=16,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=17,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=18,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=19,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=20,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=21,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=22,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=23,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=24,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=25,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=26,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=27,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=28,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=29,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=30,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=31,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=1,applications=32,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
        }
    },
    debuffs =
    {
        count = 32,
        debuff =
        {
            {name="Test",rank=1,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=2,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=3,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=4,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=5,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=6,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=7,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=8,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=9,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=10,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=11,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=12,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=13,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=14,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=15,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=16,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=17,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=18,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=19,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=20,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=21,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=22,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=23,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=24,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=25,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=26,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=27,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=28,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=29,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=30,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=31,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
            {name="Test",rank=32,applications=1,expirationTime=10,duration=-1,
            texture="Interface\\CharacterFrame\\TempPortrait"},
        }
    },
    debuffCounts =
    {
        Magic   = 0,
        Curse   = 0,
        Disease = 0,
        Poison  = 0
    }
}
