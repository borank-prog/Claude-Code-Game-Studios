# Mission System

> **Status**: Designed
> **Author**: user + game-designer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Always a Next Move, Instant Read, Street Cred

## Overview

Oyunun birincil oynanis dongusu. Oyuncu stamina harcayarak gorevler yapar, cash +
respect + loot kazanir. 30 saniyelik cekirdek donguyu olusturur. Gorevler data-driven
— yeni gorev eklemek JSON duzenlemesiyle mumkun.

## Player Fantasy

"Her gorev bir risk-odul hesabi. Zor gorevi basarirsam buyuk kazanc. Kolay gorevle
sabit gelir. Benim stratejim, benim secimim."

## Detailed Design

### Core Rules

```
MissionDefinition {
    mission_id: String           # "rob_convenience_store"
    name: String                 # "Market Soygunu"
    description: String
    category: MissionCategory    # ROBBERY, TRAFFICKING, EXTORTION, HEIST, ASSASSINATION
    difficulty: Difficulty       # EASY, MEDIUM, HARD, EXTREME

    # Maliyetler
    stamina_cost: int
    required_rank: int
    required_stats: Dictionary   # {"strength": 10}

    # Odüller
    cash_reward_min: int
    cash_reward_max: int
    respect_reward: int
    loot_table_id: String        # Loot tablosu referansi

    # Zamanlama
    duration_seconds: float      # Gorev animasyon suresi (3-10s)
    cooldown_seconds: int        # Ayni gorevi tekrar bekleme (0 = yok)

    # Basari hesaplama
    base_success_rate: float     # 0.0-1.0
    stat_influence: Dictionary   # {"strength": 0.05} -> her puan %5 bonus
}

MissionCategory: ROBBERY | TRAFFICKING | EXTORTION | HEIST | ASSASSINATION
Difficulty: EASY | MEDIUM | HARD | EXTREME
```

### Gorev Akisi (30-Saniyelik Dongu)

```
1. Oyuncu gorev listesinden gorev secer
2. Gereksinimler kontrol edilir (rank, stat, stamina)
3. Stamina dusulur
4. Gorev animasyonu oynar (3-10s) — gorsel anlatim
5. Basari/basarisizlik hesaplanir
6. BASARI:
   - Cash odulu (min-max arasi random)
   - Respect odulu
   - Loot roll (nadir esya sansi)
   - Sonuc ekrani: para sayma animasyonu, loot gosterimi
7. BASARISIZLIK:
   - Cash odulu yok
   - Kucuk respect odulu (deneme icin)
   - Stamina kaybedilmis (geri gelmez)
   - "Tekrar dene" butonu
```

### Gorev Kategorileri (MVP: 3, Full: 8-10)

**MVP Kategorileri:**

| Kategori | Tema | Birincil Stat | Risk/Odul |
|---|---|---|---|
| ROBBERY | Soygun — dukkan, banka, kisi | Strength | Orta risk, orta odul |
| TRAFFICKING | Uyusturucu teslimat | Endurance | Dusuk risk, sabit odul |
| EXTORTION | Harac toplama | Charisma | Dusuk risk, tekrarlayan gelir |

