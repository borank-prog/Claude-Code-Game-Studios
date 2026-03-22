# CartelHood: Street Empire — Game Concept Document

## Overview

CartelHood: Street Empire is a mobile crime RPG where players rise from street-level
thugs to cartel kingpins. Players form gangs with friends, build criminal empires
across a city map, and wage asynchronous turf wars against rival gangs. Inspired by
The Crims' mechanical depth but reimagined with stunning visuals and a social-first
mobile experience.

## Elevator Pitch

Start from the streets, build your crew, run your operations, and conquer the city
— with your friends as your right hand. A visually striking mobile crime RPG where
your gang is your power.

## Core Fantasy

"I built a criminal empire with my friends, and together we run this city."

## Core Verb

**Manage** — your operations, your territory, your crew.

## Unique Hook

The Crims' depth + Idle Mafia's visuals + **asynchronous gang vs gang turf wars** —
a gorgeous mobile crime RPG where social bonds ARE the gameplay.

---

## MDA Analysis

### Mechanics (Rules & Systems)

- **Stamina-based mission system**: Each action costs energy, regenerates over time
- **Territory control**: City divided into neighborhoods, each capturable
- **Gang system**: Create/join gangs, invite friends, level gang collectively
- **Asynchronous PvP**: Raid other gangs' territory, results calculated server-side
- **Economy**: Earn cash + respect from missions, invest in buildings and equipment
- **Progression**: Individual rank (thug → kingpin) + gang rank (crew → cartel)
- **Seasonal reset**: 30-45 day seasons, respect leaderboard determines winner

### Dynamics (Emergent Behavior)

- Players naturally form alliances to control map regions
- Gang chat creates social bonds that increase retention
- Territory disputes create emergent rivalries between gangs
- Resource management tension: invest in personal power vs gang infrastructure
- Stamina scarcity creates strategic planning: "what do I spend energy on?"

### Aesthetics (Player Emotions)

| MDA Aesthetic | Priority | How It Manifests |
|---|---|---|
| **Fellowship** | PRIMARY | Gang bonds, shared victories, coordinated raids |
| **Challenge** | PRIMARY | PvP competition, leaderboard climbing, territory control |
| **Fantasy** | SECONDARY | Crime lord power trip, empire building |
| **Submission** | SECONDARY | Quick sessions, idle progression, satisfying loops |
| **Expression** | TERTIARY | Character customization, gang identity, territory display |

---

## Game Pillars

### 1. Rise Together
> You survive alone, you reign with your crew.

**Design test:** "Is this feature better with a gang? If yes, we're on the right track."

### 2. Street Cred
> Everything revolves around respect — your name makes you powerful, not your wallet.

**Design test:** "Does this mechanic give the player a sense of status? Can other players see it and envy it?"

### 3. Instant Read
> Mobile game — understand in 3 seconds, play in 5. Complexity lives in depth, not surface.

**Design test:** "Can someone playing this on a bus understand it on the first try, one-handed?"

### 4. Eye Candy
> We are not text-based — every screen, every animation must be visually striking.

**Design test:** "Would someone screenshot this and share it on social media?"

### 5. Always a Next Move
> Even when stamina runs out, there's something to plan, a battle to check, a building to upgrade.

**Design test:** "When the player closes the app, do they have a next move in mind?"

---

## Anti-Pillars

1. **No simulation depth** — We don't simulate every detail. This is not GTA — clean, fast, mobile. *Protects: Instant Read*
2. **No pay-to-win** — Spenders get cosmetic advantages, not power. Otherwise turf wars become meaningless. *Protects: Rise Together, Street Cred*
3. **No solo-first design** — No feature is designed as "complete without a gang." Playable solo, but shines with a crew. *Protects: Rise Together*
4. **No deep menu chains** — No menu chain deeper than 3 taps. *Protects: Instant Read*

---

## Core Loop Design

### 30-Second Loop (Moment-to-Moment)
- Tap a mission → watch action unfold → collect rewards (cash, respect, rare loot)
- Stamina consumed per action
- Satisfying feedback: cash counting animation, respect bar filling, level-up effects
- One-handed, quick, rewarding

### 5-Minute Loop (Short-Term Goals)
- Spend earnings on weapons, vehicles, clothing
- Upgrade neighborhood buildings (stash house, crack house, casino)
- Hire crew members, assign them to missions
- Scout rival gang territories
- "One more mission" urge → maximize before stamina runs out

### Session Loop (15-30 Minutes)
- Spend stamina → missions, robberies
- Invest income → building upgrades, crew hiring
- Initiate or defend gang war → territory control
- Check friends' status → alliance contributions
- Natural stop: stamina depleted, battle results pending

### Progression Loop (Days/Weeks)
- **Individual**: Street Thug → Dealer → Enforcer → Underboss → Kingpin (respect ranks)
- **Gang**: Street Crew → Hood Gang → District Force → City Cartel → International Syndicate
- **Territory**: City made of neighborhoods, each controllable and upgradeable
- **Seasons**: Periodic reset (30-45 days) — new race to the top each season

---

## Player Motivation (Self-Determination Theory)

| Need | How CartelHood Fulfills It |
|---|---|
| **Autonomy** | Choose your crime path — guns, drugs, gambling? Your territory strategy is yours |
| **Competence** | Rank climbs, territory expands, gang grows — tangible, visible progress |
| **Relatedness** | Gang with friends, alliances, gang chat, shared enemies |

