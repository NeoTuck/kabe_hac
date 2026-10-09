#!/usr/bin/env python3
"""Bind the reviewed inventory to bundled, explicitly draft synthetic audio.

The receipt and current text must agree before any bundled catalog is changed.
Use --check in CI to detect later edits to either the catalog or audio files.
"""

import argparse
import hashlib
import json
from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "release-inputs/local-review-audio-v2"
DESTINATION = ROOT / "assets/audio/draft-v2"
CATALOGS = [
    ROOT / "assets/content/umre_inventory.v1.json",
    ROOT / "assets/content/hac_inventory.v1.json",
]


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def expected_script(record: dict, target: dict) -> str:
    if record["kind"] == "turkishNarration":
        return target["summary"] + "\n" + target["details"]
    if record["kind"] == "turkishMeaning":
        return target["meaningTr"]
    raise ValueError(f"Unexpected recording kind: {record['kind']}")


def prepare() -> tuple[list[dict], list[tuple[Path, Path]]]:
    index = load(SOURCE / "review-index.json")
    if index.get("reviewOnly") is not True or len(index["records"]) != 54:
        raise ValueError("Expected exactly 54 review-only recordings")
    catalogs = [load(path) for path in CATALOGS]
    targets = {
        item["id"]: (catalog, item, kind)
        for catalog in catalogs
        for kind, key in (("step", "steps"), ("prayer", "prayerRecords"))
        for item in catalog[key]
    }
    copies = []
    seen = set()
    for record in index["records"]:
        audio_id = record["audioId"]
        if audio_id in seen:
            raise ValueError(f"Duplicate recording: {audio_id}")
        seen.add(audio_id)
        catalog, target, kind = targets[record["textId"]]
        if target["textVersion"] != record["textVersion"]:
            raise ValueError(f"Text version mismatch: {audio_id}")
        script = expected_script(record, target)
        if script != record["script"] or digest(script.encode()) != record["scriptSha256"]:
            raise ValueError(f"Script mismatch: {audio_id}")
        receipt_file = SOURCE / "receipts" / f"{audio_id}.json"
        receipt_bytes = receipt_file.read_bytes()
        receipt = json.loads(receipt_bytes)
        if digest(receipt_bytes) != record["receiptSha256"]:
            raise ValueError(f"Receipt hash mismatch: {audio_id}")
        if any(receipt[key] != record[key] for key in
               ("audioId", "textId", "textVersion", "scriptSha256", "file")):
            raise ValueError(f"Receipt identity mismatch: {audio_id}")
        if (receipt["reviewOnly"] is not True or
                receipt["declaredOrigin"] != "synthetic" or
                receipt["distributionRights"] != "pending-training-corpus-and-content-review"):
            raise ValueError(f"Review status mismatch: {audio_id}")
        source = SOURCE / record["file"]
        audio_bytes = source.read_bytes()
        if len(audio_bytes) != receipt["sizeBytes"] or digest(audio_bytes) != receipt["sha256"]:
            raise ValueError(f"Audio hash mismatch: {audio_id}")
        destination = DESTINATION / f"{audio_id}.m4a"
        copies.append((source, destination))
        entry = {
            "id": audio_id,
            "status": "draft",
            "kind": record["kind"],
            "textId": record["textId"],
            "textVersion": record["textVersion"],
            "asset": destination.relative_to(ROOT).as_posix(),
            "assetSha256": receipt["sha256"],
            "origin": "synthetic",
            "reviewOnly": True,
        }
        existing = next((item for item in catalog["audioRecords"] if item["id"] == audio_id), None)
        if existing is None:
            catalog["audioRecords"].append(entry)
        else:
            existing.update(entry)
        if kind == "step":
            linked = target.setdefault("audioIds", [])
            if audio_id not in linked and target.get("audioId") != audio_id:
                linked.append(audio_id)
        else:
            linked = target.setdefault("audioIds", [])
            if audio_id not in linked and target.get("audioId") != audio_id:
                linked.append(audio_id)
    if len(seen) != 54 or len([r for r in index["records"] if r["kind"] == "turkishNarration"]) != 53:
        raise ValueError("Recording coverage mismatch")
    for catalog in catalogs:
        catalog["contentVersion"] = "inventory-2026-10-09-draft2-audio"
    return catalogs, copies


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    catalogs, copies = prepare()
    for (source, destination) in copies:
        if args.check:
            if not destination.is_file() or digest(destination.read_bytes()) != digest(source.read_bytes()):
                raise ValueError(f"Bundled recording differs: {destination}")
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
    for path, catalog in zip(CATALOGS, catalogs):
        serialized = json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
        if args.check:
            if path.read_text(encoding="utf-8") != serialized:
                raise ValueError(f"Bundled catalog differs: {path}")
        else:
            path.write_text(serialized, encoding="utf-8")
    print("PASS: 53 narration files and one Turkish meaning, text versions and SHA-256")


if __name__ == "__main__":
    main()
