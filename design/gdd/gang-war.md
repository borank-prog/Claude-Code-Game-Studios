# Gang War (Async PvP)

> **Status**: Designed
> **Author**: user + game-designer, ai-programmer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Rise Together (ANA), Street Cred, Always a Next Move

## Overview

Oyunun sosyal rekabet cekirdegi. Ceteler birbirlerinin bolgelerine asenkron baskinlar
duzenler. Saldiran cete saldiri gucu olusturur, savunan cete savunma gucu + binalarla
korunur. Sonuc server-side hesaplanir — oyuncular cevrimdisi bile saldiriya ugramakta.
Bu, oyuncuyu "cetem guclu olmali" motivasyonuyla geri getiren ANA retention mekanizmasidir.

## Player Fantasy

"Rakip cetenin bolgesine goz diktik. Gece baskin planliyoruz — sonucu sabah gorecegiz.
Eger kazanirsak, o bolge artik bizim."

## Detailed Design

### Core Rules

```
Raid {
    raid_id: String
    attacker_gang_id: String
    defender_gang_id: String
    target_territory_id: String

    # Gucler
    attack_power: int           # Saldiri takiminin toplam gucu
    defense_power: int          # Savunma gucu (uyeler + binalar + entrenchment)

    # Katilimcilar
    attackers: RaidParticipant[]  # Saldiriya katilan uyeler
    defenders: RaidParticipant[]  # Savunmaya katilan uyeler (otomatik)

    # Zamanlama
    declared_at: DateTime        # Baskin ilan zamani
    resolves_at: DateTime        # Sonuc zamani (declared + WAR_DURATION)
    resolved: bool

    # Sonuc
    result: RaidResult?          # ATTACKER_WIN, DEFENDER_WIN, DRAW
    territory_changed: bool
    loot_stolen: int             # Kazanan tarafa cash odul
}

RaidParticipant {
    player_id: String
    power_contribution: int      # O oyuncunun power_score + equipment_power
    stamina_spent: int           # Katilim maliyeti
}

RaidResult: ATTACKER_WIN | DEFENDER_WIN | DRAW
```

### Savas Akisi

```
1. ILAN (Leader/Officer baslatir)
   - Hedef bolge secilir (komsuluk kontrolu)
   - Stamina maliyeti: RAID_DECLARE_COST (leader'dan)
   - Savunan ceteye bildirim gider
   - WAR_PREPARATION_HOURS suresi baslar

2. HAZIRLIK (WAR_PREPARATION_HOURS = 4 saat)
   - Saldiran cete uyeleri katilim bildirir (stamina harcanir)
   - Savunan cete uyeleri savunmaya katilir (otomatik + aktif takviye)
   - Her iki taraf guc barini gorur (ama kesin rakam gizli)
   - Son 1 saat: yeni katilim kabul edilmez (kilitlenme)

3. COZUM (server-side, otomatik)
   - attack_power vs defense_power karsilastirilir
   - Sonuc hesaplanir (asagidaki formul)
   - Kazanan/kaybeden belirlenir
   - Bolge el degistirme uygulanir
   - Loot dagitimi yapilir
   - Her iki tarafa sonuc bildirimi

4. SONUC EKRANI
   - Detayli savas raporu (kim ne katki yapti)
   - Bolge durumu guncellenmis harita
   - Loot dagitimi
   - MVP (en cok katki yapan oyuncu) vurgulanir
```

### Guc Hesaplama

```
# Saldiri gucu
attack_power = sum(attacker.power_score + attacker.equipment_power
                   for attacker in attackers)
attack_power *= ATTACK_MORALE_BONUS  # Katilimci sayisi bonusu

# Savunma gucu
defense_power = sum(defender.power_score + defender.equipment_power
                    for defender in active_defenders)
defense_power += territory.defense_bonus          # Bina savunmasi
defense_power *= (1 + territory.control_strength * ENTRENCHMENT_MULTIPLIER)
                                                   # Yerlesme bonusu

# Morale bonusu (katilimci sayisi)
morale_bonus = 1.0 + (participant_count * MORALE_PER_MEMBER)
# MORALE_PER_MEMBER = 0.05 -> 10 kisi = %50 bonus
```

