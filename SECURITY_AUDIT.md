# pickle_casinos — Security Hardening Checklist

Date: 2026-10-24 · Baseline: `development` @ `38a52a9`

This is a remediation checklist from a source review of the server-side code. It covers which server-side checks are missing and how to add them. Nothing here has been run against a live server; each item comes from reading the code.

General rule for this resource: **every value that arrives through `RegisterNetEvent`, `RegisterCallback`, or `lib.callback.register` is attacker-controlled** — type, range, and meaning. The fixes below all come down to validating on the server and keeping secret state on the server.

---

## Priority order

| # | Area | Priority |
|---|---|---|
| 1 | Poker blind / entity setting validation | Critical |
| 2 | Secret game state sent to clients | Critical |
| 3 | Integer-only wagers and purchase amounts | High |
| 4 | Lucky ticket accounting | High |
| 5 | Employees callbacks authorization | High |
| 6 | Turn / seat ownership in table games | High |
| 7 | Entity-type checks on game callbacks | High |
| 8 | Owner-controlled economic settings | High |
| 9 | Client-only feature gates | Medium |
| 10 | Disconnect cleanup and stuck game loops | Medium |
| 11 | Information exposure and rate limiting | Medium |
| 12 | Smaller correctness issues | Low |

---

## 1. Entity settings are stored without validation (Critical)

**Where:** `modules/casino/server.lua` — `EnsureGameSettings` (~L210), `createCasinoEntity` (~L771), `updateCasinoEntitySetting` (~L827).

**Problem:** Client-supplied settings (`smallBlind`, `bigBlind`, `maxWager`, `spinPrice`, `store`, `game`, `location`, models, `vip`) are copied as-is. `updateCasinoEntitySetting` writes `entity.settings[variable] = value` for *any* key. In personal casinos this is reachable by any player who owns a placed entity. The poker engine trusts the blind values arithmetically, and in the personal casino chips are cash.

**Fix:**
- Whitelist the settable keys per entity type, and reject everything else.
- Clamp numeric settings to sane integer ranges, for example:
  - `smallBlind`: integer ≥ 1
  - `bigBlind`: integer ≥ 2 × `smallBlind`
  - `maxWager`: integer in [100, `Config.MaxWager`]
  - `spinPrice`: integer ≥ 0
  - `store`: an existing index into `Config.CreatorOptions.stores`
  - `game`: an existing key in `Config.Slots`
  - models: must appear in the matching `Config.CreatorOptions` list
- Apply the same validator in both `createCasinoEntity` and `updateCasinoEntitySetting`.
- Don't let settings change while a game is in progress. Reject the update unless the entity is idle, or defer it until then. Today `InitializeCasinoEntity(..., true)` rebuilds `seats` / `players` even with `dataOnly`, which wipes live seats, escrowed baccarat wagers and poker seat balances.

```lua
local function int(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    if v ~= math.floor(v) then return nil end
    if (lo and v < lo) or (hi and v > hi) then return nil end
    return v
end
```

---

## 2. Secret game state is replicated to clients (Critical)

**Where:** `pickle_casinos:initializePlayer` (`modules/casino/server.lua` ~L643) sends the whole `Casinos` table. `RegisterCasino` and `createCasinoEntity` broadcast whole entities.

**Problem:** Entities are live game objects. For poker, `entity.seats[i].cards` holds real hole cards during a hand (`modules/poker/server.lua` ~L218). The lucky wheel's predetermined `sectionIndex` is also stored on the entity. Any client can request the full table at any time.

**Fix:**
- Build an explicit public view for replication, such as `GetPublicCasino(casino)` / `GetPublicEntity(entity)`. Copy only `id`, `type`, `settings`, and display-safe state. Strip `cards`, `sectionIndex`, `spinner`, deck state, and per-player wager internals.
- Use that view everywhere `Casinos` or an entity goes out through `TriggerClientEvent`.
- Keep `vip_players` out of the broadcast. Send each player only their own VIP status.

---

## 3. Wagers and amounts must be positive integers (High)

