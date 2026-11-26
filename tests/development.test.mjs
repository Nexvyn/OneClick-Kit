import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const kit = fileURLToPath(new URL('../',import.meta.url));
const cli = (script,args,env={}) => spawnSync(process.execPath,[path.join(kit,'tools',script),...args],{encoding:'utf8',env:{...process.env,...env}});
test('approved profile contains 50 unique IDs, excludes backend tools',()=>{
  const m=JSON.parse(fs.readFileSync(path.join(kit,'profiles/development.json'),'utf8'));
  assert.equal(m.tools.length,50);
  assert.equal(new Set(m.tools.map(t=>t.id)).size,50);
  assert.ok(!m.tools.some(t=>['bruno','docker','adb','scrcpy','opentelemetry','curl'].includes(t.id)));
});
test('installer defaults to preview and rejects unknown selections',()=>{
  const p=cli('install-development.mjs',['vlc']);
  assert.equal(p.status,0);
  assert.match(p.stdout,/VLC/);
  assert.equal(cli('install-development.mjs',['--apply']).status,2);
  assert.equal(cli('install-development.mjs',['unknown']).status,2);
  assert.equal(cli('install-development.mjs',['--all','vlc']).status,2);
  assert.equal(cli('install-development.mjs',['--all','--apply','--dry-run']).status,2);
  assert.equal(cli('install-development.mjs',['--all']).status,0);
});
test('project targets are distinct, status and plan are nonmutating, active cleanup refused',()=>{
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'oneclick-test-'));
  try {
    const env={ONECLICK_CACHE_ROOT:path.join(temp,'cache'),ONECLICK_STATE_DIR:path.join(temp,'state')};
    const a=path.join(temp,'a'), b=path.join(temp,'b');
    for(const p of [a,b]){fs.mkdirSync(p);fs.writeFileSync(path.join(p,'Cargo.toml'),'[package]\nname="test"\nversion="0.1.0"\n');}
    const run=p=>cli('devcache.mjs',['run',p,'--',process.execPath,'-e','console.log(process.env.CARGO_TARGET_DIR)'],env);
    const ra=run(a),rb=run(b);
    assert.equal(ra.status,0,ra.stderr);assert.equal(rb.status,0,rb.stderr);
    const state=JSON.parse(fs.readFileSync(path.join(temp,'state','projects.json'),'utf8'));
    assert.equal(new Set(Object.values(state).map(p=>p.target)).size,2);
    assert.equal(cli('devcache.mjs',['status'],env).status,0);
    assert.equal(cli('devcache.mjs',['plan'],env).status,0);
    assert.equal(cli('devcache.mjs',['clean-idle'],env).status,0);
    assert.notEqual(cli('devcache.mjs',['clean-idle','--apply'],env).status,0);
    assert.notEqual(cli('devcache.mjs',['clean',a,'target','--apply','--confirm-idle'],env).status,0);
    assert.ok(Object.values(state).every(p=>fs.existsSync(p.target)));
    assert.equal(cli('devcache.mjs',['deactivate',a],env).status,0);
    assert.notEqual(cli('devcache.mjs',['clean',a,'target','--apply','--confirm-idle'],env).status,0);
    const registry=path.join(temp,'state','projects.json');
    const idle=JSON.parse(fs.readFileSync(registry,'utf8'));
    const entry=Object.values(idle).find(p=>p.project===a);
    entry.lastActive=Date.now()-49*3600000;
    fs.writeFileSync(registry,JSON.stringify(idle));
    const preview=cli('devcache.mjs',['clean-idle'],env);
    assert.equal(preview.status,0,preview.stderr);
    assert.match(preview.stdout,/REVIEW:/);
    assert.ok(fs.existsSync(entry.target));
  } finally { fs.rmSync(temp,{recursive:true,force:true}); }
});

