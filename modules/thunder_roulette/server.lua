local LastWagers = {}
local ThunderRouletteLobbies = {}

function DoesThunderRouletteLobbyExist(casinoId, entityId)
    if not ThunderRouletteLobbies[casinoId] then return false end
    if not ThunderRouletteLobbies[casinoId][entityId] then return false end
    return ThunderRouletteLobbies[casinoId][entityId]
end

function JoinThunderRouletteEntity(source, casinoId, entityId, seatId)
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
        connects = GenerateThunderRouletteDefaultWagers(),
        inSeat = true,
    }
    CurrentPlayers[source] = {casinoId = casinoId, entityId = entityId, seatId = seatId}
    if not DoesThunderRouletteLobbyExist(casinoId, entityId) then
        StartThunderRouletteLobby(casinoId, entityId)
    end
    SetTimeout(100 * 1, function()
        TriggerClientCasinoEvent("pickle_casinos:thunder_roulette:updateSeat", -1, casinoId, entityId, seatId, GetCompressedThunderRouletteSeat(entity.seats[seatId]))
    end)
    ShowNotification(source, _L("joined_seat", seatId))
    return seatId
end

function GetCompressedThunderRouletteSeat(seat)
    if not seat then return seat end
    local copy = {}
    for k, v in pairs(seat) do
        if k ~= "connects" then copy[k] = v end
    end
    copy.wagers = GetThunderRouletteWagersOnly(seat.connects)
    return copy
end

function GetCompressedThunderRouletteSeats(seats)
    local out = {}
    for i, seat in pairs(seats) do
        out[i] = GetCompressedThunderRouletteSeat(seat)
    end
    return out
end

