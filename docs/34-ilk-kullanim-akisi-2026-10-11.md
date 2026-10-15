# İlk kullanım akışı — 11 Ekim 2026

## Kullanıcı sorunu ve plan

İlk açılışta prova, rehber seçimi ve çevrimdışı araçlar birlikte görünüyordu. Yeni bir Umre kullanıcısı önce tür, sonra kullanım biçimi, sonra adım listesi seçiyordu. İlk dilim, kullanıcıyı mevcut Umre öğrenme listesine tek dokunuşla götürür; Hac ve yolculuk seçeneklerini, kayıtları ve diğer özellikleri korur.

## Uygulanan dilim

- Ana başlık ve açıklama kısaltıldı. Taslak içerik uyarısı daha kısa ve görünür kaldı.
- Hiç rehber kaydı yoksa “Umreyi öğrenmeye başla” düğmesi, mevcut Umre öğrenme akışını doğrudan açar. Yükleme sürerken yeni kayıt varsayılmaz.
- Kayıt varsa “Kaldığım yerden devam” öne çıkar. Umre/Hac seçimi hemen altında; isteğe bağlı prova daha sonra görünür.
- İçerik onayı, ses hakkı, Hac profili veya ilerleme semantiği değiştirilmedi.

## Kabul ölçütü

Yeni kullanıcı ana ekrandan bir dokunuşla Umre öğrenme başlıklarına ulaşır; mevcut oturumu olan kullanıcı devam eder. Yükleme sırasında sahte “yeni kullanıcı” düğmesi görünmez. Eski Umre/Hac öğrenme ve yolculuk yolları ile prova açılışı çalışır. Küçük ekran ve büyük yazıda taşma olmaz.

## Doğrulama

Yeni başlangıç ve yükleme durumu widget kontrolleri geçti. Tüm Flutter testleri 211/211 başarılı; 320 ve 390 piksel genişlik ile normal/iki kat yazı ölçekli mevcut ekran matrisi de bu koşuya dahildir. `flutter analyze --no-pub` hata bulmadı; değişen Dart dosyaları biçimlendirildi ve `git diff --check` temiz. Bu turda fiziksel cihaz veya native ekran akışı çalıştırılmadı.
