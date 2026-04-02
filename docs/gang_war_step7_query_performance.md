# Cartel War - Step 7 Query Performance + Indexing

Date: 2026-04-03

Step 7 improves cartel-war responsiveness by making reads deterministic and index-friendly.

## Backend Optimization

File: `functions/index.js`

`createGangWar` pair checks were optimized:

- Active-war collision check now queries only active statuses:
  - `pairKey == ...` + `status in [recruiting, ready, active]` + `limit(1)`
- Cooldown check now reads only latest cooldown doc:
  - `pairKey == ...` + `orderBy(pairCooldownUntilEpoch desc)` + `limit(1)`

This removes full scan-like behavior on repeated pair lookups.

## Client Query Optimization

File: `flutter_app/lib/src/services/gang_war_service.dart`

- `watchParticipants(...)`
  - Added `orderBy('powerSnapshot', descending: true)`.
- `watchEvents(...)`
  - Added `orderBy('turn')` + `orderBy('createdAt')`.
  - Removed local in-memory sort.
- `watchMyReports(...)`
  - Added `orderBy('createdAt', descending: true)`.
  - Removed local in-memory sort.

This reduces client CPU work and stabilizes list ordering.

## Firestore Indexes

Files:
- `firestore.indexes.json` (new)
- `firebase.json` (updated to include indexes path)

Added composite indexes for:

- `gang_wars`:
  - `pairKey + status`
  - `pairKey + pairCooldownUntilEpoch(desc)`
  - `attackerGangId + createdAt(desc)`
  - `defenderGangId + createdAt(desc)`
- `gang_war_participants`:
  - `warId + status + powerSnapshot(desc)`
- `gang_war_events`:
  - `warId + turn + createdAt`
- `gang_war_reports`:
  - `viewerUid + createdAt(desc)`

## Deployment Notes

- Deploy rules + indexes:
  - `firebase deploy --only firestore`
- If index build is in progress, Firestore may take a short time before all queries become fast globally.