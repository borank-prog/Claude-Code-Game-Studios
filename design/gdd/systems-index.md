# Systems Index: CartelHood — Street Empire

> **Status**: Approved
> **Created**: 2026-03-22
> **Last Updated**: 2026-03-22
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

CartelHood is a social-first mobile crime RPG built around four interlocking loop
tiers: missions (30s), investment (5min), gang war sessions (15-30min), and seasonal
progression (weeks). The game requires 34 systems spanning player data, crime
gameplay, gang mechanics, territory control, economy, backend infrastructure,
monetization, and polish. The core hypothesis — "is forming a gang and fighting for
territory with friends fun?" — requires 18 MVP systems to test.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|---|---|---|---|---|---|
| 1 | Player Data | Core | MVP | Designed | design/gdd/player-data.md | — |
| 2 | Economy (Currency) | Economy | MVP | Designed | design/gdd/economy-currency.md | — |
| 3 | Item Database | Economy | MVP | Designed | design/gdd/item-database.md | — |
| 4 | Auth & Account | Persistence | MVP | Designed | design/gdd/auth-account.md | — |
| 5 | UI Framework | UI | MVP | Designed | design/gdd/ui-framework.md | — |
| 6 | Stamina System | Core | MVP | Designed | design/gdd/stamina-system.md | Player Data |
| 7 | Character Progression | Progression | MVP | Designed | design/gdd/character-progression.md | Player Data, Economy |
| 8 | Inventory & Equipment | Economy | MVP | Designed | design/gdd/inventory-equipment.md | Player Data, Item Database |
| 9 | Cloud Save | Persistence | MVP | Designed | design/gdd/cloud-save.md | Auth & Account, Player Data |
| 10 | Mission System | Gameplay | MVP | Designed | design/gdd/mission-system.md | Stamina, Character Progression, Economy, Inventory |
| 11 | Territory Map | Gameplay | MVP | Designed | design/gdd/territory-map.md | Economy |
| 12 | Gang System | Gameplay | MVP | Designed | design/gdd/gang-system.md | Player Data, Economy, Auth & Account |
| 13 | Building System | Gameplay | MVP | Designed | design/gdd/building-system.md | Territory Map, Economy |
| 14 | Shop System | Economy | MVP | Designed | design/gdd/shop-system.md | Economy, Item Database, Inventory |
| 15 | Gang War (Async PvP) | Gameplay | MVP | Designed | design/gdd/gang-war.md | Gang System, Territory Map, Character Progression, Inventory |
| 16 | HUD & Feedback | UI | MVP | Designed | design/gdd/hud-feedback.md | UI Framework, Economy, Stamina |
| 17 | Character Visuals | UI | MVP | Designed | design/gdd/character-visuals.md | Inventory & Equipment, UI Framework |
| 18 | Map UI | UI | MVP | Designed | design/gdd/map-ui.md | Territory Map, UI Framework |
| 19 | Chat System | Social | Tier 2 | Not Started | — | Gang System, Auth & Account |
| 20 | Alliance System | Social | Tier 2 | Not Started | — | Gang System |
| 21 | Leaderboard | Social | Tier 2 | Not Started | — | Character Progression, Gang System |
| 22 | Push Notifications | Infra | Tier 2 | Not Started | — | Auth & Account, Gang War, Stamina |
| 23 | Drug Factory | Gameplay | Tier 3 | Not Started | — | Building System, Economy |
| 24 | Casino | Gameplay | Tier 3 | Not Started | — | Economy, UI Framework |
| 25 | Vehicle System | Economy | Tier 3 | Not Started | — | Item Database, Economy, Mission System |
| 26 | Trading System | Economy | Tier 3 | Not Started | — | Inventory, Economy, Gang System |
| 27 | Season System | Meta | Tier 4 | Not Started | — | Leaderboard, Economy, Gang War |
| 28 | IAP (In-App Purchase) | Monetization | Tier 4 | Not Started | — | Auth & Account, Economy |
| 29 | Cosmetic System | Monetization | Tier 4 | Not Started | — | Character Visuals, Item Database |
| 30 | Battle Pass | Monetization | Tier 4 | Not Started | — | Season System, IAP, Cosmetic System |
| 31 | Daily Rewards | Meta | Tier 4 | Not Started | — | Economy, Player Data |
| 32 | Tutorial/Onboarding | Meta | Tier 5 | Not Started | — | Mission System, UI Framework |
| 33 | Achievement System | Meta | Tier 5 | Not Started | — | Character Progression, Mission System, Gang War |
| 34 | Analytics | Infra | Tier 5 | Not Started | — | Auth & Account |

