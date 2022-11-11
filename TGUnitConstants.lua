TGU = {}

-- This is the period between poll updates for units that the game interface
-- doesn't automatically generate events for, and some variables that get
-- polled for periodically.
TGU.POLL_RATE = 0.1 -- The delay between manual polls

-- Bitmasks defining various attributes that we can poll.
TGU.FLAGS = {
    ISPLAYERTARGET = bit.lshift(1,  0), -- The unit is same as "target"
    --COMBOPOINTS    = bit.lshift(1,  1), -- The number of combo points
    NAME           = bit.lshift(1,  2), -- The unit name
    CLASS          = bit.lshift(1,  3), -- The unit class
    HEALTH         = bit.lshift(1,  4), -- The unit health or max health
    POWER          = bit.lshift(1,  5), -- The unit power, max, type
    LEVEL          = bit.lshift(1,  6), -- The unit level
    COMBAT         = bit.lshift(1,  7), -- In combat or not
    BUFFS          = bit.lshift(1,  8), -- Unit buffs
    DEBUFFS        = bit.lshift(1,  9), -- Unit debuffs
    PLAYER_SPELL   = bit.lshift(1, 10), -- Spell being cast by the player
    REACTION       = bit.lshift(1, 11), -- Friendly, neutral or hostile
    LEADER         = bit.lshift(1, 12), -- Unit is group or raid leader
    RAIDICON       = bit.lshift(1, 13), -- Unit's raid icon num or nil if none
    NPC            = bit.lshift(1, 14), -- Unit is an NPC.
    CLASSIFICATION = bit.lshift(1, 15), -- Rare, elite, worldboss, etc.
    PVPSTATUS      = bit.lshift(1, 16), -- Whether the unit is in PVP or not
    LIVING         = bit.lshift(1, 17), -- Living, dead or ghost.
    TAPPED         = bit.lshift(1, 18), -- True if someone else tapped the unit
    ISVISIBLE      = bit.lshift(1, 19), -- True if the unit is visible
    INHEALINGRANGE = bit.lshift(1, 20), -- True if the unit is in healing range
    CREATURETYPE   = bit.lshift(1, 21), -- Localized creature type or nil
    THREAT         = bit.lshift(1, 22), -- Player threat vs. unit
    LOOT_MASTER    = bit.lshift(1, 23), -- Unit is loot master
    EXISTS         = bit.lshift(1, 24), -- Whether or not a unit exists
    GUID           = bit.lshift(1, 25), -- The unit's globally unique id
    COMBAT_SPELL   = bit.lshift(1, 26), -- Spellcast detected in combat log
    AFKSTATUS      = bit.lshift(1, 27), -- Whether the unit is AFK or not
    MODEL          = bit.lshift(1, 28), -- Unit model
    ROLE           = bit.lshift(1, 29), -- LFG role
}

-- Map names in the set "UPDATE_FOO" to the bit TGU.FLAGS.FOO.
TGU.FLAG_HANDLERS = {}
local count = 0
for k, v in pairs(TGU.FLAGS) do
    count = count + 1
    TGU.FLAG_HANDLERS["UPDATE_"..k] = v
end
TGU.NUMFLAGS = count
TGU.LASTFLAG = bit.lshift(1,TGU.NUMFLAGS)

-- This bitmask describes the set of attributes for which the game engine
-- generates events notifying us of a change.  These events are generated only
-- for the player.
TGU.PLAYEREVENT_MASK = bit.bor(
    TGU.FLAGS.ISPLAYERTARGET,
    --TGU.FLAGS.COMBOPOINTS,
    TGU.FLAGS.NAME,
    TGU.FLAGS.CLASS,
    TGU.FLAGS.HEALTH,
    TGU.FLAGS.POWER,
    TGU.FLAGS.LEVEL,
    TGU.FLAGS.COMBAT,
    TGU.FLAGS.BUFFS,
    TGU.FLAGS.DEBUFFS,
    TGU.FLAGS.PLAYER_SPELL,
    TGU.FLAGS.LEADER,
    TGU.FLAGS.RAIDICON,
    TGU.FLAGS.PVPSTATUS,
    TGU.FLAGS.AFKSTATUS,
    TGU.FLAGS.THREAT,
    TGU.FLAGS.LOOT_MASTER,
    TGU.FLAGS.MODEL)
TGU.PLAYERPOLL_MASK = bit.bor(
    TGU.FLAGS.REACTION,
    TGU.FLAGS.NPC,
    TGU.FLAGS.CLASSIFICATION,
    TGU.FLAGS.LIVING,
    TGU.FLAGS.TAPPED,
    TGU.FLAGS.ISVISIBLE,
    TGU.FLAGS.INHEALINGRANGE,
    TGU.FLAGS.CREATURETYPE,
    TGU.FLAGS.EXISTS,
    TGU.FLAGS.GUID,
    TGU.FLAGS.ROLE)
TGU.ALL_PLAYER_FLAGS = bit.bor(TGU.PLAYEREVENT_MASK, TGU.PLAYERPOLL_MASK)

