#!/usr/bin/env python3
"""Generate authentic Umrah guide audio using Google Gemini TTS."""

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

API_KEY = os.environ.get("GEMINI_API_KEY", "AIzaSyBu-TCnoQ-cXlJCr201wtKKWkedOvWfg9k")

MODELS = [
    "gemini-3.8-flash-tts",
    "gemini-3.8-flash-lite-tts",
    "gemini-3.1-flash-tts-preview",
    "gemini-2.5-flash-preview-tts",
]

ITEMS = [
    {
        "id": "U01.1",
        "audio_id": "A-U01.1-TR-01",
        "title": "Umre Yolculuğuna Niyet ve Başlangıç",
        "summary": "Kutlu Umre seferine niyet ve samimi bir tevbe ile başlıyoruz.",
        "details": "Değerli kardeşim, Allah'ın evine, Kutlu Beldeye yapacağın bu mübarek Umre seferi şimdiden mübarek olsun. Bu yolculuk sadece bedenen Mekke'ye gitmek değil; kalben günahlardan arınma ve Rahman'ın huzuruna çıkma yolculuğudur. Yola çıkmadan önce samimi bir tevbe edelim ve tüm sevdiklerimizle helalleşelim."
    },
    {
        "id": "U01.2",
        "audio_id": "A-U01.2-TR-01",
        "title": "Yolculuk ve Valiz Hazırlığı",
        "summary": "İhram kıyafeti, kokusuz temizlik ürünleri ve ibadet hazırlığı.",
        "details": "Umre hazırlığında yanımıza dikişsiz iki parça ihram örtüsü, ihram kemeri, tavafta ayağımızı vurmayacak rahat terlik veya sandalet alıyoruz. İhramlıyken koku yasak olduğu için kokusuz sabun veya şampuan tercih edilmelidir. Manevi hazırlık olarak da kalbimizi dünyalık meşguliyetlerden arındırıyoruz."
    },
    {
        "id": "U02.1",
        "audio_id": "A-U02.1-TR-01",
        "title": "Mikat Sınırı ve İhram Hazırlığı",
        "summary": "Mikat sınırında ihram hazırlığı ve dikişsiz örtülere bürünme.",
        "details": "Mikat, Peygamber Efendimiz'in belirlediği ve ihramsız geçilmeyecek kutsal sınırdır. Uçakta veya Mikat mescidinde gusül veya abdestimizi alıp erkekler dikişsiz ihram örtüsüne bürünür. Hanım kardeşlerimiz ise kendi mutad tesettür kıyafetleriyle ihrama girerler."
    },
    {
        "id": "U02.2",
        "audio_id": "A-U02.2-TR-01",
        "title": "İhram Namazı, Niyet ve Telbiye",
        "summary": "İki rekat ihram namazı, kalpten umre niyeti ve telbiyeye başlama.",
        "details": "İhrama büründükten sonra kerahet vakti değilse iki rekat ihram namazı kılarız. Ardından kalben niyet ederiz: Allah'ım, senin rızan için Umre yapmaya niyet ettim, onu bana kolaylaştır ve benden kabul eyle. Niyetin hemen ardından telbiye getirmeye başlarız."
    },
    {
        "id": "P-U02.2-01",
        "audio_id": "A-P-U02.2-ANLAM-01",
        "title": "Telbiye Zikri ve Türkçe Anlamı",
        "meaningTr": "Lebbeyk Allahümme lebbeyk. Lebbeyke lâ şerîke leke lebbeyk. İnnel-hamde ven-ni‘mete leke vel-mülk, lâ şerîke lek. Yani: Buyur Allah'ım buyur! Davetine icabet ettim. Senin hiçbir ortağın yoktur. Hamd ve nimet sana aittir, mülk de senindir. Senin hiçbir ortağın yoktur."
    },
    {
        "id": "U02.3",
        "audio_id": "A-U02.3-TR-01",
        "title": "İhram Yasakları ve Ruhaniyeti",
        "summary": "Koku, tıraş, tartışma yasakları ve ihramın getirdiği mahşer şuuru.",
        "details": "Niyet ve telbiye ile artık ihramlısınız. İhramlıyken saç, sakal, tırnak kesilmez; vücuda koku sürülmez. En mühimi ise kimseyle tartışmamak, gönül kırmamak ve hiçbir canlıyı incitmemektir. İhram bize mahşer günündeki kefenimizi ve eşitliği hatırlatır."
    },
    {
        "id": "U03.1",
        "audio_id": "A-U03.1-TR-01",
        "title": "Mescid-i Haram'a Giriş",
        "summary": "Harem-i Şerif'e hürmetle, sağ ayakla ve dualarla giriş adabı.",
        "details": "Mekke-i Mükerreme'ye ulaştık. Otelimize yerleşip dinlendikten sonra abdestli ve huşû içinde Mescid-i Haram'a yöneliyoruz. Harem-i Şerif'e mümkünse Babüsselâm kapısından, sağ ayağımızla ve Bismillâh, salât ve selâm Resûlullah'a olsun, Allah'ım bana rahmet kapılarını aç duasıyla giriyoruz."
    },
    {
        "id": "U04.1",
        "audio_id": "A-U04.1-TR-01",
        "title": "Kâbe-i Muazzama'yı İlk Görüş",
        "summary": "Beytullah'ı ilk görünce tekbir, tehlil ve duaların kabulü anı.",
        "details": "Ve işte Beytullah... Kâbe-i Muazzama'yı ilk gördüğümüz bu an, duaların geri çevrilmediği en mübarek andır. Tekbir, tehlil ve salavat getirerek duruyoruz. Bu kutlu anda kalbimizden geçen en samimi dünya ve ahiret dualarımızı Rabbimize arz ediyoruz."
    },
    {
        "id": "U05.1",
        "audio_id": "A-U05.1-TR-01",
        "title": "Tavafa Hazırlık ve İztıba",
        "summary": "Erkeklerin sağ omzunu açması (iztıba) ve başlangıç çizgisine yöneliş.",
        "details": "Tavafa başlamadan önce erkekler iztıba yapar; yani ihramın üst parçasını sağ koltuk altından geçirip sağ omuzu açıkta bırakır, sol omuz üzerine atar. Ardından Hacerülesved hizasındaki yeşil ışıklı tavaf başlangıç çizgisine yöneliyoruz."
    },
    {
        "id": "U06.1",
        "audio_id": "A-U06.1-TR-01",
        "title": "Tavafa Başlangıç ve İlk Şavt",
        "summary": "Hacerülesved'i selamlama (istilâm) ve Hatîm dışından tavafa başlama.",
        "details": "Hacerülesved hizasında yüzümüzü Kâbe'ye dönüp ellerimizi omuz hizasına kaldırarak Bismillâhi Allahu Ekber diyerek Hacerülesved'i selamlarız. Ardından Kâbe'yi solumuza alarak, Hatîm taş duvarının dışından tavafın ilk şavtına başlıyoruz."
    },
    {
        "id": "U06.2",
        "audio_id": "A-U06.2-TR-01",
        "title": "Yedi Şavt ve Rükn-i Yemânî",
        "summary": "Tavafın yedi şavtı boyunca zikirler ve Rabbenâ âtinâ duası.",
        "details": "Tavaf 7 şavttan oluşur. Her dönüşte Rükn-i Yemânî köşesinden Hacerülesved'e doğru Rabbenâ âtinâ fi'd-dünyâ haseneten ve fi'l-âhirati haseneten ve kınâ azâbe'n-nâr duasını okumak sünnettir. Huşû içinde zikir, dua ve tefekkür ile 7 şavtı tamamlıyoruz."
    },
    {
        "id": "U06.3",
        "audio_id": "A-U06.3-TR-01",
        "title": "Tavafın Tamamlanması",
        "summary": "Son şavtın istilâmı ve açık sağ omzun kapatılması.",
        "details": "Yedinci şavt bittiğinde Hacerülesved hizasında son kez istilâm yaparız. Erkekler açtıkları sağ omuzlarını ihram örtüsüyle kapatırlar. Böylece tavaf tamamlanmış olur."
    },
    {
        "id": "U07.1",
        "audio_id": "A-U07.1-TR-01",
        "title": "Tavaf Namazı",
        "summary": "Makam-ı İbrahim arkasında kılınan iki rekat vacip tavaf namazı.",
        "details": "Tavafın hemen ardından Makam-ı İbrahim arkasında, kalabalıksa Harem'in uygun bir yerinde iki rekat tavaf namazı kılmak vaciptir. Birinci rekatta Kâfirûn, ikinci rekatta İhlâs surelerini okumak sünnettir."
    },
    {
        "id": "U07.2",
        "audio_id": "A-U07.2-TR-01",
        "title": "Zemzem İkramı ve Şifa Duası",
        "summary": "Kıbleye yönelerek kana kana zemzem içme ve şifa niyazı.",
        "details": "Namazın ardından kana kana zemzem içiyoruz. Kıbleye yönelerek ayakta zemzem içerken Allah'ım, senden faydalı ilim, bol rızık ve her türlü dertten şifa diliyorum diye dua edilir."
    },
    {
        "id": "U08.1",
        "audio_id": "A-U08.1-TR-01",
        "title": "Safa Tepesine Çıkış ve Sa'y Niyeti",
        "summary": "Safa tepesinde Kâbe'ye dönerek tekbir, tehlil ve sa'y niyeti.",
        "details": "Şimdi Sa'y ibadeti için Safa tepesine çıkıyoruz. Kâbe'ye yönelip ellerimizi kaldırarak tekbir ve tehlil getiriyoruz: Allah'ım, senin rızan için Safa ile Merve arasında umre sa'yi yapmaya niyet ettim diyerek niyetimizi ediyoruz."
    },
    {
        "id": "U09.1",
        "audio_id": "A-U09.1-TR-01",
        "title": "Safa'dan Merve'ye Yürüyüş ve Hervele",
        "summary": "Yeşil ışıklar arasında erkeklerin canlı adımları (hervele) ve dualar.",
        "details": "Safa'dan Merve'ye doğru dualarla yürüyoruz. İki yeşil ışık arasına geldiğimizde erkekler adımlarını sıklaştırarak canlı ve çalımlı yürürler; buna hervele denir. Yeşil ışıklar bitince normal adımlarla Merve tepesine varırız. Bu bir şavt olur."
    },
    {
        "id": "U09.2",
        "audio_id": "A-U09.2-TR-01",
        "title": "Yedi Şavtın Tamamlanması",
        "summary": "Safa ile Merve arasında 7 turun tamamlanması ve şükür duası.",
        "details": "Merve'den Safa'ya dönüş ikinci şavttır. Bu şekilde 4 gidiş ve 3 dönüş yapılarak 7. şavt Merve'de biter. Merve tepesinde ellerimizi semaya açıp şükür duamızı yaparız."
    },
    {
        "id": "U10.1",
        "audio_id": "A-U10.1-TR-01",
        "title": "Saç Tıraşı ve İhramdan Çıkış (Tahallül)",
        "summary": "Erkek ve kadınların saç kesimi ile ihram yasaklarının sona ermesi.",
        "details": "Sa'y bittikten sonra erkekler saçlarının tamamını tıraş eder veya eşit şekilde parmak ucu kadar kısaltırlar. Hanımlar ise saçlarının ucundan bir parmak ucu kadar keserler. Saç kesimiyle birlikte ihramdan çıkılır ve tüm ihram yasakları sona erer."
    },
    {
        "id": "U10.2",
        "audio_id": "A-U10.2-TR-01",
        "title": "Umrenin Tamamlanması ve Şükür",
        "summary": "Mebrur bir umre temennisi, ibadetin kabulü ve şükür niyazı.",
        "details": "Elhamdülillâh, Umre ibadetinizi hakkıyla ve sünnete uygun olarak tamamladınız. Cenâb-ı Hak niyetinizi, tavafınızı, sa'yinizi ve dualarınızı Mebrur bir Umre olarak kabul eylesin."
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
                        "voiceName": "Fenrir"
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
    print(f"Generating {len(ITEMS)} authentic Umrah audio narrations with Gemini TTS...")
    
    # 1. Load catalog
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    steps_by_id = {s["id"]: s for s in catalog["steps"]}
    prayers_by_id = {p["id"]: p for p in catalog.get("prayerRecords", [])}
    audio_records_by_id = {a["id"]: a for a in catalog["audioRecords"]}

    # 2. Load CSV
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
        csv_rows = list(csv.DictReader(f))
    csv_by_id = {r["ses_kimligi"]: r for r in csv_rows}

    # Tracking generated status file
    status_file = ROOT / "build/gemini_audio_status.json"
    status = {}
    if status_file.exists():
        try:
            status = json.loads(status_file.read_text())
        except Exception:
            status = {}

    for item in ITEMS:
        item_id = item["id"]
        audio_id = item["audio_id"]
        out_m4a = AUDIO_DIR / f"{audio_id}.m4a"
        
        # Determine script
        if "summary" in item:
            script = item["summary"] + "\n" + item["details"]
            step = steps_by_id[item_id]
            step["title"] = item["title"]
            step["summary"] = item["summary"]
            step["details"] = item["details"]
        else:
            script = item["meaningTr"]
            prayer = prayers_by_id[item_id]
            prayer["meaningTr"] = item["meaningTr"]

        script_hash = digest(script.encode("utf-8"))
        
        # If already successfully synthesized this script, reuse
        if status.get(audio_id) == script_hash and out_m4a.exists():
            print(f"Reusing already generated {audio_id} ({item['title']})...")
            m4a_bytes = out_m4a.read_bytes()
            m4a_hash = digest(m4a_bytes)
        else:
            print(f"Synthesizing {audio_id} ({item['title']})...")
            mime, raw_bytes = synthesize_text(script)
            audio_to_m4a(mime, raw_bytes, out_m4a)
            m4a_bytes = out_m4a.read_bytes()
            m4a_hash = digest(m4a_bytes)
            status[audio_id] = script_hash
            status_file.parent.mkdir(parents=True, exist_ok=True)
            status_file.write_text(json.dumps(status, indent=2))
            print(f"  -> {audio_id}.m4a ({len(m4a_bytes)} bytes, SHA-256: {m4a_hash[:12]}...)")
            time.sleep(2)

        # Update catalog audio record
        audio_rec = audio_records_by_id[audio_id]
        audio_rec["assetSha256"] = m4a_hash
        audio_rec["voiceStyle"] = "Fenrir"
        audio_rec["origin"] = "gemini-tts"

        # Update receipt
        receipt_file = MAKBUZ_DIR / f"{audio_id}.json"
        if receipt_file.exists():
            receipt = json.loads(receipt_file.read_text(encoding="utf-8"))
            receipt["script"] = script
            receipt["scriptSha256"] = script_hash
            receipt["model"] = "google/gemini-tts"
            receipt["speakerId"] = "Fenrir"
            receipt["speakerType"] = "Google Gemini TTS Fenrir voice"
            receipt["files"]["m4a"]["sha256"] = m4a_hash
            receipt_file.write_text(json.dumps(receipt, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

        # Update CSV row
        if audio_id in csv_by_id:
            row = csv_by_id[audio_id]
            row["metin_sha256"] = script_hash
            row["m4a_sha256"] = m4a_hash
            row["ses"] = "Fenrir"

    # 3. Write back catalog
    CATALOG_PATH.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    # 4. Write back CSV
    with CSV_PATH.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=csv_rows[0].keys())
        writer.writeheader()
        writer.writerows(csv_rows)

    print("\nSUCCESS: All 19 Umrah narrations generated, encoded, hashed and synchronized!")


if __name__ == "__main__":
    main()