test('clean-idle --unattended removes an idle project target and keeps an active one',()=>{
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'oneclick-unattended-test-'));
  try {
    const env={ONECLICK_CACHE_ROOT:path.join(temp,'cache'),ONECLICK_STATE_DIR:path.join(temp,'state')};
    const idleProject=path.join(temp,'idle'), activeProject=path.join(temp,'active');
    for(const p of [idleProject,activeProject]){fs.mkdirSync(p);fs.writeFileSync(path.join(p,'Cargo.toml'),'[package]\nname="test"\nversion="0.1.0"\n');}
    const run=p=>cli('devcache.mjs',['run',p,'--',process.execPath,'-e','console.log(process.env.CARGO_TARGET_DIR)'],env);
    assert.equal(run(idleProject).status,0);
    assert.equal(run(activeProject).status,0);
    const registry=path.join(temp,'state','projects.json');
    const state=JSON.parse(fs.readFileSync(registry,'utf8'));
    const idle=Object.values(state).find(p=>p.project===fs.realpathSync(idleProject));
    const active=Object.values(state).find(p=>p.project===fs.realpathSync(activeProject));
    assert.ok(idle&&active);
    idle.active=false;
    idle.lastActive=Date.now()-49*3600000;
    fs.writeFileSync(registry,JSON.stringify(state));
    const cleaned=cli('devcache.mjs',['clean-idle','--unattended'],env);
    assert.equal(cleaned.status,0,cleaned.stderr);
    assert.match(cleaned.stdout,/Removed /);
    assert.ok(!fs.existsSync(idle.target));
    assert.ok(fs.existsSync(active.target));
  } finally { fs.rmSync(temp,{recursive:true,force:true}); }
});

test('clean-idle --unattended with no state file exits 0 and cleans nothing',()=>{
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'oneclick-empty-test-'));
  try {
    const env={ONECLICK_CACHE_ROOT:path.join(temp,'cache'),ONECLICK_STATE_DIR:path.join(temp,'state')};
    const r=cli('devcache.mjs',['clean-idle','--unattended'],env);
    assert.equal(r.status,0,r.stderr);
    assert.match(r.stdout,/Nothing needs cleaning/);
  } finally { fs.rmSync(temp,{recursive:true,force:true}); }
});

test('same-named projects get readable Cargo targets and keep them across runs',()=>{
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'oneclick-name-test-'));
  try {
    const cache=path.join(temp,'cache');
    const env={ONECLICK_CACHE_ROOT:cache,ONECLICK_STATE_DIR:path.join(temp,'state')};
    const first=path.join(temp,'x','app'), second=path.join(temp,'y','app');
    for(const p of [first,second]){fs.mkdirSync(p,{recursive:true});fs.writeFileSync(path.join(p,'Cargo.toml'),'[package]\nname="app"\nversion="0.1.0"\n');}
    const run=p=>cli('devcache.mjs',['run',p,'--',process.execPath,'-e','console.log(process.env.CARGO_TARGET_DIR)'],env);
    // The wrapped command prints its CARGO_TARGET_DIR; devcache's own output always starts with the project path.
    const targetOf=r=>{assert.equal(r.status,0,r.stderr);return r.stdout.split(/\r?\n/).find(l=>l.startsWith(cache));};
    const a=targetOf(run(first)), b=targetOf(run(second));
    assert.equal(a,path.join(cache,'cargo-targets','app','target'));
    assert.equal(path.basename(b),'target');
    assert.equal(path.dirname(path.dirname(b)),path.join(cache,'cargo-targets'));
    assert.match(path.basename(path.dirname(b)),/^app-[0-9a-f]{6}$/);
    assert.equal(targetOf(run(first)),a);
  } finally { fs.rmSync(temp,{recursive:true,force:true}); }
});

