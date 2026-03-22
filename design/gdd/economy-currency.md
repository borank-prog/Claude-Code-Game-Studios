# Economy (Currency)

> **Status**: Designed
> **Author**: user + economy-designer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Street Cred, Always a Next Move

## Overview

Oyundaki tum kaynak akisini yoneten cift para birimi sistemi. **Cash** (birincil,
oyun ici kazanilir) ve **Premium Currency** (satin alinir, sadece kozmetik). Tum
ekonomik islemler (kazanim, harcama, transfer) bu sistemden gecer. Kapali ekonomi
modeli — enflasyonu onlemek icin her kaynak (source) bir tuketime (sink) eslenmelidir.

## Player Fantasy

"Her gorevden sonra kasam buyuyor, parami nereye yatiracagima ben karar veriyorum."
Para = guc degil, para = secim ozgurlugu.

## Detailed Design

### Core Rules

```
CurrencyType {
    CASH            # Birincil — gorevler, soygunlar, binalar
    PREMIUM         # Ikincil — IAP, kozmetik, convenience
}

Transaction {
    player_id: String
    currency: CurrencyType
    amount: int          # Pozitif = kazanim, Negatif = harcama
    source: String       # "mission_reward", "building_income", "shop_purchase"
    timestamp: DateTime
}
```

1. Tum para degisiklikleri `Transaction` uzerinden yapilir — dogrudan set yok
2. `cash` minimum 0, negatife dusemez
3. `premium_currency` minimum 0, sadece IAP veya odul ile kazanilir
4. Her transaction loglanir (analytics + hile tespiti)
5. Cete kasasi ayri bir havuz — kisisel cash'ten bagimsiz

### Sources (Kaynaklar) ve Sinks (Tuketim)

| Source | Miktar Araligi | Sikligi |
|---|---|---|
| Gorev odulleri | 50-500 cash | Her gorev |
| Bina geliri | 10-100 cash/saat | Pasif |
| Soygun | 100-2000 cash | Risk bazli |
| Sezon odulleri | 500-5000 cash | Sezon sonu |

| Sink | Miktar Araligi | Sikligi |
|---|---|---|
| Silah/ekipman satin alma | 100-5000 cash | Ihtiyac bazli |
| Bina yukseltme | 500-50000 cash | Ilerleme bazli |
| Adam ise alma | 200-2000 cash | Cete buyumesi |
| Stat sifirlama (respec) | 1000 cash | Nadir |

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Player Data | <-> | `cash`, `premium_currency` alanlarini okur/yazar |
| Mission System | -> Economy | `add_cash(player_id, amount, "mission_reward")` |
| Shop System | -> Economy | `spend_cash(player_id, amount, "shop_purchase") -> bool` |
| Building System | -> Economy | `add_cash(player_id, amount, "building_income")` |
| Gang System | <-> | Cete kasasi ayri, `add_gang_cash(gang_id, amount)` |
| IAP | -> Economy | `add_premium(player_id, amount, "iap_purchase")` |

## Formulas

```
# Gorev odulu (Mission System tarafindan hesaplanir, buraya yazilir)
mission_reward = base_reward * (1 + charisma * CHARISMA_REWARD_BONUS)
# CHARISMA_REWARD_BONUS = 0.02 -> charisma 5 = %10 bonus

# Bina geliri (Building System hesaplar)
building_income_per_hour = base_income * building_level * territory_bonus

# Enflasyon kontrolu — gunluk net akis hedefi
target_daily_net = 0  # Uzun vadede dengeli ekonomi
# Izleme: daily_sources - daily_sinks yaklasik 0 olmali
```

## Edge Cases

| Durum | Cozum |
|---|---|
| Ayni anda 2 islem cash'i negatife dusurmeye calisir | Atomik islem, ilk gelen kazanir, ikinci reddedilir |
| Cete kasasindan birisi tum parayi cekmis | Cete kasasi cekim limiti: gunluk max %20 |
| Premium currency ile cash satin alinabilir mi? | HAYIR — P2W onleme kurali, premium sadece kozmetik |
| Overflow (cok buyuk rakam) | int64 kullan, pratik limit 9.2 quintillion |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Player Data | Upstream (hard) | Cash/premium degerleri PlayerData'da yasar |
| Mission System | Downstream | Gorev odullerini yazar |
| Shop System | Downstream | Satin alma islemlerini yapar |
| Building System | Downstream | Bina gelirlerini yazar |
| Gang System | Downstream | Cete kasasi yonetimi |
| IAP | Downstream | Premium currency ekler |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `CHARISMA_REWARD_BONUS` | 0.02 | 0.01-0.05 | Charisma'nin ekonomik degeri |
| `GANG_TREASURY_DAILY_WITHDRAW_PERCENT` | 20 | 5-50 | Cete kasasi korumasi |
| `TRANSACTION_LOG_RETENTION_DAYS` | 90 | 30-365 | Hile tespiti penceresi |

## Acceptance Criteria

- [ ] Cash asla negatif olmaz
- [ ] Premium currency sadece IAP/odul ile kazanilir, cash ile degil
- [ ] Tum islemler loglanir (source, miktar, zaman)
- [ ] Atomik islemler — yarisma durumunda veri tutarliligi korunur
- [ ] Cete kasasi cekim limiti calisir
- [ ] Enflasyon izleme: gunluk kaynak/tuketim orani loglanir
