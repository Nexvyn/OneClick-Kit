#!/usr/bin/env node
// Browser chooser. Without --apply it only lists browsers. With --apply it installs the chosen ones.
import { spawnSync } from 'node:child_process';
import readline from 'node:readline/promises';
import { detectManager, ensureFlatpak, installSystemPackage } from './linux-setup.mjs';

const browsers = [
  { id: 'chrome', name: 'Google Chrome', winget: 'Google.Chrome', flatpak: 'com.google.Chrome', bins: ['google-chrome', 'google-chrome-stable'] },
  { id: 'firefox', name: 'Mozilla Firefox', winget: 'Mozilla.Firefox', flatpak: 'org.mozilla.firefox', bins: ['firefox'],
    pkg: { 'apt-get': 'firefox', dnf: 'firefox', pacman: 'firefox', zypper: 'MozillaFirefox' } },
  { id: 'brave', name: 'Brave', winget: 'Brave.Brave', flatpak: 'com.brave.Browser', bins: ['brave-browser'] },
  { id: 'edge', name: 'Microsoft Edge', winget: 'Microsoft.Edge', flatpak: 'com.microsoft.Edge', bins: ['microsoft-edge', 'microsoft-edge-stable'] },
  { id: 'opera', name: 'Opera', winget: 'Opera.Opera', flatpak: 'com.opera.Opera', bins: ['opera'] },
  { id: 'vivaldi', name: 'Vivaldi', winget: 'Vivaldi.Vivaldi', flatpak: 'com.vivaldi.Vivaldi', bins: ['vivaldi'] },
];

const win = process.platform === 'win32';
const quiet = (cmd, args) => spawnSync(cmd, args, { encoding: 'utf8', stdio: 'pipe', shell: false });
const which = cmd => quiet('which', [cmd]).status === 0;

function installed(b) {
  if (win) {
    if (b.id === 'edge') return true; // Edge ships with Windows.
    const r = quiet('winget', ['list', '--id', b.winget, '--exact', '--accept-source-agreements']);
    return r.status === 0 && String(r.stdout || '').includes(b.winget);
  }
  if (b.bins.some(which)) return true;
  return quiet('flatpak', ['info', b.flatpak]).status === 0;
}

function installBrowser(b, manager) {
  if (win) {
    return spawnSync('winget', ['install', '--id', b.winget, '--exact', '--source', 'winget',
      '--accept-source-agreements', '--accept-package-agreements'], { stdio: 'inherit', shell: false }).status === 0;
  }
  const pkg = b.pkg?.[manager];
  if (pkg && installSystemPackage(manager, pkg)) return true;
  if (!ensureFlatpak(manager)) return false;
  return spawnSync('flatpak', ['install', '--user', '-y', 'flathub', b.flatpak], { stdio: 'inherit', shell: false }).status === 0;
}

const listing = () => browsers.map((b, i) => `  ${i + 1}. ${b.name}${installed(b) ? ' (already installed)' : ''}`).join('\n');

// Accepts numbers from the list or browser IDs; "none" is ignored.
function resolve(tokens, picked, unknown) {
  for (const raw of tokens) {
    const token = raw.trim().toLowerCase();
    if (!token || token === 'none') continue;
    const byNumber = /^\d+$/.test(token) ? browsers[Number(token) - 1] : undefined;
    const b = byNumber || browsers.find(x => x.id === token);
    if (!b) { unknown.push(raw.trim()); continue; }
    if (!picked.includes(b)) picked.push(b);
  }
}

const args = process.argv.slice(2);
const apply = args.includes('--apply');
const extra = args.filter(a => a !== '--apply');
if (extra.length) { console.error('Unknown option: ' + extra.join(' ')); process.exit(2); }
if (!win && process.platform !== 'linux') { console.error('Unsupported platform'); process.exit(2); }

async function main() {
  if (!apply) {
    console.log('Browsers (choose on apply; Edge ships with Windows):');
    console.log(listing());
    console.log('Preview only. Browsers are installed only with --apply. Nothing was changed.');
    return 0;
  }
  const picked = [];
  const unknown = [];
  const envValue = process.env.ONECLICK_BROWSERS;
  if (envValue !== undefined && envValue.trim() !== '') {
    resolve(envValue.split(','), picked, unknown);
  } else if (process.stdin.isTTY) {
    console.log('Browsers:');
    console.log(listing());
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    const answer = await rl.question('Type the numbers of the browsers to install, separated by spaces, or press Enter for none: ');
    rl.close();
    resolve(answer.split(/\s+/), picked, unknown);
  }
  for (const u of unknown) console.warn('Ignored unknown browser: ' + u);
  if (!picked.length) {
    console.log('No browsers selected. Nothing was installed.');
    return 0;
  }
  const manager = win ? null : detectManager();
  const done = [];
  const skipped = [];
  const failed = [];
  for (const b of picked) {
    if (installed(b)) {
      skipped.push(b.name);
      console.log(b.name + ': already installed');
      continue;
    }
    console.log('Installing ' + b.name + '...');
    if (installBrowser(b, manager)) done.push(b.name);
    else failed.push(b.name);
  }
  console.log('\nBrowser summary: installed ' + done.length + ', already installed ' + skipped.length + ', failed ' + failed.length);
  if (failed.length) console.log('Failed: ' + failed.join(', '));
  return failed.length ? 1 : 0;
}

main().then(code => { process.exitCode = code; });
