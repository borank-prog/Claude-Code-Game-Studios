# CartelHood Flutter Port

Bu klasor Godot projesinin Flutter'a tasinmis surumudur.

## Calistirma

```bash
cd flutter_app
flutter pub get
flutter run -d chrome
# veya
flutter run -d windows
# veya
flutter run -d android
```

## Tasinan cekirdek sistemler

- Giris ekrani (Google / e-posta / misafir akisi - lokal mock)
- Ana 6 sekme: Profil, Sokak, Sehir, Market, Sosyal, Telsiz
- Profil ekrani + secilen karakter portresi + karakter kartlari
- Ekipman gridi (2x4) ve profil kart assetleri
- Gorev sistemi (Kolay/Orta/Zor), stamina, basari/basarisizlik
- Hapis/Hastane sureleri ve altinla hizli cikis
- Market satin alim (tek oge satin alim guvenli)
- Sehir/mekan satin alma ve pasif gelir toplama
- XP/Level/Rank ilerlemesi + guc hesabi
- Local save/load (SharedPreferences)
- Offline queue altyapisi + online oldugunda replay (idempotent)

## Not

Cloud save (Firebase Auth/Firestore), canli chat, alliance/gang backend ve tam server-authoritative PvP ikinci fazda baglanacak sekilde tasarlandi.