-- This bitmask describes the set of attributes for which the game engine
-- generates events notifying us of a change for all of the non-player unit
-- IDs which the game generates events for:
--     target, pet, mouseover, partyX, raidX
TGU.NONPLAYEREVENT_MASK = bit.bor(
    TGU.FLAGS.ISPLAYERTARGET,
    TGU.FLAGS.NAME,
    TGU.FLAGS.CLASS,
    TGU.FLAGS.HEALTH,
    TGU.FLAGS.POWER,
    TGU.FLAGS.LEVEL,
    TGU.FLAGS.BUFFS,
    TGU.FLAGS.DEBUFFS,
    TGU.FLAGS.LEADER,
    TGU.FLAGS.RAIDICON,
    TGU.FLAGS.PVPSTATUS,
    TGU.FLAGS.AFKSTATUS,
    TGU.FLAGS.COMBAT_SPELL,
    TGU.FLAGS.MODEL)
TGU.NONPLAYERPOLL_MASK = bit.bor(
    --TGU.FLAGS.COMBOPOINTS,
    TGU.FLAGS.COMBAT,
    TGU.FLAGS.REACTION,
    TGU.FLAGS.NPC,
    TGU.FLAGS.CLASSIFICATION,
    TGU.FLAGS.LIVING,
    TGU.FLAGS.TAPPED,
    TGU.FLAGS.ISVISIBLE,
    TGU.FLAGS.INHEALINGRANGE,
    TGU.FLAGS.CREATURETYPE,
    TGU.FLAGS.THREAT,
    TGU.FLAGS.EXISTS,
    TGU.FLAGS.GUID,
    TGU.FLAGS.ROLE)
TGU.ALL_NONPLAYER_FLAGS = bit.bor(TGU.NONPLAYEREVENT_MASK,
                                  TGU.NONPLAYERPOLL_MASK)

-- Table that tells us all the flags based on unit ID.  If a unit ID is not
-- present in this table, then TGU.ALL_NONPLAYER_FLAGS applies.
TGU.ALLFLAGS = {
    ["player"] = TGU.ALL_PLAYER_FLAGS,
}

