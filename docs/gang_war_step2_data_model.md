# Cartel War - Step 2 Data Model

Date: 2026-04-02

This step introduces the Firestore schema + client service skeleton.

## Collections

### `gang_wars/{warId}`
- `attackerGangId`, `attackerGangName`
- `defenderGangId`, `defenderGangName`
- `createdByUid`, `createdByRole`
- `participantLimit` (default: 5)
- `minParticipants` (default: 3)
- `attackerCount`, `defenderCount`
- `attackerPowerSnapshot`, `defenderPowerSnapshot`
- `durationMinutes` (default: 30)
- `pairCooldownUntilEpoch`
- `status`: `recruiting | ready | active | resolved | cancelled`
- `result`: `pending | attackerWin | defenderWin | draw`
- `winnerGangId`
- `createdAt`, `startsAt`, `endsAt`, `resolvedAt`
- `version`

### `gang_war_participants/{warId_uid}`
- `warId`, `uid`, `displayName`
- `gangId`, `gangRole`
- `side`: `attacker | defender`
- `status`: `active | left | knocked | unavailable`
- `powerSnapshot`
- `weaponId`, `armorId`, `knifeId`, `vehicleId`
- `ready`, `turnOrder`
- `joinedAt`, `updatedAt`

### `gang_war_events/{eventId}`
- `warId`, `turn`, `type`
- `side`, `actorUid`, `actorName`
- `payload` (map)
- `createdAt`

### `gang_war_reports/{reportId}`
- `warId`, `viewerUid`, `gangId`
- `result`, `title`, `summary`
- `attackerScore`, `defenderScore`
- `cashDelta`, `xpDelta`
- `createdAt`

## Client Service Skeleton

File: `flutter_app/lib/src/services/gang_war_service.dart`

Implemented methods:
- `createWar(...)`
- `joinWar(...)`
- `leaveWar(...)`
- `markWarStarted(...)`
- `markWarResolved(...)`
- `appendEvent(...)`
- `createReport(...)`
- `watchWar(...)`
- `watchParticipants(...)`
- `fetchRecentWarsForGang(...)`

Notes:
- This is a foundation layer.
- Final authoritative resolution logic should be moved to Cloud Functions in the next step.
