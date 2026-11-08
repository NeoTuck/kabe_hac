#!/usr/bin/env python3
"""Generate authentic Umrah guide audio using Google Gemini TTS with natural breath pacing and Charon voice."""

import base64
import csv
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.request
import wave

ROOT = Path(__file__).resolve().parent.parent
AUDIO_DIR = ROOT / "assets/audio/review-male-v1"
CATALOG_PATH = ROOT / "assets/content/umre_inventory.v1.json"
MAKBUZ_DIR = ROOT / "docs/audio-review/male-v1/makbuzlar"
CSV_PATH = ROOT / "docs/audio-review/male-v1/ses_envanteri.csv"

API_KEY = os.environ.get("GEMINI_API_KEY", "")

MODELS = [
    "gemini-3.8-flash-tts",
    "gemini-3.8-flash-lite-tts",
    "gemini-2.5-flash-preview-tts",
    "gemini-3.1-flash-tts-preview",
]

ITEMS = [
    {
        "id": "U01.1",
        "audio_id": "A-U01.1-TR-01",
        "title": "Umre Yolculuğuna Niyet ve Başlangıç",
        "summary": "Kutlu Umre seferine niyet ve samimi bir tevbe ile başlıyoruz.",
        "details": "Değerli kardeşim... Allah'ın evine, bu kutlu beldeye yapacağın mübarek Umre yolculuğu şimdiden hayırlı olsun. Bu kutlu sefer, sadece bedenen Mekke'ye gitmek değil... Kalben günahlardan arınma, ve Rahman'ın huzuruna çıkma vaktidir. Yola çıkmadan önce samimi bir tevbe edelim... Ve bütün sevdiklerimizle helalleşelim."
    },
    {
        "id": "U01.2",
        "audio_id": "A-U01.2-TR-01",
        "title": "Yolculuk ve Valiz Hazırlığı",
        "summary": "İhram kıyafeti, kokusuz temizlik ürünleri ve ibadet hazırlığı.",
        "details": "Umre yolculuğuna çıkarken yanımıza... Dikişsiz iki parça ihram örtüsü, emniyetli bir ihram kemeri, ve tavafta ayağımızı yormayacak rahat bir terlik alıyoruz. İhramlıyken koku kullanmak yasak olduğu için... Mutlaka kokusuz sabun ve şampuan tercih etmeliyiz. En önemlisi de... Kalbimizi dünyalık telaşlardan arındırıp, bu kutlu ibadete hazırlamalıyız."
    },
    {
        "id": "U02.1",
        "audio_id": "A-U02.1-TR-01",
        "title": "Mikat Sınırı ve İhram Hazırlığı",
        "summary": "Mikat sınırında ihram hazırlığı ve dikişsiz örtülere bürünme.",
        "details": "Şu an Mikat sınırındayız... Burası, Peygamber Efendimiz aleyhisselamın belirlediği, ve ihramsız asla geçilmeyecek kutlu sınırdır. Uçakta veya Mikat mescidinde abdestimizi tazeleyip... Erkekler dikişsiz ihram örtülerine bürünür. Hanım kardeşlerimiz ise, kendi mutad kıyafetleriyle ihrama girerler."
    },
    {
        "id": "U02.2",
        "audio_id": "A-U02.2-TR-01",
        "title": "İhram Namazı, Niyet ve Telbiye",
        "summary": "İki rekat ihram namazı, kalpten umre niyeti ve telbiyeye başlama.",
        "details": "İhrama büründükten sonra... Eğer kerahet vakti değilse, iki rekat ihram namazı kılarız. Namazın ardından kalbimizi Rabbimize açıp niyet ederiz: 'Allah'ım... Senin rızan için Umre yapmaya niyet ettim. Onu bana kolaylaştır, ve benden kabul eyle.' Niyetimizin hemen peşinden... Aşkla ve huşû ile telbiyemizi getirmeye başlarız."
    },
    {
        "id": "P-U02.2-01",
        "audio_id": "A-P-U02.2-ANLAM-01",
        "title": "Telbiye Zikri ve Türkçe Anlamı",
        "meaningTr": "Telbiye, kulun Rabbine teslimiyet feryadıdır... 'Lebbeyk Allahümme lebbeyk... Lebbeyke lâ şerîke leke lebbeyk... İnnel-hamde ven-ni‘mete leke vel-mülk... Lâ şerîke lek.' Yani: 'Buyur Allah'ım buyur... Davetine icabet ettim. Senin hiçbir ortağın yoktur. Hamd ve nimet sana aittir... Mülk de senindir. Senin hiçbir ortağın yoktur.'"
    },
    {
        "id": "U02.3",
        "audio_id": "A-U02.3-TR-01",
        "title": "İhram Yasakları ve Ruhaniyeti",
        "summary": "Koku, tıraş, tartışma yasakları ve ihramın getirdiği mahşer şuuru.",
        "details": "Niyet ve telbiye ile birlikte, artık ihramlısınız... İhramlıyken tırnak kesilmez, saça ve sakala dokunulmaz, vücuda koku sürülmez. Ama en büyük yasak... Kimseyle tartışmamak, kalp kırmamak, ve hiçbir canlıyı incitmemektir. Unutmayalım ki ihram... Bize mahşer günündeki kefenimizi hatırlatır."
    },
    {
        "id": "U03.1",
        "audio_id": "A-U03.1-TR-01",
        "title": "Mescid-i Haram'a Giriş",
        "summary": "Harem-i Şerif'e hürmetle, sağ ayakla ve dualarla giriş adabı.",
        "details": "Mekke-i Mükerreme'ye ulaştık... Abdestli ve büyük bir huşû içinde Mescid-i Haram'a yöneliyoruz. Harem-i Şerif'e girerken, sağ ayağımızla adım atıp şu duayı okuyoruz: 'Bismillâh... Salât ve selâm Resûlullah'a olsun. Allah'ım, bana rahmet kapılarını aç.'"
    },
    {
        "id": "U04.1",
        "audio_id": "A-U04.1-TR-01",
        "title": "Kâbe-i Muazzama'yı İlk Görüş",
        "summary": "Beytullah'ı ilk görünce tekbir, tehlil ve duaların kabulü anı.",
        "details": "Ve işte Beytullah... Kâbe-i Muazzama tam karşımızda. Bu an, kulun Rabbine en yakın olduğu... Ve yapılan duaların geri çevrilmediği en mübarek andır. Tekbir ve salavat getirerek duralım... Ve kalbimizden geçen en samimi duaları Rabbimize arz edelim."
    },
    {
        "id": "U05.1",
        "audio_id": "A-U05.1-TR-01",
        "title": "Tavafa Hazırlık ve İztıba",
        "summary": "Erkeklerin sağ omzunu açması (iztıba) ve başlangıç çizgisine yöneliş.",
        "details": "Tavafa başlamadan önce erkekler iztıba yapar... Yani ihramın üst parçasını sağ koltuk altından geçirip, sağ omzu açıkta bırakır ve sol omuz üzerine atar. Şimdi... Hacerülesved hizasındaki yeşil ışıklı başlangıç çizgisine doğru ilerliyoruz."
    },
    {
        "id": "U06.1",
        "audio_id": "A-U06.1-TR-01",
        "title": "Tavafa Başlangıç ve İlk Şavt",
        "summary": "Hacerülesved'i selamlama (istilâm) ve Hatîm dışından tavafa başlama.",
        "details": "Hacerülesved hizasında yüzümüzü Kâbe'ye dönüp, ellerimizi omuz hizasına kaldırarak selamlama yaparız: 'Bismillâhi Allahu Ekber.' Ardından Kâbe'yi solumuza alarak... Hatîm taş duvarının dışından tavafımızın ilk şavtına başlıyoruz."
    },
    {
        "id": "U06.2",
        "audio_id": "A-U06.2-TR-01",
        "title": "Yedi Şavt ve Rükn-i Yemânî",
        "summary": "Tavafın yedi şavtı boyunca zikirler ve Rabbenâ âtinâ duası.",
        "details": "Tavafımız yedi şavttan oluşur... Her şavtta, Rükn-i Yemânî köşesinden Hacerülesved'e doğru yürürken şu duayı okuruz: 'Rabbenâ âtinâ fi'd-dünyâ haseneten, ve fi'l-âhirati haseneten, ve kınâ azâbe'n-nâr.' Zikir, tefekkür ve dualarla yedi şavtımızı tamamlıyoruz."
    },
    {
        "id": "U06.3",
        "audio_id": "A-U06.3-TR-01",
        "title": "Tavafın Tamamlanması",
        "summary": "Son şavtın istilâmı ve açık sağ omzun kapatılması.",
        "details": "Yedinci şavtımız bittiğinde... Hacerülesved hizasında son kez istilâm yaparız. Erkekler açtıkları sağ omuzlarını ihram örtüsüyle kapatırlar... Ve böylece tavaf ibadetimiz tamamlanmış olur."
    },
    {
        "id": "U07.1",
        "audio_id": "A-U07.1-TR-01",
        "title": "Tavaf Namazı",
        "summary": "Makam-ı İbrahim arkasında kılınan iki rekat vacip tavaf namazı.",
        "details": "Tavafın hemen ardından... Makam-ı İbrahim arkasında, eğer kalabalıksa Harem'in uygun bir yerinde iki rekat tavaf namazı kılarız. Birinci rekatta Kâfirûn... İkinci rekatta İhlâs surelerini okumak sünnettir."
    },
    {
        "id": "U07.2",
        "audio_id": "A-U07.2-TR-01",
        "title": "Zemzem İkramı ve Şifa Duası",
        "summary": "Kıbleye yönelerek kana kana zemzem içme ve şifa niyazı.",
        "details": "Namazımızın ardından, doya doya zemzem içiyoruz... Kıbleye yönelip ayakta zemzem içerken şöyle dua ederiz: 'Allah'ım... Senden faydalı ilim, bol rızık, ve her türlü dertten şifa diliyorum.'"
    },
    {
        "id": "U08.1",
        "audio_id": "A-U08.1-TR-01",
        "title": "Safa Tepesine Çıkış ve Sa'y Niyeti",
        "summary": "Safa tepesinde Kâbe'ye dönerek tekbir, tehlil ve sa'y niyeti.",
        "details": "Şimdi Sa'y ibadeti için Safa tepesine çıkıyoruz... Kâbe'ye yönelip ellerimizi semaya açarak tekbir getiririz: 'Allah'ım... Senin rızan için Safa ile Merve arasında umre sa'yini yapmaya niyet ettim.' diyerek Sa'yımıza başlıyoruz."
    },
    {
        "id": "U09.1",
        "audio_id": "A-U09.1-TR-01",
        "title": "Safa'dan Merve'ye Yürüyüş ve Hervele",
        "summary": "Yeşil ışıklar arasında erkeklerin canlı adımları (hervele) ve dualar.",
        "details": "Safa'dan Merve'ye doğru dualarla yürüyoruz... İki yeşil ışık arasına geldiğimizde, erkekler adımlarını sıklaştırarak canlı ve çalımlı yürürler; buna hervele denir. Yeşil ışıklar bitince normal adımlarla Merve tepesine varırız... Bu bir şavt olur."
    },
    {
        "id": "U09.2",
        "audio_id": "A-U09.2-TR-01",
        "title": "Yedi Şavtın Tamamlanması",
        "summary": "Safa ile Merve arasında 7 turun tamamlanması ve şükür duası.",
        "details": "Merve'den Safa'ya dönüş ikinci şavttır... Bu şekilde dört gidiş ve üç dönüş yapılarak, yedinci şavt Merve tepesinde biter. Merve'de ellerimizi açıp, Sa'yımızın kabulü için şükür duamızı yaparız."
    },
    {
        "id": "U10.1",
        "audio_id": "A-U10.1-TR-01",
        "title": "Saç Tıraşı ve İhramdan Çıkış (Tahallül)",
        "summary": "Erkek ve kadınların saç kesimi ile ihram yasaklarının sona ermesi.",
        "details": "Sa'y ibadetimiz tamamlandıktan sonra... Erkekler saçlarını tamamen tıraş eder veya her tarafından eşit şekilde kısaltırlar. Hanımlar ise saçlarının ucundan parmak ucu kadar keserler. Saç kesimiyle birlikte ihramdan çıkılır... Ve tüm ihram yasakları sona erer."
    },
    {
        "id": "U10.2",
        "audio_id": "A-U10.2-TR-01",
        "title": "Umrenin Tamamlanması ve Şükür",
        "summary": "Mebrur bir umre temennisi, ibadetin kabulü ve şükür niyazı.",
        "details": "Elhamdülillâh... Umre ibadetinizi sünnete uygun olarak tamamladınız. Cenâb-ı Hak niyetinizi, tavafınızı, sa'yinizi ve dualarınızı... Mebrur bir Umre olarak dergâh-ı izzetinde kabul eylesin."
    }
]


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def synthesize_text(text: str) -> tuple[str, bytes]:
    payload = {
        "contents": [{"parts": [{"text": text}]}],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {
                "voiceConfig": {
                    "prebuiltVoiceConfig": {
                        "voiceName": "Charon"
                    }
                }
            }
        }
    }
    
    for model in MODELS:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={API_KEY}"
        for attempt in range(2):
            try:
                req = urllib.request.Request(
                    url,
                    data=json.dumps(payload).encode("utf-8"),
                    headers={"Content-Type": "application/json"}
                )
                with urllib.request.urlopen(req, timeout=30) as resp:
                    res = json.loads(resp.read().decode("utf-8"))
                inline = res["candidates"][0]["content"]["parts"][0]["inlineData"]
                mime = inline.get("mimeType", "audio/wav")
                b64 = inline["data"]
                return mime, base64.b64decode(b64)
            except urllib.error.HTTPError as e:
                if e.code == 429:
                    print(f"    [{model}] Rate limit 429, trying next model or retry...")
                    time.sleep(3)
                    break
                else:
                    raise
    raise RuntimeError("All models rate-limited or unavailable.")