**Where:**
- `modules/blackjack/server.lua` `setWager` (~L524): no validation at all
- `modules/wheel/server.lua` `setWager` / `repeatWager` (~L227/264)
- `modules/roulette/shared.lua` and `modules/thunder_roulette/shared.lua` `Apply*Wagers`
- `modules/horseracing/server.lua` `setWager` (~L179)
- `modules/stores/server.lua` `storePurchase` (~L6)
- `modules/cashier/server.lua` `casinoExchange` (~L32)
- `modules/casino/server.lua` `startCasinoTransfer` (~L843)
- `modules/poker/server.lua` `sendPokerAction` raise amount (~L636)

**Problem:** These handlers accept fractional numbers, and some also accept `NaN`/`inf`/strings/tables. Inventories (ox_inventory confirmed) round item counts when adding and removing. Game payouts are computed on the unrounded value. That mismatch lets a player play without paying the full stake. Non-numeric values can also crash a game's loop thread and freeze the table.

**Fix:**
- Reuse one validator (like `int()` above) everywhere a quantity arrives from the client.
- Baccarat's `ValidateBaccaratWagers` (`modules/baccarat/server.lua` ~L417) is already the right pattern: type check, NaN check, `>= 0`, integer, per-field cap, total cap. Apply the same to the other games.
- Enforce `betRange` (min and max) on the server in every game. Blackjack doesn't check `maxWager` at all.
- Horse racing: build the wager table from fixed indices `1..12` only, and compute totals with the same loop used for charging. Today the cap uses `#wagers` while charging uses `pairs`.
- Validate `casinoId` / `entityId` and confirm that the entity exists and has the expected type.
- Make removals authoritative: check the return value of `Inventory.RemoveItem` / `RemoveMoney`, and abort the round or purchase if it fails.

---

## 4. Lucky ticket progress is recorded before the stake is final (High)

**Where:** `RegisterLuckyTicketWager` calls in `modules/baccarat/server.lua` (`setWager`/`repeatWager`) and `modules/poker/server.lua` (`JoinPokerEntity`, replenish); `modules/lucky_ticket/server.lua`.

**Problem:** Progress is recorded when chips go into escrow (a baccarat bet before the round starts, a poker buy-in). When that escrow is refunded (bet lowered, seat left), the progress isn't reversed.

**Fix:**
- Record ticket progress only for stakes that were actually committed. For baccarat, that's at `StartBaccaratGame`. For poker, record chips actually put into the pot (blinds, calls, raises), not the buy-in.
- In `loadProgress`, guard against concurrent first loads, for example with a `loading[identifier]` promise or queue, so two near-simultaneous wagers can't each load a stale row.

---

## 5. Employees callbacks over-trust the caller (High)

**Where:** `modules/casino/employees_server.lua`.

**Problem:**
- `fireEmployee` (~L73-84) skips its employee check when the casino has no job configured. The handler then sets the target's job to `unemployed` for any online player id.
- `hirePlayer` (~L90-97) assigns the casino job to any online player id, with no consent or proximity check.
- `setEmployeeGrade` accepts any grade number.

**Fix:**
- Require `GetCasinoJobName(cid)` to be non-nil for **all** employee operations, and always require `GetPlayerJobName(tgt) == jobName` for fire and grade changes.
- For hiring, require the target to be within range (server-side distance) and to accept an invite (a pending-offer table with a short TTL that the target confirms).
- Clamp `grade` to the job's existing grades and below the caller's own grade.

---

## 6. Turn and seat ownership (High)

**Where:**
- `modules/blackjack/server.lua` `performAction` (~L511)
- `Join*Entity` in blackjack, roulette, thunder roulette, baccarat and poker

**Problem:**
- Blackjack `performAction` only checks that *some* turn is active. It doesn't check that the turn belongs to the caller's seat.
- In the "already seated" branch, `Join*Entity` writes `entity.seats[seatId].inSeat = true` using the **client-supplied** `seatId`, not the seat that was found. Out-of-range `seatId` values index `nil`.