function LeaveThunderRouletteEntity(source, casinoId, entityId, seatId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    if entity.seats[seatId].source == source then
        entity.seats[seatId] = GenerateDefaultThunderRouletteSeat()
        SetTimeout(100 * 1, function()
            TriggerClientCasinoEvent("pickle_casinos:thunder_roulette:updateSeatWager", -1, casinoId, entityId, seatId, GetThunderRouletteWagersOnly(entity.seats[seatId].connects))
            TriggerClientCasinoEvent("pickle_casinos:thunder_roulette:updateSeat", -1, casinoId, entityId, seatId, GetCompressedThunderRouletteSeat(entity.seats[seatId]))
        end)
        CurrentPlayers[source] = nil
        ShowNotification(source, _L("left_thunder_roulette"))
    end
end

function GenerateDefaultThunderRouletteSeat()
    return {
        source = nil,
        name = nil,
        connects = GenerateThunderRouletteDefaultWagers()
    }
end

function GetThunderRouletteEntity(casinoId, entityId)
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

function ProcessThunderRouletteWager(casinoId, entityId, seat)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    local totalWager = GetThunderRouletteTotalWager(entity.seats[seat].connects)
    if totalWager == 0 then return end
    local wager = totalWager
    if GetCasinoChips(entity.seats[seat].source, casinoId) < wager or not RemoveCasinoChips(entity.seats[seat].source, casinoId, wager) then
        ShowNotification(entity.seats[seat].source, _L("insufficient_chips_bet"))
        return false
    end
    RegisterLuckyTicketWager(entity.seats[seat].source, "thunder_roulette", wager)
    return true
end

-- Pick a value from a weighted list of {value=, weight=} entries.
local function pickWeighted(list, fallback)
    if not list or #list == 0 then return fallback end
    local total = 0
    for i=1, #list do total = total + (list[i].weight or 0) end
    if total <= 0 then return list[1].value end
    local roll = math.random() * total
    local acc = 0
    for i=1, #list do
        acc = acc + (list[i].weight or 0)
        if roll <= acc then return list[i].value end
    end
    return list[#list].value
end

-- Roll thunder numbers + their multipliers for a single round.
function GenerateThunderRound()
    local cfg = Config.ThunderRoulette or {}
    local count = pickWeighted(cfg.NumberCounts, 1)
    if count < 1 then count = 1 end
    if count > #THUNDER_ROULETTE_NUMBERS then count = #THUNDER_ROULETTE_NUMBERS end
    local pool = {}
    for i=1, #THUNDER_ROULETTE_NUMBERS do pool[i] = THUNDER_ROULETTE_NUMBERS[i] end
    local thunder = {}
    for _=1, count do
        local idx = math.random(1, #pool)
        local number = pool[idx]
        table.remove(pool, idx)
        thunder[number] = pickWeighted(cfg.Multipliers, 50)
    end
    return thunder
end

function StartThunderRouletteGame(casinoId, entityId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    if entity.stage.type ~= "waiting" then return end
    entity.stage = {type = "starting"}
    local hasAcceptedWager = false
    local transactions = {}
    for i=1, #entity.seats do
        local totalWager = GetThunderRouletteTotalWager(entity.seats[i].connects)
        if not ProcessThunderRouletteWager(casinoId, entityId, i) then
            entity.seats[i].connects = GenerateThunderRouletteDefaultWagers()
            TriggerClientCasinoEvent("pickle_casinos:thunder_roulette:updateSeatWager", -1, casinoId, entityId, i, GetThunderRouletteWagersOnly(entity.seats[i].connects))
        else
            transactions[entity.seats[i].source] = StartCasinoGameplayTransaction(entity.seats[i].source, casinoId, entityId, "thunder_roulette", totalWager)
            LastWagers[entity.seats[i].source] = {connects = entity.seats[i].connects, wager = totalWager}
            hasAcceptedWager = true
        end
    end
    if not hasAcceptedWager then
        StartThunderRouletteLobby(casinoId, entityId)
        return
    end
    entity.roundPaid = false
    CreateSafeGameThread("thunder_roulette", function()
        local cfg = Config.ThunderRoulette or {}
        local spinDuration = cfg.SpinDuration or 20000
        local thunder = GenerateThunderRound()
        local winningNumber = THUNDER_ROULETTE_NUMBERS[math.random(1, #THUNDER_ROULETTE_NUMBERS)]
        entity.stage = {type = "rolling", targetNumber = winningNumber, thunder = thunder}
        TriggerClientCasinoEvent("pickle_casinos:thunder_roulette:updateStage", -1, casinoId, entityId, entity.stage)
        Wait(spinDuration)
        local seats = {}
        entity.roundPaid = true
        for i=1, #entity.seats do
            local seat = entity.seats[i]
            local connects = seat.connects
            local totalWin = 0
            local data = GetDefaultThunderRouletteConnections()
            for j=1, #data do
                local wager = connects[j].wager
                if wager > 0 and data[j].numbers then
                    local hasNumber = false
                    for k=1, #data[j].numbers do
                        if data[j].numbers[k] == winningNumber then
                            hasNumber = true
                            break
                        end
                    end
                    if hasNumber then
                        if #data[j].numbers == 1 and thunder[winningNumber] then
                            -- Thunder strike: straight bet on a thunder number gets the multiplier instead of the configured straight payout.
                            totalWin = totalWin + (wager * thunder[winningNumber])
                        elseif #data[j].numbers == 1 then
                            local payRatio = (Config.ThunderRoulette and Config.ThunderRoulette.StraightPayout) or 36
                            totalWin = totalWin + (wager * payRatio)
                        else
                            local payRatio = math.floor(36 / #data[j].numbers)
                            totalWin = totalWin + (wager * payRatio)
                        end
                    end
                end
            end
            seats[i] = { totalWin = totalWin }
            if totalWin > 0 then
                AddCasinoChips(seat.source, casinoId, totalWin)
            end
            if transactions[seat.source] then
                EndCasinoGameplayTransaction(transactions[seat.source], seat.source, casinoId, entityId, "thunder_roulette", totalWin)
            end
        end
        entity.stage = {type = "winningNumber", winningNumber = winningNumber, seats = seats, thunder = thunder}
        TriggerClientCasinoEvent("pickle_casinos:thunder_roulette:updateStage", -1, casinoId, entityId, entity.stage)
        local historyEntry = winningNumber
        if thunder[winningNumber] then
            historyEntry = { number = winningNumber, multiplier = thunder[winningNumber] }
        end
        table.insert(entity.history, 1, historyEntry)
        if #entity.history > 30 then
            table.remove(entity.history, #entity.history)
        end
        TriggerClientCasinoEvent("pickle_casinos:thunder_roulette:updateHistory", -1, casinoId, entityId, entity.history)
        Wait(5000)
        for i=1, #entity.seats do
            entity.seats[i].connects = GenerateThunderRouletteDefaultWagers()
            if entity.seats[i].source then
                UpdatePlayerBalance(entity.seats[i].source, casinoId)
            end
            SetTimeout(1000, function()
                TriggerClientCasinoEvent("pickle_casinos:thunder_roulette:updateSeatWager", -1, casinoId, entityId, i, GetThunderRouletteWagersOnly(entity.seats[i].connects))
            end)
        end
        Wait(1000)
        StartThunderRouletteLobby(casinoId, entityId)
    end, function()
        -- The round crashed: refund stakes if payouts hadn't started, then reopen the table.
        for i, seat in pairs(entity.seats) do
            if seat.source and not entity.roundPaid and IsPlayerOnline(seat.source) then
                local refund = GetThunderRouletteTotalWager(seat.connects)
                if refund > 0 then AddCasinoChips(seat.source, casinoId, refund) end
            end
            seat.connects = GenerateThunderRouletteDefaultWagers()
        end
        entity.stage = {type = "waiting", time = 0}
        StartThunderRouletteLobby(casinoId, entityId)
    end)
end

function StartThunderRouletteLobby(casinoId, entityId)
    ThunderRouletteLobbies[casinoId] = ThunderRouletteLobbies[casinoId] or {}
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    local totalPlayers = 0
    for i=1, #entity.seats do
        if entity.seats[i].source and not entity.seats[i].inSeat then
            LeaveThunderRouletteEntity(entity.seats[i].source, casinoId, entityId, i)
        elseif entity.seats[i].source then
            totalPlayers = totalPlayers + 1
        end
    end
    if totalPlayers == 0 then
        ThunderRouletteLobbies[casinoId][entityId] = false
        return
    else
        ThunderRouletteLobbies[casinoId][entityId] = true
    end
    entity.stage = {type = "waiting", time = GetWaitingTime("thunder_roulette")}
    TriggerClientCasinoEvent("pickle_casinos:thunder_roulette:updateStage", -1, casinoId, entityId, entity.stage)
    CreateThread(function()
        while entity.stage.type == "waiting" and entity.stage.time > 1 do
            entity.stage.time = entity.stage.time - 1
            Wait(1000)
        end
        local totalWagers = 0
        for i=1, #entity.seats do
            totalWagers = totalWagers + GetThunderRouletteTotalWager(entity.seats[i].connects)
        end
        if totalWagers > 0 then
            StartThunderRouletteGame(casinoId, entityId)
        else
            StartThunderRouletteLobby(casinoId, entityId)
        end
    end)
end

function GenerateThunderRouletteDefaultWagers()
    return GetDefaultThunderRouletteConnections()
end

function InitializeThunderRouletteEntity(casinoId, entity, dataOnly)
    local entity = entity or { id = "ERR_THUNDER_ROULETTE_ENTITY" }
    entity.seats = {}
    entity.history = {}
    for i=0, 4 do
        entity.seats[i] = GenerateDefaultThunderRouletteSeat()
    end
    entity.betRange = {
        math.floor(entity.settings.maxWager / 100),
        entity.settings.maxWager
    }
    return entity
end

function GetPlayerThunderRouletteInfo(source)
    if not source or source < 1 then return end
    for k,v in pairs(Casinos) do
        for i=1, #v.entities do
            local entity = v.entities[i]
            if entity.type == "thunder_roulette" then
                for j, _ in pairs(entity.seats) do
                    if entity.seats[j].source and tonumber(entity.seats[j].source) == tonumber(source) then
                        return {casinoId = k, entityId = entity.id, seatId = j}
                    end
                end
            end
        end
    end
end

RegisterCallback("pickle_casinos:repeatThunderRouletteWager", function(source, cb)
    PerformCooldownProcess(source)
    local info = GetPlayerThunderRouletteInfo(source)
    if not info then return end
    local entity = GetCasinoEntity(info.casinoId, info.entityId)
    if not entity then return end
    if entity.stage.type ~= "waiting" then return end
    if not entity.seats[info.seatId].source then return end
    local lastWager = LastWagers[source]
    local totalWager = lastWager and lastWager.wager or 0
    debugPrint("REPEAT WAGER (THUNDER)", lastWager, totalWager)
    if totalWager <= 0 or GetCasinoChips(source, info.casinoId) < totalWager then return cb({wagers = {}, wager = 0}) end
    entity.seats[info.seatId].connects = lastWager.connects
    local wagersOnly = GetThunderRouletteWagersOnly(lastWager.connects)
    TriggerClientCasinoEvent("pickle_casinos:thunder_roulette:updateSeatWager", -1, info.casinoId, info.entityId, info.seatId, wagersOnly)
    cb({wagers = wagersOnly, wager = totalWager})
end)

RegisterCallback("pickle_casinos:thunder_roulette:requestSeat", function(source, cb, casinoId, entityId, seatId)
    if not CanUseCasinoEntity(source, casinoId, entityId, "thunder_roulette") then return cb(nil) end
    local seatId = JoinThunderRouletteEntity(source, casinoId, entityId, seatId)
    local entity = GetThunderRouletteEntity(casinoId, entityId)
    if seatId then
        return cb(seatId, {
            id = entity.id,
            seats = GetCompressedThunderRouletteSeats(entity.seats),
            stage = entity.stage,
            betRange = entity.betRange,
            history = entity.history,
            money = GetCasinoChips(source, casinoId)
        })
    end
    cb(seatId)
end)

RegisterNetEvent("pickle_casinos:thunder_roulette:leaveTable", function()
    local source = source
    local info = GetPlayerThunderRouletteInfo(source)
    if not info then return end
    local entity = GetCasinoEntity(info.casinoId, info.entityId)
    if not entity then return end
    if entity.stage.type == "waiting" then
        LeaveThunderRouletteEntity(source, info.casinoId, info.entityId, info.seatId)
    else
        entity.seats[info.seatId].inSeat = false
    end
end)

RegisterNetEvent("pickle_casinos:thunder_roulette:updateThunderRouletteWagers", function(wagers)
    local source = source
    PerformCooldownProcess(source)
    local info = GetPlayerThunderRouletteInfo(source)
    if not info then return end
    local entity = GetCasinoEntity(info.casinoId, info.entityId)
    if not entity then return end
    if entity.stage.type ~= "waiting" then return end
    if type(wagers) ~= "table" then return end
    local data = ApplyThunderRouletteWagers(wagers)
    local totalWager = GetThunderRouletteTotalWager(data)
    if totalWager <= entity.settings.maxWager then
        entity.seats[info.seatId].connects = data
    end
    TriggerClientCasinoEvent("pickle_casinos:thunder_roulette:updateSeatWager", -1, info.casinoId, info.entityId, info.seatId, GetThunderRouletteWagersOnly(entity.seats[info.seatId].connects))
end)


AddEventHandler('playerDropped', function()
    local source = source
    local info = GetPlayerThunderRouletteInfo(source)
    if not info then return end
    local entity = GetCasinoEntity(info.casinoId, info.entityId)
    if not entity then return end
    LeaveThunderRouletteEntity(source, info.casinoId, info.entityId, info.seatId)
end)
