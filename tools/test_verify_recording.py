import hashlib
import math
import pathlib
import struct
import subprocess
import tempfile
import unittest
import wave

from verify_recording import binding, verify

ROOT = pathlib.Path(__file__).resolve().parent.parent


class RecordingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)
        data = (ROOT / 'assets/audio/teknik_demo.m4a').read_bytes()
        (self.root / 'fixture.m4a').write_bytes(data)
        self.catalog = {'steps': [{'id': 'T', 'textVersion': 'v1'}],
                        'audioRecords': [{'id': 'A', 'textId': 'T', 'textVersion': 'v1'}]}
        self.receipt = {'audioId': 'A', 'textId': 'T', 'textVersion': 'v1', 'file': 'fixture.m4a',
                        'sha256': hashlib.sha256(data).hexdigest(), 'sizeBytes': len(data),
                        'durationSeconds': 30, 'durationToleranceSeconds': 0.05, 'declaredOrigin': 'synthetic'}

    def test_binding_hash_version_and_path_rejected(self):
        for changes in ({'sha256': '0' * 64}, {'textVersion': 'v2'}, {'file': '../fixture.m4a'},
                        {'sizeBytes': 1}, {'declaredOrigin': 'unknown'}, {'durationSeconds': float('nan')}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                binding(self.catalog, {**self.receipt, **changes}, self.root)

    def test_symlink_parent_and_duplicate_text_rejected(self):
        (self.root / 'linked').symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(ValueError):
            binding(self.catalog, {**self.receipt, 'file': 'linked/fixture.m4a'}, self.root)
        self.catalog['steps'].append({'id': 'T', 'textVersion': 'v1'})
        with self.assertRaises(ValueError):
            binding(self.catalog, self.receipt, self.root)

    def test_decode_does_not_grant_human_or_rights_acceptance(self):
        result = verify(self.catalog, self.receipt, self.root)
        self.assertEqual(result['technicalIntegrity'], 'passed')
        self.assertFalse(result['humanVoiceVerified'])
        self.assertFalse(result['rightsVerified'])
        self.assertEqual(result['declaredOrigin'], 'synthetic')

    def test_truncated_duration_and_corrupted_file_rejected(self):
        with self.assertRaises(ValueError):
            verify(self.catalog, {**self.receipt, 'durationSeconds': 60}, self.root)
        data = b'not a recording'
        (self.root / 'fixture.m4a').write_bytes(data)
        import subprocess
        with self.assertRaises(subprocess.SubprocessError):
            verify(self.catalog, {**self.receipt, 'sha256': hashlib.sha256(data).hexdigest(),
                                  'sizeBytes': len(data)}, self.root)

    def test_boundary_padding_is_checked_when_declared(self):
        wav = self.root / 'padded.wav'
        with wave.open(str(wav), 'wb') as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(22050)
            samples = [0] * 5513 + [int(6000 * math.sin(i * 2 * math.pi * 440 / 22050))
                                    for i in range(22050)] + [0] * 5513
            output.writeframes(b''.join(struct.pack('<h', value) for value in samples))
        encoded = self.root / 'padded.m4a'
        subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-i', str(wav),
                        '-c:a', 'aac', str(encoded)], check=True)
        data = encoded.read_bytes()
        receipt = {**self.receipt, 'file': encoded.name, 'sha256': hashlib.sha256(data).hexdigest(),
                   'sizeBytes': len(data), 'durationSeconds': 1.5,
                   'boundarySilenceRequired': True}
        self.assertTrue(verify(self.catalog, receipt, self.root)['boundaryQuiet'])
        with self.assertRaises(ValueError):
            verify(self.catalog, {**self.receipt, 'boundarySilenceRequired': True}, self.root)
