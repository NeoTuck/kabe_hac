# Lisans ve kaynaklar

Bu paketteki 54 ses yapay zekâ ile üretilmiş **sentetik erkek anlatımıdır**. İnsan kaydı veya uzman onaylı ses olarak sunulmaz. Önceki seslerin dinleme/hak kabulü bu yeni dosyalara taşınmamıştır. İnceleme tarihi: 22 Ekim 2026.

| Katman | Gerçek kaynak ve koşul | Bu pakette kullanım |
| --- | --- | --- |
| Motor | `supertonic==1.3.1`; MIT; © Supertone Inc. | Yerel Python/ONNX çalıştırıldı. Lisans kopyası eklendi. |
| Model ağırlıkları | `Supertone/supertonic-3`, revizyon `3cadd1ee6394adea1bd021217a0e650ede09a323`; **BigScience Open RAIL-M** | Ticari kullanım yasağı bulunmuyor. Kullanım sınırlamaları olan bir model lisansıdır; MIT diye sunulmaz. |
| Hazır ses | Aynı resmî revizyonda `voice_styles/M1.json`; hazır erkek ses stili | Modelle birlikte yayımlanan yerleşik stildir. Dışarıdan referans ses, izinsiz gerçek kişi klonu veya ücretli Voice Builder kullanılmadı. Ayrı ses stili lisansı yayımlanmamış; model paketinin lisans beyanı esas alındı. |
| Referans ses | Haricî kayıt yok | Referans dosyası indirilmedi veya klonlama yapılmadı. |
| Model eğitim verileri | Resmî model kartı tüm korpus/konuşmacı sözleşmelerini yayımlamıyor | Her bir eğitim kaydı için bağımsız onam/hak zinciri doğrulandığı iddia edilmez. Yayımlayanın model ve hazır stil kullanım izni esas alındı. |
| ASR | `Systran/faster-whisper-small`, revizyon `536b0662742c02347bc0e980a01041f333bce120`; Whisper/MIT | Yalnız yerel otomatik kıyas. ASR motoru `faster-whisper==1.2.1`; ağırlıklar ZIP'e konulmadı. |
| Metin | NeoTuck/kabe_hac `824e540a20ef3024445437d4fe43f23c8550a559` | Kullanıcı metin incelemesinin tamamlandığını bildirdi. Katalogdaki mevcut `draft`, kaynak ve hak alanları aynen korunur; resmî belge üretilmez. |

## Uygulamada dağıtım değerlendirmesi

Model lisansı madde 6, lisans verenin üretilen çıktı üzerinde hak iddia etmediğini belirtir; çıktının kullanımı lisans hükümlerine aykırı olamaz. Bu nedenle ücretli/ticari bir uygulamada ses dosyası dağıtımını yasaklayan bir hüküm saptanmadı. Bununla birlikte bu sonuç, uygulamanın bütünü için resmî hukuki/yayın kabulü değildir; metnin kendi kaynak hakları ayrı kalır.

Özellikle Ek A(e), içeriğin makine üretimi olduğunu açık ve anlaşılır biçimde bildirmeden dağıtımını sınırlar. `DINLE.html` bu bildirimi görünür gösterir; M4A dosyalarının metadata alanına da sentetik ses bildirimi yazılmıştır. Uygulamaya alınırken kullanıcıya görünür **“Yapay zekâ ile üretilmiş erkek anlatımı”** açıklaması korunmalıdır; yalnız metadata son kullanıcı için görünür bildirim yerine geçmez. Ek A(g) izinsiz kimliğe bürünmeyi yasaklar. Paket belirli bir gerçek kişinin kimliğini iddia etmez. Model veya model türevi yeniden dağıtılacak olursa madde 4'teki lisans kopyası, bildirimler ve kullanım kısıtlarının aktarımı ayrıca gerekir. Bu ZIP ağırlıkları içermez.

Atıf: **Supertonic 3 / Supertone Inc. (2026), OpenRAIL-M; Supertonic Python SDK, MIT; hazır M1 erkek ses stili.** Atıf ve lisans metinleri `lisanslar/` içindedir.

## Resmî bağlantılar

- [Sabit model kartı](https://huggingface.co/Supertone/supertonic-3/blob/3cadd1ee6394adea1bd021217a0e650ede09a323/README.md)
- [Sabit model lisansı](https://huggingface.co/Supertone/supertonic-3/blob/3cadd1ee6394adea1bd021217a0e650ede09a323/LICENSE)
- [Sabit M1 stili](https://huggingface.co/Supertone/supertonic-3/blob/3cadd1ee6394adea1bd021217a0e650ede09a323/voice_styles/M1.json)
- [Motor belgeleri](https://github.com/supertone-oss-archive/supertonic-py)
- [Motor lisansı](https://github.com/supertone-oss-archive/supertonic-py/blob/main/LICENSE)
- [ASR model kartı](https://huggingface.co/Systran/faster-whisper-small/blob/536b0662742c02347bc0e980a01041f333bce120/README.md)
- [Whisper lisansı](https://github.com/openai/whisper/blob/main/LICENSE)
- [Kaynak commit](https://github.com/NeoTuck/kabe_hac/commit/824e540a20ef3024445437d4fe43f23c8550a559)

## Seçilmeyenler ve araç sınırları

EMA Lightning tek seslidir; erkek/speaker parametresi uydurulmadı. Piper `dfki` ve MMS Türkçe, ticari olmayan lisansları nedeniyle seçilmedi. Piper `fahrettin`/`fettah` resmî güncel depodan katkıcıların isteğiyle kaldırılmış göründüğünden eski aynalardan alınmadı. Üretimde Piper veya perde düşürme kullanılmadı. Firecrawl doküman araması HTTP 402 döndürdü; ücretli işlem başlatılmadan resmî kaynaklar web ve doğrudan indirme ile incelendi.

Motor deposu Eylül 2026 itibarıyla arşivlenmiş. Bu paket sabit yayımlanmış sürümü kullanır; bakım desteği vaadi içermez. Mac M3/8 GB üzerinde test yapılmadı. Linux'ta CPU üzerinde gerçek üretim yapıldı.