**Fix:**
- In blackjack `performAction`, require `entity.stage.seat == info.seatId`, and whitelist `action` to `hit` / `stand` / `double` / `split`.
- In the join functions, validate `seatId` as an integer within the seat range (excluding the dealer seat 0). In the already-seated branch, use the found index `i`.
- Poker already checks turn ownership correctly. Use it as the reference.

---

## 7. Callbacks don't check entity type (High)

**Where:**
- `modules/luckywheel/server.lua` `requestSpin` (~L167)
- `modules/wheel/server.lua` `requestSeat` (~L195)
- `modules/slots/server.lua` `requestSeat` (~L180)
- `modules/horseracing/server.lua` `setWager`

**Problem:** These callbacks act on whatever entity id they receive. `requestSpin` rewrites `stage` and `spinner` on any entity. A table game whose stage is overwritten never leaves that state, so it freezes until restart, and any escrowed wagers stay locked.

**Fix:**
- Check `entity.type` in every handler: `"luckywheel"`, `"wheel"`, `"slot"`, `"horseracing"` respectively.
- Lucky wheel: add a timeout. If `startSpin` doesn't arrive within a few seconds of `requestSpin`, reset the stage to `waiting`, clear `spinner`, and refund. Also clear `spinner` in `playerDropped`.
- Apply the spin cooldown at `requestSpin` time (when payment is taken), not after the 15 s animation.
- Remove the stray `cb(false)` calls in `startSpin`, which is a net event and has no `cb`.

---

## 8. Owner-controlled economic settings (High)

**Where:** `updateCasinoSetting` (`modules/casino/server.lua` ~L699); cashier exchange (`modules/cashier/server.lua`); lucky wheel `spinPrice`.

**Problem:** Casino owners are ordinary players. They can set `moneyExchangeRate`, `dirtyExchangeRate`, `vipPrice`, and entity `spinPrice` to any number, including negative or extreme values. Chips minted at one casino can be redeemed wherever the same `chipItem` is accepted. Selling at an **unowned** casino has no balance limit.

**Fix:**
- Clamp exchange rates to a config-defined range (for example, `Config.ExchangeRateLimits = {min = 50, max = 100}`) so buying never yields more chips than money paid.
- Clamp `spinPrice` and `vipPrice` to integers ≥ 0.
- Require a unique `chipItem` per casino (enforce it in admin `updateCasinoSetting` / `createCasino`), or tie chip redemption to the issuing casino.
- Cap per-transaction sell amounts at unowned casinos, for example with `Config.MaximumChipPurchaseAmount`.

---

## 9. Feature gates exist only on the client (Medium)

**Where:** cashier, store, game join callbacks.

**Not enforced server-side today:**
- `settings.vip` (VIP-only games). `IsPlayerCasinoVIP` exists but is never called.
- `settings.isOpen`
- `settings.cashEnabled` / `settings.markedEnabled`
- `Config.MaximumChipPurchaseAmount` / `Config.MaximumItemPurchaseAmount`
- Interaction distance for cashier, store, VIP purchase and horse-racing bets

**Fix:** Add a shared server guard and call it at the top of every player-facing handler:

```lua
function CanUseCasinoEntity(source, casinoId, entityId, expectedType)
    local casino = Casinos[casinoId]; if not casino then return false end
    if not casino.settings.isOpen and not CanManageCasino(source, casinoId) then return false end
    local entity = GetCasinoEntity(casinoId, entityId)
    if not entity or (expectedType and entity.type ~= expectedType) then return false end
    if entity.settings.vip and not IsPlayerCasinoVIP(source, casinoId) then return false end
    local ped = GetPlayerPed(source)
    if #(GetEntityCoords(ped) - entity.settings.location.coords) > (Config.InteractDistance + 5.0) then return false end
    return true, casino, entity
end
```

Then check `cashEnabled` / `markedEnabled` and the max-amount configs in `casinoExchange` and `storePurchase`.

---

## 10. Disconnect cleanup and stuck loops (Medium)

