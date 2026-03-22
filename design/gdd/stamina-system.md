# Stamina System

> **Status**: Designed
> **Author**: user + systems-designer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Always a Next Move, Instant Read

## Overview

Tum aksiyonlarin (gorev, soygun, baskin) maliyetini belirleyen enerji sistemi.
Stamina zamanla yenilenir, oyuncuyu duzenli oturumlara tesvik eder. Mobil oyunun
oturum ritmini kontrol eden temel mekanizma.

## Player Fantasy

"Enerjimi akilli kullanmaliyim — hangi goreve harcasam en karli?" Kaynak kisitlamasi
stratejik secim yaratir.

## Detailed Design

### Core Rules

```
StaminaData {
    current: int              # Mevcut stamina
    max: int                  # Cap = BASE_STAMINA + (endurance * STAMINA_PER_ENDURANCE)
    last_regen_time: DateTime # Son regen hesaplama zamani
}
```

1. Stamina her `REGEN_INTERVAL` saniyede 1 puan yenilenir
2. `max` degerini asamaz (dogal regen ile)
3. Gorev/soygun baslangicinda stamina dusuLur — yetersizse islem reddedilir
4. Stamina 0'a dustugunde oyuncu gorev yapamaz ama diger islemleri (bina, magaza, harita) yapabilir
5. Level up'ta stamina full olur (bonus his)

### Regen Hesaplama (Lazy — her sorgulamada hesaplanir)

```
func get_current_stamina() -> int:
    elapsed = now() - last_regen_time
    regen_points = floor(elapsed.seconds / REGEN_INTERVAL)
    new_stamina = min(current + regen_points, max)
    if regen_points > 0:
        last_regen_time += regen_points * REGEN_INTERVAL
        current = new_stamina
    return current
```

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Player Data | Upstream | `endurance` stat'ini okur -> max_stamina hesaplar |
| Mission System | <-> | `spend_stamina(amount) -> bool`, `get_stamina() -> int` |
| Gang War | <-> | Baskin maliyeti stamina harcar |
| HUD & Feedback | <- | Stamina bar gosterimi, regen timer |
| Push Notifications | <- | "Staminan doldu!" bildirimi |

## Formulas

```
# Max stamina
max_stamina = BASE_STAMINA + (endurance * STAMINA_PER_ENDURANCE)
# BASE_STAMINA=100, STAMINA_PER_ENDURANCE=2
# Baslangic (end=5): 110 | Gec oyun (end=105): 310

# Regen hizi
regen_rate = 1 stamina / REGEN_INTERVAL saniye
# REGEN_INTERVAL=120s (2dk) -> 110 stamina = ~3.7 saat full regen
# Gec oyun: 310 stamina = ~10.3 saat full regen

# Gorev maliyeti ornekleri
easy_mission = 5 stamina
medium_mission = 10 stamina
hard_mission = 20 stamina
raid_attack = 15 stamina
```

## Edge Cases

| Durum | Cozum |
|---|---|
| Stamina tam limitte, bina geliri stamina veriyor | Max uzerinde kabul edilmez, isaretle "stamina dolu" |
| Level up esnasinda zaten full | Full kalir, kayip yok |
| Zaman manipulasyonu (cihaz saati ileri alma) | Server-side zaman kullan, client saatine guvenme |
| Stamina refill (IAP) max uzerine cikarabilir mi | HAYIR — max deger siniri her zaman gecerli (P2W onleme) |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Player Data | Upstream (hard) | endurance, stamina verileri |
| Mission System | Downstream | Gorev maliyeti |
| Gang War | Downstream | Baskin maliyeti |
| HUD & Feedback | Downstream | UI gosterimi |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `BASE_STAMINA` | 100 | 50-200 | Oturum uzunlugu |
| `STAMINA_PER_ENDURANCE` | 2 | 1-5 | Endurance stat degeri |
| `REGEN_INTERVAL` | 120s | 60-300s | Geri gelme sikligi |
| `LEVEL_UP_FULL_REFILL` | true | bool | Level up bonusu |

## Acceptance Criteria

- [ ] Lazy regen dogru hesaplanir (sunucu zamani ile)
- [ ] Yetersiz staminada gorev baslatilamaz
- [ ] Max uzerinde stamina birikemez
- [ ] Level up'ta full refill calisir
- [ ] Stamina bar HUD'da dogru gosterilir
- [ ] Cihaz saati manipulasyonu islemi etkilemez