test('unified Linux launcher is preview-first and rejects unattended apply',()=>{
  if (process.platform !== 'linux') return;
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'oneclick-launcher-test-'));
  try {
    const env={...process.env,ONECLICK_CACHE_ROOT:path.join(temp,'cache'),ONECLICK_STATE_DIR:path.join(temp,'state')};
    const launch=args=>spawnSync('bash',[path.join(kit,'linux/oneclick.sh'),...args],{encoding:'utf8',env});
    const preview=launch([]);
    assert.equal(preview.status,0,preview.stderr);
    assert.match(preview.stdout,/Nothing was changed/);
    assert.equal(launch(['update']).status,0);
    assert.notEqual(launch(['all','--apply']).status,0);
    assert.notEqual(launch(['--dry-run','--apply']).status,0);
    assert.ok(!fs.existsSync(path.join(temp,'cache')));
    assert.ok(!fs.existsSync(path.join(temp,'state')));
  } finally { fs.rmSync(temp,{recursive:true,force:true}); }
});

test('expanded profile previews selected AI CLIs and preserves project-local tools',()=>{
  const p=cli('install-development.mjs',['--all']);
  assert.equal(p.status,0,p.stderr);
  for(const name of ['Claude Code CLI','Codex CLI','OpenCode CLI','Antigravity CLI','GitHub Copilot CLI','Gradle Wrapper','Handy']) assert.ok(p.stdout.includes(name));
  assert.match(p.stdout,/Vitest: project/);
  assert.ok(!p.stdout.includes('Raycast'));
});

test('browser chooser lists the six browsers and installs nothing when none is selected',()=>{
  const p=cli('browsers.mjs',[]);
  assert.equal(p.status,0,p.stderr);
  for(const name of ['Google Chrome','Mozilla Firefox','Brave','Microsoft Edge','Opera','Vivaldi']) assert.ok(p.stdout.includes(name));
  const none=cli('browsers.mjs',['--apply'],{ONECLICK_BROWSERS:'none'});
  assert.equal(none.status,0,none.stderr);
  assert.match(none.stdout,/Nothing was installed/);
  assert.ok(!/Installing /.test(none.stdout));
});

// Debloat data: the profile must parse and must never offer a protected item.
const debloatProfile = JSON.parse(fs.readFileSync(path.join(kit,'profiles/debloat.json'),'utf8'));
const debloatWin = debloatProfile.windows;
const BS = String.fromCharCode(92);
const escapeRe = ch => BS + ch;
// Case-insensitive wildcard match where * matches any run of characters.
const wildcardLike = (name,pattern) => {
  const source = pattern.split('*').map(part=>part.replace(/[^A-Za-z0-9]/g, escapeRe)).join('.*');
  return new RegExp('^'+source+'$','i').test(name);
};
const coreOf = pattern => pattern.split('*').join('');
const neverMatches = name => debloatWin.never.some(p=>wildcardLike(name,p));

test('debloat profile parses and its Windows apps are all marked yes',()=>{
  assert.ok(Array.isArray(debloatWin.apps)&&debloatWin.apps.length>0);
  assert.ok(Array.isArray(debloatWin.askGroups)&&debloatWin.askGroups.length>0);
  for(const app of debloatWin.apps) assert.equal(app.mark,'yes',app.name);
});

test('debloat never removes protected packages (apps, ask groups and promo patterns)',()=>{
  const names=[];
  for(const app of debloatWin.apps) names.push(...app.packages);
  for(const group of debloatWin.askGroups) names.push(...(group.packages||[]));
  for(const promo of debloatWin.promo) names.push(...promo.patterns.map(coreOf));
  for(const name of names) assert.ok(!neverMatches(name),'protected item offered: '+name);
  for(const promo of debloatWin.promo) for(const p of promo.patterns) {
    for(const n of debloatWin.never) assert.ok(!wildcardLike(coreOf(n),p),p+' overlaps never entry '+n);
  }
});

test('debloat never list protects the required system apps',()=>{
  for(const name of ['Microsoft.EdgeWebView2Runtime','Microsoft.WindowsCalculator','Microsoft.Paint','Microsoft.WindowsStore']) {
    assert.ok(debloatWin.never.includes(name),name);
  }
});