### Sonuc Hesaplama

```
# Guc orani
power_ratio = attack_power / defense_power

# Sonuc belirleme
if power_ratio >= WIN_THRESHOLD:       # 1.2 (saldiri %20 guclu)
    result = ATTACKER_WIN
elif power_ratio <= LOSE_THRESHOLD:    # 0.8 (savunma %20 guclu)
    result = DEFENDER_WIN
else:
    result = DRAW                      # Bolge el degistirmez

# RNG faktoru (kucuk surpriz)
final_ratio = power_ratio * random(0.9, 1.1)  # %10 varyans
```

### Oduller ve Cezalar

```
ATTACKER_WIN:
  - Bolge el degistirir
  - Saldiran cete: loot = defender_territory_income * LOOT_HOURS
  - Savunma binalari %50 hasar alir (level duser)
  - Saldiran tum katilimcilar respect kazanir

DEFENDER_WIN:
  - Bolge el degistirmez
  - Savunan cete: bonus control_strength
  - Saldiran cete: harcanan stamina kayip, respect yok

DRAW:
  - Bolge el degistirmez
  - Her iki taraf kucuk respect odulu
  - 24 saat ayni bolgeye yeni baskin yapilamaz
```

### Savas Kisitlamalari

1. Ayni bolgeye 24 saat icinde sadece 1 baskin
2. Bir cete ayni anda max 2 savas yurUtebilir (1 saldiri + 1 savunma)
3. Sadece KOMSFU bolgelere saldirabilirsin
4. Min 3 katilimci saldiri icin gerekli
5. Savunma otomatik — cevrimdisi uyeler de power'lariyla katilir

### States and Transitions

| Durum | Gecis |
|---|---|
| Baris (bolge icin) | -> Ilan edildi (saldiri baslatildi) |
| Hazirlik | -> Kilitlendi (son 1 saat) |
| Kilitlendi | -> Cozum (sure doldu) |
| Cozum | -> Sonuc (hesaplama tamamlandi) |
| Sonuc | -> Baris (24s cooldown sonrasi) |

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Gang System | Upstream (hard) | Cete uyeleri, roller, yetki kontrolu |
| Territory Map | <-> | Hedef bolge, sonucta el degistirme |
| Character Progression | <- | Savas respect odulu |
| Player Data | <- | power_score, equipment_power okur |
| Inventory | <- | Ekipman gucu hesabi |
| Building System | <-> | Savunma bonusu, savas hasari |
| Economy | <-> | Loot dagitimi |
| Stamina | <- | Katilim maliyeti |
| Push Notifications | <- | Savas bildirimleri |
| HUD & Feedback | <- | Savas durumu, sonuc ekrani |

## Formulas

```
# Toplam saldiri gucu
attack_power = sum(p.power_score + p.equipment_power for p in attackers)
             * (1 + len(attackers) * MORALE_PER_MEMBER)

# Toplam savunma gucu
defense_power = sum(p.power_score + p.equipment_power for p in defenders)
              + territory.building_defense
              * (1 + territory.control_strength * ENTRENCHMENT_MULTIPLIER)

# Guc orani + RNG
final_ratio = (attack_power / defense_power) * uniform(0.9, 1.1)

# Sonuc
ATTACKER_WIN if final_ratio >= 1.2
DEFENDER_WIN if final_ratio <= 0.8
DRAW otherwise

# Loot
loot = territory.base_income_per_hour * LOOT_HOURS
# Saldiri galibiyetinde kasadan veya bolge gelirinden

# Respect odulu
war_respect = BASE_WAR_RESPECT * difficulty_factor
difficulty_factor = max(1.0, defender_power / attacker_power)
# Guclu rakibi yenmek daha fazla respect verir
```

