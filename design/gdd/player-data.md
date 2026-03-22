# Player Data

> **Status**: Designed
> **Author**: user + systems-designer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Rise Together, Street Cred

## Overview

Player Data sistemi, bir oyuncunun tum kalici verilerini tutan merkezi veri
modelidir. Profil bilgileri (isim, avatar, rank), istatistikler (guc, dayaniklilik,
sans), para birimleri, envanter referanslari, cete uyeligi ve oturum durumu bu
sistemde yasar. Oyuncu dogrudan bu sistemle etkilesimez — diger tum sistemler
(Stamina, Progression, Gang, Economy) bu verileri okur ve yazar. Bu sistem olmadan
oyunda hicbir ilerleme kaydedilemez.

## Player Fantasy

Bu bir altyapi sistemidir — oyuncu bunun varligini hissetmez. Ancak dolayli olarak
"ben gucleniyor, buyuyorum, iz birakiyorum" hissini destekler. Oyuncunun profil
ekranina baktiginda gordugu her rakam, her rank, her istatistik bu sistemden gelir.
**Street Cred** sutununu dogrudan besler: "Adim bu sehirde biliniyor."

## Detailed Design

### Core Rules

```
PlayerData {
    # Kimlik
    player_id: String          # UUID, Auth sisteminden gelir
    display_name: String       # 3-16 karakter, benzersiz
    avatar_id: int             # Secili karakter portresi
    created_at: DateTime
    last_login: DateTime

    # Rank & Sayginlik
    rank: int                  # 0-19 (20 seviye: Thug -> Kingpin)
    respect: int               # Toplam sayginlik puani (ana ilerleme metrigi)
    season_respect: int        # Bu sezon kazanilan sayginlik (sifirlanir)

    # Temel Statlar
    strength: int              # Savas gucu, soygun basarisi
    endurance: int             # Stamina cap bonusu, savunma
    charisma: int              # Cete bonuslari, gorev odul carpani
    luck: int                  # Nadir loot sansi, kumarhane
    intelligence: int          # Bina yukseltme hizi, kesif

    # Ekonomi Referanslari (gercek degerler Economy sisteminde)
    cash: int                  # Birincil para birimi
    premium_currency: int      # Satin alinabilir para birimi (kozmetik)

    # Stamina Referansi (gercek mantik Stamina sisteminde)
    stamina: int               # Mevcut stamina
    max_stamina: int           # Stamina cap (base + endurance bonus)
    stamina_last_regen: DateTime  # Son regen zamani

    # Cete Referansi
    gang_id: String?           # null = cetesiz
    gang_role: GangRole?       # LEADER, OFFICER, MEMBER

    # Oturum
    is_online: bool
    current_territory: String? # Su an hangi mahallede
}
```

**Kurallar:**

1. `player_id` olusturulduktan sonra degistirilemez
2. `display_name` benzersiz olmali, 3-16 alfanumerik karakter + alt cizgi
3. Statlar minimum 1, baslangic degeri 5, maksimum rank'a bagli
4. `cash` negatif olamaz — yetersiz bakiyede islem reddedilir
5. `season_respect` her sezon baslangiCinda 0'a sifirlanir, `respect` kalir
6. Tum stat degisiklikleri **olay (event) bazli** — dogrudan set edilmez, delta uygulanir

### States and Transitions

| Durum | Aciklama | Gecis |
|---|---|---|
| **Yeni** | Hesap olusturulmus, tutorial baslamamis | -> Aktif (ilk goreve baslayinca) |
| **Aktif** | Normal oyun durumu | -> Cevrimdisi (cikis/timeout) |
| **Cevrimdisi** | Uygulamayi kapatmis | -> Aktif (giris yapinca) |
| **Yasakli** | Hile/kural ihlali | -> (geri donus yok) |

### Interactions with Other Systems

| Sistem | Yon | Veri Akisi |
|---|---|---|
| **Auth & Account** | -> Player Data | `player_id` olusturma, giris dogrulama |
| **Stamina** | <-> | Stamina okuma/yazma, `max_stamina` hesaplama icin `endurance` okur |
| **Character Progression** | -> Player Data | `rank`, `respect`, stat artislari yazar |
| **Economy** | <-> | `cash`, `premium_currency` okuma/yazma |
| **Inventory** | <- | Envanter icin `player_id` referansi |
| **Gang System** | <-> | `gang_id`, `gang_role` okuma/yazma |
| **Cloud Save** | <- | Tum PlayerData serialize edip kaydeder |
| **Mission System** | <- | Stat degerlerini gorev hesaplamalarinda okur |
| **Gang War** | <- | Savas gucu hesabi icin statlari okur |

## Formulas

