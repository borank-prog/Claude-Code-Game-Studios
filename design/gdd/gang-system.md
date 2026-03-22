# Gang System

> **Status**: Designed
> **Author**: user + game-designer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Rise Together (ANA SUTUN), Street Cred

## Overview

Oyunun sosyal cekirdegi. Oyuncular cete kurar, arkadaslarini davet eder, birlikte
bolge kontrol eder ve savasir. Cete sistemi olmadan CartelHood sadece bir solo idle
oyunu olurdu — cete, oyunu sosyal deneyime donusteren unsurdur.

## Player Fantasy

"Cetemiz buyuyor, guc kazaniyoruz, kimse bize dokunamiyor. Arkadaslarimla birlikte
bu sehri yonetiyoruz."

## Detailed Design

### Core Rules

```
Gang {
    gang_id: String              # UUID
    name: String                 # 3-20 karakter, benzersiz
    tag: String                  # 2-4 karakter kisaltma: "[CH]"
    emblem_id: int               # Cete amblemi
    created_at: DateTime

    # Uyeler
    members: GangMember[]        # Max GANG_MAX_MEMBERS
    member_count: int

    # Seviye & Guc
    gang_level: int              # 1-20
    gang_xp: int                 # Uye katkilarindan birikir
    total_power: int             # Tum uyelerin power_score toplami

    # Ekonomi
    treasury: int                # Cete kasasi (ortak cash)
    treasury_log: Transaction[]  # Katkı/cekim gecmisi

    # Bolge
    controlled_territories: String[] # Kontrol edilen bolge ID'leri

    # Ayarlar
    join_policy: JoinPolicy      # OPEN, APPROVAL, INVITE_ONLY
    min_rank_to_join: int        # Minimum rank gereksinimiF
}

GangMember {
    player_id: String
    role: GangRole               # LEADER, OFFICER, MEMBER
    joined_at: DateTime
    contribution: int            # Toplam cete XP katkisi
}

GangRole: LEADER | OFFICER | MEMBER
JoinPolicy: OPEN | APPROVAL | INVITE_ONLY
```

### Rol Yetkileri

| Yetki | Leader | Officer | Member |
|---|---|---|---|
| Ceteyi dagitma | ✅ | ❌ | ❌ |
| Uye atma | ✅ | ✅ | ❌ |
| Uye davet etme | ✅ | ✅ | ❌ |
| Officer atama | ✅ | ❌ | ❌ |
| Savas baslatma | ✅ | ✅ | ❌ |
| Kasadan cekim | ✅ | ✅ (limitli) | ❌ |
| Cete ayarlari | ✅ | ❌ | ❌ |
| Kasaya katki | ✅ | ✅ | ✅ |
| Gorev/savas katilim | ✅ | ✅ | ✅ |

### Cete Leveli

```
Cete XP kaynaklari:
- Uyelerin gorev tamamlamasi: gorev_respect * 0.1 = cete XP
- Bolge ele gecirme: 500 XP
- Cete savasi kazanma: 1000 XP

Level bonuslari:
- Her level: +1 max member slot
- Her 5 level: yeni cete ozelligi acilir
  - Level 5: Cete seferleri (koordineli gorevler)
  - Level 10: Cete binasi (ozel bina tipi)
  - Level 15: Ittifak kurma
  - Level 20: Uluslararasi operasyonlar
```

### Cete Olusturma Akisi

```
1. Oyuncu "Cete Kur" secer
2. Isim + tag + amblem secer
3. Katilim politikasi belirler
4. GANG_CREATION_COST cash harcanir
5. Cete olusturulur, oyuncu LEADER olur
6. Davet linki/kodu uretilir
```

### States and Transitions

