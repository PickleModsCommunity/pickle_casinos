-- Run from the repository root: lua tests/bridge_regression.lua
-- The QB bridge's existing ?. extension is normalized only for stock Lua tests.
local checks = 0
local function check(value, message) assert(value, message); checks=checks+1 end
function AddEventHandler() end
function CreateThread() end
function TriggerClientEvent() end
function GetPlayerName() return "Connected" end
function joaat() return 123 end
lib = {callback={register=function() end}}
json = {encode=function() return "{}" end, decode=function() return {"money"} end}
Config = {FrameworkSettings={cashItem="cash"}}
local full, itemCount, balance, active, framework, swapOnLookup, insertOwner
local A = {identifier="A", PlayerData={citizenid="A",license="license-A",money={cash=0}}}
local B = {identifier="B", PlayerData={citizenid="B",license="license-B",money={cash=0}}}
local function addCash(n) balance=balance+n; active.PlayerData.money.cash=balance end
for _, player in ipairs({A,B}) do
    player.addMoney=addCash
    player.getMoney=function() return balance end
    player.Functions={AddMoney=function(_, n) addCash(n); return true end}
end
local esx = {GetPlayerFromId=function() return active end}
local qb = {Functions={GetPlayer=function() return active end}}
exports = setmetatable({es_extended={getSharedObject=function() return esx end},
    ['qb-core']={GetCoreObject=function() return qb end}}, {__call=function() end})
function GetResourceState(name) return name == framework and "started" or "missing" end
Inventory = {
    AddItem=function(_,_,n) if full then return false end; itemCount=itemCount+n; return true end,
    GetItemCount=function() return itemCount end,
}
MySQL = {Sync={
    fetchAll=function()
        if swapOnLookup then active=B; swapOnLookup=false end
        return {}
    end,
    execute=function(_, args) insertOwner=args['@owner'] or args['@citizenid']; return 1 end,
}}
dofile("core/server.lua")
for _, bridge in ipairs({"esx","qb"}) do
    framework = bridge == "esx" and "es_extended" or "qb-core"
    active=A; balance=0; itemCount=0; full=true
    A.PlayerData.money.cash=0; B.PlayerData.money.cash=0
    local f=assert(io.open("bridge/" .. bridge .. "/server.lua")); local code=f:read("*a"); f:close()
    assert(load((code:gsub("%?%.", ".")), "@bridge/" .. bridge .. "/server.lua"))()
    Config.FrameworkSettings.cashItem="cash"
    check(AddMoney(1,50) == false and itemCount == 0, bridge .. " full cash inventory reported success")
    full=false
    check(AddMoney(1,50) == true and itemCount == 50, bridge .. " cash item grant failed")
    Config.FrameworkSettings.cashItem=false
    check(AddMoney(1,75) == true and balance == 75, bridge .. " framework cash grant failed")
    swapOnLookup=true; insertOwner=nil
    check(AddOwnedVehicle(1,"adder") == true and insertOwner == "A", bridge .. " vehicle changed owner during lookup")
    active=nil
    check(AddOwnedVehicle(1,"adder") == false and AddMoney(1,50) == false, bridge .. " missing player accepted")
end
print(("PASS: %d framework bridge checks"):format(checks))
