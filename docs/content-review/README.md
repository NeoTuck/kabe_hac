# Umre/Hac editöryal çalışma tabloları

CSV dosyaları mevcut sabit kimliklerden üretilen UTF-8 (BOM) çalışma tablolarıdır. Umre 18, Hac 35 satırdır. Dinî açıklama yazılmamış; onay verilmemiştir. Uygulama bu dosyaları yüklemez.

Her satırda mevcut kimlik, sıra, grup, başlık ve taslak durum korunur. Metin, kaynak/konum, kullanım hakkı ve gerçek inceleyen/tarih alanları uzmanla doldurulur. Dua, ses kayıtları ve Hac profil matrisi ayrı şema girdileridir; tek bir CSV satırı onların kabulünü sağlamaz. Onaylı yayın kataloğuna aktarım, mevcut Dart içerik doğrulayıcısı ve testler üzerinden ayrı yapılmalıdır.

`tools/content_audit.py` kaynak envanterlerin tip/sayı/benzersiz ID/sıralamasını denetler. `--export` tabloları üretir, mevcut çalışma tablolarını ezmez; uzman düzenlemelerini korur. Yeniden dışa aktarmadan önce mevcut değişiklikleri inceleyip ayrı dosyada koruyun. Kaynak envanterdeki `status=approved` sayısı tek başına uzman onayı kanıtı değildir.
