import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).parent))
import delivery

spec = importlib.util.spec_from_file_location('deliver_ios', Path(__file__).with_name('deliver-ios.py'))
ios = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ios)


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.env = dict(TARGET_APP='T2QR', VERSION='5.8.0', BUILD_NUMBER='65',
                        CANDIDATE_SHA='a'*40, PLATFORM='android')
        self.manifest = dict(app='T2QR', version='5.8.0', build='65', candidate='a'*40,
                             platform='android', files={'app.aab': hashlib.sha256(b'aab').hexdigest()})

    def test_reject_wrong_identity_and_unexpected_paths(self):
        for key, value in [('app', 'Bookmark-Safe'), ('candidate', 'b'*40), ('build', '66'),
                           ('files', {'../escape': 'a'*64}), ('files', {'app.aab': 'bad'})]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                delivery.validate_manifest(dict(self.manifest, **{key: value}), self.env)

    def test_extract_checks_bytes_and_rejects_extra_executable(self):
        for content, extra, valid in [(b'aab', False, True), (b'changed', False, False), (b'aab', True, False)]:
            with tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                with zipfile.ZipFile(root/'delivery.zip', 'w') as archive:
                    archive.writestr('manifest.json', json.dumps(self.manifest))
                    archive.writestr('app.aab', content)
                    if extra:
                        archive.writestr('run.sh', 'echo unsafe')
                if valid:
                    delivery.extract(root/'delivery.zip', root/'out', self.env)
                    self.assertEqual((root/'out/app.aab').read_bytes(), b'aab')
                else:
                    with self.assertRaises(ValueError):
                        delivery.extract(root/'delivery.zip', root/'out', self.env)

    def test_screenshots_require_exact_order_checksums_and_processing(self):
        with tempfile.TemporaryDirectory() as folder:
            files = [Path(folder)/f'cover-{i}.png' for i in (1, 2)]
            for i, path in enumerate(files): path.write_bytes(str(i).encode())
            remote = [dict(attributes=dict(fileName=p.name, sourceFileChecksum=hashlib.md5(p.read_bytes()).hexdigest(),
                                          assetDeliveryState=dict(state='COMPLETE'))) for p in files]
            self.assertTrue(ios.verify_screenshots(remote, files, complete=True))
            self.assertFalse(ios.verify_screenshots(remote[:1], files, complete=True))
            with self.assertRaises(ValueError): ios.verify_screenshots(remote[::-1], files)
            remote[0]['attributes']['assetDeliveryState']['state'] = 'PROCESSING'
            self.assertFalse(ios.verify_screenshots(remote, files, complete=True))


if __name__ == '__main__':
    unittest.main()
