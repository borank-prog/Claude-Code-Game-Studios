# Sprint 1 — 2026-03-24 to 2026-04-06

## Sprint Goal

Godot proje yapisini kur, foundation sistemlerini (Player Data, Economy, Item Database,
Auth, UI Framework) implement et ve temel ekran navigasyonunu calistir.

## Capacity

- Total days: 14 (2 hafta)
- Buffer (20%): 3 gun (unplanned work, ogrenme suresi)
- Available: 11 gun
- Developer: 1 (solo)

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S1-01 | Godot 4.6 proje yapisini olustur (src/ dizin yapisi, autoload'lar, export ayarlari) | lead-programmer | 0.5 | — | Proje acilir, bos sahne calisir, Android export template yuklenir |
| S1-02 | PlayerData sinifinı implement et (autoload, tum alanlar, serialize/deserialize) | systems-designer, gameplay-programmer | 1.5 | S1-01 | Tum alanlar tanimli, delta bazli stat degisiklik, serialize/deserialize unit test |
| S1-03 | Economy sistemi (Currency manager, Transaction log, cash/premium islemleri) | economy-designer, gameplay-programmer | 1.5 | S1-02 | add_cash, spend_cash, transaction log calisir, negatif bakiye engellenir |
| S1-04 | Item Database (JSON loader, esya tanimlari, rarity sistemi) | systems-designer, gameplay-programmer | 1 | S1-01 | JSON'dan esya yuklenir, duplikat tespiti, rarity filtreleme calisir |
| S1-05 | Firebase Auth entegrasyonu (Guest login, hesap baglama flow) | network-programmer | 2 | S1-01 | Guest giris 0 surtuNme, token yenileme, 2 cihaz kontrolu |
| S1-06 | UI Framework (ekran yonetici, tab bar, tema, popup sistemi) | ux-designer, ui-programmer | 2 | S1-01 | 5 tab navigasyon, 3-tap kurali, tema renkleri, popup kuyrugu |
| S1-07 | Stamina sistemi (lazy regen, harcama, HUD bar) | systems-designer, gameplay-programmer | 1 | S1-02 | Regen dogru hesaplanir (server zaman), harcama calisir, bar gosterimi |
| S1-08 | Cloud Save temeli (Firestore baglantisi, PlayerData sync) | network-programmer | 1.5 | S1-02, S1-05 | Veri kaydedilir, cihaz degistirmede veri gelir, offline cache |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S1-09 | MVP esya JSON dosyalarini olustur (10 silah, 5 zirh, 5 kiyafet) | game-designer | 0.5 | S1-04 | 20 esya tanimli, rarity dagilimi dogru, fiyatlar dengeli |
| S1-10 | Profil ekrani (avatar, rank, statlar, power score) | ui-programmer | 1 | S1-02, S1-06 | Tum bilgiler dogru gosterilir, tema uyumlu |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S1-11 | Android export test (APK olustur, fiziksel cihazda calistir) | devops-engineer | 0.5 | S1-01 | APK olusur, bos sahne cihazda calisir |
| S1-12 | GUT test framework kurulumu + ilk unit testler | qa-lead | 0.5 | S1-02, S1-03 | PlayerData + Economy unit testleri gecerli |

## Carryover from Previous Sprint

Yok — ilk sprint.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Firebase Godot 4.6 uyumluluk sorunu | ORTA | YUKSEK | GodotFirebase addon'u kontrol et, alternatif: Supabase |
| Godot 4.6 mobil export sorunlari | DUSUK | ORTA | Erken S1-11 ile test et, 4.5'e donme plani hazir |
| Solo dev olarak 11 gune sigmama | ORTA | ORTA | Nice to Have'leri kes, Should Have'leri Sprint 2'ye tasi |
| JSON item loading performansi | DUSUK | DUSUK | Lazy loading, cache |

## Dependencies on External Factors

- Firebase hesabi olusturma ve proje kurulumu
- Godot 4.6 stable indirme ve Android export template
- Android SDK / cihaz erisimi (test icin)
- Google Play Developer hesabi (ileride, bu sprintte degil)

## Definition of Done for this Sprint

- [ ] Tum Must Have taskleri tamamlandi
- [ ] PlayerData + Economy + Stamina unit testleri geciyor
- [ ] Firebase guest login calisir durumda
- [ ] UI Framework ile ekranlar arasi navigasyon calisir
- [ ] Veri Firestore'a kaydediliyor ve geri yuklenebiliyor
- [ ] Kod design doc'lardaki kurallara uygun
- [ ] Git'e commit edilmis, temiz calisan durumda

---

## Sprint 2 Onizleme

Sprint 2'de implement edilecekler:
- Character Progression (rank, stat dagitimi)
- Inventory & Equipment (envanter, kusanma)
- Mission System (3 gorev tipi, basari hesabi, loot)
- Shop System (satin alma, satma)
- HUD & Feedback (animasyonlar, bildirimler)

Bu, solo core loop'un calisir hale gelmesini saglayacak.
