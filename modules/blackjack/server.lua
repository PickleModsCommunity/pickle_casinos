local BlackjackLobbies = {}
local LastWagers = {}

local CardClasses = {"spd", "club", "dia", "hrt"}
local CardValues = {"ace", "02", "03", "04", "05", "06", "07", "08", "09", "10", "jack", "queen", "king"}
local TenValues = {"10", "jack", "queen", "king"}

function RollBlackjackOdds(key)
    local odds = Config.BlackjackOdds
    if not odds then return false end
    local chance = tonumber(odds[key])
    if not chance or chance <= 0 then return false end
    return math.random(100) <= chance
end

function GenerateBlackjackCard(value)
    return { class = CardClasses[math.random(1, #CardClasses)], value = value }
end

-- Returns the two cards making up a natural blackjack, in a random order so the
-- ace isn't always the hole card.
function GenerateDealerBlackjackHand()
    local ace = GenerateBlackjackCard("ace")
    local ten = GenerateBlackjackCard(TenValues[math.random(1, #TenValues)])
    if math.random(2) == 1 then
        return ace, ten
    end
    return ten, ace
end

-- Returns a card that brings `cards` to exactly 21, or nil if no such card exists.
function GenerateDealerTwentyOneCard(cards)
    local candidates = {}
    for i=1, #CardValues do
        local card = GenerateBlackjackCard(CardValues[i])
        local hand = {}
        for j=1, #cards do
            hand[j] = cards[j]
        end
        hand[#hand + 1] = card
        local value, secondaryValue = GetValueOfCards(hand)
        if value == 21 or secondaryValue == 21 then
            candidates[#candidates + 1] = card
        end
    end
    if #candidates < 1 then return end
    return candidates[math.random(1, #candidates)]
end

function DoesBlackjackLobbyExist(casinoId, entityId)
    if not BlackjackLobbies[casinoId] then return false end
    if not BlackjackLobbies[casinoId][entityId] then return false end
    return BlackjackLobbies[casinoId][entityId]
end

function JoinBlackjackEntity(source, casinoId, entityId, seatId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    -- Seat 0 is the dealer; only player seats 1..4 are valid.
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
        if not seatId or seatId < 1 then
            ShowNotification(source, _L("no_seats_available"))
            return 
        end
    end
    CurrentPlayers[source] = {casinoId = casinoId, entityId = entityId, seatId = seatId}
    entity.seats[seatId] = {source = source, name = GetPlayerCharacterName(source), wagers = {0, 0}, hands = {{}, {}}, inSeat = true}
    if not DoesBlackjackLobbyExist(casinoId, entityId) then
        StartBlackjackLobby(casinoId, entityId)
    end
    SetTimeout(100 * 1, function()
        TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeat", -1, casinoId, entityId, seatId, entity.seats[seatId])
    end)
    ShowNotification(source, _L("joined_seat", seatId))
    return seatId
end

function LeaveBlackjackEntity(source, casinoId, entityId, seatId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    if entity.seats[seatId].source == source then
        entity.seats[seatId] = GenerateDefaultBlackjackSeat()
        SetTimeout(100 * 1, function()
            TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeat", -1, casinoId, entityId, seatId, entity.seats[seatId])
        end)
        CurrentPlayers[source] = nil
        ShowNotification(source, _L("left_blackjack"))
    end
end

function GetBlackjackEntity(casinoId, entityId)
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

function IsSplittable(cards)
    if #cards ~= 2 then return false end
    return GetValueOfCards({cards[1]}) == GetValueOfCards({cards[2]})
end

function StartBlackjackTurn(casinoId, entityId, seat, handId, splitAllowed)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    local done = false
    local hasHit = false
    repeat
        entity.stage = {type = "turn", seat = seat, hasHit = hasHit, action = nil, handId = handId, hands = entity.seats[seat].hands}
        TriggerClientCasinoEvent("pickle_casinos:blackjack:updateStage", -1, casinoId, entityId, entity.stage)
        local timeLeft = GetSeatTurnTime("blackjack")
        repeat
            local entity2 = GetCasinoEntity(casinoId, entityId)
            timeLeft = timeLeft - 1
            Wait(1000)
        until timeLeft == 0 or entity.stage.action ~= nil
        local action = entity.stage.action or "stand"
        if action == "double" and #entity.seats[seat].hands[handId] == 2 then
            local balance = GetCasinoChips(entity.seats[seat].source, casinoId)
            if balance < entity.seats[seat].wagers[handId] or not RemoveCasinoChips(entity.seats[seat].source, casinoId, entity.seats[seat].wagers[handId]) then
                action = "hit"
            else
                RegisterLuckyTicketWager(entity.seats[seat].source, "blackjack", entity.seats[seat].wagers[handId])
                entity.seats[seat].wagers[handId] = entity.seats[seat].wagers[handId] * 2
                TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeatWager", -1, casinoId, entityId, seat, handId, entity.seats[seat].wagers[handId])
                entity.stage = {type = "dealing", seat = seat, handId = handId, isDouble = true, card = GenerateCard() }
                entity.seats[seat].hands[handId][#entity.seats[seat].hands[handId] + 1] = entity.stage.card
                TriggerClientCasinoEvent("pickle_casinos:blackjack:updateStage", -1, casinoId, entityId, entity.stage)
                SetTimeout(1300, function()
                    TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeatCards", -1, casinoId, entityId, seat, handId, entity.seats[seat].hands[handId], {isDouble = true})
                end)
                Wait(2000)
            end
            done = true
        end
        if action == "hit" then
            entity.stage = {type = "dealing", seat = seat, isHit = true, handId = entity.stage.handId, card = GenerateCard()}
            entity.seats[seat].hands[entity.stage.handId][#entity.seats[seat].hands[entity.stage.handId] + 1] = entity.stage.card
            hasHit = true
            local value = GetValueOfCards(entity.seats[seat].hands[entity.stage.handId])
            TriggerClientCasinoEvent("pickle_casinos:blackjack:updateStage", -1, casinoId, entityId, entity.stage)
            SetTimeout(1300, function()
                TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeatCards", -1, casinoId, entityId, seat, entity.stage.handId, entity.seats[seat].hands[entity.stage.handId])
            end)
            Wait(2000)
            if value >= 21 then
                done = true
            end
        elseif action == "split" and IsSplittable(entity.seats[seat].hands[1]) and splitAllowed then
            local balance = GetCasinoChips(entity.seats[seat].source, casinoId)
            if balance < entity.seats[seat].wagers[1] or not RemoveCasinoChips(entity.seats[seat].source, casinoId, entity.seats[seat].wagers[1]) then
                ShowNotification(entity.seats[seat].source, _L("insufficient_chips"))
            else
                RegisterLuckyTicketWager(entity.seats[seat].source, "blackjack", entity.seats[seat].wagers[1])
                entity.seats[seat].hands = {
                    [1] = {entity.seats[seat].hands[entity.stage.handId][1]},
                    [2] = {entity.seats[seat].hands[entity.stage.handId][2]}
                }
                entity.seats[seat].wagers[2] = entity.seats[seat].wagers[1]
                TriggerClientCasinoEvent("pickle_casinos:blackjack:performAction", -1, casinoId, entityId, {
                    type = "split",
                    seat = seat,
                    hands = entity.seats[seat].hands
                })
                Wait(1300)
                entity.stage = {type = "dealing", seat = seat, handId = 2, card = GenerateCard() }
                entity.seats[seat].hands[2][#entity.seats[seat].hands[2] + 1] = entity.stage.card
                TriggerClientCasinoEvent("pickle_casinos:blackjack:updateStage", -1, casinoId, entityId, entity.stage)
                SetTimeout(1300, function()
                    TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeatCards", -1, casinoId, entityId, seat, 2, entity.seats[seat].hands[2])
                end)
                Wait(2000)
                StartBlackjackTurn(casinoId, entityId, seat, 2, false)
            end
            done = true
        else
            done = true
        end
    until done
    if handId == 2 then
        entity.stage = {type = "dealing", seat = seat, handId = 1, card = GenerateCard() }
        entity.seats[seat].hands[1][#entity.seats[seat].hands[1] + 1] = entity.stage.card
        TriggerClientCasinoEvent("pickle_casinos:blackjack:updateStage", -1, casinoId, entityId, entity.stage)
        SetTimeout(1300, function()
            TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeatCards", -1, casinoId, entityId, seat, 1, entity.seats[seat].hands[1])
        end)
        Wait(2000)
        StartBlackjackTurn(casinoId, entityId, seat, 1, false)
    end
end

function ProcessBlackjackWager(casinoId, entityId, seat, handId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    local wager = entity.seats[seat].wagers[handId]
    if type(wager) ~= "number" or wager <= 0 then return false end
    if wager > GetCasinoChips(entity.seats[seat].source, casinoId) or not RemoveCasinoChips(entity.seats[seat].source, casinoId, wager) then
        ShowNotification(entity.seats[seat].source, _L("insufficient_chips"))
        return false
    end
    RegisterLuckyTicketWager(entity.seats[seat].source, "blackjack", wager)
    return true
end

function StartBlackjackGame(casinoId, entityId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    if entity.stage.type ~= "waiting" then return end
    entity.stage = {type = "starting"}
    local transactions = {}
    local hiddenCard = GenerateCard()
    local dealerUpCard = nil
    if RollBlackjackOdds("BlackjackPossibility") then
        hiddenCard, dealerUpCard = GenerateDealerBlackjackHand()
    end
    entity.seats[0] = {source = 0, hands = {{}, {}}}
    entity.roundPaid = false
    for i=1, 4 do
        if entity.seats[i].source then
            if not ProcessBlackjackWager(casinoId, entityId, i, 1) then
                entity.seats[i].wagers = {0, 0}
                entity.seats[i].hands = {{}, {}}
                TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeat", -1, casinoId, entityId, i, entity.seats[i])
            else
                transactions[entity.seats[i].source] = StartCasinoGameplayTransaction(entity.seats[i].source, casinoId, entityId, "blackjack", entity.seats[i].wagers[1])
                LastWagers[entity.seats[i].source] = entity.seats[i].wagers
            end
        end
    end
    CreateSafeGameThread("blackjack", function()
        local round = 0
        local isFirstCard = true
        repeat
            round = round + 1
            for k=1, 4 do
                if entity.seats[k].source and entity.seats[k].wagers[1] > 0 then
                    entity.stage = {type = "dealing", seat = k, card = GenerateCard(), isFirstCard = isFirstCard}
                    entity.seats[k].hands[1][#entity.seats[k].hands[1] + 1] = entity.stage.card
                    TriggerClientCasinoEvent("pickle_casinos:blackjack:updateStage", -1, casinoId, entityId, entity.stage)
                    if isFirstCard then
                        Wait(3000)
                    end
                    isFirstCard = false
                    SetTimeout(1300, function()
                        TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeatCards", -1, casinoId, entityId, k, 1, entity.seats[k].hands[1])
                    end)
                    Wait(2000)
                end
            end
            entity.stage = {type = "dealing", seat = 0, card = round == 1 and { class = "hidden", value = 0 } or (dealerUpCard or GenerateCard())}
            entity.seats[0].hands[1][#entity.seats[0].hands[1] + 1] = entity.stage.card
            TriggerClientCasinoEvent("pickle_casinos:blackjack:updateStage", -1, casinoId, entityId, entity.stage)
            SetTimeout(1300, function()
                TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeatCards", -1, casinoId, entityId, 0, 1, entity.seats[0].hands[1])
            end)
            Wait(2000)
        until round == 2
        local seat = 0
        repeat
            seat = seat + 1
            if entity.seats[seat].source and entity.seats[seat].wagers[1] > 0 then
                local value, secondaryValue = GetValueOfCards(entity.seats[seat].hands[1])
                if value < 21 and secondaryValue < 21 then
                    StartBlackjackTurn(casinoId, entityId, seat, 1, true)
                end
            end
        until seat >= 4
        entity.stage = {type = "displayCard", seat = 0, card = hiddenCard}
        entity.seats[0].hands[1][1] = entity.stage.card
        TriggerClientCasinoEvent("pickle_casinos:blackjack:updateStage", -1, casinoId, entityId, entity.stage)
        SetTimeout(1300, function()
            TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeatCards", -1, casinoId, entityId, 0, 1, entity.seats[0].hands[1])
        end)
        Wait(2000)
        local inPlay = false
        for i=1, 4 do
            if entity.seats[i].source and entity.seats[i].wagers[1] > 0 then
                local value, secondaryValue = GetValueOfCards(entity.seats[i].hands[1])
                if value < 21 and secondaryValue < 21 then
                    inPlay = true
                end
            end
        end
        local dealerValue, dealerSecondaryValue = GetValueOfCards(entity.seats[0].hands[1])
        if inPlay and dealerValue < 17 and dealerSecondaryValue < 17 then
            local done = false
            repeat
                local drawnCard = nil
                if RollBlackjackOdds("DrawBlackjackPossibility") then
                    drawnCard = GenerateDealerTwentyOneCard(entity.seats[0].hands[1])
                end
                entity.stage = {type = "dealing", seat = 0, card = drawnCard or GenerateCard()}
                entity.seats[0].hands[1][#entity.seats[0].hands[1] + 1] = entity.stage.card
                TriggerClientCasinoEvent("pickle_casinos:blackjack:updateStage", -1, casinoId, entityId, entity.stage)
                SetTimeout(1300, function()
                    TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeatCards", -1, casinoId, entityId, 0, 1, entity.seats[0].hands[1])
                end)
                Wait(2000)
                dealerValue, dealerSecondaryValue = GetValueOfCards(entity.seats[0].hands[1])
                if dealerValue >= 17 or dealerSecondaryValue >= 17 then
                    done = true
                end
            until done 
        end
        local dealerValue, dealerSecondaryValue = GetValueOfCards(entity.seats[0].hands[1])
        if dealerSecondaryValue > 0 then
            dealerValue = dealerSecondaryValue
        end
        local seatResults = {}
        for i=1, 4 do 
            seatResults[i] = {won = 0, money = 0}
            if entity.seats[i].source and entity.seats[i].wagers[1] > 0 then
                for j=1, 2 do
                    local wager = entity.seats[i].wagers[j]
                    local hand = entity.seats[i].hands[j]
                    local value, secondaryValue = GetValueOfCards(hand)
                    if secondaryValue > 0 then
                        value = secondaryValue
                    end
                    if wager > 0 and value <= 21 then
                        if value == dealerValue then
                            seatResults[i].won = seatResults[i].won + wager
                        elseif (dealerValue > 21 or (value > dealerValue)) then
                            local multiplier = 2
                            if j == 1 and (not entity.seats[i].hands[2] or #entity.seats[i].hands[2] == 0) and #hand == 2 and value == 21 then
                                multiplier = 2.5
                            end
                            seatResults[i].won = seatResults[i].won + (wager * multiplier)
                        end
                    end
                end
            end
        end
        entity.roundPaid = true
        for i=1, 4 do
            if entity.seats[i].source  then
                seatResults[i].money = GetCasinoChips(entity.seats[i].source, casinoId) + seatResults[i].won
                if entity.seats[i].wagers[1] > 0 and seatResults[i].won > 0 then
                    AddCasinoChips(entity.seats[i].source, casinoId, seatResults[i].won)
                end
                if transactions[entity.seats[i].source] then
                    EndCasinoGameplayTransaction(transactions[entity.seats[i].source], entity.seats[i].source, casinoId, entityId, "blackjack", seatResults[i].won)
                end
            end
        end
        TriggerClientCasinoEvent("pickle_casinos:blackjack:updateResults", -1, casinoId, entityId, seatResults)
        local seat = 0
        repeat
            seat = seat + 1
            if entity.seats[seat].source then
                UpdatePlayerBalance(entity.seats[seat].source, casinoId)
                if entity.seats[seat].wagers[1] > 0 then
                    entity.stage = {type = "cleanup", seat = seat}
                    TriggerClientCasinoEvent("pickle_casinos:blackjack:updateStage", -1, casinoId, entityId, entity.stage)
                    Wait(2000)
                end
            end
        until seat >= 4
        entity.stage = {type = "cleanup", seat = 0}
        TriggerClientCasinoEvent("pickle_casinos:blackjack:updateStage", -1, casinoId, entityId, entity.stage)
        Wait(2000)
        for k,v in pairs(entity.seats) do
            entity.seats[k].hands = {{}, {}}
            entity.seats[k].wagers = {0, 0}
            TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeat", -1, casinoId, entityId, k, entity.seats[k])
        end
        StartBlackjackLobby(casinoId, entityId)
    end, function()
        -- The round crashed: refund stakes if payouts hadn't started, then reopen the table.
        for k, seat in pairs(entity.seats) do
            if k ~= 0 and seat.source and not entity.roundPaid and IsPlayerOnline(seat.source) then
                local refund = (seat.wagers[1] or 0) + (seat.wagers[2] or 0)
                if refund > 0 then AddCasinoChips(seat.source, casinoId, refund) end
            end
            seat.hands = {{}, {}}
            seat.wagers = {0, 0}
        end
        entity.stage = {type = "waiting", time = 0}
        StartBlackjackLobby(casinoId, entityId)
    end)
end

function StartBlackjackLobby(casinoId, entityId)
    BlackjackLobbies[casinoId] = BlackjackLobbies[casinoId] or {}
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    local totalPlayers = 0
    for i=1, #entity.seats do
        if entity.seats[i].source and not entity.seats[i].inSeat then
            LeaveBlackjackEntity(entity.seats[i].source, casinoId, entityId, i)
        elseif entity.seats[i].source then
            totalPlayers = totalPlayers + 1
        end
    end
    if totalPlayers < 1 then
        BlackjackLobbies[casinoId][entityId] = false
        return
    else
        BlackjackLobbies[casinoId][entityId] = true
    end
    entity.stage = {type = "waiting", time = GetWaitingTime("blackjack")}
    TriggerClientCasinoEvent("pickle_casinos:blackjack:updateStage", -1, casinoId, entityId, entity.stage)
    CreateThread(function()
        for i=1, #entity.seats do
            if entity.seats[i].source and not entity.seats[i].inSeat then
                LeaveBlackjackEntity(entity.seats[i].source, casinoId, entityId, i)
            end
        end
        while entity.stage.type == "waiting" and entity.stage.time > 1 do
            entity.stage.time = entity.stage.time - 1
            Wait(1000)
        end
        local totalWagers = 0
        for k,v in pairs(entity.seats) do
            if v.wagers then
                totalWagers = totalWagers + v.wagers[1]
            end
        end
        if totalWagers > 0 then
            StartBlackjackGame(casinoId, entityId)
        else
            StartBlackjackLobby(casinoId, entityId)
        end
    end)
end

function GenerateDefaultBlackjackSeat()
    return {source = nil, wagers = {0, 0}, hands = {{}, {}}, inSeat = false}
end

function InitializeBlackjackEntity(casinoId, entity, dataOnly)
    local entity = entity or { id = "ERR_BLACKJACK_ENTITY" }
    entity.seats = {}
    for i=0, 4 do 
        entity.seats[i] = GenerateDefaultBlackjackSeat()
    end
    entity.betRange = {
        math.floor(entity.settings.maxWager / 100),
        entity.settings.maxWager
    }
    return entity
end

function GetPlayerBlackjackInfo(source)
    if not source or source < 1 then return end
    for k,v in pairs(Casinos) do
        for i=1, #v.entities do
            local entity = v.entities[i]
            if entity.type == "blackjack" then
                for j, v in pairs(entity.seats) do
                    if entity.seats[j].source and tonumber(entity.seats[j].source) == tonumber(source) then
                        return {casinoId = k, entityId = entity.id, seatId = j}
                    end
                end
            end
        end
    end
end

RegisterCallback("pickle_casinos:blackjack:requestSeat", function(source, cb, casinoId, entityId, seatId)
    if not CanUseCasinoEntity(source, casinoId, entityId, "blackjack") then return cb(nil) end
    local seatId = JoinBlackjackEntity(source, casinoId, entityId, seatId)
    local entity = GetBlackjackEntity(casinoId, entityId)
    if seatId then
        return cb(seatId, {
            id = entity.id,
            betRange = entity.betRange,
            seats = entity.seats,
            stage = entity.stage,
            money = GetCasinoChips(source, casinoId)
        })
    end
    cb(seatId)
end)

RegisterNetEvent("pickle_casinos:blackjack:leaveTable", function()
    local source = source
    local info = GetPlayerBlackjackInfo(source)
    if not info then return end
    local entity = GetCasinoEntity(info.casinoId, info.entityId)
    if not entity then return end
    if entity.stage.type == "waiting" then
        LeaveBlackjackEntity(source, info.casinoId, info.entityId, info.seatId)
    else 
        entity.seats[info.seatId].inSeat = false
    end
end)

RegisterNetEvent("pickle_casinos:blackjack:performAction", function(action)
    local source = source
    local info = GetPlayerBlackjackInfo(source)
    if not info then return end
    local entity = GetCasinoEntity(info.casinoId, info.entityId)
    if not entity then return end
    if entity.stage.type ~= "turn" then return end
    -- Only the seat whose turn it is may act, and only with a known action.
    if entity.stage.seat ~= info.seatId then return end
    if entity.stage.action ~= nil then return end
    if action ~= "hit" and action ~= "stand" and action ~= "double" and action ~= "split" then return end
    entity.stage.action = action
    if action == "split" then
        TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeatWager", -1, info.casinoId, info.entityId, info.seatId, 2, entity.seats[info.seatId].wagers[1])
    end
end)    

RegisterNetEvent("pickle_casinos:blackjack:setWager", function(wager)
    local source = source
    PerformCooldownProcess(source)
    local info = GetPlayerBlackjackInfo(source)
    if not info then return end
    local entity = GetCasinoEntity(info.casinoId, info.entityId)
    if not entity then return end
    if entity.stage.type ~= "waiting" then return end
    -- 0 clears the bet; anything else must be a whole number inside the table's range.
    wager = SanitizeInt(wager, 0, entity.betRange[2])
    if not wager or (wager > 0 and wager < entity.betRange[1]) then
        return ShowNotification(source, _L("invalid_wager"))
    end
    entity.seats[info.seatId].wagers[1] = wager
    TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeatWager", -1, info.casinoId, info.entityId, info.seatId, 1, wager)
end)

RegisterNetEvent("pickle_casinos:blackjack:repeatWager", function()
    local source = source
    PerformCooldownProcess(source)
    local info = GetPlayerBlackjackInfo(source)
    if not info then return end
    local entity = GetCasinoEntity(info.casinoId, info.entityId)
    if not entity then return end
    if entity.stage.type ~= "waiting" then return end
    if not LastWagers[source] then return end
    if LastWagers[source][1] > entity.betRange[2] then
        LastWagers[source][1] = entity.betRange[2]
    end
    local balance = GetCasinoChips(source, info.casinoId)
    if balance < LastWagers[source][1] then
        LastWagers[source][1] = balance
    end
    entity.seats[info.seatId].wagers[1] = LastWagers[source][1]
    TriggerClientCasinoEvent("pickle_casinos:blackjack:updateSeatWager", -1, info.casinoId, info.entityId, info.seatId, 1, entity.seats[info.seatId].wagers[1])
end)

AddEventHandler('playerDropped', function()
    local source = source
    local info = GetPlayerBlackjackInfo(source)
    if not info then return end
    LeaveBlackjackEntity(source, info.casinoId, info.entityId, info.seatId)
end)