"""Collect independent native checks without masking failures or skipping evidence."""
import json
import pathlib
import subprocess


class NativeStages:
    def __init__(self, root, evidence):
        self.root = pathlib.Path(root)
        self.evidence = pathlib.Path(evidence)
        self.evidence.mkdir(parents=True, exist_ok=True)
        self.results = []

    def run(self, name, command, *, timeout=900, **metadata):
        command = [str(part) for part in command]
        result = {'name': name, 'command': command, **metadata}
        with (self.evidence / f'{name}.log').open('w') as log:
            try:
                result['exit_code'] = subprocess.run(
                    command, cwd=self.root, stdout=log,
                    stderr=subprocess.STDOUT, timeout=timeout).returncode
            except subprocess.TimeoutExpired:
                result.update(exit_code=124, error=f'timeout after {timeout} seconds')
            except OSError as error:
                result.update(exit_code=127, error=str(error))
        self.results.append(result)
        (self.evidence / f'{name}.json').write_text(json.dumps(result, indent=2) + '\n')
        (self.evidence / 'native-stages.json').write_text(
            json.dumps(self.results, indent=2) + '\n')
        print(f'{name}: exit {result["exit_code"]}', flush=True)
        return result['exit_code']

    @property
    def exit_code(self):
        return int(any(result['exit_code'] != 0 for result in self.results))
