function InitializeCashierEntity(casinoId, data)
    local entity = data or { id = "ERR_NO_ID_SLOT" }
    return entity
end

RegisterCallback("pickle_casinos:getBalances", function(source, cb, casinoId, entityId)
    PerformCooldownProcess(source)
    RememberPlayerIdentifier(source)
    PayPendingRefunds(source)
    local money = GetMoney(source)
    local dirty = GetMoney(source, "dirty")
    local balance = 0
    local casinoBalance = 0
    local casinoMarkedBalance = 0
    local casino = Casinos[casinoId]
    if casino then
        balance = Inventory.GetItemCount(source, casino.settings.chipItem) or 0
        if IsCasinoOwned(casinoId) then 
            casinoBalance = casino.balance or 0
            casinoMarkedBalance = casino.marked_balance or 0
        else
            casinoBalance = Config.MaximumChipPurchaseAmount
            casinoMarkedBalance = Config.MaximumChipPurchaseAmount
        end
    end
    return cb({
        money = money,
        dirty = dirty,
        balance = balance,
        casinoBalance = casinoBalance,
        casinoMarkedBalance = casinoMarkedBalance,
    })
end)

local ProcessCasinoExchange

RegisterNetEvent("pickle_casinos:casinoExchange", function(casinoId, entityId, exchangeType, param, param2)
    local source = source
    PerformCooldownProcess(source)
    -- One exchange at a time per player (queued requests are rejected, not stacked).
    WithEconomyLock(source, function()
        ProcessCasinoExchange(source, casinoId, entityId, exchangeType, param, param2)
    end)
end)

ProcessCasinoExchange = function(source, casinoId, entityId, exchangeType, param, param2)
    if not CanUseCasinoEntity(source, casinoId, entityId, "cashier") then return end
    local maxAmount = Config.MaximumChipPurchaseAmount
    if exchangeType == "buy" then
        local currency = param
        local amount = SanitizeInt(param2, 1, maxAmount)
        if currency ~= "money" and currency ~= "dirty" then return end
        if not amount then return ShowNotification(source, _L("invalid_amount")) end
        local casino = Casinos[casinoId]
        if not casino then return end
        if currency == "money" and not casino.settings.cashEnabled then return end
        if currency == "dirty" and not casino.settings.markedEnabled then return end
        local currencyCash = GetMoney(source, currency)
        if currencyCash < amount then return end
        local exchangeRate = 100
        if currency == "money" then
            exchangeRate = casino.settings.moneyExchangeRate or 100
        elseif currency == "dirty" then
            exchangeRate = casino.settings.dirtyExchangeRate or 100
        end
        local multiplier = exchangeRate / 100
        local chips = math.floor(amount * multiplier)
        if chips <= 0 then return end
        -- Take the money first (atomic check-and-remove in the inventory); grant
        -- chips only if that really succeeded.
        if not TryRemoveMoney(source, amount, currency) then return ShowNotification(source, _L("insufficient_funds")) end
        if Inventory.AddItem(source, casino.settings.chipItem, chips) == false then
            -- Couldn't hand over the chips (e.g. inventory full): give the money back.
            AddMoney(source, amount, currency)
            return ShowNotification(source, _L("cashier_chips_not_added"))
        end
        ShowNotification(source, _L("cashier_bought_chips", NumberWithCommas(chips, true), NumberWithCommas(amount), currency == "money" and _L("cashier_buy_currency_type_cash") or _L("cashier_buy_currency_type_dirty")))
        ConfigSV.WebhookHandler("purchaseChips", {
            casinoId = casinoId,
            casinoLabel = casino.settings.label or "No Label",
            player = GetFormattedPlayer(source),
            currency = currency,
            price = NumberWithCommas(amount),
            chips = NumberWithCommas(chips, true)
        })
        if IsCasinoOwned(casinoId) then 
            if currency == "money" then
                casino.balance = (casino.balance or 0) + amount
            elseif currency == "dirty" then
                casino.marked_balance = (casino.marked_balance or 0) + amount
            end
            MySQL.Async.execute('UPDATE `pickle_casinos` SET balance = ?, marked_balance = ? WHERE id = ?', {
                casino.balance,
                casino.marked_balance,
                casinoId
            })
            TriggerCasinoStateEvent("pickle_casinos:updateCasinoBalance", casinoId, casino.balance, casino.marked_balance)
        end
        AddCasinoTransaction(source, casinoId, "deposit", amount)
    elseif exchangeType == "sell" then
        local amount = SanitizeInt(param2, 1, maxAmount)
        if not amount then return ShowNotification(source, _L("invalid_amount")) end
        local casino = Casinos[casinoId]
        if not casino then return end
        local chips = Inventory.GetItemCount(source, casino.settings.chipItem) or 0
        if chips < amount then return end
        local casinoBalance = casino.balance or 0
        if IsCasinoOwned(casinoId) and amount > casinoBalance then return end
        -- Take the chips first; only pay out if they were actually removed.
        if not TryRemoveItem(source, casino.settings.chipItem, amount) then return end
        if IsCasinoOwned(casinoId) then
            casino.balance = casinoBalance - amount
            MySQL.Async.execute('UPDATE `pickle_casinos` SET balance = ?, marked_balance = ? WHERE id = ?', {
                casino.balance,
                casino.marked_balance,
                casinoId
            })
            TriggerCasinoStateEvent("pickle_casinos:updateCasinoBalance", casinoId, casino.balance, casino.marked_balance)
        end
        AddMoney(source, amount, "money")
        ShowNotification(source, _L("cashier_sold_chips", NumberWithCommas(amount, true), NumberWithCommas(amount), _L("cashier_buy_currency_type_cash")))
        ConfigSV.WebhookHandler("sellChips", {
            casinoId = casinoId,
            casinoLabel = casino.settings.label or "No Label",
            player = GetFormattedPlayer(source),
            chips = NumberWithCommas(amount, true),
            price = NumberWithCommas(amount),
        })
        AddCasinoTransaction(source, casinoId, "withdraw", amount)
    else
        return
    end
