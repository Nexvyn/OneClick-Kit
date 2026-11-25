import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';

const manifest = JSON.parse(fs.readFileSync(new URL('../profiles/development.json', import.meta.url), 'utf8'));
const policy = manifest.cachePolicy;
const GiB = 1024 ** 3;
const root = path.resolve(process.env.ONECLICK_CACHE_ROOT || (process.platform === 'win32'
  ? path.join(os.homedir(), 'Desktop', 'F-project', 'shared-cache')
  : path.join(os.homedir(), 'F-project', 'shared-cache')));
const stateDir = path.resolve(process.env.ONECLICK_STATE_DIR || path.join(os.homedir(), '.oneclick-kit'));
const stateFile = path.join(stateDir, 'projects.json');
const lockFile = path.join(stateDir, 'projects.lock');
const [action, input, ...rest] = process.argv.slice(2);
const now = () => Date.now();
const exists = p => fs.existsSync(p);
const hash = s => createHash('sha256').update(s).digest('hex');
const fail = message => { throw new Error(message); };

function readState() {
  if (!exists(stateFile)) return {};
  return JSON.parse(fs.readFileSync(stateFile, 'utf8'));
}
function writeState(state) {
  const tmp = stateFile + '.' + process.pid + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(state, null, 2) + '\n', {mode: 0o600});
  fs.renameSync(tmp, stateFile);
}
function projectInfo(input) {
  if (!input) fail('Pass an explicit project root.');
  const project = fs.realpathSync(input);
  if (!fs.statSync(project).isDirectory() || !['package.json','Cargo.toml','settings.gradle','settings.gradle.kts'].some(f => exists(path.join(project,f)))) fail('Not a recognized project root: ' + project);
  if (project === root || project.startsWith(root + path.sep)) fail('Project cannot be inside the cache.');
  const key = process.platform === 'win32' ? project.toLowerCase() : project;
  const id = hash(key).slice(0, 24);
  return {project,id,target:path.join(root,'cargo-targets',id)};
}
function size(target, seen = new Set()) {
  let total = 0;
  if (!exists(target)) return 0;
  const pending = [target];
  while (pending.length) {
    const p = pending.pop();
    let st;
    try { st = fs.lstatSync(p); } catch (e) { if (e.code === 'ENOENT') continue; throw e; }
    if (st.isSymbolicLink()) continue;
    if (st.isDirectory()) {
      for (const entry of fs.readdirSync(p)) pending.push(path.join(p,entry));
    } else if (st.isFile()) {
      const key = st.ino ? st.dev + ':' + st.ino : p;
      if (!seen.has(key)) { seen.add(key); total += st.size; }
    }
  }
  return total;
}
function showSize(bytes) { return (bytes / GiB).toFixed(2) + ' GiB'; }
function status(state, plan) {
  const seen = new Set();
  let total = size(root,seen);
  for (const p of Object.values(state)) {
    const deps = path.join(p.project,'node_modules');
    const depBytes = size(deps,seen);
    const targetBytes = size(p.target);
    total += depBytes;
    const idle = (now() - (p.lastActive || 0)) / 3600000;
    const held = p.active || p.pinned;
    console.log(p.project + ' | ' + (held ? 'active/pinned' : 'idle') + ' | dependencies ' + showSize(depBytes) + ' | Cargo ' + showSize(targetBytes));
    if (targetBytes >= policy.cargoWorkspaceWarning * GiB) console.log('  Cargo storage warning; target ' + policy.cargoWorkspaceRetention + ' GiB.');
    if (plan && !held && idle >= policy.idleDependenciesHours && exists(deps)) console.log('  REVIEW ONLY: ' + deps + ' (confirm all IDEs, builds and watches are stopped before manual cleanup)');
    if (plan && !held && idle >= policy.idleBuildHours && exists(p.target)) console.log('  REVIEW ONLY: ' + p.target + ' (retain required artifacts)');
  }
  console.log('Managed cache and registered dependencies (logical bytes, hardlinks deduplicated where identifiable): ' + showSize(total));
  if (total >= policy.aggregateWarning * GiB) console.log('Aggregate warning; retention target ' + policy.aggregateRetention + ' GiB.');
  if (typeof fs.statfsSync === 'function' && exists(root)) {
    const disk = fs.statfsSync(root);
    const free = disk.bavail * disk.bsize;
    console.log('Free space: ' + showSize(free));
    if (free < policy.minimumFree * GiB) console.log('Free space below recommended reserve.');
  }
}
function restore(project) {
  const files = [
    ['pnpm-lock.yaml','pnpm',['install','--frozen-lockfile','--prefer-offline']],
    ['package-lock.json','npm',['ci','--prefer-offline']],
    ['npm-shrinkwrap.json','npm',['ci','--prefer-offline']],
    ['yarn.lock','yarn',[]],
    ['bun.lock','bun',['install','--frozen-lockfile']],
    ['bun.lockb','bun',['install','--frozen-lockfile']]
  ].filter(([lock]) => exists(path.join(project, lock)));
  if (!exists(path.join(project,'package.json'))) return;
  if (exists(path.join(project,'node_modules')) || exists(path.join(project,'.pnp.cjs'))) {
    console.log('Existing dependencies retained; refresh explicitly with the project package manager if needed.');
    return;
  }
  if (files.length !== 1) fail('Select one lockfile before restoring dependencies.');
  const [,command,args] = files[0];
  if (command === 'yarn') {
    const pkg = JSON.parse(fs.readFileSync(path.join(project,'package.json'),'utf8'));
    const version = /^yarn@(\d+)/.exec(pkg.packageManager || '');
    if (!version) fail('Pin the Yarn major version in packageManager before restoring.');
    args.push('install', version[1] === '1' ? '--frozen-lockfile' : '--immutable');
  }
  // Only fixed commands and arguments are passed through cmd on Windows.
  const result = spawnSync(command, args, {cwd:project, stdio:'inherit', shell:process.platform === 'win32'});
  if (result.status !== 0) fail('Dependency restore failed. Existing lockfile was not intentionally changed.');
}
function main() {
  if (root === path.parse(root).root || root === os.homedir()) fail('Choose a dedicated cache directory.');
  if (action === 'status' || action === 'plan') { status(readState(),action === 'plan'); return; }
  if (!['activate','deactivate','pin','unpin','run','clean'].includes(action)) fail('Usage: devcache.mjs status|plan|activate|deactivate|pin|unpin|run|clean PROJECT [-- command args]');
  const info = projectInfo(input);
  fs.mkdirSync(stateDir,{recursive:true});
  let lock;
  try { lock = fs.openSync(lockFile,'wx',0o600); }
  catch { fail('Another project operation is active. If interrupted, verify it stopped before removing the lock.'); }
  try {
    const state = readState();
    const p = state[info.id] || {...info,active:false,pinned:false,lastActive:now()};
    if (p.target !== info.target) fail('Cache root changed; review the registered workspace before migrating its target.');
    if (action === 'clean') {
      if (!state[info.id] || p.active || p.pinned) fail('Project must be registered, inactive and unpinned.');
      if (rest.length !== 3 || !['deps','target'].includes(rest[0]) || rest[1] !== '--apply' || rest[2] !== '--confirm-idle') fail('Usage: clean PROJECT deps|target --apply --confirm-idle');
      const hours = rest[0] === 'deps' ? policy.idleDependenciesHours : policy.idleBuildHours;
      if (now() - p.lastActive < hours * 3600000) fail('Project has not reached the idle retention period.');
      const target = rest[0] === 'deps' ? path.join(info.project,'node_modules') : info.target;
      if (!exists(target)) { console.log('Nothing to clean'); return; }
      const st = fs.lstatSync(target);
      if (!st.isDirectory() || st.isSymbolicLink() || fs.realpathSync(target) !== target) fail('Refusing non-canonical or linked cleanup target.');
      if (rest[0] === 'deps') {
        const tracked = spawnSync('git',['ls-files','--','node_modules'],{cwd:info.project,encoding:'utf8'});
        if (tracked.status !== 0 || tracked.stdout.trim()) fail('Cannot establish that node_modules is untracked.');
        const lockfiles = ['pnpm-lock.yaml','package-lock.json','npm-shrinkwrap.json','yarn.lock','bun.lock','bun.lockb'];
        if (!lockfiles.some(f=>exists(path.join(info.project,f)))) fail('No lockfile; refusing to remove dependencies.');
      }
      // Explicit operator acknowledgement is required because external IDEs and processes are not controlled by this tool.
      // Refuse linked top-level directories; fs.rm unlinks nested symlinks rather than following them.
      fs.rmSync(target,{recursive:true,force:false});
      console.log('Removed reviewed generated directory: ' + target);
      return;
    }
    if (action === 'activate') { restore(info.project); p.active = true; p.lastActive = now(); }
    if (action === 'deactivate') { p.active = false; p.lastActive = now(); }
    if (action === 'pin') p.pinned = true;
    if (action === 'unpin') p.pinned = false;
    state[info.id] = p;
    writeState(state);
    if (action === 'run') {
      if (rest[0] !== '--' || rest.length < 2) fail('Usage: run PROJECT -- executable args');
      p.active = true; p.lastActive = now(); writeState(state);
      fs.mkdirSync(info.target,{recursive:true});
      console.log('Project Cargo target: ' + info.target);
      const result = spawnSync(rest[1],rest.slice(2),{cwd:info.project,stdio:'inherit',env:{...process.env,CARGO_TARGET_DIR:info.target},shell:false});
      p.lastActive = now(); writeState(state);
      if (result.error) fail(result.error.message);
      process.exitCode = result.status ?? 1;
    }
    console.log(info.project + ' | target ' + info.target);
  } finally { fs.closeSync(lock); fs.unlinkSync(lockFile); }
}
try { main(); } catch (error) { console.error(error.message); process.exitCode = 1; }
