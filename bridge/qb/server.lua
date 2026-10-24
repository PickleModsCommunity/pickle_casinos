if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

-- Route all server callbacks through ox_lib regardless of framework, keeping the
-- existing (source, cb, ...) handler contract the modules rely on. See the ESX
-- bridge for the full rationale.
function RegisterCallback(name, cb)
    lib.callback.register(name, function(source, ...)
        local results
        cb(source, function(...) results = table.pack(...) end, ...)
        if results then return table.unpack(results, 1, results.n) end
    end)
end

function RegisterUsableItem(...)
    QBCore.Functions.CreateUseableItem(...)
end

function ShowNotification(target, text)
	TriggerClientEvent(GetCurrentResourceName()..":showNotification", target, text)
end

function GetIdentifier(source)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))?.PlayerData
    if not xPlayer or not xPlayer.citizenid then return end
    return xPlayer.citizenid 
end

function GetSourceFromIdentifier(identifier)
    local xPlayer = QBCore.Functions.GetPlayerByCitizenId(identifier)
    return xPlayer and xPlayer?.PlayerData.source or nil
end

function GetPlayerCharacterName(source)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
    if not xPlayer or not xPlayer.PlayerData then return "Unknown Name" end
    return xPlayer.PlayerData.charinfo.firstname .. " " .. xPlayer.PlayerData.charinfo.lastname
end

function CanAccessGroup(source, data)
    if not data then return true end
    local pdata = QBCore.Functions.GetPlayer(tonumber(source)).PlayerData
    for k,v in pairs(data) do 
        if (pdata.job.name == k and pdata.job.grade.level >= v) then return true end
    end
    return false
end

function CheckPermission(source, permission)
    if permission.ignorePermissions then return true end
    local source = tonumber(source)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))?.PlayerData
    if not xPlayer then return end
    local name = xPlayer.job.name
    local rank = xPlayer.job.grade.level
    if permission.jobs[name] and permission.jobs[name] <= rank then 
        return true
    end
    for i=1, #(permission.groups or {}) do 
        if QBCore.Functions.HasPermission(source, permission.groups[i]) then 
            return true 
        end
    end
end

function AddMoney(source, count, currency)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
    local currency = currency or "money"
    if (currency == "money") then
        xPlayer.Functions.AddMoney('cash', count)
    elseif (currency == "dirty") then
        local setting = Config.FrameworkSettings.dirtyMoney
        Inventory.AddItem(source, setting == "DEFAULT" and 'dirty_money' or setting, count)
    end
    TriggerClientEvent("pickle_casinos:updateMoney", source, money)
end

function RemoveMoney(source, count, currency)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
    local currency = currency or "money"
    if (currency == "money") then
        xPlayer.Functions.RemoveMoney('cash', count)
    elseif (currency == "dirty") then
        local setting = Config.FrameworkSettings.dirtyMoney
        Inventory.RemoveItem(source, setting == "DEFAULT" and 'dirty_money' or setting, count)
    end
    TriggerClientEvent("pickle_casinos:updateMoney", source, money)
end

function GetMoney(source, currency)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
    local currency = currency or "money"
    local money = 0
    if (currency == "money") then
        money = xPlayer.PlayerData.money.cash
    elseif (currency == "dirty") then
        local setting = Config.FrameworkSettings.dirtyMoney
        money = Inventory.GetItemCount(source, setting == "DEFAULT" and 'dirty_money' or setting)
    end
    TriggerClientEvent("pickle_casinos:updateMoney", source, money)
    return money
end

function GetOwnedVehicleFromPlate(plate)
    local data = MySQL.Sync.fetchAll("SELECT * FROM player_vehicles WHERE plate=@plate;", {
        ['@plate'] = plate,
    })[1]
    return data and {owner = data.citizenid} or nil
end

