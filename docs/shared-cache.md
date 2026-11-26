# Shared development cache

Share downloaded packages and eligible compiler outputs, not a single mutable build directory. Cache files are regenerable, but never remove them during active work or without review.

Run the existing setup script, then reopen the terminal. The setup configures separate npm, pnpm, modern Yarn, Bun, pip and uv caches, plus Gradle, Playwright and Puppeteer download locations. Existing Cargo registry/Git downloads remain in Cargo home. Keep the cache on the same filesystem as projects for pnpm linking. The setup no longer sets a single global Cargo target; it preserves the old directory for manual review. If a custom legacy CARGO_TARGET_DIR remains, remove or adjust it yourself after verifying its origin.

## Project lifecycle

With Node.js installed, use the following commands from the kit (substitute your actual workspace path):

```sh
node tools/devcache.mjs activate /path/to/project
node tools/devcache.mjs run /path/to/project -- cargo build
node tools/devcache.mjs status
node tools/devcache.mjs deactivate /path/to/project
node tools/devcache.mjs plan
```

The run command gives each canonical workspace or worktree its own target directory at `shared-cache/cargo-targets/<project>/target`, named after the project folder. If two projects share a folder name, the second gets `<project>-<6 hex chars>`; a registered project keeps its folder. Use the actual Cargo workspace root (not a member crate). A plain Cargo invocation uses its existing configuration; configure your IDE tasks to use the wrapper if you want the centralized project-specific directory. Existing project configuration is not rewritten. If a project overrides Cargo's intermediate build directory, review it separately.

Activate restores missing dependencies using the existing lockfile and package manager; existing installations are preserved. Pin/unpin controls retention. Deactivate only after stopping external IDEs, builds, tests and watchers. The registry tracks cooperating commands, not all processes. The run wrapper holds a lock until the child command exits.

Status reports logical sizes, deduplicating identifiable hardlinks, and warns at the configured budgets. It is not an exact physical allocation measurement. Plan lists idle candidates without modifying data. The cleanup command is deliberately manual:

```sh
node tools/devcache.mjs clean /path/to/project deps --apply --confirm-idle
node tools/devcache.mjs clean /path/to/project target --apply --confirm-idle
```

Only use it after checking that all external processes have stopped, the directory has no manual edits, and any required release artifacts are backed up. It refuses active/pinned projects, recent projects, linked top-level directories and tracked dependencies. The scheduled Auto-clean (see the main README) runs `clean-idle --unattended`, which keeps every one of these checks and only removes outputs of idle, unpinned projects.

## Retention policy

25 GiB warning; 35 GiB total retention target; aim for 40 GiB free. Cargo per workspace: warning at 4 GiB, target 5 GiB. Shared sccache: 5 GiB. Idle dependencies are eligible after 24 hours; build outputs after 48 hours. Allow exceptions for active builds. These are soft limits, not quotas.

The clean operation prunes or clears package downloads as listed under bulk idle cleanup. Review space and dependencies before running it. Keep different operating systems and toolchains isolated, and do not sync live caches.

## Rules for AI agents

- Keep projects on the same drive as the shared cache. pnpm hard links do not work across drives; pnpm then copies files and wastes space.
- Never delete the shared cache or anything in it without asking the owner.
- Do not create a per-project `.pnpm-store`, and do not set `target-dir` in a project's `.cargo/config.toml`. Use `devcache run` so the project gets its own folder under `cargo-targets`.
- Do not set `CARGO_TARGET_DIR`, `GRADLE_USER_HOME`, `TMP` or `TEMP` for a single command; the setup already points them to the right place.
- To convert a project to pnpm, use [convert-project-prompt.md](convert-project-prompt.md).

## If the cache folder is moved

Run the setup again with the new path, then open a new terminal and run `pnpm install` in each project:

```sh
windows\install\setup_shared_cache.bat "D:\new\path\shared-cache"
bash linux/install/setup_shared_cache.sh /new/path/shared-cache
```

If the folder was only deleted, run the setup again with the same path. Everything in it is rebuilt on the next install or build.

## Optional: Microsoft Defender exclusion (not applied by the kit)

Defender scans every file as it is written. A `pnpm install` writes tens of thousands of small files, so installs can be slow. You can exclude the cache folder. Open PowerShell as administrator:

```powershell
Add-MpPreference -ExclusionPath "$env:ONECLICK_CACHE_ROOT"
```

- Check: `Get-MpPreference | Select-Object -ExpandProperty ExclusionPath`
- Undo: `Remove-MpPreference -ExclusionPath "$env:ONECLICK_CACHE_ROOT"`
- Trade-off: a harmful package downloaded into the cache is no longer caught when it is written. Only do this if slow installs are a real problem. Never exclude your whole user folder or a drive.
- If the cache folder moves, remove the old exclusion and add the new path.

See [development-profile.md](development-profile.md) for the approved tools and installation workflow.

## Bulk idle cleanup

Run `node tools/devcache.mjs clean-idle` to preview eligible registered project outputs. Run `node tools/devcache.mjs clean-idle --apply` interactively to review exact paths and confirm with the phrase shown. Platform launchers are available in the repository root platform directories. This command never touches download caches. The clean operation (`oneclick clean --apply`) removes idle project node_modules and Cargo targets after typed confirmation, then prunes download caches: `pnpm store prune`, `npm cache verify`, `uv cache prune`, and `yarn cache clean`, `bun pm cache rm`, `pip cache purge`. It skips active/pinned projects. External processes must be stopped first; the tool cannot establish their state automatically.
