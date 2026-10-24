function GetDefaultRouletteConnections()
    local connects = {
        -- 2:1 Rows
        {
            wager = 0,
            numbers = {"3", "6", "9", "12", "15", "18", "21", "24", "27", "30", "33", "36"},
            x = -2000,
            y = 0,
            width = 0,
            height = 0,
        },
        {
            wager = 0,
            numbers = {"2", "5", "8", "11", "14", "17", "20", "23", "26", "29", "32", "35"},
            x = -2000,
            y = 0,
            width = 0,
            height = 0,
        },
        {
            wager = 0,
            numbers = {"1", "4", "7", "10", "13", "16", "19", "22", "25", "28", "31", "34"},
            x = -2000,
            y = 0,
            width = 0,
            height = 0,
        },
        -- Section Row 1 (1-12, 13-24, 25-36)
        {
            wager = 0,
            numbers = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"},
            x = -2000,
            y = 0,
            width = 0,
            height = 0,
        },
        {
            wager = 0,
            numbers = {"13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24"},
            x = -2000,
            y = 0,
            width = 0,
            height = 0,
        },
        {
            wager = 0,
            numbers = {"25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36"},
            x = -2000,
            y = 0,
            width = 0,
            height = 0,
        },
        -- Section Row 2 (1-18, Even, Red, Black, Odd, 19-36)
        {
            wager = 0,
            numbers = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18"},
            x = -2000,
            y = 0,
            width = 0,
            height = 0,
        },
        {
            wager = 0,
            numbers = {"2", "4", "6", "8", "10", "12", "14", "16", "18", "20", "22", "24", "26", "28", "30", "32", "34", "36"},
            x = -2000,
            y = 0,
            width = 0,
            height = 0,
        },
        {
            wager = 0,
            numbers = {"1", "3", "5", "7", "9", "12", "14", "16", "18", "19", "21", "23", "25", "27", "30", "32", "34", "36"},
            x = -2000,
            y = 0,
            width = 0,
            height = 0,
        },
        {
            wager = 0,
            numbers = {"2", "4", "6", "8", "10", "11", "13", "15", "17", "20", "22", "24", "26", "28", "29", "31", "33", "35"},
            x = -2000,
            y = 0,
            width = 0,
            height = 0,
        },
        {
            wager = 0,
            numbers = {"1", "3", "5", "7", "9", "11", "13", "15", "17", "19", "21", "23", "25", "27", "29", "31", "33", "35"},
            x = -2000,
            y = 0,
            width = 0,
            height = 0,
        },
        {
            wager = 0,
            numbers = {"19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36"},
            x = -2000,
            y = 0,
            width = 0,
            height = 0,
        },
        -- 0's
        {
            wager = 0,
            numbers = {"0", "00"},
            x = 0,
            y = 50,
            width = 30,
            height = 5,
        },
        {
            wager = 0,
            numbers = {"00"},
            x = 0,
            y = 0,
            width = 26,
            height = 48,
        },
        {
            wager = 0,
            numbers = {"0"},
            x = 0,
            y = 57,
            width = 26,
            height = 48,
        },
    }

    local numbers = {
        {
            {"3"}, {"6"}, {"9"}, {"12"}, {"15"}, {"18"}, {"21"}, {"24"}, {"27"}, {"30"}, {"33"}, {"36"}
        },
        {
            {"2"}, {"5"}, {"8"}, {"11"}, {"14"}, {"17"}, {"20"}, {"23"}, {"26"}, {"29"}, {"32"}, {"35"}
        },
        {
            {"1"}, {"4"}, {"7"}, {"10"}, {"13"}, {"16"}, {"19"}, {"22"}, {"25"}, {"28"}, {"31"}, {"34"}
        }
    }

    for i = 1, #numbers do
        for j = 1, #numbers[i] do
            table.insert(connects, {
                wager = 0,
                numbers = numbers[i][j],
                x = 32 + ((j - 1) * 35),
                y = 3 + ((i - 1) * 35),
                width = 30,
                height = 30,
            })
        end
    end

    local splits = {
        {
            {"00", "3"},
            {"3", "6"},
            {"6", "9"},
            {"9", "12"},
            {"12", "15"},
            {"15", "18"},
            {"18", "21"},
            {"21", "24"},
            {"24", "27"},
            {"27", "30"},
            {"30", "33"},
            {"33", "36"},
        },
        {
            {"00", "0", "2"},
            {"2", "5"},
            {"5", "8"},
            {"8", "11"},
            {"11", "14"},
            {"14", "17"},
            {"17", "20"},
            {"20", "23"},
            {"23", "26"},
            {"26", "29"},
            {"29", "32"},
            {"32", "35"},
        },
        {
            {"0", "1"},
            {"1", "4"},
            {"4", "7"},
            {"7", "10"},
            {"10", "13"},
            {"13", "16"},
            {"16", "19"},
            {"19", "22"},
            {"22", "25"},
            {"25", "28"},
            {"28", "31"},
            {"31", "34"},
        }
    }
    for i = 1, #splits do
        for j = 1, #splits[i] do
            table.insert(connects, {
                wager = 0,
                numbers = splits[i][j],
                x = 28 + ((j - 1) * 35),
                y = 5 + ((i - 1) * 35),
                width = 5,
                height = 25,
            })
        end
    end
    local verticalSplits = {
        {
            {"3", "2"},
            {"6", "5"},
            {"9", "8"},
            {"12", "11"},
            {"15", "14"},
            {"18", "17"},
            {"21", "20"},
            {"24", "23"},
            {"27", "26"},
            {"30", "29"},
            {"33", "32"},
            {"36", "35"},
        },
        {
            {"2", "1"},
            {"5", "4"},
            {"8", "7"},
            {"11", "10"},
            {"14", "13"},
            {"17", "16"},
            {"20", "19"},
            {"23", "22"},
            {"26", "25"},
            {"29", "28"},
            {"32", "31"},
            {"35", "34"},
        },
        {
            {"1", "2", "3"},
            {"4", "5", "6"},
            {"7", "8", "9"},
            {"10", "11", "12"},
            {"13", "14", "15"},
            {"16", "17", "18"},
            {"19", "20", "21"},
            {"22", "23", "24"},
            {"25", "26", "27"},
            {"28", "29", "30"},
            {"31", "32", "33"},
            {"34", "35", "36"},
        }
    }
    for i = 1, #verticalSplits do
        for j = 1, #verticalSplits[i] do
            table.insert(connects, {
                wager = 0,
                numbers = verticalSplits[i][j],
                x = 34 + ((j - 1) * 35),
                y = 34 + ((i - 1) * 35),
                width = 28,
                height = 5,
            })
        end
    end
    local intersections = {
        {
            {"00", "3", "2"},
            {"3", "6", "5", "2"},
            {"6", "9", "8", "5"},
            {"9", "12", "11", "8"},
            {"12", "15", "14", "11"},
            {"15", "18", "17", "14"},
            {"18", "21", "20", "17"},
            {"21", "24", "23", "20"},
            {"24", "27", "26", "23"},
            {"27", "30", "29", "26"},
            {"30", "33", "32", "29"},
            {"33", "36", "35", "32"},
        },
        {
            {"0", "2", "1"},
            {"2", "5", "4", "1"},
            {"5", "8", "7", "4"},
            {"8", "11", "10", "7"},
            {"11", "14", "13", "10"},
            {"14", "17", "16", "13"},
            {"17", "20", "19", "16"},
            {"20", "23", "22", "19"},
            {"23", "26", "25", "22"},
            {"26", "29", "28", "25"},
            {"29", "32", "31", "28"},
            {"32", "35", "34", "31"},
        },
        {
            {"0", "00", "3", "2", "1"},
            {"1", "2", "3", "6", "5", "4"},
            {"4", "5", "6", "9", "8", "7"},
            {"7", "8", "9", "12", "11", "10"},
            {"10", "11", "12", "15", "14", "13"},
            {"13", "14", "15", "18", "17", "16"},
            {"16", "17", "18", "21", "20", "19"},
            {"19", "20", "21", "24", "23", "22"},
            {"22", "23", "24", "27", "26", "25"},
            {"25", "26", "27", "30", "29", "28"},
            {"28", "29", "30", "33", "32", "31"},
            {"31", "32", "33", "36", "35", "34"},
        }
    }
    for i = 1, #intersections do
        for j = 1, #intersections[i] do
            table.insert(connects, {
                wager = 0,
                numbers = intersections[i][j],
                x = 28 + ((j - 1) * 35),
                y = 33 + ((i - 1) * 35),
                width = 5,
                height = 5,
            })
        end
    end
    return connects
