'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { launch } = require('../src/launch');
const status = require('../src/status');
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

test('the server is asked for rune/status and rune/context under experimental', () => {
  const capabilities = { experimental: { other: true } };
  status.addCapabilities(capabilities);
  assert.deepEqual(capabilities.experimental, { other: true, rune: { status: true, context: true } });
});

test('progress shows the server\'s state, and an error once a worker failed', () => {
  assert.deepEqual(status.progressView({ busy: true, severity: 'information', text: 'Checking a.sml', detail: 'one: 2 units checked, 3 reused' }),
    { busy: true, severity: 'Information', text: 'Checking a.sml', detail: 'one: 2 units checked, 3 reused' });
  assert.equal(status.progressView({ busy: false, severity: 'error', text: 'Analysis failed', detail: 'why' }).severity, 'Error');
});

const one = { id: 'one#1', name: 'one.build', label: 'file:///one.build (unit 2)' };
const two = { id: 'two#1', name: 'two.build', label: 'file:///two.build (unit 2)' };

test('a file with several contexts shows the one it is checked in and offers the others', () => {
  const report = { state: 'selected', context: two, contexts: [one, two] };
  const view = status.contextView(report);
  assert.equal(view.text, 'two.build');
  assert.match(view.detail, /^2 build contexts/);
  assert.equal(view.severity, 'Information');
  assert.equal(view.choose, true);
  assert.deepEqual(status.contextChoices(report).map(item => [item.label, item.description]),
    [['one.build', undefined], ['two.build', 'current']]);
});

test('an unresolved file warns and offers the choice', () => {
  const view = status.contextView({ state: 'unresolved', context: null, contexts: [one, two] });
  assert.equal(view.severity, 'Warning');
  assert.equal(view.choose, true);
  assert.equal(view.detail, '2 build contexts');
});

test('a file with one context, or none, offers no choice', () => {
  const single = status.contextView({ state: 'selected', context: one, contexts: [one] });
  assert.equal(single.text, 'one.build');
  assert.match(single.detail, /^1 build context:/);
  assert.equal(single.choose, false);
  const loose = status.contextView({ state: 'none', context: null, contexts: [] });
  assert.equal(loose.text, 'No build context');
  assert.equal(loose.choose, false);
  assert.equal(status.contextView(undefined).choose, false);
});

test('a pull cancelled for a pending context reports nothing, and other failures stay failures', async () => {
  const cancelled = Object.assign(new Error('select a build context'), { data: { retriggerRequest: false } });
  assert.deepEqual(await status.pullWhileUnresolved(async () => { throw cancelled; }), { kind: 'full', items: [] });
  const report = { kind: 'full', items: [{}] };
  assert.equal(await status.pullWhileUnresolved(async () => report), report);
  const retried = Object.assign(new Error('source changed'), { data: { retriggerRequest: true } });
  await assert.rejects(status.pullWhileUnresolved(async () => { throw retried; }), retried);
  await assert.rejects(status.pullWhileUnresolved(async () => { throw new Error('no data'); }), /no data/);
});

test('the commands of the status items are contributed', () => {
  const names = manifest.contributes.commands.map(({ command }) => command);
  for (const name of ['runelsp.restart', 'runelsp.chooseContext', 'runelsp.showOutput']) assert.ok(names.includes(name));
});
