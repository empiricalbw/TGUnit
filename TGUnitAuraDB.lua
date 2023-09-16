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

    -- Shadow Word: Pain
    [589]   = 18 + 3*improvedSWPRank,
    [594]   = 18 + 3*improvedSWPRank,
    [970]   = 18 + 3*improvedSWPRank,
    [992]   = 18 + 3*improvedSWPRank,
    [2767]  = 18 + 3*improvedSWPRank,
    [10892] = 18 + 3*improvedSWPRank,
    [10893] = 18 + 3*improvedSWPRank,
    [10894] = 18 + 3*improvedSWPRank,

    -- Vampiric Touch
    [34914] = {length = 15},
    [34916] = {length = 15},
    [34917] = {length = 15},


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
    [27215] = 15,

    -- Corruption
    [172]   = 12,
    [6222]  = 15,
    [6223]  = 18,
    [7648]  = 18,
    [11671] = 18,
    [11672] = 18,
    [25311] = 18,
    [27216] = 18,

    -- Curse of Agony
    [980]   = 24,
    [1014]  = 24,
    [6217]  = 24,
    [11711] = 24,
    [11712] = 24,
    [11713] = 24,
    [27218] = 24,

    -- Siphon Life
    [18265] = 30,
    [18879] = 30,
    [18880] = 30,
    [18881] = 30,

    -- Banish
    [710]   = 30,
    [18647] = 30,
}
