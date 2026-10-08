# Teknik ses kaydı

`teknik_demo.m4a` sentetik, dinî açıklama/dua olmayan teknik denemedir;
uzman onaylı insan anlatımı yerine kullanılmaz.

8 Ekim 2026 mobil kabulünde önceki 6,6 saniyelik kayıt, Maestro'nun native
hareketli ekranı bulma işlemi sırasında bitiyordu. Aynı mevcut sentetik kayıt
tekrarlanarak 30 saniyeye uzatıldı. Sessiz süre eklenmedi, yeni dinî metin veya
üçüncü taraf ses eklenmedi. Oynat/duraklat, süre ve 10 saniye sarma kontrolleri
için daha uzun teknik deneme sağlar. İnsan sesi/hak/onay girdileri hâlâ eksiktir.

Önceki kaydın SHA-256 değeri:
`2ce5971e54cb32dacabe3d75a9250fdcb23bcc9be805a3153050d728e61204d9`.
Önceki dosya Git geçmişinde bulunur. Yeniden üretim (geçici önceki dosyadan):

```sh
ffmpeg -stream_loop -1 -i ORIGINAL.m4a -t 30 -c:a aac -b:a 64k -movflags +faststart teknik_demo.m4a
python3 tools/verify_audio.py
```

Maestro'nun bekleme sınırı tek başına native sürücü iç işlemini kesemedi.
Test “Ses duraklatıldı” durumunu zorunlu tutar; tamamlanmayı kabul saymaz.
