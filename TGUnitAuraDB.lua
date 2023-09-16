local improvedSWPRank = 0
local _, class = UnitClass("player")
if class == "PRIEST" then
    _, _, _, _, improvedSWPRank = GetTalentInfo(3,4)
end

-- The list of heal or damage over time spells that we are interested in
-- tracking.
TGUnit.AuraDuration = {
    -- ************************ Priest Spells ***************************
    -- Renew
    [139]   = 15,
    [6074]  = 15,
    [6075]  = 15,
    [6076]  = 15,
    [6077]  = 15,
    [6078]  = 15,
    [10927] = 15,
    [10928] = 15,
    [10929] = 15,
    [25315] = 15,

    -- Power Word: Fortitude
    [1243]  = 1800,
    [1244]  = 1800,
    [1245]  = 1800,
    [2791]  = 1800,
    [10937] = 1800,
    [10938] = 1800,

    -- Power Word: Shield
    [17]    = 30,
    [592]   = 30,
    [600]   = 30,
    [3747]  = 30,
    [6065]  = 30,
    [6066]  = 30,
    [10898] = 30,
    [10899] = 30,
    [10900] = 30,
    [10901] = 30,

    -- Weakend Soul
    [6788]  = 15,

    -- Shadow Word: Pain
    [589]   = 18 + 3*improvedSWPRank,
    [594]   = 18 + 3*improvedSWPRank,
    [970]   = 18 + 3*improvedSWPRank,
    [992]   = 18 + 3*improvedSWPRank,
    [2767]  = 18 + 3*improvedSWPRank,
    [10892] = 18 + 3*improvedSWPRank,
    [10893] = 18 + 3*improvedSWPRank,
    [10894] = 18 + 3*improvedSWPRank,

    -- Shackle Undead
    [9484]  = 30,
    [9485]  = 40,
    [10955] = 50,

    -- Abolish Disease
    [552]   = 20,

    -- Fear Ward
    [6346]  = 600,

    -- ************************ Mage Spells ***************************
    -- Arcane Intellect
    [1459]  = 1800,
    [1460]  = 1800,
    [1461]  = 1800,
    [10156] = 1800,
    [10157] = 1800,

    -- Polymorph
    [118]   = 20,
    [12824] = 30,
    [12825] = 40,
    [12826] = 50,
    [28270] = 50,
    [28271] = 50,
    [28272] = 50,

    -- Frostbolt (slow)
    [116]   = 5,
    [205]   = 6,
    [837]   = 6,
    [7322]  = 7,
    [8406]  = 7,
    [8407]  = 8,
    [8408]  = 8,
    [10179] = 9,
    [10180] = 9,
    [10181] = 9,
    [25304] = 9,

    -- Fireball (burn)
    [133]   = 4,
    [143]   = 6,
    [145]   = 6,
    [3140]  = 8,
    [8400]  = 8,
    [8401]  = 8,
    [8402]  = 8,
    [10148] = 8,
    [10149] = 8,
    [10150] = 8,
    [10151] = 8,
    [25306] = 8,

    -- Slow Fall
    [130]   = 30,

    -- Dampen Magic
    [604]   = 600,
    [8450]  = 600,
    [8451]  = 600,
    [10173] = 600,
    [10174] = 600,

    -- Amplify Magic
    [1008]  = 600,
    [8455]  = 600,
    [10169] = 600,
    [10170] = 600,

    -- Counterspell
    [2139]  = 10,

    -- ************************ Warrior Spells ***************************
    -- Rend
    [772]   = 9,
    [6546]  = 12,
    [6547]  = 15,
    [6548]  = 18,
    [11572] = 21,
    [11573] = 21,
    [11574] = 21,

    -- Sunder Armor
    [7386]  = 30,
    [7405]  = 30,
    [8380]  = 30,
    [11596] = 30,
    [11597] = 30,

    -- ************************ Warlock Spells ***************************
    -- Immolate
    [348]   = 15,
    [707]   = 15,
    [1094]  = 15,
    [2941]  = 15,
    [11665] = 15,
    [11667] = 15,
    [11668] = 15,
    [25309] = 15,

    -- Corruption
    [172]   = 12,
    [6222]  = 15,
    [6223]  = 18,
    [7648]  = 18,
    [11671] = 18,
    [11672] = 18,
    [25311] = 18,

    -- Curse of Agony
    [980]   = 24,
    [1014]  = 24,
    [6217]  = 24,
    [11711] = 24,
    [11712] = 24,
    [11713] = 24,

    -- Siphon Life
    [18265] = 30,
    [18879] = 30,
    [18880] = 30,
    [18881] = 30,

    -- Banish
    [710]   = 30,
    [18647] = 30,
}

TGUnit.AuraNames = {}
for k in pairs(TGUnit.AuraDuration) do
    local name = GetSpellInfo(k)
    if name == nil then
        print("No name for spell "..k.."!")
    else
        TGUnit.AuraNames[GetSpellInfo(k)] = 1
    end
end
