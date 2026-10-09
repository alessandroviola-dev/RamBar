#!/usr/bin/env python3
"""Privacy regression tests; synthetic paths never use the developer's HOME."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.dont_write_bytecode = True
SCRIPT = Path(__file__).with_name('privacy-scan.py')
spec = importlib.util.spec_from_file_location('privacy_scan', SCRIPT)
scanner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scanner)


class PrivacyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='rambar-privacy-test-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.app = self.root / 'RamBar.app'
        self.binary = self.app / 'Contents/MacOS/RamBar'
        self.binary.parent.mkdir(parents=True)
        self.binary.write_bytes(b'\xcf\xfa\xed\xfe\0clean executable\0')
        self.env = dict(os.environ, HOME='/unrelated-fixture-home')

    def run_scan(self, mode, path, expected):
        result = subprocess.run(['python3', str(SCRIPT), mode, str(path)],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, expected, result.stderr)
        self.assertNotIn('fixture-private', result.stdout + result.stderr)

    def zip(self):
        path = self.root / 'fixture.zip'
        with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_STORED) as archive:
            for file in self.app.rglob('*'):
                if file.is_file():
                    archive.write(file, file.relative_to(self.root))
        return path

    def test_clean_bundle(self):
        self.run_scan('bundle', self.app, 0)

    def test_contaminated_executable(self):
        self.binary.write_bytes(b'\xcf\xfa\xed\xfe\0/Users/fixture-private/project/object.o\0')
        self.run_scan('bundle', self.app, 1)

    def test_other_file(self):
        (self.app / 'metadata').write_bytes(b'/Users/fixture-private/project')
        self.run_scan('bundle', self.app, 1)

    def test_clean_zip(self):
        self.run_scan('zip', self.zip(), 0)

    def test_contaminated_zip(self):
        self.binary.write_bytes(b'/Users/fixture-private/path\0' + b'x\n' * 8000000)
        self.run_scan('zip', self.zip(), 1)

    def test_read_errors(self):
        with patch('builtins.open', side_effect=PermissionError):
            with self.assertRaises(PermissionError):
                scanner.scan_bundle(self.app)
        with patch.object(scanner, 'scan_bundle', side_effect=PermissionError):
            self.assertEqual(scanner.main(['scanner', 'bundle', str(self.app)]), 1)
        self.run_scan('bundle', self.root / 'missing', 1)
        self.run_scan('zip', self.root / 'missing.zip', 1)

    def test_corrupt_zip(self):
        path = self.root / 'corrupt.zip'
        path.write_bytes(b'not a zip')
        self.run_scan('zip', path, 1)

    def test_symlink(self):
        (self.app / 'unsafe').symlink_to(self.binary)
        self.run_scan('bundle', self.app, 1)

    def test_utf16_path(self):
        self.binary.write_bytes('/Users/fixture-private/path'.encode('utf-16-le'))
        self.run_scan('bundle', self.app, 1)

    def test_sigpipe_false_negative_cannot_bypass_scanner(self):
        self.binary.write_bytes(b'/Users/fixture-private/path\n' + b'x\n' * 8000000)
        path = self.zip()
        # Demonstrate the unsafe early-exit pipeline with pipefail enabled.
        script = ('set -o pipefail; unzip -p "$1" | grep -a -q -F /Users/fixture-private; '
                  'codes=("${PIPESTATUS[@]}"); printf "%s %s" "${codes[0]}" "${codes[1]}"')
        result = subprocess.run(['/bin/bash', '-c', script, 'test', str(path)],
                                capture_output=True, text=True, env=self.env)
        self.assertEqual(result.stdout, '141 0')
        self.run_scan('zip', path, 1)
        self.run_scan('bundle', self.app, 1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
