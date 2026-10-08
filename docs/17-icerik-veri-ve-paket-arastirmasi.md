# Kaynaklı taslak, veri hakları ve paket hazırlığı — 9 Ekim 2026

Bu çalışma **editöryal/teknik hazırlıktır**. Kaynak incelemesi dinî uzman, Arapça dil uzmanı, lisans sahibi veya saha görevlisi onayı değildir. Uygulama 53 adımı `draft` tutar; onaysız açıklama, dua ve ses kullanıcıya açılmaz. Kaynaklara erişim tarihi 2026-10-09 olarak kataloğa işlendi. Mevcut kimlikler ve ilerleme kayıtları korunur; katalog sürümü `inventory-2026-10-09-draft1` oldu.

## Dinî içerik ve profil farkları

18 Umre ve 35 Hac adımının her birine özgün kısa özet ile hazırlık, işlem, dikkat ve sonraki aşama alanları eklendi. Adım bazlı kaynak, bölüm, erişim tarihi ve kullanım hakkı durumu `assets/content/` kataloglarında ve `docs/content-review/2026-10-09-adim-onay-calisma.csv` içinde bulunur. CSV, eski uzman çalışma tablolarını ezmez; karar, düzeltme, hak ve gerçek inceleyen/tarih sütunları boş bırakıldı.

Başlıca kaynaklar:

