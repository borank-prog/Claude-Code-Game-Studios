# Sprint 2 — 2026-04-07 to 2026-04-20

## Sprint Goal

Tum MVP sistemlerini test et, eksik parcalari tamamla, Cloud Save'i saglamlastir,
HUD animasyonlarini ekle ve core loop'u uctan uca oynanabilir hale getir.

## Capacity

- Total days: 14 (2 hafta)
- Buffer (20%): 3 gun (unplanned work, bug fix)
- Available: 11 gun
- Developer: 1 (solo)

## Sprint 1 Velocity

Sprint 1'de 12 task (Must + Should + Nice to Have) tamamlandi.
Tum foundation + core + feature sistemleri kodlandi.
Sprint 2 test/polish agirlikli — daha az yeni kod, daha cok kalite.

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S2-01 | Cloud Save saglamlastirma — conflict resolution (timestamp karsilastirma), offline queue (100 op), CRC32 checksum, retry logic | network-programmer | 2 | S1-08 | Server-wins politikasi calisir, offline 100 op kuyruk test edilir, bozuk veri tespit edilir |
| S2-02 | HUD animasyonlari — floating text (cash/respect), rank-up full-screen efekti, loot drop ikon animasyonu, mission basari/basarisizlik animasyonu | ui-programmer | 2 | S1-06, S1-07 | Tum animasyonlar 0.3s icinde gosterilir, atlanabilir, performans butcesi icinde |
| S2-03 | Mission System uctan uca test — 30s loop, stamina harcama, basari hesabi, cash/respect odulu, loot drop, cooldown | qa-tester | 1 | Tum core sistemler | 3 gorev tipi (Robbery/Trafficking/Extortion) calisir, basari orani %5-%95 clamp |
| S2-04 | Inventory & Equipment uctan uca test — kusanma/cikarma, stat bonus, power score guncelleme, 50 slot siniri, temp stash | qa-tester | 0.5 | S2-03 | Kusanma stat degistirir, envanter dolu iken temp stash calisir |
| S2-05 | Shop System uctan uca test — rank-gate, satin alma, satma, envanter dolu engeli | qa-tester | 0.5 | S2-04 | Rank yetersiz iken buy engellenir, sell %30 fiyat dogru |
| S2-06 | Character Progression test — respect -> rank up, stat point dagitimi, stat cap, stamina refill on rank-up | qa-tester | 0.5 | S2-03 | Multi rank-up calisir, stat cap rank'a gore artar |
| S2-07 | Unit testler — Mission, Inventory, Shop, Gang, Territory sistemleri icin GUT testleri | qa-lead | 2 | S2-03 thru S2-06 | Her sistem icin min 10 test, tum testler gecer |
| S2-08 | Bildirim sistemi — notification queue (max 5), 2s aralik, oncelik sirasi, dismiss | ui-programmer | 1 | S2-02 | Kuyruk tasmiyor, bildirimler sirayla gosteriliyor |
| S2-09 | Android APK build + cihaz testi — tum sistemler mobilde calisir | devops-engineer | 0.5 | S2-01 thru S2-08 | APK yuklenir, core loop oynanabilir, Cloud Save calisir |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S2-10 | Character Visuals — 10 avatar secimi, equipment overlay katmanlari, rank badge | ui-programmer, technical-artist | 1.5 | S2-04 | Avatar secim ekrani calisir, kusanilan esya gorusel olarak gosterilir |
| S2-11 | Mission JSON balance — 30+ gorev, zorluk dagilimi (40/30/20/10), odul dengesi, cooldown ayarlari | game-designer | 0.5 | S2-03 | missions.json 30+ gorev icerir, cash/respect progression akici |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S2-12 | Territory Map stub — 10 bolge gorsel harita, renk kodlama (altin/kirmizi/gri), tap detay popup | ui-programmer | 1 | — | Harita goruntulenir, bolge bilgisi popup'ta gosterilir |
| S2-13 | Economy balance simulasyonu — 1 saat oyun akisi simule et, inflation kontrolu, sink/source dengesi | economy-designer | 0.5 | S2-03, S2-05 | Enflasyon yok, 1 saat icinde belirgin ilerleme var ama tukenmez |
| S2-14 | Risk register olustur — tum sprint ve milestone riskleri belgelenmis | producer | 0.5 | — | production/risk-register/risks.md olusturulmus |

## Carryover from Previous Sprint

Yok — Sprint 1 tamamen tamamlandi. Tum 12 task bitti.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Cloud Save conflict resolution karmasikligi | ORTA | YUKSEK | Basit server-wins politikasi ile basla, edge case'leri Sprint 3'e birak |
| Mission balance bozuk — oyuncu cok hizli veya cok yavas ilerliyor | ORTA | ORTA | 30+ gorev JSON'u balance sheet ile, erken playtest |
| Animasyon performans butcesi asimi (mobil) | DUSUK | ORTA | Basit tween animasyonlari kullan, particle kullanma |
| GUT addon Godot 4.6 uyumsuzlugu | DUSUK | DUSUK | GUT v9.x kullan, alternatif: manuel test runner |
| Offline queue veri kaybi | DUSUK | YUKSEK | user:// dosyaya yedekle, uygulama kapanisinda flush |

## Dependencies on External Factors

- GUT addon kurulumu (AssetLib veya GitHub release)
- Firebase Firestore kurallari guncelleme (conflict resolution icin)
- Android test cihazi veya emulator (son test icin)

## Definition of Done for this Sprint

- [x] Cloud Save conflict resolution + offline queue calisir
- [x] Tum HUD animasyonlari (cash, respect, rank-up, loot) gosteriliyor
- [x] Mission System 30s core loop uctan uca oynanabilir
- [x] Inventory kusanma/cikarma dogru calisir, stat bonus uygulanir
- [x] Shop rank-gate + buy/sell dogru calisir
- [x] Mission, Inventory, Shop, Gang, Territory unit testleri geciyor
- [x] Bildirim kuyrugu calisir
- [ ] Android APK'da core loop test edildi
- [ ] Git'e commit edilmis, temiz calisan durumda

---

## Sprint 3 Onizleme

Sprint 3'te odak:
- Territory Map tam UI (zoom, pan, gorsel harita)
- Gang System multiplayer (Firebase Realtime DB)
- Map UI (renk kodlama, tap interaction)
- Building System gorsel + placement UI
- Integration testing (tum sistemler bir arada)
