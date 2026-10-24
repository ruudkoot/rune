'use strict';
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { execFileSync } = require('node:child_process');
const { runTests } = require('@vscode/test-electron');
const version = process.env.VSCODE_TEST_VERSION || '1.106.0';
// Codex/VS Code terminals may inherit this; Electron must start as an editor.
delete process.env.ELECTRON_RUN_AS_NODE;
for (const key of Object.keys(process.env)) if (key.startsWith('VSCODE_')) delete process.env[key];
const root = path.resolve(__dirname, '../../..');
const archive = process.argv[2];
if (!archive) throw new Error('usage: node test/editor.cjs VSIX');
// Editor IPC uses Unix sockets, whose paths must fit within 107 bytes.
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'rune-vscode-editor-'));
console.log(`Editor test artifacts: ${temp}`);
if (process.platform === 'linux') {
  const runtime = path.join(temp, 'runtime');
  fs.mkdirSync(runtime, { mode: 0o700 });
  process.env.XDG_RUNTIME_DIR = runtime;
}
execFileSync('unzip', ['-q', path.resolve(archive), '-d', temp]);
const project = process.env.RUNE_VSCODE_PROJECT_ROOT;
const workspace = path.join(temp, 'rune.code-workspace');
if (project) {
  const { pathToFileURL } = require('node:url');
  fs.writeFileSync(workspace, JSON.stringify({ folders: [{ path: path.resolve(project) }], settings: {
    'runelsp.libraryRoot': pathToFileURL(path.join(project, 'lib')).href,
    'runelsp.targets': [{ name: 'rune', build: pathToFileURL(path.join(project, 'rune.build')).href }],
    'runelsp.activeContext': 'rune',
    ...(process.env.RUNE_VSCODE_TRACE ? { 'runelsp.trace.server': 'verbose' } : {})
  } }));
}
runTests({
  extensionDevelopmentPath: path.join(temp, 'extension'),
  extensionTestsPath: path.join(__dirname, 'editor-suite.cjs'),
  cachePath: path.join(root, 'build/vscode/editor-cache'),
  version,
  launchArgs: ['--disable-gpu', '--ozone-platform=x11', '--password-store=basic',
    '--disable-extensions', '--skip-welcome', '--skip-release-notes',
    '--user-data-dir', path.join(temp, 'user'), '--extensions-dir', path.join(temp, 'extensions'),
    ...(project ? [workspace] : [])]
}).catch(error => { console.error(error); process.exitCode = 1; });
