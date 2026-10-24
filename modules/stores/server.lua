function InitializeStoreEntity(casinoId, data)
    local entity = data or { id = "ERR_NO_ID_SLOT" }
    return entity
end

local function ProcessStorePurchase(source, casinoId, entityId, itemIndex, amount)
    local canUse, casino, casinoEntity = CanUseCasinoEntity(source, casinoId, entityId, "store")
    if not canUse then return end
    local storeCfg = Config.CreatorOptions.stores[casinoEntity.settings.store]
    if not storeCfg then
        storeCfg = Config.CreatorOptions.stores[1]
    end
    if not storeCfg then return end
    itemIndex = SanitizeInt(itemIndex, 1, #storeCfg.items)
    if not itemIndex then return end
    local item = storeCfg.items[itemIndex]
    if not item then return end
    amount = SanitizeInt(amount, 1, Config.MaximumItemPurchaseAmount)
    if not amount then return ShowNotification(source, _L("invalid_amount")) end
    local itemName = item.item
    local price = item.price * amount
    -- Take the money first; only hand over the items if that really succeeded.
    if price > 0 and not TryRemoveMoney(source, price) then
        return ShowNotification(source, _L("insufficient_funds"))
    end
    if Inventory.AddItem(source, itemName, amount) == false then
        -- Couldn't hand over the items (e.g. inventory full): give the money back.
        if price > 0 then AddMoney(source, price) end
        return ShowNotification(source, _L("store_items_not_added"))
    end
    ShowNotification(source, _L("store_purchase_success", NumberWithCommas(amount, true), GetItemLabel(item.item), NumberWithCommas(price)))
    local profit = math.floor(price * (Config.Casinos.profitPercent / 100))
    AddCasinoTransaction(source, casinoId, "purchase", profit)
    if IsCasinoOwned(casinoId) then
        casino.balance = (casino.balance or 0) + profit
        MySQL.Async.execute('UPDATE `pickle_casinos` SET balance = ? WHERE id = ?', {
            casino.balance,
            casinoId
        })
        TriggerCasinoStateEvent("pickle_casinos:updateCasinoBalance", casinoId, casino.balance, casino.marked_balance)
    end
end

RegisterNetEvent("pickle_casinos:storePurchase", function(casinoId, entityId, itemIndex, amount)
    local source = source
    PerformCooldownProcess(source)
    -- One purchase at a time per player (queued requests are rejected, not stacked).
    WithEconomyLock(source, function()
        ProcessStorePurchase(source, casinoId, entityId, itemIndex, amount)
    end)
end)
