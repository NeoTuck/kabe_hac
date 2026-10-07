# Kafile mesaj geçmişi

7 Ekim 2026. Mevcut rehber, ses, sayaç, gezi ve kafile akışları korunur.

## Kullanıcı davranışı

İlk açılış son 100 mesajı gösterir. “Eski mesajları yükle” düğmesi 50 mesaj daha getirir. Yükleme sırasında düğme kilitlenir; bağlantı hatasında mevcut mesajlar kalır ve tekrar deneme açıklaması çıkar. Mesaj zamanı cihazın yerel saatinde okunabilir biçimde gösterilir.

Bu ekran en fazla 500 mesaj gösterir. Bu sınır kalıcı geçmişin silinmesi değildir; daha eski mesajlara burada erişim sınırıdır. Sayfalar bellekte tutulur, SQLite'a sohbet arşivi eklenmez. Sunucu erişimi olmadan eski mesajlar indirilemez.

## Doğruluk ve erişim

- Cursor UTC zaman ve UUID kimliğidir. Aynı zamanlı mesajlar kimlikle kararlı sıralanır. Sorgu 51 kayıt okuyup 50 kayıt döndürür; sonraki sayfa olup olmadığı doğru belirlenir.
- Hesap ve üyelik sorgudan önce/sonra doğrulanır. RLS değişmez. Üyelik kaybında görünür sohbet temizlenir.
- Tekrarlanan kimlikler ayıklanır. Hesap değişimi, ekran kapanması veya yenileme eski isteğin ekrana yazmasını engeller.
- Yenileme daha önce açılmış sayfaları yeniden okur; düzenlenen/silinen mesajlar eski halleriyle kalmaz. En fazla sekiz geçmiş sayfası tekrar okunur; canlı servis yükü saha ölçümü ister.
- `messages_group_created_id_idx` yalnız indeks ekler; veri silmez veya politika gevşetmez.

## Kontrol ve sınırlar

SDK HTTP testleri cursor, 51 kayıt, boş son sayfa, üyelik kaybı ve hesap kontrolünü kapsar. Widget testleri tekrarlar, yenileme/silme, ağ hatası, üyelik iptali, hesap değişimi, yarış koşulları, 320 piksel/%200 yazı ve 500 mesaj sınırını kapsar. SQL fixture testleri aynı zamanlı sayfa sınırını ve grup/üyelik yalıtımını kontrol eder.

Bu değişikliğin format kontrolü geçti; analiz, tüm testler ve Android/iOS derlemeleri GitHub CI doğrulamasını bekliyor. UI ekran görüntüsü test verisiyle üretilir; gerçek kullanıcı, cihaz veya Supabase kabulü değildir. Fiziksel cihaz, canlı Auth/RLS/Realtime ve push kabulü açık kalır.
