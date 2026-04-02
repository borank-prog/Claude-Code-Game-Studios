# Cartel War - Step 3 Authoritative Logic

Date: 2026-04-03

This step moves cartel war resolution to server-authoritative Cloud Functions.

## Added Cloud Functions

File: `functions/index.js`

- `createGangWar` (callable)
  - Only `Lider` or `Sağ Kol` can create.
  - Validates both cartels exist and are different.
  - Enforces pair cooldown between same cartel matchup.
  - Builds top eligible 5v5 participant snapshots (status must be active).
  - Creates:
    - `gang_wars/{warId}` (`status: active`)
    - `gang_war_participants/{warId_uid}`
    - `gang_war_events` (`war_created`)

- `resolveGangWar` (callable)
  - Requires commander authorization from one of the two cartels.
  - Resolves round-by-round duel scores from snapshot power + loadout matchup.
  - Applies rewards/punishments:
    - gang vault transfer
    - gang respect change
    - player XP/cash updates
  - Writes:
    - `gang_war_reports/{warId_uid}`
    - `users/{uid}/inbox/*` as `attack_report` (`attackType: gang_war`)
    - `gang_war_events` (`duel_resolved`, `war_resolved`)
  - Finalizes `gang_wars/{warId}` (`status: resolved`)

- `resolveExpiredGangWars` (scheduled, every 5 minutes)
  - Scans active wars and resolves ones whose end time has passed.

## Updated Client Service

File: `flutter_app/lib/src/services/gang_war_service.dart`

Added methods:

- `createWarByTargetGang(...)` → calls `createGangWar`
- `resolveWar(...)` → calls `resolveGangWar`
- `watchMyReports(...)` for `gang_war_reports`

## Notes

- Step 3 uses snapshot-based combat logic for deterministic fairness.
- UI invocation and dedicated cartel-war screens are next step candidates.
