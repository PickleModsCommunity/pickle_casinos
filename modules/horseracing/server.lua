Tracks = {}

local LastWagers = {}

function GetDefaultWager()
    return {
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
        [5] = 0,
        [6] = 0,
        [7] = 0,
        [8] = 0,
        [9] = 0,
        [10] = 0,
        [11] = 0,
        [12] = 0,
    }
end

function GenerateWinningHorse(horses)
    local stack = {}
    for i=1, #Config.HorseRacing.odds do
        local odds = Config.HorseRacing.odds[i]
        for j=1, odds.chances do
            table.insert(stack, i)
        end
    end
    local oddsIndex = stack[math.random(1, #stack)]
    for i=1, #horses do 
        if horses[i].oddsIndex == oddsIndex then return i end
    end
end

function InitializeHorseRacingTracks()
    for i=1, #Config.HorseRacing.tracks do
        local track = Config.HorseRacing.tracks[i]
        Tracks[i] = {
            id = i,
            stage = {type = "waiting"},
            label = track.label,
            coords = vector3(track.coords.x, track.coords.y, track.coords.z),
            heading = track.heading,
            distance = track.distance,
            renderDistance = track.renderDistance,
            players = {}
        }
        StartHorseRacingTrackLobby(i)
    end
end

function StartHorseRacingTrackRace(trackId)
    local track = Tracks[trackId]
    if not track then return end
    local transactions = {}
    track.stage = {type = "racing", winner = GenerateWinningHorse(track.horses)}
    for source,player in pairs(track.players) do 
        local totalWager = 0
        for a,b in pairs(player.wagers) do 
            totalWager = totalWager + b
        end
        if totalWager > 0 then
            local money = GetCasinoChips(source, track.players[source].casinoId)
            if money < totalWager or not RemoveCasinoChips(source, track.players[source].casinoId, totalWager) then
                track.players[source].wagers = GetDefaultWager()
                TriggerClientEvent("pickle_casinos:horseracing:updateWager", source, track.players[source].casinoId, trackId, track.players[source].wagers)
            else
                LastWagers[source] = track.players[source].wagers
                RegisterLuckyTicketWager(source, "horseracing", totalWager)
                transactions[source] = StartCasinoGameplayTransaction(source, track.players[source].casinoId, track.players[source].entityId, "horseracing", totalWager)
            end
        end
    end
    TriggerHorseRacingUpdateForNearbyPlayers(trackId, trackId, track.stage)
    Wait(18000)
    local multiplier = Config.HorseRacing.odds[track.horses[track.stage.winner].oddsIndex].multiplier
    for source,player in pairs(track.players) do
        local winnings = (player.wagers[track.stage.winner] or 0) * multiplier
        if winnings > 0 and transactions[source] then
            AddCasinoChips(source, player.casinoId, player.wagers[track.stage.winner] + winnings)
            TriggerClientEvent("pickle_casinos:displayResults", source, player.wagers[track.stage.winner] + winnings, GetCasinoChips(source, player.casinoId))
        end
        if transactions[source] then
            EndCasinoGameplayTransaction(transactions[source], source, player.casinoId, player.entityId, "horseracing", player.wagers[track.stage.winner] + winnings)
        end
    end
    Wait(7000)
    for source,player in pairs(track.players) do 
        player.wagers = GetDefaultWager()
        TriggerClientEvent("pickle_casinos:horseracing:updateWager", source,  track.players[source].casinoId, trackId, player.wagers)
        UpdatePlayerBalance(source, track.players[source].casinoId)
    end
    StartHorseRacingTrackLobby(trackId)
end

function StartHorseRacingTrackLobby(trackId)
    local track = Tracks[trackId]
    if not track then return end
    track.horses = GenerateHorses()
    track.stage = {type = "waiting", time = GetWaitingTime("horseracing")}
    TriggerHorseRacingUpdateForNearbyPlayers(trackId, trackId, track.stage, track.horses)
    CreateThread(function()
        while track.stage.type == "waiting" and track.stage.time > 1 do
            track.stage.time = track.stage.time - 1
            Wait(1000)
        end
        StartHorseRacingTrackRace(trackId)
    end)
end

function GetHorseRacingEntity(casinoId, entityId)
    local casino = Casinos[casinoId]
    if not casino then return end
    for i=1, #casino.entities do
        local entity = casino.entities[i]
        if entity.id == entityId then
            return entity
        end
    end
end

function InitializeHorseRacingEntity(casinoId, data)
    local entity = data or { id = "ERR_NO_ID_HORSERACING" }
    entity.betRange = {
        math.floor(entity.settings.maxWager / 100),
        entity.settings.maxWager
    }
    return entity
end

function GenerateHorses()
    local horseCount = 12
    local horses = {}
    local multipliersLeft = {}
    for i=1, #Config.HorseRacing.odds do
        multipliersLeft[i] = i
    end
    for i=1, horseCount do
        local horse = {}
        local randomIndex = math.random(1, #multipliersLeft)
        local oddsIndex = multipliersLeft[randomIndex]
        local odds = Config.HorseRacing.odds[oddsIndex]
        horse.oddsIndex = oddsIndex
        table.insert(horses, horse)
        table.remove(multipliersLeft, randomIndex)
    end
    return horses
end

function UpdateHorseTracks(source)
    TriggerClientEvent("pickle_casinos:horseracing:updateTracks", source, GetPublicHorseTracks())
end

-- Send a track-stage update only to players who are within the track's renderDistance.
-- This prevents the race loop from being triggered on clients that are far away from
-- the track and would never meaningfully interact with it.
function TriggerHorseRacingUpdateForNearbyPlayers(trackId, ...)
    local track = Tracks[trackId]
    if not track then return end
    local trackCoords = track.coords
    local renderDistance = track.renderDistance
    local args = {...}
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if source then
            local ped = GetPlayerPed(source)
            if ped and ped ~= 0 then
                local playerCoords = GetEntityCoords(ped)
                if #(playerCoords - trackCoords) <= renderDistance then
                    TriggerClientEvent("pickle_casinos:horseracing:updateTrackStage", source, table.unpack(args))
                end
            end
        end
    end
end

RegisterNetEvent("pickle_casinos:horseracing:setWager", function(casinoId, entityId, trackId, wager)
    local source = tonumber(source)
    PerformCooldownProcess(source)
    local canUse, casino, casinoEntity = CanUseCasinoEntity(source, casinoId, entityId, "horseracing")
    if not canUse then return end
    local track = Tracks[trackId]
    if not track then return end
    if track.stage.type ~= "waiting" then return end
    local wagers = {}
    if type(wager) == "table" then
        -- The NUI sends horses keyed "0".."11"; build a fixed 1..12 table from
        -- whole, non-negative chip amounts only.
        wagers = GetDefaultWager()
        local valid = true
        for i, v in pairs(wager) do
            local index = SanitizeInt(i, 0, #wagers - 1)
            local value = SanitizeInt(v, 0)
            if not index or not value then
                valid = false
                break
            end
            wagers[index + 1] = value
        end
        local totalWager = 0
        for i=1, #wagers do
            totalWager = totalWager + wagers[i]
        end
        local money = GetCasinoChips(source, casinoId)
        if not valid or money < totalWager or totalWager > casinoEntity.betRange[2] then
            wagers = track.players[source] and (track.players[source].wagers or GetDefaultWager()) or GetDefaultWager()
        end
    elseif wager == "repeat" then
        wagers = LastWagers[source] or GetDefaultWager()
        local totalWager = 0
        for i=1, #wagers do
            totalWager = totalWager + wagers[i]
        end
        if totalWager <= 0 or totalWager > GetCasinoChips(source, casinoId) then
            wagers = GetDefaultWager()
        end
    else
        wagers = GetDefaultWager()
    end
    track.players[source] = {casinoId = casinoId, entityId = entityId, wagers = wagers}
    TriggerClientEvent("pickle_casinos:horseracing:updateWager", source, casinoId, trackId, track.players[source].wagers)
end)

CreateThread(function()
    Wait(100)
    InitializeHorseRacingTracks()
end)

-- Tracks without other players' bets.
function GetPublicHorseTracks()
    local out = {}
    for id, track in pairs(Tracks) do
        local copy = {}
        for k, v in pairs(track) do
            if k ~= "players" then copy[k] = v end
        end
        out[id] = copy
    end
    return out
end

RegisterCallback("pickle_casinos:horseracing:getHorseRacingInfo", function(source, cb, casinoId)
    cb({
        money = GetCasinoChips(source, casinoId),
        tracks = GetPublicHorseTracks(),
    })
end)


AddEventHandler('playerDropped', function()
    local source = source
    for k,v in pairs(Tracks) do
        if v.players[source] then
            v.players[source] = nil
        end
    end
end)