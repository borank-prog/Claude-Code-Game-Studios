# Cloud Save

> **Status**: Designed
> **Author**: user + network-programmer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Rise Together (cihazlar arasi devam)

## Overview

Oyuncu verisinin Firebase Firestore'da saklanmasi ve cihazlar arasi
senkronizasyonu. Yerel cache + bulut yedek modeli. Veri kaybi olusmamasini
garanti eder.

## Player Fantasy

"Telefonum bozulsa bile hesabim guvende. Tabletten devam edebilirim."

## Detailed Design

### Core Rules

1. Tum PlayerData her onemli islemden sonra yerel cache'e yazilir
2. Yerel cache periyodik olarak (ve her oturum sonunda) Firestore'a sync edilir
3. Giris yapildiginda: sunucu vs yerel → en yeni timestamp kazanir
4. Cakisma durumunda sunucu verisi oncelikli (server-authoritative)
5. Offline modda yerel cache'e yazilir, cevrimici olunca sync edilir

### Veri Yapisi (Firestore)

```
/players/{player_id}/
    profile: { display_name, avatar_id, rank, respect, ... }
    stats: { strength, endurance, charisma, luck, intelligence }
    economy: { cash, premium_currency }
    inventory: { items: [...], equipment: {...} }
    gang: { gang_id, role }
    meta: { last_save, version, checksum }
```

### Sync Zamanlama

| Olay | Sync |
|---|---|
| Gorev tamamlama | Yerel + kuyruga al |
| Esya satin alma | Yerel + aninda sync |
| Rank atlama | Yerel + aninda sync |
| Uygulama arka plana | Aninda sync |
| Periyodik | Her 60 saniye |

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Auth & Account | Upstream | Firebase UID ile belge yolu |
| Player Data | Upstream | Tum veriyi serialize eder |
| Tum sistemler | Dolayli | Veri kaliciligi saglar |

## Formulas

```
# Checksum (veri butunlugu)
checksum = crc32(serialize(player_data))

# Sync onceligi
priority = { rank_up: IMMEDIATE, purchase: IMMEDIATE, mission: QUEUED, periodic: LOW }
```

## Edge Cases

| Durum | Cozum |
|---|---|
| Sync sirasinda baglanti koptu | Kuyrukta kalir, baglanti gelince tekrar dener |
| Yerel ve sunucu verisi cakisiyor | Server wins — ama timestamp farki > 1 saat ise kullaniciya sor |
| Veri bozulmuş (checksum hatasi) | Son gecerli yedegi yukle, hata logla |
| Cok buyuk veri (envanter overflow) | Firestore belge limiti 1MB — yeterli, ama izle |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Auth & Account | Upstream (hard) | Firebase UID |
| Player Data | Upstream (hard) | Kaydetilecek veri |
| Firebase Firestore | External (hard) | Bulut depolama |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `PERIODIC_SYNC_INTERVAL` | 60s | 30-300s | Bant genisligi vs veri guvenligi |
| `CONFLICT_ASK_THRESHOLD` | 3600s | 600-86400s | Ne zaman kullaniciya sorulur |
| `MAX_OFFLINE_QUEUE` | 100 | 10-500 | Cevrimdisi islem limiti |

## Acceptance Criteria

- [ ] Offline modda oynanabilir, cevrimici olunca sync olur
- [ ] Cihaz degistirmede veri kaybi yok
- [ ] Checksum dogrulamasi calisir
- [ ] Cakisma durumunda dogru cozum uygulanir
- [ ] Sync kuyrugu baglanti kesildiginde veri kaybetmez
