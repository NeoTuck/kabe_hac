# MVP yayın kapsamı denetimi

`mvp-release-scope.v1.json` bugünkü uygulamanın görünür 53 adımını, bir dua
kaydını, katalogdaki 55 ses kimliğini (54 paketli taslak dosya ve eksik Arapça
telbiye), üç indirilebilir gezi/harita paketini ve canlı hizmet kararını
sürümleriyle listeler. Dosya bir yayın onayı değildir. Mevcut kapsam **blocked**
olmalıdır: dinî içerik taslak, 54 ses hak/dinleme incelemesinde, Arapça kayıt
eksik, canlı hizmet kapalı ve dış kabul kanıtları yoktur.

Depo kökünden ayrı MVP denetimi:

```sh
python3 tools/release_preflight.py \
  --mvp-scope docs/qa/mvp-release-scope.v1.json \
  --output build/mvp-release-preflight.json
```

Argümansız komut eski **tam sürüm** denetimini çalıştırmaya devam eder. İki
sonucu ayrı raporlayın. Çıkış 2 engelli, 0 yalnız girdilerin biçim/hash
denetimi geçti anlamındadır; bağımsız insan, mağaza veya dinî kabul anlamına
gelmez.

Kapsam denetimi manifesti iki yerel katalogdaki gerçek ID/sürümlerle birebir
eşleştirir. Katalog dosyası hash'ini, `pubspec.yaml` ile paketlenen ses
dosyalarının tam kümesini, katalogdaki ses hash'lerini ve indirilebilir paket
kataloğunun hash/ID/sürümlerini denetler. Manifestte bir adımı veya sesi
silmek, uygulamanın onu göstermesini ya da paketlemesini değiştirmediği için
engeldir. Kısmi MVP istenirse önce çalışma zamanında görünür içeriği ve
derlemede paketlenen varlıkları gerçekten filtreleyen, ayrıca doğrulanan bir
uygulama değişikliği gerekir.

Üretim kabulü için katalogdaki her görünür kaydın sürümüne bağlı uzman/hak
kararı, ses dosyasının hak ve dinleme kararı, gerçek hizmet bağlantıları,
harita hakkı, fiziksel cihaz ve imzalı paket kanıtları tamamlanmalıdır.
Denetim yerel kaynakları okur; dağıtılmış APK/AAB/IPA'nın içeriğini,
bağlantıların gerçekten açıldığını veya kanıtı imzalayan kişinin yetkisini
tek başına doğrulamaz. Bu kontroller son yayın kabulünde ayrıca yapılır.
