# Building System

> **Status**: Designed
> **Author**: user + economy-designer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Always a Next Move, Rise Together

## Overview

Kontrol edilen bolgelere binalar insa edip yukseltme sistemi. Binalar pasif gelir,
savunma bonusu ve ozel ozellikler saglar. Bina yerlestirme stratejik — sinirli slot
ve secim gerektiriyor.

## Player Fantasy

"Mahalleye stash house yaptim, pasif gelirim var. Crack house actigimda gelirim
katlandi. Binalarim buyudukce bolgemiz vazgecilemez oldu."

## Detailed Design

### Core Rules

```
BuildingDefinition {
    building_id: String          # "stash_house", "crack_house", "casino"
    name: String
    category: BuildingCategory   # INCOME, DEFENSE, PRODUCTION, UTILITY

    # Maliyetler
    build_cost: int[]            # Level bazli: [500, 1500, 4000, ...]
    build_time_seconds: int[]    # Level bazli: [60, 300, 900, ...]

    # Uretim
    income_per_hour: int[]       # Level bazli: [20, 50, 120, ...]
    defense_bonus: int[]         # Level bazli: [0, 100, 250, ...]

    # Gereksinimler
    required_rank: int
    required_gang_level: int
    max_level: int               # 5
}

BuildingCategory: INCOME | DEFENSE | PRODUCTION | UTILITY
```

**MVP Bina Tipleri:**

| Bina | Kategori | Gelir/saat (L1-L5) | Savunma (L1-L5) | Rank |
|---|---|---|---|---|
| Stash House | INCOME | 20/50/120/250/500 | 0 | 0 |
| Crack House | INCOME | 40/100/240/500/1000 | 0 | 3 |
| Gun Store | DEFENSE | 0 | 100/250/500/1000/2000 | 5 |
| Safe House | DEFENSE | 10/20/40/80/160 | 200/500/1000/2000/4000 | 7 |
| Workshop | UTILITY | 0 | 0 | 2 |
| Lookout Tower | UTILITY | 0 | 50/100/200/400/800 | 4 |

1. Her bolge sinirli bina slotuna sahip (tier'a gore 2-4)
2. Bina insa etmek cash ve zaman harcar
3. Intelligence stat'i insa suresini %2/puan azaltir
4. Binalar cete kasasindan veya kisisel cash'ten finanse edilebilir
5. Bolge el degistirirse binalar YOK EDILIR (stratejik kayip)

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Territory Map | Upstream (hard) | Bina slotlari bolgeden gelir |
| Economy | <-> | Insa maliyeti, gelir |
| Gang System | Upstream (soft) | Cete level gereksinimleri |
| Gang War | <- | Savunma bonusu |
| Player Data | <- | Intelligence insa hizi bonusu |

## Formulas

```
# Insa suresi (intelligence bonusu)
actual_build_time = build_time * (1 - player.intelligence * 0.02)
# Int=5: %10 hizli | Int=50: %100 hizli (yari sure)
# Minimum: build_time * 0.2 (max %80 indirim)

# Bolge toplam geliri
territory_total_income = sum(building.income_per_hour for b in territory.buildings)

# Bolge toplam savunma
territory_defense = sum(building.defense_bonus for b in territory.buildings)
```

## Edge Cases

| Durum | Cozum |
|---|---|
| Bolge kaybedildi, binalar ne olur | Yok edilir — yeniden insa gerekir (stratejik kayip) |
| Insa sirasinda bolge kaybedildi | Insa iptal, %50 cash iade |
| Tum slotlar dolu | Bina yik (bedava) + yeni insa |
| Cete kasasindan insa, cete dagildi | Bina kalir (bolge sahibi oldugu surece) |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Territory Map | Upstream (hard) | Bina slotlari |
| Economy | Upstream (hard) | Insa maliyeti, gelir |
| Gang War | Downstream | Savunma bonusu |
| Player Data | Upstream (soft) | Intelligence bonusu |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `INTELLIGENCE_BUILD_BONUS` | 0.02 | 0.01-0.05 | Int stat degeri |
| `MIN_BUILD_TIME_RATIO` | 0.2 | 0.1-0.5 | Minimum insa suresi orani |
| `TERRITORY_LOST_REFUND` | 0.5 | 0-1.0 | Kaybedilen binadan iade |

## Acceptance Criteria

- [ ] Bina insa, yukseltme, yikma calisir
- [ ] Slot siniri dogru uygulanir
- [ ] Pasif gelir dogru hesaplanir
- [ ] Intelligence bonusu insa suresini azaltir
- [ ] Bolge kaybedilince binalar yok edilir
- [ ] Savunma bonusu Gang War'da hesaplanir
