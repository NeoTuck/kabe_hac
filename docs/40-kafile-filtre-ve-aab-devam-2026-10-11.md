# Kafile filtresi ve gerçek AAB doğrulaması — 11 Ekim 2026

Başlangıç yerel/uzak `2a358c4`, hedef `codex/mvp1-pilot`, PR #1. Kullanıcı
değişikliği yoktu; mevcut özellikler, taslaklar ve yayın kapıları korundu.

## Uygulanan işler

- Sunucuda sürümlü `content_moderation_policies`: koşul sürümüne bağlı, gerçek belge
  URL/hash alanlı, yalnız trusted operator/service-role yazabilir. Kullanıcılar kural
  kataloğunu okuyamaz veya seçemez. Üretim politika satırı eklenmedi.
- Sohbet/özel mesaj/duyuru INSERT ve metin UPDATE filtrelenir. Koşul kabulü ilk hata
  olarak kalır. Politika eksik veya başka koşul sürümündeyse yazma kapanır. 1–200,
  en çok160 karakter literal kurallar NFKC/case/whitespace/zero-width normalizasyonuyla
  uygulanır; regex çalıştırılmaz. Bunlar tam bağlamsal/insan moderasyonu kabulü değildir.
- Kabul edilen metne güvenilir politika sürümü ve sunucu kontrol zamanı yazılır;
  istemcinin gönderdiği sahte değerler ezilir. Kural değişikliği yeni sürüm gerektirir.
  Policy satırı `FOR SHARE` kilitlenir; yayınla eşzamanlı gönderim eski kurala dayanarak
  sessizce kabul edilmez. RLS, outbox, rapor/engel ve trusted silme korunur.
- Reddedilen mesaj SQLite outbox'ta `rejected` olur; hesap veya yeniden açılışta
  otomatik tekrar gönderilmez. Neden ve sonraki adım görünür. Kendi reddedilen yerel
  mesajını kaldırma idempotenttir; başka hesap veya gönderilmiş/pending kayıt silinmez.
  Politika outage'ı `failed`/retryable kalır. SQLite v10 yükseltmesi eski owner,
  recipient, pending/failed/sent, hata ve attempt kayıtlarını korur; prova ayrı kalır.
- [Gerçek politika teslimi](release-handoff/2026-10-10/MODERATION_POLICY.md) hazır;
  inceleyen/karar/kurallar gerçek sorumlu tarafından sağlanmalı, QA fixture taşınmamalı.
