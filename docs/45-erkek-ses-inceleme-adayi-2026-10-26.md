# Erkek ses inceleme adayı — 26 Ekim 2026

Kullanıcının `Hac_Umre_Erkek_Sesler_54/` klasöründeki Supertonic 3 M1 sentetik erkek kayıtları, önceki kadın ses kayıtlarının yerine **gelecek onaylı paket için aday** olarak bağlandı. Kadın kayıtlarının eski inceleme kaynağı korunur. Yeni kayıtlar `assets/audio/review-male-v1/` altında, kaynak makbuzları ve lisans/kalite belgeleri `docs/audio-review/male-v1/` altında tutulur.

## Yapılan bağlama

- 53 adım anlatımı ve telbiyenin Türkçe anlamı için 54 M4A dosyasının kimlik, metin sürümü, tam metin SHA-256 ve dosya SHA-256 eşleşmesi kaynak kataloglarla doğrulandı.
- Umre ve Hac taslak kataloglarındaki Türkçe ses bağlantıları erkek kayıtlarının dosya özetlerine döndü. Arapça telbiye kaydı hâlâ yoktur.
- Erkek kayıtlarının katalog alanı `voiceStyle: M1` olarak işlendi. Gelecekte onaylı paketle çalınırsa rehber ve prova ekranında “Yapay zekâ ile üretilmiş erkek anlatımı.” açıklaması görünür.
- `tools/prepare_male_review_audio.py --check` dosya/makbuz/katalog bağını tekrar denetler. Varlık lisans envanteri erkek ses kökenini ayrı kaydeder. Kullanıcı APK denetimi yeni inceleme klasörünü reddeder.
- Kısa GitHub QA işine erkek kayıt ve lisans envanteri kontrolü eklendi; APK/native/cihaz işi eklenmedi.
- Normal `pubspec.yaml` erkek veya eski kadın taslak sesleri ve taslak rehber kataloglarını paketlemez. Uygulamada onaylı katalog bulunmadıkça rehber boş görünmeye devam eder.

## Onay ve yayın sınırı

Kaynak klasörün kalite raporuna göre 54/54 insan dinleme kararı bekliyor; otomatik ASR, 22 kaydı ayrıca dikkat için işaretliyor. Metin katalogları `draft` durumundadır. Modelin [Open RAIL-M lisansı](https://huggingface.co/Supertone/supertonic-3/blob/3cadd1ee6394adea1bd021217a0e650ede09a323/LICENSE) sentetik üretim açıklamasını gerektirir. Bu teknik bağlama dinî/dil incelemesi, kayıt dinleme kararı, dağıtım hakkı veya cihaz kabulü üretmez. Kayıtlar `approved` yapılmadı ve kullanıcı APK'sinde etkinleştirilmedi.

Sıradaki bağımlı iş: ilgili metin sürümlerinin gerçek uzman/kaynak hakkı kararlarını ve erkek seslerin insan dinleme/dağıtım kararlarını kimlik ve dosya özetine bağlı olarak al. Öncelikle ilk Umre dilimini onaylı, güvenilir çevrimdışı pakete koy; görünür “Yapay zekâ ile üretilmiş erkek anlatımı” açıklamasını koru. Son paket için Android/iOS cihaz ve APK varlık denetimini yinele.

## Yerel doğrulama

- `python3 tools/prepare_male_review_audio.py --check`: 54/54 eşleşti.
- FFmpeg ile yeni M4A dosyalarının 54/54'ü sonuna kadar hatasız çözüldü.
- Bağımsız Dart katalog ayrıştırması 19 Umre ve 35 Hac Türkçe kaydını `M1` taslak olarak yükledi; görünür sentetik ses açıklaması alanını doğruladı.
- `python3 -m unittest discover -s tools -p 'test_*.py' -q`: 87 test geçti.
- `python3 tools/build_asset_license_inventory.py --check`: 142 varlık, 150 kilitli Dart paketi, 0 eksik yerel lisans dosyası.
- Değişen dört Dart dosyası `dart format` ile biçimlendirildi. Makinedeki bağımsız Dart 3.12.2 ile tüm depo format kontrolü, bu değişiklik dışındaki 27 mevcut dosyada farklı çıktı önerdi; dosyalar değiştirilmedi. Projenin CI Flutter sürümü 3.47.6'dır.
- Flutter 3.47.6 SDK'sı `/Users/mustafasenoglu/.local/share/flutter-3.47.6/bin/` altında bulundu; `flutter analyze --no-pub` sıfır sorunla geçti. İlk tam test koşusunda geçici bir hata görüldü; ilgili paket yenileme dosyası tek başına 9/9, ikinci tam koşu 255/255 geçti.
- Android için `KABE_TECHNICAL_PILOT=true` ile optimize release APK üretildi. Gradle'ın release dışı bıraktığı `integration_test` eklentisini eski, Git tarafından izlenmeyen `GeneratedPluginRegistrant.java` dosyası çağırdığı için ilk derleme durdu; bu üretilmiş dosyadaki çağrı yerel olarak çıkarılıp derleme tekrarlandı. Üretim kaynak kodu değiştirilmedi.
- Masaüstündeki `Kabe_Hac_2026-10-26_Teknik_Deneme.apk` 95.545.616 bayt; SHA-256 `3a854f1bace704ff6876a9ec669eecd6856e07dc7408e0bb1cef62a90ea3feaa`. Android debug sertifikasıyla imzalı teknik denemedir; APK imzası doğrulandı. `verify_production_assets.py` geçti; arşivde taslak rehber JSON'u ve eski/yeni inceleme sesleri yok. Fiziksel cihaz kabulü yapılmadı.