## Edge Cases

| Durum | Cozum |
|---|---|
| Saldiri ilan edildi ama kimse katilmadi | Min 3 katilimci kurali — 3'e ulasilmazsa baskin iptal |
| Savunan cete 0 cevrimici uye | Cevrimdisi uyeler otomatik savunur (power'lariyla) |
| Savas sirasinda uye ceteden ayrildi | Savastan cikarilir, gucu duser |
| Savas sirasinda uye ban yedi | Gucu cikarilir, sonuc yeniden hesaplanir |
| Her iki cete esit gucte | DRAW — bolge el degistirmez, 24s cooldown |
| Saldiran cete savas sirasinda dagildi | Baskin iptal, bolge degismez |
| Ayni bolgeye 2 cete ayni anda saldiriyor | Ilk ilan oncelikli, ikinci reddedilir |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Gang System | Upstream (hard) | Cete uyeleri, roller |
| Territory Map | Upstream (hard) | Bolge bilgisi, komsuluk |
| Player Data | Upstream (hard) | power_score |
| Inventory | Upstream (hard) | equipment_power |
| Building System | Upstream (hard) | Savunma bonusu |
| Stamina | Upstream (hard) | Katilim maliyeti |
| Economy | Downstream (hard) | Loot dagitimi |
| Character Progression | Downstream (hard) | Respect odulu |
| Push Notifications | Downstream (soft) | Savas bildirimleri |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `WAR_PREPARATION_HOURS` | 4 | 1-12 | Hazirlik suresi |
| `WAR_LOCKOUT_HOURS` | 1 | 0.5-3 | Kilitlenme suresi |
| `WIN_THRESHOLD` | 1.2 | 1.05-1.5 | Saldiri avantaj gereksinimi |
| `LOSE_THRESHOLD` | 0.8 | 0.5-0.95 | Savunma avantaj gereksinimi |
| `RNG_VARIANCE` | 0.1 | 0-0.25 | Surpriz faktoru |
| `MORALE_PER_MEMBER` | 0.05 | 0.02-0.10 | Katilimci sayisi bonusu |
| `ENTRENCHMENT_MULTIPLIER` | 0.5 | 0.1-1.0 | Yerlesmislik avantaji |
| `LOOT_HOURS` | 6 | 2-24 | Galibiyet lootu (saat bazli gelir) |
| `BASE_WAR_RESPECT` | 200 | 50-1000 | Savas respect bazali |
| `MIN_ATTACKERS` | 3 | 1-5 | Min saldiri katilimci |
| `RAID_COOLDOWN_HOURS` | 24 | 6-48 | Ayni bolge tekrar saldiri bekleme |
| `RAID_DECLARE_COST` | 15 stamina | 5-30 | Baskin ilan maliyeti |
| `RAID_JOIN_COST` | 10 stamina | 3-20 | Baskina katilim maliyeti |

## Acceptance Criteria

- [ ] Baskin ilan etme — komsuluk kontrolu, stamina maliyeti calisir
- [ ] Hazirlik suresi — iki taraf katilimci toplar
- [ ] Kilitlenme — son 1 saat yeni katilim engellenir
- [ ] Guc hesabi dogru: saldiri vs savunma (binalar + entrenchment dahil)
- [ ] RNG varyansı %10 icerisinde
- [ ] Sonuclar dogru: ATTACKER_WIN, DEFENDER_WIN, DRAW esikleri
- [ ] Bolge el degistirme calisir (saldiri galibiyeti)
- [ ] Loot dagitimi calisir
- [ ] Respect odulu verilir
- [ ] 24s cooldown ayni bolgeye uygulanir
- [ ] Min 3 katilimci kurali
- [ ] Cevrimdisi uyeler otomatik savunur
- [ ] Push bildirimleri gonderilir (ilan, sonuc)
- [ ] Savas raporu detayli goruntulenir
