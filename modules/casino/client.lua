CLIENT_FPS = 60

CurrentCasinoEntity = nil
LOCAL_IDENTIFIER = "ERR_UNKNOWN"
LOCAL_MONEY = 0
local isEditing = false
local gizmoEntity = nil
local LocalCasinos = {}
CreateThread(function()
    while true do 
        local startCount = GetFrameCount()
        Wait(1000)
        local endCount = GetFrameCount()
        CLIENT_FPS = endCount - startCount
    end
end)

function CreateCasinoEntity(casinoId, entityId)
    local casino = Casinos[casinoId]
    local casinoEntity = GetCasinoEntity(casinoId, entityId)
    if not casino or not casinoEntity then return end
    if casinoEntity.type == "blackjack" then
        CreateBlackjackEntity(casinoId, entityId)
    elseif casinoEntity.type == "roulette" then
        CreateRouletteEntity(casinoId, entityId)
    elseif casinoEntity.type == "thunder_roulette" then
        CreateThunderRouletteEntity(casinoId, entityId)
    elseif casinoEntity.type == "baccarat" then
        CreateBaccaratEntity(casinoId, entityId)
    elseif casinoEntity.type == "slot" then
        CreateSlotEntity(casinoId, entityId)
    elseif casinoEntity.type == "poker" then
        CreatePokerEntity(casinoId, entityId)
    elseif casinoEntity.type == "wheel" then
        CreateWheelEntity(casinoId, entityId)
    elseif casinoEntity.type == "luckywheel" then
        CreateLuckyWheelEntity(casinoId, entityId)
    elseif casinoEntity.type == "horseracing" then
        CreateHorseRacingEntity(casinoId, entityId)
    elseif casinoEntity.type == "cashier" then
        CreateCashierEntity(casinoId, entityId)
    elseif casinoEntity.type == "store" then
        CreateStoreEntity(casinoId, entityId)
    end
end

function GetCasinoEntity(casinoId, entityId)
    local casino = Casinos[casinoId]
    if not casino then return end
    for i=1, #casino.entities do
        if casino.entities[i].id == entityId then
            return casino.entities[i], i
        end
    end
end

function UpdateCasinoEntity(casinoId, entity)
    local casino = Casinos[casinoId]
    if not casino then return end
    local casinoEntity, index = GetCasinoEntity(casinoId, entity.id)
    if not casinoEntity then return end
    casino.entities[index] = entity
end

function GenerateWheelBonusConfig()
    local entries = {}
    for i=1, #Config.WheelBonus do 
        entries[i] = {
            id = "bonus_" .. i,
            multiplier = Config.WheelBonus[i].multiplier,
            chance = Config.WheelBonus[i].chance,
        }
    end
    return entries
end

function SetEntitySmoothRotation(entity, from, to, speed)
    local speed = speed or 4
    local progress = 0
    CreateThread(function()
        while progress < 100 do
            progress = progress + speed
            if progress > 100 then progress = 100 end
            local newCoords = lerp(from, to, progress / 100)
            SetEntityRotation(entity, newCoords, 2, true)
            Wait(10)
        end
    end)
end

function StartCasinoEditor(casinoId, editorData)
    local editorData = editorData or {}
    if isEditing then return end
    isEditing = true
    SetEditorFocus(true)
    SendNUIMessage({
        type = "openCasinoEditor",
        casinos = CasinosArrayUI(),
        casinoId = casinoId,
        editorData = editorData,
    })
    CreateThread(function()
        while isEditing do 
            if not inGizmo and IsControlJustPressed(1, 47) then 
                SetEditorFocus(true)
                -- SetCursorLocation(0.85, 0.5)
            end
            Wait(0)
        end
    end)
end

function StopCasinoEditor()
    isEditing = false
    SetEditorFocus(false)
    SendNUIMessage({
        type = "closeCasinoEditor",
    })
end

function CasinosArrayUI()
    local casinosArray = {}
    for k,v in pairs(Casinos) do
        table.insert(casinosArray, v)
    end
    return casinosArray
end

