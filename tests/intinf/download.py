#!/usr/bin/env python3
"""Exercise pinned download failures and cache publication without a network."""
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('build_gmp', ROOT/'scripts/build-gmp.py')
gmp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gmp)
CONTENT = b'a deterministic stand-in for the pinned archive\n'


class Downloads(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.archive = Path(temporary.name)/'downloads/gmp.tar.xz'
        self.archive.parent.mkdir()
        patches = contextlib.ExitStack()
        self.addCleanup(patches.close)
        patches.enter_context(patch.object(gmp, 'SHA256', hashlib.sha256(CONTENT).hexdigest()))
        self.console = io.StringIO()
        patches.enter_context(contextlib.redirect_stdout(self.console))
        patches.enter_context(contextlib.redirect_stderr(self.console))
        self.run = Mock(side_effect=self.success)

    def success(self, argv, name):
        self.assertFalse(self.archive.exists(), 'must not publish before verification')
        Path(argv[-1]).write_bytes(CONTENT)

    def fetch(self):
        return gmp.download_archive(self.archive, self.run)

    def assert_published(self):
        self.assertEqual(self.archive.read_bytes(), CONTENT)
        self.assertEqual(list(self.archive.parent.iterdir()), [self.archive])

    def assert_empty(self):
        self.assertEqual(list(self.archive.parent.iterdir()), [])

    def test_primary_success(self):
        self.assertEqual(self.fetch(), gmp.DOWNLOAD_URLS[0])
        self.run.assert_called_once()
        self.assert_published()

    def test_bounded_retries(self):
        self.fetch()
        argv, name = self.run.call_args.args
        self.assertEqual(name, 'download-1')
        for flag, value in [('--retry', '2'), ('--retry-delay', '2'),
                            ('--retry-max-time', '180'), ('--max-time', '60'),
                            ('--connect-timeout', '15')]:
            self.assertEqual(argv[argv.index(flag)+1], value)
        for flag in ['--fail', '--location', '--show-error', '--retry-connrefused']:
            self.assertIn(flag, argv)

    def test_cached_archive_verified_without_download(self):
        self.archive.write_bytes(CONTENT)
        self.assertIsNone(self.fetch())
        self.run.assert_not_called()
        self.assert_published()

    def test_corrupt_cache_rejected_without_overwriting(self):
        self.archive.write_bytes(b'corrupt cache')
        with self.assertRaisesRegex(RuntimeError, 'cached source checksum mismatch'):
            self.fetch()
        self.run.assert_not_called()
        self.assertEqual(self.archive.read_bytes(), b'corrupt cache')

    def test_timeout_falls_back_and_discards_partial(self):
        def run(argv, name):
            if name == 'download-1':
                Path(argv[-1]).write_bytes(b'interrupted transfer')
                raise gmp.CommandFailed('curl failed (28)')
            self.assertFalse(Path(argv[-1]).exists())
            self.success(argv, name)
        self.run.side_effect = run
        self.assertEqual(self.fetch(), gmp.DOWNLOAD_URLS[1])
        self.assertIn('curl failed (28)', self.console.getvalue())
        self.assertEqual([c.args[0][-3] for c in self.run.call_args_list], list(gmp.DOWNLOAD_URLS))
        self.assert_published()

    def test_process_timeout_falls_back(self):
        def run(argv, name):
            if name == 'download-1':
                raise subprocess.TimeoutExpired(argv, 1)
            self.success(argv, name)
        self.run.side_effect = run
        self.assertEqual(self.fetch(), gmp.DOWNLOAD_URLS[1])
        self.assert_published()

    def test_all_sites_fail_with_diagnostics_and_no_cache(self):
        def run(argv, name):
            Path(argv[-1]).write_bytes(b'partial')
            raise gmp.CommandFailed(f'{name} failed (28)')
        self.run.side_effect = run
        with self.assertRaisesRegex(RuntimeError, 'all release sites') as error:
            self.fetch()
        for url in gmp.DOWNLOAD_URLS:
            self.assertIn(url, str(error.exception))
        self.assertIn('download-1 failed (28)', str(error.exception))
        self.assertIn('download-2 failed (28)', str(error.exception))
        self.assert_empty()

    def test_checksum_mismatch_is_fatal_on_either_site(self):
        for bad_site in ['download-1', 'download-2']:
            with self.subTest(site=bad_site):
                def run(argv, name):
                    if name != bad_site:
                        raise gmp.CommandFailed('curl failed (28)')
                    Path(argv[-1]).write_bytes(b'wrong archive')
                self.run.reset_mock(side_effect=True)
                self.run.side_effect = run
                with self.assertRaisesRegex(RuntimeError, 'source checksum mismatch from https://'):
                    self.fetch()
                self.assertEqual(self.run.call_count, 1 if bad_site == 'download-1' else 2)
                self.assert_empty()

    def test_interruption_cleans_up_without_fallback(self):
        def run(argv, name):
            Path(argv[-1]).write_bytes(b'partial')
            raise KeyboardInterrupt
        self.run.side_effect = run
        with self.assertRaises(KeyboardInterrupt):
            self.fetch()
        self.run.assert_called_once()
        self.assert_empty()

    def test_missing_curl_is_not_a_mirror_failure(self):
        self.run.side_effect = FileNotFoundError('curl')
        with self.assertRaises(FileNotFoundError):
            self.fetch()
        self.run.assert_called_once()
        self.assert_empty()

    def test_legacy_partial_is_not_trusted(self):
        partial = self.archive.with_suffix('.xz.part')
        partial.write_bytes(b'old interrupted transfer')
        self.fetch()
        self.assertEqual(self.archive.read_bytes(), CONTENT)
        self.assertEqual(partial.read_bytes(), b'old interrupted transfer')

    def test_cli_retains_each_failure_and_prints_curl_diagnostic(self):
        root = self.archive.parent.parent
        child = root/'fake-curl.py'
        child.write_text("import sys\nprint('synthetic curl timeout', file=sys.stderr)\nsys.exit(28)\n")
        popen = subprocess.Popen
        self.addCleanup(os.chdir, Path.cwd())
        with patch.object(gmp, 'ROOT', root), patch.object(sys, 'argv', ['build-gmp.py']), \
             patch.object(gmp.subprocess, 'Popen',
                          side_effect=lambda argv, **kw: popen([sys.executable, str(child)], **kw)):
            with self.assertRaisesRegex(RuntimeError, 'all release sites'):
                gmp.main()
        build, = (root/'build/deps/gmp-build').iterdir()
        commands = json.loads((build/'commands.json').read_text())
        self.assertEqual([c['name'] for c in commands], ['download-1', 'download-2'])
        for name in ['download-1', 'download-2']:
            self.assertEqual((build/(name+'.log')).read_text(), 'synthetic curl timeout\n')
            self.assertIn('exit:28', (build/(name+'.status')).read_text())
        self.assertEqual(self.console.getvalue().count('synthetic curl timeout'), 2)
        self.assertEqual(list((root/'build/deps/downloads').iterdir()), [])


if __name__ == '__main__':
    unittest.main()
