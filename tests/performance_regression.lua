-- Run from the repository root: lua tests/performance_regression.lua
local checks, events, handlers, nets = 0, {}, {}, {}
local positions, characters, managers = {}, {}, {}
local scans, coordinateReads = 0, 0
Config = {RenderDistance=50, CasinoSyncDistance=150, PerformanceUpdateInterval=1000}
-- PerformanceMode intentionally absent at first: enabled unless explicitly false.
PERSONAL_CASINOS_LABEL = "personal"
ManagementViewers = {}
local function location(x,y,z) return {coords={x=x,y=y or 0,z=z or 0},rotation={x=0,y=0,z=0}} end
local tableA = {id="A",type="poker",settings={location=location(0)},stage={type="waiting"},
    seats={{source=1,cards={{value="ace",class="spd"}}}},sectionIndex=17,spinner=1}
local tableB = {id="B",type="roulette",settings={location=location(2000)},stage={type="waiting"}}
Casinos = {[1]={id=1,settings={location=location(5000)},entities={tableA,tableB},balance=1000,marked_balance=50}}
function AddEventHandler(name, fn) handlers[name]=handlers[name] or {}; table.insert(handlers[name],fn) end
function TriggerEvent(name, ...) for _,fn in ipairs(handlers[name] or {}) do fn(...) end end
function TriggerClientEvent(...) events[#events+1]=table.pack(...) end
function RegisterNetEvent(name,fn) nets[name]=fn end
function RegisterCallback() end
function RegisterCommand() end
function CreateThread() end
function SetTimeout() end
function exports() end
function GetIdentifier(src) return characters[src] end
function GetPlayerName(src) return characters[src] and "Player" end
function GetPlayerPed(src) return positions[src] and src or 0 end
function GetEntityCoords(ped) coordinateReads=coordinateReads+1; return positions[ped] end
function GetPlayers() scans=scans+1; return {"1","2","3","4","5","6","7"} end
lib = {callback={register=function() end}}
dofile("core/server.lua")
dofile("core/proximity_server.lua")
dofile("modules/casino/server.lua")
dofile("modules/poker/server.lua")
function CanManageCasino(src) return managers[src] == true end
local function check(value, msg) assert(value,msg); checks=checks+1 end
local function player(src,x,y,z)
    characters[src]="character-" .. src
    positions[src]=x and {x=x,y=y or 0,z=z or 0} or nil
    RegisterCasinoProximityPlayer(src)
end
local function clear() events={} end
local function received(src,name)
    for _, event in ipairs(events) do if event[2]==src and (not name or event[1]==name) then return event end end
end
local function count(name)
    local n=0; for _,event in ipairs(events) do if not name or event[1]==name then n=n+1 end end; return n
end
player(1,0); player(2,150); player(3,151); player(4,0,0,151)
player(5,-150); player(6,nil); player(7,2000)
-- Only ready, nearby clients receive broadcast events; the radius is inclusive and 3D.
TriggerClientCasinoEvent("stage",-1,1,"A",{type="dealing"},nil,"tail")
check(count()==3 and received(1) and received(2) and received(5), "distance/grid boundary routing failed")
check(not received(3) and not received(4) and not received(6) and not received(7), "far or missing-ped spectator received event")
check(received(1).n==7 and received(1)[7]=="tail", "event arguments/nil positions changed")
check(scans==0, "live broadcast scanned every server player")
-- Explicit replies preserve their target even when the player is far away.
clear(); TriggerClientCasinoEvent("private",3,1,"A","private-card")
check(count()==1 and received(3)[5]=="private-card", "direct player reply was filtered")
-- The casino origin can be far from a placed table; events remain table-local.
clear(); TriggerClientCasinoEvent("stage",-1,1,"B","spin")
check(count()==1 and received(7), "scattered personal-casino table routing failed")
-- Balance updates union the casino/table anchors and current management viewers, without duplicates.
ManagementViewers[1]={[3]=true,[4]=true}; managers[3]=true; managers[4]=false
clear(); TriggerCasinoStateEvent("balance",1,750,25)
check(count()==5 and received(3) and not received(4), "management balance subscription or dedup failed")
-- Entering range hydrates current public state once, without exposing hole cards or outcomes.
clear(); coordinateReads=0; RefreshCasinoProximity()
check(coordinateReads==6, "proximity refresh read each player position more than once")
local snapshot=received(1,"pickle_casinos:syncNearbyCasinos")[3][1]
check(snapshot.balance==1000 and #snapshot.entities==1, "arrival snapshot missing or contains remote table")
check(received(2)[3][1].entities[1].seats[1].cards[1].class=="hidden", "arrival leaked poker hole cards to spectators")
check(snapshot.entities[1].seats[1].cards[1].value=="ace", "arrival erased seated player's private hand")
check(snapshot.entities[1].sectionIndex==nil and snapshot.entities[1].spinner==nil, "arrival leaked private wheel fields")
clear(); RefreshCasinoProximity(); check(count()==0, "stationary players repeatedly received snapshots")
-- Cached-grid candidates are rechecked immediately after teleporting out.
positions[1]={x=10000,y=0,z=0}; clear(); TriggerClientCasinoEvent("stage",-1,1,"A","next")
check(not received(1), "teleported player received stale grid event")
RefreshCasinoProximity(); positions[1]={x=0,y=0,z=0}
clear(); RefreshCasinoProximity()
check(received(1,"pickle_casinos:syncNearbyCasinos") ~= nil, "re-entry did not refresh missed state")
-- Movement to another table of the same casino hydrates the newly nearby table.
positions[1]={x=2000,y=0,z=0}; clear(); RefreshCasinoProximity()
check(received(1)[3][1].entities[1].id=="B", "new table in same casino did not hydrate")
-- Participants with unavailable peds still receive their own game updates.
tableA.seats[2]={source=6,cards={},balance=0}
clear(); TriggerClientCasinoEvent("stage",-1,1,"A","next")
check(received(6)~=nil, "missing-ped participant lost game updates")
-- Cleanup drops subscriptions and source-ID reuse cannot inherit them.
CleanupCasinoPlayer(6); characters[6]="new-character-6"
clear(); TriggerClientCasinoEvent("stage",-1,1,"A","next")
check(not received(6), "reused source ID inherited subscription")
-- Spectator poker delivery shares proximity rules and excludes the private-card owner.
positions[1]={x=0,y=0,z=0}; RegisterCasinoProximityPlayer(1); RefreshCasinoProximity()
clear(); TriggerReclusiveClientEvent("hidden-card",1,1,"A",{class="hidden"})
check(count()==2 and received(2) and received(5) and not received(1), "poker spectator routing leaked or missed players")
check(scans==0, "poker spectator path scanned every player")
-- Configured distance is clamped outside render range, preventing visible stale tables.
Config.CasinoSyncDistance=1; player(2,75); player(5,-76); RefreshCasinoProximity()
clear(); TriggerClientCasinoEvent("stage",-1,1,"A","next")
check(received(2) and not received(5), "minimum render margin not respected")
-- Explicit opt-out preserves the original broadcast delivery and spectator behavior.
Config.PerformanceMode=false
clear(); TriggerClientCasinoEvent("legacy",-1,1,"A","next")
check(count()==1 and events[1][2]==-1, "legacy table broadcast changed")
clear(); TriggerCasinoStateEvent("balance",1,100,20)
check(count()==1 and events[1][2]==-1, "legacy balance broadcast changed")
clear(); TriggerReclusiveClientEvent("hidden-card",1,1,"A",{class="hidden"})
check(count()==6 and not received(1) and scans==1, "legacy poker spectator delivery changed")
clear(); RefreshCasinoProximity(); check(count()==0, "disabled performance mode sent snapshots")
-- Clients subscribe only after acknowledging a completed initial setup.
Config.PerformanceMode=true
source=8; characters[8]="character-8"; positions[8]={x=0,y=0,z=0}
clear(); nets["pickle_casinos:readyForNearbyUpdates"]()
TriggerClientCasinoEvent("stage",-1,1,"A","next")
check(not received(8), "uninitialized client subscribed without setup")
function UpdateHorseTracks() end
function UpdateObjects() end
function PayPendingRefunds() end
Inventory={Items={}}
nets["pickle_casinos:initializePlayer"]()
clear(); TriggerClientCasinoEvent("stage",-1,1,"A","next")
check(not received(8), "server subscribed before client setup finished")
nets["pickle_casinos:readyForNearbyUpdates"]()
clear(); TriggerClientCasinoEvent("stage",-1,1,"A","next")
check(received(8)~=nil, "ready client did not subscribe")
local beforeReady=coordinateReads
nets["pickle_casinos:readyForNearbyUpdates"]()
check(coordinateReads==beforeReady, "duplicate ready acknowledgement repeated initialization")
CleanupCasinoPlayer(8)

-- Client hydration mutates existing entity objects, preserving renderer references.
function RegisterNUICallback() end
function SendNUIMessage() end
local file=assert(io.open("modules/casino/client.lua")); local code=file:read("*a"); file:close()
assert(load((code:gsub("`[^`\n]+`","0")),"@modules/casino/client.lua"))()
local original=Casinos[1].entities[1]
nets["pickle_casinos:syncNearbyCasinos"]({[1]={balance=25,marked_balance=5,entities={{id="A",type="poker",stage={type="results"}}}}})
check(Casinos[1].entities[1]==original and original.stage.type=="results", "snapshot invalidated renderer reference")
check(original.sectionIndex==nil and original.seats==nil, "snapshot retained stale state")
print(("PASS: %d performance-mode regression checks"):format(checks))