end

local ProcessVIPPurchase

RegisterNetEvent("pickle_casinos:purchaseVIP", function(casinoId, entityId)
    local source = source
    PerformCooldownProcess(source)
    WithEconomyLock(source, function()
        ProcessVIPPurchase(source, casinoId, entityId)
    end)
end)

ProcessVIPPurchase = function(source, casinoId, entityId)
    if not CanUseCasinoEntity(source, casinoId, entityId, "cashier") then return end
    local identifier = GetIdentifier(source)
    if not identifier then return end
    local casino = Casinos[casinoId]
    if not casino then return end
    local vipPrice = SanitizeInt(casino.settings.vipPrice, 0) or 0
    local isFree = vipPrice <= 0
    local playerInfo, playerIndex = GetPlayerCasinoInfo(source, casinoId)
    if IsPlayerCasinoVIP(source, casinoId) then
        ShowNotification(source, _L("cashier_vip_already_owned"))
        return
    end
    if not isFree and not TryRemoveMoney(source, vipPrice) then
        ShowNotification(source, _L("insufficient_funds"))
        return
    end
    if playerIndex then
        casino.vip_players[playerIndex].startTime = os.time()
    else
        table.insert(casino.vip_players, { identifier = identifier, name = GetPlayerCharacterName(source), startTime = os.time() })
    end
    if isFree then
        ShowNotification(source, _L("cashier_vip_bought_free"))
    else
        ShowNotification(source, _L("cashier_vip_bought", NumberWithCommas(vipPrice)))
    end
    MySQL.Async.execute('UPDATE `pickle_casinos` SET vip_players = ? WHERE id = ?', {
        json.encode(casino.vip_players),
        casinoId
    })
    if not isFree and IsCasinoOwned(casinoId) then
        casino.balance = (casino.balance or 0) + vipPrice
        MySQL.Async.execute('UPDATE `pickle_casinos` SET balance = ? WHERE id = ?', {
            casino.balance,
            casinoId
        })
        TriggerCasinoStateEvent("pickle_casinos:updateCasinoBalance", casinoId, casino.balance, casino.marked_balance)
    end
    if not isFree then
        -- Free VIP doesn't represent a cash movement, so skip the log to
        -- avoid littering the management view with $0 rows.
        AddCasinoTransaction(source, casinoId, "vip", vipPrice)
    end
end