# UI Framework

> **Status**: Designed
> **Author**: user + ux-designer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Instant Read, Eye Candy

## Overview

Tum oyun icin ekran yonetimi, navigasyon, gecis animasyonlari ve UI bilesenleri.
Godot'nun Control node sistemi uzerine insa edilir. 3-tap kurali: herhangi bir
ozellige maksimum 3 dokunusta ulasilmali.

## Player Fantasy

"Her sey bir bakista anlasilir. Menulerde kaybolmuyorum, hizli ve akici."

## Detailed Design

### Core Rules

**Ekran Hiyerarsisi (max 3 katman):**

```
Ana Ekranlar (Tab Bar ile erisim):
  1. Ana Sayfa (profil ozeti, hizli erisim)
  2. Gorevler (mission listesi)
  3. Harita (bolge haritasi)
  4. Cete (gang yonetimi)
  5. Magaza (shop)

Alt Ekranlar (1 tap derinlikte):
  - Envanter, Karakter detay, Bina yonetimi, Savaş detay, Ayarlar

Modal/Popup (islem onay, odul, bildirim):
  - Satin alma onayi, Level up, Savas sonucu
```

1. Alt tab bar her zaman gorunur (5 ana sekme)
2. Geri butonu her zaman sol ustte
3. Gecisler 0.2s slide animasyon — hizli, temiz
4. Popup'lar arka plani karartir, disina dokunma kapatir
5. Tum UI tek elle (sag veya sol) kullanilabilir olmali

### Tema

```
COLORS = {
    background: "#0D0D0D"      # Siyaha yakin
    surface: "#1A1A2E"         # Koyu mavi-gri
    primary: "#E2B714"         # Altin (ana aksiyonlar)
    danger: "#FF3333"          # Kirmizi (savas, uyari)
    success: "#33FF57"         # Yesil (kazanim, basari)
    text_primary: "#FFFFFF"
    text_secondary: "#888888"
    neon_accent: "#FF6B35"     # Neon turuncu vurgu
}

FONTS = {
    heading: "Bold, 24-32px"
    body: "Regular, 16-18px"
    caption: "Light, 12-14px"
    numbers: "Monospace Bold"  # Para, stat rakamlari
}
```

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| HUD & Feedback | Downstream | HUD bu framework uzerine insa edilir |
| Character Visuals | Downstream | Karakter gosterimi UI icinde |
| Map UI | Downstream | Harita ekrani UI icinde |
| Tum sistemler | <- | Ekran gecisi, popup, bildirim API'si |

## Formulas

```
# Animasyon sureleri
screen_transition = 0.2s
popup_fade_in = 0.15s
popup_fade_out = 0.1s
button_press_scale = 0.95 (scale down)
button_release_scale = 1.0

# Touch hedef boyutu (minimum)
min_touch_target = 44x44 dp (Apple HIG standardi)
```

## Edge Cases

| Durum | Cozum |
|---|---|
| Cok hizli ekran gecisi (spam tap) | Input kilitleme: gecis animasyonu bitene kadar yeni gecis engellenir |
| Popup uzerinde popup | Queue sistemi — max 1 popup, digerleri siraya girer |
| Ekran boyutu degisimi (tablet vs telefon) | Responsive layout: anchor bazli, min/max boyutlar |
| Notch/punch hole alanlar | Safe area margin, Godot'nun `get_display_safe_area()` kullanimi |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Godot Control Nodes | External | UI altyapisi |
| Tum UI sistemleri | Downstream | Framework'u kullanir |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `SCREEN_TRANSITION_DURATION` | 0.2s | 0.1-0.5s | Hiz hissi |
| `MIN_TOUCH_TARGET_DP` | 44 | 36-56 | Dokunma hassasiyeti |
| `MAX_POPUP_QUEUE` | 5 | 1-10 | Bildirim birikmesi |
| `TAB_BAR_HEIGHT_DP` | 56 | 48-72 | Alt bar boyutu |

## Acceptance Criteria

- [ ] Herhangi bir ozellige max 3 tap ile ulasilir
- [ ] Alt tab bar tum ana ekranlarda gorunur
- [ ] Gecis animasyonlari 0.2s'de tamamlanir
- [ ] Tek elle (bas parmakla) tum islemler yapilabilir
- [ ] Safe area tum cihazlarda dogru calisir
- [ ] Popup spam korunmasi calisir
- [ ] Minimum dokunma hedefi 44dp
- [ ] Tablet ve telefonda responsive layout
