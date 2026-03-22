# Sprint 4 — 2026-05-05 to 2026-05-18

## Sprint Goal

Gang War UI'i tamamla, tum ekranlari parlat, performans profili olustur
ve MVP milestone'unun tum success criteria'larini dogrulanabilir hale getir.

## Capacity

- Total days: 14 (2 hafta)
- Buffer (20%): 3 gun (unplanned work, bug fix)
- Available: 11 gun
- Developer: 1 (solo)

## Sprint 3 Velocity

Sprint 3'te 8 task tamamlandi (7 Must + 1 Should).
Gorsel harita, building UI, gang sync, davet sistemi, 36 unit test, cloud save genisletme.
Velocity: yuksek — solo dev milestone'a uygun ilerliyor.

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S4-01 | Gang War hazirlik ekrani — aktif baskinlar listesi, hazirlama timer (4 saat), katilim butonu, saldiri/savunma gucu gostergesi, kilitlenme uyarisi (son 1 saat) | ui-programmer | 2 | — | Aktif baskinlar gorulur, timer dogru sayar, katilim calisir |
| S4-02 | Gang War sonuc animasyonu — zafer/yenilgi/berabere ekrani, loot gostergesi, respect kazanimi, bolge degisimi animasyonu, history listesi | ui-programmer | 1.5 | S4-01 | Sonuc ekrani acilir, oduller gosterilir, harita guncellenir |
| S4-03 | Gang War balance tuning — guc hesabi dogrulama, RNG varyans ayari, tier bazli NPC savunma, morale carpani, odul dengesi tablosu | game-designer | 1 | — | Tier 1 bolge solo oyuncuyla alinabilir, Tier 3 cete gerektirir |
| S4-04 | UI polish — tum 5 tab ekraninda tutarli tema, font boyutlari, padding, buton stilleri, separator'lar, scrollbar styling | ui-programmer | 1.5 | — | Tum ekranlar neon dark temaya uygun, tutarli gorunum |
| S4-05 | Mission ekrani polish — gorev karti tasarimi (rarity border, zorluk rozeti, odul onizleme), ilerleme bar, cooldown timer gostergesi | ui-programmer | 1 | S4-04 | Gorev kartlari bilgilendirici, zorluk renk kodlu |
| S4-06 | Shop ekrani polish — kategori tab'lari (silah/zirh/kiyafet), esya karti (ikon placeholder, stat bonus gosterimi, rank-gate badge) | ui-programmer | 1 | S4-04 | Kategoriler arasi gecis calisir, rank-gate gorusel |
| S4-07 | Performans profili — 60fps hedef kontrol, draw call sayimi, bellek kullanimi, autoload _process maliyeti, harita zoom/pan akiciligi | performance-analyst | 1 | S4-04 | Profil raporu olusturulmus, 60fps hedef karsilanir veya darbogazlar belgelenmis |
| S4-08 | Entegrasyon testi — uctan uca MVP senaryosu: hesap -> gorev -> rank up -> shop -> cete -> bolge -> bina -> baskin -> kaydet -> yukle | qa-lead | 1 | S4-01 thru S4-07 | Tum 9 milestone criteria test edilmis, sonuclar belgelenmis |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S4-09 | Milestone 1 success criteria gecis raporu — her kriter icin PASS/FAIL, ekran goruntuleri, bilinen sorunlar listesi | producer | 0.5 | S4-08 | Rapor olusturulmus, tum kriterler degerlendirilmis |
| S4-10 | Android APK build + test — Sprint 3-4 ozellikleri dahil, tam core loop mobilde | devops-engineer | 0.5 | S4-08 | APK yuklenir, core loop oynanabilir, harita akici |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|---|---|---|---|---|---|
| S4-11 | Economy balance raporu — 1 saat oyun akisi simule, inflation kontrol, sink/source dengesi, ilerleme hizi | economy-designer | 0.5 | S4-03 | Rapor olusturulmus, dengesizlik varsa onerileri yazilmis |
| S4-12 | Ses efektleri placeholder — buton tik, cash kazanim, rank up, baskin ilan, baskin sonuc (5 temel ses) | sound-designer | 0.5 | S4-04 | Ses dosyalari eklenmis, EventBus ile tetikleniyor |
| S4-13 | Tutorial stub — ilk 3 adim icin tooltip overlay (gorev yap, esya al, cete kur) | ux-designer | 0.5 | S4-08 | Ilk giris tooltip'leri gosteriliyor, atlanabilir |

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|---|---|---|
| S3-09: Entegrasyon testi | S4-08 ile birlesiyor (genisletilmis) | — |
| S3-12: Android APK test | S4-10 ile birlesiyor | 0.5 gun |

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Gang War balance bozuk — cok kolay veya cok zor | ORTA | YUKSEK | NPC savunma gucu tier bazli, solo playtestable, hizli JSON ayar |
| UI polish suresi tasiyor — 5 ekran cok fazla | ORTA | ORTA | En onemli 3 ekrani once parlat (Mission, Map, Home), digerleri Sprint 5'e |
| Performans profili kritik darbogazlar buluyor | DUSUK | ORTA | Basit cozumler once, karmasik optimizasyonlar Sprint 5'e |
| Android APK spesifik bug'lar | DUSUK | ORTA | Erken test, emulator + fiziksel cihaz |

## Dependencies on External Factors

- Android test cihazi/emulator (performance profiling icin sart)
- Placeholder ses dosyalari (yoksa sessiz kalir, blocker degil)

## Definition of Done for this Sprint

- [x] Gang War hazirlik ekrani + katilim calisir
- [x] Gang War sonuc animasyonu gosteriliyor
- [x] Gang War balance solo playtest'te dengeli
- [x] Tum 5 tab ekrani tutarli tema ile parlatilmis
- [x] Mission + Shop ekranlari bilgilendirici kart tasarimlarina sahip
- [ ] Performans profili olusturulmus (60fps hedef)
- [ ] Uctan uca MVP entegrasyon testi geciyor
- [ ] Git'e commit edilmis, temiz calisan durumda

---

## Sprint 5 Onizleme (Son Sprint)

Sprint 5'te odak:
- Bug fix (entegrasyon testinden cikan sorunlar)
- Final UI polish (kalan ekranlar, animasyon tutarliligi)
- Tutorial (ilk 5 dakika oyuncu deneyimi)
- Android release build (signed APK, ProGuard, minify)
- Milestone 1 gate check — PASS/FAIL karari
- Eger PASS: Alpha release hazirligi
