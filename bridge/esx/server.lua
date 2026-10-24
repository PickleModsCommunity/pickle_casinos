if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

-- Route all server callbacks through ox_lib regardless of framework. Newer ESX
-- Legacy versions changed the ESX.RegisterServerCallback signature, which broke
-- every callback registered through it. lib.callback is version-independent.
-- The wrapper preserves the existing (source, cb, ...) handler contract used by
-- the modules: handlers still receive a `cb` they call synchronously, and we
-- forward those returned values back through lib.callback.
function RegisterCallback(name, cb)
    lib.callback.register(name, function(source, ...)
        local results
        cb(source, function(...) results = table.pack(...) end, ...)
        if results then return table.unpack(results, 1, results.n) end
    end)
end

function RegisterUsableItem(...)
    ESX.RegisterUsableItem(...)
end

function ShowNotification(target, text)
	TriggerClientEvent(GetCurrentResourceName()..":showNotification", target, text)
end

function GetIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not xPlayer.identifier then return end
    return xPlayer.identifier
end

function GetSourceFromIdentifier(identifier)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    return xPlayer and xPlayer.source or nil
end

function GetPlayerCharacterName(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return "Unknown Name" end
    return xPlayer.getName()
end

function CanAccessGroup(source, data)
    if not data then return true end
    local pdata = ESX.GetPlayerFromId(source)
    for k,v in pairs(data.jobs) do 
        if (pdata.job.name == k and pdata.job.grade >= v) then return true end
    end
    return false
end 

function CheckPermission(source, permission)
    if permission.ignorePermissions then return true end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    local name = xPlayer.job.name
    local rank = xPlayer.job.grade
    local group = xPlayer.getGroup()
    if permission.jobs[name] and permission.jobs[name] <= rank then 
        return true
    end
    for i=1, #(permission.groups or {}) do 
        if group == permission.groups[i] then 
            return true 
        end
    end
end

-- Cash/black money can be stored two ways: as an inventory item (ox_inventory
-- does this for the accounts in its "inventory:accounts" convar) or as a
-- plain ESX account. When it's an item, the item is the source of truth and
-- ESX's account value is only a synced copy, so we read and remove the item.
local function UsingOxInventory()
    return GetResourceState("ox_inventory") == "started"
end

-- Same rule ESX and ox_inventory use: the accounts listed in the
-- inventory:accounts convar (default ["money"]), plus black_money, which the
-- ESX integration always stores as an item.
local function IsOxAccountItem(accountName)
    if not UsingOxInventory() then return false end
    if accountName == "black_money" then return true end
    local ok, list = pcall(json.decode, GetConvar("inventory:accounts", '["money"]'))
    if not ok or type(list) ~= "table" then return accountName == "money" end
    for _, name in ipairs(list) do
        if name == accountName then return true end
    end
    return false
end

-- Returns the item that holds this currency, or nil if it's an ESX account.
-- Config.FrameworkSettings.cashItem can force cash either way.
local function GetCurrencyItem(currency)
    local account = (currency == "dirty") and "black_money" or "money"
    if currency ~= "dirty" then
        local setting = Config.FrameworkSettings and Config.FrameworkSettings.cashItem
        if setting == false then return nil end
        if type(setting) == "string" and setting ~= "" and setting ~= "auto" then return setting end
    end
    if IsOxAccountItem(account) then return account end
    return nil
end

function AddMoney(source, count, currency)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    local currency = currency or "money"
    local item = GetCurrencyItem(currency)
    if item then
        Inventory.AddItem(source, item, count)
    elseif (currency == "money") then
        xPlayer.addMoney(count)
    elseif (currency == "dirty") then
        xPlayer.addAccountMoney("black_money", count)
    end
    TriggerClientEvent("pickle_casinos:updateMoney", source, GetMoney(source, currency))
end

-- Removes money and returns true only if it was really taken. For item-based
-- cash this is one check-and-remove on the item, so a stale ESX balance can't
-- make a failed removal look successful.
function RemoveMoney(source, count, currency)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    local currency = currency or "money"
    if currency ~= "money" and currency ~= "dirty" then return false end
    local success
    local item = GetCurrencyItem(currency)
    if item then
        local before = Inventory.GetItemCount(source, item) or 0
        local result = Inventory.RemoveItem(source, item, count)
        if result == nil then
            -- A custom inventory returned nothing; confirm the count dropped.
            success = (before - (Inventory.GetItemCount(source, item) or 0)) >= count
        else
            success = result == true
        end
    else
        local before = GetMoney(source, currency)
        local result
        if currency == "money" then
            result = xPlayer.removeMoney(count)
        else
            result = xPlayer.removeAccountMoney("black_money", count)
        end
        if result == false then
            success = false
        else
            -- Older ESX versions return nothing; confirm the balance dropped.
            success = (before - GetMoney(source, currency)) >= count
        end
    end
    TriggerClientEvent("pickle_casinos:updateMoney", source, GetMoney(source, currency))
    return success
end

function GetMoney(source, currency)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return 0 end
    local currency = currency or "money"
    local money = 0
    local item = GetCurrencyItem(currency)
    if item then
        money = Inventory.GetItemCount(source, item) or 0
    elseif (currency == "money") then
        money = xPlayer.getMoney()
    elseif (currency == "dirty") then
        local account = xPlayer.getAccount("black_money")
        money = account and account.money or 0
    end
    TriggerClientEvent("pickle_casinos:updateMoney", source, money)
    return money
end

function GetOwnedVehicleFromPlate(plate)
    local data = MySQL.Sync.fetchAll("SELECT * FROM owned_vehicles WHERE plate=@plate;", {
        ['@plate'] = plate,
    })[1]
    return data and {owner = data.owner} or nil 
end

function AddOwnedVehicle(source, plate, model)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.execute("INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (@owner, @plate, @vehicle);", {
        ['@owner'] = xPlayer.identifier,
        ['@plate'] = plate,
        ['@vehicle'] = json.encode({
            plate = toupper(plate),
            model = joaat(model),
        }),
    })
end

function UpdateVehiclePlate(source, plate, newPlate)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.execute("UPDATE owned_vehicles SET plate=@newPlate WHERE owner=@owner AND plate=@plate;", {
        ['@owner'] = xPlayer.identifier,
        ['@plate'] = plate,
        ['@newPlate'] = newPlate,
    })
end

function GetPlayerJob(source)
    local xPlayer = ESX.GetPlayerFromId(tonumber(source))
    if not xPlayer then return "Unknown Job", "Unknown Grade" end
    return {label = xPlayer.job.label, rank_label = xPlayer.job.grade_label}
end

function GetPlayerJobName(source)
    local xPlayer = ESX.GetPlayerFromId(tonumber(source))
    if not xPlayer or not xPlayer.job then return nil end
    return xPlayer.job.name
end

function GetPlayerJobGrade(source)
    local xPlayer = ESX.GetPlayerFromId(tonumber(source))
    if not xPlayer or not xPlayer.job then return nil end
    return tonumber(xPlayer.job.grade)
end

function SetPlayerJob(source, job, grade)
    local xPlayer = ESX.GetPlayerFromId(tonumber(source))
    if not xPlayer then return end
    xPlayer.setJob(job, grade)
end

function IsPlayerJobBoss(source, jobName)
    if not jobName then return false end
    local xPlayer = ESX.GetPlayerFromId(tonumber(source))
    if not xPlayer or not xPlayer.job then return false end
    if xPlayer.job.name ~= jobName then return false end
    if xPlayer.job.grade_name == "boss" then return true end
    local jobs = ESX.GetJobs and ESX.GetJobs() or nil
    if jobs and jobs[jobName] and jobs[jobName].grades then
        local maxGrade = -1
        for _, g in pairs(jobs[jobName].grades) do
            local lvl = tonumber(g.grade) or -1
            if lvl > maxGrade then maxGrade = lvl end
        end
        if maxGrade >= 0 and tonumber(xPlayer.job.grade) == maxGrade then return true end
    end
    return false
end

function GetEmployees(jobName, cb)
    local employees = {}
    local xPlayers = ESX.GetExtendedPlayers("job", jobName)
    for _, xPlayer in pairs(xPlayers) do
        employees[#employees + 1] = {
            source = xPlayer.source,
            name = xPlayer.getName(),
            grade = xPlayer.job.grade,
            gradeLabel = xPlayer.job.grade_label or ("Grade " .. xPlayer.job.grade),
            online = true,
        }
    end
    if type(cb) == "function" then cb(employees) end
    return employees
end

function GetJobGrades(jobName)
    local job = ESX.GetJobs()
    if not job or not job[jobName] or not job[jobName].grades then return {} end
    local grades = {}
    for _, grade in pairs(job[jobName].grades) do
        grades[#grades + 1] = {
            level = grade.grade,
            label = grade.label or ("Grade " .. grade.grade),
        }
    end
    table.sort(grades, function(a, b) return a.level < b.level end)
    return grades
end

function IsPlayerAdmin(source)
    local source = tonumber(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    local group = xPlayer.getGroup()
    for i=1, #Config.AdminGroups do 
        if group == Config.AdminGroups[i] then
            return true 
        end
        if IsPlayerAceAllowed(source, Config.AdminGroups[i]) then
            return true
        end
    end
    return false
end

function AddSocietyMoney(name, amount)
    TriggerEvent('esx_addonaccount:getSharedAccount', "society_"..name, function(account)
        account.addMoney(amount)
    end)
end

function AddOwnedVehicle(source, model)
    local xPlayer = ESX.GetPlayerFromId(source)
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
    MySQL.Async.execute("INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (@owner, @plate, @vehicle);", {
        ['@owner'] = xPlayer.identifier,
        ['@plate'] = plate,
        ['@vehicle'] = json.encode({
            plate = toupper(plate),
            model = joaat(model),
        }),
    })
end

-- Inventory Fallback

CreateThread(function()
    Wait(100)

    if InitializeInventory then return InitializeInventory() end -- Already loaded through inventory folder.
    
    Inventory = {}

    Inventory.Items = {}
    
    Inventory.Ready = false

    Inventory.CanCarryItem = function(source, name, count)
        local xPlayer = ESX.GetPlayerFromId(source)
        if Config.InventoryLimit then 
            local item = xPlayer.getInventoryItem(name)
            return (item.limit >= item.count + count)
        else 
            return xPlayer.canCarryItem(name, count)
        end
    end

    Inventory.GetInventory = function(source)
        local xPlayer = ESX.GetPlayerFromId(source)
        local items = {}
        local data = xPlayer.getInventory()
        for i=1, #data do 
            local item = data[i]
            if item then
                items[#items + 1] = {
                    name = item.name,
                    label = item.label,
                    count = item.count,
                    weight = item.weight
                }
            end
        end
        return items
    end

    Inventory.UpdateInventory = function(source)
        SetTimeout(1000, function()
            TriggerClientEvent("pickle_casinos:updateInventory", source, Inventory.GetInventory(source))
        end)
    end

    -- AddItem/RemoveItem return true only when the inventory really changed.
    -- With ox_inventory they call it directly (one atomic check-and-change).
    Inventory.AddItem = function(source, name, count, metadata) -- Metadata is not required.
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        local success
        if GetResourceState("ox_inventory") == "started" then
            success = exports.ox_inventory:AddItem(source, name, count, metadata) == true
        else
            local before = Inventory.GetItemCount(source, name)
            xPlayer.addInventoryItem(name, count)
            success = (Inventory.GetItemCount(source, name) - before) >= count
        end
        Inventory.UpdateInventory(source)
        return success
    end

    Inventory.RemoveItem = function(source, name, count)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        local success
        if GetResourceState("ox_inventory") == "started" then
            success = exports.ox_inventory:RemoveItem(source, name, count) == true
        else
            local before = Inventory.GetItemCount(source, name)
            xPlayer.removeInventoryItem(name, count)
            success = (before - Inventory.GetItemCount(source, name)) >= count
        end
        Inventory.UpdateInventory(source)
        return success
    end

    Inventory.AddWeapon = function(source, name, count, metadata) -- Metadata is not required.
        local xPlayer = ESX.GetPlayerFromId(source)
        xPlayer.addWeapon(name, 0)
        Inventory.UpdateInventory(source)
    end

    Inventory.RemoveWeapon = function(source, name, count)
        local xPlayer = ESX.GetPlayerFromId(source)
        xPlayer.removeWeapon(name, 0)
        Inventory.UpdateInventory(source)
    end

    Inventory.GetItemCount = function(source, name)
        if GetResourceState("ox_inventory") == "started" then
            return exports.ox_inventory:GetItemCount(source, name) or 0
        end
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return 0 end
        local item = xPlayer.getInventoryItem(name)
        return item and item.count or 0
    end

    Inventory.HasWeapon = function(source, name, count)
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer.hasWeapon(name)
    end

    RegisterCallback("pickle_casinos:getInventory", function(source, cb)
        cb(Inventory.GetInventory(source))
    end)
    
    if GetResourceState("ox_inventory") == "started" then 
        for item, data in pairs(exports.ox_inventory:Items()) do
            Inventory.Items[item] = {label = data.label}
        end
        Inventory.Ready = true
    elseif GetResourceState("qs-inventory") == "started" then 
        for item, data in pairs(exports['qs-inventory']:GetItemList()) do
            Inventory.Items[item] = {label = data.label}
        end
        Inventory.Ready = true
    else
        MySQL.ready(function() 
            MySQL.Async.fetchAll("SELECT * FROM items;", {}, function(results) 
                for i=1, #results do 
                    Inventory.Items[results[i].name] = {label = results[i].label}
                end
                Inventory.Ready = true
            end)
        end)
    end
end)