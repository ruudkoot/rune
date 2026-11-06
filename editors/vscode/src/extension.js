'use strict';
const vscode = require('vscode');
const { LanguageClient, State, TransportKind } = require('vscode-languageclient/node');
const { launch } = require('./launch');
const status = require('./status');
let client;

// The server sends rune/status and rune/context only to a client that asks here.
const statusFeature = {
  fillClientCapabilities: status.addCapabilities,
  initialize() {},
  getState: () => ({ kind: 'static' }),
  clear() {}
};

const documents = ['sml', 'rune-build'].flatMap(language => ['file', 'untitled'].map(scheme => ({ language, scheme })));

function languageStatus(context) {
  const progress = vscode.languages.createLanguageStatusItem('runelsp.progress', documents);
  progress.name = 'Rune Language Server';
  progress.command = { title: 'Show Output', command: 'runelsp.showOutput' };
  const build = vscode.languages.createLanguageStatusItem('runelsp.context', documents.filter(({ language }) => language === 'sml'));
  build.name = 'Rune Build Context';
  context.subscriptions.push(progress, build);
  return { progress, build };
}

async function activate(context) {
  const output = vscode.window.createOutputChannel('Rune Language Server', { log: true });
  context.subscriptions.push(output);
  const items = languageStatus(context);
  const reports = new Map();
  const showProgress = view => {
    Object.assign(items.progress, view, { severity: vscode.LanguageStatusSeverity[view.severity] });
  };
  const activeUri = () => vscode.window.activeTextEditor?.document.uri.toString();
  const showContext = () => {
    const { text, detail, severity, choose } = status.contextView(reports.get(activeUri()));
    Object.assign(items.build, { text, detail, severity: vscode.LanguageStatusSeverity[severity],
      command: choose ? { title: 'Choose', command: 'runelsp.chooseContext' } : undefined });
  };
  showProgress(status.starting);
  showContext();
  context.subscriptions.push(
    vscode.window.onDidChangeActiveTextEditor(showContext),
    vscode.workspace.onDidCloseTextDocument(document => {
      reports.delete(document.uri.toString());
      showContext();
    }),
    vscode.commands.registerCommand('runelsp.showOutput', () => output.show()),
    // The argument is a context's id, for a caller that knows which it wants.
    vscode.commands.registerCommand('runelsp.chooseContext', async id => {
      const uri = activeUri();
      const report = reports.get(uri);
      if (!report?.contexts.length) return;
      const chosen = id ?? (await vscode.window.showQuickPick(status.contextChoices(report),
        { title: 'Rune build context', placeHolder: uri }))?.id;
      if (chosen) await client.sendRequest('rune/setContext', { uri, context: chosen });
    }));
  try {
    const server = { ...launch(context.extensionPath), transport: TransportKind.stdio };
    output.info(`Rune ${context.extension.packageJSON.runeVersion}`);
    client = new LanguageClient('runelsp', 'Rune Language Server', server, {
      documentSelector: documents,
      synchronize: { configurationSection: 'runelsp' },
      outputChannel: output,
      middleware: {
        provideDiagnostics: (document, previous, token, next) =>
          status.pullWhileUnresolved(() => next(document, previous, token))
      }
    });
    client.registerFeature(statusFeature);
    context.subscriptions.push(
      client.onNotification('rune/status', params => showProgress(status.progressView(params))),
      client.onNotification('rune/context', params => {
        reports.set(params.uri, params);
        showContext();
      }),
      client.onDidChangeState(({ newState }) => {
        if (newState === State.Running) return showProgress(status.idle);
        reports.clear();
        showContext();
        showProgress(newState === State.Starting ? status.starting : status.stopped);
      }),
      vscode.commands.registerCommand('runelsp.restart', () => client.restart()));
    await client.start();
  } catch (error) {
    output.error(error.message);
    showProgress({ ...status.stopped, text: 'Failed to start', detail: error.message, severity: 'Error' });
    vscode.window.showErrorMessage(`Rune Language Server: ${error.message}`);
    throw error;
  }
  return { ...items, reports };
}

async function deactivate() {
  if (client) {
    const running = client;
    client = undefined;
    await running.stop();
  }
}

module.exports = { activate, deactivate };
