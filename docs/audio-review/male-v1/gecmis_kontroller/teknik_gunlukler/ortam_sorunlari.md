# Düzeltilen araç/ortam sorunları

- İlk bağımsız ASR denemesi, Faster-Whisper 1.2.1 ile PyAV 19.0.2 arasında API uyumsuzluğu nedeniyle çalışmadı: `TypeError: open() got an unexpected keyword argument 'metadata_errors'`. Ücretli servis açılmadan PyAV `16.1.0` sürümüne sabitlendi. Son kilit dosyası bu sürümü kullanır. Gerçek ASR bundan sonra çalıştırıldı.
- İlk araç hazırlığında standart Python'da requests yüklü değildi; model ortamı ayrı venv içinde kuruldu. Kaynak metinlerde veya repoda değişiklik yapılmadı.
- Firecrawl developer search HTTP 402 döndürdü. Ödeme başlatılmadı; resmî model/SDK/lisans kaynakları mevcut web araması ve doğrudan dosya indirmeleriyle incelendi.
- Eski Piper fahrettin kaynak dosyasına isteklerde HTTP 429 alındı; güncel resmî katalog bu sesi katkıcı isteğiyle kaldırmış olduğundan başka aynadan indirilmedi ve üretimde kullanılmadı.
- ASR ek denemesinde `A-U01.2-TR-01.wav` tam decoder hatası verdi. Sonraki hash kontrolü, dosyanın makbuzda kayıtlı ilk üretimden sonra 262.144 bayta düştüğünü gösterdi. Bu eski ASR sonucu geçersizdir ve tarihsel kanıt olarak korunur. Aynı metin/model/ayarlarla yeni WAV ve M4A üretildi, ilk üretimle aynı hash elde edildi.
- `A-H01.1-TR-01.m4a` 44 bayta düşmüş bulundu; WAV sağlamdı. Kayıt ikilisi aynı sabit ayarlarla yeniden üretildi ve ilk üretimle aynı hash doğrulandı.
- `A-H10.3-TR-01.wav` son kontrolde 2.359.296 bayta düşmüş bulundu. ASR'ye eklenen girdi hash denetimi bu dosyada çalışmayı durdurdu. Kayıt yeniden üretildi. Nedeni kesin belirlenemeyen bu dosya değişiklikleri gizlenmedi; son paket hash/decoder ve arşiv içi hash kontrollerinden geçirilir.
