# Map UI

> **Status**: Designed
> **Author**: user + ux-designer, art-director
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Eye Candy, Instant Read

## Overview

Bolge haritasinin gorsel arayuzu. Mahalleleri, kontrol durumunu, binalari ve
savas durumunu gosterir. Interaktif — dokunarak bolge detayina, baskina veya
bina yonetimine gecilir.

## Player Fantasy

"Haritaya bakiyorum — cetemizin altin rengiyle parlayan bolgeleri buyuyor.
Rakip cetenin kirmizi bolgesi goze batiyor. Oraya dokunuyorum, baskin planliyorum."

## Detailed Design

### Core Rules

```
Harita Gosterimi:
- Sehir kus bakisi, stilize 2D
- Her mahalle bir polygon/bolge
- Renk kodlamasi:
  - Altin: Senin ceten
  - Kirmizi: Rakip ceteler (farkli tonlar)
  - Gri: Tarafsiz bolge
  - Yanip sonen: Aktif savas
- Dokunma: Bolge detay popup'i acar

Bolge Detay Popup:
  - Bolge adi + tier
  - Kontrol eden cete
  - Gelir/saat
  - Binalar listesi
  - Aksiyonlar: [Baskin Yap] [Bina Yonet] [Gorev Yap]
```

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Territory Map | Upstream | Bolge verisi, kontrol durumu |
| Gang System | Upstream | Cete renkleri, isimler |
| Gang War | <-> | Savas durumu, baskin baslatma |
| Building System | <- | Bina gosterimi |
| UI Framework | Upstream | Ekran, tema, popup sistemi |

## Edge Cases

| Durum | Cozum |
|---|---|
| 30 bolge ekrana sigmaz | Pinch-to-zoom + pan destegi |
| Cok fazla cete farkli renk | Max 8 ana renk, geri kalan tonlarla |
| Yavas baglantida harita yuklenmiyor | Yerel cache, son bilinen durumu goster |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Territory Map | Upstream (hard) | Bolge verisi |
| Gang System | Upstream (hard) | Cete bilgisi |
| UI Framework | Upstream (hard) | Render, dokunma |
| Gang War | Downstream (soft) | Baskin baslatma erisimi |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `MAP_ZOOM_MIN` | 0.5x | 0.3-1.0 | Uzaklastirma siniri |
| `MAP_ZOOM_MAX` | 3.0x | 2.0-5.0 | Yakinlastirma siniri |
| `WAR_FLASH_INTERVAL` | 0.5s | 0.2-1.0 | Savas yanip sonme hizi |

## Acceptance Criteria

- [ ] 10 mahalle haritada gorunur, dokunulabilir
- [ ] Renk kodlamasi dogru (altin=benim, kirmizi=dusmanlar, gri=tarafsiz)
- [ ] Bolge detay popup'i tum bilgiyi gosterir
- [ ] Aktif savaslar yanip sonerek gosterilir
- [ ] Pinch-to-zoom ve pan akici calisir
- [ ] Bina ve baskin aksiyonlari popup'tan erisilebilir