---

## Player Type Validation

### Primary: Socializer-Killer (Bartle)
Players who form teams to dominate others together.

**Quantic Foundry Profile:**
- Social motivation: HIGH — gang, chat, cooperative strategy
- Competition motivation: HIGH — leaderboards, territory control, PvP
- Collection/Progression: MEDIUM — weapons, cars, rank system

### Secondary Appeal
- **Achievers** — rank system, territory expansion, collection completion
- **Strategists** — territory map planning, resource allocation

### NOT For
- **Explorers** — no open world exploration; map is strategic, not narrative
- **Solo story seekers** — story exists but core experience is social competition
- **Casual/Zen players** — PvP pressure and gang dynamics are not relaxing

### Market Validation

| Reference Game | Similarity | Lesson |
|---|---|---|
| Clash of Clans | Clan wars, async PvP, territory | Social bonds = long-term retention |
| Idle Mafia | Crime theme, idle progression, mobile | Theme works but lacks social depth |
| The Crims | Crime RPG, stamina, respect | Mechanical depth good but zero visuals |
| Grand Mafia | Mobile mafia, gangs, turf wars | High revenue but P2W complaints |

**Market opportunity:** "Visually strong + social gang-focused + non-P2W" mobile crime RPG niche is nearly empty. Grand Mafia generates revenue but player satisfaction is low — that's CartelHood's lane.

---

## Scope & Feasibility

### Engine

**Godot 4.6** — Free, open source, excellent 2D/UI performance, GDScript for rapid
iteration, mature mobile export. Backend is separate regardless of engine.

### Art Style

**Stylized 2D — Neon Street Aesthetic**
- Dark backgrounds, neon highlights, smoke effects
- Illustration-quality character portraits (AI art + manual touch-up pipeline)
- UI: dark theme, gold/red accent colors
- Reference feel: Midnight Club darkness + Hotline Miami stylization + Grand Mafia UI polish
- Solo dev advantage: 2D illustration + UI animations far less work than 3D modeling

### Content Scope (Full Vision)

| Area | Quantity |
|---|---|
| Neighborhoods (territory map) | 25-30 zones |
| Mission types | 8-10 categories (robbery, trafficking, extortion, assassination...) |
| Weapons/equipment | 50+ items |
| Vehicles | 20+ |
| Building types | 10-12 upgradeable structures |
| Rank levels | 20 levels (thug → kingpin) |
| Season duration | 30-45 days |

### MVP Definition

Tests the core question: **"Is forming a gang and fighting for territory with friends fun?"**

| MVP Feature | Detail |
|---|---|
| Mission system | 3 mission types, stamina, cash/XP rewards |
| Character progression | 5 ranks, basic stat system |
| Gang creation | Create, invite, basic gang level |
| Territory map | 8-10 neighborhoods, control mechanic |
| Gang war | Async raids — attack/defend |
| Shop | Weapons + equipment, basic economy |
| Backend | Auth, player data, gang data, leaderboard |

**NOT in MVP:** Vehicles, casino, drug factories, cosmetic shop, season system, chat, alliances.

### Scope Tiers

```
Tier 1 — MVP (Core)           → Mission + Gang + Territory + War
Tier 2 — Social Expansion     → Chat, alliances, gang leaderboard, friend list
Tier 3 — Economy Depth        → Factories, casino, vehicles, trading
Tier 4 — Living World         → Seasons, events, cosmetics, global leaderboard
Tier 5 — Full Vision          → International map, clan wars, story mode
```

### Risk Assessment

| Risk | Level | Mitigation Strategy |
|---|---|---|
| Solo dev + multiplayer backend | HIGH | Use Firebase/Supabase, avoid custom backend |
| Balance (P2W perception) | HIGH | Defined as anti-pillar, early playtesting |
| Content production | MEDIUM | Procedural mission variations, data-driven design |
| Player retention | MEDIUM | Gang bonds = social retention, season system |
| Art production speed | MEDIUM | Stylized 2D + AI-assisted art pipeline |

---

## Monetization Model (F2P)

### Revenue Streams
- **Cosmetics**: Character skins, gang emblems, territory decorations, weapon skins
- **Battle Pass (Seasonal)**: Free + premium tier, cosmetics and progression boosts
- **Stamina refills**: Optional, capped to prevent P2W
- **Convenience**: Extra building slots, faster upgrade timers (cosmetic-adjacent)

### Hard Rules
- No stat-boosting items for purchase
- No exclusive weapons/equipment behind paywall
- Paying players look cooler, not stronger
- Gang war matchmaking ignores spending level

---

## Platform & Technical

- **Platforms**: Android (Google Play) + iOS (App Store)
- **Engine**: Godot 4.6
- **Language**: GDScript
- **Backend**: Firebase or Supabase (auth, database, cloud functions)
- **Networking**: REST API + WebSocket for real-time gang events
- **Minimum Target**: Android 8.0+ / iOS 14+

---

## Next Steps

1. `/setup-engine godot 4.6` — Configure engine and populate version-aware reference docs
2. `/design-review design/gdd/game-concept.md` — Validate document completeness
3. `/map-systems` — Decompose concept into individual systems with dependencies and priorities
4. `/design-system` — Author per-system GDDs (guided, section-by-section)
5. `/prototype` — Prototype the core loop (mission → reward → upgrade → raid)
6. `/sprint-plan new` — Plan the first development sprint