---

## Categories

| Category | Description |
|---|---|
| **Core** | Foundation data systems everything depends on |
| **Gameplay** | The systems that make the game fun — missions, territory, gangs, combat |
| **Economy** | Resource creation, consumption, items, trading |
| **Progression** | How the player grows over time — ranks, XP, stats |
| **Social** | Multiplayer social features — chat, alliances, leaderboards |
| **UI** | Player-facing screens, HUD, map, feedback |
| **Persistence** | Save state, cloud sync, authentication |
| **Infra** | Backend infrastructure — notifications, analytics |
| **Monetization** | Revenue systems — IAP, battle pass, cosmetics |
| **Meta** | Outside core loop — tutorials, achievements, daily rewards |

---

## Priority Tiers

| Tier | Definition | Target | Count |
|---|---|---|---|
| **MVP** | Core loop + gang war çalışır durumda | İlk oynanabilir prototip | 18 |
| **Tier 2 — Social** | Sosyal bağ, retention | Vertical Slice | 4 |
| **Tier 3 — Economy** | İçerik derinliği | Alpha | 4 |
| **Tier 4 — Living World** | Monetizasyon + uzun vade | Beta | 5 |
| **Tier 5 — Polish** | Yeni oyuncu, analytics | Release | 3 |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Player Data** — Oyuncu profili, statlar — her sistemin okuduğu veri kaynağı
2. **Economy (Currency)** — Para + Saygınlık — tüm ödül/maliyet sistemlerinin temeli
3. **Item Database** — Eşya tanımları — envanter, mağaza, ekipman bundan okur
4. **Auth & Account** — Giriş/kayıt — backend iletişiminin kapısı
5. **UI Framework** — Ekran yönetimi, navigasyon — tüm UI'ların oturduğu iskelet

### Core Layer (depends on foundation)

6. **Stamina System** — depends on: Player Data
7. **Character Progression** — depends on: Player Data, Economy
8. **Inventory & Equipment** — depends on: Player Data, Item Database
9. **Cloud Save** — depends on: Auth & Account, Player Data
10. **Territory Map** — depends on: Economy

### Feature Layer (depends on core)

11. **Mission System** — depends on: Stamina, Character Progression, Economy, Inventory
12. **Gang System** — depends on: Player Data, Economy, Auth & Account
13. **Building System** — depends on: Territory Map, Economy
14. **Shop System** — depends on: Economy, Item Database, Inventory

### Advanced Feature Layer (depends on features)

15. **Gang War (Async PvP)** — depends on: Gang System, Territory Map, Character Progression, Inventory
16. **Leaderboard** — depends on: Character Progression, Gang System
17. **Alliance System** — depends on: Gang System
18. **Chat System** — depends on: Gang System, Auth & Account
19. **Push Notifications** — depends on: Auth & Account, Gang War, Stamina

### Economy Depth Layer (Tier 3)

20. **Drug Factory** — depends on: Building System, Economy
21. **Casino** — depends on: Economy, UI Framework
22. **Vehicle System** — depends on: Item Database, Economy, Mission System
23. **Trading System** — depends on: Inventory, Economy, Gang System

### Presentation Layer

