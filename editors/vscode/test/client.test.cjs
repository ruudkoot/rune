'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { launch } = require('../src/launch');
const manifest = require('../package.json');

test('workspace host determines the private runtime, including Remote WSL', () => {
  const root = path.resolve('/tmp/extension with spaces λ');
  for (const [platform, name] of [['linux', 'runevm'], ['win32', 'runevm.exe']]) {
    const server = launch(root, platform, 'x64');
    assert.equal(server.command, path.join(root, 'server/bin', name));
    assert.deepEqual(server.args, ['--heap-size', '67108864', path.join(root, 'server/bin/runelsp.rbc'),
      '--stdio', '--lib', path.join(root, 'server/lib')]);
    assert.equal(server.options.shell, false);
  }
  assert.deepEqual(manifest.extensionKind, ['workspace']);
});

test('unsupported hosts fail explicitly instead of launching an unrelated Rune', () => {
  for (const [platform, arch] of [['darwin', 'x64'], ['linux', 'arm64'], ['win32', 'ia32']]) {
    assert.throws(() => launch('/extension', platform, arch), new RegExp(`${platform}/${arch}`));
  }
});

test('project settings are resource-scoped and libraryRoot remains optional', () => {
  const properties = manifest.contributes.configuration.properties;
  for (const name of ['libraryRoot', 'target', 'sourceMode', 'libraries', 'pathVariables', 'targets', 'activeContext']) {
    assert.equal(properties[`runelsp.${name}`].scope, 'resource');
  }
  assert.equal(properties['runelsp.libraryRoot'].default, null);
});
