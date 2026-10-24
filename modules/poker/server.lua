local PokerLobbies = {}
local PokerTransactions = {}

function DoesPokerLobbyExist(casinoId, entityId)
    if not casinoId or not entityId then return end
    if not PokerLobbies[casinoId] then return end
    if not PokerLobbies[casinoId][entityId] then return end
    return PokerLobbies[casinoId][entityId]
end

function GenerateDefaultPokerSeat(source, casinoId, entityId)
    local casinoBalance = GetCasinoChips(source, casinoId)
    local entity = GetCasinoEntity(casinoId, entityId)
    if not source or not entity then return {source = nil, cards = {}, name = "ERR_UNKNOWN", inSeat = false, balance = 0} end
    local maxBalance = entity.settings.bigBlind * 100
    local balance = GetCasinoChips(source, casinoId)
    if balance > maxBalance then
        balance = maxBalance
    end
    return {source = source, cards = {}, blind = "none", name = GetPlayerCharacterName(source), balance = balance, inSeat = true}
end

function JoinPokerEntity(source, casinoId, entityId, seatId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    local seatId = SanitizeInt(seatId, 1, #entity.seats) or 1
    if CurrentPlayers[source] then
        for i=1, #entity.seats do
            if entity.seats[i].source == source then
                entity.seats[i].inSeat = true
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
    local newSeat = GenerateDefaultPokerSeat(source, casinoId, entityId)
    if newSeat.balance < entity.settings.bigBlind then
        ShowNotification(source, _L("insufficient_buy_in"))
        return
    end
    -- The buy-in is escrow, not a wager: lucky-ticket progress is recorded from
    -- chips actually put into pots at the end of each hand.
    if not RemoveCasinoChips(source, casinoId, newSeat.balance) then
        ShowNotification(source, _L("insufficient_buy_in"))
        return
    end
    entity.seats[seatId] = newSeat
    PokerTransactions[source] = StartCasinoGameplayTransaction(source, casinoId, entityId, "poker", entity.seats[seatId].balance)
    CurrentPlayers[source] = {casinoId = casinoId, entityId = entityId, seatId = seatId}
    if not DoesPokerLobbyExist(casinoId, entityId) then
        StartPokerLobby(casinoId, entityId)
    end
    SetTimeout(100 * 1, function()
        TriggerClientCasinoEvent("pickle_casinos:poker:updateSeat", -1, casinoId, entityId, seatId, entity.seats[seatId])
    end)
    ShowNotification(source, _L("joined_seat", seatId))
    return seatId
end

function InitializePokerEntity(casinoId, data, dataOnly)
    local entity = data or { id = "ERR_NO_ID_POKER" }
    entity.seats = {}
    entity.dealerCards = {}
    for i=1, 10 do
        entity.seats[i] = GenerateDefaultPokerSeat()
    end
    -- for i=1, 1 do
    --     if i ~= 8 then
    --         entity.seats[i].source = i + 1000
    --         entity.seats[i].name = "Bot #" .. i
    --         entity.seats[i].balance = 10000
    --         entity.seats[i].inSeat = true
    --     end
    -- end
    return entity
end

function GetPlayerPokerInfo(source)
    if not source or source < 1 then return end
    for k,v in pairs(Casinos) do
        for i=1, #v.entities do
            local entity = v.entities[i]
            if entity.type == "poker" and entity.id == Casinos[k].entities[i].id then
                for j=1, #entity.seats do
                    if entity.seats[j].source == source then
                        return {casinoId = k, entityId = entity.id, seatId = j}
                    end
                end
            end
        end
    end
end

function TriggerReclusiveClientEvent(eventName, source, ...)
    for _, playerId in ipairs(GetPlayers()) do
        if tonumber(source) ~= tonumber(playerId) then
            TriggerClientEvent(eventName, playerId, ...)
        end
    end
end

function GetObfuscuatedSeat(seat)
    local obfuscatedSeat = {}
    for k,v in pairs(seat) do
        if k == "cards" then
            obfuscatedSeat.cards = {}
            for i=1, #v do
                obfuscatedSeat.cards[i] = { class = "hidden", value = 0 }
            end
        else
            obfuscatedSeat[k] = v
        end
    end
    if obfuscatedSeat.cards then
        for i=1, #obfuscatedSeat.cards do
            if obfuscatedSeat.cards[i] then
                obfuscatedSeat.cards[i].class = "hidden"
                obfuscatedSeat.cards[i].value = 0
            end
        end
    end
    return obfuscatedSeat
end

function GetObfuscuatedSeats(seats, winners)
    local obfuscatedSeats = {}
    for i=1, #seats do
        local isWinner = false
        if winners then
            for j=1, #winners do
                if winners[j] == i then
                    isWinner = true
                    break
                end
            end
        end
        if not isWinner then
            obfuscatedSeats[i] = GetObfuscuatedSeat(seats[i])
        else
            obfuscatedSeats[i] = seats[i]
        end
    end
    return obfuscatedSeats
end

function StartPokerGame(casinoId, entityId)
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    local round = 0
    local smallBlind = entity.settings.smallBlind or 1
    local bigBlind = entity.settings.bigBlind or 2
    entity.pot = 0
    entity.dealerCards = {}
    local lastButtonIndex = 1
    local smallBlindIndex = lastButtonIndex
    local deck = GenerateDeck()
    repeat
        smallBlindIndex = smallBlindIndex - 1
        if smallBlindIndex < 1 then
            smallBlindIndex = #entity.seats
        end
    until entity.seats[smallBlindIndex].source
    local bigBlindIndex = smallBlindIndex
    repeat
        bigBlindIndex = bigBlindIndex - 1
        if bigBlindIndex < 1 then
            bigBlindIndex = #entity.seats
        end
    until entity.seats[bigBlindIndex].source and bigBlindIndex ~= smallBlindIndex
    entity.seats[smallBlindIndex].blind = "small"
    entity.seats[smallBlindIndex].balance = entity.seats[smallBlindIndex].balance - smallBlind
    entity.seats[bigBlindIndex].blind = "big"
    entity.seats[bigBlindIndex].balance = entity.seats[bigBlindIndex].balance - bigBlind
    entity.seats[smallBlindIndex].totalWager = (entity.seats[smallBlindIndex].totalWager or 0) + smallBlind
    entity.seats[bigBlindIndex].totalWager = (entity.seats[bigBlindIndex].totalWager or 0) + bigBlind
    -- debugPrint("Small Blind: " .. smallBlindIndex .. " Big Blind: " .. bigBlindIndex)
    entity.pot = smallBlind + bigBlind
    -- Determine dealer (button) seat: seat immediately to the right of the small blind
    local dealerIndex = smallBlindIndex
    repeat
        dealerIndex = dealerIndex + 1
        if dealerIndex > #entity.seats then dealerIndex = 1 end
    until entity.seats[dealerIndex].source
    TriggerClientCasinoEvent("pickle_casinos:poker:updateSeats", -1, casinoId, entityId, GetObfuscuatedSeats(entity.seats))
    TriggerClientCasinoEvent("pickle_casinos:poker:updatePot", -1, casinoId, entityId, entity.pot)
    local seatOrder = {}
    local currentSeat = bigBlindIndex
    entity.stage = {type = "dealing", time = 0, seat = bigBlindIndex, minimumBet = 0}
    repeat
        if entity.seats[currentSeat].source then
            entity.seats[currentSeat].playing = true
            seatOrder[#seatOrder + 1] = currentSeat
        end
        currentSeat = currentSeat - 1
        if currentSeat < 1 then
            currentSeat = #entity.seats
        end
    until currentSeat == bigBlindIndex
    entity.roundPaid = false
    CreateSafeGameThread("poker", function()
        repeat
            round = round + 1
            for i=1, #seatOrder do
                local seatId = seatOrder[i]
                local card, updatedDeck = GenerateCard(deck)
                deck = updatedDeck
                entity.seats[seatId].cards[round] = card
                TriggerReclusiveClientEvent("pickle_casinos:poker:updateStage", entity.seats[seatId].source, casinoId, entityId, {type = "dealing", seat = seatId, card = { class = "hidden", value = 0 }})
                TriggerClientEvent("pickle_casinos:poker:updateStage", entity.seats[seatId].source, casinoId, entityId, {type = "dealing", seat = seatId, card = card})
                SetTimeout(1200, function()
                    debugPrint(json.encode(entity.seats[seatId].cards))
                    TriggerReclusiveClientEvent("pickle_casinos:poker:updateSeat", entity.seats[seatId].source, casinoId, entityId, seatId, GetObfuscuatedSeat(entity.seats[seatId]))
                    TriggerClientEvent("pickle_casinos:poker:updateSeat", entity.seats[seatId].source, casinoId, entityId, seatId, entity.seats[seatId])
                end)
                Wait(1300)
            end
        until round >= 2
        local currentRound = {
            active = true,
            section = "preflop",
            highestBet = 0,
            seatBets = {},
            actionSeat = seatOrder[1],
        }
        repeat
            local totalSeats = 0
            local totalPlayers = 0
            currentRound.active = true
            for i=1, #seatOrder do
                local seatId = seatOrder[i]
                local seat = entity.seats[seatId]
                if not (seat.all or seat.fold) then
                    totalSeats = totalSeats + 1
                end
                if not (seat.fold) then
                    totalPlayers = totalPlayers + 1
                end
            end
            if totalSeats <= 1 then
                currentRound.active = false
            end
            if totalPlayers <= 1 then
                currentRound.active = false
                break
            else
                local dealCardSections = {
                    ["flop"] = 3,
                    ["turn"] = 1,
                    ["river"] = 1,
                }
                if dealCardSections[currentRound.section] then
                    local cardCount = dealCardSections[currentRound.section]
                    for i=1, cardCount do
                        local index = #entity.dealerCards + 1
                        local card, updatedDeck = GenerateCard(deck)
                        deck = updatedDeck
                        entity.dealerCards[index] = card
                        entity.stage = {type = "dealerDealing", index = index, card = entity.dealerCards[index]}
                        TriggerClientCasinoEvent("pickle_casinos:poker:updateStage", -1, casinoId, entityId, entity.stage)
                        SetTimeout(1400, function()
                            TriggerClientCasinoEvent("pickle_casinos:poker:updateDealerCards", -1, casinoId, entityId, entity.dealerCards)
                        end)
                        Wait(1500)
                    end
                end
            end
            if currentRound.active then
                local allSeatsPlayed = false
                local roundRepeat = false
                while currentRound.active do
                    for i=1, #seatOrder do
                        local currentSeat = seatOrder[i]
                        debugPrint("TOTAL WAGER: " .. (entity.seats[currentSeat].totalWager or 0),"SEAT ID: " .. currentSeat)
                        local skipTurn = false
                        if allSeatsPlayed and currentRound.actionSeat == currentSeat then
                            currentRound.active = false
                            skipTurn = true
                            break
                        end
                        if entity.seats[currentSeat].all or entity.seats[currentSeat].fold then
                            skipTurn = true
                        end
                        if not skipTurn then
                            local minimumBet = 0
                            if entity.seats[currentSeat].blind == "small" then
                                minimumBet = currentRound.highestBet
                            elseif entity.seats[currentSeat].blind == "big" then
                                minimumBet = currentRound.highestBet
                            else
                                minimumBet = currentRound.highestBet
                            end
                            minimumBet = minimumBet - (currentRound.seatBets[currentSeat] or 0)
                            if minimumBet < 0 then minimumBet = 0 end
                            debugPrint("Minimum Bet: " .. minimumBet, "Highest Bet: " .. currentRound.highestBet, "SEAT INFO:", currentSeat, currentRound.seatBets[currentSeat])
                            entity.seats[currentSeat].action = nil
                            TriggerClientCasinoEvent("pickle_casinos:poker:updateSeatAction", -1, casinoId, entityId, currentSeat, entity.seats[currentSeat].action)
                            entity.stage = {type = "seatTurn", time = GetSeatTurnTime("poker"), seat = currentSeat, minimumBet = minimumBet}
                            TriggerClientCasinoEvent("pickle_casinos:poker:updateStage", -1, casinoId, entityId, entity.stage)
                            for i=1, GetSeatTurnTime("poker") + 1 do 
                                if entity.seats[currentSeat].action then break end
                                Wait(1000)
                            end
                            
                            if not entity.seats[currentSeat].action then
                                entity.seats[currentSeat].action = {type = "fold", amount = 0, wagered = 0}
                            end
                            if entity.seats[currentSeat].action.type == "fold" and minimumBet <= 0 then
                                entity.seats[currentSeat].action = {type = "check", amount = 0, wagered = 0}
                            end
                            if entity.seats[currentSeat].action.type == "check" and minimumBet > 0 and (currentRound.seatBets[currentSeat] == nil or currentRound.seatBets[currentSeat] < minimumBet) then
                                entity.seats[currentSeat].action = {type = "call", amount = 0, wagered = 0}
                            end
                            if entity.seats[currentSeat].action.type == "call" then
                                local deductedAmount = minimumBet
                                if entity.seats[currentSeat].balance - deductedAmount < 0 then
                                    entity.seats[currentSeat].action = {type = "all"}
                                else
                                    entity.seats[currentSeat].totalWager = (entity.seats[currentSeat].totalWager or 0) + deductedAmount
                                    entity.seats[currentSeat].balance = entity.seats[currentSeat].balance - deductedAmount
                                    entity.seats[currentSeat].action = {type = "call", amount = minimumBet, wagered = 0}
                                    entity.pot = entity.pot + deductedAmount
                                end
                            end
                            if entity.seats[currentSeat].action.type == "raise" then
                                local amount = entity.seats[currentSeat].action.amount or 0
                                if amount < (minimumBet + smallBlind) then
                                    amount = minimumBet + smallBlind
                                end
                                local deductedAmount = amount
                                if entity.seats[currentSeat].balance - amount <= smallBlind then
                                    entity.seats[currentSeat].action = {type = "all"}
                                else
                                    currentRound.actionSeat = currentSeat
                                    currentRound.highestBet = amount
                                    entity.seats[currentSeat].totalWager = (entity.seats[currentSeat].totalWager or 0) + deductedAmount
                                    entity.seats[currentSeat].action = {type = "raise", amount = amount, wagered = 0}
                                    entity.seats[currentSeat].balance = entity.seats[currentSeat].balance - deductedAmount
                                    currentRound.seatBets[currentSeat] = amount
                                    entity.pot = entity.pot + deductedAmount
                                end
                            end
                            if entity.seats[currentSeat].action.type == "all" then
                                currentRound.actionSeat = currentSeat
                                -- Move all remaining balance to pot and correctly track total wager
                                local remainingBalance = entity.seats[currentSeat].balance
                                entity.pot = entity.pot + remainingBalance
                                entity.seats[currentSeat].all = true
                                entity.seats[currentSeat].action.amount = (entity.seats[currentSeat].totalWager or 0) + remainingBalance
                                entity.seats[currentSeat].totalWager = (entity.seats[currentSeat].totalWager or 0) + remainingBalance
                                entity.seats[currentSeat].balance = 0
                                if entity.seats[currentSeat].action.amount > currentRound.highestBet then
                                    currentRound.highestBet = entity.seats[currentSeat].action.amount
                                end
                            end
                            if entity.seats[currentSeat].action.type == "fold" then
                                entity.seats[currentSeat].fold = true
                            elseif entity.seats[currentSeat].action.type == "raise" or entity.seats[currentSeat].action.type == "all" then
                                roundRepeat = true
                            end
                            -- TriggerClientEvent("pickle_casinos:poker:updateSeat", -1, casinoId, entityId, currentSeat, GetObfuscuatedSeat(entity.seats[currentSeat]))
                            debugPrint(currentSeat, json.encode(entity.seats[currentSeat].action))
                            TriggerClientCasinoEvent("pickle_casinos:poker:updateSeatAction", -1, casinoId, entityId, currentSeat, entity.seats[currentSeat].action, entity.seats[currentSeat].balance)
                            TriggerClientCasinoEvent("pickle_casinos:poker:updatePot", -1, casinoId, entityId, entity.pot)
                        
                        end
                    end
                    allSeatsPlayed = true
                end
            end
            currentRound.highestBet = 0
            currentRound.seatBets = {}
            currentRound.actionSeat = seatOrder[1]
            if currentRound.section == "preflop" then
                currentRound.section = "flop"
            elseif currentRound.section == "flop" then
                currentRound.section = "turn"
            elseif currentRound.section == "turn" then
                currentRound.section = "river"
            else
                currentRound.section = "end"
            end
        until currentRound.section == "end"
        local formattedPlayerCards = {}
        local activePlayers = {}
        for i=1, #entity.seats do
            if entity.seats[i].source and not entity.seats[i].fold then
                formattedPlayerCards[i] = {}
                for j=1, #entity.seats[i].cards do
                    formattedPlayerCards[i][j] = { class = entity.seats[i].cards[j].class, value = entity.seats[i].cards[j].value }
                end
                table.insert(activePlayers, i)
            end
        end

        -- Prepare winnings table
        local winnings = {}
        for i=1, #entity.seats do winnings[i] = 0 end

        -- If only one active player remains, award the full pot to that player
        local winners = {}
        local results = {}
        if #activePlayers == 1 then
            local soleWinner = activePlayers[1]
            winnings[soleWinner] = winnings[soleWinner] + entity.pot
            winners = { soleWinner }
        else
            -- Build contribution map from totalWager (includes blinds/raises/calls/all-ins)
            local contributions = {}
            local contributors = {}
            for i=1, #entity.seats do
                if entity.seats[i].source then
                    local contributed = entity.seats[i].totalWager or 0
                    if contributed > 0 then
                        contributions[i] = contributed
                        table.insert(contributors, i)
                    end
                end
            end

            -- Create unique sorted contribution levels
            local uniqueLevelsMap = {}
            for _, seatId in ipairs(contributors) do
                uniqueLevelsMap[contributions[seatId]] = true
            end
            local levels = {}
            for level,_ in pairs(uniqueLevelsMap) do table.insert(levels, level) end
            table.sort(levels, function(a,b) return a < b end)

            -- Helper to determine clockwise order from left of dealer for odd-chip distribution
            local function sortWinnersForOddChip(allWinners)
                local ordered = {}
                local idx = dealerIndex
                for _=1, #entity.seats do
                    idx = idx - 1
                    if idx < 1 then idx = #entity.seats end
                    for _, w in ipairs(allWinners) do
                        if w == idx then table.insert(ordered, w) end
                    end
                    if #ordered == #allWinners then break end
                end
                return ordered
            end

            -- Compute each pot in sequence and award to eligible winners
            local prev = 0
            local winnersSet = {}
            for li=1, #levels do
                local level = levels[li]
                local numEligibleContributors = 0
                local eligibleForThisLevel = {}
                for _, seatId in ipairs(contributors) do
                    if contributions[seatId] >= level then
                        numEligibleContributors = numEligibleContributors + 1
                        table.insert(eligibleForThisLevel, seatId)
                    end
                end
                local potAmount = (level - prev) * numEligibleContributors
                if potAmount > 0 then
                    if numEligibleContributors == 1 then
                        -- Uncalled overage: refund to the sole contributor regardless of fold status
                        local onlySeat = eligibleForThisLevel[1]
                        winnings[onlySeat] = (winnings[onlySeat] or 0) + potAmount
                    else
                        -- Determine eligible non-folded players for this pot
                        local eligibleActive = {}
                        for _, seatId in ipairs(eligibleForThisLevel) do
                            if not entity.seats[seatId].fold then
                                eligibleActive[seatId] = true
                            end
                        end
                        -- Collect cards only for eligible active players
                        local potPlayersCards = {}
                        for seatId,_ in pairs(eligibleActive) do
                            potPlayersCards[seatId] = formattedPlayerCards[seatId]
                        end
                        local potWinners = {}
                        if next(potPlayersCards) ~= nil then
                            local potWinnersList, potResults = GetPokerWinners(potPlayersCards, entity.dealerCards)
                            -- Copy to array
                            for _, w in ipairs(potWinnersList) do table.insert(potWinners, w); winnersSet[w] = true end
                            results = potResults -- last assignment is fine; client only needs overall for debugging
                        end
                        if #potWinners > 0 then
                            local base = math.floor(potAmount / #potWinners)
                            local remainder = potAmount - (base * #potWinners)
                            for _, w in ipairs(potWinners) do
                                winnings[w] = (winnings[w] or 0) + base
                            end
                            if remainder > 0 then
                                local ordered = sortWinnersForOddChip(potWinners)
                                local ri = 1
                                while remainder > 0 do
                                    local w = ordered[ri]
                                    winnings[w] = (winnings[w] or 0) + 1
                                    remainder = remainder - 1
                                    ri = ri + 1
                                    if ri > #ordered then ri = 1 end
                                end
                            end
                        end
                    end
                end
                prev = level
            end

            -- Build winners list for display
            for seatId,_ in pairs(winnersSet) do table.insert(winners, seatId) end
        end

        -- Apply winnings to seat balances
        entity.roundPaid = true
        for i=1, #entity.seats do
            if winnings[i] and winnings[i] > 0 then
                entity.seats[i].balance = entity.seats[i].balance + winnings[i]
            end
        end

        debugPrint("Round Ended", json.encode(winners), json.encode(results))
        -- Everyone sees the winners' hands; each seated player additionally sees
        -- their own. Other (e.g. folded) hands stay hidden.
        entity.stage = {type = "results", winnings = winnings, seats = GetObfuscuatedSeats(entity.seats, winners)}
        TriggerClientCasinoEvent("pickle_casinos:poker:updateStage", -1, casinoId, entityId, entity.stage)
        for i=1, #entity.seats do
            if entity.seats[i].source then
                local seats = GetObfuscuatedSeats(entity.seats, winners)
                seats[i].cards = entity.seats[i].cards
                TriggerClientCasinoEvent("pickle_casinos:poker:updateStage", entity.seats[i].source, casinoId, entityId, {type = "results", winnings = winnings, seats = seats})
            end
        end

        -- Reset the pot
        entity.pot = 0
        -- Reset seat data
        for i=1, #entity.seats do
            local seat = entity.seats[i]
            if seat.source and (seat.totalWager or 0) > 0 then
                RegisterLuckyTicketWager(seat.source, "poker", seat.totalWager)
            end
            seat.action = nil
            seat.fold = nil
            seat.all = nil
            seat.playing = nil
            seat.blind = "none"
            seat.totalWager = 0
            seat.cards = {}
            if seat.source and IsPlayerOnline(seat.source) and seat.balance < (entity.settings.bigBlind * 100) then
                local replenishAmount = (entity.settings.bigBlind * 100) - seat.balance
                local casinoBalance = GetCasinoChips(seat.source, casinoId)
                local topUp = math.min(replenishAmount, casinoBalance)
                if topUp > 0 and RemoveCasinoChips(seat.source, casinoId, topUp) then
                    seat.balance = seat.balance + topUp
                end
            end
        end
        entity.dealerCards = {}
        Wait(5000)
        TriggerClientCasinoEvent("pickle_casinos:poker:updateSeats", -1, casinoId, entityId, GetObfuscuatedSeats(entity.seats))
        TriggerClientCasinoEvent("pickle_casinos:poker:updateDealerCards", -1, casinoId, entityId, entity.dealerCards)
        TriggerClientCasinoEvent("pickle_casinos:poker:updatePot", -1, casinoId, entityId, entity.pot)
        -- Start a new poker lobby
        StartPokerLobby(casinoId, entityId)
    end, function()
        -- The hand crashed: if the pot wasn't paid out, give each seat back what it put in.
        for i=1, #entity.seats do
            local seat = entity.seats[i]
            if seat.source and not entity.roundPaid then
                seat.balance = (seat.balance or 0) + (seat.totalWager or 0)
            end
            seat.action = nil
            seat.fold = nil
            seat.all = nil
            seat.playing = nil
            seat.blind = "none"
            seat.totalWager = 0
            seat.cards = {}
        end
        entity.pot = 0
        entity.dealerCards = {}
        TriggerClientCasinoEvent("pickle_casinos:poker:updateSeats", -1, casinoId, entityId, GetObfuscuatedSeats(entity.seats))
        StartPokerLobby(casinoId, entityId)
    end)
end

function LeavePokerEntity(source, casinoId, entityId, seatId)
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    local source = entity.seats[seatId].source
    if entity.seats[seatId].balance > 0 then
        AddCasinoChips(source, casinoId, entity.seats[seatId].balance)
    end
    if PokerTransactions[source] then
        EndCasinoGameplayTransaction(PokerTransactions[source], source, casinoId, entityId, "poker", entity.seats[seatId].balance)
        PokerTransactions[source] = nil
    end
    entity.seats[seatId] = GenerateDefaultPokerSeat()
    CurrentPlayers[source] = nil
    TriggerClientCasinoEvent("pickle_casinos:poker:updateSeat", -1, casinoId, entityId, seatId, entity.seats[seatId])
end

function StartPokerLobby(casinoId, entityId)
    PokerLobbies[casinoId] = PokerLobbies[casinoId] or {}
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    local totalPlayers = 0
    for i=1, #entity.seats do
        if entity.seats[i].source then
            if entity.seats[i].inSeat and entity.seats[i].balance >= entity.settings.bigBlind then
                totalPlayers = totalPlayers + 1
            else
                if entity.seats[i].balance < entity.settings.bigBlind then
                    TriggerClientEvent("pickle_casinos:exitGame", entity.seats[i].source, true)
                end
                LeavePokerEntity(entity.seats[i].source, casinoId, entityId, i)
            end
        end
    end
    if totalPlayers <= 0 then
        PokerLobbies[casinoId] = PokerLobbies[casinoId] or {}
        PokerLobbies[casinoId][entityId] = false
        return
    else
        PokerLobbies[casinoId][entityId] = true
    end
    entity.stage = {type = "waiting", time = GetWaitingTime("poker")}
    TriggerClientCasinoEvent("pickle_casinos:poker:updateStage", -1, casinoId, entityId, entity.stage)
    CreateThread(function()
        while entity.stage.type == "waiting" and entity.stage.time > 1 do
            entity.stage.time = entity.stage.time - 1
            Wait(1000)
        end
        local totalPlayers = 0
        for i=1, #entity.seats do
            if entity.seats[i].source and entity.seats[i].inSeat then
                totalPlayers = totalPlayers + 1
            end
        end
        if totalPlayers < 2 then
            StartPokerLobby(casinoId, entityId)
        else
            StartPokerGame(casinoId, entityId)
        end
    end)
end

RegisterNetEvent("pickle_casinos:poker:sendPokerAction", function(betType, value)
    local playerInfo = GetPlayerPokerInfo(source)
    if not playerInfo then return end
    local casinoId = playerInfo.casinoId
    local entityId = playerInfo.entityId
    local seatId = playerInfo.seatId
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    if not entity.seats[seatId] then return end
    if not entity.seats[seatId].playing then return end
    if entity.stage.type ~= "seatTurn" or entity.stage.seat ~= seatId then return end
    -- Amounts feed straight into pot/balance arithmetic: whole chips only.
    if betType == "raise" then
        value = SanitizeInt(value, 1, entity.seats[seatId].balance)
        if not value then return end
    else
        value = 0
    end
    if betType == "call" then
        entity.seats[seatId].action = {type = "call", amount = value, wagered = 0}
    elseif betType == "raise" then
        entity.seats[seatId].action = {type = "raise", amount = value, wagered = 0}
    elseif betType == "fold" then
        entity.seats[seatId].action = {type = "fold", amount = 0, wagered = 0}
    elseif betType == "check" then
        entity.seats[seatId].action = {type = "check", amount = 0, wagered = 0}
    elseif betType == "all" then
        entity.seats[seatId].action = {type = "all", amount = value, wagered = 0}
    end
end)

RegisterNetEvent("pickle_casinos:poker:leaveTable", function()
    local source = source
    local playerInfo = GetPlayerPokerInfo(source)
    if not playerInfo then return end
    local casinoId = playerInfo.casinoId
    local entityId = playerInfo.entityId
    local seatId = playerInfo.seatId
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    if entity.stage.type == "waiting" then
        LeavePokerEntity(source, casinoId, entityId, seatId)
    else
        entity.seats[seatId].inSeat = false
    end
end)

AddEventHandler('playerDropped', function()
    local source = source
    local playerInfo = GetPlayerPokerInfo(source)
    if not playerInfo then return end
    local casinoId = playerInfo.casinoId
    local entityId = playerInfo.entityId
    local seatId = playerInfo.seatId
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    LeavePokerEntity(source, casinoId, entityId, seatId)
end)

RegisterCallback("pickle_casinos:poker:requestSeat", function(source, cb, casinoId, entityId, seatId)
    PerformCooldownProcess(source)
    if not CanUseCasinoEntity(source, casinoId, entityId, "poker") then return cb(nil) end
    local seatId = JoinPokerEntity(source, casinoId, entityId, seatId)
    local entity = GetCasinoEntity(casinoId, entityId)
    if seatId then
        return cb(seatId, {
            id = entity.id,
            seats = GetObfuscuatedSeats(entity.seats),
            stage = entity.stage,
            money = entity.seats[seatId].balance,
        })
    end
    cb(seatId)
end)