**Problem:**
- The wheel game has **no `playerDropped` handler**. Departed players stay in `entity.players`, and later frameworks lookups on their stale source can error inside the game thread.
- Game loops run in `CreateThread` without protection. One error leaves the entity stuck in a non-waiting stage forever.
- Lucky wheel rewards are paid 15 s after the spin. If the player has left, the casino balance is already debited, and a nil player object raises an error.
- Several leave/refund paths (`LeaveBaccaratEntity` on drop) credit a player whose framework object may already be gone.

**Fix:**
- Add a `playerDropped` handler for the wheel that removes `entity.players[source]`.
- Wrap each game round body in `pcall`. On error, log it, refund escrowed stakes for that round, and restart the lobby so the table recovers.
- Before paying out after a delay, check that the player is still online (`GetPlayerPing(src) > 0` / the framework player exists). Pay to the identifier instead of the source, or roll back the casino debit.
- Make refund-on-drop write against the identifier (offline-safe), or refund before the framework drops the player.

---

## 11. Information exposure and rate limiting (Medium)

- `getPlayers` (`modules/casino/server.lua` ~L483) returns every online player's identifier and character name to any caller. Restrict it to `IsPlayerAdmin`, which matches its only use in the owner picker.
- `getHorseRacingInfo` returns all bettors' wagers. Return only the caller's.
- `initializePlayer` has no rate limit and sends large payloads. Allow it once per session, or throttle it per source.
- `PerformCooldownProcess` covers only some wager events. Also apply it, or a lighter per-event throttle, to `casinoExchange`, `storePurchase`, `requestSpin`, poker join/leave, `startCasinoTransfer`, and the employees callbacks.
- QB bridge `IsPlayerAdmin` (`bridge/qb/server.lua`) returns true for anyone with the generic `command` ACE. Use only `Config.AdminGroups`.

---

## 12. Smaller correctness issues (Low)

- `createCasino`: `if not type(data) == "table"` is always false. Use `if type(data) ~= "table" then return end`.
- `storePurchase`: `ShowNotification(_L("insufficient_funds"))` is missing the `source` argument.
- `startCasinoTransfer`: validate `transferInfo` is a table, `amount` is a positive integer, and `transferType`/`balanceType` are known values.
- Slots: `PendingSpins` is never cleaned up when spins aren't redeemed. Expire entries after a timeout or on `playerDropped`. Each free spin re-ends the same transaction id, which skews the P/L log.
- Baccarat third-card rule: `playerThirdCard` isn't the card that was actually dealt, and `value ~= 8` compares a string to a number. This is a game-integrity bug, not a security one.
- Audio zones: cap the number of zones and points per casino, and validate point coordinates as numbers.
- `StartCasinoGameplayTransaction` ids (`os.time() .. "_" .. source`) can collide within the same second. Add a counter.

---

## Regression tests to add

Use a headless harness that mocks `source`, the bridge (`GetMoney`, `AddMoney`, `RemoveMoney`, `Inventory.*` with ox-style rounding), `Wait`, and `CreateThread`. At minimum, check that:

1. Every wager and amount handler rejects `nil`, strings, tables, `NaN`, `±inf`, negatives, non-integers, and values above the cap, and that no balance changes as a result.
2. Entity settings updates reject unknown keys and out-of-range values, and are refused while a game is active.
3. Replicated casino and entity payloads never contain `cards`, `sectionIndex`, `spinner`, or `vip_players`.
4. Raising and then lowering a baccarat bet, or joining and leaving poker, leaves lucky-ticket progress unchanged.
5. `fireEmployee` / `hirePlayer` / `setEmployeeGrade` fail for non-employees, casinos without a job, and out-of-range grades.
6. Blackjack `performAction` from a seat other than `stage.seat` is ignored.
7. `requestSpin` on a non-luckywheel entity is rejected, and an abandoned spin resets after the timeout.
8. A player disconnecting at each stage of each game (waiting, after escrow, mid-round, before payout) leaves the table able to start its next round, with stakes either refunded or forfeited consistently.
9. A game round that throws an error recovers to `waiting`.
10. Exchange rates and `spinPrice` outside the configured range are rejected.

---

## Fix status (branch `security-audit-ticker-24102026`)

