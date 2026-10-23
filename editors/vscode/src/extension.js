'use strict';
const vscode = require('vscode');
const { LanguageClient, TransportKind } = require('vscode-languageclient/node');
const { launch } = require('./launch');
let client;

async function activate(context) {
  const output = vscode.window.createOutputChannel('Rune language server', { log: true });
  context.subscriptions.push(output);
  try {
    const server = { ...launch(context.extensionPath), transport: TransportKind.stdio };
    output.info(`Rune ${context.extension.packageJSON.runeVersion}`);
    client = new LanguageClient('runelsp', 'Rune language server', server, {
      documentSelector: ['sml', 'rune-build'].flatMap(language =>
        ['file', 'untitled'].map(scheme => ({ language, scheme }))),
      synchronize: { configurationSection: 'runelsp' },
      outputChannel: output
    });
    context.subscriptions.push(vscode.commands.registerCommand('runelsp.restart', () => client.restart()));
    await client.start();
  } catch (error) {
    output.error(error.message);
    vscode.window.showErrorMessage(`Rune language server: ${error.message}`);
    throw error;
  }
}

async function deactivate() {
  if (client) {
    const running = client;
    client = undefined;
    await running.stop();
  }
}

module.exports = { activate, deactivate };
