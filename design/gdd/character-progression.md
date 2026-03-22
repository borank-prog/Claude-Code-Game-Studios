# Character Progression

> **Status**: Designed
> **Author**: user + game-designer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Street Cred

## Overview

Oyuncunun bireysel buyumesini yoneten sistem. Sayginlik (respect) kazanarak rank
atlar, her rank stat cap'i arttirir ve yeni icerik acar. 20 rank seviyesi:
Street Thug (0) -> Kingpin (19).

## Player Fantasy

"Sokak serserisinden sehrin kralina yukseliyorum. Her rank beni daha guclu, daha
saygin yapiyor."

## Detailed Design

### Core Rules

```
RankDefinition {
    rank: int                # 0-19
    name: String             # "Street Thug", "Dealer", ... "Kingpin"
    required_respect: int    # Bu rank'a ulasmak icin gereken toplam respect
    stat_cap: int            # STAT_CAP_BASE + (rank * STAT_CAP_PER_RANK)
    unlocks: String[]        # Bu rank'ta acilan ozellikler
}

Rank isimleri:
 0: Street Thug      5: Hustler        10: Lieutenant    15: Don
 1: Petty Criminal   6: Enforcer       11: Capo          16: Boss
 2: Pickpocket       7: Dealer         12: Consigliere   17: Overlord
 3: Mugger           8: Underboss      13: Godfather     18: Cartel Lord
 4: Thief            9: Captain        14: Crime Lord    19: Kingpin
```

1. Respect gorevler, soygunlar ve savaslardan kazanilir
2. Respect asla kaybolmaz (sadece `season_respect` sifirlanir)
3. Rank dusmez — bir kez ulasildi mi kalici
4. Her rank yeni silah/ekipman/bina/gorev turlerini acar
5. Rank atlamada: stat noktasi odulu, stamina full refill, UI kutlama

### Stat Puan Dagitimi

```
Level up'ta oyuncu STAT_POINTS_PER_RANK puan kazanir.
Puanlari 5 stat arasinda dagitir (strength, endurance, charisma, luck, intelligence).
Her stat max stat_cap'e kadar arttirilabilir.
```

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Player Data | <-> | rank, respect, statlar okur/yazar |
| Mission System | -> Progression | Gorev tamamlamada respect verir |
| Gang War | -> Progression | Savas respect odulu |
| Item Database | <- | Rank gereksinimleri okur |
| HUD & Feedback | <- | Rank bar, level up animasyonu |

## Formulas

```
# Respect gereksinimleri (ustel buyume)
required_respect(rank) = floor(BASE_RESPECT * (RESPECT_GROWTH ^ rank))
# BASE_RESPECT=100, RESPECT_GROWTH=1.8
# Rank 0->1: 100  | Rank 5->6: 1,890  | Rank 10->11: 35,700
# Rank 15->16: 674,000 | Rank 18->19: 3,936,000

# Stat puanlari
stat_points_per_rank = STAT_POINTS_PER_RANK  # default: 3
# 20 rank * 3 puan = 60 toplam stat puani

# Stat cap
stat_cap = STAT_CAP_BASE + (rank * STAT_CAP_PER_RANK)
# Rank 0: 10 | Rank 10: 60 | Rank 19: 105
```

## Edge Cases

| Durum | Cozum |
|---|---|
| Tek gorevde birden fazla rank atlama | Tum ranklarin odullerini sirali ver, coklu kutlama |
| Tum statlari max'a vurduktan sonra stat puani | Puan birikmez, uyari: "Stat noktasi kullanilamadi" |
| Season_respect sifirlaninca rank duser mi? | HAYIR — rank kalici, sadece season_respect sifirlanir |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Player Data | Upstream (hard) | Rank, respect, stat verileri |
| Economy | Upstream (hard) | Respect para birimi gibi davranir |
| Mission System | Downstream | Respect odulu verir |
| Item Database | Downstream | Rank gereksinimleri kontrol eder |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `BASE_RESPECT` | 100 | 50-500 | Ilk rank'a ulasma hizi |
| `RESPECT_GROWTH` | 1.8 | 1.3-2.5 | Gec rank zorlugu (ustel) |
| `STAT_POINTS_PER_RANK` | 3 | 1-5 | Build cesitliligi vs guc artisi |
| `STAT_CAP_BASE` | 10 | 5-50 | Baslangic stat siniri |
| `STAT_CAP_PER_RANK` | 5 | 1-20 | Rank basina stat siniri artisi |

## Acceptance Criteria

- [ ] Respect ustel buyume formulu dogru hesaplanir
- [ ] Rank atlama odulleri (stat puani, stamina refill) verilir
- [ ] Stat puanlari dagitilabilir, cap asilmaz
- [ ] Rank dusmuyor, respect kaybolmuyor
- [ ] Season_respect sifirlaninca rank etkilenmez
- [ ] Rank gereksinimleri item/gorev erisimini dogru kisitlar
