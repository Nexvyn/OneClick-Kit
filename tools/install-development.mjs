import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';

const {tools} = JSON.parse(readFileSync(new URL('../profiles/development.json', import.meta.url), 'utf8'));
// Deliberately limited to exact package identifiers. Everything else is a manual or project-specific step.
const winget = {
  cursor:'Anysphere.Cursor', 'github-cli':'GitHub.cli', nodejs:'OpenJS.NodeJS.LTS',
  discord:'Discord.Discord', vlc:'VideoLAN.VLC', '7zip':'7zip.7zip',
  localsend:'LocalSend.LocalSend', ffmpeg:'Gyan.FFmpeg', figma:'Figma.Figma',
  notion:'Notion.Notion', wiztree:'AntibodySoftware.WizTree', syncthing:'Syncthing.Syncthing'
};
const apt = {'github-cli':'gh',vlc:'vlc','7zip':'7zip',ffmpeg:'ffmpeg',syncthing:'syncthing'};
const flags = process.argv.slice(2);
const apply = flags.includes('--apply');
const all = flags.includes('--all');
const ids = flags.filter(a => !['--apply','--dry-run','--all'].includes(a));
if (all && ids.length) { console.error('Use --all or selected IDs, not both.'); process.exit(2); }
if (apply && (flags.includes('--dry-run') || (!ids.length && !all))) {
  console.error('Pass explicit tool IDs or --all with --apply. Do not combine with --dry-run.');
  process.exit(2);
}
const known = new Set(tools.map(t=>t.id));
if (ids.some(id=>!known.has(id))) { console.error('Unknown tool ID'); process.exit(2); }
if (!['win32','linux'].includes(process.platform)) { console.error('Unsupported platform'); process.exit(2); }
const selected = tools.filter(t => !ids.length || ids.includes(t.id));
const isWin = process.platform === 'win32';
const pkg = isWin ? winget : apt;
const run = (cmd,args,quiet=false) => spawnSync(cmd,args,{encoding:'utf8',stdio:quiet?'pipe':'inherit',shell:false});
let failures = 0;
for (const t of selected) {
  if (t.desktopPlatforms && !t.desktopPlatforms.includes(process.platform)) {
    console.log(t.name + ': ' + (t.alternative || 'not available') + ' (' + t.url + ')'); continue;
  }
  if (!Object.hasOwn(pkg,t.id)) { console.log(t.name + ': manual/project-specific (' + t.url + ')'); continue; }
  const id = pkg[t.id];
  const cmd = isWin ? 'winget' : 'apt-get';
  const args = isWin ? ['install','--id',id,'--exact','--source','winget'] : ['install',id];
  if (!apply) { console.log(t.name + ': ' + (isWin ? '' : 'sudo ') + [cmd,...args].join(' ')); continue; }
  if (isWin) {
    const installed = run('winget',['list','--id',id,'--exact','--source','winget'],true);
    if (installed.status === 0 && installed.stdout.includes(id)) { console.log(t.name + ': already installed'); continue; }
    const found = run('winget',['show','--id',id,'--exact','--source','winget'],true);
    if (found.status !== 0) { console.error(t.name + ': package unavailable; use ' + t.url); failures++; continue; }
  } else {
    const installed = run('dpkg-query',['-W','-f=${Status}',id],true);
    if (installed.status === 0 && installed.stdout.trim() === 'install ok installed') { console.log(t.name + ': already installed'); continue; }
    const found = run('apt-cache',['show',id],true);
    if (found.status !== 0 || !found.stdout.trim()) { console.error(t.name + ': package unavailable; use ' + t.url); failures++; continue; }
  }
  const result = isWin ? run(cmd,args) : run('sudo',[cmd,...args]);
  if (result.status !== 0) { console.error(t.name + ': installation did not complete'); failures++; }
}
if (failures) process.exitCode = 1;
