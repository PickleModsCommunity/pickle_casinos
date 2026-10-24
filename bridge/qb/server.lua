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

-- Cash can be stored two ways: as an inventory item (ox_inventory does this
-- for the accounts in its "inventory:accounts" convar) or as the player's
-- QB cash balance. When it's an item, the item is the source of truth and the
-- cash balance is only a synced copy, so we read and remove the item.
local function UsingOxInventory()
    return GetResourceState("ox_inventory") == "started"
end

-- Returns the item that holds cash, or nil if cash is the QB cash balance.
-- Config.FrameworkSettings.cashItem can force it either way.
local function GetCashItem()
    local setting = Config.FrameworkSettings and Config.FrameworkSettings.cashItem
    if setting == false then return nil end
    if type(setting) == "string" and setting ~= "" and setting ~= "auto" then return setting end
    if not UsingOxInventory() then return nil end
    -- Same rule ox_inventory uses: accounts in inventory:accounts (default ["money"]).
    local ok, list = pcall(json.decode, GetConvar("inventory:accounts", '["money"]'))
    if not ok or type(list) ~= "table" then return "money" end
    for _, name in ipairs(list) do
        if name == "money" then return "money" end
    end
    return nil
end

local function GetDirtyMoneyItem()
    local setting = Config.FrameworkSettings.dirtyMoney
    return setting == "DEFAULT" and 'dirty_money' or setting
end

-- Removes an item through the bridge and returns true only if it was taken,
-- confirming by count when a custom inventory returns nothing.
local function RemoveItemConfirmed(source, item, count)
    local before = Inventory.GetItemCount(source, item) or 0
    local result = Inventory.RemoveItem(source, item, count)
    if result == nil then
        return (before - (Inventory.GetItemCount(source, item) or 0)) >= count
    end
    return result == true
end

function AddMoney(source, count, currency)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
    if not xPlayer then return false end
    local currency = currency or "money"
    local before = GetMoney(source, currency)
    if (currency == "money") then
        local cashItem = GetCashItem()
        if cashItem then
            Inventory.AddItem(source, cashItem, count)
        else
            xPlayer.Functions.AddMoney('cash', count)
        end
    elseif (currency == "dirty") then
        Inventory.AddItem(source, GetDirtyMoneyItem(), count)
    end
    local after = GetMoney(source, currency)
    TriggerClientEvent("pickle_casinos:updateMoney", source, after)
    return after - before >= count
end

-- Removes money and returns true only if it was really taken.
function RemoveMoney(source, count, currency)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
    if not xPlayer then return false end
    local currency = currency or "money"
    local success = false
    if (currency == "money") then
        local cashItem = GetCashItem()
        if cashItem then
            success = RemoveItemConfirmed(source, cashItem, count)
        else
            local before = xPlayer.PlayerData.money.cash or 0
            local result = xPlayer.Functions.RemoveMoney('cash', count)
            if result == nil then
                success = (before - (xPlayer.PlayerData.money.cash or 0)) >= count
            else
                success = result == true
            end
        end
    elseif (currency == "dirty") then
        success = RemoveItemConfirmed(source, GetDirtyMoneyItem(), count)
    end
    TriggerClientEvent("pickle_casinos:updateMoney", source, GetMoney(source, currency))
    return success
end

function GetMoney(source, currency)
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
    if not xPlayer then return 0 end
    local currency = currency or "money"
    local money = 0
    if (currency == "money") then
        local cashItem = GetCashItem()
        if cashItem then
            money = Inventory.GetItemCount(source, cashItem) or 0
        else
            money = xPlayer.PlayerData.money.cash or 0
        end
    elseif (currency == "dirty") then
        money = Inventory.GetItemCount(source, GetDirtyMoneyItem())
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
    if not xPlayer then return false end
    local license, identifier = xPlayer.PlayerData.license, xPlayer.PlayerData.citizenid
    return InsertCasinoPrizeVehicle(function(plate)
        local changed = MySQL.Sync.execute('INSERT IGNORE INTO player_vehicles (license, citizenid, vehicle, hash, plate, garage, state) VALUES (@license, @citizenid, @vehicle, @hash, @plate, @garage, @state)', {
            ['@license'] = license,
            ['@citizenid'] = identifier,
            ['@vehicle'] = model,
            ['@hash'] = joaat(model),
            ['@plate'] = plate,
            ['@garage'] = "pillboxgarage",
            ['@state'] = 0,
        })
        return changed ~= nil and changed > 0
    end)
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

    -- AddItem/RemoveItem return true only when the inventory really changed.
    Inventory.AddItem = function(source, name, count, metadata) -- Metadata is not required.
        local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
        if not xPlayer then return false end
        local success
        if GetResourceState("ox_inventory") == "started" then
            success = exports.ox_inventory:AddItem(source, name, count, metadata) == true
        else
            local before = Inventory.GetItemCount(source, name)
            local result = xPlayer.Functions.AddItem(name, count, nil, metadata)
            if result == nil then
                -- Some inventories return nothing; confirm the count went up.
                success = (Inventory.GetItemCount(source, name) - before) >= count
            else
                success = result == true
            end
        end
        Inventory.UpdateInventory(source)
        return success
    end

    Inventory.RemoveItem = function(source, name, count)
        local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
        if not xPlayer then return false end
        local success
        if GetResourceState("ox_inventory") == "started" then
            success = exports.ox_inventory:RemoveItem(source, name, count) == true
        else
            local before = Inventory.GetItemCount(source, name)
            local result = xPlayer.Functions.RemoveItem(name, count)
            if result == nil then
                -- Some inventories return nothing; confirm the count went down.
                success = (before - Inventory.GetItemCount(source, name)) >= count
            else
                success = result == true
            end
        end
        Inventory.UpdateInventory(source)
        return success
    end

    Inventory.AddWeapon = function(source, name, count, metadata) -- Metadata is not required.
        Inventory.AddItem(source, name, count, metadata)
    end

    Inventory.RemoveWeapon = function(source, name, count)
        Inventory.RemoveItem(source, name, count, metadata)
    end

    Inventory.GetItemCount = function(source, name)
        if GetResourceState("ox_inventory") == "started" then
            return exports.ox_inventory:GetItemCount(source, name) or 0
        end
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