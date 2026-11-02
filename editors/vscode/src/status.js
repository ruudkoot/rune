'use strict';
// What the two language status items show, from the server's rune/ messages.
// No vscode here, so that test/client.test.cjs can run it under plain Node.

function addCapabilities(capabilities) {
  capabilities.experimental = { ...capabilities.experimental, rune: { status: true, context: true } };
}

function progressView({ busy, severity, text, detail }) {
  return { busy, text, detail, severity: severity === 'error' ? 'Error' : 'Information' };
}

const stopped = { busy: false, text: 'Stopped', detail: '', severity: 'Information' };
const starting = { busy: true, text: 'Starting', detail: '', severity: 'Information' };
const idle = { busy: false, text: 'Idle', detail: '', severity: 'Information' };

function counted(count) {
  return `${count} build context${count === 1 ? '' : 's'}`;
}

function contextView(report) {
  if (!report) return { text: 'Build context not known yet', detail: '', severity: 'Information', choose: false };
  const count = report.contexts.length;
  switch (report.state) {
    case 'selected':
      return { text: report.context.name, detail: `${counted(count)}: ${report.context.label}`,
        severity: 'Information', choose: count > 1 };
    case 'unresolved':
      return { text: 'No build context chosen', detail: counted(count), severity: 'Warning', choose: true };
    default:
      return { text: 'No build context', detail: 'Checked on its own', severity: 'Information', choose: false };
  }
}

function contextChoices(report) {
  return report.contexts.map(({ id, name, label }) => ({
    id, label: name, description: id === report.context?.id ? 'current' : undefined, detail: label
  }));
}

// While a file waits for a context the server cancels its diagnostic pulls with
// retriggerRequest false. vscode-languageclient 10.1.2 rethrows that with the
// request still open, and pulls that document no more, so a choice would change
// nothing on screen. To the client the file has no diagnostics yet.
async function pullWhileUnresolved(pull) {
  try {
    return await pull();
  } catch (error) {
    if (error?.data?.retriggerRequest === false) return { kind: 'full', items: [] };
    throw error;
  }
}

module.exports = { addCapabilities, progressView, stopped, starting, idle, contextView, contextChoices, pullWhileUnresolved };
