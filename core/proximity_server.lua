-- Server-owned subscriptions. Clients cannot choose recipients or report positions.
local ReadyPlayers, PlayerGrid = {}, {}
local NearbyCasinos, NearbyEntities = {}, {}

local function SyncDistance()
    return math.max(tonumber(Config.CasinoSyncDistance) or 150.0, (Config.RenderDistance or 50.0) + 25.0)
end

local function GridKey(x, y)
    return x .. ":" .. y
end

local function PlayerPosition(src)
    if not IsCasinoPlayerSession(src, ReadyPlayers[src]) then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    return GetEntityCoords(ped)
end

local function InRange(a, b, distance)
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return x * x + y * y + z * z <= distance * distance
end

local function EntityCoords(entity)
    return entity.settings and entity.settings.location and entity.settings.location.coords
end

local function AddToGrid(src, coords)
    local size = SyncDistance()
    local key = GridKey(math.floor(coords.x / size), math.floor(coords.y / size))
    PlayerGrid[key] = PlayerGrid[key] or {}
    PlayerGrid[key][src] = true
end

-- Query a small number of grid cells, then verify each candidate's current
-- position. Teleporting away stops delivery immediately, before the next tick.
function GetNearbyCasinoPlayers(coords, distance, positions)
    local recipients = {}
    if not coords then return recipients end
    distance = distance or SyncDistance()
    local size = SyncDistance()
    for x = math.floor((coords.x - distance) / size), math.floor((coords.x + distance) / size) do
        for y = math.floor((coords.y - distance) / size), math.floor((coords.y + distance) / size) do
            for src in pairs(PlayerGrid[GridKey(x, y)] or {}) do
                local position
                if positions then position = positions[src] else position = PlayerPosition(src) end
                if position and InRange(position, coords, distance) then recipients[src] = true end
            end
        end
    end
    return recipients
end

function GetCasinoEntityRecipients(casinoId, entityId)
    local entity = GetCasinoEntity(casinoId, entityId)
    local recipients = GetNearbyCasinoPlayers(entity and EntityCoords(entity))
    if not entity then return recipients end
    -- Preserve active games on servers where a participant's ped is temporarily
    -- unavailable (including OneSync-off setups), without broadcasting to spectators.
    local function AddParticipant(src)
        src = tonumber(src)
        if src and not recipients[src] and IsCasinoPlayerSession(src, ReadyPlayers[src]) and not PlayerPosition(src) then
            recipients[src] = true
        end
    end
    for _, seat in pairs(entity.seats or {}) do AddParticipant(seat.source) end
    for src in pairs(entity.players or {}) do AddParticipant(src) end
    if entity.currentPlayer then AddParticipant(entity.currentPlayer.source) end
    AddParticipant(entity.spinner)
    return recipients
end

local function AddRecipients(target, players)
    for src in pairs(players) do target[src] = true end
end

local function CasinoRecipients(casino, positions)
    local recipients = GetNearbyCasinoPlayers(casino.settings and casino.settings.location and casino.settings.location.coords, nil, positions)
    -- Personal casinos can have tables spread across the map. Each table is an
    -- anchor, so proximity never depends on a placeholder casino location.
    for _, entity in ipairs(casino.entities or {}) do
        AddRecipients(recipients, GetNearbyCasinoPlayers(EntityCoords(entity), nil, positions))
    end
    return recipients
end

-- Casino-wide live updates (balances), including explicitly opened management UIs.
-- Infrequent map/layout changes stay global so far-away clients retain valid blips
-- and entity locations and can render them correctly when they approach.
function TriggerCasinoStateEvent(eventName, casinoId, ...)
    if Config.PerformanceMode == false then
        return TriggerClientEvent(eventName, -1, casinoId, ...)
    end
    local casino = Casinos[casinoId]
    if not casino then return end
    local recipients = CasinoRecipients(casino)
    for src in pairs(ManagementViewers[casinoId] or {}) do
        if IsPlayerOnline(src) and CanManageCasino(src, casinoId) then recipients[src] = true end
    end
    for src in pairs(recipients) do TriggerClientEvent(eventName, src, casinoId, ...) end
end

-- Called only after the client's initial casino/track/object definitions were sent.
function RegisterCasinoProximityPlayer(src)
    if Config.PerformanceMode == false then return end
    ReadyPlayers[src] = GetCasinoPlayerSession(src)
    local coords = PlayerPosition(src)
    if coords then AddToGrid(src, coords) end
end

function RefreshCasinoProximity()
    if Config.PerformanceMode == false then
        PlayerGrid, NearbyCasinos, NearbyEntities = {}, {}, {}
        return
    end
    PlayerGrid = {}
    local positions = {}
    for src in pairs(ReadyPlayers) do
        local coords = PlayerPosition(src)
        if coords then
            positions[src] = coords
            AddToGrid(src, coords)
        end
    end
    local nextCasinos, nextEntities, updates = {}, {}, {}
    local function UpdateFor(src, casinoId, casino)
        updates[src] = updates[src] or {}
        updates[src][casinoId] = updates[src][casinoId] or {
            balance = casino.balance, marked_balance = casino.marked_balance, entities = {},
        }
        return updates[src][casinoId]
    end
    for casinoId, casino in pairs(Casinos) do
        local recipients = CasinoRecipients(casino, positions)
        nextCasinos[casinoId] = recipients
        nextEntities[casinoId] = {}
        for src in pairs(recipients) do
            if not (NearbyCasinos[casinoId] or {})[src] then UpdateFor(src, casinoId, casino) end
        end
        for _, entity in ipairs(casino.entities or {}) do
            local players = GetNearbyCasinoPlayers(EntityCoords(entity), nil, positions)
            nextEntities[casinoId][entity.id] = players
            local previous = (NearbyEntities[casinoId] or {})[entity.id] or {}
            for src in pairs(players) do
                if not previous[src] then
                    local snapshot = GetPublicCasinoEntity(entity)
                    -- A seated poker player may have received private cards just
                    -- before this refresh. Keep their own hand; spectators still
                    -- receive the public, obfuscated seats.
                    if entity.type == "poker" then
                        for seatId, seat in pairs(entity.seats or {}) do
                            if seat.source == src then
                                local ownSeat = {}
                                for key, value in pairs(seat) do ownSeat[key] = value end
                                snapshot.seats[seatId] = ownSeat
                            end
                        end
                    end
                    local update = UpdateFor(src, casinoId, casino)
                    update.entities[#update.entities + 1] = snapshot
                end
            end
        end
    end
    NearbyCasinos, NearbyEntities = nextCasinos, nextEntities
    for src, casinos in pairs(updates) do
        TriggerClientEvent("pickle_casinos:syncNearbyCasinos", src, casinos)
    end
end

AddEventHandler("pickle_casinos:playerUnloaded", function(src)
    ReadyPlayers[src] = nil
    for _, players in pairs(PlayerGrid) do players[src] = nil end
    for _, players in pairs(NearbyCasinos) do players[src] = nil end
    for _, entities in pairs(NearbyEntities) do
        for _, players in pairs(entities) do players[src] = nil end
    end
end)

CreateThread(function()
    while true do
        -- One position-index refresh per interval, shared by every live table.
        Wait(math.max(250, math.min(5000, tonumber(Config.PerformanceUpdateInterval) or 1000)))
        RefreshCasinoProximity()
    end
end)
