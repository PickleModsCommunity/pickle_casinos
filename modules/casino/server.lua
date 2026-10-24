CurrentPlayers = {}
PlayerCooldowns = {}

local function SanitizeCasinoLabel(value)
    if type(value) ~= "string" then return "INVALID_LABEL" end
    value = value:gsub("[%c]", "")
    local length = utf8.len(value)
    if not length then return "INVALID_LABEL" end
    if length > 64 then value = value:sub(1, utf8.offset(value, 65) - 1) end
    if value == "" or value == PERSONAL_CASINOS_LABEL then return "INVALID_LABEL" end
    return value
end

function GetCasino(casinoId)
    return Casinos[casinoId]
end

exports("GetCasino", GetCasino)

function EnsureOwnerInfo(owner_info)
    if not owner_info then return nil end
    if owner_info.identifier and not owner_info.type then
        owner_info.type = "player"
    end
    return owner_info
end

function IsCasinoOwned(casinoId)
    local casino = Casinos[casinoId]
    if not casino then return false end
    local oi = casino.owner_info
    if not oi then return false end
    if oi.type == "job" and oi.job then return true end
    if oi.identifier and oi.identifier ~= "none" then return true end
    return false
end

function IsCasinoPersonalCasinos(casinoId)
    local casino = Casinos[casinoId]
    if not casino then return false end
    if casino.settings.label == PERSONAL_CASINOS_LABEL then return true end
    return false
end

function CanManageCasino(source, casinoId)
    if IsPlayerAdmin(source) then return true end
    if not casinoId then return false end
    local casino = Casinos[casinoId]
    if not casino then return false end
    local oi = casino.owner_info
    if not oi then return false end
    if oi.type == "job" then
        if not oi.job then return false end
        if type(IsPlayerJobBoss) ~= "function" then return false end
        return IsPlayerJobBoss(source, oi.job) and true or false
    end
    if oi.identifier and oi.identifier == GetIdentifier(source) then return true end
    return false
end

function InitializeCasinoEntity(casinoId, entity, dataOnly)
    entity.settings = EnsureGameSettings(entity.type, entity.settings)
    if entity.type == "blackjack" then
        entity = InitializeBlackjackEntity(casinoId, entity, dataOnly)
    elseif entity.type == "roulette" then
        entity = InitializeRouletteEntity(casinoId, entity, dataOnly)
    elseif entity.type == "thunder_roulette" then
        entity = InitializeThunderRouletteEntity(casinoId, entity, dataOnly)
    elseif entity.type == "baccarat" then
        entity = InitializeBaccaratEntity(casinoId, entity, dataOnly)
    elseif entity.type == "slot" then
        entity = InitializeSlotEntity(casinoId, entity, dataOnly)
    elseif entity.type == "poker" then
        entity = InitializePokerEntity(casinoId, entity, dataOnly)
    elseif entity.type == "wheel" then
        entity = InitializeWheelEntity(casinoId, entity, dataOnly)
    elseif entity.type == "luckywheel" then
        entity = InitializeLuckyWheelEntity(casinoId, entity, dataOnly)
    elseif entity.type == "horseracing" then
        entity = InitializeHorseRacingEntity(casinoId, entity, dataOnly)
    elseif entity.type == "cashier" then
        entity = InitializeCashierEntity(casinoId, entity, dataOnly)
    elseif entity.type == "store" then
        entity = InitializeStoreEntity(casinoId, entity, dataOnly)
    end
    return entity
end

function InitializeCasinoEntities(casinoId, entities)
    for i=1, #entities do
        entities[i] = InitializeCasinoEntity(casinoId, entities[i])
    end
    return entities
end

function EnsureCasinoSettings(settings)
    local newSettings = {}
    for k,v in pairs(settings) do
        newSettings[k] = v
    end
    if not newSettings.label then newSettings.label = "UNKNOWN_LABEL" end
    if not newSettings.location then newSettings.location = { coords = vector3(0, 0, 0), rotation = vector3(0, 0, 0) } end
    newSettings.location.coords = vector3(newSettings.location.coords.x, newSettings.location.coords.y, newSettings.location.coords.z)
    newSettings.location.rotation = vector3(newSettings.location.rotation.x, newSettings.location.rotation.y, newSettings.location.rotation.z)
    if not newSettings.chipItem then newSettings.chipItem = "UNKNOWN_CHIP_ITEM" end
    if not newSettings.blipEnabled then newSettings.blipEnabled = false end
    if not newSettings.isOpen then newSettings.isOpen = false end
    if not newSettings.cashEnabled then newSettings.cashEnabled = false end
    if not newSettings.markedEnabled then newSettings.markedEnabled = false end
    local rateLimits = Config.ExchangeRateLimits or { min = 1, max = 100 }
    newSettings.moneyExchangeRate = SanitizeInt(newSettings.moneyExchangeRate, rateLimits.min, rateLimits.max) or math.min(100, rateLimits.max)
    newSettings.dirtyExchangeRate = SanitizeInt(newSettings.dirtyExchangeRate, rateLimits.min, rateLimits.max) or math.min(75, rateLimits.max)
    newSettings.vipPrice = SanitizeInt(newSettings.vipPrice, 0) or 1000
    return newSettings
end

function EnsureCasinoTransactions(transactions)
    local expireTime = os.time() - (86400 * 7)
    local newTransactions = {}
    for i=1, #transactions do
        local transaction = transactions[i]
        if transaction and transaction.datetime then
            if transaction.datetime > expireTime then
                table.insert(newTransactions, transaction)
            end
        end
    end
    return newTransactions
end

function RegisterCasino(id, data, dontSync)
    Casinos[id] = {
        id = id,
        balance = data.balance or 0,
        marked_balance = data.marked_balance or 0,
        owner_info = EnsureOwnerInfo(data.owner_info) or nil,
        vip_players = data.vip_players or {},
        transactions = EnsureCasinoTransactions(data.transactions or {}),
        settings = EnsureCasinoSettings(data.settings),
        entities = InitializeCasinoEntities(id, data.entities or {})
    }
    if dontSync then return end
    TriggerClientEvent("pickle_casinos:registerCasino", -1, id, GetPublicCasino(Casinos[id]))
end

