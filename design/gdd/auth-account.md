# Auth & Account

> **Status**: Designed
> **Author**: user + network-programmer
> **Last Updated**: 2026-03-22
> **Implements Pillar**: Rise Together (multiplayer altyapisi)

## Overview

Oyuncu kimlik dogrulama ve hesap yonetimi. Firebase Authentication uzerinde calisir.
Misafir giris, e-posta, Google ve Apple Sign-In destekler. Oyuncu ilk acilista
otomatik misafir hesap olusturur, sonra kalici hesaba baglar.

## Player Fantasy

Altyapi sistemi — oyuncu farketmez. Hedef: "Acildim, hemen oynuyorum. Hesabim
guvende, baska cihazda devam edebilirim."

## Detailed Design

### Core Rules

```
AuthProvider: GUEST | EMAIL | GOOGLE | APPLE

AccountState {
    auth_id: String          # Firebase UID
    provider: AuthProvider
    email: String?           # Guest'te null
    is_linked: bool          # Guest -> kalici hesaba bagli mi
    created_at: DateTime
    last_auth: DateTime
    ban_status: BanStatus    # NONE, TEMPORARY, PERMANENT
    ban_expires: DateTime?   # TEMPORARY icin
}
```

1. Ilk acilista otomatik GUEST hesap olusturulur (sifir surtuNme)
2. Guest hesap cihaza bagli — cihaz degisirse kaybolur
3. "Hesabini bagla" ile Guest -> Email/Google/Apple'a yukseltilir
4. Baglanan hesap birden fazla cihazda kullanilabilir
5. Ban durumu server-side kontrol edilir, client manipule edemez

### Auth Flow

```
App acildi
  -> Firebase Auth kontrol
  -> Token var mi?
     EVET -> Token gecerli mi? -> EVET -> Giris basarili -> PlayerData yukle
                                -> HAYIR -> Yeniden auth -> Giris
     HAYIR -> Guest hesap olustur -> player_id ata -> PlayerData olustur
```

### Interactions with Other Systems

| Sistem | Yon | Arayuz |
|---|---|---|
| Player Data | Economy -> | `create_player(auth_id) -> player_id` |
| Cloud Save | <- | Auth token ile backend erisimi |
| Gang System | <- | Oyuncu kimligini dogrular |
| Push Notifications | <- | Device token kaydeder |
| Analytics | <- | Anonim/kimlikli izleme |

## Formulas

Yok — bu sistem hesaplama yapmaz, kimlik dogrulama yapar.

## Edge Cases

| Durum | Cozum |
|---|---|
| Guest hesap, uygulama silindi | Veri kaybolur — "hesabini bagla" uyarisi goster |
| Token suresi dolmus | Arka planda sessiz token yenileme |
| Ayni email 2 farkli provider | Firebase link hatasi — kullaniciya acikla |
| Ban suresi dolmus | Otomatik NONE'a don, girise izin ver |
| Sunucu erisimi yok (offline) | Yerel cache ile son oturumu goster, yazma islemleri kuyruga al |

## Dependencies

| Bagimlilik | Yon | Tip |
|---|---|---|
| Firebase Auth | External (hard) | Kimlik dogrulama servisi |
| Player Data | Downstream (hard) | Yeni hesapta PlayerData olusturur |
| Cloud Save | Downstream (hard) | Auth token saglar |
| Push Notifications | Downstream (soft) | Device token kaydeder |

## Tuning Knobs

| Knob | Varsayilan | Aralik | Etki |
|---|---|---|---|
| `GUEST_LINK_REMINDER_INTERVAL` | 3 gun | 1-7 gun | Hesap baglama hatirlatma sikligi |
| `TOKEN_REFRESH_INTERVAL` | 55 dk | 30-59 dk | Firebase token 60dk'da biter |
| `OFFLINE_QUEUE_MAX` | 50 islem | 10-200 | Cevrimdisi kuyruk boyutu |

## Acceptance Criteria

- [ ] Ilk acilista 0 surtuNmeyle guest giris yapilir
- [ ] Guest -> Email/Google/Apple baglama calisir
- [ ] Bagli hesap baska cihazda giris yapabilir
- [ ] Token otomatik yenilenir
- [ ] Banlanan oyuncu giris yapamaz (PERMANENT) veya sure sonunda yapar (TEMPORARY)
- [ ] Offline modda yerel cache calisir
- [ ] 2 cihaz ayni anda -> eski oturum kapatilir
