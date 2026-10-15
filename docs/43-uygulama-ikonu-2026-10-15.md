# Kullanıcı logosunun uygulama ikonuna bağlanması — 15 Ekim 2026

- Kullanıcının gönderdiği 832×835 JPEG, `assets/branding/app_icon_source.jpg` yolunda kaynak olarak saklanır. Görseldeki Kâbe, ışık halkası ve zemin aynen kullanılır; kare ikon için yalnız yatay/dikey ölçekleme yapılır.
- `python3 tools/build_app_icons.py` kaynak görselden Android `mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` ve iOS `AppIcon.appiconset` PNG'lerini yeniden üretir. Android manifesti ve iOS asset catalog zaten bu dosyaları kullanır.
- `tools/build_asset_license_inventory.py` kaynak görseli ve üretilen ikonları kullanıcıdan gelen varlık olarak listeler. Görselin üreticisi veya mağaza dağıtım hakkı kanıtı henüz verilmediği için envanterde hak incelemesi açık görünür. Teknik entegrasyon yayın izni anlamına gelmez.
- Bu dilimde uygulama içeriği, ses, ağ, servis ve CI/native yayın akışı değiştirilmedi.

## Yerel doğrulama

- Kaynak JPEG 832×835; 5 Android ve 19 iOS PNG dosyasının beklenen kare piksel ölçüleri ile RGB biçimi doğrulandı.
- `tools/build_asset_license_inventory.py --check` ve `git diff --check` geçti.
- Bu çalışma ortamında `flutter` komutu kurulu olmadığından Flutter analiz/test veya mobil derleme çalıştırılmadı. Yeni simülatör/fiziksel cihaz kabulü yapılmadı.
