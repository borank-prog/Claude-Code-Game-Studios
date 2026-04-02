# Cartel War - Step 4 UI Integration

Date: 2026-04-03

Step 4 connects the server-authoritative cartel war logic to an in-game UI flow.

## Added Screen

File: `flutter_app/lib/src/screens/gang_war_screen.dart`

Features:

- Commander-ready header
  - Shows eligible member count and minimum member requirement.
  - Shows whether current player has war-start permission (`Lider` / `Sağ Kol`).
  - Shows block reason from `GameState.gangWarStartBlockReason` when unavailable.

- Start war flow
  - `Yeni Kartel Savaşı Başlat` opens a target cartel picker.
  - Target list is sourced from `discoverableGangs` and excludes own cartel.
  - Requires target cartel member count >= `gangWarMinMembersToStart`.
  - Calls `GangWarService.createWarByTargetGang(...)`.

- Active war flow
  - Lists active wars for current cartel.
  - `Savaşı Çöz` action calls `GangWarService.resolveWar(...)`.

- History + report flow
  - Shows recent resolved wars.
  - Streams personal cartel war reports via `watchMyReports(...)`.

## Profile Integration

File: `flutter_app/lib/src/screens/profile_screen.dart`

- Added `Kartel Savaşı` button to cartel section.
- Button opens `GangWarScreen`.

## Validation

- `flutter analyze flutter_app/lib/src/screens/gang_war_screen.dart flutter_app/lib/src/screens/profile_screen.dart`
- Android emulator build/run completed (`flutter run -d emulator-5554 --target lib/main.dart --no-resident`)
