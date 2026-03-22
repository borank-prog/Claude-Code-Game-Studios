# Sprint 5 — 2026-05-19 to 2026-06-01

## Sprint Goal

MVP milestone'u kapat: entegrasyon testi, bug fix, tutorial, milestone raporu olustur
ve Android release build hazirla.

## Capacity

- Total days: 14 (2 hafta)
- Buffer (20%): 3 gun (unplanned work, bug fix)
- Available: 11 gun
- Developer: 1 (solo)

## Sprint 4 Velocity

Sprint 4'te 6 task tamamlandi.
Gang War UI, baskin sonuc animasyonu, balance tuning, mission/shop polish.
Tum 9 MVP kriteri kod tarafinda tamamlandi.
Sprint 5 polish/release odakli — yeni ozellik yok.

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S5-01 | Entegrasyon testi — uctan uca 9 MVP senaryosu elle test, her kriter icin PASS/FAIL, bug listesi olustur | qa-lead | 1 | — | 9 kriter test edilmis, bug listesi belgelenmis |
| S5-02 | Bug fix — entegrasyon testinden cikan S1/S2 bug'lari duzelt | gameplay-programmer | 2 | S5-01 | Tum S1 (critical) bug'lar duzeltilmis |
| S5-03 | Tutorial overlay — ilk 5 adim tooltip (gorev yap, esya al, stat dagit, cete kur, bolge ele gecir), atlanabilir, bir kez gosterilir | ux-designer | 1.5 | S5-02 | Yeni oyuncu ilk 5 dakikada ne yapacagini anlIyor |
| S5-04 | Milestone 1 gate check — 9 success criteria PASS/FAIL raporu, bilinen sorunlar, performans notu, release onerisi | producer | 0.5 | S5-02 | Gate check raporu olusturulmus, GO/NO-GO karari |
| S5-05 | Cloud Save tam test — kaydet/yukle dongusu: tum veriler (player, stamina, inventory, gang, territory, war), cihaz degistirme senaryosu | qa-tester | 0.5 | S5-02 | Veri kaybi yok, deserialize dogru |
| S5-06 | War Screen entegrasyonu — Gang ekranindan war screen'e gecis butonu, map'ten baskin sonrasi war screen'e yonlendirme | ui-programmer | 0.5 | — | Navigasyon akici, kullanici baskin durumunu kolayca gorebiliyor |
| S5-07 | Android release build — signed APK, export presets guncelle, minimum SDK, hedef SDK, ikon/splash | devops-engineer | 1 | S5-04 | APK olusur, cihazda core loop oynanabilir, crash yok |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S5-08 | Performans optimizasyonu — _process maliyeti azalt, harita lazy update, gereksiz queue_free/new dongulerini temizle | performance-analyst | 1 | S5-01 | 60fps hedef karsilanir veya kabul edilebilir seviyede |
| S5-09 | Offline mode polish — baglanti yok iken kullanici bilgilendirme, yerel yedek gosterme, reconnect sonrasi sync | network-programmer | 1 | S5-05 | Offline bildirim gosterilir, reconnect'te veri kaybi yok |
| S5-10 | Milestone 1 success criteria guncelleme — milestone dosyasinda tum kriterleri check et | producer | 0.5 | S5-04 | milestone-1-mvp.md guncellenmis |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S5-11 | Ses efektleri placeholder — 5 temel ses (buton, cash, rank up, baskin, sonuc) | sound-designer | 0.5 | — | Ses dosyalari eklenmis |
| S5-12 | Splash screen — CartelHood logosu, 2s gosterim, fade out | ui-programmer | 0.5 | — | Uygulama acilisinda logo gosterilir |

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|---|---|---|
| S4-07: Performans profili | S5-08 ile birlesiyor | 1 gun |
| S4-08: Entegrasyon testi | S5-01 ile birlesiyor (genisletilmis) | 1 gun |

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Entegrasyon testinde kritik bug cikmasi | ORTA | YUKSEK | 2 gun bug fix buffer ayrildi |
| Android spesifik crash | DUSUK | YUKSEK | Erken APK build, emulator + fiziksel test |
| Tutorial akisi kullanici deneyimini bozuyor | DUSUK | ORTA | Basit tooltip, zorlamayan, atlanabilir |
| Milestone gate check FAIL | DUSUK | YUKSEK | Tum kriterler Sprint 1-4'te kodlandi, sadece dogrulama |

## Dependencies on External Factors

- Android test cihazi (release build icin sart)
- Google Play Developer hesabi (ileride, bu sprintte degil)
- Placeholder ses dosyalari

## Definition of Done for this Sprint

- [x] 9 MVP kriteri entegrasyon testi PASS
- [x] S1/S2 bug'lar duzeltilmis
- [x] Tutorial ilk 5 adimi gosteriliyor
- [x] Milestone gate check raporu olusturulmus
- [x] Cloud Save tam dongu test edilmis
- [x] War Screen navigasyon entegrasyonu calisir
- [ ] Android signed APK olusturulmus ve test edilmis
- [ ] Git'e commit edilmis, temiz calisan durumda

---

## Post-MVP

Milestone 1 PASS ise:
- Alpha test grubu olustur (5-10 kisi)
- Sprint 6+: Tier 2 sistemler (Chat, Alliance, Leaderboard)
- Monetizasyon (Cosmetic IAP, Battle Pass)
- App Store / Google Play submission hazirligi
