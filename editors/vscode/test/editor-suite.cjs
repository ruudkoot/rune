'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vscode = require('vscode');
const sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
async function until(action) {
  const end = Date.now() + 30000;
  while (Date.now() < end) {
    const result = await action();
    if (result) return result;
    await sleep(100);
  }
  throw new Error('Timed out waiting for editor language service');
}
// The two language status items, in a folder of its own whose builds discovery
// finds: shared.sml types in one.build and not in two.build.
async function languageStatus({ progress, build, reports }) {
  const { Information, Warning } = vscode.LanguageStatusSeverity;
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'rune-status-'));
  const files = {
    'one.build': 'files one.sml shared.sml end\n', 'two.build': 'files two.sml shared.sml end\n',
    'solo.build': 'files solo.sml end\n', 'long.build': 'files long.sml end\n',
    'one.sml': 'val input=1\n', 'two.sml': 'val input=true\n', 'shared.sml': 'val result:int=input\n',
    'solo.sml': 'val alone=1\n',
    'long.sml': `val long=[${'0,0,0,0,0,0,0,0,0,0,\n'.repeat(20000)}0]\n`
  };
  for (const [name, text] of Object.entries(files)) fs.writeFileSync(path.join(folder, name), text);
  const open = async name => {
    const document = await vscode.workspace.openTextDocument(vscode.Uri.file(path.join(folder, name)));
    await vscode.window.showTextDocument(document);
    return document;
  };
  const errors = document => vscode.languages.getDiagnostics(document.uri)
    .filter(item => item.severity === vscode.DiagnosticSeverity.Error);

  await open('solo.sml');
  await until(() => build.text === 'solo.build');
  assert.equal(build.severity, Information);
  assert.equal(build.command, undefined);
  console.log('PASS vscode/editor/status-one-context-offers-no-choice');

  await until(() => !progress.busy);
  await open('long.sml');
  await until(() => progress.busy && progress.text === 'Checking long.sml');
  await until(() => !progress.busy && progress.text === 'Idle');
  assert.match(progress.detail, / checked, /);
  assert.equal(progress.command.command, 'runelsp.showOutput');
  console.log('PASS vscode/editor/status-progress-busy-then-idle');

  const shared = await open('shared.sml');
  await until(() => build.severity === Warning);
  assert.equal(build.text, 'No build context chosen');
  assert.equal(build.command?.command, 'runelsp.chooseContext');
  await sleep(500);
  await vscode.commands.executeCommand('notifications.clearAll');
  await sleep(500);
  assert.equal(build.severity, Warning);
  assert.equal(build.command?.command, 'runelsp.chooseContext');
  console.log('PASS vscode/editor/status-dismissed-prompt-leaves-warning-and-choice');

  const { contexts } = reports.get(shared.uri.toString());
  assert.deepEqual(contexts.map(context => context.name), ['one.build', 'two.build']);
  const chooseId = name => vscode.commands.executeCommand('runelsp.chooseContext', contexts.find(context => context.name === name).id);
  await chooseId('two.build');
  await until(() => build.text === 'two.build' && build.severity === Information);
  assert.match(build.detail, /^2 build contexts/);
  assert.equal(build.command?.command, 'runelsp.chooseContext');
  await until(() => errors(shared).length > 0);
  console.log('PASS vscode/editor/status-shows-the-context-it-is-checked-in');

  await chooseId('one.build');
  await until(() => build.text === 'one.build');
  await until(() => errors(shared).length === 0);
  await chooseId('two.build');
  await until(() => errors(shared).length > 0);
  const picking = vscode.commands.executeCommand('runelsp.chooseContext');
  await sleep(1000);
  await vscode.commands.executeCommand('workbench.action.acceptSelectedQuickOpenItem');
  await picking;
  await until(() => build.text === 'one.build');
  await until(() => errors(shared).length === 0);
  console.log('PASS vscode/editor/status-choosing-again-changes-diagnostics');
  await vscode.commands.executeCommand('workbench.action.closeAllEditors');
  fs.rmSync(folder, { recursive: true, force: true });
}

