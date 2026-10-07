# Özellikleri koruyan kullanım düzenlemesi

Kullanıcının talebi doğrultusunda özellik kaldırmadan ilk kullanım kolaylaştırılır. Ana ekranda Umreye hazırlanıyorum öğrenme kaydına, Umredeyim yolculuk kaydına doğrudan gider. Var olan kayıtlar yeniden kullanılır; iki kullanım biçimi birbirine aktarılmaz. Kaldığım yerden devam mevcut son oturumu açar. Tüm rehberler bölümünden eski Umre/Hac seçimleri ve Hac profilleri kullanılabilir.

Adım ekranının sırası: içerik durumu ve kısa açıklama, sesli anlatım, varsa manuel sayaç, Arapça/okunuş/anlam/kaynak/dua, ayrıntı, kişisel işaretleme ve önceki/sonraki. Taslak bölümde Şimdi ne yapacağım yerine İçerik hazırlanıyor gösterilir. Dinî metin, onay veya ses üretilmez.

Kafile, gezi/yer/rota, güvenli iletişim/dil, çevrimdışı paket, ayarlar ve teknik ses denemesi erişimleri korunur. Yapılandırma ve onay gerektiren özellikler önceki sınırlarını korur. SQLite şeması ve sabit içerik kimlikleri değişmez.

## Doğrulama

Mevcut UI matrisi 320×568 ve 390×844 ekranlarda %100/%200 yazı ile doğrudan girişleri de açıp kapatır; öğrenme ve yolculuk kayıtlarının ayrı oluştuğunu kontrol eder. Mevcut eski seçim, Hac profili, paket yenileme, ses, sayaç ve ilerleme testleri korunur. CI ekran renderlarını ui-preview artifact olarak verir. Yerel Dart biçimlendirmesi çalıştırıldı. `8e871203f517aba56946d98c0c761e79999eed69` commit için https://github.com/NeoTuck/kabe_hac/actions/runs/37590553180 başarılı: analiz/format, 87 Flutter testi, ses dosyası QA, database, Android debug APK ve iOS debug/no-codesign. Ana ekranın yeni gerçek Flutter görüntüsü incelendi ve docs/mvp-ui/home.png içine kaydedildi. Fiziksel telefon kabulü ayrıdır.

## APK teslimi

APK 210197775 bayt; SHA-256 `75e8e7c9afc6f966ba2651833ae2e0f0acede6b65a5e73e5dce55f284ee19ca4`. İndirilen ZIP özeti GitHub artifact özetiyle eşleşti; ZIP/APK CRC ve manifest/DEX/Flutter assets kontrolü geçti. Bu debug teknik pilot paketidir.

Bu CI çalışmasının debug imza sertifikası önceki APK ile farklıdır (önceki: af8989aa7d2949a685861e540d425a1da609aa4aba2b4409a05a80a59ef04737; yeni: c72ba0e62cba2839b1513badb9bfda92121b715f72856bf9439bbfa856bb21df). Önceki APK'nın üstüne normal güncelleme kabul edilmeyebilir. İlerleme kaydı bulunan kullanıcıya uygulamayı kaldırma/veri temizleme önerilmez; veri aktarımı ve kalıcı güvenli imzalama ayrı ele alınmalıdır. Mobil kurulum veya fiziksel ses testi yapılmış sayılmaz.
