local function GetAudioZone(casino, zoneId)
    if not casino.settings.audio_zones then return nil, nil end
    for i = 1, #casino.settings.audio_zones do
        if casino.settings.audio_zones[i].id == zoneId then
            return casino.settings.audio_zones[i], i
        end
    end
    return nil, nil
end

local function SaveAndSync(casinoId, casino)
    MySQL.Async.execute('UPDATE `pickle_casinos` SET settings = ? WHERE id = ?', {json.encode(casino.settings), casinoId})
    TriggerClientEvent("pickle_casinos:syncAudioZones", -1, casinoId, casino.settings.audio_zones)
end

-- Every zone/point is saved to the DB and broadcast to all players, so keep them bounded.
local MAX_AUDIO_ZONES = 32
local MAX_ZONE_POINTS = 64

local function ToPoint(p)
    if type(p) ~= "table" and type(p) ~= "vector3" then return nil end
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return nil end
    if math.abs(x) > 1e5 or math.abs(y) > 1e5 or math.abs(z) > 1e5 then return nil end
    return { x = x, y = y, z = z }
end

RegisterNetEvent("pickle_casinos:addAudioZone", function(casinoId, zoneData)
    local source = source
    if not CanManageCasino(source, casinoId) then return ShowNotification(source, _L("no_permission")) end
    local casino = Casinos[casinoId]
    if not casino then return end
    if casino.settings.label == PERSONAL_CASINOS_LABEL then return end
    if type(zoneData) ~= "table" or not GetAudioPreset(zoneData.preset) then return end

    if not casino.settings.audio_zones then
        casino.settings.audio_zones = {}
    end
    if #casino.settings.audio_zones >= MAX_AUDIO_ZONES then return end

    local points = {}
    if type(zoneData.points) == "table" then
        for i = 1, math.min(#zoneData.points, MAX_ZONE_POINTS) do
            local p = ToPoint(zoneData.points[i])
            if p then
                table.insert(points, p)
            end
        end
    end

    local zone = {
        id = math.random(100000, 999999),
        preset = zoneData.preset,
        points = points,
    }

    table.insert(casino.settings.audio_zones, zone)
    SaveAndSync(casinoId, casino)
end)

RegisterNetEvent("pickle_casinos:deleteAudioZone", function(casinoId, zoneId)
    local source = source
    if not CanManageCasino(source, casinoId) then return ShowNotification(source, _L("no_permission")) end
    local casino = Casinos[casinoId]
    if not casino then return end
    if not casino.settings.audio_zones then return end

    for i = #casino.settings.audio_zones, 1, -1 do
        if casino.settings.audio_zones[i].id == zoneId then
            table.remove(casino.settings.audio_zones, i)
            break
        end
    end

    SaveAndSync(casinoId, casino)
end)

RegisterNetEvent("pickle_casinos:addAudioZonePoint", function(casinoId, zoneId, coords)
    local source = source
    if not CanManageCasino(source, casinoId) then return ShowNotification(source, _L("no_permission")) end
    local casino = Casinos[casinoId]
    if not casino then return end
    local point = ToPoint(coords)
    if not point then return end

    local zone = GetAudioZone(casino, zoneId)
    if not zone then return end
    if #zone.points >= MAX_ZONE_POINTS then return end

    table.insert(zone.points, point)
    SaveAndSync(casinoId, casino)
end)

RegisterNetEvent("pickle_casinos:deleteAudioZonePoint", function(casinoId, zoneId, pointIndex)
    local source = source
    if not CanManageCasino(source, casinoId) then return ShowNotification(source, _L("no_permission")) end
    local casino = Casinos[casinoId]
    if not casino then return end

    local zone = GetAudioZone(casino, zoneId)
    if not zone then return end

    pointIndex = tonumber(pointIndex)
    if not pointIndex or pointIndex < 1 or pointIndex > #zone.points then return end

    table.remove(zone.points, pointIndex)
    SaveAndSync(casinoId, casino)
end)
