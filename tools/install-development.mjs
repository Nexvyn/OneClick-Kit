import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { ensureAptUpdated, ensureFlatpak } from './linux-setup.mjs';

const {tools} = JSON.parse(readFileSync(new URL('../profiles/development.json', import.meta.url), 'utf8'));
const winget = {
  cursor:'Anysphere.Cursor','github-cli':'GitHub.cli',nodejs:'OpenJS.NodeJS.LTS',
  discord:'Discord.Discord',vlc:'VideoLAN.VLC','7zip':'7zip.7zip',localsend:'LocalSend.LocalSend',
  ffmpeg:'Gyan.FFmpeg',figma:'Figma.Figma',notion:'Notion.Notion',wiztree:'AntibodySoftware.WizTree',
  syncthing:'Syncthing.Syncthing',git:'Git.Git',rustup:'Rustlang.Rustup',sccache:'Mozilla.sccache',
  bun:'Oven-sh.Bun',deno:'DenoLand.Deno',python:'Python.Python.3.13',uv:'astral-sh.uv',
  jdk:'EclipseAdoptium.Temurin.21.JDK',swift:'Swift.Toolchain',
  'vs-build-tools':'Microsoft.VisualStudio.2022.BuildTools','windows-sdk':'Microsoft.WindowsSDK.10.0.26100',
  webview2:'Microsoft.EdgeWebView2Runtime','yt-dlp':'yt-dlp.yt-dlp',powershell:'Microsoft.PowerShell',
  handy:'cjpais.Handy','windows-terminal':'Microsoft.WindowsTerminal',crystaldiskinfo:'CrystalDewWorld.CrystalDiskInfo',
  'claude-code':'Anthropic.ClaudeCode',helium:'ImputNet.Helium',kotlin:'JetBrains.Kotlin'
};
const apt = {cursor:'cursor','github-cli':'gh',vlc:'vlc','7zip':'7zip',ffmpeg:'ffmpeg',syncthing:'syncthing',
  git:'git',nodejs:'nodejs',python:'python3',jdk:'openjdk-21-jdk',sccache:'sccache','yt-dlp':'yt-dlp',
  rustup:'rustup',uv:'uv',kotlin:'kotlin',powershell:'powershell',discord:'discord',deno:'deno',bun:'bun'};
const dnf = {...apt,'7zip':'7zip',jdk:'java-21-openjdk-devel',python:'python3'};
const pacman = {...apt,'7zip':'7zip',jdk:'jdk21-openjdk','github-cli':'github-cli',python:'python',uv:'uv'};
const zypper = {...apt,jdk:'java-21-openjdk-devel',python:'python3'};
const npm = {moon:'@moonrepo/cli',codex:'@openai/codex',opencode:'@opencode/cli',copilot:'@github/copilot',
  pnpm:'pnpm',yarn:'yarn@1','claude-code':'@anthropic-ai/claude-code',bun:'bun',deno:'deno'};
const flatpak = {discord:'com.discordapp.Discord',vlc:'org.videolan.VLC',localsend:'org.localsend.localsend_app',
  handy:'com.pais.handy',helium:'net.imput.helium'};
const probes = {nodejs:'node',git:'git','github-cli':'gh',moon:'moon',rustup:'rustup',sccache:'sccache',
  pnpm:'pnpm',yarn:'yarn',bun:'bun',deno:'deno',python:'python',uv:'uv',jdk:'javac',swift:'swift',
  kotlin:'kotlinc',ffmpeg:'ffmpeg','yt-dlp':'yt-dlp',powershell:'pwsh','claude-code':'claude',
  codex:'codex',opencode:'opencode',copilot:'copilot',antigravity:'agy',syncthing:'syncthing',maestro:'maestro'};
const flags = process.argv.slice(2);
const apply = flags.includes('--apply'), all = flags.includes('--all');
const ids = flags.filter(a=>!['--apply','--dry-run','--all'].includes(a));
if ((all && ids.length) || (apply && (flags.includes('--dry-run') || (!ids.length && !all)))) {
  console.error('Use --all or selected IDs; apply must be explicit and cannot be combined with dry-run.'); process.exit(2);
}
if (ids.some(id=>!tools.some(t=>t.id===id))) { console.error('Unknown tool ID'); process.exit(2); }
if (!['win32','linux'].includes(process.platform)) { console.error('Unsupported platform'); process.exit(2); }
const win = process.platform==='win32';
const run = (cmd,args,quiet=false) => spawnSync(cmd,args,{encoding:'utf8',stdio:quiet?'pipe':'inherit',shell:false});
const has = cmd => run(win?'where.exe':'which',[cmd],true).status===0;
// On Windows, python is only "present" when where.exe finds a real install outside the Store stub folder.
const hasWindowsPython = cmd => {
  const found = run('where.exe',[cmd],true);
  if (found.status!==0) return false;
  return String(found.stdout||'').split(/\r?\n/).some(line=>line.trim()&&!/\\WindowsApps\\/i.test(line));
};
const present = cmd => win&&(cmd==='python'||cmd==='python3') ? hasWindowsPython(cmd) : has(cmd);
const npmRun = (args,quiet=false) => win
  ? run('cmd.exe',['/d','/s','/c','npm.cmd '+args.join(' ')],quiet)
  : run('npm',args,quiet);
