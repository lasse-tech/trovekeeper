local ADDON, T = ...

-- Chest coordinates are percentages on the delve's own map.
--
-- The delve's uiMapID is deliberately absent: Blizzard does not publish it and
-- no guide lists it, so Core\Zones.lua works out which delve the player is in
-- and learns the id on the spot, and Core\Discovery.lua corrects the
-- coordinates from the game's own vignettes as chests come into range.
--
-- `entrance` is on the outdoor zone map, where the uiMapID *is* known. It is
-- optional: two delves sit in Voidstorm, which spans uiMapIDs 2405 and 2444,
-- and no source pins down which of the two the entrances belong to. Twilight
-- Crypts is missing entrance coordinates outright. A wrong entrance pin is
-- worse than none, so those three carry no entrance until verified in-game.
--
-- `mapNamePattern` matches the delve's own map or instance name, lowercased.
-- It only fires on English clients for the delves whose names translate, which
-- is why Zones.lua also identifies a delve by which entrance the player walked
-- into. Proper nouns like Gnarldor and Atal'Aman survive every locale.
--
-- `zone` is the outdoor zone the delve sits in, and only groups the Delver's
-- Call list; the entrance pin uses `entrance.uiMapID` instead. That is why both
-- Voidstorm delves can carry a zone while their entrance stays absent: naming
-- the zone wrongly costs a heading, naming the map wrongly costs a wrong pin.
--
-- Zone uiMapIDs used below, and their display order, live in T.ZoneOrder.

T.Delves = {
    {
        key = "atal-aman",
        name = "Atal'Aman",
        zone = 2437,
        mapNamePattern = "atal",
        achievementID = 61863,
        entrance = { uiMapID = 2437, x = 63.78, y = 80.15 },
        chests = {
            { x = 48.33, y = 50.44 },
            { x = 53.15, y = 57.99 },
            { x = 52.98, y = 65.38 },
        },
    },
    {
        key = "the-shadow-enclave",
        name = "The Shadow Enclave",
        zone = 2395,
        mapNamePattern = "shadow enclave",
        achievementID = 61892,
        entrance = { uiMapID = 2395, x = 45.55, y = 86.31 },
        chests = {
            { x = 54.58, y = 48.93 },
            { x = 56.07, y = 36.07 },
            { x = 54.62, y = 84.87 },
        },
    },
    {
        key = "parhelion-plaza",
        name = "Parhelion Plaza",
        zone = 2424,
        mapNamePattern = "parhelion",
        achievementID = 61893,
        entrance = { uiMapID = 2424, x = 47.74, y = 41.58 },
        chests = {
            { x = 9.63, y = 50.36 },
            { x = 40.91, y = 86.91 },
            { x = 22.41, y = 61.01 },
        },
    },
    {
        key = "collegiate-calamity",
        name = "Collegiate Calamity",
        zone = 2393,
        mapNamePattern = "collegiate",
        achievementID = 61894,
        entrance = { uiMapID = 2393, x = 40.76, y = 54.06 },
        chests = {
            { x = 30.96, y = 12.51 },
            { x = 81.26, y = 32.11 },
            { x = 29.53, y = 53.97 },
        },
    },
    {
        key = "the-darkway",
        name = "The Darkway",
        zone = 2393,
        mapNamePattern = "darkway",
        achievementID = 61895,
        entrance = { uiMapID = 2393, x = 39.31, y = 32.07 },
        chests = {
            { x = 45.84, y = 45.55 },
            { x = 52.99, y = 43.07 },
            { x = 41.62, y = 48.25 },
        },
    },
    {
        key = "twilight-crypts",
        name = "Twilight Crypts",
        zone = 2437,
        mapNamePattern = "twilight",
        achievementID = 61896,
        -- Entrance is in Zul'Aman (2437); no source gives the coordinates.
        chests = {
            { x = 57.23, y = 85.52 },
            { x = 46.96, y = 49.84 },
            { x = 21.72, y = 36.84 },
        },
    },
    {
        key = "the-grudge-pit",
        name = "The Grudge Pit",
        zone = 2413,
        mapNamePattern = "grudge",
        achievementID = 61897,
        entrance = { uiMapID = 2413, x = 70.30, y = 67.14 },
        chests = {
            { x = 67.33, y = 28.77 },
            { x = 67.33, y = 59.30 },
            { x = 70.00, y = 32.20 },
        },
    },
    {
        key = "the-gulf-of-memory",
        name = "The Gulf of Memory",
        zone = 2413,
        mapNamePattern = "gulf",
        achievementID = 61898,
        entrance = { uiMapID = 2413, x = 45.36, y = 51.34 },
        chests = {
            { x = 39.90, y = 26.65 },
            { x = 55.24, y = 27.07 },
            { x = 54.41, y = 25.09 },
        },
    },
    {
        key = "sunkiller-sanctum",
        name = "Sunkiller Sanctum",
        zone = 2405,
        mapNamePattern = "sunkiller",
        achievementID = 61899,
        -- Entrance is in Voidstorm at 54.78, 47.27 - map id unresolved.
        chests = {
            { x = 49.79, y = 50.50 },
            { x = 60.14, y = 40.75 },
            { x = 38.16, y = 48.99 },
        },
    },
    {
        key = "shadowguard-point",
        name = "Shadowguard Point",
        zone = 2405,
        mapNamePattern = "shadowguard",
        achievementID = 61900,
        -- Entrance is in Voidstorm at 37.38, 47.74 - map id unresolved.
        chests = {
            { x = 41.79, y = 53.72 },
            { x = 58.26, y = 41.56 },
            { x = 58.67, y = 60.53 },
        },
    },
    {
        key = "gnarldor-isle",
        name = "Gnarldor Isle",
        zone = 2512,
        mapNamePattern = "gnarldor",
        achievementID = 63170,
        entrance = { uiMapID = 2512, x = 64.45, y = 77.73 },
        chests = {
            { x = 61.36, y = 67.87 },
            { x = 53.07, y = 41.08 },
            { x = 28.05, y = 38.33 },
        },
    },
    {
        key = "the-ring-of-glory",
        name = "The Ring of Glory",
        zone = 2512,
        mapNamePattern = "ring of glory",
        achievementID = 63171,
        entrance = { uiMapID = 2512, x = 71.20, y = 56.54 },
        chests = {
            { x = 42.90, y = 23.11 },
            { x = 48.09, y = 93.23 },
            { x = 26.02, y = 73.18 },
        },
    },
}

