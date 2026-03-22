# Shop System

> **Status**: Designed
> **Author**: user + economy-designer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Instant Read, Street Cred

## Overview

Oyuncunun silah, ekipman ve tuketim esyasi satin aldigi magaza. Rank bazli envanter
— rank yukseldikce yeni esyalar acilir. Fiyatlar Item Database'den gelir.

## Player Fantasy

"Magazaya giriyorum, yeni bir silah aliyorum, aninda daha guclu hissediyorum."

## Detailed Design

### Core Rules

1. Magaza sabit envanter — Item Database'den rank'a uygun esyalari gosterir
2. Satin alma: cash harcanir (Economy), esya envantere eklenir (Inventory)
3. Satma: esya envanterden cikarilir, sell_price cash kazanilir
4. Rank yetersizse esya gri gosterilir, satin alinamaz
5. Envanter doluysa satin alinamaz

### Magaza Kategorileri

```
Sekmeler:
  1. Silahlar (WEAPON)
  2. Zirh (ARMOR)
  3. Kiyafet (CLOTHING)
  4. Tuketim (CONSUMABLE) — stamina refill, stat boost (gecici)
```

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Economy | <-> | `spend_cash()`, `add_cash()` (satista) |
| Item Database | Upstream | Esya tanimlari, fiyatlar |
| Inventory | Downstream | Esya ekle/cikar |
| Player Data | Upstream | Rank kontrolu |
| Character Progression | Upstream | Rank'a gore esya acilimi |

## Formulas

```
# Satin alma
buy_result = spend_cash(player_id, item.buy_price, "shop_purchase")
if buy_result: add_item(player_id, item.item_id, 1)

# Satma
sell_result = remove_item(player_id, item.item_id, 1)
if sell_result: add_cash(player_id, item.sell_price, "shop_sell")
```

## Edge Cases

| Durum | Cozum |
|---|---|
| Cash tam yetmiyor | "Yetersiz bakiye" + eksik miktari goster |
| Envanter dolu | "Envanter dolu — once bir esya sat" |
| Ayni esyadan 2 satin alma | Izin ver (yedek veya satma amaFcli) |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Economy | Upstream (hard) | Cash islemi |
| Item Database | Upstream (hard) | Esya/fiyat verisi |
| Inventory | Downstream (hard) | Esya ekleme |
| Player Data | Upstream (hard) | Rank kontrolu |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `SELL_RATIO` | 0.3 | 0.1-0.5 | Satis fiyati orani |
| `SHOP_REFRESH_ON_RANK_UP` | true | bool | Rank'ta yeni esyalar gosterilsin mi |

## Acceptance Criteria

- [ ] Rank'a uygun esyalar listelenir
- [ ] Satin alma cash harcar, esya envantere eklenir
- [ ] Satma esya cikarir, cash verir
- [ ] Rank yetersiz esya satin alinamaz
- [ ] Envanter dolu kontrolu calisir