function GenerateGameSettingsUI()   
    local slotOptions = {}
    for k,v in pairs(Config.Slots) do
        table.insert(slotOptions, {
            label = v.label,
            value = k,
        })
    end
    local modelToOptions = function(models, isDealerModel)
        local options = {}
        for i=1, #models do
            table.insert(options, {
                label = models[i].label,
                value = isDealerModel and i or models[i].model,
            })
        end
        return options
    end
    local storesToOptions = function(stores)
        local options = {}
        for i=1, #stores do
            table.insert(options, {
                label = stores[i].label,
                value = i,
            })
        end
        return options
    end
    return {
        ["blackjack"] = {
            {variable = "dealerModel", type = "dropdown", label = _L("dealer_model"), default = 1, options = modelToOptions(Config.CreatorOptions.dealerModels, true)},
            {variable = "tableModel", type = "dropdown", label = _L("table_model"), default = Config.CreatorOptions.blackjack.tableModels[1].model, options = modelToOptions(Config.CreatorOptions.blackjack.tableModels)},
            {variable = "maxWager", type = "money", default = 100, min = 100, label = _L("max_wager")},
        },
        ["roulette"] = {
            {variable = "dealerModel", type = "dropdown", label = _L("dealer_model"), default = 1, options = modelToOptions(Config.CreatorOptions.dealerModels, true)},
            {variable = "tableModel", type = "dropdown", label = _L("table_model"), default = Config.CreatorOptions.roulette.tableModels[1].model, options = modelToOptions(Config.CreatorOptions.roulette.tableModels)},
            {variable = "maxWager", type = "money", default = 100, min = 100, label = _L("max_wager")},
        },
        ["thunder_roulette"] = {
            {variable = "dealerModel", type = "dropdown", label = _L("dealer_model"), default = 1, options = modelToOptions(Config.CreatorOptions.dealerModels, true)},
            {variable = "tableModel", type = "dropdown", label = _L("table_model"), default = Config.CreatorOptions.thunder_roulette.tableModels[1].model, options = modelToOptions(Config.CreatorOptions.thunder_roulette.tableModels)},
            {variable = "maxWager", type = "money", default = 100, min = 100, label = _L("max_wager")},
        },
        ["baccarat"] = {
            {variable = "dealerModel", type = "dropdown", label = _L("dealer_model"), default = 1, options = modelToOptions(Config.CreatorOptions.dealerModels, true)},
            {variable = "tableModel", type = "dropdown", label = _L("table_model"), default = Config.CreatorOptions.baccarat.tableModels[1].model, options = modelToOptions(Config.CreatorOptions.baccarat.tableModels)},
            {variable = "maxWager", type = "money", default = 100, min = 100, label = _L("max_wager")},        
        },
        ["wheel"] = {
            {variable = "maxWager", type = "money", default = 100, min = 100, label = _L("max_wager")},
        },
        ["luckywheel"] = {
            {variable = "wheelModel", type = "dropdown", label = _L("wheel_model"), default = GetCreatorOptions("luckywheel").wheelModels[1].model, options = modelToOptions(GetCreatorOptions("luckywheel").wheelModels)},
            {variable = "vehicleLocation", type = "location", default = {
                coords = vector3(0.0, 0.0, 0.0),
                rotation = vector3(0.0, 0.0, 0.0),
            }, label = _L("luckywheel_vehicle_location")},
            {variable = "spinPrice", type = "money", default = 0, min = 0, label = _L("luckywheel_spin_price")},
        },
        ["horseracing"] = {
            {variable = "maxWager", type = "money", default = 100, min = 100, label = _L("max_wager")},
        },
        ["slot"] = {
            {variable = "game", type = "dropdown", label = "Game", default = slotOptions[1].value, options = slotOptions},
            {variable = "maxWager", type = "money", default = 100, min = 100, label = _L("max_wager")},
        },
        ["poker"] = {
            {variable = "dealerModel", type = "dropdown", label = _L("dealer_model"), default = 1, options = modelToOptions(Config.CreatorOptions.dealerModels, true)},
            {variable = "tableModel", type = "dropdown", label = _L("table_model"), default = Config.CreatorOptions.poker.tableModels[1].model, options = modelToOptions(Config.CreatorOptions.poker.tableModels)},
            {variable = "smallBlind", type = "money", default = 10, min = 10, label = _L("poker_smallblind")},
            {variable = "bigBlind", type = "money", default = 15, min = 15, label = _L("poker_bigblind")},
        },
        ["cashier"] = {
            {variable = "dealerModel", type = "dropdown", label = _L("cashier_model"), default = 1, options = modelToOptions(Config.CreatorOptions.dealerModels, true)},
        },
        ["store"] = {
            {variable = "dealerModel", type = "dropdown", label = _L("store_model"), default = 1, options = modelToOptions(Config.CreatorOptions.dealerModels, true)},
            {variable = "store", type = "dropdown", label = _L("store_type"), default = 1, options = storesToOptions(Config.CreatorOptions.stores)},
        }
    }
end

