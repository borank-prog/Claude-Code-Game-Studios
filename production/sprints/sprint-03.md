# Sprint 3 — 2026-04-21 to 2026-05-04

## Sprint Goal

Territory Map'i gorsel haritaya donustur, Building placement UI'i tamamla,
Gang System'i Firebase ile senkronize et ve tum sistemleri entegrasyon testi ile dogrula.

## Capacity

- Total days: 14 (2 hafta)
- Buffer (20%): 3 gun (unplanned work, bug fix)
- Available: 11 gun
- Developer: 1 (solo)

## Sprint 2 Velocity

Sprint 2'de 11 task tamamlandi (9 Must + 2 Should).
Cloud Save, HUD animasyonlari, 96 unit test, avatar sistemi, 30 gorev balance.
Tum Must Have'ler bitti, Should Have'ler de bitti.
Velocity: yuksek — solo dev plan ustuNde ilerliyor.

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S3-01 | Territory Map gorsel harita — 10 bolge node'u, baglanti cizgileri, tier bazli yerlesim, renk kodlama (altin/kirmizi/gri), aktif savas icin flash animasyonu | ui-programmer | 2.5 | — | Harita goruntulenir, tier'lar ayirt edilir, kontrol renkleri dogru |
| S3-02 | Map zoom & pan — pinch-to-zoom (0.5x-3.0x), drag pan, double-tap zoom, minimap gostergesi | ui-programmer | 1 | S3-01 | Mobilde smooth zoom/pan, minimap konumu dogru |
| S3-03 | Territory detail popup — tap'te acilan popup: gelir, savunma, binalar, aksiyonlar (ele gecir/baskin/bina), komsuluk gorseli | ui-programmer | 1 | S3-01 | Popup tum bilgileri gosterir, aksiyonlar calisir |
| S3-04 | Building placement UI — bina secim listesi, maliyet gosterimi, slot doluluğu, insa timer, yukseltme/yikma butonlari | ui-programmer | 1.5 | S3-03 | Bina secimi calisir, slot kontrolu dogru, timer gorunur |
| S3-05 | Gang Firebase sync — cete verisi Firestore'a kaydetme/yukleme, uye listesi guncelleme, kasa sync | network-programmer | 2 | — | Cete olusturma/ayrılma Firestore'a yansir, veri cihaz degistirmede korunur |
| S3-06 | Gang davet sistemi — davet kodu olusturma, kod ile katilma, join_policy kontrol | gameplay-programmer | 1 | S3-05 | Davet kodu paylasılir, diger oyuncu kodla katilir |
| S3-07 | Building + GangWar unit testleri — BuildingManager (insa, yukselt, yik, gelir, savunma, slot) + GangWarManager (declare, resolve, power calc) icin GUT testleri | qa-lead | 1.5 | — | Her sistem min 15 test, tum testler gecer |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S3-08 | Cloud Save genisletme — Inventory, Gang, Territory, Building verilerini de kaydet/yukle | network-programmer | 1 | S3-05 | Tum oyuncu verisi cloud'da, cihaz degistirmede envanter/cete/bolge korunur |
| S3-09 | Entegrasyon testi — uctan uca senaryo: hesap olustur -> gorev yap -> esya al -> cete kur -> bolge ele gecir -> bina in -> kaydet/yukle | qa-lead | 0.5 | S3-07 | Senaryo basariyla tamamlanir, veri tutarli |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S3-10 | Map gorselleri — bolge ikon/arka plan resimleri (placeholder art), tier rozeti, gelir gostergesi | technical-artist | 1 | S3-01 | Her bolge ayirt edilir gorsele sahip |
| S3-11 | Gang ekrani polish — level progress bar, rol rozeti, uye power gostergesi, kasaya katki oran grafi | ui-programmer | 1 | S3-05 | Gang ekrani bilgilendirici ve estetik |
| S3-12 | Android APK test — Sprint 2 + Sprint 3 ozellikleri mobilde | devops-engineer | 0.5 | S3-09 | APK calisir, harita scroll/zoom mobilde akici |

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|---|---|---|
| S2-09: Android APK test | Manuel test — kullanici tarafindan yapilacak | 0.5 gun |

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Gorsel harita performansi (10+ node + baglanti cizgileri) | DUSUK | ORTA | Basit Control node'lari kullan, Canvas item degil |
| Firebase cete sync race condition (2 oyuncu ayni anda guncelleme) | ORTA | YUKSEK | Server timestamp + last-writer-wins, transaction kullan |
| Zoom/pan mobil dokunmatik uyumsuzlugu | DUSUK | ORTA | Godot InputEventScreenDrag/Pinch kullan, erken test |
| Building timer dogrulugu (offline/resume) | DUSUK | DUSUK | Server timestamp bazli, client clock'a guvenme |

## Dependencies on External Factors

- Firebase Firestore kurallari (cete collection ekleme)
- Placeholder art asset'ler (bolge ikonlari — yoksa renkli rect kullan)
- Android test cihazi/emulator

## Definition of Done for this Sprint

- [x] Territory Map gorsel harita calisir (zoom, pan, renk kodlama)
- [x] Bolge detay popup'i ve aksiyonlar dogru calisir
- [x] Building placement UI ile bina secme/insa/yukseltme calisir
- [x] Gang verisi Firebase'e senkronize ediliyor
- [x] Davet kodu ile ceteye katilma calisir
- [x] Building + GangWar unit testleri geciyor
- [x] Cloud Save tum verileri kapsiyor
- [ ] Git'e commit edilmis, temiz calisan durumda

---

## Sprint 4 Onizleme

Sprint 4'te odak:
- Gang War UI (baskin hazirlama ekrani, katilim, sonuc animasyonu)
- Gang War balance tuning (guc hesabi, RNG, odul dengesi)
- UI polish (tum ekranlar tema uyumlu, animasyonlar tutarli)
- Performance profiling (mobil hedef: 60fps, 16.6ms frame budget)
- Full integration test + Android APK
