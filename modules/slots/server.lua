local PendingSpins = {}

function InitializeSlotEntity(casinoId, data)
    local entity = data or { id = "ERR_NO_ID_SLOT" }
    entity.currentPlayer = nil
    local betMax = entity.settings.maxWager
    local betMin = math.floor(entity.settings.maxWager / 100)
    local bets = {}
    local betLength = 10
    for i=1, (betLength + 1) do
        bets[i] = math.floor(lerp(betMin, betMax, (i - 1) / betLength))
    end
    entity.bets = bets
    return entity
end

function GetPlayerSlotInfo(source)
    if not source or source < 1 then return end
    for k,v in pairs(Casinos) do
        for i=1, #v.entities do
            local entity = v.entities[i]
            if entity.type == "slot" and entity.currentPlayer and entity.currentPlayer.source == source then
                return {casinoId = k, entityId = entity.id, seatId = 1}
            end
        end
    end
end

function GenerateSpin(game, forceBonus, removeBonus)
    local reelResults = {}
    local totalBonuses = 0
    local slotStructure = game
    for i=1, slotStructure.reelCount do
        local reelResult = {}
        local hasAddedBonus = false;
        for j=1, slotStructure.reelSymbols do
            local symbols = {}
            for slotSymbol, data in pairs(slotStructure.slotSymbols) do
                for k=1, data.reels[i] do
                    if not (removeBonus and slotSymbol == slotStructure.bonusSymbol) then
                        symbols[#symbols + 1] = slotSymbol
                    end
                end
            end
            local symbolIndex = math.random(1, #symbols)
            local symbol = symbols[symbolIndex]
            if (symbol == slotStructure.bonusSymbol) then
                if (hasAddedBonus) then
                    repeat
                        symbolIndex = math.random(1, #symbols)
                        symbol = symbols[symbolIndex]
                    until symbol ~= slotStructure.bonusSymbol
                else             
                    totalBonuses = totalBonuses + 1
                    hasAddedBonus = true
                end
            end
            reelResult[#reelResult + 1] = symbol
        end
        if (forceBonus) then
            reelResult[1] = slotStructure.bonusSymbol
        end
        reelResults[#reelResults + 1] = reelResult
    end
    local additionalSpins = {}
    if (forceBonus or totalBonuses >= slotStructure.bonusTriggerCount) then
        for i=1, slotStructure.bonusFreeSpins do
            additionalSpins[#additionalSpins + 1] = GenerateSpin(game, nil, true).spins[1]
        end
    end
    local finalSpins = {}
    finalSpins[#finalSpins + 1] = reelResults
    for i=1, #additionalSpins do
        finalSpins[#finalSpins + 1] = additionalSpins[i]
    end
    return {
        spinIndex = 0,
        spins = finalSpins
    }
end


function GetPaylineResults(spin, game)
    local paylineResults = {}
    local hasWin = false
    local slotStructure = game
    for i=1, #slotStructure.paylines do
        local payline = slotStructure.paylines[i]
        if (spin) then
            local firstSymbol = spin[1][payline[1] + 1]
            local count = 1
            for j=2, #payline do
                local spinColumn = spin[j]
                if (spinColumn) then
                    local symbol = spinColumn[payline[j] + 1]
                    if (symbol == firstSymbol) then
                        count = count + 1
                    else
                        break
                    end
                end
            end
            if (count >= slotStructure.paylineWinThreshold) then
                hasWin = true
                paylineResults[#paylineResults + 1] = {
                    symbol = firstSymbol,
                    count = count,
                }
            else 
                paylineResults[#paylineResults + 1] = {
                    symbol = nil,
                    count = 0,
                }
            end
        else
            paylineResults[#paylineResults + 1] = {
                symbol = nil,
                count = 0,
            }
        end
    end
    return paylineResults -- Return the array of results
end

function GenerateSpinId()
    local id = math.random(1, 999999999)
    while PendingSpins[id] do
        id = math.random(1, 999999999)
    end
    return id
end

function GetSpinCalculatedWin(gameId, spin, bet)
    local slotStructure = Config.Slots[gameId]
    if not slotStructure then return end
    local paylineResults = GetPaylineResults(spin, slotStructure)
    local calculatedWin = 0
    for i=1, #paylineResults do
        local paylineResult = paylineResults[i]
        if (paylineResult.symbol and paylineResult.count >= slotStructure.paylineWinThreshold) then
            local winningSymbol = paylineResult.symbol
            calculatedWin = calculatedWin + slotStructure.slotSymbols[winningSymbol].pay[paylineResult.count] * bet
        end
    end
    return math.floor(calculatedWin)
end

RegisterNetEvent("pickle_casinos:slots:redeemSpin", function(id, spinIndex)
    local source = source
    local slotSpin = PendingSpins[id]
    if not slotSpin or slotSpin.source ~= source then return end
    local spin = slotSpin.spins[spinIndex]
    if not spin or spin.redeemed then return end
    debugPrint("Redeeming spin", id, spinIndex, slotSpin.bet)
    spin.redeemed = true
    local calculatedWin = GetSpinCalculatedWin(slotSpin.gameId, spin, slotSpin.bet) or 0
    local playerMoney = GetCasinoChips(source, slotSpin.casinoId)
    if calculatedWin > 0 then
        playerMoney = playerMoney + calculatedWin
        AddCasinoChips(source, slotSpin.casinoId, calculatedWin)
        ShowNotification(source, _L("spin_won", GetCurrencyString(calculatedWin)))
    end
    slotSpin.totalWin = (slotSpin.totalWin or 0) + calculatedWin
    slotSpin.redeemedCount = (slotSpin.redeemedCount or 0) + 1
    TriggerClientEvent("pickle_casinos:updateBalance", source, playerMoney)
    -- Log the round once, with the bet against the total of every redeemed spin.
    if slotSpin.redeemedCount >= #slotSpin.spins then
        EndCasinoGameplayTransaction(slotSpin.transaction, source, slotSpin.casinoId, slotSpin.entityId, "slots", slotSpin.totalWin)
        PendingSpins[id] = nil
    end
end)

RegisterNetEvent("pickle_casinos:slots:leaveSlotMachine", function()
    local playerInfo = GetPlayerSlotInfo(source)
    if not playerInfo then return end
    local casinoId = playerInfo.casinoId
    local entityId = playerInfo.entityId
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    entity.currentPlayer = nil
end)

RegisterCallback("pickle_casinos:slots:requestSeat", function(source, cb, casinoId, entityId)
    local canUse, casino, entity = CanUseCasinoEntity(source, casinoId, entityId, "slot")
    if not canUse then return cb(nil) end
    -- One machine per player.
    local current = GetPlayerSlotInfo(source)
    if current and (current.casinoId ~= casinoId or current.entityId ~= entityId) then
        cb(nil)
        return
    end
    if entity.currentPlayer then
        cb(nil)
        return
    end
    entity.currentPlayer = {
        source = source,
        seatId = 1,
        money = GetCasinoChips(source, casinoId),
        game = entity.settings.game,
        bets = entity.bets,
    }
    debugPrint("Player", source, "has taken a seat at slot machine", entityId)
    cb(1, entity.currentPlayer)
end)

RegisterCallback("pickle_casinos:slots:spinSlot", function(source, cb, betIndex)
    local playerInfo = GetPlayerSlotInfo(source)
    if not playerInfo then return cb(nil) end
    local casinoId = playerInfo.casinoId
    local entityId = playerInfo.entityId
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return cb(nil) end
    betIndex = betIndex or 1
    local bet = entity.bets[betIndex]
    if not bet then bet = entity.bets[1] end
    if not Config.Slots[entity.settings.game] then return cb(nil) end
    local playerMoney = GetCasinoChips(source, casinoId)
    if playerMoney < bet or not RemoveCasinoChips(source, casinoId, bet) then
        ShowNotification(source, _L("not_enough_money_spin"))
        return cb(nil)
    end
    playerMoney = playerMoney - bet
    RegisterLuckyTicketWager(source, "slots", bet)
    local spinId = GenerateSpinId()
    local spin = GenerateSpin(Config.Slots[entity.settings.game])

    spin.casinoId = casinoId
    spin.entityId = entityId
    spin.gameId = entity.settings.game
    spin.id = spinId
    spin.source = source
    spin.bet = bet
    spin.transaction = StartCasinoGameplayTransaction(source, casinoId, entityId, "slots", bet)
    PendingSpins[spinId] = spin
    cb(spin, playerMoney)
end)


AddEventHandler('playerDropped', function()
    local source = source
    -- Unredeemed spins can't be paid to a disconnected player; don't keep them forever.
    for id, spin in pairs(PendingSpins) do
        if spin.source == source then
            PendingSpins[id] = nil
        end
    end
    local playerInfo = GetPlayerSlotInfo(source)
    if not playerInfo then return end
    local casinoId = playerInfo.casinoId
    local entityId = playerInfo.entityId
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    entity.currentPlayer = nil
end)

-- RegisterCommand("slotrtp", function(source, args, rawCommand)
--     if source and source > 0 then return end
--     local slotId = args[1]
--     if not slotId or not Config.Slots[slotId] then
--         debugPrint("Please provide a slot ID.")
--         return
--     end
--     CreateThread(function()
--         local v = Config.Slots[slotId]
--         local gameId = k
--         local game = v
--         local totalWin = 0
--         local betSize = 1
--         local betAmount = 50000
--         local bonuses = 0
--         for i=1, betAmount do
--             local spin = GenerateSpin(game, false)
--             local win = 0
--             for j=1, #spin.spins do
--                 local spinResult = spin.spins[j]
--                 local calculatedWin = GetSpinCalculatedWin(gameId, spinResult, betSize)
--                 if calculatedWin > 0 then
--                     win = win + calculatedWin
--                 end
--             end
--             if #spin.spins > 1 then
--                 bonuses = bonuses + 1
--             end
--             totalWin = totalWin + win
--         end
--         local rtp = (totalWin / (betAmount * betSize)) * 100
--         debugPrint(string.format("Game: %s, RTP: %.2f%%, Bonus: %.2f%%", gameId, rtp, (bonuses / betAmount) * 100))
--     end)
-- end, false)
