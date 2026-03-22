# Inventory & Equipment

> **Status**: Designed
> **Author**: user + systems-designer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Street Cred, Eye Candy

## Overview

Oyuncunun sahip oldugu esyalari depolayan ve kusanma (equip) islemlerini yoneten
sistem. Envanter slot bazli, ekipman kategorilere ayrilir. Kusanilan esyalar statlara
bonus verir ve karakter gorselini etkiler.

## Player Fantasy

"Envanterim doluyor, daha guclu silahlari kusaniyorum, gorunusum degisiyor.
Nadir bir esya dustugunde heyecanlaniyorum."

## Detailed Design

### Core Rules

```
InventorySlot {
    item_id: String
    quantity: int          # Stackable esyalar icin (silahlar = 1)
}

EquipmentSlots {
    weapon: String?        # item_id veya null
    armor: String?
    clothing: String?
    vehicle: String?       # Tier 3'te aktif
    accessory_1: String?
    accessory_2: String?
}

MAX_INVENTORY_SLOTS = 50  # Baslangic
```

1. Envanter slot sinirli — doluysa yeni esya alinamaz (sat veya at)
2. Ekipman slotlarina sadece dogru kategoriden esya konulabilir
3. Kusanma anliktir — cooldown yok
4. Kusanilan esya stat bonusu aninda uygulanir
5. Esya satma: sell_price cash kazandirir
6. Stackable (tuketim) esyalar ayni slotta birikir

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Player Data | Upstream | player_id referansi |
| Item Database | Upstream | Esya tanimlarini okur |
| Economy | <-> | Esya satista cash kazanimi |
| Shop System | <- | Satin alinan esya envantere eklenir |
| Mission System | <- | Loot envantere eklenir |
| Gang War | <- | Ekipman power_bonus okur |
| Character Visuals | <- | Kusanilan esya gorsellerini okur |

## Formulas

```
# Toplam ekipman gucu
equipment_power = sum(equipped_item.power_bonus for item in equipped_items)

# Toplam stat bonusu (her stat icin)
equipment_stat_bonus(stat) = sum(item.stat_bonuses[stat] for item in equipped_items)

# Envanter genisletme maliyeti (Tier 4 ozellik)
expand_cost = BASE_EXPAND_COST * (1.5 ^ expansion_count)
```

## Edge Cases

| Durum | Cozum |
|---|---|
| Envanter dolu, gorev loot dusturuyor | "Envanter dolu" uyarisi, loot 24s temp stash'te bekler |
| Kusanili esya satilmaya calisilir | Once cikar, sonra sat — tek islemde yapilabilir |
| Rank duserse kusanilan esya rank gereksinimini karsilamaz | Rank dusmez (kural), bu durum olusumaz |
| Ayni esyadan 2 kusanma | Ekipman slotlari benzersiz — ayni esya 2 slota konulamaz |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Player Data | Upstream (hard) | player_id |
| Item Database | Upstream (hard) | Esya tanimlari |
| Economy | Downstream | Satis geliri |
| Shop/Mission | Downstream | Esya ekleme |
| Gang War | Downstream | Ekipman gucu |
| Character Visuals | Downstream | Gorsel guncelleme |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `MAX_INVENTORY_SLOTS` | 50 | 20-200 | Envanter yonetim baskisi |
| `TEMP_STASH_DURATION` | 24 saat | 1-72 saat | Loot kaybetme baskisi |
| `BASE_EXPAND_COST` | 500 premium | 100-2000 | Monetizasyon firsati |

## Acceptance Criteria

- [ ] Envanter slot siniri calisir
- [ ] Kusanma dogru slota, dogru kategoriyle calisir
- [ ] Stat bonuslari aninda uygulanir/kaldirilir
- [ ] Esya satisi dogru cash verir
- [ ] Dolu envanterde loot temp stash'e gider
- [ ] Stackable esyalar dogru birikir
