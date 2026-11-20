# Shared cache

One shared, regenerable cache folder for every project on the PC. Everything in it can be deleted at any time. Nothing is lost: it is rebuilt on the next install or build, which is slower once.

Default location (`<CACHE>` below):

- Windows: `%USERPROFILE%\Desktop\F-project\shared-cache`
- Linux: `~/F-project/shared-cache`

```
<CACHE>/
  pnpm-store/     pnpm package store (projects' node_modules hard-link to it)
  cargo-target/   Rust build output (CARGO_TARGET_DIR)
  sccache/        compiled Rust crates reused across projects, capped at 10 GB (SCCACHE_DIR)
  gradle/         Android/Gradle cache (GRADLE_USER_HOME)
  npm-cache/      npm and npx download cache
  puppeteer/      Puppeteer browser downloads
```

## Set it up

On a new PC, `first_install` runs this for you after installing your apps. To run it on its own:

- Windows: `windows\install\setup_shared_cache.bat` (or `setup_shared_cache.bat "D:\other\place"` for another folder)
- Linux: `bash linux/install/setup_shared_cache.sh` (or `... setup_shared_cache.sh /other/place`)

It creates the folders, installs `sccache` and `pnpm` if they are missing, and applies the settings below. Running it again is safe. To move the cache, run it with the new folder, then run `pnpm install` in each project.

Open a new terminal afterwards (on Linux, log out and back in or run `source ~/.profile`). Then run `pnpm install` in each project.

## Settings it applies (user level, every project)

| Setting | Value |
|---|---|
| pnpm `store-dir` (global) | `<CACHE>/pnpm-store` |
| pnpm `package-import-method` (global) | `hardlink` (install fails instead of silently copying) |
| npm `cache` (npx cache lives in `<cache>/_npx`) | `<CACHE>/npm-cache` |
| env `CARGO_TARGET_DIR` | `<CACHE>/cargo-target` |
| env `CARGO_INCREMENTAL` | `0` (sccache needs incremental builds off) |
| env `RUSTC_WRAPPER` | `sccache`, only set when sccache is installed |
| env `SCCACHE_DIR` | `<CACHE>/sccache` |
| env `SCCACHE_CACHE_SIZE` | `10G` |
| env `GRADLE_USER_HOME` | `<CACHE>/gradle` |
| env `PUPPETEER_CACHE_DIR` | `<CACHE>/puppeteer` |

On Windows the environment variables are saved with `setx`. On Linux they go in a marked block in `~/.profile`, which the script replaces each time it runs.

Use pnpm only, never npm or yarn, in projects.

## Rules for AI agents

- Projects must be on the same drive as the store. Hard links do not work across drives; pnpm silently copies instead and wastes space.
- Never delete this folder or anything in it without asking the owner.
- Do not create a per-project `node_modules` store, `.pnpm-store`, or `target` folder, and do not set `target-dir` in a project's `.cargo/config.toml`.
- Never set `CARGO_TARGET_DIR`, `GRADLE_USER_HOME`, `TMP` or `TEMP` for a single command, and never create a cache, target or temp folder anywhere else.
- Converting a project: if `package-lock.json` or `yarn.lock` exists, run `pnpm import` first, ask the owner before deleting `node_modules` and the old lockfile, then run `pnpm install`. The prompt in [convert-project-prompt.md](convert-project-prompt.md) does this.

## Cleaning

- The OneClick Kit developer cleanup only prunes the shared cache: `pnpm store prune` removes packages no project uses any more, and `npm cache verify` removes only broken or unused entries. It never wipes the cache.
- `cargo-target` has no size limit. Delete it by hand when it gets large; the rebuild reuses `sccache`, so it is much faster than a build from nothing.
- `cargo clean` in any project wipes `cargo-target` for every project, because they all share it.
- `sccache` drops its oldest entries on its own at 10 GB. `sccache --show-stats` shows hits, misses and size.

## Optional (Windows): skip Defender scanning for this folder

Defender checks every file as it is written. A `pnpm install` writes tens of thousands of small files, so those checks can make installs slow. Only do this if slow installs are a real problem.

In PowerShell as administrator:

```powershell
Add-MpPreference -ExclusionPath "$env:USERPROFILE\Desktop\F-project\shared-cache"
```

- Check: `Get-MpPreference | Select -ExpandProperty ExclusionPath`
- Undo: `Remove-MpPreference -ExclusionPath "$env:USERPROFILE\Desktop\F-project\shared-cache"`
- Trade-off: Defender stops scanning files in this folder, so a harmful package downloaded here is not caught at download time.
- If the folder moves, remove the old exclusion and add one for the new path.
