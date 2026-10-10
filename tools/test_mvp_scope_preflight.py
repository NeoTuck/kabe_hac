"""Regression checks for the separate, fail-closed MVP scope gate."""
import json
import pathlib
import tempfile
import unittest

from release_preflight import ROOT, SCOPE_PATH, audit_mvp_scope


class MvpScopeAuditTests(unittest.TestCase):
    def test_current_scope_blocks_draft_content_and_review_only_audio(self):
        blockers = audit_mvp_scope(ROOT, SCOPE_PATH, ROOT / 'release-inputs')
        kinds = {block['type'] for block in blockers}
        self.assertIn('scope_unapproved_content', kinds)
        self.assertIn('review_only_audio', kinds)
        self.assertIn('live_service_not_accepted', kinds)

    def test_omitting_visible_step_does_not_reduce_release_scope(self):
        scope = json.loads(SCOPE_PATH.read_text())
        scope['visibleSteps'].pop()
        with tempfile.TemporaryDirectory() as temp:
            path = pathlib.Path(temp) / 'scope.json'
            path.write_text(json.dumps(scope))
            blockers = audit_mvp_scope(ROOT, path, ROOT / 'release-inputs')
        self.assertIn('scope_ids_mismatch', {b['type'] for b in blockers})

    def test_omitting_bundled_audio_does_not_clear_rights_gate(self):
        scope = json.loads(SCOPE_PATH.read_text())
        scope['audioRecords'].pop()
        with tempfile.TemporaryDirectory() as temp:
            path = pathlib.Path(temp) / 'scope.json'
            path.write_text(json.dumps(scope))
            blockers = audit_mvp_scope(ROOT, path, ROOT / 'release-inputs')
        self.assertIn('scope_ids_mismatch', {b['type'] for b in blockers})
        self.assertIn('review_only_audio', {b['type'] for b in blockers})

    def test_missing_manifest_is_blocked(self):
        blockers = audit_mvp_scope(ROOT, ROOT / 'missing-scope.json',
                                   ROOT / 'release-inputs')
        self.assertEqual(blockers[0]['type'], 'scope_manifest_invalid')
