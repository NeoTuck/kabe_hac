# Kalite raporu — 22 Ekim 2026

**54/54 kayıt üretildi: 18 Umre adımı, 35 Hac adımı, telbiyenin Türkçe anlamı.** Arapça `A-P-U02.2-AR-01` üretilmedi. Her kayıtta 1 PCM 24 bit WAV ana dosyası + 1 mono AAC/M4A kopyası var. Toplam WAV süresi **1321.84 saniye (22 dakika 1.8 saniye)**.

Kaynak dal GitHub bağlantısıyla doğrulandı: `codex/mvp1-pilot`, son commit `824e540a20ef3024445437d4fe43f23c8550a559` (15 Ekim 2026). Salt okunur kaynak kopyası temiz; commit/push/PR/merge/katalog kabul değişikliği yapılmadı. Mevcut araçların gerçek planı metin ve sürüm için esas alındı. Kullanıcının metin incelemesinin tamamlandığı beyanıyla ilerlenmiştir; kaynak kataloglar `draft` kalır ve resmî uzman imzası yoktur.

## Gerçek teknik sonuçlar

- 54 benzersiz ses kimliği / metin kimliği / sürüm / tam metin SHA-256 eşleşmesi geçti. Metin dosyaları byte düzeyinde plan ve kaynak katalogla eşit.
- 54 WAV ve 54 M4A dosyasının decoder ile sonuna kadar açılması, pozitif süre, sonlu örnekler, sessiz olmama, clipping ve tek mono akış kontrolleri geçti. M4A ayrıca orijinal `verify_recording.verify()` denetiminden geçti; gerçek sonuç her makbuzdadır.
- Bütün dosyalarda aynı sabit model, M1 stili, aynı stil hash'i ve üretim ayarları doğrulandı. Bu, algılanan cinsiyet/doğallık için bağımsız insan değerlendirmesi değildir; üretici tarafından yayımlanan erkek hazır ses kimliğidir. Perde düşürme yoktur.
- M4A entegre ses yüksekliği: **-20.30 – -20.01 LUFS**; fark 0.29 LU. RMS: -21.37 – -20.85 dBFS. En yüksek gerçek tepe -2.31 dBTP; clipping yok.
- İlk/son 100 ms sınır sakinliği 108/108 geçti. Model çıkışı kırpılmadı; başa/sona 250 ms dolgu eklendi. En uzun -45 dBFS altı 20 ms çerçeve dizisi 1.72 saniye (<2,5 sn eşiği). Bu ölçüm baş/son kelimenin TTS tarafından hiç atlanmadığını kanıtlamaz.
- Tek kayıt süresi 8.65 – 29.52 sn. Metin uzunluğuna göre hız 11.04 – 11.81 karakter/sn; farklı metin uzunlukları nedeniyle kayıt süreleri eşit olması beklenmez. WAV/M4A süre farkları <100 ms.

## Bağımsız ASR

54/54 WAV, bağımsız Türkçe Faster-Whisper small modeliyle yerel CPU üzerinde çözümlendi. Kaynak metin ASR'ye prompt olarak verilmedi. Toplam kelime hata oranı (normalize edilmiş ağırlıklı WER) **%4.73**; **22 kayıt** belirlenen otomatik kurallarla ayrıca dikkat işareti taşıyor. Eşik: WER >%15, >2 silinen kelime, dinî terim sayımı farkı veya ilk/son üç kelime eşleşmemesi. Düşük fark da insan incelemesini kapatmaz.

`asr_ozet.csv` ve `asr/` dosyaları eksik/fazla/değişen kelimeleri, dinî terim farklarını, tam transcript'i ve kelime zamanlarını içerir. Türkçe çekim, birleşik yazım ve tanıyıcı yanılmaları yanlış alarm verebilir. Otomatik düzeltme kaynak metni değiştirmedi. Hedefli yeniden deneme yapılmışsa ilk sonuç ve son seçim `gecmis_kontroller/` ve `yeniden_deneme_raporu.json` içinde korunur. Ara hash turlarında üç dosyanın makbuzdan farklılaştığı saptandı (iki WAV sırasıyla 262.144 ve 2.359.296 bayt, bir M4A 44 bayt olarak kaldı). Sebep kesin belirlenemedi. İlgili eski makbuz/ASR ve hata kanıtları korundu; dosyalar yeniden üretildi ve son hash/decoder/ZIP denetimine yeniden tabi tutuldu. Hiçbir başarısız kontrol sessizce başarıya çevrilmez.

