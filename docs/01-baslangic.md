# Sesli rehber — ilk dilim

Kaynak: `Hac_Umre_Sesli_Rehber_Plani.md` (5 Ekim 2026). Bu dosya uygulama planıdır; dinî içerik onayı veya yayın izni yerine geçmez.

## İnceleme sonucu

- Ürün iki ayrı kullanım sunuyor: öğrenme ve yolculukta rehber. İlerleme kayıtları da ayrı olmalı.
- Umre için 18, hac için 35 alt adım envanteri hedeflenmiş. Asıl 2.3 plan dosyası bu çalışma alanında bulunamadığından sabit kimlikler henüz doğrulanmadı.
- Metin, dua ve sesin aynı içerik sürümüne bağlanması kritik. Onaysız metin ve ses kullanıcıya ibadet talimatı olarak sunulmamalı.
- Sayaçlar manuel; sayaç veya ses olayı adımı otomatik tamamlamamalı.
- Çevrimdışı metin temel uygulamada, ses ise doğrulanan indirilebilir paketlerde olacak.

## Sıralama

1. Flutter projesi ve tek teknik demo kartı: büyük yazı, Türkçe/Arapça yönü, yerel demo ses, son kart kaydı.
2. İçerik şeması ve sabit kimlikler; uzman onayı alanları; örnek SQLite migrasyonu.
3. Umre öğrenme akışı, ardından manuel tavaf/sa‘y sayacı.
4. Ses yöneticisi ve çevrimdışı paket doğrulaması.
5. Hac tür/gün/güzergâh matrisi yalnız onaylı kurallarla.

## İlk dilimin kabulü

- Uygulama statik teknik demo kartını açar; kart onaylı dinî içerik gibi görünmez.
- Arapça örnek sağdan sola, Türkçe metin soldan sağa gösterilir.
- Yerel örnek ses oynar ve durur; ses bitişi ilerlemeyi değiştirmez.
- Son görüntülenen kart yerelde saklanır ve yeniden açıldığında okunur.
- `flutter analyze` ve `flutter test` geçer. Gerçek telefon derlemeleri, araçlar ve cihazlar hazır olduğunda ayrıca doğrulanır.

## Dış girdiler

- Ana plan 2.3 ve mevcut U/H içerik kimlikleri.
- İlk kartın kaynaklı ve uzman onaylı metni, Arapça incelemesi ve ses kayıt hakkı.
- Gerçek Android/iPhone, Android SDK ve Xcode/imza erişimi.