end

function ConvertWagersToPositions(connects)
    local numbers = {
        {
            {"00"}, {"0"},
        },
        {
            {"1"}, {"4"}, {"7"}, {"10"}, {"13"}, {"16"}, {"19"}, {"22"}, {"25"}, {"28"}, {"31"}, {"34"}
        },
        {
            {"2"}, {"5"}, {"8"}, {"11"}, {"14"}, {"17"}, {"20"}, {"23"}, {"26"}, {"29"}, {"32"}, {"35"}
        },
        {
            {"3"}, {"6"}, {"9"}, {"12"}, {"15"}, {"18"}, {"21"}, {"24"}, {"27"}, {"30"}, {"33"}, {"36"}
        },

    }
    local positions = {}
    for i=1, #numbers do
        for b=1, #numbers[i] do 
            local currentNumber = numbers[i][b][1]
            local totalWager = 0
            for j=1, #connects do 
                for k=1, #connects[j].numbers do
                    if connects[j].numbers[k] == currentNumber then
                        totalWager = totalWager + (connects[j].wager / #connects[j].numbers)
                    end
                end
            end
            positions[#positions + 1] = {
                number = currentNumber,
                wager = totalWager
            }
        end
    end
    return positions
end

function GetRouletteConnectPositions()
    local connects = {
        {
            wager = 0,
            numbers = {"00"},
            x = -0.1525,
            y = 0.11,
            width = 26,
            height = 48,
        },
        {
            wager = 0,
            numbers = {"0"},
            x = -0.1525,
            y = -0.15,
            width = 26,
            height = 48,
        },
    }

    local numbers = {
        {
            {"3"}, {"6"}, {"9"}, {"12"}, {"15"}, {"18"}, {"21"}, {"24"}, {"27"}, {"30"}, {"33"}, {"36"}
        },
        {
            {"2"}, {"5"}, {"8"}, {"11"}, {"14"}, {"17"}, {"20"}, {"23"}, {"26"}, {"29"}, {"32"}, {"35"}
        },
        {
            {"1"}, {"4"}, {"7"}, {"10"}, {"13"}, {"16"}, {"19"}, {"22"}, {"25"}, {"28"}, {"31"}, {"34"}
        }
    }

    for i = 1, #numbers do
        for j = 1, #numbers[i] do
            table.insert(connects, {
                wager = 0,
                numbers = numbers[i][j],
                x = (-0.055) + ((j - 1) * 0.081),
                y = (-0.19) + ((i - 1) * 0.165),
                width = 30,
                height = 30,
            })
        end
    end

    return connects
end

function CreateEmptyRouletteConnections()
    local connects = GetDefaultRouletteConnections()
    local data = {}
    for i=1, #connects do
        data[i] = {}
    end
    return data
end

function GetRouletteTotalWager(connects)
    local totalWager = 0
    for i=1, #connects do
        totalWager = totalWager + connects[i].wager
    end
    return totalWager
end

-- Compress connects into just the wager values (static layout is rebuilt locally).
function GetRouletteWagersOnly(connects)
    local wagers = {}
    if not connects then return wagers end
    for i=1, #connects do
        wagers[i] = connects[i].wager or 0
    end
    return wagers
end

-- Rebuild a full connects table from a wagers-only array using the default layout.
function ApplyRouletteWagers(wagers)
    local connects = GetDefaultRouletteConnections()
    if wagers then
        for i=1, #connects do
            -- Whole chips only: inventories round fractional counts.
            local w = SanitizeInt(wagers[i], 0)
            connects[i].wager = w or 0
        end
    end
    return connects
end
