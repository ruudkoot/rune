'use strict';
const assert = require('node:assert/strict');
const vscode = require('vscode');
async function until(action) {
  const end = Date.now() + 30000;
  while (Date.now() < end) {
    const result = await action();
    if (result) return result;
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  throw new Error('Timed out waiting for editor language service');
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
};