function CreateCurrentCasinoEntity(coords, rotation, data)
    if CurrentCasinoEntity then
        DeleteScriptObject(CurrentCasinoEntity.object)
        CurrentCasinoEntity = nil
    end
    CurrentCasinoEntity = {entityType = data.info.entityType, settings = data.info.settings}
    local model
    local entityType = data.info.entityType
    if not entityType and data.info.entityId then
        local casinoEntity = GetCasinoEntity(data.info.casinoId, data.info.entityId)
        if not casinoEntity then return end
        entityType = casinoEntity.type
    end
    if not entityType then return end
    if data.info.settings.tableModel then
        model = data.info.settings.tableModel
    else
        if entityType == "slot" then
            model = Config.Slots[data.info.settings.game].model
        elseif entityType == "wheel" then
            model = `vw_prop_vw_luckywheel_01a`
        elseif entityType == "luckywheel" then
            model = `vw_prop_vw_luckywheel_01a`
        elseif entityType == "horseracing" then
            model = Config.HorseRacing.machineModel
        elseif entityType == "cashier" or entityType == "store" then
            CurrentCasinoEntity.object = CreateDealerPed(data.info.settings.dealerModel, coords, rotation.z)
            return
        else
            model = Config.CreatorOptions[entityType].tableModels[1].model
        end
    end
    CurrentCasinoEntity.object = CreateProp(model, coords.x, coords.y, coords.z, false, false, false)
    SetEntityRotation(CurrentCasinoEntity.object, rotation.x, rotation.y, rotation.z, 2, true)
end

function SetEditorFocus(toggle)
    SetNuiFocus(toggle, toggle)
    SendNUIMessage({
        type = "setEditorFocus",
        toggle = toggle,
    })
end

function CreateCasinoInteract(casinoId)
    return CreateInteraction({
        label = _L("interact_casino_manage"),
        icon = Config.TargetIcons and Config.TargetIcons["management"] or nil,
        coords = Casinos[casinoId].settings.location.coords,
        heading = Casinos[casinoId].settings.location.rotation.z,
    }, function(selected)
        ServerCallback("pickle_casinos:getManagementStatus", function(allowed)
            if not allowed then return ShowNotification(_L("no_permission")) end
            StartCasinoManagement(casinoId)
        end, casinoId)
    end)
end

function CreateCasinoBlip(casinoId) 
    local casino = Casinos[casinoId]
    if not casino then return end
    if not casino.settings.blipEnabled then return end
    local blip = AddBlipForCoord(casino.settings.location.coords.x, casino.settings.location.coords.y, casino.settings.location.coords.z)
    local blipCfg = Config.CasinoBlip or {}
    SetBlipSprite(blip, blipCfg.sprite or 1)
    SetBlipDisplay(blip, blipCfg.display or 4)
    SetBlipScale(blip, blipCfg.scale or 1.0)
    SetBlipColour(blip, blipCfg.color or 0)
    SetBlipAsShortRange(blip, true)
    local category = blipCfg.category or 40
    SetBlipCategory(blip, category)
    AddTextEntry("BLIP_CAT_" .. category, _L("blip_casino"))
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(casino.settings.label)
    EndTextCommandSetBlipName(blip)
    return blip
end

function RegisterCasino(casinoId, data)
    Casinos[casinoId] = data
    for i=1, #Casinos[casinoId].entities do
        CreateCasinoEntity(casinoId, Casinos[casinoId].entities[i].id)
    end
    LocalCasinos[casinoId] = {
        location = Casinos[casinoId].settings.location,
        interact = CreateCasinoInteract(casinoId),
        blip = CreateCasinoBlip(casinoId),
    }
end

function StartCasinoManagement(casinoId)
    if isEditing then return end
    local casino = Casinos[casinoId]
    if not casino then return end
    CurrentCasinoManagement = {casinoId = casinoId}
    -- Tell the server we're viewing so it can push new-transaction events
    -- to us instead of broadcasting the full list to everyone.
    TriggerServerEvent("pickle_casinos:enterManagement", casinoId)
    SendNUIMessage({
        type = "setManagementInfo",
        info = {
            casinoId = casinoId,
            balance = casino.balance,
            marked_balance = casino.marked_balance,
            -- transactions list is no longer pushed up-front; the UI fetches
            -- a page at a time via the getCasinoTransactions NUI callback.
            settings = casino.settings,
            owner_info = casino.owner_info,
        }
    })
    SetNuiFocus(true, true)
end

function ExitCasinoManagement()
    local prev = CurrentCasinoManagement
    CurrentCasinoManagement = nil
    SetNuiFocus(false, false)
    if prev and prev.casinoId then
        TriggerServerEvent("pickle_casinos:exitManagement", prev.casinoId)
    end
    SendNUIMessage({
        type = "setManagementInfo",
        info = nil,
    })
end

function CreateDealerPed(dealerIndex, coords, heading)
    local dealerCfg = Config.CreatorOptions.dealerModels[dealerIndex]
    if not dealerCfg then 
        dealerCfg = Config.CreatorOptions.dealerModels[1]
    end
    local ped = CreateNPC(dealerCfg.model, coords.x, coords.y, coords.z, heading, false, false)
    SetEntityHeading(ped, heading)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedDefaultComponentVariation(ped)
    local components = dealerCfg.pedComponents
    for i=1, #components do
        SetPedComponentVariation(ped, components[i].id, components[i].drawable, components[i].texture, 0)
    end
    return ped