| Ses kimliği | Başlık | Süre (sn) | ASR WER | ASR işareti |
| --- | --- | ---: | ---: | --- |
| A-U01.1-TR-01 | Kullanım biçimi seçimi | 23.23 | %0.0 | Düşük fark |
| A-U01.2-TR-01 | Hazırlık | 26.71 | %7.0 | Düşük fark |
| A-U02.1-TR-01 | İhram ve mikat bağlamı | 28.55 | %0.0 | Düşük fark |
| A-U02.2-TR-01 | Niyet ve telbiye | 28.75 | %4.7 | Düşük fark |
| A-U02.3-TR-01 | İhram bilgileri | 29.52 | %4.7 | Düşük fark |
| A-U03.1-TR-01 | Mescid-i Haram'a yaklaşma | 26.78 | %9.5 | İncele |
| A-U04.1-TR-01 | Kâbe'yi ilk görüş bağlamı | 25.67 | %0.0 | Düşük fark |
| A-U05.1-TR-01 | Tavaf başlangıcı ve yönü | 26.23 | %12.2 | İncele |
| A-U06.1-TR-01 | İlk şavtı öğrenme | 23.65 | %16.2 | İncele |
| A-U06.2-TR-01 | Yedi şavt takibi | 23.09 | %8.8 | İncele |
| A-U06.3-TR-01 | Tavaf sonrası geçiş | 24.35 | %2.6 | İncele |
| A-U07.1-TR-01 | Tavaf namazını öğrenme | 24.83 | %0.0 | Düşük fark |
| A-U07.2-TR-01 | Zemzem | 24.21 | %2.6 | İncele |
| A-U08.1-TR-01 | Safâ ve sa‘y başlangıcı | 26.25 | %2.3 | İncele |
| A-U09.1-TR-01 | İlk gidiş/dönüş ve sayım | 21.91 | %10.8 | İncele |
| A-U09.2-TR-01 | Yedi geçişin takibi | 21.84 | %11.1 | İncele |
| A-U10.1-TR-01 | Tahallül bilgisi | 26.09 | %2.7 | İncele |
| A-U10.2-TR-01 | Öğrenme/yolculuk özeti | 25.53 | %0.0 | Düşük fark |
| A-P-U02.2-ANLAM-01 | Telbiye duasının Türkçe anlamı | 8.65 | %13.3 | Düşük fark |
| A-H01.1-TR-01 | Hac türü ve profil seçimi | 26.50 | %12.2 | İncele |
| A-H01.2-TR-01 | Gün ve güzergâh bağlamı | 26.09 | %5.1 | Düşük fark |
| A-H01.3-TR-01 | Kullanım ve paket hazırlığı | 27.15 | %4.8 | İncele |
| A-H02.1-TR-01 | Hazırlık ve mikat | 26.80 | %7.1 | İncele |
| A-H02.2-TR-01 | Niyet ve telbiye | 24.35 | %2.6 | Düşük fark |
| A-H02.3-TR-01 | Mekke ve ilk görüş bağlamı | 25.11 | %2.6 | Düşük fark |
| A-H02.4-TR-01 | İlgili ön aşama | 25.81 | %15.4 | İncele |
| A-H02.5-TR-01 | Hac başlangıcına geçiş | 25.46 | %5.1 | İncele |
| A-H03.1-TR-01 | İlk güzergâh | 25.18 | %5.3 | İncele |
| A-H03.2-TR-01 | Uygulanırsa ilk Mina | 24.90 | %2.7 | Düşük fark |
| A-H03.3-TR-01 | Arafat'a geçiş açıklaması | 23.30 | %8.8 | Düşük fark |
| A-H04.1-TR-01 | Arafat ve sınır bilgisi | 25.25 | %5.7 | Düşük fark |
| A-H04.2-TR-01 | Namaz ve vakfe bağlamı | 25.32 | %0.0 | Düşük fark |
| A-H04.3-TR-01 | Dua zamanı | 22.81 | %0.0 | Düşük fark |
| A-H04.4-TR-01 | Sonraki geçiş | 22.74 | %9.1 | İncele |
| A-H05.1-TR-01 | Gece varışı | 24.69 | %2.9 | İncele |
| A-H05.2-TR-01 | Namaz ve vakfe bağlamı | 22.95 | %0.0 | Düşük fark |
| A-H05.3-TR-01 | Taş hazırlığı ve Mina'ya yönelim | 23.37 | %2.7 | İncele |
| A-H06.1-TR-01 | Aktif gün ve hedef | 23.16 | %0.0 | Düşük fark |
| A-H06.2-TR-01 | Yaklaşma bilgisi | 23.86 | %2.8 | Düşük fark |
| A-H06.3-TR-01 | Manuel atış takibi | 23.93 | %5.4 | Düşük fark |
| A-H06.4-TR-01 | Sonraki hedef | 24.21 | %2.6 | Düşük fark |
| A-H07.1-TR-01 | Kurban bağlamı | 24.28 | %6.5 | İncele |
| A-H07.2-TR-01 | Tahallül | 23.65 | %0.0 | Düşük fark |
| A-H07.3-TR-01 | Sonraki aşama | 24.83 | %8.3 | Düşük fark |
| A-H08.1-TR-01 | Ziyaret tavafı | 23.44 | %11.1 | İncele |
| A-H08.2-TR-01 | Tavaf sonrası | 23.44 | %3.0 | Düşük fark |
| A-H08.3-TR-01 | Gerekiyorsa sa'y | 25.74 | %13.2 | İncele |
| A-H08.4-TR-01 | Sonraki durum | 23.58 | %0.0 | Düşük fark |
| A-H09.1-TR-01 | Mina ve yeni gün | 22.53 | %2.8 | Düşük fark |
| A-H09.2-TR-01 | Günün cemre sırası | 24.83 | %2.4 | Düşük fark |
| A-H09.3-TR-01 | Devam veya ayrılma dalı | 24.76 | %0.0 | Düşük fark |
| A-H10.1-TR-01 | Veda uygulanabilirliği | 25.95 | %0.0 | Düşük fark |
| A-H10.2-TR-01 | Veda açıklaması | 22.74 | %0.0 | Düşük fark |
| A-H10.3-TR-01 | Özet | 23.30 | %0.0 | Düşük fark |