function JoinCasinoEntity(source, casinoId, entityId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    if entity.type == "blackjack" then
        JoinBlackjackEntity(source, casinoId, entityId)
    elseif entity.type == "roulette" then
        JoinRouletteEntity(source, casinoId, entityId)
    elseif entity.type == "baccarat" then
        JoinBaccaratEntity(source, casinoId, entityId)
    end
end

function GenerateDeck()
    local deck = {}
    local classes = {"spd", "club", "dia", "hrt"}
    local values = {"ace", "02", "03", "04", "05", "06", "07", "08", "09", "10", "jack", "queen", "king"}
    for i=1, #classes do
        for j=1, #values do
            table.insert(deck, { class = classes[i], value = values[j] })
        end
    end
    -- Randomize the deck
    for i = #deck, 2, -1 do
        local j = math.random(1, i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

function GenerateCard(deck) 
    local classes = {"spd", "club", "dia", "hrt"}
    local values = {"ace", "02", "03", "04", "05", "06", "07", "08", "09", "10", "jack", "queen", "king"}
    -- return { class = classes[1], value = values[6] }
    if deck then
        local index = math.random(1, #deck)
        local card = deck[index]
        table.remove(deck, index)
        return card, deck
    else
        return { class = classes[math.random(1, #classes)], value = values[math.random(1, #values)] }
    end
end

function GetCasinoEntity(casinoId, entityId)
    local casino = Casinos[casinoId]
    if not casino then return end
    for i=1, #casino.entities do
        if casino.entities[i].id == entityId then
            return casino.entities[i]
        end
    end
end

exports("GetCasinoEntity", GetCasinoEntity)

function SendCasinoEntityUpdate(casinoId, entityId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    TriggerClientEvent("pickle_casinos:updateCasinoEntity", -1, casinoId, GetPublicCasinoEntity(entity))
end

function GenerateEntityId(casinoId)
    local casino = Casinos[casinoId]
    if not casino then return end
    local entityId
    repeat
        entityId = math.random(1, 9999999) .. "_" .. math.random(1, 9999999)
    until not GetCasinoEntity(casinoId, entityId)
    return entityId
end

CASINO_ENTITY_TYPES = {
    blackjack = true, roulette = true, thunder_roulette = true, baccarat = true, slot = true,
    poker = true, wheel = true, luckywheel = true, horseracing = true, cashier = true, store = true,
}

-- Settings keys an owner may change through updateCasinoEntitySetting, per entity type.
local WAGER_GAMES = { blackjack = true, roulette = true, thunder_roulette = true, baccarat = true, slot = true, wheel = true, horseracing = true }
local TABLE_GAMES = { blackjack = true, roulette = true, thunder_roulette = true, baccarat = true, poker = true }
local TYPE_SETTING_KEYS = {
    poker = { smallBlind = true, bigBlind = true },
    slot = { game = true },
    cashier = { dealerModel = true },
    store = { dealerModel = true, store = true },
    luckywheel = { wheelModel = true, spinPrice = true, costsTickets = true, vehicleLocation = true },
}

function IsEntitySettingAllowed(entityType, key)
    if type(key) ~= "string" then return false end
    if key == "location" or key == "vip" then return true end
    if key == "maxWager" and WAGER_GAMES[entityType] then return true end
    if (key == "tableModel" or key == "dealerModel") and TABLE_GAMES[entityType] then return true end
    local keys = TYPE_SETTING_KEYS[entityType]
    return keys ~= nil and keys[key] == true
end

local function SanitizeNumber(value, fallback)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return fallback end
    return value
end

local function SanitizeVector(v)
    local t = type(v)
    if t ~= "table" and t ~= "vector3" and t ~= "vector4" then return vector3(0, 0, 0) end
    return vector3(SanitizeNumber(v.x, 0), SanitizeNumber(v.y, 0), SanitizeNumber(v.z, 0))
end

function SanitizeLocation(location)
    if type(location) ~= "table" then return { coords = vector3(0, 0, 0), rotation = vector3(0, 0, 0) } end
    return { coords = SanitizeVector(location.coords), rotation = SanitizeVector(location.rotation) }
end

local function SanitizeModel(model)
    if type(model) == "number" and model == math.floor(model) then return model end
    return nil
end

local function GetDefaultSlotGame()
    local keys = {}
    for k in pairs(Config.Slots or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys[1]
end

-- Every value here can come from a client (createCasinoEntity /
-- updateCasinoEntitySetting), so each one is type- and range-checked.
function EnsureGameSettings(entityType, settings)
    settings = type(settings) == "table" and settings or {}
    local defaultSettings = {
        location = SanitizeLocation(settings.location),
        vip = settings.vip and true or false,
    }
    if WAGER_GAMES[entityType] then
        -- At least 100 so the minimum bet (maxWager / 100) is a whole chip.
        local maxWager = SanitizeInt(settings.maxWager, 1)
        maxWager = maxWager and math.max(100, maxWager) or 1000
        if Config.MaxWager and maxWager > Config.MaxWager then
            maxWager = math.max(100, math.floor(Config.MaxWager))
        end
        defaultSettings["maxWager"] = maxWager
    end
    if TABLE_GAMES[entityType] then
        defaultSettings["tableModel"] = SanitizeModel(settings.tableModel)
        defaultSettings["dealerModel"] = SanitizeModel(settings.dealerModel)
    end
    if entityType == "cashier" or entityType == "store" then
        defaultSettings["dealerModel"] = SanitizeModel(settings.dealerModel)
    end
    if entityType == "luckywheel" then
        defaultSettings["wheelModel"] = SanitizeModel(settings.wheelModel)
        defaultSettings["spinPrice"] = SanitizeInt(settings.spinPrice, 0) or 0
        defaultSettings["costsTickets"] = settings.costsTickets and true or false
        defaultSettings["vehicleLocation"] = SanitizeLocation(settings.vehicleLocation)
    end
    if entityType == "store" then
        local stores = Config.CreatorOptions and Config.CreatorOptions.stores or {}
        defaultSettings["store"] = SanitizeInt(settings.store, 1, math.max(1, #stores)) or 1
    end
    if entityType == "slot" then
        defaultSettings["game"] = (type(settings.game) == "string" and Config.Slots[settings.game]) and settings.game or GetDefaultSlotGame()
    end
    if entityType == "poker" then
        local maxBlind = math.max(2, math.floor((Config.MaxWager or 1000000) / 100))
        local smallBlind = SanitizeInt(settings.smallBlind, 1) or 10
        smallBlind = math.min(smallBlind, maxBlind)
        local bigBlind = SanitizeInt(settings.bigBlind, 1) or (smallBlind * 2)
        bigBlind = math.min(math.max(bigBlind, smallBlind), maxBlind)
        defaultSettings["smallBlind"] = smallBlind
        defaultSettings["bigBlind"] = bigBlind
    end
    return defaultSettings
end

-- True while anyone is seated, playing or spinning. Changing settings
-- re-initialises the entity, which would wipe live seats and escrow. (Stage is
-- not used: tables keep their last stage after everyone has left.)
function IsCasinoEntityInUse(entity)
    if not entity then return false end
    if entity.seats then
        for _, seat in pairs(entity.seats) do
            if seat and seat.source and seat.source ~= 0 then return true end
        end
    end
    if entity.players and next(entity.players) ~= nil then return true end
    if entity.currentPlayer or entity.spinner then return true end
    return false
end

-- Fields that must never leave the server.
local PRIVATE_ENTITY_FIELDS = { sectionIndex = true, spinner = true, pendingSpin = true, players = true }

-- Client-safe copy of an entity: hides poker hole cards and server-only state.
function GetPublicCasinoEntity(entity)
    if type(entity) ~= "table" then return entity end
    local out = {}
    for k, v in pairs(entity) do
        if not PRIVATE_ENTITY_FIELDS[k] then out[k] = v end
    end
    if entity.type == "poker" and type(entity.seats) == "table" then
        local seats = {}
        for i, seat in pairs(entity.seats) do
            seats[i] = GetObfuscuatedSeat(seat)
        end
        out.seats = seats
    end
    return out
end

-- Client-safe copy of a casino. VIP membership lists (identifiers) stay server-side.
function GetPublicCasino(casino)
    if type(casino) ~= "table" then return casino end
    local entities = {}
    for i = 1, #(casino.entities or {}) do
        entities[i] = GetPublicCasinoEntity(casino.entities[i])
    end
    return {
        id = casino.id,
        balance = casino.balance,
        marked_balance = casino.marked_balance,
        owner_info = casino.owner_info,
        vip_players = {},
        transactions = {},
        settings = casino.settings,
        entities = entities,
    }
end

function GetPublicCasinos()
    local out = {}
    for id, casino in pairs(Casinos) do
        out[id] = GetPublicCasino(casino)
    end
    return out
end

function UpdateCasinoEntitiesSQL(casinoId)
    local entities = {}
    for i=1, #Casinos[casinoId].entities do
        table.insert(entities, {
            id = Casinos[casinoId].entities[i].id,
            type = Casinos[casinoId].entities[i].type,
            settings = Casinos[casinoId].entities[i].settings,
            owner_info = Casinos[casinoId].entities[i].owner_info,
        })
    end
    MySQL.Async.execute('UPDATE `pickle_casinos` SET entities = ? WHERE id = ?', {json.encode(entities), casinoId})
end

function GetPlayerCasinoInfo(source, casinoId)
    local casino = Casinos[casinoId]
    if not casino then return false end
    local identifier = GetIdentifier(source)
    for i=1, #casino.vip_players do
        if casino.vip_players[i].identifier == identifier then
            return casino.vip_players[i], i
        end
    end
    return { identifier = identifier, name = GetPlayerCharacterName(source) }, nil
end

function UpdateCasinoPlayerInfo(casinoId)
    local casino = Casinos[casinoId]
    if not casino then return end
    MySQL.Async.execute('UPDATE `pickle_casinos` SET vip_players = ? WHERE id = ?', {json.encode(casino.vip_players), casinoId})
end

function IsPlayerCasinoVIP(source, casinoId)
    local casino = Casinos[casinoId]
    if not casino then return false end
    local player = GetPlayerCasinoInfo(source, casinoId)
    if not player or not player.startTime then return false end
    local expireTime = Config.Casinos.vipExpireTime or 0
    if expireTime > 0 and (player.startTime + expireTime) < os.time() then return false end
    return true
end

-- Sources currently viewing a casino's management UI, keyed by casinoId.
-- We push new-transaction events only to these, instead of broadcasting the
-- full history to every connected player like the old flow did.
ManagementViewers = ManagementViewers or {}

local function GetManagementViewers(casinoId)
    local viewers = ManagementViewers[casinoId] or {}
    for src in pairs(viewers) do
        if not IsPlayerOnline(src) or not CanManageCasino(src, casinoId) then
            viewers[src] = nil
        end
    end
    return viewers
end

function RegisterManagementViewer(source, casinoId)
    if not casinoId then return end
    ManagementViewers[casinoId] = ManagementViewers[casinoId] or {}
    ManagementViewers[casinoId][source] = true
end

function UnregisterManagementViewer(source, casinoId)
    if casinoId then
        if ManagementViewers[casinoId] then
            ManagementViewers[casinoId][source] = nil
        end
        return
    end
    -- No casino specified — sweep the player out of every casino (used on
    -- disconnect so we don't leak dangling sources).
    for cid, viewers in pairs(ManagementViewers) do
        viewers[source] = nil
    end
end

AddEventHandler("pickle_casinos:playerUnloaded", function(source)
    UnregisterManagementViewer(source)
end)

-- Gameplay rounds (slots/blackjack/poker/etc) fire Start/EndCasinoGameplayTransaction
-- via core/server.lua. The previous build TriggerEvent'd those names but had no
-- listener, so the casino balance never moved and nothing got logged when a
-- player won or lost — which is exactly the bug reported. Track each round
-- between start and end so we can compute the net P/L for the house in one
-- log entry.
local PendingGameplayTransactions = {}

AddEventHandler("pickle_casinos:gameplay:startTransaction", function(id, source, casinoId, _entityId, gameType, wagerAmount)
    wagerAmount = tonumber(wagerAmount) or 0
    if wagerAmount <= 0 then return end
    PendingGameplayTransactions[id] = {
        source     = source,
        casinoId   = casinoId,
        gameType   = gameType,
        wagerAmount = wagerAmount,
    }
    -- NOTE: We intentionally do NOT touch casino.balance here. The real-money
    -- inflow was already accounted for when the player purchased chips at the
    -- cashier (buy handler). Crediting the balance again here would double-count
    -- the revenue before any actual cash has moved.
end)

AddEventHandler("pickle_casinos:gameplay:endTransaction", function(id, source, casinoId, _entityId, gameType, winAmount)
    winAmount = tonumber(winAmount) or 0
    local pending = PendingGameplayTransactions[id]
    PendingGameplayTransactions[id] = nil
    local wager = (pending and pending.wagerAmount) or 0
    -- NOTE: We intentionally do NOT touch casino.balance here. The real-money
    -- outflow is accounted for when the player redeems chips at the cashier
    -- (sell handler). Debiting the balance here would cause a double-debit:
    -- once when winning chips are issued, and again when those chips are cashed
    -- out — which is exactly the bug this fix resolves.
    --
    -- Net P/L for the house from this round. One log row, not two, so high-
    -- volume games (slots) don't flood the transactions list.
    local net = wager - winAmount
    if net > 0 then
        AddCasinoTransaction(source, casinoId, gameType .. "_deposit", net)
    elseif net < 0 then
        AddCasinoTransaction(source, casinoId, gameType .. "_withdraw", -net)
    end
end)

function AddCasinoTransaction(source, casinoId, transactionType, amount)
    local casino = Casinos[casinoId]
    if not casino then return end
    local transaction = {
        origin = {
            identifier = GetIdentifier(source),
            name = GetPlayerCharacterName(source),
        },
        type = transactionType,
        amount = amount,
        datetime = os.time(),
    }
    local insertedId = MySQL.insert.await(
        "INSERT INTO `pickle_casino_transactions` (`casino_id`, `identifier`, `name`, `type`, `amount`, `datetime`) VALUES (?, ?, ?, ?, ?, ?)",
        {
            casinoId,
            transaction.origin.identifier or "",
            transaction.origin.name or "",
            transaction.type,
            transaction.amount,
            transaction.datetime,
        }
    )
    transaction.id = insertedId
    -- Targeted push: only sources currently in the management UI for this
    -- casino need to know. Everyone else doesn't care and shouldn't pay the
    -- bandwidth.
    for src, _ in pairs(GetManagementViewers(casinoId)) do
        TriggerClientEvent("pickle_casinos:newCasinoTransaction", src, casinoId, transaction)
    end
end

function GetCasinoChips(source, casinoId)
    local casino = Casinos[casinoId]
    if not source then return 0 end
    if not casino then return 0 end
    if casino.settings.label == PERSONAL_CASINOS_LABEL then 
        return GetMoney(source)
    end
    local chips = Inventory.GetItemCount(source, casino.settings.chipItem) or 0
    return chips
end

local QueuePendingRefund

function AddCasinoChips(source, casinoId, amount, skipPending)
    local casino = Casinos[casinoId]
    if not casino then return false end
    -- Payouts like 2.5x or 0.95x can be fractional; pay whole chips instead of
    -- leaving the rounding to the inventory.
    amount = tonumber(amount)
    if not amount or amount ~= amount or amount == math.huge then return false end
    amount = math.floor(amount)
    if amount <= 0 then return false end
    local personal = casino.settings.label == PERSONAL_CASINOS_LABEL
    if IsPlayerOnline(source) then
        local paid
        if personal then paid = AddMoney(source, amount)
        else paid = Inventory.AddItem(source, casino.settings.chipItem, amount) end
        if paid ~= false then return true end
    end
    if not skipPending then
        return QueuePendingRefund(source, casinoId, not personal and casino.settings.chipItem or nil, amount)
    end
    return false
end

-- Removes chips and returns true only if the full amount was actually taken.
-- Amounts must be positive integers: inventories round fractional counts.
function RemoveCasinoChips(source, casinoId, amount)
    local casino = Casinos[casinoId]
    if not casino then return false end
    amount = SanitizeInt(amount, 1)
    if not amount then return false end
    if casino.settings.label == PERSONAL_CASINOS_LABEL then
        return TryRemoveMoney(source, amount)
    end
    return TryRemoveItem(source, casino.settings.chipItem, amount)
end

-- Removes an item and returns true only if the full amount was actually taken.
-- The bridges return the inventory's own success value (a single atomic
-- check-and-remove with ox_inventory); the before/after comparison is only a
-- fallback for custom bridges that return nothing.
function TryRemoveItem(source, item, amount)
    amount = SanitizeInt(amount, 1)
    if not amount then return false end
    local before = Inventory.GetItemCount(source, item) or 0
    if before < amount then return false end
    local result = Inventory.RemoveItem(source, item, amount)
    if result ~= nil then return result == true end
    return (before - (Inventory.GetItemCount(source, item) or 0)) >= amount
end

-- Removes money and returns true only if the full amount was actually taken.
-- Never grant anything paid for with money unless this returned true.
function TryRemoveMoney(source, amount, currency)
    amount = SanitizeInt(amount, 1)
    if not amount then return false end
    local before = GetMoney(source, currency) or 0
    if before < amount then return false end
    local result = RemoveMoney(source, amount, currency)
    if result ~= nil then return result == true end
    return (before - (GetMoney(source, currency) or 0)) >= amount
end

-- Serialises economy actions per player. Several requests queued during a
-- network drop arrive together; handlers that wait on the database could
-- otherwise interleave. Returns false (and runs nothing) if one is in progress.
local EconomyLocks = {}

function WithEconomyLock(source, fn)
    if EconomyLocks[source] then return false end
    EconomyLocks[source] = true
    local ok, err = pcall(fn)
    EconomyLocks[source] = nil
    if not ok then
        print(("^1[pickle_casinos] economy action error for %s: %s^0"):format(tostring(source), tostring(err)))
    end
    return true
end

AddEventHandler("pickle_casinos:playerUnloaded", function(source)
    EconomyLocks[source] = nil
end)

-- Identifiers of players who have interacted with the casino, kept briefly
-- after they drop so disconnect handlers can still credit them.
local KnownIdentifiers = {}

function RememberPlayerIdentifier(source)
    local identifier = GetIdentifier(source)
    if identifier and KnownIdentifiers[source] and KnownIdentifiers[source] ~= identifier then
        CleanupCasinoPlayer(source, KnownIdentifiers[source])
    end
    if identifier then KnownIdentifiers[source] = identifier end
    return identifier
end

function GetKnownIdentifier(source)
    return CasinoUnloadingIdentifiers[source] or GetIdentifier(source) or KnownIdentifiers[source]
end

AddEventHandler("pickle_casinos:playerUnloaded", function(source)
    local src = source
    -- Other playerDropped handlers may still need it; forget it shortly after.
    local identifier = KnownIdentifiers[src]
    SetTimeout(10000, function()
        if KnownIdentifiers[src] == identifier and not GetIdentifier(src) then KnownIdentifiers[src] = nil end
    end)
end)

QueuePendingRefund = function(source, casinoId, item, amount, identifier)
    identifier = identifier or GetKnownIdentifier(source)
    if not identifier then
        print(("^1[pickle_casinos] Could not store a refund of %s for player %s: identifier unknown.^0"):format(tostring(amount), tostring(source)))
        return
    end
    MySQL.insert("INSERT INTO `pickle_casino_pending_refunds` (`identifier`, `casino_id`, `item`, `amount`) VALUES (?, ?, ?, ?)", {
        identifier, casinoId or 0, item, amount
    })
    return true
end

-- Gives chips back now if the player is still connected, otherwise stores
-- them and pays them out the next time the character loads. Pass `dropped`
-- from playerDropped handlers, where the player may still look online.
function RefundCasinoChips(source, casinoId, amount, dropped, identifier)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not Casinos[casinoId] then return end
    if not dropped and IsPlayerOnline(source) then
        return AddCasinoChips(source, casinoId, amount)
    end
    return QueuePendingRefund(source, casinoId, Casinos[casinoId].settings.label ~= PERSONAL_CASINOS_LABEL and Casinos[casinoId].settings.chipItem or nil, amount, identifier)
end

-- Same as RefundCasinoChips, for a plain inventory item (e.g. a lucky ticket).
function RefundCasinoItem(source, item, amount, dropped, identifier)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or type(item) ~= "string" then return end
    if not dropped and IsPlayerOnline(source) and Inventory.AddItem(source, item, amount) ~= false then
        return true
    end
    return QueuePendingRefund(source, 0, item, amount, identifier)
end

-- Delete claims each row once; a failed inventory grant is stored again for retry.
local RefundPayouts = {}
function PayPendingRefunds(source)
    local identifier = GetIdentifier(source)
    if not identifier or RefundPayouts[identifier] then return end
    local session = GetCasinoPlayerSession(source)
    RefundPayouts[identifier] = true
    local ok, err = pcall(function()
        local rows = MySQL.query.await("SELECT `id`, `casino_id`, `item`, `amount` FROM `pickle_casino_pending_refunds` WHERE `identifier` = ?", { identifier }) or {}
        for _, row in ipairs(rows) do
            if not IsCasinoPlayerSession(source, session) then break end
            local amount = math.floor(tonumber(row.amount) or 0)
            local casinoId = tonumber(row.casino_id)
            if amount > 0 and (row.item ~= nil or Casinos[casinoId] ~= nil) then
                local deleted = MySQL.update.await("DELETE FROM `pickle_casino_pending_refunds` WHERE `id` = ?", { row.id })
                if deleted and deleted > 0 then
                    local paid = false
                    if IsCasinoPlayerSession(source, session) then
                        local granted, result = pcall(function()
                            if row.item then return Inventory.AddItem(source, row.item, amount) end
                            return AddCasinoChips(source, casinoId, amount, true)
                        end)
                        paid = granted and result ~= false
                        if not granted then print("^1[pickle_casinos] refund grant failed: " .. tostring(result) .. "^0") end
                    end
                    if paid then
                        ShowNotification(source, _L("pending_refund_paid", NumberWithCommas(amount, true)))
                    else
                        QueuePendingRefund(source, casinoId, row.item, amount, identifier)
                    end
                end
            end
        end
    end)
    RefundPayouts[identifier] = nil
    if not ok then print("^1[pickle_casinos] refund payout failed: " .. tostring(err) .. "^0") end
end

-- Returns true if the inventory knows this item, false if it doesn't, or nil
-- if the item list hasn't loaded yet.
function DoesInventoryItemExist(name)
    if type(name) ~= "string" or name == "" then return false end
    if GetResourceState("ox_inventory") == "started" then
        local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
        if ok then return item ~= nil end
    end
    if not Inventory or not Inventory.Items or not Inventory.Ready or next(Inventory.Items) == nil then return nil end
    return Inventory.Items[name] ~= nil
end

-- Returns the casino (other than `exceptCasinoId`) that already uses `item` as its chip.
function GetCasinoUsingChipItem(item, exceptCasinoId)
    for id, casino in pairs(Casinos) do
        if id ~= exceptCasinoId and casino.settings.label ~= PERSONAL_CASINOS_LABEL and casino.settings.chipItem == item then
            return casino
        end
    end
end

-- Validates a chip item chosen by an admin and tells them what's wrong.
-- Returns the cleaned item name, or nil if it can't be used.
function ValidateChipItem(source, item, casinoId)
    if type(item) ~= "string" then
        ShowNotification(source, _L("chip_item_invalid"))
        return nil
    end
    item = item:match("^%s*(.-)%s*$")
    if item == "" or #item > 100 then
        ShowNotification(source, _L("chip_item_invalid"))
        return nil
    end
    local exists = DoesInventoryItemExist(item)
    if exists == nil then
        ShowNotification(source, _L("chip_item_unverified"))
        return nil
    elseif not exists then
        ShowNotification(source, _L("chip_item_not_found", item))
        return nil
    end
    local other = GetCasinoUsingChipItem(item, casinoId)
    if other then
        ShowNotification(source, _L("chip_item_in_use", item, other.settings.label or tostring(other.id)))
        return nil
    end
    return item
end

-- Console warnings for existing casinos whose chip item is missing from the
-- inventory or shared with another casino. Runs once the item list is loaded.
function WarnAboutCasinoChipItems()
    CreateThread(function()
        for _ = 1, 60 do
            if DoesInventoryItemExist("__pickle_casinos_probe__") ~= nil then break end
            Wait(500)
        end
        local seen = {}
        for id, casino in pairs(Casinos) do
            local item = casino.settings.chipItem
            if casino.settings.label ~= PERSONAL_CASINOS_LABEL then
                if DoesInventoryItemExist(item) == false then
                    print(("^3[pickle_casinos] Casino '%s' (ID %s) uses chip item '%s', which doesn't exist in your inventory. Add the item or change the casino's chip item.^0"):format(tostring(casino.settings.label), tostring(id), tostring(item)))
                end
                if seen[item] then
                    print(("^3[pickle_casinos] Casinos %s and %s share the chip item '%s'. Give each casino its own chip item.^0"):format(tostring(seen[item]), tostring(id), tostring(item)))
                else
                    seen[item] = id
                end
            end
        end
    end)
end

-- Shared guard for player-facing interactions with a casino entity: the casino
-- must exist and be open (managers excepted), the entity must have the expected
-- type, VIP-only entities require VIP, and the player must be near it.
function CanUseCasinoEntity(source, casinoId, entityId, expectedType)
    local casino = Casinos[casinoId]
    if not casino then return false end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return false end
    if expectedType and entity.type ~= expectedType then return false end
    RememberPlayerIdentifier(source)
    if not IsCasinoPersonalCasinos(casinoId) and not casino.settings.isOpen and not CanManageCasino(source, casinoId) then
        ShowNotification(source, _L("casino_closed"))
        return false
    end
    if entity.settings.vip and not IsPlayerCasinoVIP(source, casinoId) then
        ShowNotification(source, _L("casino_vip_required"))
        return false
    end
    local coords = entity.settings.location and entity.settings.location.coords
    -- `false` means the ped is visible and too far away; `nil` (no server-side
    -- ped, e.g. OneSync off) can't be checked and is allowed.
    if coords and IsPlayerNearCoords(source, coords, (Config.InteractDistance or 2.5) + 7.5) == false then
        return false
    end
    return true, casino, entity
end

function UpdatePlayerBalance(source, casinoId, noDelay)
    local performUpdate = function()
        local balance = GetCasinoChips(source, casinoId)
        TriggerClientEvent("pickle_casinos:updateBalance", source, balance, casinoId)
    end
    if noDelay then
        performUpdate()
        return
    end
    SetTimeout(100, function()
        performUpdate()
    end)
end

function GetFormattedPlayer(source)
    local name = GetPlayerName(source)
    name = "**Name:** ".. name .. " (ID: " .. source .. ")\n**Identifiers:**\n`" .. json.encode(GetFilteredPlayerIdentifiers(source), {indent = true}) .. "`"
    return name
end

function PerformCooldownProcess(source)
    local source = tonumber(source)
    local threshold = Config.CooldownTime or 10
    local warningThreshold = threshold - 3
    local newCooldown = false
    if not PlayerCooldowns[source] then
        newCooldown = true
        PlayerCooldowns[source] = {
            cooldown = 0,
        }
    end
    if PlayerCooldowns[source] then 
        PlayerCooldowns[source].cooldown = PlayerCooldowns[source].cooldown + 1
        if PlayerCooldowns[source].cooldown == warningThreshold then
            ShowNotification(source, _L("cooldown_warning"))
        end
    end
    if newCooldown then
        SetTimeout(1000, function()
            if PlayerCooldowns[source] and PlayerCooldowns[source].cooldown >= threshold then
                DropPlayer(source, "Pickle Casinos: You have been kicked for spamming game actions.")
            end
            PlayerCooldowns[source] = nil
        end)
    end
end

RegisterCallback("pickle_casinos:getManagementStatus", function(source, cb, casinoId)
    return cb(CanManageCasino(source, casinoId))
end)

RegisterCallback("pickle_casinos:getPlayers", function(source, cb)
    -- Only used by the admin owner picker; don't expose identifiers to everyone.
    if not IsPlayerAdmin(source) then return cb({}) end
    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        players[#players + 1] = {
            source = playerId,
            identifier = GetIdentifier(playerId),
            name = GetPlayerCharacterName(playerId),
        }
    end
    return cb(players)
end)

RegisterCallback("pickle_casinos:getVIPStatus", function(source, cb, casinoId)
    local playerInfo, playerIndex = GetPlayerCasinoInfo(source, casinoId)
    local vipStartTime = playerInfo.startTime
    if not vipStartTime then return cb(false) end
    if Config.Casinos.vipExpireTime > 0 and (vipStartTime + Config.Casinos.vipExpireTime) < os.time() then
        local casino = Casinos[casinoId]
        if not casino then return end
        if playerIndex then
            casino.vip_players[playerIndex].startTime = nil
            MySQL.Async.execute('UPDATE `pickle_casinos` SET vip_players = ? WHERE id = ?', {json.encode(casino.vip_players), casinoId})
        end
        return cb(false)
    end 
    return cb(true, {
        timeLeft = Config.Casinos.vipExpireTime > 0 and ((vipStartTime + Config.Casinos.vipExpireTime) - os.time()) or nil,
    })
end)

-- Whitelist of sortable columns so callers can't pass arbitrary SQL into
-- ORDER BY. Same shape as the indexed columns on pickle_casino_transactions.
local TRANSACTION_SORT_COLUMNS = {
    datetime   = "datetime",
    amount     = "amount",
    type       = "type",
    name       = "name",
}

local function escapeLike(s)
    if type(s) ~= "string" then return "" end
    return s:gsub("\\", "\\\\"):gsub("%%", "\\%%"):gsub("_", "\\_")
end

--- Paged, searchable, sortable transaction fetch. Replaces shipping the full
--- list in setManagementInfo. Caller gets back { rows, total } so the UI can
--- show a "loaded N of M" counter and stop scrolling when total is reached.
lib.callback.register("pickle_casinos:getCasinoTransactions", function(source, data)
    local casinoId = tonumber(data and data.casinoId)
    if not casinoId or not CanManageCasino(source, casinoId) then
        return { rows = {}, total = 0 }
    end

    local offset    = math.max(0, tonumber(data.offset) or 0)
    local limit     = math.max(1, math.min(200, tonumber(data.limit) or 50))
    local search    = type(data.search) == "string" and data.search or ""
    local typeFilter = type(data.type) == "string" and data.type or ""
    local sortBy    = TRANSACTION_SORT_COLUMNS[data.sortBy] or "datetime"
    local sortDir   = (type(data.sortDir) == "string" and data.sortDir:lower() == "asc") and "ASC" or "DESC"

    local where = { "`casino_id` = ?" }
    local params = { casinoId }

    if search ~= "" then
        table.insert(where, "(`name` LIKE ? ESCAPE '\\\\' OR `type` LIKE ? ESCAPE '\\\\')")
        local needle = "%" .. escapeLike(search) .. "%"
        table.insert(params, needle)
        table.insert(params, needle)
    end
    if typeFilter ~= "" then
        table.insert(where, "`type` = ?")
        table.insert(params, typeFilter)
    end

    local whereClause = table.concat(where, " AND ")

    local total = MySQL.scalar.await(
        "SELECT COUNT(*) FROM `pickle_casino_transactions` WHERE " .. whereClause,
        params
    ) or 0

    local pageParams = {}
    for i = 1, #params do pageParams[i] = params[i] end
    table.insert(pageParams, limit)
    table.insert(pageParams, offset)

    local rows = MySQL.query.await(
        ("SELECT `id`, `identifier`, `name`, `type`, `amount`, `datetime` FROM `pickle_casino_transactions` WHERE %s ORDER BY `%s` %s, `id` %s LIMIT ? OFFSET ?")
            :format(whereClause, sortBy, sortDir, sortDir),
        pageParams
    ) or {}

    -- Reshape to the {origin = { identifier, name }, ...} shape the existing
    -- client code consumed, so the chart helpers / row renderer don't need to
    -- learn a new schema.
    local out = {}
    for i = 1, #rows do
        local r = rows[i]
        out[i] = {
            id = r.id,
            origin = { identifier = r.identifier, name = r.name },
            type = r.type,
            amount = tonumber(r.amount) or 0,
            datetime = tonumber(r.datetime) or 0,
        }
    end
    return { rows = out, total = total }
end)

--- Server-side weekly profit so the chart doesn't need the full transaction
--- history client-side. Returns 7 buckets (oldest → newest, today inclusive),
--- each `{ date = 'YYYY-MM-DD', profit = number }`.
lib.callback.register("pickle_casinos:getCasinoWeeklyProfit", function(source, data)
    local casinoId = tonumber(data and data.casinoId)
    if not casinoId or not CanManageCasino(source, casinoId) then
        return {}
    end
    local startTs = os.time() - (86400 * 7)
    local rows = MySQL.query.await(
        "SELECT `type`, `amount`, `datetime` FROM `pickle_casino_transactions` WHERE `casino_id` = ? AND `datetime` >= ?",
        { casinoId, startTs }
    ) or {}

    -- Build seven daily buckets keyed by YYYY-MM-DD in server-local time so
    -- the labels line up with what the client sees in toLocaleDateString.
    local buckets = {}
    local order = {}
    for i = 6, 0, -1 do
        local ts = os.time() - (86400 * i)
        local key = os.date("%Y-%m-%d", ts)
        buckets[key] = { date = key, profit = 0 }
        order[#order + 1] = key
    end
    for _, r in ipairs(rows) do
        local key = os.date("%Y-%m-%d", tonumber(r.datetime) or 0)
        local b = buckets[key]
        if b then
            local amt = tonumber(r.amount) or 0
            if type(r.type) == "string" and r.type:find("withdraw") then
                b.profit = b.profit - amt
            else
                b.profit = b.profit + amt
            end
        end
    end
    local out = {}
    for i, key in ipairs(order) do out[i] = buckets[key] end
    return out
end)

RegisterNetEvent("pickle_casinos:enterManagement", function(casinoId)
    local src = source
    if not CanManageCasino(src, casinoId) then return end
    RegisterManagementViewer(src, casinoId)
end)

RegisterNetEvent("pickle_casinos:exitManagement", function(casinoId)
    UnregisterManagementViewer(source, casinoId)
end)

local LastInitialize = {}
local AwaitingProximityReady = {}

AddEventHandler("pickle_casinos:playerUnloaded", function(source)
    LastInitialize[source] = nil
    AwaitingProximityReady[source] = nil
end)

RegisterNetEvent("pickle_casinos:readyForNearbyUpdates", function()
    local src = source
    local session = AwaitingProximityReady[src]
    if not session or not IsCasinoPlayerSession(src, session) then return end
    AwaitingProximityReady[src] = nil
    RegisterCasinoProximityPlayer(src)
end)

RegisterNetEvent("pickle_casinos:initializePlayer", function()
    local source = source
    local now = os.time()
    if LastInitialize[source] and (now - LastInitialize[source]) < 10 then return end
    RememberPlayerIdentifier(source)
    LastInitialize[source] = now
    if Config.PerformanceMode ~= false then
        AwaitingProximityReady[source] = GetCasinoPlayerSession(source)
    end
    TriggerClientEvent("pickle_casinos:syncCasinos", source, GetPublicCasinos(), GetIdentifier(source))
    TriggerClientEvent("pickle_casinos:setupInventory", source, {
        items = Inventory.Items,
    })
    UpdateHorseTracks(source)
    UpdateObjects(source)
    PayPendingRefunds(source)
end)

RegisterNetEvent("pickle_casinos:createCasino", function(data)
    local source = source
    if type(data) ~= "table" then return end
    if not CanManageCasino(source) then return ShowNotification(source, _L("no_permission")) end
    local chipItem = ValidateChipItem(source, data.chipItem)
    if not chipItem then return end
    local casinoSettings = {
        label = SanitizeCasinoLabel(data.label),
        location = SanitizeLocation(data.location),
        chipItem = chipItem,
        blipEnabled = data.blipEnabled or false,
        isOpen = true,
        cashEnabled = true,
        markedEnabled = true,
    }
    if casinoSettings.label == PERSONAL_CASINOS_LABEL then
        casinoSettings.label = "UNKNOWN_LABEL"
    end
    local entities = {}
    if data.template and data.template ~= "none" then
        local template = Templates[data.template]
        if template then
            entities = json.decode(template.entitiesJSON) or {}
            AddTemplateMapObjects(data.template, json.decode(template.objectsJSON) or {})
        end
    end 
    MySQL.insert('INSERT INTO `pickle_casinos` (settings, entities, transactions, vip_players) VALUES (?, ?, ?, ?)', {
        json.encode(casinoSettings), json.encode(entities), "[]", "[]"
    }, function(id)
        RegisterCasino(id, {
            id = id,
            entities = entities,
            settings = casinoSettings,
        })
    end)
end)

RegisterNetEvent("pickle_casinos:deleteCasino", function(casinoId)
    if not CanManageCasino(source) then return ShowNotification(source, _L("no_permission")) end
    local casino = Casinos[casinoId]
    if not casino then return end
    MySQL.Async.execute('DELETE FROM `pickle_casinos` WHERE id = ?', {casinoId})
    Casinos[casinoId] = nil
    TriggerClientEvent("pickle_casinos:deleteCasino", -1, casinoId)
end)

RegisterNetEvent("pickle_casinos:updateCasinoSetting", function(casinoId, variable, value)
    if not CanManageCasino(source, casinoId) then return ShowNotification(source, _L("no_permission")) end
    if variable == "chipItem" and not CanManageCasino(source) then return ShowNotification(source, _L("no_permission")) end
    local casino = Casinos[casinoId]
    if not casino then return end
    if variable == "label" then
        casino.settings.label = SanitizeCasinoLabel(value)
    elseif variable == "chipItem" then
        if casino.settings.label == PERSONAL_CASINOS_LABEL then return end
        local chipItem = ValidateChipItem(source, value, casinoId)
        if not chipItem then return end
        casino.settings.chipItem = chipItem
    elseif variable == "blipEnabled" then
        casino.settings.blipEnabled = value and true or false
    elseif variable == "isOpen" then
        casino.settings.isOpen = value and true or false
    elseif variable == "cashEnabled" then
        casino.settings.cashEnabled = value and true or false
    elseif variable == "markedEnabled" then
        casino.settings.markedEnabled = value and true or false
    elseif variable == "location" then
        if type(value) ~= "table" or not value.coords or not value.rotation then return end
        casino.settings.location = SanitizeLocation(value)
    elseif variable == "moneyExchangeRate" or variable == "dirtyExchangeRate" then
        -- Rates above 100 would hand out more chips than the money paid.
        local limits = Config.ExchangeRateLimits or { min = 1, max = 100 }
        local rate = SanitizeInt(value, limits.min, limits.max)
        if not rate then return ShowNotification(source, _L("invalid_amount")) end
        casino.settings[variable] = rate
    elseif variable == "vipPrice" then
        local price = SanitizeInt(value, 0)
        if not price then return ShowNotification(source, _L("invalid_amount")) end
        casino.settings.vipPrice = price
    else
        return
    end
    casino.settings = EnsureCasinoSettings(casino.settings)
    MySQL.Async.execute('UPDATE `pickle_casinos` SET settings = ? WHERE id = ?', {json.encode(casino.settings), casinoId})
    TriggerClientEvent("pickle_casinos:updateCasinoSetting", -1, casinoId, variable, casino.settings[variable])
end)

RegisterNetEvent("pickle_casinos:updateCasinoOwner", function(casinoId, newOwner)
    local source = source
    if not IsPlayerAdmin(source) then return ShowNotification(source, _L("no_permission")) end
    local casino = Casinos[casinoId]
    if not casino then return end
    newOwner = newOwner or {}
    local ownerType = newOwner.type
    -- Backwards compatibility: legacy payload sent only {identifier, name}
    if not ownerType then
        if newOwner.identifier and newOwner.identifier ~= "none" then
            ownerType = "player"
        else
            ownerType = "none"
        end
    end
    if ownerType == "none" or newOwner.identifier == "none" then
        casino.owner_info = nil
    elseif ownerType == "job" then
        if not newOwner.job or newOwner.job == "" then
            return ShowNotification(source, _L("no_permission"))
        end
        casino.owner_info = {
            type = "job",
            job = tostring(newOwner.job),
            name = newOwner.name or tostring(newOwner.job),
        }
    else
        casino.owner_info = {
            type = "player",
            identifier = newOwner.identifier,
            name = newOwner.name,
        }
    end
    MySQL.Async.execute('UPDATE `pickle_casinos` SET owner_info = ? WHERE id = ?', {json.encode(casino.owner_info), casinoId})
    TriggerClientEvent("pickle_casinos:updateCasinoOwner", -1, casinoId, casino.owner_info)
end)

RegisterNetEvent("pickle_casinos:createCasinoEntity", function(casinoId, entityType, settings)
    local source = source
    if not IsCasinoPersonalCasinos(casinoId) and not CanManageCasino(source, casinoId) then return ShowNotification(source, _L("no_permission")) end
    local casino = Casinos[casinoId]
    if not casino then return end
    if type(entityType) ~= "string" or not CASINO_ENTITY_TYPES[entityType] then return end
    PerformCooldownProcess(source)
    if IsCasinoPersonalCasinos(casinoId) then
        local placeableCfg = Config.PlaceableEntities[entityType]
        if not placeableCfg then return end
        local item = placeableCfg.item
        if not TryRemoveItem(source, item, 1) then return end
    end
    local entityId = GenerateEntityId(casinoId)
    local entity = {
        id = entityId,
        type = entityType,
        settings = EnsureGameSettings(entityType, settings),
    }
    if IsCasinoPersonalCasinos(casinoId) then
        entity.owner_info = {
            identifier = GetIdentifier(source),
            name = GetPlayerCharacterName(source)
        }
    end
    table.insert(casino.entities, entity)
    UpdateCasinoEntitiesSQL(casinoId)
    InitializeCasinoEntity(casinoId, entity)
    TriggerClientEvent("pickle_casinos:createCasinoEntity", -1, casinoId, GetPublicCasinoEntity(entity))
end)

RegisterNetEvent("pickle_casinos:deleteCasinoEntity", function(casinoId, entityId)
    local source = source
    local casinoEntity = GetCasinoEntity(casinoId, entityId)
    if not casinoEntity then return end
    local isEntityOwner = (casinoEntity.owner_info and casinoEntity.owner_info.identifier == GetIdentifier(source))
    if not CanManageCasino(source, casinoId) and not isEntityOwner then return ShowNotification(source, _L("no_permission")) end
    if IsCasinoEntityInUse(casinoEntity) then return ShowNotification(source, _L("casino_entity_in_use")) end
    local casino = Casinos[casinoId]
    if not casino then return end
    local entityType = nil
    for i=1, #casino.entities do
        if casino.entities[i].id == entityId then
            entityType = casino.entities[i].type
            table.remove(casino.entities, i)
            break
        end
    end
    UpdateCasinoEntitiesSQL(casinoId)
    TriggerClientEvent("pickle_casinos:deleteCasinoEntity", -1, casinoId, entityId)
    if IsCasinoPersonalCasinos(casinoId) then
        local placeableCfg = Config.PlaceableEntities[entityType]
        if not placeableCfg then return end
        local item = placeableCfg.item
        Inventory.AddItem(source, item, 1)
    end
end)

RegisterNetEvent("pickle_casinos:updateCasinoEntitySetting", function(casinoId, entityId, variable, value)
    local casinoEntity = GetCasinoEntity(casinoId, entityId)
    if not casinoEntity then return end
    local isEntityOwner = (casinoEntity.owner_info and casinoEntity.owner_info.identifier == GetIdentifier(source))
    if not CanManageCasino(source, casinoId) and not isEntityOwner then return ShowNotification(source, _L("no_permission")) end
    local casino = Casinos[casinoId]
    if not casino then return end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity then return end
    if not IsEntitySettingAllowed(entity.type, variable) then return end
    if IsCasinoEntityInUse(entity) then return ShowNotification(source, _L("casino_entity_in_use")) end
    entity.settings[variable] = value
    entity.settings = EnsureGameSettings(entity.type, entity.settings)
    InitializeCasinoEntity(casinoId, entity, true)
    UpdateCasinoEntitiesSQL(casinoId)
    TriggerClientEvent("pickle_casinos:updateCasinoEntitySetting", -1, casinoId, entityId, variable, entity.settings[variable])
end)

local function ProcessCasinoTransfer(source, casinoId, transferInfo)
    if not CanManageCasino(source, casinoId) then return ShowNotification(source, _L("no_permission")) end
    PerformCooldownProcess(source)
    local casino = Casinos[casinoId]
    if not casino then return end
    if type(transferInfo) ~= "table" then return end
    local transferType = transferInfo.type
    local balanceType = transferInfo.balanceType
    local amount = SanitizeInt(transferInfo.amount, 1)
    if not amount then return ShowNotification(source, _L("invalid_amount")) end
    if transferType ~= "deposit" and transferType ~= "withdraw" then return end
    if balanceType ~= "balance" and balanceType ~= "marked_balance" then return end
    if transferType == "deposit" then
        if balanceType == "balance" then
            if not TryRemoveMoney(source, amount) then return ShowNotification(source, _L("insufficient_funds")) end
            casino.balance = casino.balance + amount
        elseif balanceType == "marked_balance" then
            if not TryRemoveMoney(source, amount, "dirty") then return ShowNotification(source, _L("insufficient_funds")) end
            casino.marked_balance = casino.marked_balance + amount
        end
        ShowNotification(source, _L("casino_deposited", NumberWithCommas(amount), casino.settings.label))
        AddCasinoTransaction(source, casinoId, "management_deposit", amount)
    elseif transferType == "withdraw" then
        if balanceType == "balance" then
            if casino.balance < amount then return ShowNotification(source, _L("insufficient_funds")) end
            casino.balance = casino.balance - amount
            local totalTax = math.floor(amount * (Config.Casinos.tax / 100))
            AddMoney(source, amount - totalTax)
            if totalTax > 0 then
                for k,v in pairs(Config.Casinos.taxRecipients) do
                    AddSocietyMoney(k, math.floor(totalTax * (v / 100)))
                end
                ShowNotification(source, _L("casino_tax", NumberWithCommas(totalTax)))
            end
        elseif balanceType == "marked_balance" then
            if casino.marked_balance < amount then return ShowNotification(source, _L("insufficient_funds")) end
            casino.marked_balance = casino.marked_balance - amount
            AddMoney(source, amount, "dirty")
        end
        AddCasinoTransaction(source, casinoId, "management_withdraw", amount)
        ShowNotification(source, _L("casino_withdrawn", NumberWithCommas(amount), casino.settings.label))
    end
    MySQL.Async.execute('UPDATE `pickle_casinos` SET balance = ?, marked_balance = ? WHERE id = ?', {
        casino.balance,
        casino.marked_balance,
        casinoId
    })
    TriggerCasinoStateEvent("pickle_casinos:updateCasinoBalance", casinoId, casino.balance, casino.marked_balance)
end

RegisterNetEvent("pickle_casinos:startCasinoTransfer", function(casinoId, transferInfo)
    local source = source
    -- One transfer at a time per player (queued requests are rejected, not stacked).
    WithEconomyLock(source, function()
        ProcessCasinoTransfer(source, casinoId, transferInfo)
    end)
end)

RegisterCommand("casinos", function(source, args, raw)
    if not CanManageCasino(source) then return ShowNotification(source, _L("no_permission")) end
    TriggerClientEvent("pickle_casinos:casinosMenu", source)
end)

CreateThread(function() 
    for k,v in pairs(Config.PlaceableEntities) do 
        RegisterUsableItem(v.item, function(source)
            TriggerClientEvent("pickle_casinos:createPlacedEntity", source, k)
        end)
    end
    -- Chips/items owed to players who disconnected before a refund could be
    -- given; paid out on their next character load (PayPendingRefunds).
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pickle_casino_pending_refunds` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(255) NOT NULL,
            `casino_id` INT NOT NULL DEFAULT 0,
            `item` VARCHAR(100) DEFAULT NULL,
            `amount` BIGINT NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_identifier` (`identifier`)
        )
    ]], {})
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pickle_casino_ticket_progress` (
            `identifier` VARCHAR(255) NOT NULL PRIMARY KEY,
            `wager_total` BIGINT NOT NULL DEFAULT 0,
            `tickets_earned` INT NOT NULL DEFAULT 0,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]], {})
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pickle_casinos` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `owner_info` longtext DEFAULT NULL,
            `balance` int(11) NOT NULL DEFAULT 0,
            `marked_balance` int(11) NOT NULL DEFAULT 0,
            `settings` longtext NOT NULL,
            `vip_players` longtext NOT NULL,
            `transactions` longtext NOT NULL,
            `entities` longtext NOT NULL,
            PRIMARY KEY (`id`)
        )
    ]], {})

    -- Per-row transaction store. Replaces the JSON blob on pickle_casinos.transactions
    -- so the management UI can paginate / search / sort / aggregate server-side
    -- without ever loading the full history. The legacy `transactions` column on
    -- pickle_casinos is preserved (unread by the management flow) so a rollback
    -- of this resource still has the historical data to fall back on.
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pickle_casino_transactions` (
            `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `casino_id`  INT UNSIGNED    NOT NULL,
            `identifier` VARCHAR(64)     NOT NULL DEFAULT '',
            `name`       VARCHAR(128)    NOT NULL DEFAULT '',
            `type`       VARCHAR(64)     NOT NULL DEFAULT '',
            `amount`     BIGINT          NOT NULL DEFAULT 0,
            `datetime`   INT UNSIGNED    NOT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_casino_datetime` (`casino_id`, `datetime`),
            KEY `idx_casino_type`     (`casino_id`, `type`),
            KEY `idx_casino_name`     (`casino_id`, `name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]], {}, function()
        -- 7-day retention parity with EnsureCasinoTransactions. Prune on boot
        -- so the table doesn't grow unbounded across restarts.
        MySQL.Async.execute(
            "DELETE FROM `pickle_casino_transactions` WHERE `datetime` < ?",
            { os.time() - (86400 * 7) }
        )

        MySQL.Async.fetchAll("SELECT * FROM `pickle_casinos`", {}, function(results)
            local personalCasinoFound = false
            for i=1, #results do
                local result = results[i]
                local settings = json.decode(result.settings) or {}
                local entities = json.decode(result.entities) or {}
                local legacyTransactions = json.decode(result.transactions) or {}
                local vip_players = json.decode(result.vip_players) or {}
                local owner_info = json.decode(result.owner_info) or nil
                if settings and settings.label == PERSONAL_CASINOS_LABEL then
                    personalCasinoFound = true
                end

                -- One-time backfill from the legacy JSON blob into the new
                -- per-row table. Only runs when no rows exist for the casino,
                -- so subsequent restarts are no-ops. We apply the same 7-day
                -- retention EnsureCasinoTransactions used before.
                local existing = MySQL.scalar.await(
                    "SELECT COUNT(*) FROM `pickle_casino_transactions` WHERE `casino_id` = ?",
                    { result.id }
                ) or 0
                if existing == 0 and #legacyTransactions > 0 then
                    local cutoff = os.time() - (86400 * 7)
                    for _, tx in ipairs(legacyTransactions) do
                        if tx and tx.datetime and tx.datetime > cutoff then
                            MySQL.insert.await(
                                "INSERT INTO `pickle_casino_transactions` (`casino_id`, `identifier`, `name`, `type`, `amount`, `datetime`) VALUES (?, ?, ?, ?, ?, ?)",
                                {
                                    result.id,
                                    (tx.origin and tx.origin.identifier) or "",
                                    (tx.origin and tx.origin.name) or "",
                                    tx.type or "",
                                    tonumber(tx.amount) or 0,
                                    tonumber(tx.datetime) or 0,
                                }
                            )
                        end
                    end
                end

                RegisterCasino(result.id, {
                    id = result.id,
                    balance = result.balance,
                    marked_balance = result.marked_balance,
                    owner_info = owner_info,
                    settings = settings,
                    entities = entities,
                    transactions = {}, -- transactions now live in pickle_casino_transactions
                    vip_players = vip_players,
                }, true)
            end
            WarnAboutCasinoChipItems()
            if not personalCasinoFound then
                MySQL.insert('INSERT INTO `pickle_casinos` (settings, entities, transactions, vip_players) VALUES (?, ?, ?, ?)', {
                    json.encode({
                        label = PERSONAL_CASINOS_LABEL,
                        location = {
                            coords = vector3(0, 0, 0),
                            rotation = vector3(0, 0, 0)
                        },
                        chipItem = "UNKNOWN_CHIP_ITEM",
                        blipEnabled = false,
                        isOpen = true,
                        cashEnabled = true,
                        markedEnabled = true,
                    }), "[]", "[]", "[]"
                }, function(id)
                    RegisterCasino(id, {
                        id = id,
                        balance = 0,
                        marked_balance = 0,
                        owner_info = nil,
                        settings = {
                            label = PERSONAL_CASINOS_LABEL,
                            location = {
                                coords = vector3(0, 0, 0),
                                rotation = vector3(0, 0, 0)
                            },
                            chipItem = "UNKNOWN_CHIP_ITEM",
                            blipEnabled = false,
                            isOpen = true,
                            cashEnabled = true,
                            markedEnabled = true,
                        },
                        entities = {},
                        transactions = {},
                        vip_players = {},
                    }, true)
                end)
            end
        end)
    end)
end)