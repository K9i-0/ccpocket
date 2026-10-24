import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('prepare', Path(__file__).with_name('prepare.py'))
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class PrepareTests(unittest.TestCase):
    def setUp(self):
        self.env = dict(TARGET_APP='T2QR', OPERATION='submit', PLATFORM='both',
                        EXPECTED_REF_SHA='a'*40, GITHUB_SHA='a'*40, CANDIDATE_SHA='b'*40,
                        VERSION='5.7.2', BUILD_NUMBER='64', CONFIRMATION='SUBMIT T2QR 5.7.2+64',
                        RELEASE_NOTES_JSON=json.dumps({'ios': {'en-US': 'Stability.', 'ja': '安定性'},
                                                      'android': {'en-US': 'Security.', 'ja-JP': '安全性'}}))

    def test_exact_app_modes(self):
        self.assertEqual(prepare.validate(self.env)[:2], ('com.kotahayashi.t2qr', 'MANUAL'))
        self.env.update(TARGET_APP='Bookmark-Safe', CONFIRMATION='SUBMIT Bookmark-Safe 5.7.2+64')
        self.assertEqual(prepare.validate(self.env)[:2], ('com.k9i.b72', 'AFTER_APPROVAL'))

    def test_reject_bad_dispatch(self):
        for key, value in [('TARGET_APP', 'other'), ('EXPECTED_REF_SHA', 'c'*40),
                           ('CANDIDATE_SHA', 'main'), ('VERSION', '5.7.2;echo bad'),
                           ('BUILD_NUMBER', '0'), ('CONFIRMATION', 'SUBMIT 5.7.2+64'),
                           ('PLATFORM', 'windows'), ('OPERATION', 'publish')]:
            with self.subTest(key=key):
                env = dict(self.env, **{key: value})
                with self.assertRaises((AssertionError, KeyError)):
                    prepare.validate(env)

    def test_reject_bad_notes(self):
        for notes in [{}, {'ios': {}}, {'ios': {'en-US': 'x', 'ja': 'x', '../': 'x'}},
                      {'ios': {'en-US': '', 'ja': 'x'}}, {'ios': {'en-US': 'x'*4001, 'ja': 'x'}},
                      {'ios': {'en-US': 12, 'ja': 'x'}}, {'ios': {'en-US': 'x\0', 'ja': 'x'}}]:
            env = dict(self.env, PLATFORM='ios', RELEASE_NOTES_JSON=json.dumps(notes))
            with self.subTest(notes=str(notes)[:40]), self.assertRaises(AssertionError):
                prepare.validate(env)

    def test_android_length_limit(self):
        env = dict(self.env, PLATFORM='android', RELEASE_NOTES_JSON=json.dumps({'android': {'en-US': 'x'*501, 'ja-JP': 'x'}}))
        with self.assertRaises(AssertionError):
            prepare.validate(env)

    def test_inspection_needs_no_candidate_or_notes(self):
        self.env.update(OPERATION='inspect', RELEASE_NOTES_JSON='not JSON', CANDIDATE_SHA='')
        self.assertEqual(prepare.validate(self.env)[2], {})

    def test_inspection_still_checks_workflow_sha(self):
        self.env.update(OPERATION='inspect', GITHUB_SHA='c'*40)
        with self.assertRaises(AssertionError):
            prepare.validate(self.env)


if __name__ == '__main__':
    unittest.main()