- [Diyanet İlmihal I, Dokuzuncu Bölüm: Hac ve Umre, basılı s. 511–554](https://webdosya.diyanet.gov.tr/DiyanetAnasayfa/UserFiles/DiniBilgiler/ilmihal_cilt_1.pdf): ihram (518–525), tavaf (528–533), sa‘y (533–535), cemarat (537–541), umre (547–548), üç hac türü (548–550) ve yapılış sırası (550–554) için bölüm başlangıçları içindekilerden doğrulandı. Adım bazında ilgili alt bölüm/sayfa `sourceLocation` alanına işlendi; saha güvenliği yorumları kaynak hükmü olarak sunulmadı. Metinler kopyalanmadı; özgün kısa taslaklar yazıldı.
- [Din İşleri Yüksek Kurulu, İhram ne demektir?](https://kurul.diyanet.gov.tr/tr/fetva/ihram-ne-demektir/c8a56fea-4dd9-4872-090e-08dd1c135351): niyet/telbiye ve mezhep ayrımı.
- [Din İşleri Yüksek Kurulu, Tavaf nedir?](https://kurul.diyanet.gov.tr/tr/fetva/tavaf-nedir-ve-kac-cesit-tavaf-vardir/0193c42d-793d-79e9-3fb4-ff842e2a0759): tavaf yönü ve şavt bağlamı.
- [Din İşleri Yüksek Kurulu, Sa’yin eksik şavtları](https://kurul.diyanet.gov.tr/tr/fetva/sayin-savtlarini-eksik-yapan-kisiye-ne-gerekir/0193c42d-7a72-7dea-2f22-dcdaeaedf06b): tek yönlü geçiş sayımı.

Üç Hac profili için kaynak düzeyindeki farklar aşağıdaki uzman inceleme sırasına dönüştürüldü. `profileApplicability` **35 adımın tamamında `unverified`** kalır. İnceleme olmadan otomatik filtreleme açılmaz.

| Profil | Kaynakta ayırt edilen sıra | Uzman kararı gereken uygulama noktası |
| --- | --- | --- |
| İfrad | Hac ihramı; ön umre olmadan hac akışı | H02.4/H08.3 ön tavaf ve sa’yin durumuna göre uygulanabilirlik, kurban ve veda istisnaları |
| Temettü | Önce umre; ihramdan çıkış; hac için yeni ihram | H02.4/H02.5 ayrımı, kurban ve hac sa’yinin kişisel sıra kararı |
| Kıran | Tek ihramda umre ve hac ilişkisi | H02.4 ön aşaması, ihram sürekliliği, sa’y ve kurban hükümleri |

`P-U02.2-01` telbiye kaydına [Diyanet'in 28 Haziran 2019 tarihli hutbesindeki Arapça metin ve kaynak atfı](https://www.diyanet.gov.tr/tr-TR/Kurumsal/Detay/25737/cuma-hutbesi-bir-mukaddes-yolculuk-hac) başlangıç alınarak Arapça, taslak okunuş ve özgün kısa Türkçe anlam eklendi. Hutbe ayrıca Müslim, Hac 19 ve 21'e atıf yapar. Bu bir **editöryal taslaktır**; uzman/dil incelemesi ve uygulamada yayımlama hakkı doğrulanmadığı için `draft` kalır ve kullanıcı ekranında metin gizlidir. `docs/content-review/2026-10-09-dua-onay-calisma.csv` karar alanlarını boş bırakır. Türkçe anlatım sesi ile Arapça okuma ayrı kimliklerdedir. [Diyanet Hac Eğitimi materyal sayfası](https://hacumreegitim.hac.gov.tr/kaynaklar) Telbiye Arapça/Türkçe seslerini ve dua PDF'sini listeliyor; **uygulamada yeniden dağıtım veya seslendirme hakkı vermiyor**. Metin, okunuş, anlam ve kullanım hakkı ayrı kişi/kurumca teyit edilmeden kataloğa `approved` yazılmaz. Dua önerisi bir ibadetin zorunlu şartı olarak gösterilmez.

## Ses

Katalogdaki üç kayıt hâlâ taslak ve varlık yolu boş. `U02.2` Türkçe anlatım kaydının metin sürümü yeni taslağa eşlendi; Arapça dua kayıtları boş kaldı. Depodaki `assets/audio/teknik_demo.m4a` yalnız teknik QA fixture'ıdır, uygulama varlığı değildir. Diyanet materyallerinin çevrimiçi dinlenebilmesi uygulamada kopyalama hakkı sayılmadı. Yetkili TTS hesabı veya izin belgesi bulunmadığından ücretli üretim başlatılmadı. Gerçek ses için kayıt sahibi, yeniden dağıtım izni, metin kimliği/sürümü, işitsel inceleme ve cihaz testi gerekiyor.

## Çevrimdışı paket

`tools/build_offline_manifest.py` kullanıcıya ait ve hakları doğrulanmış bir klasördeki normal dosyaları sayar; yol, boyut, SHA-256 ve HTTPS indirme URL'lerinden mobil istemcinin beklediği alan sırasıyla manifest üretir ve sabitlenecek manifest özetini verir. Sembolik bağ, gizli dosya, mevcut çıktı üzerine yazma ve HTTP adresi reddedilir. Araç **dosya yüklemez veya bir sunucu kurmaz**. Örnek kullanım:

```sh
python3 tools/build_offline_manifest.py \
  --source-dir /izinli/paket-dosyalari \
  --base-url https://sahibine-ait-sunucu.example/paketler/1.0.0 \
  --package-id umre-ses-1 --kind audio --version 1.0.0 \
  --output /ayri/konum/package-manifest.json
```

Çıkan `sha256` değeri ancak hakları ve yükleme içeriği kontrol edildikten sonra derleme zamanındaki sabit güven özetine eklenir. Ayrı HTTPS katalog URL'si ve sunucu allowlist'i de gerekir. Yerel fixture sunucusunda indirme, sürüm güncelleme, bozuk hash reddi, geri dönüş ve silme test edildi; fixture HTTP taşıyıcısı yalnız testtedir. Üretim `HttpPackageFileFetcher` HTTPS şartını korur. Gerçek hosting, URL, lisanslı içerik ve yayın kabulü yoktur.

## Harita, POI, iletişim ve dil

[OpenStreetMap verisi ODbL lisanslıdır ve atıf ister](https://www.openstreetmap.org/copyright). [OSMF kamusal tile sunucusu politikası](https://operations.osmfoundation.org/policies/tiles/) offline toplu indirmeyi açıkça yasaklar. Uygun aday, lisans/atıf yükümlülükleri yönetilen OSM verisinden **kendi sunucusunda** üretilmiş tile'lar veya offline izni açık bir sağlayıcıdır. Sağlayıcı/stil/region henüz seçilip işletilmedi; `MapLibreOfflineMapAdapter` için gerçek çevrimdışı harita oluşturulmadı. OSM POI koordinatları sahada doğrulanmış hastane, eczane veya yürünebilir rota sayılmaz; bu turda üretim POI/rota paketi yapılmadı.

[T.C. Cidde Başkonsolosluğu güncel resmî sayfası](https://cidde-bk.mfa.gov.tr/Mission/Index) 7/24 konsolosluk çağrı merkezini yayımlıyor. Ancak yayında kullanılacak telefonun tam biçimi, kapsamı, bölgesi ve güncellik süreci gerçek operatör tarafından ayrıca kabul edilmelidir; eski acil numara duyuruları bu nedenle kataloğa taşınmadı. Canlı kapı/yoğunluk verisi için doğrulanmış servis yok. `docs/content-review/dil-kartlari-taslak.csv` yalnız Türkçe ihtiyaç cümleleri ve Arapça insan inceleme alanlarını hazırlar; uygulama bunları onaylı dil kartı olarak göstermez.

## Açık kabul girdileri

1. Yetkili dinî uzman ve Arapça dil uzmanı: 53 adım, telbiye/dua taslağı ve anlamı, üç profil matrisi ve manuel sayaç hedefleri.
2. Hak sahipleri: gerçek insan sesi/TTS kullanım ve dağıtım yetkisi; Diyanet materyalinin yeniden kullanımı gerekiyorsa ayrıca yazılı izin.
3. Paket işletmecisi: HTTPS dosya/katalog barındırması, sabit güven özeti yönetimi ve kaynak lisansları.
4. Harita/saha sorumlusu: offline tile hakkı, görünür atıf, doğrulanmış POI/rota, resmî iletişim ve veri yenileme süreci.
5. Canlı servis/cihaz: Supabase ve APNs/FCM hesapları ile iki hesaplı kabul, fiziksel Android/iPhone ve gerçek ses/konum testi.