end

function GenerateTemplates()
    local templates = {
        {label = _L("none"), value = "none"},
    }
    for k,v in pairs(Templates) do 
        table.insert(templates, {
            label = v.label,
            value = k,
        })
    end
    return templates
end

function ExitCasinoCamera(CurrentCamera, durationValue)
    local duration = durationValue
    if duration == nil then duration = 2000 end
    ClearFocus()
	DestroyAllCams()
    RenderScriptCams(false, true, duration, true, false) 
end

function PlayCasinoDealerSpeech(ped, speech, speechAction)
    PlayPedAmbientSpeechNative(ped, speech, speechAction, 1)
end

function RequestCasinoEntityMenu(casinoId, entityId)
    local alert = lib.alertDialog({
        header = _L("personal_casinos_dialog"),
        centered = true,
        cancel = true
    })
    local isEditing = (alert == "confirm")
    if isEditing then
        StartCasinoEditor(casinoId, {
            entityId = entityId,
        })
    end
    return isEditing
end

-- CreateThread(function()
--     local audioBanks = {
--         "DLC_VINEWOOD/CASINO_GENERAL",
--         "DLC_VINEWOOD/CASINO_SLOT_MACHINES_01",
--         "DLC_VINEWOOD/CASINO_SLOT_MACHINES_02",
--         "DLC_VINEWOOD/CASINO_SLOT_MACHINES_03",
--     }
--     for i=1, #audioBanks do
--         while not RequestScriptAudioBank(audioBanks[i], false) do
--             Wait(0)
--         end
--     end
--     while true do
--         local ped = PlayerPedId()
--         local playerCoords = GetEntityCoords(ped)w
--         for k,v in pairs(LocalCasinos) do 
--             print(k, v.location)
--             if v.location and #(playerCoords - v.location.coords) < 100.0 then
--                 print("PLAY TIME!")
--                 if not IsStreamPlaying() and LoadStream("casino_walla", "DLC_VW_Casino_Interior_Sounds") then
--                     PlayStreamFromPosition(v.location.coords.x, v.location.coords.y, v.location.coords.z)
--                 end
--                 if IsStreamPlaying() and not IsAudioSceneActive("DLC_VW_Casino_General") then
--                     StartAudioScene("DLC_VW_Casino_General")
--                 end
--             end
--         end
--         Wait(1500)
--     end
-- end)

