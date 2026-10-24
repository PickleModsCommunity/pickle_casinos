function GetPlayerIdentifiersArray(source)
    local source = tonumber(source)
    if not source then return {} end
    local identifierTypes = {"steam", "discord", "xbl", "live", "license", "license2", "fivem", "ip"}
    local identifiers = {}
    for i=1, #identifierTypes do
        local identifier = GetPlayerIdentifierByType(source, identifierTypes[i])
        if identifier then
            table.insert(identifiers, identifier)
        end
    end
    return identifiers
end

function GetFilteredPlayerIdentifiers(source)
    local source = tonumber(source)
    if not source then return end
    local identifiers = GetPlayerIdentifiersArray(source)
    local filteredIdentifiers = {}
    for i=1, #identifiers do
        if not string.match(identifiers[i], "ip:") or not Config.DisableIPIdentifier then
            table.insert(filteredIdentifiers, identifiers[i])
        end
    end
    return filteredIdentifiers
end

function GetPlayerPrefixIdentifier(source)
    local source = tonumber(source)
    if not source then return end
    local prefix = Config.IdentifierPrefix
    local identifiers = GetPlayerIdentifiersArray(source)
    for i=1, #identifiers do
        if string.match(identifiers[i], prefix .. ":") then
            return identifiers[i]
        end
    end
    if prefix == "license2" then
        for i=1, #identifiers do
            if string.match(identifiers[i], "license:") then
                return identifiers[i]
            end
        end
    end  
end

function TriggerClientCasinoEvent(eventName, target, casinoId, entityId, ...)
    local casinoEntity = GetCasinoEntity(casinoId, entityId)
    if not casinoEntity then return end
    local coords = casinoEntity.settings.location.coords
    -- HANDLE GRID COORDS HERE IF SUPER COOL AND AWESOME
    TriggerClientEvent(eventName, target, casinoId, entityId, ...)
end

local GameplayTransactionCounter = 0

function StartCasinoGameplayTransaction(source, casinoId, entityId, gameType, wagerAmount)
    GameplayTransactionCounter = GameplayTransactionCounter + 1
    local id = os.time() .. "_" .. source .. "_" .. GameplayTransactionCounter
    TriggerEvent("pickle_casinos:gameplay:startTransaction", id, source, casinoId, entityId, gameType, wagerAmount)
    return id
end

function EndCasinoGameplayTransaction(id, source, casinoId, entityId, gameType, winAmount)
    TriggerEvent("pickle_casinos:gameplay:endTransaction", id, source, casinoId, entityId, gameType, winAmount)
end

-- True while the player is still connected. Use before paying out after a delay.
function IsPlayerOnline(source)
    source = tonumber(source)
    if not source or source < 1 then return false end
    return GetPlayerName(source) ~= nil
end

-- True if the player's ped is within `distance` of `coords` (server-side check).
-- Returns nil when the server can't see the ped (e.g. OneSync disabled), so
-- callers can decide whether that should block the action.
function IsPlayerNearCoords(source, coords, distance)
    if not coords then return false end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    local pedCoords = GetEntityCoords(ped)
    return #(pedCoords - vector3(coords.x, coords.y, coords.z)) <= distance
end

-- Runs a game loop body in a thread and logs instead of silently killing the
-- table when it errors. `onError` is called afterwards so the game can recover
-- (normally by restarting its lobby).
function CreateSafeGameThread(label, fn, onError)
    CreateThread(function()
        local ok, err = pcall(fn)
        if not ok then
            print(("^1[pickle_casinos] %s loop error: %s^0"):format(label, tostring(err)))
            if onError then
                Wait(1000)
                pcall(onError)
            end
        end
    end)
end
