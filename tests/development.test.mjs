import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const kit = fileURLToPath(new URL('../',import.meta.url));
const cli = (script,args,env={}) => spawnSync(process.execPath,[path.join(kit,'tools',script),...args],{encoding:'utf8',env:{...process.env,...env}});
test('approved profile contains 25 unique IDs, excludes backend tools',()=>{
  const m=JSON.parse(fs.readFileSync(path.join(kit,'profiles/development.json'),'utf8'));
  assert.equal(m.tools.length,25);
  assert.equal(new Set(m.tools.map(t=>t.id)).size,25);
  assert.ok(!m.tools.some(t=>['bruno','docker','adb','scrcpy','opentelemetry','curl'].includes(t.id)));
});
test('installer defaults to preview and rejects unknown selections',()=>{
  const p=cli('install-development.mjs',['vlc']);
  assert.equal(p.status,0);
  assert.match(p.stdout,/VLC/);
  assert.equal(cli('install-development.mjs',['--apply']).status,2);
  assert.equal(cli('install-development.mjs',['unknown']).status,2);
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
    assert.notEqual(cli('devcache.mjs',['clean',a,'target','--apply','--confirm-idle'],env).status,0);
    assert.ok(Object.values(state).every(p=>fs.existsSync(p.target)));
    assert.equal(cli('devcache.mjs',['deactivate',a],env).status,0);
    assert.notEqual(cli('devcache.mjs',['clean',a,'target','--apply','--confirm-idle'],env).status,0);
  } finally { fs.rmSync(temp,{recursive:true,force:true}); }
});