RegisterNUICallback("editPlayer", function(data, cb)
    cb("ok")
    SendNUIMessage({
        type = "setEditorHidden",
        hidden = true,
    })
    SetEditorFocus(false)
    ServerCallback("pickle_casinos:getPlayers", function(players)
        local existing = data and data.player or {}
        local existingType = existing.type or (existing.identifier and existing.identifier ~= "none" and "player") or "none"

        local typeOptions = {
            { label = _L("none"), value = "none" },
            { label = "Player", value = "player" },
            { label = "Job", value = "job" },
        }

        local playerOptions = {
            {label = _L("none"), value = "none"},
        }
        for i=1, #players do
            playerOptions[#playerOptions + 1] = {
                label = players[i].name .. " (ID: " .. players[i].source .. ")",
                value = players[i].identifier,
            }
        end

        local options = {
            { required = true, type = "select", label = "Owner Type", default = existingType, options = typeOptions },
            { type = "select", label = _L("casino_owner_select"), default = (existing.identifier or "none"), options = playerOptions },
            { type = "input", label = "Job Name", description = "Job that owns this casino (boss-grade members manage it)", default = existing.job or "" },
            { type = "input", label = "Job Display Name", description = "Optional display name shown in management UI", default = existing.name or "" },
        }
        local input = lib.inputDialog(_L("casino_owner"), options)
        if input then
            local selectedType = input[1] or "none"
            local newOwner
            if selectedType == "none" then
                newOwner = { type = "none", name = _L("none"), identifier = "none" }
            elseif selectedType == "job" then
                local jobName = (input[3] or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if jobName == "" then
                    SendNUIMessage({ type = "setEditorHidden", hidden = false })
                    SetEditorFocus(true)
                    return
                end
                local displayName = input[4] and input[4] ~= "" and input[4] or jobName
                newOwner = { type = "job", job = jobName, name = displayName }
            else -- player
                local identifier = input[2]
                if not identifier or identifier == "none" then
                    newOwner = { type = "none", name = _L("none"), identifier = "none" }
                else
                    local picked
                    for i=1, #players do
                        if players[i].identifier == identifier then picked = players[i]; break end
                    end
                    if picked then
                        newOwner = { type = "player", identifier = picked.identifier, name = picked.name }
                    else
                        newOwner = { type = "player", identifier = identifier, name = input[4] or identifier }
                    end
                end
            end
            SendNUIMessage({
                type = "setPlayer",
                player = newOwner,
            })
        end
        SendNUIMessage({
            type = "setEditorHidden",
            hidden = false,
        })
        SetEditorFocus(true)
    end)
end)

RegisterNUICallback("updateCasinoOwner", function(data, cb)
    TriggerServerEvent("pickle_casinos:updateCasinoOwner", data.casinoId, data.value)
    cb("ok")
end)

RegisterNUICallback("openCasinoEditor", function(data, cb)
    ExitCasinoManagement()
    StartCasinoEditor(data.casinoId)
end)

RegisterNUICallback("startCasinoTransfer", function(data, cb)
    if not CurrentCasinoManagement then return end
    TriggerServerEvent("pickle_casinos:startCasinoTransfer", CurrentCasinoManagement.casinoId, {
        type = data.type,
        balanceType = data.balanceType,
        amount = data.amount,
    })
    cb("ok")
end)

RegisterNUICallback("exitManagement", function(data, cb)
    ExitCasinoManagement()
    cb("ok")
end)

RegisterNUICallback("getCasinoTransactions", function(data, cb)
    local casinoId = CurrentCasinoManagement and CurrentCasinoManagement.casinoId
    if not casinoId then return cb({ rows = {}, total = 0 }) end
    local result = lib.callback.await("pickle_casinos:getCasinoTransactions", false, {
        casinoId = casinoId,
        offset   = data.offset,
        limit    = data.limit,
        search   = data.search,
        type     = data.type,
        sortBy   = data.sortBy,
        sortDir  = data.sortDir,
    })
    cb(result or { rows = {}, total = 0 })
end)

RegisterNUICallback("getCasinoWeeklyProfit", function(data, cb)
    local casinoId = CurrentCasinoManagement and CurrentCasinoManagement.casinoId
    if not casinoId then return cb({}) end
    local result = lib.callback.await("pickle_casinos:getCasinoWeeklyProfit", false, {
        casinoId = casinoId,
    })
    cb(result or {})
end)

RegisterNUICallback("exitCasinoEditor", function(data, cb)
    StopCasinoEditor()
    cb("ok")
end)

RegisterNUICallback("disableEditorFocus", function(data, cb)
    SetEditorFocus(false)
    cb("ok")
end)

RegisterNUICallback("pageLoaded", function(data, cb)
    local Currency = Config.Currency or {
        currency = "USD",
        countryCode = "en-US",
    }
    SendNUIMessage({
        type = "setConfig",
        config = {
            personalCasinosLabel = PERSONAL_CASINOS_LABEL,
            displayCurrencyAsChips = Config.DisplayCurrencyAsChips,
            chips = Config.Chips,
            currency = Currency.currency,
            countryCode = Currency.countryCode,
            bonusWheelMultipliers = GenerateWheelBonusConfig(),
            gameSettings = GenerateGameSettingsUI(),
            audioPresets = GetAudioPresetOptions(),
            locale = Language[Config.Language],
            templates = GenerateTemplates(),
        }
    })
    cb("ok")
end)

RegisterNUICallback("exitGame", function(data, cb)
    cb("ok")
    TriggerEvent("pickle_casinos:exitGame")
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = "setCurrentGame",
        game = nil
    })
    if Config.ToggleGameMode then
        Config.ToggleGameMode(false)
    end
end)

RegisterNUICallback("createCasino", function(data, cb)
    TriggerServerEvent("pickle_casinos:createCasino", data)
    cb("ok")
end)

RegisterNUICallback("updateCasinoSetting", function(data, cb)
    TriggerServerEvent("pickle_casinos:updateCasinoSetting", data.casinoId, data.variable, data.value)
    cb("ok")
end)

RegisterNUICallback("updateCasinoEntitySetting", function(data, cb)
    TriggerServerEvent("pickle_casinos:updateCasinoEntitySetting", data.casinoId, data.entityId, data.variable, data.value)
    cb("ok")
end)

RegisterNUICallback("deleteCasino", function(data, cb)
    TriggerServerEvent("pickle_casinos:deleteCasino", data.id)
    cb("ok")
end)

