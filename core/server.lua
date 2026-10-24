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
    if target ~= -1 or Config.PerformanceMode == false then
        return TriggerClientEvent(eventName, target, casinoId, entityId, ...)
    end
    for src in pairs(GetCasinoEntityRecipients(casinoId, entityId)) do
        TriggerClientEvent(eventName, src, casinoId, entityId, ...)
    end
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

-- Only server-side framework events reach this dispatcher. Do not register it
-- as a network event: a client must never choose which player's state to clear.
CasinoUnloadingIdentifiers = {}
local CasinoSessions = {}

function GetCasinoPlayerSession(source)
    source = tonumber(source)
    local identifier = GetIdentifier(source)
    if not identifier then return nil end
    local session = CasinoSessions[source]
    if not session or session.identifier ~= identifier then
        session = { identifier = identifier }
        CasinoSessions[source] = session
    end
    return session
end

function IsCasinoPlayerSession(source, session)
    return session ~= nil and CasinoSessions[tonumber(source)] == session
        and IsPlayerOnline(source) and GetIdentifier(source) == session.identifier
end

function CleanupCasinoPlayer(playerSource, identifier)
    local src = tonumber(playerSource)
    if not src or src <= 0 or CasinoUnloadingIdentifiers[src] then return end
    CasinoUnloadingIdentifiers[src] = identifier or GetKnownIdentifier(src)
    CasinoSessions[src] = nil
    TriggerEvent("pickle_casinos:playerUnloaded", src)
    CasinoUnloadingIdentifiers[src] = nil
end

AddEventHandler("playerDropped", function()
    CleanupCasinoPlayer(source)
end)
AddEventHandler("esx:playerLogout", function(playerSource)
    CleanupCasinoPlayer(playerSource)
end)
AddEventHandler("QBCore:Server:OnPlayerUnload", function(playerSource)
    CleanupCasinoPlayer(playerSource)
end)

-- Default roulette layouts use pairs 7/12 (low/high), 8/11 (even/odd),
-- and 9/10 (red/black). Only their unmatched amounts earn tickets.
function GetUnhedgedRouletteWager(connects)
    local total = 0
    for _, bet in ipairs(connects) do total = total + (bet.wager or 0) end
    for _, pair in ipairs({ {7, 12}, {8, 11}, {9, 10} }) do
        total = total - 2 * math.min(connects[pair[1]].wager or 0, connects[pair[2]].wager or 0)
    end
    return math.max(0, total)
end

-- Reserve before the database lookup so two concurrent casino prizes cannot
-- choose the same plate while the first lookup/insert is waiting on SQL.
local ReservedPrizePlates = {}
function InsertCasinoPrizeVehicle(insertVehicle)
    for _ = 1, 100 do
        local plate = string.char(math.random(65, 90), math.random(65, 90), math.random(65, 90))
            .. " " .. string.format("%03d", math.random(0, 999))
        if not ReservedPrizePlates[plate] then
            ReservedPrizePlates[plate] = true
            local ok, result = pcall(function()
                if GetOwnedVehicleFromPlate(plate) then return false end
                return insertVehicle(plate)
            end)
            ReservedPrizePlates[plate] = nil
            if ok and result then return true end
            if not ok then
                print("^1[pickle_casinos] vehicle prize insert failed: " .. tostring(result) .. "^0")
                return false
            end
        end
    end
    return false
end
