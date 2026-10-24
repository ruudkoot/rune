'use strict';
// JS tooling owns bundling only. SML selects and stages the distributable files.
const fs = require('node:fs');
const path = require('node:path');
const esbuild = require('esbuild');
const out = process.argv[2];
if (!out) throw new Error('usage: node bundle.cjs OUTPUT_DIRECTORY');
fs.mkdirSync(out, { recursive: true });
esbuild.build({
  absWorkingDir: __dirname, entryPoints: ['src/extension.js'], bundle: true,
  platform: 'node', format: 'cjs', target: 'node20', external: ['vscode'],
  outfile: path.join(out, 'extension.js'), metafile: true, legalComments: 'inline'
}).then(result => {
  const packages = new Map();
  for (const input of Object.keys(result.metafile.inputs)) {
    if (!input.includes('node_modules/')) continue;
    let dir = path.dirname(path.resolve(__dirname, input));
    let pkg;
    while (!(fs.existsSync(path.join(dir, 'package.json')) &&
      (pkg = JSON.parse(fs.readFileSync(path.join(dir, 'package.json'), 'utf8'))).name)) {
      const parent = path.dirname(dir);
      if (parent === dir) throw new Error(`No package metadata for ${input}`);
      dir = parent;
    }
    const license = fs.readdirSync(dir).filter(name => /^(licen[cs]e|copyright|notice)(\.|$)/i.test(name));
    if (!license.length) throw new Error(`Missing license text for ${pkg.name}`);
    packages.set(`${pkg.name}@${pkg.version}`, license.sort().map(name =>
      fs.readFileSync(path.join(dir, name), 'utf8')).join('\n'));
  }
  const notices = [...packages].sort(([a], [b]) => a.localeCompare(b)).map(([name, license]) => `${name}\n\n${license}`);
  fs.writeFileSync(path.join(out, 'ThirdPartyNotices.txt'), notices.join('\n\n-----\n\n') + '\n');
}).catch(error => { console.error(error); process.exitCode = 1; });
