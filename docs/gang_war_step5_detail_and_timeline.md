# Cartel War - Step 5 War Detail + Timeline

Date: 2026-04-03

Step 5 adds a detailed cartel-war view with roster and turn timeline.

## Service Layer

File: `flutter_app/lib/src/services/gang_war_service.dart`

Added:

- `watchEvents({required String warId, int limit = 80})`
  - Streams `gang_war_events` for a given war.
  - Sorts events locally by `turn` then `createdAt`.

## UI Layer

File: `flutter_app/lib/src/screens/gang_war_screen.dart`

Added/updated:

- Active war cards now support:
  - `Detay` button
  - tap-to-open war detail sheet
  - `Savaşı Çöz` action still available

- Resolved war cards now open the same detail sheet on tap.

- New war detail bottom sheet includes:
  - Header + status badge
  - start/end info
  - dual roster view (attacker/defender)
  - real-time war event timeline (`war_created`, `duel_resolved`, `war_resolved`)
  - contextual resolve button (disabled if war already finished)

## Validation

- `dart format` on changed files
- `flutter analyze` on changed files
- Android emulator smoke build/run completed