24. **HUD & Feedback** — depends on: UI Framework, Economy, Stamina
25. **Character Visuals** — depends on: Inventory & Equipment, UI Framework
26. **Map UI** — depends on: Territory Map, UI Framework

### Monetization & Polish Layer

27. **Season System** — depends on: Leaderboard, Economy, Gang War
28. **IAP** — depends on: Auth & Account, Economy
29. **Cosmetic System** — depends on: Character Visuals, Item Database
30. **Battle Pass** — depends on: Season System, IAP, Cosmetic System
31. **Daily Rewards** — depends on: Economy, Player Data
32. **Tutorial/Onboarding** — depends on: Mission System, UI Framework
33. **Achievement System** — depends on: Character Progression, Mission System, Gang War
34. **Analytics** — depends on: Auth & Account

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|---|---|---|---|---|---|
| 1 | Player Data | MVP | Foundation | systems-designer, lead-programmer | S |
| 2 | Economy (Currency) | MVP | Foundation | economy-designer, systems-designer | M |
| 3 | Item Database | MVP | Foundation | systems-designer, economy-designer | S |
| 4 | Auth & Account | MVP | Foundation | network-programmer, security-engineer | S |
| 5 | UI Framework | MVP | Foundation | ux-designer, ui-programmer | M |
| 6 | Stamina System | MVP | Core | systems-designer, economy-designer | S |
| 7 | Character Progression | MVP | Core | game-designer, systems-designer | M |
| 8 | Inventory & Equipment | MVP | Core | systems-designer, ui-programmer | M |
| 9 | Cloud Save | MVP | Core | network-programmer | S |
| 10 | Mission System | MVP | Feature | game-designer, gameplay-programmer | L |
| 11 | Territory Map | MVP | Feature | game-designer, level-designer | M |
| 12 | Gang System | MVP | Feature | game-designer, network-programmer | L |
| 13 | Building System | MVP | Feature | economy-designer, systems-designer | M |
| 14 | Shop System | MVP | Feature | economy-designer, ui-programmer | S |
| 15 | Gang War (Async PvP) | MVP | Adv. Feature | game-designer, ai-programmer, network-programmer | L |
| 16 | HUD & Feedback | MVP | Presentation | ux-designer, ui-programmer | M |
| 17 | Character Visuals | MVP | Presentation | art-director, technical-artist | M |
| 18 | Map UI | MVP | Presentation | ux-designer, ui-programmer, art-director | M |

---

## Circular Dependencies

- None found. Clean dependency graph.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|---|---|---|---|
| Gang War (Async PvP) | Technical + Design | Savaş sonucu hesaplama, hile önleme, balans — en karmaşık sistem | Erken prototip, basit güç hesabıyla başla |
| Gang System | Technical | Gerçek zamanlı çete yönetimi + backend sync | Firebase Realtime DB ile basit başla |
| Cloud Save | Technical | Veri tutarlılığı, çakışma çözümü, offline destek | Firebase offline persistence kullan |
| Economy (Currency) | Design | Enflasyon, kaynak dengesi, exploit önleme | Kapalı ekonomi simülasyonu, erken balans testi |
| Mission System | Design | Tekrarlayan hissetmemeli, yeterli çeşitlilik lazım | Data-driven görev üretimi, prosedürel varyasyonlar |

---

## Progress Tracker

| Metric | Count |
|---|---|
| Total systems identified | 34 |
| Design docs started | 18 |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 18/18 |
| Tier 2 systems designed | 0/4 |
| Tier 3 systems designed | 0/4 |
| Tier 4 systems designed | 0/5 |
| Tier 5 systems designed | 0/3 |

---

## Next Steps

- [ ] Design MVP-tier systems first (use `/design-system [system-name]`)
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when MVP systems are designed
- [ ] Prototype the highest-risk system early (`/prototype gang-war`)
- [ ] Plan the first implementation sprint (`/sprint-plan new`)
