# Cartel War - Step 6 Security Hardening

Date: 2026-04-03

Step 6 focuses on anti-cheat hardening for cartel war collections.

## Firestore Rules Update

File: `firestore.rules`

Changes:

- `gang_wars/{warId}`
  - `read`: authenticated users
  - `create/update/delete`: **false**

- `gang_war_participants/{participantId}`
  - `read`: authenticated users
  - `create/update/delete`: **false**

- `gang_war_events/{eventId}`
  - `read`: authenticated users
  - `create/update/delete`: **false**

- `gang_war_reports/{reportId}`
  - `read`: only `viewerUid == request.auth.uid`
  - `create/update/delete`: **false**

## Why

Previously, parts of the cartel-war write surface were open to authenticated clients.
Now all cartel-war writes are server-authoritative through Cloud Functions, reducing tampering risk.

## Deployment

- Deploy rules with: `firebase deploy --only firestore:rules`
