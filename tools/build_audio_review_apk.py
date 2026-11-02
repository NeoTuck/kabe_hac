#!/usr/bin/env python3
"""Build an isolated, clearly labeled APK for listening to draft male audio."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parent.parent
CATALOGS = (
    "assets/content/umre_inventory.v1.json",
    "assets/content/hac_inventory.v1.json",
)
AUDIO_PREFIX = "assets/audio/review-male-v1/"
APK_PREFIX = "assets/flutter_assets/"


def audit_review_apk(apk: Path) -> None:
    expected_audio = {}
    for catalog_path in CATALOGS:
        catalog = json.loads((ROOT / catalog_path).read_text())
        if any(item["status"] == "approved" for item in catalog["steps"]):
            raise RuntimeError("Review APK source contains approved steps")
        for record in catalog["audioRecords"]:
            asset = record.get("asset")
            if not asset or not asset.startswith(AUDIO_PREFIX):
                continue
            if record["status"] != "draft" or record.get("reviewOnly") is not True:
                raise RuntimeError(f"Review state missing for {record['id']}")
            expected_audio[asset] = record["assetSha256"]
    if len(expected_audio) != 54:
        raise RuntimeError(f"Expected 54 review recordings; got {len(expected_audio)}")

    with zipfile.ZipFile(apk) as archive:
        names = set(archive.namelist())
        found_audio = {
            name.removeprefix(APK_PREFIX)
            for name in names
            if name.startswith(APK_PREFIX + AUDIO_PREFIX) and name.endswith(".m4a")
        }
        if found_audio != set(expected_audio):
            raise RuntimeError("APK review audio set differs from catalog")
        for catalog_path in CATALOGS:
            name = APK_PREFIX + catalog_path
            if name not in names or archive.read(name) != (ROOT / catalog_path).read_bytes():
                raise RuntimeError(f"APK catalog missing or changed: {catalog_path}")
        for asset, expected_hash in expected_audio.items():
            actual_hash = hashlib.sha256(archive.read(APK_PREFIX + asset)).hexdigest()
            if actual_hash != expected_hash:
                raise RuntimeError(f"APK audio hash mismatch: {asset}")
        if any("/audio/draft-v2/" in name for name in names):
            raise RuntimeError("Old draft audio slipped into review APK")


def build(flutter: str, output: Path) -> None:
    subprocess.run(
        ["python3", str(ROOT / "tools/prepare_male_review_audio.py"), "--check"],
        check=True,
        cwd=ROOT,
    )
    with tempfile.TemporaryDirectory(prefix="kabe-audio-review-") as temporary:
        work = Path(temporary)
        for name in ("android", "assets", "lib", "tools"):
            shutil.copytree(
                ROOT / name,
                work / name,
                ignore=shutil.ignore_patterns(
                    ".gradle", ".kotlin", "build", "__pycache__",
                    "GeneratedPluginRegistrant.java", "key.properties",
                ),
            )
        for name in ("pubspec.yaml", "pubspec.lock", ".metadata"):
            source = ROOT / name
            if source.exists():
                shutil.copy2(source, work / name)

        pubspec = work / "pubspec.yaml"
        text = pubspec.read_text()
        anchor = "    - assets/content/package_defaults.v1.json\n"
        if text.count(anchor) != 1:
            raise RuntimeError("Cannot locate Flutter asset list")
        extra = "".join(f"    - {name}\n" for name in CATALOGS)
        extra += f"    - {AUDIO_PREFIX}\n"
        integration_test = "  integration_test:\n    sdk: flutter\n"
        if text.count(integration_test) != 1:
            raise RuntimeError("Cannot locate isolated integration test dependency")
        pubspec.write_text(
            text.replace(anchor, anchor + extra).replace(integration_test, "")
        )

        manifest = work / "android/app/src/main/AndroidManifest.xml"
        text = manifest.read_text()
        label = 'android:label="Hac ve Umre Sesli Rehber"'
        if text.count(label) != 1:
            raise RuntimeError("Cannot locate Android app label")
        manifest.write_text(text.replace(label, 'android:label="Hac Umre Ses İncelemesi"'))

        gradle = work / "android/app/build.gradle.kts"
        text = gradle.read_text()
        anchor = "        release {\n            signingConfig"
        if text.count(anchor) != 1:
            raise RuntimeError("Cannot locate Android release build type")
        gradle.write_text(
            text.replace(anchor, '        release {\n            applicationIdSuffix = ".review"\n            signingConfig')
        )

        environment = os.environ.copy()
        environment["KABE_TECHNICAL_PILOT"] = "true"
        subprocess.run([flutter, "pub", "get", "--offline"], check=True, cwd=work, env=environment)
        registrant = work / "android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"
        if registrant.exists() and "IntegrationTestPlugin" in registrant.read_text():
            raise RuntimeError("Test plugin remained in isolated release registrant")
        subprocess.run(
            [
                flutter, "build", "apk", "--release", "--no-pub",
                "--dart-define=KABE_AUDIO_REVIEW_BUILD=true",
            ],
            check=True,
            cwd=work,
            env=environment,
        )
        apk = work / "build/app/outputs/flutter-apk/app-release.apk"
        audit_review_apk(apk)
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(apk, output)
    print(f"PASS review APK: {output}")
    print(f"SHA-256 {hashlib.sha256(output.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter", default=shutil.which("flutter"))
    parser.add_argument("--output", type=Path, default=ROOT / "build/review/Kabe_Hac_Ses_Inceleme.apk")
    args = parser.parse_args()
    if not args.flutter:
        parser.error("Pass --flutter with the installed Flutter executable")
    build(args.flutter, args.output.resolve())
