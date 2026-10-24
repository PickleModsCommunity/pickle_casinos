# Performance mode

Performance mode is on by default:

```lua
Config.PerformanceMode = true
Config.CasinoSyncDistance = 150.0
Config.PerformanceUpdateInterval = 1000
```

Live table events (seats, wagers, cards, stages, pots and results) go to nearby players instead of the entire server. Poker spectator events use the same routing. Casino balance changes go to nearby players and authorized managers who explicitly opened the management screen. Direct player replies and private cards keep their original recipient.

The distance is measured in three dimensions around each table. Casino-wide balance updates also use the casino entrance and every placed table as proximity anchors, supporting personal casinos whose tables are spread across the map. The effective radius is at least `Config.RenderDistance + 25` metres so spectators normally receive current state before a table renders.

A shared server-side spatial index refreshes once per interval, clamped to 250?5000 ms, with one coordinate read per player per refresh. Live sends recheck candidate positions so a player teleporting away stops receiving updates immediately. New arrivals receive current state on the next refresh; stationary players do not repeatedly receive snapshots. Poker snapshots hide other players' hole cards while preserving the seated player's own hand.

Subscriptions begin after the client acknowledges that initial casino setup has finished. They are cleared on character unload/disconnect. Spectator routing uses server-side ped coordinates; if a participant's ped is temporarily unavailable, their existing game subscription continues without broadcasting to spectators.

Initial casino definitions and infrequent structural changes (blips, layout, ownership, audio zones and placed map objects) still synchronize globally. This keeps far-away clients' map and rendering definitions correct. Horse-race stage updates already use each track's proximity radius.

Set `Config.PerformanceMode = false` and restart the resource to restore the previous delivery behavior. Restart after changing the radius or refresh interval as well.

Live server load and bandwidth measurements have not been performed.
