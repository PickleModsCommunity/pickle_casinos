function InitializeStoreEntity(casinoId, data)
    local entity = data or { id = "ERR_NO_ID_SLOT" }
    return entity
end

RegisterNetEvent("pickle_casinos:storePurchase", function(casinoId, entityId, itemIndex, amount)
    local source = source
    PerformCooldownProcess(source)
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
    if price > 0 and not TryRemoveMoney(source, price) then
        return ShowNotification(source, _L("insufficient_funds"))
    end
    Inventory.AddItem(source, itemName, amount)
    ShowNotification(source, _L("store_purchase_success", NumberWithCommas(amount, true), GetItemLabel(item.item), NumberWithCommas(price)))
    local profit = math.floor(price * (Config.Casinos.profitPercent / 100))
    AddCasinoTransaction(source, casinoId, "purchase", profit)
    if IsCasinoOwned(casinoId) then 
        casino.balance = (casino.balance or 0) + profit
        MySQL.Async.execute('UPDATE `pickle_casinos` SET balance = ? WHERE id = ?', {
            casino.balance,
            casinoId
        })
        TriggerClientEvent("pickle_casinos:updateCasinoBalance", -1, casinoId, casino.balance, casino.marked_balance)
    end
end)