## Kalan incelemeler

**54/54 yeni kayıtta insan dinleme: BEKLİYOR.** Bu oturumda sesler işitsel olarak dinlenmedi; yalnız sinyal/decoder ve ASR incelendi. Dinî terim telaffuzu, akıcılık, sakin/doğal anlatım, eksik/fazla kelimeler ve gerçek Android/iPhone oynatma kabulü insan tarafından tamamlanmalıdır. Eski ses kabulü taşınmadı. Metnin kullanıcı tarafından gözden geçirilmiş olması yeni sesin telaffuz onayı değildir.

Model: Supertonic 3 / hazır erkek M1. Lisans motor MIT, ağırlıklar OpenRAIL-M; görünür sentetik ses açıklaması ve kullanım kısıtları korunmalıdır. Lisans dosyası ve yayımlanmış hazır ses izni, tüm eğitim korpusu/konuşmacı sözleşmelerinin bağımsız denetlenmesi demek değildir. Ayrıntılar `LISANS_VE_KAYNAKLAR.md` içindedir.

Gerçek üretim Linux x86_64 CPU üzerinde yapıldı. Mac M3/8 GB üzerinde veya Metal/CoreML ile denenmedi. ZIP çıkarıldıktan sonra `DINLE.html` 54 kaydı başlık ve tam metinle çevrimdışı gösterir. Sayfadaki kişisel dinleme kutuları yerel tarayıcı tercihleridir; resmî kabul belgesi oluşturmaz.
