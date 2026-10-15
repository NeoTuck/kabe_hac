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

`2e5f38b38a75e6c29c91fa8578082aade37a1676` için CI 37683617681: format, analiz, 102 Flutter testi, teknik ses QA, iOS debug/no-codesign, QA temeli ve 39 SQL kontrolü geçti. Android debug APK da başarıyla oluşturuldu. Kanıt: https://github.com/NeoTuck/kabe_hac/actions/runs/37683617681 . İmzalı iOS dağıtımı veya telefon kabulü değildir.

`docs/mvp-ui/group-history.png` CI'da 390×844 test verisiyle üretilen gerçek Flutter renderıdır ve görsel olarak incelendi. 320×568/%200 yazıda da widget akışı geçti. Ekran görüntüsü gerçek kullanıcı, cihaz veya Supabase kabulü değildir. Fiziksel cihaz, canlı Auth/RLS/Realtime ve push kabulü açık kalır.

Yerel Flutter bağımlılık hazırlığı gerekli olmayan metadata adresine erişim denemesi nedeniyle otomatik kontrolde engellendi. İşlem tekrar edilmedi; doğrulama GitHub CI üzerinden yürütüldü.