def audio_to_m4a(mime: str, raw_data: bytes, m4a_path: Path):
    tmp_wav = Path(f"/tmp/temp_audio_{time.time_ns()}.wav")
    try:
        if mime == "audio/wav":
            tmp_wav.write_bytes(raw_data)
        else:
            with wave.open(str(tmp_wav), "wb") as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2)
                wf.setframerate(24000)
                wf.writeframes(raw_data)
        subprocess.run(
            ["afconvert", str(tmp_wav), str(m4a_path), "-f", "m4af", "-d", "aac"],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    finally:
        if tmp_wav.exists():
            tmp_wav.unlink()


def main():
    print(f"Generating {len(ITEMS)} authentic Umrah audio narrations with Gemini TTS (Charon voice, pure spoken guidance)...")
    
    # 1. Load catalog
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    steps_by_id = {s["id"]: s for s in catalog["steps"]}
    prayers_by_id = {p["id"]: p for p in catalog.get("prayerRecords", [])}
    audio_records_by_id = {a["id"]: a for a in catalog["audioRecords"]}

    # 2. Load CSV
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
        csv_rows = list(csv.DictReader(f))
    csv_by_id = {r["ses_kimligi"]: r for r in csv_rows}

    for item in ITEMS:
        item_id = item["id"]
        audio_id = item["audio_id"]
        out_m4a = AUDIO_DIR / f"{audio_id}.m4a"
        
        # Determine script (ONLY the pure spoken guidance without prepending summary!)
        if "details" in item:
            script = item["details"]
            step = steps_by_id[item_id]
            step["title"] = item["title"]
            step["summary"] = item["summary"]
            step["details"] = item["details"]
        else:
            script = item["meaningTr"]
            prayer = prayers_by_id[item_id]
            prayer["meaningTr"] = item["meaningTr"]

        script_hash = digest(script.encode("utf-8"))
        
        print(f"Synthesizing {audio_id} ({item['title']})...")
        mime, raw_bytes = synthesize_text(script)
        audio_to_m4a(mime, raw_bytes, out_m4a)
        m4a_bytes = out_m4a.read_bytes()
        m4a_hash = digest(m4a_bytes)
        print(f"  -> {audio_id}.m4a ({len(m4a_bytes)} bytes, SHA-256: {m4a_hash[:12]}...)")
        
        # Pause 3.5 seconds to avoid tripping burst rate limits
        time.sleep(3.5)

        # Update catalog audio record
        audio_rec = audio_records_by_id[audio_id]
        audio_rec["assetSha256"] = m4a_hash
        audio_rec["voiceStyle"] = "Charon"
        audio_rec["origin"] = "gemini-tts"

        # Update receipt
        receipt_file = MAKBUZ_DIR / f"{audio_id}.json"
        if receipt_file.exists():
            receipt = json.loads(receipt_file.read_text(encoding="utf-8"))
            receipt["script"] = script
            receipt["scriptSha256"] = script_hash
            receipt["model"] = "google/gemini-tts"
            receipt["speakerId"] = "Charon"
            receipt["speakerType"] = "Google Gemini TTS Charon voice"
            receipt["files"]["m4a"]["sha256"] = m4a_hash
            receipt_file.write_text(json.dumps(receipt, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

        # Update CSV row
        if audio_id in csv_by_id:
            row = csv_by_id[audio_id]
            row["metin_sha256"] = script_hash
            row["m4a_sha256"] = m4a_hash
            row["ses"] = "Charon"

    # 3. Write back catalog
    CATALOG_PATH.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    # 4. Write back CSV
    with CSV_PATH.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=csv_rows[0].keys())
        writer.writeheader()
        writer.writerows(csv_rows)

    print("\nSUCCESS: All 19 Umrah narrations generated cleanly with Charon voice and natural spoken script!")


if __name__ == "__main__":
    main()
