-- Lucky Ticket: cumulative-wager-based item rewards + lucky wheel gating helpers.
-- See Config.LuckyTicket in config.lua.

LuckyTicketProgress = LuckyTicketProgress or {} -- in-memory cache: [identifier] = { wager_total, tickets_earned, source }

local function getCfg()
    return Config and Config.LuckyTicket or nil
end

local function getItemName()
    local cfg = getCfg()
    return (cfg and cfg.item) or "lucky_ticket"
end

-- Callbacks waiting on an in-flight DB load, keyed by identifier. Without this,
-- two wagers before the first load finished would each load (and later save)
-- their own copy of the row.
local PendingLoads = {}

local function loadProgress(identifier, cb)
    if LuckyTicketProgress[identifier] then
        cb(LuckyTicketProgress[identifier])
        return
    end
    if PendingLoads[identifier] then
        table.insert(PendingLoads[identifier], cb)
        return
    end
    PendingLoads[identifier] = { cb }
    MySQL.Async.fetchAll("SELECT wager_total, tickets_earned FROM `pickle_casino_ticket_progress` WHERE identifier = ?", { identifier }, function(rows)
        local row = rows and rows[1]
        local entry = LuckyTicketProgress[identifier] or {
            wager_total = (row and tonumber(row.wager_total)) or 0,
            tickets_earned = (row and tonumber(row.tickets_earned)) or 0,
        }
        LuckyTicketProgress[identifier] = entry
        local waiting = PendingLoads[identifier] or {}
        PendingLoads[identifier] = nil
        for _, waitingCb in ipairs(waiting) do
            waitingCb(entry)
        end
    end)
end

local function saveProgress(identifier, entry)
    MySQL.Async.execute([[
        INSERT INTO `pickle_casino_ticket_progress` (identifier, wager_total, tickets_earned)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE wager_total = VALUES(wager_total), tickets_earned = VALUES(tickets_earned)
    ]], { identifier, entry.wager_total, entry.tickets_earned })
end

function RegisterLuckyTicketWager(source, gameKey, chips)
    local cfg = getCfg()
    if not cfg or cfg.enabled == false then return end
    if not gameKey or not cfg.eligibleGames or cfg.eligibleGames[gameKey] ~= true then return end
    chips = math.floor(math.max(0, tonumber(chips) or 0))
    if chips <= 0 then return end
    local identifier = GetIdentifier(source)
    if not identifier or identifier == "" then return end
    local perTicket = tonumber(cfg.chipsPerTicket) or 0
    if perTicket <= 0 then return end

    loadProgress(identifier, function(entry)
        entry.wager_total = (entry.wager_total or 0) + chips
        local totalEarned = math.floor(entry.wager_total / perTicket)
        local newTickets = totalEarned - (entry.tickets_earned or 0)
        if newTickets > 0 then
            local itemName = getItemName()
            Inventory.AddItem(source, itemName, newTickets)
            entry.tickets_earned = totalEarned
            if ShowNotification then
                ShowNotification(source, _L("ticket_earned", newTickets))
            end
        end
        saveProgress(identifier, entry)
    end)
end

function ConsumeLuckyTicket(source)
    local itemName = getItemName()
    local count = 0
    if Inventory and Inventory.GetItemCount then
        count = Inventory.GetItemCount(source, itemName) or 0
    end
    if (count or 0) < 1 then return false end
    Inventory.RemoveItem(source, itemName, 1)
    return (Inventory.GetItemCount(source, itemName) or 0) < count
end

function HasLuckyTicket(source)
    local itemName = getItemName()
    if Inventory and Inventory.GetItemCount then
        return (Inventory.GetItemCount(source, itemName) or 0) >= 1
    end
    return false
end

-- Admin command fallback to toggle a wheel entity's costsTickets flag.
-- Usage: /setwheelticket [casinoId] [entityId] [true|false]
RegisterCommand("setwheelticket", function(source, args)
    if source == 0 then
        -- console allowed
    elseif IsPlayerAdmin and not IsPlayerAdmin(source) then
        return
    end
    local casinoId = tonumber(args[1])
    local entityId = args[2]
    local flag = args[3]
    if not casinoId or not entityId or not flag then
        if source > 0 and ShowNotification then
            ShowNotification(source, "Usage: /setwheelticket [casinoId] [entityId] [true|false]")
        else
            print("Usage: setwheelticket [casinoId] [entityId] [true|false]")
        end
        return
    end
    local bool = (flag == "true" or flag == "1" or flag == "yes")
    local casino = Casinos and Casinos[casinoId]
    if not casino then
        print("^1[lucky_ticket] Casino not found: " .. tostring(casinoId)) return
    end
    local entity = GetCasinoEntity and GetCasinoEntity(casinoId, entityId)
    if not entity or entity.type ~= "luckywheel" then
        print("^1[lucky_ticket] Lucky wheel entity not found: " .. tostring(entityId)) return
    end
    entity.settings = entity.settings or {}
    entity.settings.costsTickets = bool
    if UpdateCasinoEntitiesSQL then UpdateCasinoEntitiesSQL(casinoId) end
    local msg = ("Lucky wheel %s costsTickets set to %s"):format(tostring(entityId), tostring(bool))
    if source > 0 and ShowNotification then
        ShowNotification(source, msg)
    end
    print("^2[lucky_ticket] " .. msg)
end, false)

-- Clean up cache on disconnect (final save already happens on every update).
AddEventHandler('playerDropped', function()
    local src = source
    local identifier = GetIdentifier and GetIdentifier(src) or nil
    if identifier and LuckyTicketProgress[identifier] then
        local entry = LuckyTicketProgress[identifier]
        saveProgress(identifier, entry)
        LuckyTicketProgress[identifier] = nil
    end
end)