These changes are syntax-checked only. They have **not** been run on a FiveM server yet, so test each game before merging.

| # | Area | Status |
|---|---|---|
| 1 | Entity settings validation | Done. Settings keys are whitelisted per type, all values are clamped (blinds ≥ 1, big blind ≥ small blind, `maxWager` ≥ 100, `spinPrice` ≥ 0, valid store index and slot game), and edits/deletes are refused while the entity is in use. |
| 2 | Secret state replication | Done. Clients now receive `GetPublicCasino` / `GetPublicCasinoEntity` (hole cards, wheel outcome, spinner and VIP lists removed). Every poker seat broadcast is obfuscated, and showdown shows only winners' hands plus each player's own. |
| 3 | Integer wagers/amounts | Done for every game, the cashier, the store and transfers. `RemoveCasinoChips` / `TryRemoveMoney` now return whether the full amount was really removed, and callers abort if it wasn't. Payouts are floored to whole chips. |
| 4 | Lucky ticket accounting | Done. Baccarat records progress at round start; poker records chips actually put into the pot at the end of each hand. Concurrent DB loads are merged. |
| 5 | Employees | Done: firing needs a job-owned casino and a real employee, grades must exist, and hiring needs the target within 10 m and not already employed. The hired player now gets an Accept/Decline dialog (20 s, no answer counts as a decline). Non-admin managers can only fire or re-grade employees ranked below them, and only assign grades below their own. |
| 6 | Turn / seat ownership | Done. Blackjack actions must come from the active seat (one action per turn, known actions only); seat indexes are validated in every table game. |
| 7 | Entity-type checks | Done for lucky wheel, wheel, slots, horse racing and all table joins (`CanUseCasinoEntity`). Lucky wheel spins expire after 30 s with a refund, and the cooldown starts at payment. |
| 8 | Owner economic settings | Done. Exchange rates are limited by `Config.ExchangeRateLimits` (default 1–100, also applied to stored values on load); VIP and spin prices must be integers ≥ 0. Chip items are now verified when an admin sets them: the item must exist in the inventory and must not already be another casino's chip item, and the admin is told why otherwise. Existing casinos with a missing or shared chip item get a console warning at startup but are not changed. |
| 9 | Client-only gates | Done. `isOpen`, VIP-only entities, `cashEnabled` / `markedEnabled`, max chip/item purchase amounts and interaction distance are now checked on the server. The distance check is skipped when the server has no ped for the player (OneSync off). |
| 10 | Disconnects / stuck loops | Done. The wheel cleans up on disconnect; game rounds run in `CreateSafeGameThread` and on an error refund unpaid stakes and reopen the table. Refunds owed to players who have disconnected (baccarat bets placed during the waiting stage, poker seat balances, lucky-wheel spins and tickets, crash refunds) are stored in `pickle_casino_pending_refunds` and paid when that character next loads. Bets already in play when a player leaves a blackjack, roulette or wheel round are still forfeited, as before. |
| 11 | Exposure / rate limits | Done. `getPlayers` is admin-only, horse-racing info no longer includes other bettors, `initializePlayer` is throttled to once per 10 s, the cooldown applies to the economy events, and the QB admin check no longer accepts the generic `command` ACE. |
| 12 | Smaller issues | Done: the `createCasino` type check, the store notification, transfer validation, slots logging once per round, a unique transaction-id counter, audio-zone limits, the baccarat third-card tableau and the missing `invalid_amount` locale string. |

New config key: `Config.ExchangeRateLimits`. New DB table (created automatically): `pickle_casino_pending_refunds`. New bridge function: `GetPlayerJobGrade` (ESX and QB; add it to a custom bridge if you use one). New locale keys: `invalid_amount`, `casino_entity_in_use`, `invalid_wager`, `employee_hire_offer_header`, `employee_hire_offer_content`, `employee_hire_accept`, `employee_hire_decline`, `employee_hire_waiting`, `pending_refund_paid`, `chip_item_invalid`, `chip_item_unverified`, `chip_item_not_found`, `chip_item_in_use`. If your server has other locale files, add these keys to them too.
