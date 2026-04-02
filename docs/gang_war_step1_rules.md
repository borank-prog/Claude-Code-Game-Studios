# Cartel War - Step 1 Rules

Date: 2026-04-02

This file captures the agreed game rules before full implementation.

## Core Format

- Mode: 5v5 asynchronous cartel war.
- War duration: 30 minutes.
- Team readiness requirement: minimum 3 eligible members.
- Starter permission: only `Lider` or `Sağ Kol`.

## Eligibility

- A member is not eligible if their status is `hospital` or `prison` and `statusUntilEpoch` is still active.
- Eligible member list is sorted by power and capped to top 5.

## Safety and Fairness

- Pair cooldown target: 30 minutes between same-cartel matchups.
- Snapshot principle: war should use participant snapshot (power/loadout at war start) in next implementation steps.

## Current Code Hooks

- `GameState.canInitiateGangWar`
- `GameState.gangWarEligibleMembers`
- `GameState.gangWarEligibleMemberCount`
- `GameState.gangWarStartBlockReason`
- `GameState.gangWarDurationMinutes`
- `GameState.gangWarPairCooldownMinutes`
