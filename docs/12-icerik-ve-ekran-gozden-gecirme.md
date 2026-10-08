# İçerik ve ekran gözden geçirmesi — 8 Ekim 2026

Bu belge dinî uzman onayı değildir. Mevcut kataloglara yeni dinî talimat veya dua eklenmedi; açık kaynak sayfaları içerik ekibinin incelemesi için karşılaştırıldı. Kaynağa bağlantı vermek metni, görseli veya sesi yeniden yayımlama izni vermez.

## Katalog ve kaynak karşılaştırması

`python3 tools/content_audit.py`: Umre 18/18, Hac 35/35 adım **taslak**. Umre'de bir dua ve üç ses bağlantısı kaydı da taslak; Hac'da dua/ses kaydı yok. Katalog başlıkları gerçek ibadet metni değildir. Kaynak, kullanım hakkı, uzman ve tarih alanları dolmadan `approved` yayın durumuna alınamaz. Hac'ın üç profil uygulanabilirlik matrisi her adımda `unverified`.

| Karşılaştırma | Resmî başlangıç kaynağı | Katalogdaki durum ve gereken inceleme |
| --- | --- | --- |
| Umre ibadeti / tavaf / sa‘y | [Diyanet Bakara 2:196 tefsiri](https://kuran.diyanet.gov.tr/tefsir/Bakara-suresi/203/196-ayet-tefsiri) | U02–U10 başlık sırası genel kavramları içeriyor; açıklama, hüküm, okunuş, dua ve mezhep ayrıntıları yok. Her U kimliği tek tek kaynak konumu ve uzman kontrolü ister. |
| İfrad, temettü ve kıran | [Diyanet İstanbul Müftülüğü: Hac İbadeti](https://istanbul.diyanet.gov.tr/kartal/sayfalar/contentdetail.aspx?ContentId=143&MenuCategory=Kurumsal) | Üç profil adı var; H01–H10'un 35 satırının tamamı `unverified`. Kaynaktaki genel ayrım 105 profil kararını otomatik doğrulamaz. |
| Dualar, ziyaret ve açıklamalar | [Diyanet Hac ve Umre Rehberi duyurusu](https://hacumre.diyanet.gov.tr/Detay/449/hac-ve-umre-rehberi-mobil-uygulamas%C4%B1-yay%C4%B1nda) | Resmî uygulama bu kapsamı sunuyor; bizim katalogda onaylı dua/ses yok. Alıntı, uyarlama, lisans ve ses hakları ayrı edinilmeli. |

Ekran görüntüsü kontrolü: `docs/mvp-ui/home.png`, `audio-demo.png`, `groups.png`, `settings-dark.png`. Ana ekran ve ayarlarda Türkçe, okunaklı dokunma alanları ve taslak/teknik örnek ayrımı var. Yeni uyarı, “Umredeyim” girişinden önce taslak içeriği açıkça belirtiyor; yolculuk kartının alt yazısı da kişisel takip sınırını söylüyor. Dua kartı, taslak Arapça/okunuş/anlam metni yanlışlıkla doldurulmuş olsa dahi onay gelmeden bunları göstermiyor. Onaylı adım ile taslak bağlantılı dua varken katalog önizleme sayılıyor. Bunlar görsel ve widget kontrolleridir; fiziksel cihaz erişilebilirliği, işitilebilirlik veya gerçek saha kabulü değildir.

Yeni CI `37747539216`: 147 Flutter testi, analiz/format, 39 SQL, QA, Android debug/release ve iki Android emülatöründeki dört akış geçti. iOS derlemesi geçti; ilk Maestro koşusunda Umre girişi sonrasında boş ekran yakalandı (diğer üç akış başarılı), ikinci denemede XCTest sürücüsü açılışta süre aşımına uğradı ve hiç akış çalışmadı. Bu koşu iOS kabulü değildir. Testin ilk kartı görünür alana kaydırması ve Maestro'nun belgelenmiş sürücü açılış süresini 180 saniyeye çıkarması ayrı düzeltmedir; yeniden çalıştırılmadan sonucu başarılı yazılmamalı.

## Yayın için hâlâ gerekenler

1. Dinî editör, 18 Umre/35 Hac satırını; ilgili dua, kaynak yeri, kullanım izni ve profil kararlarını tek tek inceleyip ad/tarih ile onaylasın. Kaynak bilgisi tek başına fetva veya uzman onayı yerine geçmez.
2. Türkçe anlatım, Arapça okuma ve Türkçe anlam için metin sürümüne bağlı, izinli gerçek kayıtlar alınsın ve insan kulağıyla doğrulansın.
3. Lisanslı offline harita/POI/rota, doğrulanmış kurum ve saha bilgileri, canlı Supabase ve gerçek cihaz kabulü ayrı tamamlanıp uçak modunda ve iki platformda test edilsin.