- [Google bundletool1.18.3](https://github.com/google/bundletool/releases/tag/1.18.3)
  resmî asset SHA-256 ile sabitlendi. `audit_android_bundle.py` gerçek AAB BundleConfig
  `PAGE_ALIGNMENT_16K`/enabled kontrolü ve gerçek universal APK üretimi yapar; türev
  APK'da QA varlığı dışlama, ELF/ZIP hizalama ve hash raporu oluşturur. CI ayrıca
  türevde `zipalign` çalıştırır. Upload credential verilmez; imza kabulü yoktur.
- Native setup bulguları düzeltildi: API28'de getconf127 durumunda gerçek
  `/proc/self/smaps` KernelPageSize okunur; sabit tahmin kullanılmaz. 16 KB disposable
  emülatörde adbd restart/closed setup yanıtı en çokiki kez denenebilir, gerçek UID0
  ve iki compatibility property'si readback ile doğrulanır. UI/assertion yeniden
  denemesi eklenmedi. Yanlış sayfa boyutu, root veya property native testi durdurur.

## Kanıt

[CI38130152986](https://github.com/NeoTuck/kabe_hac/actions/runs/38130152986)
başlangıç `2a358c4` içindir; bu yeni Kafile/AAB/setup kodunun kabulü değildir.
Test merge `20ff8162` ile baseline kod ağacı aynı doğrulandı.

| Kontrol | Sonuç |
| --- | --- |
| Son yerel kod | 238 Flutter,82 Python,137 pgTAP,45 bağımsız sunucu SQL,13 Node geçti;92 dosya format/analyze0. Eski assertion'lar kaldırılmadı. Gerçek v8 fixture'a mevcut outbox eklenip rehber/prova/mesaj korunması birlikte doğrulandı. |
| Yeni SQL kapsamı |22 yeni pgTAP: politika eksikliği, kullanıcı rule seçimi, boş kural, sürüm immutability, case/zero-width/boşluk, özel sohbet/duyuru, gövde update, RLS, koşul yenileme ve server stamp. |
| Eşzamanlı SQL | Var olan7 PostgreSQL yarış testine2 politika yayın/gönderim yarışı eklendi. Yerelde PostgreSQL yok; yeni9 yarışın gerçek çalışması CI'da açık. PGlite bunların kabulü değildir. |
| Baseline Android35 |9/9 uygulama +54 gerçek paketli anlatım +ayrı probe passed. Artifact11699725552 digest `25420dd8bbb812080e32c1c7773dc92d76917dae36ebeec4e909efb987476cf7`, JUnit/session/kurulu APK hash incelendi. |
| Baseline Android28 | UI başlamadan getconf eksikliği exit127; kabul yok. Yeni fallback sayfa büyüklüğünü gerçek kernel mapping'den ölçer. |
| Baseline Android36/16 KB | Gerçek sayfa16384 ölçüldü; root setup `unable to connect ... closed` ile durdu. UI veya54 ses çalıştı denmedi; yeni helper UID0/property readback olmadan kabul vermez. |
| Baseline iOS | İki paket privacy-inventory adımı passed; Xcode16.4/iOS18.5 9/9 ekran +54 gerçek paketli anlatım +ayrı probe geçti; artifact/JUnit/session incelendi. Xcode26.2 son kontrolde in_progress. Gerçek .app içinde23 manifest yapı/hash envanteri geçti; SDK kapsamı/mağaza kabulü değildir. |
| Gerçek AAB türevi | Artifact11697949156 digest `986dfe4b2e4c10898a21275218a75aa3a252e13eab903a7a1c9f0e6c67386bea` doğrulandı. AAB hash `6a0e174eed727cc39a85559644f07da8800cf5396c148129c88311c233a2a4d3`; actual BundleConfig16K, universal APK10 adet64-bit `.so` LOAD/ZIP ve native zipalign geçti. Yerel türev unsigned uyarısı verdi; kurulabilir/üretim imzalı diye sunulmaz. |
| Yayın kapıları | Full blocked158, MVP blocked546; dış kanıt sayısı yazılım hatası değildir. LIVE kapalı, gerçek içerik/hak/cihaz/imza kabulü yok. |

Binary, tool ve çalıştırılmayan kabul kayıtları
[QA JSON](qa/2026-10-11-kafile-aab-devam.json) içinde.
Son uygulama değişikliklerinin native sonuçları yeni CI'da kontrol edilmelidir.
Yerel Android Gradle plugin erişim engeli sürer; Linux'ta Xcode/fiziksel iPhone veya
bağlı adb cihazı yoktur. Canlı projeye migration/policy veya mağazaya paket gönderilmedi.

## Kalan işler ve dış teslim

Teknik kod boşluğu olan preposting hattı ve gerçek AAB türev kontrolü bu dilimde
uygulandı. Kalan teknik kabul: son native4K/16K/iki iOS ve gerçek9 SQL yarışı,
RELRO/runtime gözlemi, son üretim imzalı AAB/Play split ve SDK kapsam doğrulaması.
Yeni failure kanıtı gelirse assertion korunarak düzeltilir.

Dış girdiler değişmedi: gerçek yasak içerik/policy/müdahale belgesi, iki test hesaplı
servis/Firebase/APNs projesi ve dört hizmet URL'si; uzman/profil ve ses hakları,
sürümlü Arapça telbiye; fiziksel iPhone ve yayın hesabı/imza/mağaza formları.
Somut içerik ve cihaz teslimi [docs/39](39-yayin-arastirmasi-ve-paket-kontrolleri-2026-10-11.md)
ve release-handoff içinde. Filtre kodu bu gerçek operasyon/onayların yerine geçmez.
