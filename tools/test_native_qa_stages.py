"""Native orchestration regressions; these do not simulate media/device acceptance."""
import json
import pathlib
import sys
import tempfile
import unittest
from unittest.mock import patch

from native_qa_stages import NativeStages
import run_ci_android_qa


class NativeStageTests(unittest.TestCase):
    def test_later_success_does_not_hide_failure_and_records_both_logs(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = NativeStages(directory, directory)
            self.assertEqual(runner.run('ui', [sys.executable, '-c', 'print("failed assertion"); exit(2)']), 2)
            self.assertEqual(runner.run('real-audio', [sys.executable, '-c', 'print("54 files")']), 0)
            self.assertEqual(runner.exit_code, 1)
            results = json.loads((pathlib.Path(directory) / 'native-stages.json').read_text())
            self.assertEqual([r['exit_code'] for r in results], [2, 0])
            self.assertIn('failed assertion', (pathlib.Path(directory) / 'ui.log').read_text())
            self.assertIn('54 files', (pathlib.Path(directory) / 'real-audio.log').read_text())

    def test_timeout_is_recorded_and_next_independent_check_runs(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = NativeStages(directory, directory)
            self.assertEqual(runner.run('timeout', [sys.executable, '-c', 'import time; time.sleep(2)'], timeout=0.01), 124)
            self.assertEqual(runner.run('next', [sys.executable, '-c', 'exit(0)']), 0)
            self.assertEqual(runner.exit_code, 1)

    def test_android_ui_failure_still_runs_production_audio_and_probe(self):
        with patch.dict('os.environ', {'GITHUB_ACTIONS': 'true'}), patch.object(run_ci_android_qa, 'NativeStages') as factory:
            stages = factory.return_value
            stages.run.side_effect = [0, 2, 0, 0, 0]
            stages.exit_code = 1
            self.assertEqual(run_ci_android_qa.main(), 1)
            names = [call.args[0] for call in stages.run.call_args_list]
            self.assertEqual(names, ['production-install', 'application-ui', 'bundled-narration-native', 'probe-install', 'technical-audio-probe'])

    def test_failed_install_does_not_claim_device_tests_executed(self):
        with patch.dict('os.environ', {'GITHUB_ACTIONS': 'true'}), patch.object(run_ci_android_qa, 'NativeStages') as factory:
            stages = factory.return_value
            stages.run.return_value = 1
            stages.exit_code = 1
            self.assertEqual(run_ci_android_qa.main(), 1)
            self.assertEqual(stages.run.call_count, 1)

    def test_ios_ui_failure_still_runs_production_audio_and_probe(self):
        import plistlib
        import run_ci_ios_qa
        with tempfile.TemporaryDirectory() as directory:
            app = pathlib.Path(directory) / 'Runner.app'
            app.mkdir()
            (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'test.app'}))
            runtime = {'version': '18.5', 'isAvailable': True,
                       'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-18-5'}
            outputs = [json.dumps({'runtimes': [runtime]}), '18.5',
                       json.dumps({'devicetypes': [{'name': 'iPhone 16', 'identifier': 'phone'}]}),
                       'disposable-device', '', '', '']
            with patch.dict('os.environ', {'GITHUB_ACTIONS': 'true'}), \
                 patch.object(run_ci_ios_qa, 'ROOT', pathlib.Path(directory)), \
                 patch.object(run_ci_ios_qa, 'APP', app), \
                 patch.object(run_ci_ios_qa, 'run', side_effect=outputs), \
                 patch.object(run_ci_ios_qa, 'NativeStages') as factory, \
                 patch.object(run_ci_ios_qa.subprocess, 'Popen'), \
                 patch.object(run_ci_ios_qa.subprocess, 'run'):
                stages = factory.return_value
                stages.run.side_effect = [2, 0, 0, 0]
                stages.exit_code = 1
                self.assertEqual(run_ci_ios_qa.main(), 1)
                self.assertEqual([call.args[0] for call in stages.run.call_args_list],
                                 ['application-ui', 'bundled-narration-native',
                                  'probe-install', 'technical-audio-probe'])
