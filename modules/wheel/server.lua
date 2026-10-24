local PendingSpins = {}
local LastWagers = {}
local WheelLobbies = {}

function DoesWheelLobbyExist(casinoId, entityId)
    if not WheelLobbies[casinoId] then return false end
    if not WheelLobbies[casinoId][entityId] then return false end
    return WheelLobbies[casinoId][entityId]
end

function InitializeWheelEntity(casinoId, data, dataOnly)
    local entity = data or { id = "ERR_NO_ID_POKER" }
    entity.players = {}
    entity.history = {}
    entity.betRange = {
        math.floor(entity.settings.maxWager / 100),
        entity.settings.maxWager
    }
    return entity
end

function GetPlayerWheelInfo(source)
    if not source or source < 1 then return end
    for k,v in pairs(Casinos) do
        for i=1, #v.entities do
            local entity = v.entities[i]
            if entity.type == "wheel" and entity.players[source] then
                return {casinoId = k, entityId = entity.id, seatId = 1}
            end
        end
    end
end

function StartWheelGame(casinoId, entityId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    if entity.stage.type ~= "waiting" then return end
    entity.stage = {type = "starting"}
    local hasSuccessWager = false
    local transactions = {}
    for k,v in pairs(entity.players) do
        if not IsPlayerOnline(k) then
            entity.players[k] = nil
        else
            local total = 0
            for a, b in pairs(v.wagers) do
                total = total + b
            end
            local money = GetCasinoChips(k, casinoId)
            if total > 0 and money - total >= 0 and RemoveCasinoChips(k, casinoId, total) then
                LastWagers[k] = v.wagers
                hasSuccessWager = true
                transactions[k] = StartCasinoGameplayTransaction(k, casinoId, entityId, "wheel", total)
            else
                entity.players[k].wagers = GenerateDefaultWheelWagers()
                LastWagers[k] = entity.players[k].wagers
                TriggerClientEvent("pickle_casinos:wheel:updateWager", k, entity.players[k].wagers)
                if total > 0 then
                    ShowNotification(k, _L("insufficient_chips_bet"))
                end
            end
        end
    end
    if not hasSuccessWager then
        StartWheelLobby(casinoId, entityId)
        return
    end
    local result = GetSafeDegrees(math.random(0, 360))
    local section = GetSectionForDegrees(result)
    entity.stage = {type = "spinning", degrees = result}
    TriggerClientCasinoEvent("pickle_casinos:wheel:updateStage", -1, casinoId, entityId, entity.stage)
    entity.roundPaid = false
    local charged = transactions
    CreateSafeGameThread("wheel", function()
        Wait(15000)
        local multiplier = 1
        if section == "bonus" then
            local bonusIndex, bonusMultiplier = GetRandomMultiplier()
            multiplier = bonusMultiplier
            entity.stage = {type = "bonus", prizeId = "bonus_" .. bonusIndex}
            TriggerClientCasinoEvent("pickle_casinos:wheel:updateStage", -1, casinoId, entityId, entity.stage)
            Wait(8000)
        end
        entity.roundPaid = true
        for k, v in pairs(entity.players) do
            local sectionBet = v.wagers[section] or 0
            local online = IsPlayerOnline(k)
            local money = online and GetCasinoChips(k, casinoId) or 0
            if sectionBet > 0 and online and transactions[k] then
                local payout = 0
                if section == "bonus" then
                    payout = math.floor(sectionBet * multiplier)
                else
                    payout = math.floor(sectionBet * Config.WheelMultiplier[section])
                end
                money = money + payout
                AddCasinoChips(k, casinoId, payout)
                TriggerClientEvent("pickle_casinos:displayResults", k, payout, money)
                if transactions[k] then
                    EndCasinoGameplayTransaction(transactions[k], k, casinoId, entityId, "wheel", payout)
                    transactions[k] = nil
                end
            end
        end
        entity.stage = {type = "winner", section = section, multiplier = section == "bonus" and multiplier or nil}
        TriggerClientCasinoEvent("pickle_casinos:wheel:updateStage", -1, casinoId, entityId, entity.stage)
        Wait(5000)
        table.insert(entity.history, 1, {section = section, multiplier = section == "bonus" and multiplier or nil})
        if #entity.history > 30 then
            table.remove(entity.history, #entity.history)
        end
        TriggerClientCasinoEvent("pickle_casinos:wheel:updateHistory", -1, casinoId, entityId, entity.history)
        for k,v in pairs(entity.players) do
            if IsPlayerOnline(k) then
                UpdatePlayerBalance(k, casinoId)
                entity.players[k].wagers = GenerateDefaultWheelWagers()
                TriggerClientEvent("pickle_casinos:wheel:updateWager", k, entity.players[k].wagers)
            else
                entity.players[k] = nil
            end
        end
        StartWheelLobby(casinoId, entityId)
    end, function()
        -- The round crashed: refund charged stakes if payouts hadn't started, then reopen the wheel.
        for k, v in pairs(entity.players) do
            if not entity.roundPaid and charged[k] and IsPlayerOnline(k) then
                local refund = 0
                for _, b in pairs(v.wagers) do refund = refund + b end
                if refund > 0 then AddCasinoChips(k, casinoId, refund) end
            end
            v.wagers = GenerateDefaultWheelWagers()
        end
        entity.stage = {type = "waiting", time = 0}
        StartWheelLobby(casinoId, entityId)
    end)
    -- CreateThread(function()
    --     while entity.stage.type == "spinning" and entity.stage.time > 1 do
    --         entity.stage.time = entity.stage.time - 1
    --         Wait(1000)
    --     end
    --     StartWheelLobby(casinoId, entityId)
    -- end)
end

function StartWheelLobby(casinoId, entityId)
    WheelLobbies[casinoId] = WheelLobbies[casinoId] or {}
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    local totalPlayers = 0
    for k,v in pairs(entity.players) do
        if not v.left then
            totalPlayers = totalPlayers + 1
        end
    end
    if totalPlayers <= 0 then 
        WheelLobbies[casinoId][entityId] = false
        return
    else 
        WheelLobbies[casinoId][entityId] = true
    end
    entity.stage = {type = "waiting", time = GetWaitingTime("wheel")}
    TriggerClientCasinoEvent("pickle_casinos:wheel:updateStage", -1, casinoId, entityId, entity.stage)
    CreateThread(function()
        for k,v in pairs(entity.players) do
            if v.left then
                entity.players[k] = nil
            end
        end
        while entity.stage.type == "waiting" and entity.stage.time > 1 do
            entity.stage.time = entity.stage.time - 1
            Wait(1000)
        end
        local totalWagers = 0
        for k,v in pairs(entity.players) do
            if v.wagers then
                local total = 0
                for a, b in pairs(v.wagers) do
                    total = total + b
                end
                totalWagers = totalWagers + total
            end
        end
        if totalWagers > 0 then
            StartWheelGame(casinoId, entityId)
        else
            StartWheelLobby(casinoId, entityId)
        end
    end)
end

function GenerateDefaultWheelWagers()
    return {
        two = 0,
        three = 0,
        five = 0,
        eleven = 0,
        twentyThree = 0,
        bonus = 0,
    }
end

RegisterNetEvent("pickle_casinos:wheel:leaveTable", function()
    local playerInfo = GetPlayerWheelInfo(source)
    if not playerInfo then return end
    local entity = GetCasinoEntity(playerInfo.casinoId, playerInfo.entityId)
    if not entity then return end
    local player = entity.players[source]
    if not player then return end
    if entity.stage.type == "waiting" then
        entity.players[source] = nil
    else
        entity.players[source].left = true
    end
end)

AddEventHandler("playerDropped", function()
    local src = source
    for _, casino in pairs(Casinos) do
        for i = 1, #casino.entities do
            local entity = casino.entities[i]
            if entity.type == "wheel" and entity.players and entity.players[src] then
                -- Keep a charged wager in place mid-spin (it is forfeited); otherwise drop the seat.
                if entity.stage and entity.stage.type == "waiting" then
                    entity.players[src] = nil
                else
                    entity.players[src].left = true
                end
            end
        end
    end
end)

RegisterCallback("pickle_casinos:wheel:requestSeat", function(source, cb, casinoId, entityId, seatId)
    local canUse, casino, entity = CanUseCasinoEntity(source, casinoId, entityId, "wheel")
    if not canUse then return cb(nil) end
    local existing = GetPlayerWheelInfo(source)
    if existing and (existing.casinoId ~= casinoId or existing.entityId ~= entityId) then
        ShowNotification(source, _L("playing_other_game"))
        return cb(nil)
    end
    if not entity.players[source] then
        entity.players[source] = {
            wagers = GenerateDefaultWheelWagers(),
        }
    end
    entity.players[source].left = nil
    if not DoesWheelLobbyExist(casinoId, entityId) then
        StartWheelLobby(casinoId, entityId)
    end
    cb(1, {
        stage = entity.stage,
        history = entity.history,
        money = GetCasinoChips(source, casinoId),
        betRange = entity.betRange,
    })
end)

function GetRandomMultiplier()
    local wheelBonus = Config.WheelBonus
    local options = {}
    for i=1, #wheelBonus do
        local option = wheelBonus[i]
        for j=1, option.chance do 
            table.insert(options, {index = i, multiplier = option.multiplier})
        end
    end
    local result = options[math.random(1, #options)]
    return result.index, result.multiplier
end

RegisterNetEvent("pickle_casinos:wheel:setWager", function(wagers)
    local source = source
    PerformCooldownProcess(source)
    if not wagers or type(wagers) ~= "table" then return end
    local info = GetPlayerWheelInfo(source)
    if not info then return end
    local entity = GetCasinoEntity(info.casinoId, info.entityId)
    if not entity then return end
    if entity.stage.type ~= "waiting" then return end
    local player = entity.players[source]
    if not player then return end
    -- Whole, non-negative chip amounts only (rejects strings, NaN, inf and fractions).
    local newWagers = {}
    local totalWager = 0
    for k in pairs(GenerateDefaultWheelWagers()) do
        local value = wagers[k]
        if value == nil then value = 0 end
        value = SanitizeInt(value, 0)
        if not value then
            ShowNotification(source, _L("invalid_wager"))
            return TriggerClientEvent("pickle_casinos:wheel:updateWager", source, player.wagers)
        end
        newWagers[k] = value
        totalWager = totalWager + value
    end
    local money = GetCasinoChips(source, info.casinoId)
    if money - totalWager < 0 then
        ShowNotification(source, _L("insufficient_chips_bet"))
    elseif totalWager > entity.betRange[2] then
        ShowNotification(source, _L("max_wager_cap", NumberWithCommas(entity.betRange[2])))
    else
        player.wagers = newWagers
    end
    TriggerClientEvent("pickle_casinos:wheel:updateWager", source, player.wagers)
end)

RegisterNetEvent("pickle_casinos:wheel:repeatWager", function()
    local source = source
    PerformCooldownProcess(source)
    local info = GetPlayerWheelInfo(source)
    if not info then return end
    local entity = GetCasinoEntity(info.casinoId, info.entityId)
    if not entity then return end
    if entity.stage.type ~= "waiting" then return end
    local player = entity.players[source]
    if not player then return end
    local newWagers = LastWagers[source] or GenerateDefaultWheelWagers()
    local totalWager = 0
    for k,v in pairs(newWagers) do
        if v < 0 then
            newWagers[k] = 0
        end
        totalWager = totalWager + newWagers[k]
    end
    local money = GetCasinoChips(source, info.casinoId)
    if money - totalWager < 0 then
        local money = GetCasinoChips(source, info.casinoId)
        ShowNotification(source, _L("insufficient_chips_bet"))
    else
        player.wagers = newWagers
        if totalWager > 0 then
            LastWagers[source] = player.wagers
        end
    end
    TriggerClientEvent("pickle_casinos:wheel:updateWager", source, player.wagers)
end)


-- RegisterCommand("wheelrtp", function(source, args, rawCommand)
--     if source and source > 0 then return end
--     local spinsLeft = 10000
--     local maxSpins = 10000
--     local results = {}
--     while spinsLeft > 0 do
--         spinsLeft = spinsLeft - 1
--         local index, multiplier = GetRandomMultiplier()
--         results[multiplier] = (results[multiplier] or 0) + 1
--         if spinsLeft % 1000 == 0 then
--             Wait(0)
--         end
--     end
--     for k,v in pairs(results) do
--         debugPrint(k, "Chance:", (v / maxSpins) * 100)
--     end
-- end, false)