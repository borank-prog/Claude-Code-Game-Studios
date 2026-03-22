# Territory Map

> **Status**: Designed
> **Author**: user + game-designer, level-designer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Rise Together, Always a Next Move

## Overview

Sehir haritasi — oyuncular ve ceteler mahalleleri kontrol icin yarisir. Her mahalle
pasif gelir, gorev bonuslari ve stratejik avantaj saglar. Harita Gang War sisteminin
savas alaFni ve Building System'in yer aldigi alandir.

## Player Fantasy

"Haritaya bakiyorum, cetemizin kontrol ettigi bolgeler altin rengiyle parlıyor.
Rakip cetenin bolgesine goz diktik — bu gece baskin yapacagiz."

## Detailed Design

### Core Rules

```
Territory {
    territory_id: String        # "downtown", "docks", "suburbs"
    name: String                # "Sehir Merkezi"
    tier: int                   # 1-3 (1=baslangiC, 3=premium)

    # Kontrol
    controlling_gang_id: String? # null = tarafsiz bolge
    control_strength: float     # 0.0-1.0 (ne kadar saglamca tutuluyor)
    contested: bool             # Baska cete saldirida mi

    # Ekonomi
    base_income_per_hour: int   # Tier'a gore: T1=50, T2=150, T3=400
    mission_reward_bonus: float # Buradaki gorevlere bonus: T1=1.1, T2=1.2, T3=1.3

    # Bina slotlari
    building_slots: int         # Kac bina yerlestirilebilir: T1=2, T2=3, T3=4

    # Komsuluk
    adjacent_territories: String[] # Komsfu bolgeler (saldiri icin onemli)
}
```

**MVP Harita: 10 Mahalle**

| Mahalle | Tier | Gelir/saat | Bina Slotu | Konum |
|---|---|---|---|---|
| Varoslar (Suburbs) | 1 | 50 | 2 | Dis |
| Gecekondular (Slums) | 1 | 50 | 2 | Dis |
| Sanayi Bolgesi | 1 | 60 | 2 | Dis |
| Liman (Docks) | 2 | 150 | 3 | Orta |
| Pazar Yeri | 2 | 140 | 3 | Orta |
| Gece Hayati (Nightlife) | 2 | 160 | 3 | Orta |
| Finans Merkezi | 2 | 180 | 3 | Orta |
| Sehir Merkezi (Downtown) | 3 | 400 | 4 | Merkez |
| Marina | 3 | 350 | 4 | Merkez |
| Saray (The Mansion) | 3 | 500 | 4 | Merkez |

1. Tarafsiz bolgeleri ele gecirmek kolay (PvE garrison'u yenmek yeterli)
2. Rakip cete bolgesini ele gecirmek Gang War gerektirir
3. Kontrol edilen bolge pasif gelir uretir (cete kasasina)
4. Bolgede gorev yapmak bonus verir
5. Sadece KOMSFU bolgelere saldirabilirsin (harita stratejisi)
6. control_strength zamanlaboyunca artar (yerlesmislik bonusu)

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Economy | Territory -> | Bolge geliri cete kasasina akar |
| Gang System | <-> | Kontrol eden cete bilgisi |
| Gang War | <-> | Savas hedefi ve sonucu |
| Building System | <- | Bina slotlari bolgeye bagli |
| Mission System | <- | Bolge bonusu gorev odullerine uygulanir |
| Map UI | <- | Gorsel harita gosterimi |

## Formulas

```
# Bolge geliri (cete kasasina)
territory_income = base_income_per_hour * control_strength * gang_bonus
# control_strength: yeni ele gecirme=0.5, 7 gun sonra=1.0

# Kontrol gucu artisi
control_strength += CONTROL_GROWTH_PER_DAY  # 0.07/gun -> 7 gunde 0.5->1.0

# Bolge savunma gucu (Gang War'da kullanilir)
defense_power = sum(building.defense_bonus for building in territory.buildings)
             + garrison_power
             + control_strength * ENTRENCHMENT_BONUS
```

## Edge Cases

| Durum | Cozum |
|---|---|
| Cete dagildi, bolgeleri ne olur | Tarafsiza doner, NPC garrison yerlestir |
| Tek kisi kalan cete bolge tutabilir mi | Evet ama savunma zayif, kolay ele gecirilir |
| Tum bolgeler tek cetede | Yeni sezon sifirlama — dengeler |
| Komsuluk zinciri kirildi (ortadaki bolge dusmus) | Bolge erisimi komsuluk sart degil, sadece saldiri icin |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Economy | Downstream (hard) | Bolge geliri |
| Gang System | Upstream (hard) | Cete sahipligi |
| Gang War | Downstream (hard) | Savas alani |
| Building System | Downstream (hard) | Bina slotlari |
| Mission System | Downstream (soft) | Bolge gorev bonusu |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `TIER1_BASE_INCOME` | 50 | 20-100 | Dis bolge degeri |
| `TIER2_BASE_INCOME` | 150 | 80-300 | Orta bolge degeri |
| `TIER3_BASE_INCOME` | 400 | 200-800 | Merkez bolge degeri |
| `CONTROL_GROWTH_PER_DAY` | 0.07 | 0.03-0.15 | Yerlesme hizi |
| `ENTRENCHMENT_BONUS` | 500 | 100-2000 | Savunma avantaji |
| `INITIAL_CONTROL_STRENGTH` | 0.5 | 0.3-0.8 | Ele gecirme anindaki guc |

## Acceptance Criteria

- [ ] 10 mahalle haritada gorunur ve erisilebilir
- [ ] Tarafsiz bolge ele gecirilebilir
- [ ] Bolge geliri dogru hesaplanir ve cete kasasina akar
- [ ] Komsuluk kontrolu calisir (sadece komsuya saldiri)
- [ ] control_strength zamanla artar
- [ ] Gorev bonusu kontrol edilen bolgede uygulanir
- [ ] Cete dagilinca bolge tarafsiza doner
