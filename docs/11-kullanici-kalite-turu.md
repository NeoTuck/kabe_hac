# Kullanıcı odaklı kalite turu

8 Ekim 2026. Mevcut özellikler, veri kayıtları ve görsel yön korunur; 3D eklenmez.

## İlk geliştirme dilimi

- Kafilede sabit “Mesaj yaz” girişi ve klavye üstünde kaydırılabilen editör. Taslak kapatınca korunur, hesap değişince temizlenir. Çift gönderim engellenir; yerel kaydın başarıyla alınması teslim edildi iddiası değildir.
- Paket indirme/silme/geri dönüş aynı ekranda tek işlem olarak yürür. Okuma hatasında sonsuz yükleme yerine tekrar deneme vardır. Türkçe paket türleri ve büyük yazıya uygun kartlar kullanılır.
- Gezi favorilerinde aynı noktaya eşzamanlı yazma engellenir. Başarılı yazmadan sonra SQLite listesi tekrar okunmadan yerel durum güncellenir. Favori filtresi ve aramayı temizleme vardır.
- Rehberin başlık açma, sonraki/önceki geçiş ve yeni yolculuk işlemleri hızlı çift dokunuşlardan korunur. Ses durdurma hatası ekranı kapatmaz.
- Ayar yazmaları dokunuş sırasıyla yürür. Ses hızı tercihi kaydedilemezse önceki oynatma hızı geri yüklenir; kuyruk bir hatadan sonra sonraki ayarı kabul eder.

## Doğrulama

Format ve diff kontrolü temiz. Yeni kod için analiz, tüm Flutter testleri, ses QA ve Android/iOS derlemeleri GitHub CI doğrulamasını bekliyor. Önceki kanıt 102 Flutter/39 SQL testidir; yeni kod için geçti kabul edilmez.

Gerçek dinî içerik/ses hakları, harita/saha verisi, Supabase/Auth/Realtime/RLS, GPS/push ve fiziksel cihaz kabulü hâlâ dış girdiler ister. Bu tur bunları uydurmaz veya üretime hazır ilan etmez.
