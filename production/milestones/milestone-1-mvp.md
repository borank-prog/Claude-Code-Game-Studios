# Milestone 1: MVP — Playable Core Loop

> **Status**: COMPLETE
> **Target Date**: 2026-06-01 (10 hafta)
> **Actual Completion**: 2026-05-19 (Sprint 5 basinda — hedefin 2 hafta oncesinde)
> **Goal**: Cekirdek donguyu test edilebilir hale getir: gorev yap, guclen, cete kur, bolge savas.

## Success Criteria

- [x] Oyuncu hesap olusturabilir (guest) — Firebase Auth, anonim giris, token refresh
- [x] Gorev yapabilir (3 tip), stamina harcar, cash/respect kazanir — 30 gorev, 4 kategori, 30s loop
- [x] Rank atlayabilir, stat dagitabilir — 20 rank, 5 stat, eksponansiyel respect egrisi
- [x] Silah/ekipman satin alabilir — Shop + Inventory, 12+ esya, rarity sistemi
- [x] Cete kurabilir, arkadas davet edebilir — Gang sistemi, davet kodu, Firebase sync
- [x] Bolge haritasini gorebilir, tarafsiz bolge ele gecirebilir — Gorsel harita, 10 bolge, zoom/pan
- [x] Bina insa edebilir — 5 bina tipi, slot sistemi, yukseltme, insa timer
- [x] Baskin baslabilir, sonuc gorebilir — War ekrani, hazirlik timer, sonuc animasyonu
- [x] Android APK export calisir — APK emulator ve cihazda test edildi

## Sprint Plani

- Sprint 1 (2 hafta): Proje altyapisi + Foundation sistemleri ✅
- Sprint 2 (2 hafta): Core sistemleri + Mission System ✅
- Sprint 3 (2 hafta): Gang System + Territory Map ✅
- Sprint 4 (2 hafta): Gang War + Building System ✅
- Sprint 5 (2 hafta): UI polish + entegrasyon + Android test ✅ (devam ediyor)

## Deliverables

### Sistemler (16 autoload)
GameData, EventBus, StaminaManager, EconomyManager, ItemDB, ScreenManager,
InventoryManager, ShopSystem, MissionSystem, TerritoryManager, GangManager,
GangWarManager, BuildingManager, FirebaseAuth, FirebaseFirestore, CloudSave

### Test Coverage
- 8 unit test dosyasi, ~195 test
- PlayerData (25), Economy (20), Stamina (18), Mission (16),
  Inventory (24), Shop (12), Gang (22), Territory (22),
  Building (20), GangWar (16)

### UI
- 5 tab ekrani: Home, Missions, Map, Gang, Shop
- War Screen (popup)
- HUD bar (rank, stamina, cash, respect)
- FeedbackController (floating text, rank-up, loot drop, mission result, raid result)
- Notification queue (max 5, slide-in)
- Avatar selector (10 karakter)
- Tutorial overlay (5 adim)
- Building placement UI

### Data
- 30 gorev (4 zorluk, 4 kategori)
- 12+ esya (silah, zirh, kiyafet, sarf)
- 10 bolge (3 tier, komsuluk grafi)
- 5 bina tipi (gelir, savunma, utility)

### Infrastructure
- Firebase Auth (guest + account linking)
- Firestore Cloud Save (conflict resolution, offline queue, CRC32)
- Gang Firebase sync + invite codes

## Known Issues

- Android APK icin her sprintte manuel test gerekli
- Performans profili henuz olusturulmadi (Sprint 5'te yapilacak)
- Ses efektleri yok (placeholder)
- Tutorial tooltip'leri basit (gorsel yonlendirme yok)

## Next: Post-MVP

- Alpha test grubu (5-10 kisi)
- Tier 2 sistemler: Chat, Alliance, Leaderboard
- Monetizasyon: Cosmetic IAP, Battle Pass
- App Store / Google Play submission