RegisterNUICallback("editLocation", function(data, cb)
    cb("ok")
    SendNUIMessage({
        type = "setEditorHidden",
        hidden = true,
    })
    SetEditorFocus(false)
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local coords = (data.coords and #(vector3(data.coords.x, data.coords.y, data.coords.z) - playerCoords) < 100.0) and data.coords or (GetEntityCoords(ped) + GetEntityForwardVector(ped) * 3)
    local rotation = (#(vector3(data.rotation.x, data.rotation.y, data.rotation.z) - vector3(0.0, 0.0, 0.0)) > 1.0 and vector3(data.rotation.x, data.rotation.y, data.rotation.z) or vector3(0.0, 0.0, GetEntityHeading(ped)))
    if not data.info or (not data.info.entityType and not data.info.entityId) then
        local result = StartGizmoEditor({model = `prop_tennis_ball`, coords = coords, rotation = rotation})
        SendNUIMessage({
            type = "setLocation",
            id = data.id,
            location = {
                coords = result.position,
                rotation = result.rotation,
            }
        })
    else
        local zOffset = 0.0
        if data.info.entityId then 
            local casinoEntity = GetCasinoEntity(data.info.casinoId, data.info.entityId)
            if not casinoEntity then return end
            if casinoEntity.type == "poker" then
                zOffset = 0.185
            end
            TriggerEvent("pickle_casinos:setCasinoEntityHidden", data.info.casinoId, data.info.entityId, true)
        end
        if data.info.entityType == "poker" then
            zOffset = 0.185
        end
        if not CurrentCasinoEntity or CurrentCasinoEntity.entityType ~= data.info.entityType then
            CreateCurrentCasinoEntity(coords, rotation, data)
        end
        local result = StartGizmoEditor({entity = CurrentCasinoEntity.object, coords = coords, rotation = rotation})
        result.position = result.position + vector3(0.0, 0.0, zOffset)
        SendNUIMessage({
            type = "setLocation",
            id = data.id,
            location = {
                coords = result.position,
                rotation = result.rotation,
            }
        })
        if data.info.entityId then 
            DeleteScriptObject(CurrentCasinoEntity.object)
            CurrentCasinoEntity = nil
            SetTimeout(1000, function()
                TriggerEvent("pickle_casinos:setCasinoEntityHidden", data.info.casinoId, data.info.entityId, false)
            end)
        end
    end
    SetEditorFocus(true)
    SendNUIMessage({
        type = "setEditorHidden",
        hidden = false,
    })
end)

RegisterNUICallback("teleportToCasino", function(data, cb)
    cb("ok")
    local casino = Casinos[data.casinoId]
    if not casino then return end
    local ped = PlayerPedId()
    local coords = casino.settings.location.coords
    local rotation = casino.settings.location.rotation
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, rotation.z)
end)

RegisterNUICallback("teleportToEntity", function(data, cb)
    cb("ok")
    local casino = Casinos[data.casinoId]
    if not casino then return end
    local casinoEntity = GetCasinoEntity(data.casinoId, data.entityId)
    if not casinoEntity then return end
    local ped = PlayerPedId()
    local coords = casinoEntity.settings.location.coords + vector3(0.0, 0.0, 1.0)
    local rotation = casinoEntity.settings.location.rotation
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, rotation.z)
end)

RegisterNUICallback("createCasinoEntity", function(data, cb)
    cb("ok")
    local casino = Casinos[data.casinoId]
    if not casino then return end
    if not data.settings.location or #(vector3(0, 0, 0) - vector3(data.settings.location.coords.x, data.settings.location.coords.y, data.settings.location.coords.z)) < 1.0 then
        ShowNotification(_L("casino_entity_location_error"))
        return
    end
    TriggerServerEvent("pickle_casinos:createCasinoEntity", data.casinoId, data.type, data.settings)
end)

RegisterNUICallback("exitCasinoEntityEditor", function(data, cb)
    cb("ok")
    if CurrentCasinoEntity then
        DeleteScriptObject(CurrentCasinoEntity.object)
        CurrentCasinoEntity = nil
    end
end)

RegisterNUICallback("deleteCasinoEntity", function(data, cb)
    cb("ok")
    TriggerServerEvent("pickle_casinos:deleteCasinoEntity", data.casinoId, data.entityId)
end)

RegisterNUICallback("updateTempCasinoEntitySettings", function(data, cb)
    cb("ok")
    if not CurrentCasinoEntity then return end
    if CurrentCasinoEntity.entityType == data.entityType then 
        if not CurrentCasinoEntity.settings.tableModel and not CurrentCasinoEntity.settings.game then
            return
        end
    end
    local coords = GetEntityCoords(CurrentCasinoEntity.object)
    if CurrentCasinoEntity.entityType and CurrentCasinoEntity.entityType == "poker" then
        coords = coords - vector3(0.0, 0.0, 0.19)
    end
    CreateCurrentCasinoEntity(coords, GetEntityRotation(CurrentCasinoEntity.object), {
        info = {
            entityType = data.entityType,
            settings = data.settings,
        }
    })
end)

