-- Run from the repository root with Lua 5.4: lua tests/security_regression.lua
-- FiveM/framework/database stubs exercise the actual server handlers.
local handlers, callbacks, net, timeouts, pushes = {}, {}, {}, {}, {}
local character, inventoryFull, inventoryCount = "character-A", false, 0
local rows, nextId, notifications = {}, 0, 0
local afterQuery, afterDelete, deferredLoad
Config = { LuckyTicket = { enabled = true, chipsPerTicket = 100, eligibleGames = { slots = true } },
    LuckyWheel = { sections = { car = {} } }, ExchangeRateLimits = { min = 1, max = 100 } }
PERSONAL_CASINOS_LABEL = "__PERSONAL__"
Casinos = { [1] = { settings = { label = "Casino", chipItem = "chips" }, balance = 1000,
    owner_info = { identifier = "character-A" }, entities = { { id = "poker", type = "poker", settings = {location={coords={x=0,y=0,z=0}}}, seats = {} } } } }
function AddEventHandler(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
function TriggerEvent(name, ...) for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
function RegisterNetEvent(name, fn) net[name] = fn end
function RegisterCallback(name, fn) callbacks[name] = fn end
function RegisterCommand() end
function exports() end
function CreateThread() end -- Game timers/SQL bootstrap are outside these unit tests.
function SetTimeout(_, fn) timeouts[#timeouts + 1] = fn end
function TriggerClientEvent(name, target, ...) pushes[#pushes + 1] = {name, target, ...} end
function GetIdentifier() return character end
function GetWaitingTime() return 10 end
function GetPlayerName() return "Connected player" end
function GetPlayerCharacterName() return character or "Unknown" end
function IsPlayerAdmin() return false end
function ShowNotification() notifications = notifications + 1 end
function _L(key) return key end
function NumberWithCommas(n) return tostring(n) end
function vector3(x,y,z) return {x=x,y=y,z=z} end
function SanitizeInt(n, min, max)
    if type(n) ~= "number" or n ~= math.floor(n) or n < min or (max and n > max) then return end
    return n
end
json = { encode = function() return "{}" end }
lib = { callback = { register = function(name, fn) callbacks[name] = fn end } }
Inventory = {
    AddItem = function(_, _, amount)
        if inventoryFull then return false end
        inventoryCount = inventoryCount + amount
        return true
    end,
    GetItemCount = function() return inventoryCount end,
}
local function insertRefund(_, args)
    nextId = nextId + 1
    rows[nextId] = {id=nextId, identifier=args[1], casino_id=args[2], item=args[3], amount=args[4]}
    return nextId
end
MySQL = {
    insert = setmetatable({await = function() return 42 end}, {__call = function(_, ...) return insertRefund(...) end}),
    query = {await = function(_, args)
        local found = {}
        for _, row in pairs(rows) do if row.identifier == args[1] then found[#found + 1] = row end end
        if afterQuery then local fn = afterQuery; afterQuery = nil; fn() end
        return found
    end},
    update = {await = function(_, args)
        local exists = rows[args[1]] ~= nil
        rows[args[1]] = nil
        if afterDelete then local fn = afterDelete; afterDelete = nil; fn() end
        return exists and 1 or 0
    end},
    Async = { execute = function() end, fetchAll = function(_, _, cb) deferredLoad = cb end },
}
dofile("core/server.lua")
dofile("modules/casino/server.lua")
dofile("modules/poker/server.lua")
dofile("modules/lucky_ticket/server.lua")
dofile("modules/luckywheel/server.lua")
local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
local function countRows() local n = 0; for _ in pairs(rows) do n=n+1 end; return n end
local function resetRefunds() rows = {}; inventoryCount = 0; inventoryFull = false; character = "character-A" end
source = 1
RememberPlayerIdentifier(1)
-- Full inventories retain winnings and repeat cashier visits never duplicate them.
inventoryFull = true
AddCasinoChips(1, 1, 125.9)
check(countRows() == 1 and rows[nextId].amount == 125, "failed payout must retain whole chips")
PayPendingRefunds(1)
check(countRows() == 1 and inventoryCount == 0, "failed refund must remain claimable")
inventoryFull = false
PayPendingRefunds(1); PayPendingRefunds(1)
check(countRows() == 0 and inventoryCount == 125, "refund must be paid exactly once")
-- A character change during either SQL await must never pay the new character.
for _, phase in ipairs({"query", "delete"}) do
    resetRefunds(); inventoryFull = true; AddCasinoChips(1, 1, 90); inventoryFull = false
    local switch = function() CleanupCasinoPlayer(1); character = "character-B" end
    if phase == "query" then afterQuery = switch else afterDelete = switch end
    PayPendingRefunds(1)
    check(inventoryCount == 0 and countRows() == 1, "session changed during " .. phase)
    for _, row in pairs(rows) do check(row.identifier == "character-A", "refund changed owner") end
end
-- Same character logging out/back in also invalidates outstanding work.
resetRefunds(); inventoryFull = true; AddCasinoChips(1,1,20); inventoryFull = false
afterDelete = function() CleanupCasinoPlayer(1); GetCasinoPlayerSession(1) end
PayPendingRefunds(1)
check(inventoryCount == 0 and countRows() == 1, "same-character session reuse")
-- Actual poker cleanup returns escrow to A even after framework removes A.
resetRefunds(); RememberPlayerIdentifier(1)
Casinos[1].entities[1].seats = {{source=1, balance=300, cards={}}}
CurrentPlayers[1] = true
character = nil
TriggerEvent("QBCore:Server:OnPlayerUnload", 1)
check(Casinos[1].entities[1].seats[1].source == nil and CurrentPlayers[1] == nil, "poker seat survived unload")
check(countRows() == 1 and rows[nextId].identifier == "character-A" and rows[nextId].amount == 300, "escrow wrong character")
TriggerEvent("QBCore:Server:OnPlayerUnload", 1)
check(countRows() == 1, "double cleanup duplicated escrow")
character = "character-B"; PayPendingRefunds(1)
check(inventoryCount == 0 and countRows() == 1, "B collected A escrow")
character = "character-A"; PayPendingRefunds(1)
check(inventoryCount == 300 and countRows() == 0, "A cannot collect escrow")
-- Deferred ticket loads pay the wagering character, including inventory-full grants.
resetRefunds(); RegisterLuckyTicketWager(1, "slots", 100)
CleanupCasinoPlayer(1); character = "character-B"; deferredLoad({})
check(inventoryCount == 0 and rows[nextId].identifier == "character-A", "deferred ticket went to B")
resetRefunds(); inventoryFull = true; RegisterLuckyTicketWager(1, "slots", 100)
check(countRows() == 1 and rows[nextId].item == "lucky_ticket", "full inventory lost ticket")
-- Every even-money roulette pair cancels for both roulette variants.
for _, pair in ipairs({{7,12},{8,11},{9,10}}) do
    local bets = {}; for i=1,12 do bets[i] = {wager=0} end
    bets[pair[1]].wager=100; bets[pair[2]].wager=100
    check(GetUnhedgedRouletteWager(bets) == 0, "opposing roulette pair earns tickets")
    bets[pair[1]].wager=150
    check(GetUnhedgedRouletteWager(bets) == 50, "unmatched roulette stake not counted")
end
-- Revoked managers lose their feed before the next transaction is sent.
resetRefunds(); RegisterManagementViewer(1,1); Casinos[1].owner_info.identifier="character-B"
pushes = {}; AddCasinoTransaction(1,1,"poker_deposit",10)
check(not ManagementViewers[1][1], "revoked manager still subscribed")
for _, push in ipairs(pushes) do check(push[1] ~= "pickle_casinos:newCasinoTransaction", "revoked manager got transaction") end
Casinos[1].owner_info.identifier="character-A"
RegisterManagementViewer(1,1); pushes = {}; AddCasinoTransaction(1,1,"poker_deposit",10)
check(#pushes == 1 and pushes[1][2] == 1, "authorized manager lost transaction feed")
-- Labels preserve UTF-8, remove controls and cap characters; dirty rate stays configurable.
net["pickle_casinos:updateCasinoSetting"](1,"label", string.rep("?",80) .. "\n\0")
check(utf8.len(Casinos[1].settings.label) == 64 and not Casinos[1].settings.label:find("%c"), "label cap/controls")
net["pickle_casinos:updateCasinoSetting"](1,"label", "Hello\nCasino")
check(Casinos[1].settings.label == "HelloCasino", "control character retained")
net["pickle_casinos:updateCasinoSetting"](1,"label", string.char(255))
check(Casinos[1].settings.label == "INVALID_LABEL", "malformed UTF-8 accepted")
net["pickle_casinos:updateCasinoSetting"](1,"dirtyExchangeRate",100)
check(Casinos[1].settings.dirtyExchangeRate == 100, "dirty-money policy changed")
-- Occupied plates and insert conflicts retry; temporary reservations are released.
local lookups, inserts = 0, 0
function GetOwnedVehicleFromPlate() lookups=lookups+1; return lookups == 1 and {owner="someone"} or nil end
check(InsertCasinoPrizeVehicle(function() inserts=inserts+1; return inserts > 1 end), "vehicle collision retry failed")
check(lookups == 3 and inserts == 2, "occupied plate was inserted or insert conflict wasn't retried")
local originalRandom = math.random
math.random = function(min) return min end
local occupiedPlate
function GetOwnedVehicleFromPlate(plate) occupiedPlate = plate; return nil end
local nested = false
check(InsertCasinoPrizeVehicle(function()
    nested = InsertCasinoPrizeVehicle(function() error("reserved plate reused") end)
    return true
end), "outer vehicle insert failed")
check(nested == false and occupiedPlate == "AAA 000", "concurrent reservation did not protect plate")
check(InsertCasinoPrizeVehicle(function() return true end), "reservation leaked after insert")
math.random = originalRandom
-- Failed vehicle prizes restore casino funds, and partial bundles only charge delivered rewards.
resetRefunds(); Casinos[1].balance=1000; LuckyWheelSections = {[1]="car"}
function AddOwnedVehicle() return false end
check(ProcessLuckyWheelRewards(1,1,"poker",1,{{type="vehicle",model="adder",casinoCost=100}}) == false, "failed insert announced a prize")
check(Casinos[1].balance == 1000, "failed vehicle charged casino")
check(ProcessLuckyWheelRewards(1,1,"poker",1,{{type="vehicle",model="adder",casinoCost=100},{type="chips",amount=50,casinoCost=20}}), "partial bundle failed")
check(Casinos[1].balance == 980 and inventoryCount == 50, "partial bundle charged undelivered vehicle")
-- A leave/unload that arrives while poker transaction logging waits on SQL
-- cannot return the seat's escrow twice.
resetRefunds(); inventoryCount = 300
Inventory.RemoveItem = function(_, _, amount) inventoryCount=inventoryCount-amount; return true end
local poker = Casinos[1].entities[1]
poker.seats = {GenerateDefaultPokerSeat()}; poker.settings.bigBlind=10
JoinPokerEntity(1,1,"poker",1)
poker.seats[1].balance=200
local originalInsert = MySQL.insert.await
MySQL.insert.await = function()
    LeavePokerEntity(1,1,"poker",1)
    return 43
end
LeavePokerEntity(1,1,"poker",1)
MySQL.insert.await = originalInsert
check(inventoryCount == 200 and poker.seats[1].source == nil, "reentrant poker leave duplicated escrow")
-- Invalid join/leave traffic still hits the same detector as wager traffic.
for _, game in ipairs({"baccarat","blackjack","roulette","thunder_roulette","slots","wheel"}) do
    dofile("modules/" .. game .. "/server.lua")
end
for _, game in ipairs({"baccarat","blackjack","poker","roulette","thunder_roulette","slots","wheel"}) do
    local before = PlayerCooldowns[1] and PlayerCooldowns[1].cooldown or 0
    callbacks["pickle_casinos:" .. game .. ":requestSeat"](1,function() end,999,"missing",1)
    local leave = game == "slots" and "leaveSlotMachine" or "leaveTable"
    net["pickle_casinos:" .. game .. ":" .. leave]()
    check(PlayerCooldowns[1].cooldown == before+2, game .. " join/leave bypasses spam detector")
end
function GetPlayerPed() return nil end
dofile("modules/casino/employees_server.lua")
local beforeNearby = PlayerCooldowns[1].cooldown
callbacks["pickle_casinos:getNearbyPlayers"](1)
check(PlayerCooldowns[1].cooldown == beforeNearby+1, "nearby scan bypasses spam detector")
-- Joining the money wheel again cannot revive the previous character's bets.
local oldCanUse = CanUseCasinoEntity
local wheel = {id="wheel",type="wheel",stage={type="spinning"},players={}}
character="character-A"; wheel.players[1]={wagers={bonus=100},session=GetCasinoPlayerSession(1)}
Casinos[1].entities[#Casinos[1].entities+1] = wheel
CleanupCasinoPlayer(1); character="character-B"
CanUseCasinoEntity = function() return true,Casinos[1],wheel end
local joined = true
callbacks["pickle_casinos:wheel:requestSeat"](1,function(seat) joined=seat end,1,"wheel",1)
check(joined == nil and wheel.players[1].left, "new character reactivated old money-wheel wagers")
CanUseCasinoEntity=oldCanUse; character="character-A"

-- Baccarat cancels the matching Player/Banker stakes, preserving side bets.
local counted
RegisterLuckyTicketWager = function(_, game, amount) check(game == "baccarat", "unexpected game"); counted=amount end
local baccarat = {id="baccarat",type="baccarat",stage={type="waiting"},seats={
    {source=1,wagers={player=100,banker=100,tie=0,playerPair=0,bankerPair=0,eitherPair=0,suitedPair=0}}, {}, {}, {} }}
Casinos[1].entities[#Casinos[1].entities+1] = baccarat
StartBaccaratGame(1,"baccarat")
check(counted == 0, "opposing baccarat bets earn tickets")
baccarat.stage.type="waiting"; baccarat.seats[1].wagers.player=150; baccarat.seats[1].wagers.tie=10
StartBaccaratGame(1,"baccarat")
check(counted == 60, "unmatched baccarat stake/side bets not counted")
print(("PASS: %d security regression checks"):format(checks))
