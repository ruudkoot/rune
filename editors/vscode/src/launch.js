'use strict';
const path = require('node:path');

function launch(extensionPath, platform = process.platform, arch = process.arch) {
  if (arch !== 'x64' || !['linux', 'win32'].includes(platform)) {
    throw new Error(`Rune language server supports Linux and Windows x86-64; this extension host is ${platform}/${arch}.`);
  }
  const bin = path.join(extensionPath, 'server', 'bin');
  return {
    command: path.join(bin, platform === 'win32' ? 'runevm.exe' : 'runevm'),
    args: ['--heap-size', '67108864', path.join(bin, 'runelsp.rbc'),
      '--stdio', '--lib', path.join(extensionPath, 'server', 'lib')],
    options: { cwd: extensionPath, shell: false }
  };
}

module.exports = { launch };