**Full Vision Ek Kategorileri:**
- HEIST (buyuk soygun, yuksek risk/odul, cooldown'lu)
- ASSASSINATION (suikast, en yuksek zorluk)
- HACKING (intelligence bazli)
- SMUGGLING (arac gerektirir)
- GAMBLING_RUN (luck bazli)

### Loot Tablosu

```
LootTable {
    table_id: String
    entries: [
        { item_id: String, weight: float, min_qty: int, max_qty: int }
    ]
}

# Loot roll: rarity bazli filtreleme + weight bazli secim
# Ornek: "rob_loot_easy"
#   60% -> hicbir sey
#   25% -> common esya
#   10% -> uncommon esya
#   4%  -> rare esya
#   1%  -> epic esya
```

### Gorev Listesi Yenilenmesi

- Gorev listesi sabit degil — her `MISSION_REFRESH_INTERVAL`'da yenilenir
- Oyuncunun rank'ina uygun gorevler havuzdan secilir
- Zorluk dagilimi: %40 Easy, %30 Medium, %20 Hard, %10 Extreme

### States and Transitions

| Durum | Gecis |
|---|---|
| Gorev listesi goruntusu | -> Gorev secimi (tap) |
| Gereksinim kontrolu | -> Basarili: Animasyon / Basarisiz: Hata mesaji |
| Gorev animasyonu | -> Sonuc hesaplama |
| Sonuc ekrani | -> Gorev listesine don |

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Stamina | -> Mission | `spend_stamina(cost) -> bool` |
| Character Progression | Mission -> | `add_respect(player_id, amount)` |
| Economy | Mission -> | `add_cash(player_id, amount, source)` |
| Inventory | Mission -> | `add_item(player_id, item_id, qty)` |
| Item Database | <- Mission | `get_item(item_id)`, loot tablolari |
| Player Data | <- Mission | Stat degerleri (basari hesabi), rank (gereksinim) |
| Territory Map | <-> | Mahalle bonuslari gorev odullerini etkiler |
| HUD & Feedback | <- | Gorev UI, sonuc ekrani, animasyonlar |

## Formulas

```
# Basari orani
success_rate = base_success_rate + sum(
    player_stat[stat] * influence
    for stat, influence in stat_influence.items()
)
success_rate = clamp(success_rate, 0.05, 0.95)  # Min %5, max %95

# Ornek: Market Soygunu
# base_success_rate = 0.6, stat_influence = {"strength": 0.03}
# Oyuncu strength = 20
# success_rate = 0.6 + (20 * 0.03) = 1.2 -> clamp -> 0.95 = %95

# Cash odulu
actual_cash = randint(cash_reward_min, cash_reward_max)
actual_cash *= (1 + player.charisma * CHARISMA_REWARD_BONUS)
actual_cash *= territory_bonus  # Kontrol edilen bolgede %20 bonus

# Respect odulu
actual_respect = respect_reward * difficulty_multiplier
difficulty_multiplier = {EASY: 1.0, MEDIUM: 1.5, HARD: 2.5, EXTREME: 4.0}

# Gorev listesi yenilenmesi
missions_shown = MISSIONS_PER_REFRESH  # default: 8
```

## Edge Cases

| Durum | Cozum |
|---|---|
| Gorev sirasinda uygulama kapandi | Gorev tamamlanmis sayilir (stamina zaten harcandi), sonuc hesaplanir |
| Basari %95'in uzerinde hesaplaniyor | Clamp %95 — her zaman kucuk basarisizlik riski |
| Envanter dolu, loot dusturuyor | Loot 24s temp stash'e gider (Inventory kurali) |
| Cooldown'lu gorev, saat manipulasyonu | Server-side cooldown, client saatine guvenme |
| Ayni gorev 2 kez ayni anda baslatilir | Islem kilidi — ilk istek islenir, ikinci reddedilir |
| Rank atlama gorev sirasinda olur | Gorev bittikten sonra rank-up UI gosterilir |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Stamina | Upstream (hard) | Gorev maliyeti |
| Player Data | Upstream (hard) | Statlar, rank |
| Character Progression | Downstream (hard) | Respect odulu |
| Economy | Downstream (hard) | Cash odulu |
| Inventory | Downstream (soft) | Loot ekle |
| Item Database | Upstream (hard) | Loot tablolari |
| Territory Map | Upstream (soft) | Bolge bonuslari |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `CHARISMA_REWARD_BONUS` | 0.02 | 0.01-0.05 | Charisma'nin ekonomik degeri |
| `MIN_SUCCESS_RATE` | 0.05 | 0.01-0.20 | Minimum basari sansi |
| `MAX_SUCCESS_RATE` | 0.95 | 0.80-0.99 | Maksimum basari sansi |
| `MISSIONS_PER_REFRESH` | 8 | 4-12 | Gorev listesi boyutu |
| `MISSION_REFRESH_INTERVAL` | 3600s | 1800-7200s | Liste yenilenme sikligi |
| `TERRITORY_BONUS` | 1.20 | 1.05-1.50 | Kontrol edilen bolgede odul bonusu |
| `DIFFICULTY_MULT_*` | Yukaridaki tablo | 1.0-10.0 | Zorluk basing odul carpani |
| `EASY_STAMINA_COST` | 5 | 3-10 | Kolay gorev maliyeti |
| `MEDIUM_STAMINA_COST` | 10 | 5-20 | Orta gorev maliyeti |
| `HARD_STAMINA_COST` | 20 | 10-40 | Zor gorev maliyeti |
| `EXTREME_STAMINA_COST` | 35 | 20-60 | Ekstrem gorev maliyeti |

## Acceptance Criteria

- [ ] 3 gorev kategorisi (Robbery, Trafficking, Extortion) calisir
- [ ] Basari orani formulu dogru hesaplanir, %5-95 arasi clamp edilir
- [ ] Stamina yetersizliginde gorev baslatilamaz
- [ ] Cash, respect ve loot dogru verilir
- [ ] Gorev listesi periyodik yenilenir
- [ ] Cooldown sistemi calisir
- [ ] Bolge bonusu uygulanir
- [ ] Gorev animasyonu 3-10s icerisinde oynar
- [ ] Data-driven: yeni gorev JSON'a eklenerek olusturulabilir
- [ ] Basarisizlikta stamina geri gelmez, kucuk respect verilir