const managers = [['apt-get',apt],['dnf',dnf],['pacman',pacman],['zypper',zypper]];
const manager = win?null:managers.find(([cmd])=>has(cmd));
const priority = ['git','nodejs','python','jdk','rustup','vs-build-tools','windows-sdk','webview2'];
const selected = tools.filter(t=>!ids.length||ids.includes(t.id)).sort((a,b)=>
  (priority.includes(a.id)?priority.indexOf(a.id):99)-(priority.includes(b.id)?priority.indexOf(b.id):99));
const result = {installed:[],existing:[],deferred:[],failed:[]};
function report(t,status,detail) { result[status].push(t.name); console.log(t.name+': '+detail); }
function native(t) {
  const id=winget[t.id];
  if (!id || !has('winget')) return null;
  const installed=run('winget',['list','--id',id,'--exact','--source','winget','--accept-source-agreements'],true);
  if(installed.status===0&&installed.stdout.includes(id)) return 'existing';
  if (run('winget',['show','--id',id,'--exact','--source','winget','--accept-source-agreements'],true).status!==0) return null;
  const args=['install','--id',id,'--exact','--source','winget','--accept-source-agreements','--accept-package-agreements'];
  if(t.id==='vs-build-tools') args.push('--override','--passive --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended');
  return run('winget',args).status===0?'installed':'failed';
}
function distro(t) {
  if (!manager) return null;
  const [cmd,map]=manager,id=map[t.id]; if(!id) return null;
  const check=cmd==='apt-get'?['dpkg-query',['-W','-f=${Status}',id]]:cmd==='pacman'?['pacman',['-Q',id]]:['rpm',['-q',id]];
  const installed=run(...check,true);
  if(installed.status===0&&(cmd!=='apt-get'||installed.stdout.trim()==='install ok installed')) return 'existing';
  if(cmd==='apt-get') ensureAptUpdated();
  const query=cmd==='apt-get'?['apt-cache',['show',id]]:cmd==='pacman'?['pacman',['-Si',id]]:cmd==='dnf'?['dnf',['info',id]]:['zypper',['info',id]];
  const found=run(...query,true); if(found.status!==0||!found.stdout.trim()) return null;
  const args=cmd==='pacman'?['-S','--needed',id]:['install',id];
  return run('sudo',[cmd,...args]).status===0?'installed':'failed';
}
const releases = {
  traycer:'traycerai/traycer', handy:'cjpais/Handy', helium:'imputnet/helium-linux',
  powershell:'PowerShell/PowerShell'
};
function releasePattern(t) {
  const arm=process.arch==='arm64', x64=process.arch==='x64';
  if(!arm&&!x64) return null;
  if(win) return t.id==='traycer'&&x64?/^traycer-desktop-windows-x64\.msi$/:null;
  const deb=manager?.[0]==='apt-get', rpm=['dnf','zypper'].includes(manager?.[0]);
  if(t.id==='traycer') return deb?new RegExp('^traycer-desktop-linux-'+(arm?'arm64':'amd64')+'\\.deb$'):rpm&&x64?/^traycer-desktop-linux-x86_64\.rpm$/:null;
  if(t.id==='handy') return deb?new RegExp('^Handy_.*_'+(arm?'arm64':'amd64')+'\\.deb$'):rpm?new RegExp('^Handy-.*\\.'+(arm?'aarch64':'x86_64')+'\\.rpm$'):null;
  if(t.id==='helium') return deb?new RegExp('^helium-bin_.*_'+(arm?'arm64':'amd64')+'\\.deb$'):null;
  if(t.id==='powershell') return deb?new RegExp('^powershell_.*_'+(arm?'arm64':'amd64')+'\\.deb$'):rpm&&x64?/^powershell-.*\.rh\.x86_64\.rpm$/:null;
  return null;
}
async function release(t) {
  const repo=releases[t.id], pattern=releasePattern(t);
  if(!repo||!pattern) return null;
  const temp=mkdtempSync(join(tmpdir(),'oneclick-release-'));
  try {
    const meta=await fetch('https://api.github.com/repos/'+repo+'/releases/latest',{signal:AbortSignal.timeout(30000)});
    if(!meta.ok) throw Error('Release metadata unavailable');
    const data=await meta.json();
    const asset=data.assets.find(a=>pattern.test(a.name)&&/^sha256:[a-f0-9]{64}$/i.test(a.digest||''));
    if(!asset) return null;
    const url=new URL(asset.browser_download_url);
    if(url.origin!=='https://github.com'||!url.pathname.startsWith('/'+repo+'/releases/download/')) throw Error('Unexpected release URL');
    const response=await fetch(url,{signal:AbortSignal.timeout(300000)});
    if(!response.ok) throw Error('Release download failed');
    const bytes=Buffer.from(await response.arrayBuffer());
    if('sha256:'+createHash('sha256').update(bytes).digest('hex')!==asset.digest.toLowerCase()) throw Error('Release checksum mismatch');
    const file=join(temp,asset.name);writeFileSync(file,bytes);
    const install=win?run('msiexec.exe',['/i',file,'/passive','/norestart']):run('sudo',[manager[0],'install',file]);
    return [0,3010].includes(install.status)?'installed':'failed';
  } catch(e) {console.error(t.name+': '+e.message);return 'failed';}
  finally {rmSync(temp,{recursive:true,force:true});}
}
async function vendor(t) {
  // Fixed publisher-owned sources only. Save the installer to disk before running it.
  // Never pipe network content into a shell or relax execution policy.
  const sources={antigravity:win?'https://antigravity.google/cli/install.cmd':'https://antigravity.google/cli/install.sh',...(!win?{uv:'https://astral.sh/uv/install.sh',rustup:'https://sh.rustup.rs',maestro:'https://get.maestro.mobile.dev'}:{})};
  const url=sources[t.id]; if(!url) return null;
  const temp=mkdtempSync(join(tmpdir(),'oneclick-vendor-'));
  try {
    const response=await fetch(url,{signal:AbortSignal.timeout(60000)});
    if(!response.ok || new URL(response.url).protocol!=='https:') throw Error('Publisher download failed');
    const file=join(temp,win?'install.cmd':'install.sh');
    writeFileSync(file,Buffer.from(await response.arrayBuffer()));
    return (win?run('cmd.exe',['/d','/c',file]):run('bash',[file,...(t.id==='rustup'?['-y']:[])])).status===0?'installed':'failed';
  } catch(e) { console.error(t.name+': '+e.message); return 'failed'; }
  finally {rmSync(temp,{recursive:true,force:true});}
}
for(const t of selected) {
  if(t.desktopPlatforms&&!t.desktopPlatforms.includes(process.platform)) {
    report(t,'deferred',t.alternative||'not available on this OS'); continue;
  }
  if(['project','remote','on-demand'].includes(t.kind)) {
    report(t,'deferred',t.kind+' (use project lockfile or service; no global install)'); continue;
  }
  const routes=[win?winget[t.id]&&'WinGet '+winget[t.id]:manager?.[1][t.id]&&manager[0]+' '+manager[1][t.id],npm[t.id]&&'npm '+npm[t.id],!win&&flatpak[t.id]&&'Flatpak '+flatpak[t.id],releases[t.id]&&releasePattern(t)&&'verified GitHub release',(t.id==='antigravity'||(!win&&['uv','rustup','maestro'].includes(t.id)))&&'official publisher installer'].filter(Boolean);
  if(!apply) {console.log(t.name+': '+(routes.join(' / ')||'official setup required')+' ('+t.url+')');continue;}
  if(t.id==='opencode'&&has('opencode')) {
    const version=run(win?'cmd.exe':'opencode',win?['/d','/c','opencode --version']:['--version'],true);
    if(!/(?:^|\s)[2-9]\d*\.\d+/.test(version.stdout||'')) {report(t,'deferred','existing OpenCode version needs review before replacing it');continue;}
  }
  if(probes[t.id]&&present(probes[t.id])) {report(t,'existing','already on PATH');continue;}
  if(t.id==='python'&&!win&&has('python3')) {report(t,'existing','Python 3 already on PATH');continue;}
  if(t.id==='nodejs') {report(t,'existing','using the Node runtime running this installer');continue;}
  let status=win?native(t):distro(t);
  if(!status&&npm[t.id]&&has('npm')) {
    const found=npmRun(['list','-g','--depth=0',npm[t.id]],true);
    status=found.status===0?'existing':npmRun(['install','-g',npm[t.id]]).status===0?'installed':'failed';
  }
  if(!status&&!win&&flatpak[t.id]&&ensureFlatpak(manager?.[0])) {
    const id=flatpak[t.id];
    if(run('flatpak',['info',id],true).status===0) status='existing';
    else if(run('flatpak',['remote-info','flathub',id],true).status===0)
      status=run('flatpak',['install','--user','flathub',id]).status===0?'installed':'failed';
  }
  if(!status) status=await release(t);
  if(!status) status=await vendor(t);
  if(status) report(t,status,status==='failed'?'installation failed; see '+t.url:status);
  else report(t,'deferred','no supported automatic source on this machine; see '+t.url);
}
if(apply) {
  console.log('\nInstallation summary: '+JSON.stringify(result,null,2));
  if(result.failed.length) process.exitCode=1;
}
