// Read-only installation plan. No downloads, installs or configuration changes.
import { readFileSync } from 'node:fs';

const manifest = JSON.parse(readFileSync(new URL('../profiles/development.json', import.meta.url), 'utf8'));
const args = process.argv.slice(2);
const known = new Set(manifest.tools.map(tool => tool.id));
const selected = args.length ? new Set(args) : known;
for (const id of selected) {
  if (!known.has(id)) {
    console.error('Unknown tool: ' + id);
    process.exit(2);
  }
}
for (const tool of manifest.tools) {
  if (!selected.has(tool.id)) continue;
  const supported = !tool.desktopPlatforms || tool.desktopPlatforms.includes(process.platform);
  const mode = supported ? tool.kind : (tool.alternative || 'not available');
  console.log(tool.name + ' | ' + mode + ' | ' + tool.url);
}
console.log('\nCache retention targets (GiB; soft limits):');
console.log(JSON.stringify(manifest.cachePolicy, null, 2));
