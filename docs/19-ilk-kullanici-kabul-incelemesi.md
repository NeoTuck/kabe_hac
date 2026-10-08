# İlk kullanıcı kabul incelemesi — 9 Ekim 2026

Başlangıç `04e7ebdd2ab2ec4d422798216844faa9caef2b34`, hedef `codex/mvp1-pilot`. Bu çalışma Linux inceleme ortamındadır; kullanıcının Mac'i veya fiziksel telefonu değildir. Yerel Flutter/Android SDK/Xcode yoktur; Flutter ve native derleme/çalıştırma GitHub CI üzerinden doğrulanır.

## İncelenen gerçek hatalar

- Önceki iOS run `37849860678` build'leri başarılı; JUnit dört akıştan ilk rehber geçişini başarısız kaydetti. Hata görüntüsü boş ekran, sonraki üç akış başarılı. Bunun kök nedeni yalnız görüntüden kesinleştirilemez; driver ön hazırlığı ve iOS uygulama konsol kaydı eklenmiştir. Assertion kaldırılmadı, başarısız UI akışını otomatik tekrarlama eklenmedi.
- `04e7ebd` run `37852105593` Flutter işi ffmpeg bağımlılık indirmesinde 180 saniye sınırına ulaştı; testler başlamadı. İndirme için `--no-install-recommends` ve 600 saniyelik sınırlı süre kullanılır; uygulama testi atlanmaz.
- Uygulama ilk kareden önce platform sesini ve çevrimiçi servisleri bekliyordu. İlk yerel yükleme ekranı artık hemen çizilir; Supabase/Firebase hazırlığı kullanılabilir çevrimdışı rehberden sonra başlar. Platform medya entegrasyonu ilk ses isteğine taşındı. Gömülü katalog ikinci kez okunmaz; bağımsız yerel okumalar birlikte başlatılır.
- Bildirim izni sürerken kapatma isteği sonradan açılan token'ı iptal etmeyebiliyordu. Aç/kapat/devam işlemleri sıraya alındı; dispose sonrası bildirim yayınlanmaz. Konum gönderimi sürerken iptalin başarı gibi sunulması engellendi.

## Kullanıcı paketi ve ses testi ayrımı

Üretim giriş noktası teknik örnek ekranı veya ses dosyası içermez. APK içeriği `verify_production_assets.py` ile denetlenir. Onaysız dinî içerik ve test gezi verisi kullanıcıya açılmaz.

Gerçek cihaz ses eklentisini test etmek için yalnız ayrı debug QA giriş noktası `tools/audio_probe.dart` vardır. `KABE_AUDIO_QA=true` ister, release modda çalışmayı reddeder. Build aracı teknik AAC dosyasını yalnız geçici QA manifestine ekler ve üretim manifest/artifact'ını `finally` ile geri getirir. Probe kullanıcının rehber veya prova verisine yazmaz. Teknik probe: oynatım, süre/konum ilerlemesi, duraklatma, devam, seek, completion, replay ve stop kontrol eder. Bu işitsel kalite, insan sesi, Bluetooth veya çağrı kabulü değildir. QA APK dağıtılacak kullanıcı APK'sı değildir.

Ana native matrisine isteğe bağlı prova başlatma, duraklatma ve yeniden açıp devam akışı eklendi. Android 28/35 ile iOS simülatöründe aynı assertion'lar çalıştırılır.

## Yerel doğrulama (ilk dilim)

23 Python kontrolü, beş rehber/prova YAML yapılandırması, Python sözdizimi, Dart format ve AAC dosya QA geçti. Flutter format/analyze/test ve platform native sonuçları yeni CI tamamlanınca güncellenecektir. Yerel yapılandırma kontrolü cihaz testi değildir.

`release_preflight.py` yeniden çalıştırıldı: blocked, 155 eksik girdi/kanıt. Bu sayı kod hatası sayısı değildir. 53 dinî adım ve dua kayıtları taslak, gerçek ses/hak/uzman ve saha/servis girdileri yoktur. Alanlar doldurulmuş görünse bile AI insan uzman incelemesi veya fiziksel cihaz kabulü üretemez.

## Son kullanıcı kararı

Henüz tam ibadet rehberi olarak yayınlanamaz. Kod hatalarının kapanması ve emülatör testlerinin geçmesi gerekli fakat yeterli değildir. Gerçek uzman onayı, içerikle eşleşen izinli ses, lisanslı paket/harita/saha verisi, canlı Supabase/FCM/APNs teslimi, fiziksel Android/iPhone kabulü ve üretim imzaları bekler. Mevcut testler bu girdilerin yerine geçmez. Ölçülmüş gerçek cihaz açılış/akıcılık/pil kabulü olmadığı için "kasmaz" veya "her şey hazır" iddiası verilmez.
