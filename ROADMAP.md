# CartelHood Roadmap

Last update: 2026-04-01

## 1) Stabilizasyon Sprinti
- [x] Flutter analyze temiz
- [x] Flutter test temiz
- [x] Functions lint temiz
- [x] Tek komut smoke script mevcut: `scripts/smoke.ps1`
- [x] Bot saldırı yoğunluğu düşürüldü (aynı gerçek oyuncuya 4 saat cooldown)
- [x] Web build + hosting deploy tamamlandı (`https://boran41.web.app`)
- [ ] Android emulator manuel smoke (giriş, görev, PvP, çete) tekrar turu
- [ ] Web smoke (kritik akışlar) tekrar turu

Exit kriteri:
- Kritik hata olmadan açılış + temel akışlar çalışır.

## 2) Auth ve Veri Güvenliği
- [x] Inbox rules izinleri düzeltildi (`users/{uid}/inbox`)
- [x] Logout akışı UI bloklamayacak şekilde düzenlendi
- [ ] Auth smoke matrisi (register/login/logout/offline) tam tur
- [ ] Replay/idempotency turu (özellikle saldırı ve çete çağrıları)

Exit kriteri:
- Auth akışlarında takılma yok, veri kaybı/çift işleme yok.

## 3) Ekonomi ve Oynanış Dengeleme
- [x] Hastane/Hapis süresi 45 dk akışı aktif
- [x] Bot hedefleme sıklığı azaltıldı
- [ ] Görev ödül/maliyet/drop tablosu netleştirme
- [ ] Kaçakçı sandığı fiyat + drop tavanı tekrar dengeleme
- [ ] İlk canlı metrik turu (nakit/altın/xp artış eğrisi)

Exit kriteri:
- Erken oyun ne çok kolay ne kırıcı.

## 4) Retention ve UX Polish
- [x] Savaş raporları mesaj kutusunda detaylandırıldı (yükout + etki yüzdeleri)
- [ ] Mission result ve popup görsel tutarlılık turu
- [ ] TR/EN metin tutarlılık turu
- [ ] Rehber ekranı (oyun döngüsü + çapraz tablo) son polish

Exit kriteri:
- Yeni oyuncu ilk 20 dakikada akıştan kopmuyor.

## 5) Sosyal Özellikler ve Yayın Öncesi
- [x] Genel sohbet + bot kişilik profilleri aktif
- [ ] Çete kur/katıl akışı hata turu (yeniden doğrulama)
- [ ] Arkadaş profili + saldırı butonu tüm listelerde doğrulama
- [ ] Release checklist (analytics/log/regression) kapatma

Exit kriteri:
- Kapalı test için güvenli build hazır.

## Çalıştırma
- Hızlı smoke: `powershell -ExecutionPolicy Bypass -File .\scripts\smoke.ps1 -WithTests`