-- Delves Trovekeeper tracks the Delver's Call for, but nothing else: The War
-- Within's twelve. They carry no chest coordinates, no achievement and no
-- entrance, because the Sturdy Chest data in this addon is Midnight's. Only
-- `questPattern` matters here - the lowercased fragment of the delve name that
-- a "Delver's Call: <delve>" quest title has to contain. Proper nouns are
-- preferred over translatable words for exactly the reason mapNamePattern is.
T.LegacyDelves = {
    { key = "earthcrawl-mines",    name = "Earthcrawl Mines",     zone = 2248, questPattern = "earthcrawl" },
    { key = "kriegvals-rest",      name = "Kriegval's Rest",      zone = 2248, questPattern = "kriegval" },
    { key = "fungal-folly",        name = "Fungal Folly",         zone = 2248, questPattern = "fungal" },
    { key = "the-waterworks",      name = "The Waterworks",       zone = 2214, questPattern = "waterworks" },
    { key = "the-dread-pit",       name = "The Dread Pit",        zone = 2214, questPattern = "dread pit" },
    { key = "the-skittering-breach", name = "The Skittering Breach", zone = 2215, questPattern = "skittering" },
    { key = "nightfall-sanctum",   name = "Nightfall Sanctum",    zone = 2215, questPattern = "nightfall" },
    { key = "the-sinkhole",        name = "The Sinkhole",         zone = 2215, questPattern = "sinkhole" },
    { key = "mycomancer-cavern",   name = "Mycomancer Cavern",    zone = 2215, questPattern = "mycomancer" },
    { key = "the-spiral-weave",    name = "The Spiral Weave",     zone = 2255, questPattern = "spiral weave" },
    { key = "tak-rethan-abyss",    name = "Tak-Rethan Abyss",     zone = 2255, questPattern = "tak-rethan" },
    { key = "the-underkeep",       name = "The Underkeep",        zone = 2255, questPattern = "underkeep" },
}

-- The order the Delver's Call list groups by: Midnight first, then The War
-- Within. The names are a fallback only - Core\Calls.lua asks the game for the
-- zone name so the headings translate, and falls back to these when a client
-- does not know the map id.
T.ZoneOrder = { 2395, 2393, 2424, 2437, 2413, 2405, 2512, 2248, 2214, 2215, 2255 }

T.ZoneNames = {
    [2395] = "Eversong Woods",
    [2393] = "Silvermoon City",
    [2424] = "Isle of Quel'Danas",
    [2437] = "Zul'Aman",
    [2413] = "Harandar",
    [2405] = "Voidstorm",
    [2512] = "Coiled Isle",
    [2248] = "Isle of Dorn",
    [2214] = "The Ringing Deeps",
    [2215] = "Hallowfall",
    [2255] = "Azj-Kahet",
}

T.DelveByKey = {}
for _, delve in ipairs(T.Delves) do
    T.DelveByKey[delve.key] = delve
end

-- Every delve with a Delver's Call, chest data or not, in one list. It is
-- deliberately a second lookup rather than an addition to DelveByKey: anything
-- that resolves a key there goes on to ask for chests, which half of these do
-- not have.
T.CallDelves = {}
T.CallDelveByKey = {}
for _, list in ipairs({ T.Delves, T.LegacyDelves }) do
    for _, delve in ipairs(list) do
        T.CallDelves[#T.CallDelves + 1] = delve
        T.CallDelveByKey[delve.key] = delve
    end
end