-- Table that tells us what state needs to be polled based on unit ID.  If a
-- unit ID is not present in this table, then all of its state requires
-- polling (TGU.ALL_NONPLAYER_FLAGS).
TGU.POLLFLAGS = {
    ["player"]    = TGU.PLAYERPOLL_MASK,
    ["target"]    = TGU.NONPLAYERPOLL_MASK,
    ["pet"]       = TGU.NONPLAYERPOLL_MASK,
    ["mouseover"] = TGU.NONPLAYERPOLL_MASK,
    ["party1"]    = TGU.NONPLAYERPOLL_MASK,
    ["party2"]    = TGU.NONPLAYERPOLL_MASK,
    ["party3"]    = TGU.NONPLAYERPOLL_MASK,
    ["party4"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid1"]     = TGU.NONPLAYERPOLL_MASK,
    ["raid2"]     = TGU.NONPLAYERPOLL_MASK,
    ["raid3"]     = TGU.NONPLAYERPOLL_MASK,
    ["raid4"]     = TGU.NONPLAYERPOLL_MASK,
    ["raid5"]     = TGU.NONPLAYERPOLL_MASK,
    ["raid6"]     = TGU.NONPLAYERPOLL_MASK,
    ["raid7"]     = TGU.NONPLAYERPOLL_MASK,
    ["raid8"]     = TGU.NONPLAYERPOLL_MASK,
    ["raid9"]     = TGU.NONPLAYERPOLL_MASK,
    ["raid10"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid11"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid12"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid13"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid14"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid15"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid16"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid17"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid18"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid19"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid20"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid21"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid22"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid23"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid24"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid25"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid26"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid27"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid28"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid29"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid30"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid31"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid32"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid33"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid34"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid35"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid36"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid37"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid38"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid39"]    = TGU.NONPLAYERPOLL_MASK,
    ["raid40"]    = TGU.NONPLAYERPOLL_MASK,
}

-- Table that maps a unit id to that unit id's pet id.  This is used when the
-- UNIT_PET event fires, which gives us the pet's owner as the id rather than
-- the pet itself.
TGU.PETMAP = { 
    ["player"] = "pet",
    ["party1"] = "partypet1",
    ["party2"] = "partypet2",
    ["party3"] = "partypet3",
    ["party4"] = "partypet4",
    ["raid1"]  = "raidpet1",
    ["raid2"]  = "raidpet2",
    ["raid3"]  = "raidpet3",
    ["raid4"]  = "raidpet4",
    ["raid5"]  = "raidpet5",
    ["raid6"]  = "raidpet6",
    ["raid7"]  = "raidpet7",
    ["raid8"]  = "raidpet8",
    ["raid9"]  = "raidpet9",
    ["raid10"] = "raidpet10",
    ["raid11"] = "raidpet11",
    ["raid12"] = "raidpet12",
    ["raid13"] = "raidpet13",
    ["raid14"] = "raidpet14",
    ["raid15"] = "raidpet15",
    ["raid16"] = "raidpet16",
    ["raid17"] = "raidpet17",
    ["raid18"] = "raidpet18",
    ["raid19"] = "raidpet19",
    ["raid20"] = "raidpet20",
    ["raid21"] = "raidpet21",
    ["raid22"] = "raidpet22",
    ["raid23"] = "raidpet23",
    ["raid24"] = "raidpet24",
    ["raid25"] = "raidpet25",
    ["raid26"] = "raidpet26",
    ["raid27"] = "raidpet27",
    ["raid28"] = "raidpet28",
    ["raid29"] = "raidpet29",
    ["raid30"] = "raidpet30",
    ["raid31"] = "raidpet31",
    ["raid32"] = "raidpet32",
    ["raid33"] = "raidpet33",
    ["raid34"] = "raidpet34",
    ["raid35"] = "raidpet35",
    ["raid36"] = "raidpet36",
    ["raid37"] = "raidpet37",
    ["raid38"] = "raidpet38",
    ["raid39"] = "raidpet39",
    ["raid40"] = "raidpet40",
}

-- Party and raid roster.
TGU.ROSTER = {
    "party1", "party2", "party3", "party4",
    "raid1",  "raid2",  "raid3",  "raid4",  "raid5",  "raid6",  "raid7",
    "raid8",  "raid9",  "raid10", "raid11", "raid12", "raid13", "raid14",
    "raid15", "raid16", "raid17", "raid18", "raid19", "raid20", "raid21",
    "raid22", "raid23", "raid24", "raid25", "raid26", "raid27", "raid28",
    "raid29", "raid30", "raid31", "raid32", "raid33", "raid34", "raid35",
    "raid36", "raid37", "raid38", "raid39", "raid40",
}

-- Reaction types.
TGU.REACTION_FRIENDLY = 0 -- Unit is "green", won't aggro
TGU.REACTION_NEUTRAL  = 1 -- Unit is "yellow", won't aggro unless attacked
TGU.REACTION_HOSTILE  = 2 -- Unit is "red", will aggro

-- List of classification types.
TGU.CLASSIFICATION_MINUS      = "minus"
TGU.CLASSIFICATION_TRIVIAL    = "trivial"
TGU.CLASSIFICATION_NORMAL     = "normal"
TGU.CLASSIFICATION_RARE       = "rare"
TGU.CLASSIFICATION_ELITE      = "elite"
TGU.CLASSIFICATION_RARE_ELITE = "rareelite"
TGU.CLASSIFICATION_BOSS       = "worldboss"

-- List of PVP types.
TGU.PVP_NONE        = 0   -- Not flagged
TGU.PVP_FLAGGED     = 1   -- PVP flagged
TGU.PVP_FFA_FLAGGED = 2   -- PVP free-for-all flagged

-- List of living types.
TGU.LIVING_ALIVE = 0      -- Unit is alive
TGU.LIVING_DEAD  = 1      -- Unit is dead
TGU.LIVING_GHOST = 2      -- Unit is a ghost

-- List of spell IDs that are channeled.  These are used to generate a list of
-- channeled spell names used when parsing the combat log.
TGU.CHANNELED_SPELL_IDS = {
    746,        -- First Aid
    13278,      -- Gnomnish Death Ray
    20577,      -- Cannibalize
    10797,      -- Starshards
    16430,      -- Soul Tap
    24323,      -- Blood Siphon
    27640,      -- Baron Rivendare's Soul Drain
    7290,       -- Soul Siphon
    24322,      -- Blood Siphon
    27177,      -- Defile
    17401,      -- Hurricane
    740,        -- Tranquility
    20687,      -- Starfall
    6197,       -- Eagle Eye
    1002,       -- Eyes of the Beast
    1510,       -- Volley
    136,        -- Mend Pet
    5143,       -- Arcane Missiles
    7268,       -- Arcane Missile
    10,         -- Blizzard
    12051,      -- Evocation
    15407,      -- Mind Flay
    2096,       -- Mind Vision
    605,        -- Mind Control
    126,        -- Eye of Kilrogg
    689,        -- Drain Life
    5138,       -- Drain Mana
    1120,       -- Drain Soul
    5740,       -- Rain Of Fire
    1949,       -- Hellfire
    755,        -- Health Funnel
    17854,      -- Consume Shadows
    6358,       -- Seduction
}
TGU.CHANNELED_SPELL_NAME_TO_ID = {}
for _, id in ipairs(TGU.CHANNELED_SPELL_IDS) do
    TGU.CHANNELED_SPELL_NAME_TO_ID[GetSpellInfo(id)] = id
end

-- List of spells we use to test if units are in healing range.
TGU.HEALING_RANGE_TABLE = {
    ["PRIEST"]  = "Heal",
    ["DRUID"]   = "Healing Touch",
    ["PALADIN"] = "Holy Light",
    ["SHAMAN"]  = "Healing Wave",
}

-- This is a template unit, used when the template editor is open so that the
-- user can see various made-up stats.
TGU.TEMPLATE_UNIT =
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
    reaction       = TGU.REACTION_FRIENDLY,
    classification = TGU.CLASSIFICATION_ELITE,
    pvpStatus      = TGU.PVP_FLAGGED,
    living         = TGU.LIVING_ALIVE,
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