exports.run = async () => {
  const extension = vscode.extensions.getExtension('ruudkoot.rune-language-server');
  assert.ok(extension);
  const document = await vscode.workspace.openTextDocument({ language: 'sml', content: 'val answer=List.length [1,2]\n' });
  await vscode.window.showTextDocument(document);
  await extension.activate();
  const hover = await until(async () => {
    const values = await vscode.commands.executeCommand('vscode.executeHoverProvider', document.uri, new vscode.Position(0, 4));
    return values?.length && values;
  });
  assert.match(hover[0].contents.map(item => item.value ?? item).join('\n'), /int/);
  const edit = new vscode.WorkspaceEdit();
  edit.replace(document.uri, new vscode.Range(0, 0, 1, 0), 'val bad:int=true\n');
  assert.equal(await vscode.workspace.applyEdit(edit), true);
  await until(() => vscode.languages.getDiagnostics(document.uri).some(item => item.severity === vscode.DiagnosticSeverity.Error));
  const fix = new vscode.WorkspaceEdit();
  fix.replace(document.uri, new vscode.Range(0, 0, 1, 0), 'val answer=List.length [1,2]\n');
  assert.equal(await vscode.workspace.applyEdit(fix), true);
  await until(() => vscode.languages.getDiagnostics(document.uri).length === 0);
  await vscode.commands.executeCommand('runelsp.restart');
  await until(async () => {
    const values = await vscode.commands.executeCommand('vscode.executeHoverProvider', document.uri, new vscode.Position(0, 4));
    return values?.some(item => item.contents.some(content => /int/.test(content.value ?? content)));
  });
  await vscode.commands.executeCommand('workbench.action.revertAndCloseActiveEditor');
  console.log('PASS vscode/editor/activation-hover-diagnostics-restart');
  await languageStatus(extension.exports);
  const root = process.env.RUNE_VSCODE_PROJECT_ROOT;
  if (root) {
    const config = vscode.workspace.getConfiguration('runelsp');
    await config.update('libraryRoot', vscode.Uri.file(`${root}/lib`).toString(), vscode.ConfigurationTarget.Workspace);
    await config.update('targets', [{ name: 'rune', build: vscode.Uri.file(`${root}/rune.build`).toString() }], vscode.ConfigurationTarget.Workspace);
    await config.update('activeContext', 'rune', vscode.ConfigurationTarget.Workspace);
    const source = await vscode.workspace.openTextDocument(vscode.Uri.file(`${root}/src/main/rune-main.sml`));
    await vscode.window.showTextDocument(source);
    const original = source.getText();
    const position = new vscode.Position(1, 15);
    await until(async () => {
      const hover = await vscode.commands.executeCommand('vscode.executeHoverProvider', source.uri, position);
      return hover?.some(item => item.contents.some(content => /ref/.test(content.value ?? content)));
    });
    const definitions = await vscode.commands.executeCommand('vscode.executeDefinitionProvider', source.uri, position);
    assert.ok(definitions?.length);
    const completion = await vscode.commands.executeCommand('vscode.executeCompletionItemProvider', source.uri, new vscode.Position(2, 11));
    assert.ok(completion?.items.length);
    const broken = new vscode.WorkspaceEdit();
    broken.insert(source.uri, source.positionAt(original.length), '\nval editor_error:int=true\n');
    assert.equal(await vscode.workspace.applyEdit(broken), true);
    await until(() => vscode.languages.getDiagnostics(source.uri).some(item => item.severity === vscode.DiagnosticSeverity.Error));
    const repair = new vscode.WorkspaceEdit();
    repair.replace(source.uri, new vscode.Range(source.positionAt(0), source.positionAt(source.getText().length)), original);
    assert.equal(await vscode.workspace.applyEdit(repair), true);
    await until(() => vscode.languages.getDiagnostics(source.uri).length === 0);
    await vscode.commands.executeCommand('workbench.action.revertAndCloseActiveEditor');
    console.log('PASS vscode/editor/rune-project-hover-navigation-completion-edit-repair');
    const basis = await vscode.workspace.openTextDocument(vscode.Uri.file(`${root}/lib/basis/runtime.sml`));
    await vscode.window.showTextDocument(basis);
    const primitive = basis.getText().indexOf('instructions\'');
    assert.ok(primitive >= 0);
    await until(async () => {
      const values = await vscode.commands.executeCommand('vscode.executeHoverProvider', basis.uri, basis.positionAt(primitive));
      return values?.length && vscode.languages.getDiagnostics(basis.uri).length === 0;
    });
    await vscode.commands.executeCommand('workbench.action.revertAndCloseActiveEditor');
    console.log('PASS vscode/editor/basis-development-context');
  }
};