| Durum | Gecis |
|---|---|
| Cetesiz | -> Cete kur / Ceteye katil |
| Cete uyesi (MEMBER) | -> Terfi (OFFICER) / Ayril / Atil |
| Officer | -> Terfi (LEADER, eski lider izin verirse) / Indir / Ayril |
| Leader | -> Ceteyi dagit / Liderlik devret |
| Cete dagildi | -> Cetesiz |

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Player Data | Upstream | `gang_id`, `gang_role` okur/yazar |
| Auth & Account | Upstream | Uye kimligi dogrular |
| Economy | <-> | Cete kasasi yonetimi |
| Territory Map | <-> | Kontrol edilen bolgeler |
| Gang War | Downstream | Savas baslatma, guc hesabi |
| Leaderboard | Downstream | Cete siralamasi |
| Chat System | Downstream | Cete sohbet kanali |
| Alliance System | Downstream | Ittifak yonetimi |

## Formulas

```
# Cete XP gereksinimleri
gang_xp_required(level) = floor(GANG_BASE_XP * (GANG_XP_GROWTH ^ level))
# GANG_BASE_XP=500, GANG_XP_GROWTH=1.6
# Level 1->2: 500 | Level 5->6: 5,243 | Level 10->11: 55,000

# Max uye sayisi
max_members = GANG_BASE_MEMBERS + (gang_level * MEMBERS_PER_LEVEL)
# GANG_BASE_MEMBERS=10, MEMBERS_PER_LEVEL=2
# Level 1: 12 | Level 10: 30 | Level 20: 50

# Cete toplam guc
total_power = sum(member.power_score for member in active_members)

# Kasadan cekim limiti (Officer)
officer_daily_withdraw = treasury * GANG_TREASURY_DAILY_WITHDRAW_PERCENT / 100
```

## Edge Cases

| Durum | Cozum |
|---|---|
| Leader oyunu birakirsa | 7 gun inaktif -> en yuksek katkili Officer otomatik leader olur |
| Son uye ayrilirsa | Cete dagilir, bolgeler tarafsiza doner |
| Cete adi uygunsuz | Profanity filter + raporlama sistemi |
| Officer tum kasayi cekmis | Gunluk cekim limiti, log tutulur, leader bildirim alir |
| Davet edilen oyuncu zaten cetede | "Zaten bir cetede" hatasi |
| Max uye sinirinda davet | "Cete dolu" hatasi, level atlayinca slot acilir |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Player Data | Upstream (hard) | gang_id, gang_role |
| Auth & Account | Upstream (hard) | Uye kimligi |
| Economy | Upstream (hard) | Cete kasasi, olusturma maliyeti |
| Territory Map | Downstream (hard) | Bolge sahipligi |
| Gang War | Downstream (hard) | Savas sistemi |
| Chat System | Downstream (soft) | Cete sohbeti |
| Leaderboard | Downstream (soft) | Cete siralamasi |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `GANG_CREATION_COST` | 5000 cash | 1000-20000 | Cete olusturma engeli |
| `GANG_BASE_MEMBERS` | 10 | 5-20 | Baslangic cete boyutu |
| `MEMBERS_PER_LEVEL` | 2 | 1-5 | Level basina uye artisi |
| `GANG_MAX_MEMBERS` | 50 | 20-100 | Mutlak uye siniri |
| `GANG_BASE_XP` | 500 | 100-2000 | Ilk level hizi |
| `GANG_XP_GROWTH` | 1.6 | 1.3-2.0 | Level zorluk artisi |
| `GANG_TREASURY_DAILY_WITHDRAW_PERCENT` | 20 | 5-50 | Kasa korumasi |
| `LEADER_INACTIVITY_DAYS` | 7 | 3-14 | Otomatik lider devri |

## Acceptance Criteria

- [ ] Cete olusturma, davet, katilma, ayrilma calisir
- [ ] 3 rol (Leader, Officer, Member) yetkileri dogru
- [ ] Cete kasasi katki/cekim limitleri calisir
- [ ] Cete level sistemi XP ile dogru calisir
- [ ] Max uye siniri level'a gore artar
- [ ] Leader inaktif kalinca otomatik devir calisir
- [ ] Cete dagilinca bolgeler tarafsiza doner
- [ ] Cete adi benzersizlik ve profanity kontrolu
- [ ] Davet linki/kodu calisir
