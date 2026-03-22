# HUD & Feedback

> **Status**: Designed
> **Author**: user + ux-designer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Eye Candy, Instant Read

## Overview

Oyun ici bilgi gosterimi ve gorsel/isitsel geri bildirim sistemi. Stamina bar,
cash gostergesi, bildirimler, odul animasyonlari ve durum gostergeleri.

## Player Fantasy

"Her kazanc hissediliyor — para sayilirken, level atlarken, loot dusurken. Ekran
canli, bilgi net."

## Detailed Design

### HUD Elemanlari (Her Zaman Gorunen)

```
Ust Bar:
  [Avatar] [Rank Badge] [Display Name]    [Cash: 12,450] [Premium: 50]
  [Stamina Bar: 87/110] [Regen Timer: 2:34]

Alt Tab Bar:
  [Ana] [Gorevler] [Harita] [Cete] [Magaza]

Bildirim Alani (sag ust):
  - Savas sonucu
  - Cete daveti
  - Stamina dolu
  - Bina tamamlandi
```

### Geri Bildirim Animasyonlari

| Olay | Gorsel | Sure |
|---|---|---|
| Cash kazanma | Yesil rakam yukari ucar "+250" | 1s |
| Cash harcama | Kirmizi rakam "-500" | 1s |
| Respect kazanma | Altin yildiz efekti + bar dolumu | 1.5s |
| Level up | Tam ekran parlama + rank badge animasyonu | 3s |
| Loot drop | Esya ikonu duser + rarity pariltisi | 2s |
| Gorev basari | Yesil tik + para sayma | 2s |
| Gorev basarisizlik | Kirmizi X + ekran sallama | 1s |
| Savas kazanma | Zafer bayrak animasyonu + loot gosterim | 3s |
| Savas kaybetme | Kirmizi overlay + bolge kaybi gosterimi | 2s |

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| UI Framework | Upstream | Ekran yonetimi, tema |
| Economy | <- | Cash/premium degerlerini gosterir |
| Stamina | <- | Stamina bar, regen timer |
| Mission System | <- | Gorev sonuc ekrani |
| Gang War | <- | Savas bildirimleri, sonuc |
| Character Progression | <- | Rank bar, level up |

## Formulas

Yok — gosterim sistemi, hesaplama yapmaz.

## Edge Cases

| Durum | Cozum |
|---|---|
| Coklu bildirim ayni anda | Kuyruk: 1 bildirim/2s, max 5 kuyrukta |
| Level up + loot + cash ayni anda | Oncelik sirasi: Level up > Loot > Cash |
| Cok buyuk rakamlar (1,000,000+) | Kisaltma: 1M, 1.5B formatinda |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| UI Framework | Upstream (hard) | Tema, layout |
| Economy | Upstream (hard) | Deger gosterimi |
| Stamina | Upstream (hard) | Bar gosterimi |
| Tum gameplay sistemleri | Upstream (soft) | Olay bildirimleri |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `NOTIFICATION_INTERVAL` | 2s | 1-5s | Bildirim gosterim hizi |
| `MAX_NOTIFICATION_QUEUE` | 5 | 1-10 | Kuyruk boyutu |
| `CASH_ANIM_DURATION` | 1s | 0.5-2s | Para animasyon suresi |
| `LEVEL_UP_ANIM_DURATION` | 3s | 2-5s | Level up gosterisi |

## Acceptance Criteria

- [ ] Stamina bar gercek zamanli guncellenir
- [ ] Cash degisiklikleri animasyonla gosterilir
- [ ] Level up tam ekran animasyonu calisir
- [ ] Bildirim kuyrugu FIFO ve limitli
- [ ] Buyuk rakamlar kisaltilmis gosterilir (1M, 1.5B)
- [ ] Tum animasyonlar 60fps'te akici
