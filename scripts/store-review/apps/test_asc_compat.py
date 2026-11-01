import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class AscCompatibilityTests(unittest.TestCase):
    def run_script(self, script, *args):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            fake = root/'asc'
            fake.write_text('''#!/usr/bin/env python3
import json, sys
key = tuple(sys.argv[1:3])
values = {
 ('apps','list'): {'data':[{'id':'app','attributes':{'bundleId':'com.k9i.ccpocket'}}]},
 ('versions','list'): {'data':[{'id':'version','attributes':{'platform':'IOS','versionString':'1.2.3','appVersionState':'READY_FOR_DISTRIBUTION'}}]},
 ('versions','view'): {'data':{'attributes':{'versionString':'1.2.3','appVersionState':'READY_FOR_DISTRIBUTION'},'relationships':{'build':{'data':{'id':'attached'}}}},'included':[{'type':'builds','id':'attached','attributes':{'version':'10'}}]},
 ('builds','wait'): {},
 ('builds','info'): {'data':{'id':'different','attributes':{'version':'11'}}},
}
if key not in values: raise SystemExit('Unexpected mutation: '+str(key))
print(json.dumps(values[key]))
''')
            fake.chmod(0o755)
            env = dict(os.environ, PATH=str(root)+os.pathsep+os.environ['PATH'],
                       ASC_ISSUER_ID='test', ASC_KEY_ID='test', ASC_PRIVATE_KEY='test', ASC_BUNDLE_ID='com.k9i.ccpocket')
            path = Path(__file__).resolve().parents[1]/script
            if script == 'inspect-ios.sh': args = (str(root/'state.json'),)
            result = subprocess.run(['bash',str(path),*args], env=env, text=True, capture_output=True)
            state = json.loads((root/'state.json').read_text()) if (root/'state.json').exists() else None
            return result, state

    def test_inspection_accepts_asc_6_nested_response(self):
        result, state = self.run_script('inspect-ios.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(state['version'], '1.2.3')
        self.assertEqual(state['buildNumber'], '10')

    def test_submission_still_refuses_different_attached_build(self):
        result, _ = self.run_script('submit-ios.sh', '1.2.3', '11', 'MANUAL')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('different build attached', result.stderr)


if __name__ == '__main__': unittest.main()
