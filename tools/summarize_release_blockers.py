#!/usr/bin/env python3
"""Group the current fail-closed preflight findings by actual dependency."""

import collections
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INPUT = ROOT / 'build/release-preflight.json'
OUTPUT = ROOT / 'docs/qa/2026-10-09-release-blockers.json'
PERSON = 'gerçek kişi/hesap onayı gerekir'
DATA = 'araştırma/veriyle çözülebilir'

RULES = {
    'steps': (PERSON, 'assets/content/*_inventory.v1.json',
              'Dinî uzman 53 metni ve kaynakları inceleyip gerçek tarihli karar verir.'),
    'missing_step_narration': (PERSON, 'assets/content/*_inventory.v1.json',
                               'Onaylı metne bağlı izinli anlatım dosyası ve hak belgesi eklenir.'),
    'hajj_profile_review': (PERSON, 'assets/content/hac_inventory.v1.json',
                            'Uzman üç profil uygulanabilirliğini her Hac adımında karara bağlar.'),
    'prayerRecords': (PERSON, 'assets/content/umre_inventory.v1.json',
                      'Arapça, anlam, okunuş, kaynak ve hak uzman/dil incelemesinden geçer.'),
    'audioRecords': (PERSON, 'assets/content/umre_inventory.v1.json',
                     'Metin sürümü, gerçek kayıt, insan/sağlayıcı hakkı ve işitsel kabul eşleşir.'),
}

EVIDENCE = {
    'religious_expert_review': (PERSON, 'docs/content-review/', 'Gerçek uzman imzalı 53 adım/dua/profil incelemesi.'),
    'human_audio_rights': (PERSON, 'docs/content-review/2026-10-09-kayit-metni-calisma.csv', 'Kayıt sahibi ve dağıtım izni ile doğrulanmış sesler.'),
    'offline_map_license': (DATA, 'lib/offline_map_adapter.dart', 'İzinli veri/tile kaynağı, görünür atıf ve gerçek offline paket.'),
    'verified_travel_safety_language_data': (DATA, 'docs/content-review/dil-kartlari-taslak.csv', 'Kaynaklı koordinat/rota/iletişim/dil ve saha/dil incelemesi.'),
    'live_supabase_acceptance': (PERSON, 'supabase/', 'Ayrı gerçek test projesi, iki hesap/iki kafile ve Auth/RLS/Realtime kabulü.'),
    'push_location_acceptance': (PERSON, 'supabase/functions/', 'Test cihaz allowlist, gerçek APNs/FCM ve GPS/iptal/saklama kabulü.'),
    'physical_android_acceptance': (PERSON, 'docs/qa/MOBIL_TEST.md', 'Fiziksel Android matrisi; bu görevin dışında.'),
    'physical_iphone_acceptance': (PERSON, 'docs/qa/MOBIL_TEST.md', 'Fiziksel iPhone matrisi; bu görevin dışında.'),
    'ios_distribution_signing': (PERSON, 'ios/', 'Apple dağıtım hesabı/imzası ve archive/TestFlight kabulü.'),
    'privacy_store_declarations': (PERSON, 'docs/16-gizlilik-ve-magaza-beyan-taslagi.md', 'Veri sorumlusu/saklama/destek/URL kararı ve gerçek mağaza beyanı.'),
    'signed_android_artifact': (PERSON, 'android/', 'Önceki uygulamayla uyumlu gerçek upload key ve imzalı AAB.'),
}


def main():
    report = json.loads(INPUT.read_text())
    groups = collections.defaultdict(list)
    for blocker in report['blockers']:
        key = blocker['id'] if blocker['type'] == 'external_evidence' else blocker['type']
        groups[key].append(blocker['id'])
    rows = []
    for key, ids in sorted(groups.items()):
        category, file, acceptance = (EVIDENCE[key] if key in EVIDENCE
                                       else RULES[key])
        rows.append({'key': key, 'count': len(ids), 'category': category,
                     'file': file, 'acceptance': acceptance, 'ids': ids})
    result = {'headAtAudit': 'fe32ebb438d861c4867f7e784c31f32c0e8e6689',
              'preflightCount': len(report['blockers']),
              'note': 'Eksik girdi ve kabul kanıtı; uygulama hata sayısı değil. Fiziksel iki kabul bu görevin dışındadır.',
              'categoryCounts': {
                  category: sum(row['count'] for row in rows
                                if row['category'] == category)
                  for category in ('kodla çözülebilir', DATA, PERSON)
              },
              'groups': rows}
    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'count': result['preflightCount'],
                      'groups': len(rows),
                      'categoryCounts': result['categoryCounts']}, ensure_ascii=False))


if __name__ == '__main__':
    main()
