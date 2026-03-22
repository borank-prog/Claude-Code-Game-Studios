# Item Database

> **Status**: Designed
> **Author**: user + systems-designer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Street Cred, Eye Candy

## Overview

Oyundaki tum esya tanimlarini iceren data-driven veritabani. Silahlar, ekipmanlar,
kiyafetler, araclar ve tuketim esyalari burada tanimlanir. Calisma zamaninda
JSON/Resource dosyalarindan yuklenir. Yeni esya eklemek kod degisikligi gerektirmez.

## Player Fantasy

"Yeni bir silah aldim, daha guclu hissediyorum. Nadir bir esya dustutu, sansli gunumdeyim."

## Detailed Design

### Core Rules

```
ItemDefinition {
    item_id: String           # Benzersiz ID: "wpn_pistol_01"
    name: String              # Gorunen ad: "Glock 19"
    description: String       # Aciklama metni
    category: ItemCategory    # WEAPON, ARMOR, CLOTHING, VEHICLE, CONSUMABLE
    rarity: Rarity            # COMMON, UNCOMMON, RARE, EPIC, LEGENDARY

    # Stat bonuslari
    stat_bonuses: Dictionary  # {"strength": 5, "luck": 2}
    power_bonus: int          # Dogrudan power_score bonusu

    # Ekonomi
    buy_price: int            # Magazadan satin alma fiyati (0 = satin alinamaz)
    sell_price: int           # Satma fiyati (buy_price * 0.3)

    # Gereksinimler
    required_rank: int        # Minimum rank
    required_stats: Dictionary # {"strength": 10}

    # Gorseller
    icon_path: String         # UI ikonu
    portrait_overlay: String  # Karakter uzerinde gosterim (varsa)

    # Meta
    is_tradeable: bool        # Oyuncular arasi takas edilebilir mi
    is_stackable: bool        # Yiginlanabilir mi (tuketim esyalari)
    max_stack: int            # Maks yigin: 99
}

ItemCategory: WEAPON | ARMOR | CLOTHING | VEHICLE | CONSUMABLE
Rarity: COMMON | UNCOMMON | RARE | EPIC | LEGENDARY
```

1. Tum esyalar JSON dosyalarindan yuklenir: `assets/data/items/`
2. Calisma zamaninda ekleme/cikarma yok — sadece baslangicta yuklenir
3. Rarity renkleri: Common(gri), Uncommon(yesil), Rare(mavi), Epic(mor), Legendary(altin)
4. `sell_price = floor(buy_price * SELL_RATIO)` otomatik hesaplanir

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Inventory & Equipment | <- | `get_item(item_id) -> ItemDefinition` |
| Shop System | <- | Satilik esyalari listeler, fiyat okur |
| Mission System | <- | Loot tablolari icin esya havuzunu saglar |
| Gang War | <- | Ekipman power bonuslarini okur |

## Formulas

```
# Satis fiyati
sell_price = floor(buy_price * SELL_RATIO)  # SELL_RATIO = 0.3

# Rarity guc carpani
rarity_power_multiplier = {COMMON: 1.0, UNCOMMON: 1.3, RARE: 1.7, EPIC: 2.2, LEGENDARY: 3.0}

# Drop olasiligi (Mission System'de kullanilir)
drop_chance = {COMMON: 0.60, UNCOMMON: 0.25, RARE: 0.10, EPIC: 0.04, LEGENDARY: 0.01}
```

## Edge Cases

| Durum | Cozum |
|---|---|
| Esya JSON'i bozuk/eksik | Baslangicta validasyon, hata logla, oyunu baslatma |
| Ayni item_id'den 2 tane | JSON yukleme sirasinda duplikat tespiti, ikincisi reddedilir |
| Rank gereksinimsiz legendary | Tum legendary esyalarin minimum rank 10 olmasi zorunlu |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Inventory & Equipment | Downstream | Esya tanimlarini saglar |
| Shop System | Downstream | Fiyat ve gereksinim bilgisi |
| Mission System | Downstream | Loot havuzu |
| Cosmetic System | Downstream (Tier 4) | Kozmetik esya tanimlari |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `SELL_RATIO` | 0.3 | 0.1-0.5 | Ekonomi hizi — yuksek = daha fazla cash dongusu |
| `DROP_CHANCE_*` | Yukaridaki tablo | 0.001-0.99 | Loot heyecani vs frustrasyon |
| `RARITY_POWER_MULTIPLIER_*` | Yukaridaki tablo | 1.0-5.0 | Nadir esyalarin guc etkisi |

## Acceptance Criteria

- [ ] Tum esyalar JSON'dan yuklenir, kod degisikligi gerektirmez
- [ ] Duplikat item_id tespiti calisir
- [ ] Bozuk JSON baslangicta yakalanir
- [ ] `sell_price` otomatik hesaplanir
- [ ] Rarity bazli filtreleme calisir
- [ ] Rank gereksinimleri dogrulanir (yetersiz rank = kullanilamaz)
