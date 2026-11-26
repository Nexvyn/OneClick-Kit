// Shared Linux bootstrap helpers for the installers. Each step runs at most once per process.
import { spawnSync } from 'node:child_process';

const FLATHUB_URL = 'https://dl.flathub.org/repo/flathub.flatpakrepo';
const run = (cmd, args, quiet = false) => spawnSync(cmd, args, { encoding: 'utf8', stdio: quiet ? 'pipe' : 'inherit', shell: false });
const exists = cmd => run('which', [cmd], true).status === 0;

// Non-interactive install commands for each supported distribution package manager.
const packageArgs = {
  'apt-get': ['apt-get', 'install', '-y'],
  dnf: ['dnf', 'install', '-y'],
  pacman: ['pacman', '-S', '--needed', '--noconfirm'],
  zypper: ['zypper', 'install', '-y'],
};

export function detectManager() {
  return ['apt-get', 'dnf', 'pacman', 'zypper'].find(exists) ?? null;
}

let aptRefreshed = null;
// Fresh Ubuntu has stale package lists, so refresh them once before the first apt-get use.
export function ensureAptUpdated() {
  if (aptRefreshed === null) {
    console.log('Refreshing apt package lists: sudo apt-get update');
    aptRefreshed = run('sudo', ['apt-get', 'update']).status === 0;
    if (!aptRefreshed) console.error('apt-get update failed; continuing with the existing package lists.');
  }
  return aptRefreshed;
}

let flatpakReady = null;
// Installs Flatpak with the detected package manager when it is missing, then adds Flathub for the user.
export function ensureFlatpak(manager) {
  if (flatpakReady !== null) return flatpakReady;
  if (!exists('flatpak')) {
    if (!packageArgs[manager]) {
      console.error('Flatpak is missing and no supported package manager was found.');
      flatpakReady = false;
      return flatpakReady;
    }
    if (manager === 'apt-get') ensureAptUpdated();
    console.log('Installing Flatpak with ' + manager + '.');
    if (run('sudo', [...packageArgs[manager], 'flatpak']).status !== 0) {
      console.error('Flatpak could not be installed.');
      flatpakReady = false;
      return flatpakReady;
    }
  }
  flatpakReady = run('flatpak', ['remote-add', '--user', '--if-not-exists', 'flathub', FLATHUB_URL]).status === 0;
  if (!flatpakReady) console.error('Flathub could not be added to Flatpak.');
  return flatpakReady;
}

// Installs one distribution package; returns true on success.
export function installSystemPackage(manager, name) {
  if (!packageArgs[manager]) return false;
  if (manager === 'apt-get') ensureAptUpdated();
  return run('sudo', [...packageArgs[manager], name]).status === 0;
}
