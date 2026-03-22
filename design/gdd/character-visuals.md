# Character Visuals

> **Status**: Designed
> **Author**: user + art-director
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Eye Candy, Street Cred

## Overview

Karakter portreleri ve kusanilan ekipmanin gorsel yansimasi. Oyuncunun profil
ekraninda, cete listesinde ve savas raporlarinda gorunen karakter gorseli.
Stylized 2D illustrasyon stili — koyu tonlar, neon vurgular.

## Player Fantasy

"Karakterim havalı gorunuyor. Yeni silahimi kusandigimda gorunum degisiyor.
Diger oyuncular profilime baktiginda etkileniyor."

## Detailed Design

### Core Rules

```
CharacterVisual {
    base_avatar: int            # Temel karakter portresi (10+ secim)
    equipped_overlays: {        # Kusanilan esyalarin gorsel katmanlari
        weapon: String?         # Silah overlay
        armor: String?          # Zirh overlay
        clothing: String?       # Kiyafet overlay
        accessory: String?      # Aksesuar overlay
    }
    rank_badge: int             # Rank rozeti
    gang_tag: String?           # Cete etiketi
    frame: String?              # Profil cercevesi (kozmetik)
}
```

1. Temel avatar ilk olusturmada secilir (sonra degistirilebilir)
2. Ekipman degisince overlay otomatik guncellenir
3. Rarity'ye gore esya pariltisi: Common(yok), Rare(mavi), Legendary(altin)
4. Gang tag profilde gorunur: "[CH] DarkKing"

### Gorsel Katmanlar (arka -> on)

```
1. Arka plan (rank'a gore renk degradesi)
2. Karakter portresi (base_avatar)
3. Kiyafet overlay
4. Zirh overlay
5. Silah overlay
6. Aksesuar overlay
7. Rank rozeti (sol ust)
8. Cete etiketi (alt)
9. Profil cercevesi (kozmetik, dis kenar)
```

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Inventory & Equipment | Upstream | Kusanilan esyalarin overlay ID'leri |
| UI Framework | Upstream | Gorsel gosterim alani |
| Player Data | Upstream | Avatar, rank |
| Gang System | Upstream | Cete tag'i |
| Cosmetic System | Upstream (Tier 4) | Cerceve, ozel efektler |

## Edge Cases

| Durum | Cozum |
|---|---|
| Esya overlay asset'i yuklenemedi | Varsayilan siluet goster, hata logla |
| Cok fazla overlay performans | Max 5 katman, onceden birlestirilmis cache |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Inventory & Equipment | Upstream (hard) | Ekipman bilgisi |
| UI Framework | Upstream (hard) | Render alani |
| Player Data | Upstream (hard) | Avatar, rank |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `AVATAR_COUNT` | 10 | 5-30 | Karakter cesitliligi |
| `RARITY_GLOW_INTENSITY` | 0.5 | 0-1.0 | Nadir esya pariltisi |

## Acceptance Criteria

- [ ] Avatar secimi ve degistirme calisir
- [ ] Ekipman degistirmek gorsel overlay'i gunceller
- [ ] Rank rozeti dogru gosterilir
- [ ] Cete tag'i profilde gorunur
- [ ] Overlay katmanlama performansi 60fps
- [ ] Eksik asset durumunda fallback calisir