RegisterNUICallback("highlightCasinoEntity", function(data, cb)
    cb("ok")
    if data.casinoId then
        local casinoEntity = GetCasinoEntity(data.casinoId, data.entityId)
        if not casinoEntity then return end
        if CurrentHighlight then
            CurrentHighlight.coords = data.coords
        else
            CurrentHighlight = {coords = casinoEntity.settings.location.coords}
            CreateThread(function()
                while CurrentHighlight do 
                    DrawMarker(0, CurrentHighlight.coords.x, CurrentHighlight.coords.y, CurrentHighlight.coords.z + 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 1.5, 255, 255, 255, 255, false, true, false, true)
                    Wait(0)
                end
            end)
        end
    elseif CurrentHighlight then
        CurrentHighlight = nil
    end
end)

RegisterNetEvent("pickle_casinos:updateCasinoOwner", function(casinoId, owner_info)
    local casino = Casinos[casinoId]
    if not casino then return end
    casino.owner_info = owner_info
    SendNUIMessage({
        type = "updateCasinoOwner",
        casinoId = casinoId,
        owner_info = owner_info,
    })
end)

-- Targeted single-row push from the server when a new transaction lands and
-- this client is currently viewing the management UI for that casino.
RegisterNetEvent("pickle_casinos:newCasinoTransaction", function(casinoId, transaction)
    if not CurrentCasinoManagement or CurrentCasinoManagement.casinoId ~= casinoId then return end
    SendNUIMessage({
        type = "newCasinoTransaction",
        casinoId = casinoId,
        transaction = transaction,
    })
end)

RegisterNetEvent("pickle_casinos:updateCasinoBalance", function(casinoId, balance, marked_balance)
    if not Casinos[casinoId] then return end
    Casinos[casinoId].balance = balance
    Casinos[casinoId].marked_balance = marked_balance
    SendNUIMessage({
        type = "updateCasinoBalance",
        casinoId = casinoId,
        balance = balance,
        marked_balance = marked_balance,
    })
end)

RegisterNetEvent("pickle_casinos:syncCasinos", function(data, identifier)
    LOCAL_IDENTIFIER = identifier
    for k,v in pairs(data) do
        RegisterCasino(k, v)
        -- Casinos[k] = v
        -- for i=1, #v.entities do
        --     CreateCasinoEntity(k, v.entities[i].id)
        -- end
    end
    SendNUIMessage({
        type = "updateCasinos",
        casinos = CasinosArrayUI(),
    })
    -- Model loading in RegisterCasino can yield. Subscribe only after every
    -- initial casino exists locally, so arrival snapshots cannot be discarded.
    if Config.PerformanceMode ~= false then
        TriggerServerEvent("pickle_casinos:readyForNearbyUpdates")
    end
end)

RegisterNetEvent("pickle_casinos:syncNearbyCasinos", function(updates)
    for casinoId, update in pairs(updates) do
        local casino = Casinos[casinoId]
        if casino then
            TriggerEvent("pickle_casinos:updateCasinoBalance", casinoId, update.balance, update.marked_balance)
            for _, snapshot in ipairs(update.entities) do
                local entity = GetCasinoEntity(casinoId, snapshot.id)
                if entity then
                    for key in pairs(entity) do entity[key] = nil end
                    for key, value in pairs(snapshot) do entity[key] = value end
                end
            end
        end
    end
end)

RegisterNetEvent("pickle_casinos:displayResults", function(totalWin, balance)
    SendNUIMessage({
        type = "displayResults",
        results = {winnings = totalWin},
    })
    SendNUIMessage({
        type = "updateBalance",
        balance = balance,
    })
end)

RegisterNetEvent("pickle_casinos:updateCasinoEntity", function(casinoId, entity)
    local casino = Casinos[casinoId]
    if not casino then return end
    local casinoEntity = GetCasinoEntity(casinoId, entity.id)
    if not casinoEntity then return end
    UpdateCasinoEntity(casinoId, entity)
end)

RegisterNetEvent("pickle_casinos:updateMoney", function(money)
    LOCAL_MONEY = money
    SendNUIMessage({
        type = "updateMoney",
        money = money
    })
end)

RegisterNetEvent("pickle_casinos:updateCasinoSetting", function(casinoId, variable, value)
    local casino = Casinos[casinoId]
    if not casino then return end
    casino.settings[variable] = value
    if LocalCasinos[casinoId] then
        LocalCasinos[casinoId].location = casino.settings.location
        DeleteInteraction(LocalCasinos[casinoId].interact)
        LocalCasinos[casinoId].interact = CreateCasinoInteract(casinoId)
        if LocalCasinos[casinoId].blip then
            RemoveBlip(LocalCasinos[casinoId].blip)
        end
        LocalCasinos[casinoId].blip = CreateCasinoBlip(casinoId)
    end
    SendNUIMessage({
        type = "updateCasinoSetting",
        casinoId = casinoId,
        variable = variable,
        value = value,
    })
    SendNUIMessage({
        type = "updateCasinos",
        casinos = CasinosArrayUI(),
    })
end)

