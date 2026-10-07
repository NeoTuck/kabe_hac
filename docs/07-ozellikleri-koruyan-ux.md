# Özellikleri koruyan kullanım düzenlemesi

Kullanıcının talebi doğrultusunda özellik kaldırmadan ilk kullanım kolaylaştırılır. Ana ekranda Umreye hazırlanıyorum öğrenme kaydına, Umredeyim yolculuk kaydına doğrudan gider. Var olan kayıtlar yeniden kullanılır; iki kullanım biçimi birbirine aktarılmaz. Kaldığım yerden devam mevcut son oturumu açar. Tüm rehberler bölümünden eski Umre/Hac seçimleri ve Hac profilleri kullanılabilir.

Adım ekranının sırası: içerik durumu ve kısa açıklama, sesli anlatım, varsa manuel sayaç, Arapça/okunuş/anlam/kaynak/dua, ayrıntı, kişisel işaretleme ve önceki/sonraki. Taslak bölümde Şimdi ne yapacağım yerine İçerik hazırlanıyor gösterilir. Dinî metin, onay veya ses üretilmez.

Kafile, gezi/yer/rota, güvenli iletişim/dil, çevrimdışı paket, ayarlar ve teknik ses denemesi erişimleri korunur. Yapılandırma ve onay gerektiren özellikler önceki sınırlarını korur. SQLite şeması ve sabit içerik kimlikleri değişmez.

## Doğrulama

Mevcut UI matrisi 320×568 ve 390×844 ekranlarda %100/%200 yazı ile doğrudan girişleri de açıp kapatır; öğrenme ve yolculuk kayıtlarının ayrı oluştuğunu kontrol eder. Mevcut eski seçim, Hac profili, paket yenileme, ses, sayaç ve ilerleme testleri korunur. CI ekran renderlarını ui-preview artifact olarak verir. Yerel Dart biçimlendirmesi çalıştırıldı; Flutter analiz/test ve Android build CI üzerinden doğrulanacak. Yeni APK bu doğrulama bitmeden hazır sayılmaz. Fiziksel telefon kabulü ayrıdır.