function AddOwnedVehicle(source, model)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
    local plate = ""
    local letters = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"}
    local numbers = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}
    for i = 1, 3 do
        plate = plate .. letters[math.random(1, #letters)]
    end
    plate = plate .. " "
    for i = 1, 3 do
        plate = plate .. numbers[math.random(1, #numbers)]
    end
    MySQL.Async.fetchAll('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, plate, garage, state) VALUES (@license, @citizenid, @vehicle, @hash, @plate, @garage, @state)',
    {
        ['@license'] = xPlayer.PlayerData.license,
        ['@citizenid'] = xPlayer.PlayerData.citizenid,
        ['@vehicle'] = model,
        ['@hash'] = joaat(model),
        ['@plate'] = toupper(plate),
        ['@garage'] = "pillboxgarage",
        ['@state'] = 0
    })
end

function UpdateVehiclePlate(source, plate, newPlate)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
    MySQL.Async.execute('UPDATE player_vehicles SET plate = @newPlate WHERE plate = @plate AND citizenid = @citizenid',
    {
        ['@newPlate'] = newPlate,
        ['@plate'] = plate,
        ['@citizenid'] = xPlayer.PlayerData.citizenid
    })
end

function GetPlayerJob(source)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
    if not xPlayer then return end
    return {label = xPlayer.PlayerData.job.label, rank_label = xPlayer.PlayerData.job.grade.name}
end

function GetPlayerJobName(source)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
    if not xPlayer or not xPlayer.PlayerData or not xPlayer.PlayerData.job then return nil end
    return xPlayer.PlayerData.job.name
end

function GetPlayerJobGrade(source)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
    if not xPlayer or not xPlayer.PlayerData or not xPlayer.PlayerData.job or not xPlayer.PlayerData.job.grade then return nil end
    return tonumber(xPlayer.PlayerData.job.grade.level)
end

function SetPlayerJob(source, job, grade)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
    xPlayer.Functions.SetJob(job, grade)
end

function IsPlayerJobBoss(source, jobName)
    if not jobName then return false end
    local player = QBCore.Functions.GetPlayer(tonumber(source))
    if not player or not player.PlayerData or not player.PlayerData.job then return false end
    if player.PlayerData.job.name ~= jobName then return false end
    if player.PlayerData.job.isboss == true then return true end
    if player.PlayerData.job.grade and player.PlayerData.job.grade.isboss == true then return true end
    return false
end

function GetEmployees(jobName, cb)
    local employees = {}
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        if player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name == jobName then
            employees[#employees + 1] = {
                source = player.PlayerData.source,
                name = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname,
                grade = player.PlayerData.job.grade.level,
                gradeLabel = player.PlayerData.job.grade.name,
                online = true,
            }
        end
    end
    if type(cb) == "function" then cb(employees) end
    return employees
end

function GetJobGrades(jobName)
    local job = QBCore.Shared.Jobs[jobName]
    if not job or not job.grades then return {} end
    local grades = {}
    for level, grade in pairs(job.grades) do
        grades[#grades + 1] = {
            level = tonumber(level),
            label = grade.name or ("Grade " .. level),
        }
    end
    table.sort(grades, function(a, b) return a.level < b.level end)
    return grades
end

function IsPlayerAdmin(source)
    local source = tonumber(source)
    if not source or source < 1 then return false end
    -- Only the configured admin groups count; the generic "command" ACE is
    -- granted far more widely than casino administration should be.
    for i=1, #Config.AdminGroups do
        if QBCore.Functions.HasPermission(source, Config.AdminGroups[i]) or IsPlayerAceAllowed(source, Config.AdminGroups[i]) then
            return true
        end
    end
    return false
end

function AddSocietyMoney(name, amount)
    if Config.FrameworkSettings.society == "qb-management" then
        exports["qb-management"]:AddMoney(name, amount)
    else
        exports["qb-banking"]:AddMoney(name, amount)
    end
end

-- Inventory Fallback

CreateThread(function()
    Wait(100)
    
    if InitializeInventory then return InitializeInventory() end -- Already loaded through inventory folder.
    
    Inventory = {}

    Inventory.Items = {}
    
    Inventory.Ready = false

    Inventory.CanCarryItem = function(source, name, count)
        local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
        local weight = QBCore.Player.GetTotalWeight(xPlayer.PlayerData.items)
        local item = QBCore.Shared.Items[name:lower()]
        return ((weight + (item.weight * count)) <= QBCore.Config.Player.MaxWeight)
    end

    Inventory.GetInventory = function(source)
        local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
        local items = {}
        local data = xPlayer.PlayerData.items
        for slot, item in pairs(data) do 
            items[#items + 1] = {
                name = item.name,
                label = item.label,
                count = item.amount,
                weight = item.weight
            }
        end
        return items
    end

    Inventory.UpdateInventory = function(source)
        SetTimeout(1000, function()
            TriggerClientEvent("pickle_casinos:updateInventory", source, Inventory.GetInventory(source))
        end)
    end

    Inventory.AddItem = function(source, name, count, metadata) -- Metadata is not required.
        local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
        xPlayer.Functions.AddItem(name, count, nil, metadata)
        Inventory.UpdateInventory(source)
    end

    Inventory.RemoveItem = function(source, name, count)
        local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
        xPlayer.Functions.RemoveItem(name, count)
        Inventory.UpdateInventory(source)
    end

    Inventory.AddWeapon = function(source, name, count, metadata) -- Metadata is not required.
        Inventory.AddItem(source, name, count, metadata)
    end

    Inventory.RemoveWeapon = function(source, name, count)
        Inventory.RemoveItem(source, name, count, metadata)
    end

    Inventory.GetItemCount = function(source, name)
        local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
        if not xPlayer then return 0 end
        local item = xPlayer.Functions.GetItemByName(name)
        return item and item.amount or 0
    end

    Inventory.HasWeapon = function(source, name, count)
        return (Inventory.GetItemCount(source, name) > 0)
    end

    RegisterCallback("pickle_casinos:getInventory", function(source, cb)
        cb(Inventory.GetInventory(source))
    end)

    for item, data in pairs(QBCore.Shared.Items) do
        Inventory.Items[item] = {label = data.label}
    end
    Inventory.Ready = true
end)