```
# Baslangic stat degerleri
initial_stat = INITIAL_STAT_VALUE  # default: 5

# Stat cap (rank'a bagli)
stat_cap = STAT_CAP_BASE + (rank * STAT_CAP_PER_RANK)
# rank 0: cap = 10 + (0 * 5) = 10
# rank 10: cap = 10 + (10 * 5) = 60
# rank 19: cap = 10 + (19 * 5) = 105

# Toplam guc skoru (Gang War'da kullanilir)
power_score = (strength * POWER_WEIGHT_STRENGTH)
            + (endurance * POWER_WEIGHT_ENDURANCE)
            + (charisma * POWER_WEIGHT_OTHER)
            + (luck * POWER_WEIGHT_OTHER)
            + (intelligence * POWER_WEIGHT_OTHER)
# Baslangic: (5*3)+(5*2)+(5*1)+(5*1)+(5*1) = 40
# Max rank 19, tum statlar 105: (105*3)+(105*2)+(105*3) = 840

# Stamina cap bonusu
max_stamina = BASE_STAMINA + (endurance * STAMINA_PER_ENDURANCE)
# Baslangic: 100 + (5*2) = 110
# Max endurance 105: 100 + (105*2) = 310
```

## Edge Cases

| Durum | Cozum |
|---|---|
| `display_name` zaten alinmis | Hata dondur, oyuncu yeni isim secer |
| Stat cap'e ulasmis ama XP kazaniyor | XP kabul edilir, stat artmaz, oyuncuya bildirim |
| Ceteden atildi ama cevrimdisi | `gang_id = null`, `gang_role = null` — giris yaptiginda gorur |
| Sezon sifirlanirken oyuncu cevrimici | Server-side sifirlama, client'a push event |
| Oyuncu 2 cihazda ayni anda giris | Son giris yapan aktif, onceki oturuma "baska cihazdan giris" bildirimi |
| Cash 0'in altina dusmeye calisir | Islem reddedilir, "yetersiz bakiye" hatasi |
| Yasakli oyuncunun cete rolu | Otomatik ceteden cikarilir, lider ise sonraki officer lider olur |

## Dependencies

| Bagimlilik | Yon | Tip | Arayuz |
|---|---|---|---|
| Auth & Account | Upstream (hard) | `player_id` saglar | `create_player(auth_id) -> PlayerData` |
| Economy | Downstream (hard) | Para okur/yazar | `get_currency(player_id) -> {cash, premium}` |
| Stamina | Downstream (hard) | Stamina + endurance okur | `get_stamina_data(player_id) -> {stamina, max, regen_time}` |
| Character Progression | Downstream (hard) | Rank/stat yazar | `apply_stat_delta(player_id, stat, delta)` |
| Inventory | Downstream (hard) | player_id referansi | `get_inventory(player_id) -> Item[]` |
| Gang System | Downstream (soft) | Cete bilgisi okur/yazar | `get_gang_info(player_id) -> {gang_id, role}` |
| Cloud Save | Downstream (hard) | Tum veriyi serialize eder | `serialize() -> Dictionary` |
| Gang War | Downstream (soft) | power_score okur | `get_power_score(player_id) -> int` |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `INITIAL_STAT_VALUE` | 5 | 1-20 | Dusuk = yavas baslangic, Yuksek = hizli guc hissi |
| `STAT_CAP_BASE` | 10 | 5-50 | Dusuk = rank daha onemli, Yuksek = rank daha az onemli |
| `STAT_CAP_PER_RANK` | 5 | 1-20 | Dusuk = duz ilerleme, Yuksek = gec rank'lar cok guclu |
| `BASE_STAMINA` | 100 | 50-200 | Dusuk = kisa oturumlar, Yuksek = uzun oturumlar |
| `STAMINA_PER_ENDURANCE` | 2 | 1-5 | Dusuk = endurance az degerli, Yuksek = endurance zorunlu |
| `POWER_WEIGHT_STRENGTH` | 3 | 1-10 | Savasta strength'in agirligi |
| `POWER_WEIGHT_ENDURANCE` | 2 | 1-10 | Savasta endurance'in agirligi |
| `POWER_WEIGHT_OTHER` | 1 | 1-5 | Diger statlarin agirligi |
| `MAX_DISPLAY_NAME_LENGTH` | 16 | 10-24 | UI layout'a etkisi var |
| `MIN_DISPLAY_NAME_LENGTH` | 3 | 2-5 | Spam onleme |

## Acceptance Criteria

- [ ] Yeni oyuncu olusturuldugunda tum statlar `INITIAL_STAT_VALUE` ile baslar
- [ ] `display_name` benzersizlik kontrolu calisir (duplikat reddedilir)
- [ ] Stat degisiklikleri delta bazli uygulanir, dogrudan set mumkun degil (admin harici)
- [ ] Stat degerleri `stat_cap` uzerinde asla artmaz
- [ ] `cash` asla negatif olmaz — yetersiz bakiyede islem reddedilir
- [ ] `season_respect` sezon sonunda 0'a sifirlanir, `respect` kalir
- [ ] Cevrimdisi oyuncunun ceteden cikarilmasi giris yaptiginda yansir
- [ ] 2 cihazdan eszamanli giris -> eski oturum kapatilir
- [ ] `power_score` formulu dogru hesaplanir (birim test ile dogrulanir)
- [ ] Tum PlayerData serialize/deserialize edilebilir (Cloud Save uyumlulugu)
- [ ] Yasakli oyuncu giris yapamaz, ceteden otomatik cikarilir
- [ ] Performans: PlayerData okuma < 1ms (yerel cache), yazma < 50ms (backend)
