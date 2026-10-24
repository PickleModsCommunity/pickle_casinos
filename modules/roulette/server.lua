local LastWagers = {}
local RouletteLobbies = {}

function DoesRouletteLobbyExist(casinoId, entityId)
    if not RouletteLobbies[casinoId] then return false end
    if not RouletteLobbies[casinoId][entityId] then return false end
    return RouletteLobbies[casinoId][entityId]
end

function JoinRouletteEntity(source, casinoId, entityId, seatId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    local seatId = SanitizeInt(seatId, 1, #entity.seats) or 1
    if CurrentPlayers[source] then
        for i=1, #entity.seats do
            if entity.seats[i].source == source then
                entity.seats[i].inSeat = true
                debugPrint("PLAYER IS ALREADY IN SEAT", i)
                return i
            end
        end
        ShowNotification(source, _L("playing_other_game"))
        return
    end
    if entity.seats[seatId].source then
        seatId = nil
        for i=1, #entity.seats do
            if entity.seats[i].source == nil then
                seatId = i
                break
            end
        end
        if not seatId then
            ShowNotification(source, _L("no_seats_available"))
            return 
        end
    end
    entity.seats[seatId] = {
        source = source, 
        name = GetPlayerCharacterName(source),
        connects = GenerateRouletteDefaultWagers(),
        inSeat = true,
    }
    CurrentPlayers[source] = {casinoId = casinoId, entityId = entityId, seatId = seatId}
    if not DoesRouletteLobbyExist(casinoId, entityId) then
        StartRouletteLobby(casinoId, entityId)
    end
    SetTimeout(100 * 1, function()
        TriggerClientCasinoEvent("pickle_casinos:roulette:updateSeat", -1, casinoId, entityId, seatId, GetCompressedRouletteSeat(entity.seats[seatId]))
    end)
    ShowNotification(source, _L("joined_seat", seatId))
    return seatId
end

function GetCompressedRouletteSeat(seat)
    if not seat then return seat end
    local copy = {}
    for k, v in pairs(seat) do
        if k ~= "connects" then copy[k] = v end
    end
    copy.wagers = GetRouletteWagersOnly(seat.connects)
    return copy
end

function GetCompressedRouletteSeats(seats)
    local out = {}
    for i, seat in pairs(seats) do
        out[i] = GetCompressedRouletteSeat(seat)
    end
    return out
end

function LeaveRouletteEntity(source, casinoId, entityId, seatId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    if entity.seats[seatId].source == source then
        entity.seats[seatId] = GenerateDefaultRouletteSeat()
        SetTimeout(100 * 1, function()
            TriggerClientCasinoEvent("pickle_casinos:roulette:updateSeatWager", -1, casinoId, entityId, seatId, GetRouletteWagersOnly(entity.seats[seatId].connects))
            TriggerClientCasinoEvent("pickle_casinos:roulette:updateSeat", -1, casinoId, entityId, seatId, GetCompressedRouletteSeat(entity.seats[seatId]))
        end)
        CurrentPlayers[source] = nil
        ShowNotification(source, _L("left_roulette"))
    end
end

function GenerateDefaultRouletteSeat()
    return {
        source = nil,
        name = nil,
        connects = GenerateRouletteDefaultWagers()
    }
end

function GetRouletteEntity(casinoId, entityId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    return {
        id = entity.id,
        seats = entity.seats,
        stage = entity.stage,
        betRange = entity.betRange,
    }
end

function ProcessRouletteWager(casinoId, entityId, seat)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    local totalWager = GetRouletteTotalWager(entity.seats[seat].connects)
    if totalWager == 0 then return end
    local wager = totalWager
    if GetCasinoChips(entity.seats[seat].source, casinoId) < wager or not RemoveCasinoChips(entity.seats[seat].source, casinoId, wager) then
        ShowNotification(entity.seats[seat].source, _L("insufficient_chips_bet"))
        return false
    end
    RegisterLuckyTicketWager(entity.seats[seat].source, "roulette", wager)
    return true
end

function StartRouletteGame(casinoId, entityId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    if entity.stage.type ~= "waiting" then return end
    entity.stage = {type = "starting"}
    local hasAcceptedWager = false
    local transactions = {}
    for i=1, #entity.seats do
        local totalWager = GetRouletteTotalWager(entity.seats[i].connects)
        if not ProcessRouletteWager(casinoId, entityId, i) then
            entity.seats[i].connects = GenerateRouletteDefaultWagers()
            TriggerClientCasinoEvent("pickle_casinos:roulette:updateSeatWager", -1, casinoId, entityId, i, GetRouletteWagersOnly(entity.seats[i].connects))
        else
            transactions[entity.seats[i].source] = StartCasinoGameplayTransaction(entity.seats[i].source, casinoId, entityId, "roulette", totalWager)
            LastWagers[entity.seats[i].source] = {connects = entity.seats[i].connects, wager = totalWager}
            hasAcceptedWager = true
        end
    end
    if not hasAcceptedWager then
        StartRouletteLobby(casinoId, entityId)
        return
    end
    entity.roundPaid = false
    CreateSafeGameThread("roulette", function()
        local numbers = {"00", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36"}
        entity.stage = {type = "rolling", targetNumber = numbers[math.random(1, 38)]}
        TriggerClientCasinoEvent("pickle_casinos:roulette:updateStage", -1, casinoId, entityId, entity.stage)
        Wait(10000)
        local winningNumber = entity.stage.targetNumber
        local seats = {}
        entity.roundPaid = true
        for i=1, #entity.seats do 
            local seat = entity.seats[i]
            local connects = seat.connects
            local totalWin = 0
            -- TODO: Calculate winnings
            local data = GetDefaultRouletteConnections()
            for i=1, #data do 
                local wager = connects[i].wager
                if wager > 0 and data[i].numbers then
                    local payRatio
                    if #data[i].numbers == 1 then
                        payRatio = (Config.Roulette and Config.Roulette.StraightPayout) or 36
                    else
                        payRatio = math.floor(36 / #data[i].numbers)
                    end
                    local hasNumber = false
                    for j=1, #data[i].numbers do
                        if data[i].numbers[j] == winningNumber then
                            hasNumber = true
                            break
                        end
                    end
                    if hasNumber then 
                        totalWin = totalWin + (wager * payRatio)
                    end
                end
            end
            seats[i] = { totalWin = totalWin }
            if totalWin > 0 then
                AddCasinoChips(seat.source, casinoId, totalWin)
            end
            if transactions[seat.source] then
                EndCasinoGameplayTransaction(transactions[seat.source], seat.source, casinoId, entityId, "roulette", totalWin)
            end
        end
        entity.stage = {type = "winningNumber", winningNumber = winningNumber, seats = seats}
        TriggerClientCasinoEvent("pickle_casinos:roulette:updateStage", -1, casinoId, entityId, entity.stage)
        table.insert(entity.history, 1, winningNumber)
        if #entity.history > 30 then
            table.remove(entity.history, #entity.history)
        end
        TriggerClientCasinoEvent("pickle_casinos:roulette:updateHistory", -1, casinoId, entityId, entity.history)
        Wait(5000)
        for i=1, #entity.seats do
            entity.seats[i].connects = GenerateRouletteDefaultWagers()
            if entity.seats[i].source then
                UpdatePlayerBalance(entity.seats[i].source, casinoId)
            end
            SetTimeout(1000, function()
                TriggerClientCasinoEvent("pickle_casinos:roulette:updateSeatWager", -1, casinoId, entityId, i, GetRouletteWagersOnly(entity.seats[i].connects))
            end)
        end
        Wait(1000)
        StartRouletteLobby(casinoId, entityId)
    end, function()
        -- The round crashed: refund stakes if payouts hadn't started, then reopen the table.
        for i, seat in pairs(entity.seats) do
            if seat.source and not entity.roundPaid then
                local refund = GetRouletteTotalWager(seat.connects)
                RefundCasinoChips(seat.source, casinoId, refund)
            end
            seat.connects = GenerateRouletteDefaultWagers()
        end
        entity.stage = {type = "waiting", time = 0}
        StartRouletteLobby(casinoId, entityId)
    end)
end

function StartRouletteLobby(casinoId, entityId)
    RouletteLobbies[casinoId] = RouletteLobbies[casinoId] or {}
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    local totalPlayers = 0
    for i=1, #entity.seats do
        if entity.seats[i].source and not entity.seats[i].inSeat then
            LeaveRouletteEntity(entity.seats[i].source, casinoId, entityId, i)
        elseif entity.seats[i].source then
            totalPlayers = totalPlayers + 1
        end
    end
    if totalPlayers == 0 then
        RouletteLobbies[casinoId][entityId] = false
        return
    else
        RouletteLobbies[casinoId][entityId] = true
    end
    entity.stage = {type = "waiting", time = GetWaitingTime("roulette")}
    TriggerClientCasinoEvent("pickle_casinos:roulette:updateStage", -1, casinoId, entityId, entity.stage)
    CreateThread(function()
        while entity.stage.type == "waiting" and entity.stage.time > 1 do
            entity.stage.time = entity.stage.time - 1
            Wait(1000)
        end
        local totalWagers = 0
        for i=1, #entity.seats do
            totalWagers = totalWagers + GetRouletteTotalWager(entity.seats[i].connects)
        end
        if totalWagers > 0 then
            StartRouletteGame(casinoId, entityId)
        else
            StartRouletteLobby(casinoId, entityId)
        end
    end)
end

function GetRouletteColor(value)
    if value == 0 then
        return "green"
    end
    if value == 1 or value == 3 or value == 5 or value == 7 or value == 9 or value == 12 or value == 14 or value == 16 or value == 18 or value == 19 or value == 21 or value == 23 or value == 25 or value == 27 or value == 30 or value == 32 or value == 34 or value == 36 then
        return "red"
    end
    return "black"
end

function GenerateRouletteRows(generateType)
    local rows = {
        {
            {value = "0", color = "green"},
            {value = "00", color = "none"},
        }
    }
    for i=0, 2 do
        local row = {}
        for j=0, 11 do
            row[#row + 1] = {
                value = (3 - i) + (j * 3),
                color = GetRouletteColor((3 - i) + (j * 3)),
            }
        end
        row[#row + 1] = {
            value = "2:1",
            color = "none",
        }
        rows[#rows + 1] = row
    end
    return rows;
end

function GenerateRouletteSections(generateType)
    return {
        {
            -- 1st, 2nd, 3rd
            {},
            {},
            {},
        },
        {
            -- 1-18
            {},
            -- Even
            {},
            -- Red
            {},
            -- Black
            {},
            -- Odd
            {},
            -- 19-36
            {},
        }
    }
end

function GenerateRouletteDefaultWagers()
    return GetDefaultRouletteConnections()
end

function InitializeRouletteEntity(casinoId, entity, dataOnly)
    local entity = entity or { id = "ERR_ROULETTE_ENTITY" }
    entity.seats = {}
    entity.history = {}
    for i=0, 4 do 
        entity.seats[i] = GenerateDefaultRouletteSeat()
    end
    entity.betRange = {
        math.floor(entity.settings.maxWager / 100),
        entity.settings.maxWager
    }
    return entity
end

function GetPlayerRouletteInfo(source)
    if not source or source < 1 then return end
    for k,v in pairs(Casinos) do
        for i=1, #v.entities do
            local entity = v.entities[i]
            if entity.type == "roulette" then
                for j, v in pairs(entity.seats) do
                    if entity.seats[j].source and tonumber(entity.seats[j].source) == tonumber(source) then
                        return {casinoId = k, entityId = entity.id, seatId = j}
                    end
                end
            end
        end
    end
end

RegisterCallback("pickle_casinos:repeatRouletteWager", function(source, cb)
    PerformCooldownProcess(source)
    local info = GetPlayerRouletteInfo(source)
    if not info then return end
    local entity = GetCasinoEntity(info.casinoId, info.entityId)
    if not entity then return end
    if entity.stage.type ~= "waiting" then return end
    if not entity.seats[info.seatId].source then return end
    local lastWager = LastWagers[source]
    local totalWager = lastWager and lastWager.wager or 0
    debugPrint("REPEAT WAGER", lastWager, totalWager)
    if totalWager <= 0 or GetCasinoChips(source, info.casinoId) < totalWager then return cb({wagers = {}, wager = 0}) end
    entity.seats[info.seatId].connects = lastWager.connects
    local wagersOnly = GetRouletteWagersOnly(lastWager.connects)
    TriggerClientCasinoEvent("pickle_casinos:roulette:updateSeatWager", -1, info.casinoId, info.entityId, info.seatId, wagersOnly)
    cb({wagers = wagersOnly, wager = totalWager})
end)

RegisterCallback("pickle_casinos:roulette:requestSeat", function(source, cb, casinoId, entityId, seatId)
    if not CanUseCasinoEntity(source, casinoId, entityId, "roulette") then return cb(nil) end
    local seatId = JoinRouletteEntity(source, casinoId, entityId, seatId)
    local entity = GetRouletteEntity(casinoId, entityId)
    if seatId then
        return cb(seatId, {
            id = entity.id,
            seats = GetCompressedRouletteSeats(entity.seats),
            stage = entity.stage,
            betRange = entity.betRange,
            history = entity.history,
            money = GetCasinoChips(source, casinoId)
        })
    end
    cb(seatId)
end)

RegisterNetEvent("pickle_casinos:roulette:leaveTable", function()
    local source = source
    local info = GetPlayerRouletteInfo(source)
    if not info then return end
    local entity = GetCasinoEntity(info.casinoId, info.entityId)
    if not entity then return end
    if entity.stage.type == "waiting" then
        LeaveRouletteEntity(source, info.casinoId, info.entityId, info.seatId)
    else 
        entity.seats[info.seatId].inSeat = false
    end
end)

RegisterNetEvent("pickle_casinos:roulette:updateRouletteWagers", function(wagers)
    local source = source
    PerformCooldownProcess(source)
    local info = GetPlayerRouletteInfo(source)
    if not info then return end
    local entity = GetCasinoEntity(info.casinoId, info.entityId)
    if not entity then return end
    if entity.stage.type ~= "waiting" then return end
    if type(wagers) ~= "table" then return end
    local data = ApplyRouletteWagers(wagers)
    local totalWager = GetRouletteTotalWager(data)
    if totalWager <= entity.settings.maxWager then
        entity.seats[info.seatId].connects = data
    end
    TriggerClientCasinoEvent("pickle_casinos:roulette:updateSeatWager", -1, info.casinoId, info.entityId, info.seatId, GetRouletteWagersOnly(entity.seats[info.seatId].connects))
end)


AddEventHandler('playerDropped', function()
    local source = source
    local info = GetPlayerRouletteInfo(source)
    if not info then return end
    local entity = GetCasinoEntity(info.casinoId, info.entityId)
    if not entity then return end
    LeaveRouletteEntity(source, info.casinoId, info.entityId, info.seatId)
end)