RegisterNetEvent("pickle_casinos:updateCasinoEntitySetting", function(casinoId, entityId, variable, value)
    local casino = Casinos[casinoId]
    if not casino then return end
    local casinoEntity = GetCasinoEntity(casinoId, entityId)
    if not casinoEntity then return end
    casinoEntity.settings[variable] = value
    SendNUIMessage({
        type = "updateCasinoEntitySetting",
        casinoId = casinoId,
        entityId = entityId,
        variable = variable,
        value = value,
    })
    SendNUIMessage({
        type = "updateCasinoEntities",
        casinoId = casinoId,
        entities = casino.entities, 
    })
    SendNUIMessage({
        type = "updateCasinos",
        casinos = CasinosArrayUI(),
    })
    TriggerEvent("pickle_casinos:refreshCasinoEntity", casinoId, entityId)
end)

RegisterNetEvent("pickle_casinos:deleteCasino", function(casinoId)
    local casino = Casinos[casinoId]
    if not casino then return end
    for i=1, #Casinos[casinoId].entities do 
        local entity = Casinos[casinoId].entities[i]
        if entity.type == "blackjack" then
            DeleteBlackjackEntity(casinoId, entity.id)
        elseif entity.type == "roulette" then
            DeleteRouletteEntity(casinoId, entity.id)
        elseif entity.type == "thunder_roulette" then
            DeleteThunderRouletteEntity(casinoId, entity.id)
        elseif entity.type == "baccarat" then
            DeleteBaccaratEntity(casinoId, entity.id)
        elseif entity.type == "slot" then
            DeleteSlotEntity(casinoId, entity.id)
        elseif entity.type == "poker" then
            DeletePokerEntity(casinoId, entity.id)
        elseif entity.type == "wheel" then
            DeleteWheelEntity(casinoId, entity.id)
        elseif entity.type == "luckywheel" then
            DeleteLuckyWheelEntity(casinoId, entity.id)
        elseif entity.type == "horseracing" then
            DeleteHorseRacingEntity(casinoId, entity.id)
        elseif entity.type == "cashier" then
            DeleteCashierEntity(casinoId, entity.id)
        elseif entity.type == "store" then
            DeleteStoreEntity(casinoId, entity.id)
        end
    end
    if LocalCasinos[casinoId] then
        if LocalCasinos[casinoId].interact then
            DeleteInteraction(LocalCasinos[casinoId].interact)
        end
        if LocalCasinos[casinoId].blip then
            RemoveBlip(LocalCasinos[casinoId].blip)
        end
    end
    Casinos[casinoId] = nil
    SendNUIMessage({
        type = "updateCasinos",
        casinos = CasinosArrayUI(),
    })
end)

RegisterNetEvent("pickle_casinos:registerCasino", function(casinoId, data)
    RegisterCasino(casinoId, data)
    SendNUIMessage({
        type = "updateCasinos",
        casinos = CasinosArrayUI(),
    })
end)

RegisterNetEvent("pickle_casinos:createCasinoEntity", function(casinoId, data)
    local casino = Casinos[casinoId]
    if not casino then return end
    table.insert(casino.entities, data)
    CreateCasinoEntity(casinoId, data.id)
    SendNUIMessage({
        type = "updateCasinoEntities",
        casinoId = casinoId,
        entities = casino.entities, 
    })
    SendNUIMessage({
        type = "updateCasinos",
        casinos = CasinosArrayUI(),
    })
end)

RegisterNetEvent("pickle_casinos:deleteCasinoEntity", function(casinoId, entityId)
    local casino = Casinos[casinoId]
    if not casino then return end
    for i=1, #casino.entities do
        if casino.entities[i].id == entityId then
            table.remove(casino.entities, i)
            break
        end
    end
    SendNUIMessage({
        type = "updateCasinoEntities",
        casinoId = casinoId,
        entities = casino.entities, 
    })
    SendNUIMessage({
        type = "updateCasinos",
        casinos = CasinosArrayUI(),
    })
end)

RegisterNetEvent("pickle_casinos:casinosMenu", function()
    StartCasinoEditor()
end)

RegisterNetEvent("pickle_casinos:createPlacedEntity", function(entityType)
    local casinoId
    for k,v in pairs(Casinos) do
        if v.settings.label == PERSONAL_CASINOS_LABEL then
            casinoId = k
            break
        end
    end
    StartCasinoEditor(casinoId, {isCreatingEntity = true, entityType = entityType})
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if isEditing then
            SetNuiFocus(false, false)
        end
        if gizmoEntity then
            DeleteScriptObject(gizmoEntity)
        end
        if CurrentCasinoEntity then
            DeleteScriptObject(CurrentCasinoEntity.object)
            CurrentCasinoEntity = nil
        end
    end
end)

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Wait(1000)
        TriggerServerEvent("pickle_casinos:initializePlayer")
    end
end)