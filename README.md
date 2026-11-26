# OneClick Kit

A Windows and Linux development-machine toolkit for fresh installation, shared caches, project cleanup and routine maintenance. Designed for small SSDs and reproducible project environments.

## Quick start

**Windows:** double-click `windows\oneclick.bat`. It asks for administrator rights once and then shows this menu:

```
What do you want to do?
  1. Install    - choose browsers, then developer tools and shared cache
  2. Debloat    - remove preinstalled junk apps, ads and tracking
  3. Update     - system, drivers and apps
  4. Clean - temp files, Recycle Bin, startup apps, idle project build folders, download caches
  5. Everything - install, debloat, update and clean
  6. Auto-clean - turn cleaning every 2 days on or off (now: On or Off)
  U. Update OneClick Kit (download the latest version)
  Q. Quit
```

**Linux:** run `bash linux/oneclick.sh` in a terminal and choose from the same menu.

Each choice first shows a preview and then asks `Run it? Y/N` (Linux: `[y/N]`). Nothing changes until you answer Y. Install then asks which browsers to add (type the numbers, or press Enter for none). The window waits for a key before it closes.

For scripts and scheduled runs, the command-line forms are:

| Workflow | Windows | Linux |
| --- | --- | --- |
| Preview everything (scripts, or input not from a console) | `windows\oneclick.bat` | `bash linux/oneclick.sh` |
| All operations | `windows\oneclick.bat all --apply` | `bash linux/oneclick.sh all --apply` |
| Install approved tools and browsers | `windows\oneclick.bat install --apply` | `bash linux/oneclick.sh install --apply` |
| Configure shared caches | `windows\oneclick.bat cache --apply` | `bash linux/oneclick.sh cache --apply` |
| Debloat (preview, then apply) | `windows\oneclick.bat debloat` / `windows\oneclick.bat debloat --apply` | `bash linux/oneclick.sh debloat` / `bash linux/oneclick.sh debloat --apply` |
| Preview cleanup | `windows\oneclick.bat clean` | `bash linux/oneclick.sh clean` |
| Apply cleanup | `windows\oneclick.bat clean --apply` (elevated terminal) | `bash linux/oneclick.sh clean --apply` |
| Update only | `windows\oneclick.bat update --apply` | `bash linux/oneclick.sh update --apply` |

The `all` operation installs the approved profile, debloats, configures shared caches, updates managed software and cleans. Clean also empties temp files, old logs, crash reports and the Recycle Bin (Windows) or Trash (Linux); it never touches browser profiles or personal files. Download caches are tidied only by the clean operation. Run from a checked-out repository. Project cache commands require Node.js. On Windows, update, debloat, clean and all operations need an elevated terminal to apply (the menu asks for it). No restart is initiated by the unified launcher.

**Fresh-machine handling:** on Windows, the launcher re-registers App Installer when winget is missing and stops with a clear message if it is still unavailable. winget installs accept source and package agreements up front, so nothing waits at a hidden prompt. The Windows Store python stub is ignored when checking for Python. Edge (Windows) and Firefox (Ubuntu, Fedora) are usually preinstalled and are shown as already installed. On Linux, the Node.js bootstrap and the installer refresh apt package lists first, and Flatpak with the Flathub remote is installed when it is missing. Node.js is bootstrapped through a supported package manager; otherwise install it from its official source.

## Approved tools

These are the 50 approved tools in [profiles/development.json](profiles/development.json). The full list with the Windows and Linux source of each tool is in [docs/applications.md](docs/applications.md). The installer never adds other standalone applications.

| Tool | Selection ID | Type |
| --- | --- | --- |
| [Traycer](https://traycer.ai/download) | `traycer` | Desktop app |
| [Cursor](https://cursor.com/) | `cursor` | Desktop app |
| [Moon](https://moonrepo.dev/moon) | `moon` | CLI |
| [GitHub CLI](https://cli.github.com/) | `github-cli` | CLI |
| [Biome](https://biomejs.dev/) | `biome` | Project dependency |
| [Vitest](https://vitest.dev/) | `vitest` | Project dependency |
| [Testing Library](https://testing-library.com/) | `testing-library` | Project dependency |
| [Playwright](https://playwright.dev/) | `playwright` | Project dependency |
| [Lighthouse](https://developer.chrome.com/docs/lighthouse/) | `lighthouse` | On demand |
| [Tauri](https://tauri.app/) | `tauri` | Project dependency |
| [Swift](https://swift.org/) | `swift` | Toolchain |
| [Kotlin](https://kotlinlang.org/) | `kotlin` | Toolchain |
| [Maestro](https://docs.maestro.dev/) | `maestro` | CLI |
| [Helium Browser](https://helium.computer/) | `helium` | Desktop app |
| [Cloudflare Kitesurf](https://developers.cloudflare.com/browser-run/kitesurf/) | `kitesurf` | Remote service |
| [Node.js](https://nodejs.org/en/download) | `nodejs` | Toolchain |
| [Notion](https://www.notion.so/desktop) | `notion` | Desktop app (Windows desktop; web on Linux) |
| [Discord](https://discord.com/download) | `discord` | Desktop app |
| [VLC](https://www.videolan.org/vlc/) | `vlc` | Desktop app |
| [7-Zip](https://www.7-zip.org/download.html) | `7zip` | Desktop app |
| [LocalSend](https://localsend.org/) | `localsend` | Desktop app |
| [FFmpeg](https://ffmpeg.org/download.html) | `ffmpeg` | CLI |
| [Figma](https://www.figma.com/downloads/) | `figma` | Desktop app (Windows desktop; web on Linux) |
| [WizTree](https://diskanalyzer.com/) | `wiztree` | Desktop app (Windows desktop only) |
| [Syncthing](https://syncthing.net/downloads/) | `syncthing` | Desktop app |

Install adapters cover WinGet, Linux distribution package managers, npm, Flatpak and selected official publisher downloads. Tools without an adapter are reported with official links; project dependencies remain project-pinned, and remote services require separate setup. The all-tools option installs only supported adapters, not every item in the catalog. Required compiler/runtime prerequisites are documented separately by each tool. The old exported application setup is still available through the separate `save_my_apps` and `install_apps` scripts; it is not part of the curated profile.

## Shared development cache

Shared package downloads (npm, pnpm, Yarn, Bun, pip and uv), eligible Rust compiler artifacts (sccache), and supported Gradle and browser downloads are configured centrally. Project Cargo targets are isolated per project at `shared-cache/cargo-targets/<project>/target`. The project runner sets the target directory; normal Cargo invocations retain their existing configuration.

| Budget | Target |
| --- | --- |
| Aggregate disposable development data | 35 GiB (warning at 25 GiB) |
| Cargo target per project | 5 GiB (warning at 4 GiB) |
| Shared sccache | 5 GiB |
| Recommended free space | 40 GiB |
| Idle dependencies | 24 hours before eligible for review |
| Idle build outputs | 48 hours before eligible for review |

Budgets are retention targets, not hard quotas; active builds must be allowed to complete.

```sh
node tools/devcache.mjs activate /path/to/project
node tools/devcache.mjs run /path/to/project -- cargo build
node tools/devcache.mjs status
node tools/devcache.mjs deactivate /path/to/project
node tools/devcache.mjs plan
```

Activation restores missing dependencies from the project's existing lockfile. Pin active or important projects to keep their generated files. Use [shared-cache.md](docs/shared-cache.md) for details and [convert-project-prompt.md](docs/convert-project-prompt.md) for existing projects.

## One-click idle cleanup

The clean-idle launchers preview registered inactive projects and their eligible generated dependency and build directories. With `--apply` they show the exact paths and ask for explicit interactive confirmation. Close editors, dev servers, tests and watches; preserve release artifacts and custom files before confirming. Active, pinned, recently used or unsafe paths are skipped. The clean operation also prunes download caches (pnpm store prune, npm cache verify, uv cache prune, and yarn, bun and pip cache clean). Auto-clean runs the same idle cleanup on a schedule with all of these safety checks; it never removes active, pinned or recently used projects.

## Update only

Run the update-only launcher with `--apply` to update without invoking cleanup.

- Windows: Windows Update and supported drivers, Defender definitions, Microsoft Store update requests and WinGet-managed applications.
- Linux: the detected apt, dnf, pacman or zypper package manager, Flatpak, Snap and supported firmware through fwupd.

Coverage depends on installed package managers and supported devices; independently installed apps may require their own updater. Restart is never automatic without user confirmation.

## Debloat

The debloat operation removes preinstalled junk apps (Clipchamp, News, Solitaire, Skype and similar), preinstalled promo games and ads, and turns off ads, suggestions, tracking and background settings. Every item has one mark:

- **Yes**: done by default.
- **Ask**: you are asked Y/N first. The default is to keep the item.
- **No**: not done (too risky, not bloat, or cannot be done reliably).
- **Never**: protected. The script refuses to touch it (Edge WebView2, Store, Calculator, Paint, Photos, GPU and PC-maker control software and similar).

Preview with `windows\oneclick.bat debloat` or `bash linux/oneclick.sh debloat`. On Windows, applying creates a System Restore point (if System Protection is on), saves the old value of every setting it changes to `%LOCALAPPDATA%\OneClickKit\debloat-backup-<date>.json`, and writes a log next to it. To put the settings back, run `windows\debloat\debloat.bat /undo`; removed Store apps come back from the Microsoft Store. Linux runs the separate script `linux/debloat/debloat_linux.sh` (`--auto` keeps every Ask item, `--dry-run` changes nothing).

The full list, with package names and marks, is in [docs/debloat.md](docs/debloat.md). The data file is [profiles/debloat.json](profiles/debloat.json).

## Auto-clean

Auto-clean runs every 2 days, only when the PC is plugged in and idle:

- Windows: the scheduled task "OneClick Kit Auto Clean" runs at 12:00 every 2 days after 10 minutes idle, on AC power only.
- Linux: a systemd user timer starts 15 minutes after boot and then every 2 days, on AC power only.

Rules:

- Temp files and folders older than 2 days. Session scratch folders named `claude` are kept.
- Recycle Bin items deleted more than 14 days ago.
- Idle project `node_modules` and Cargo targets (not active, not pinned).
- pnpm store prune and npm cache verify on every run; yarn, bun, pip and uv caches weekly.

Logs are in `%LOCALAPPDATA%\OneClickKit\logs` (Windows) or `~/.local/state/oneclick-kit/logs` (Linux). Kit logs older than 30 days are deleted.

Moving the repo folder breaks the task: turn auto-clean off and on again after moving. Turn it on or off from menu 6, or with `windows\oneclick.bat autoclean --apply` or `bash linux/oneclick.sh autoclean --apply`.

## Startup apps

Every clean and every auto-clean switches off startup programs. Nothing is deleted, and new apps are switched off on each run. On Windows this covers Run keys, Startup folders and Store app startup tasks. On Linux it covers `~/.config/autostart`.

- **Keep list:** the names you choose to keep are stored in `%LOCALAPPDATA%\OneClickKit\startup-keep.json` (Windows) or `~/.config/oneclick-kit/startup-keep` (Linux). `-Review` (Windows) or `--review` (Linux) asks which items to keep.
- **Protected (never touched):** security (SecurityHealth, Defender); drivers and hardware (Realtek, NVIDIA, AMD, Intel, HP, OMEN, Logitech, Razer and similar); input and accessibility (ctfmon, osk, Narrator); OneClick Kit items.
- **Turn something back on:** on Windows, use Task Manager > Startup apps or Settings > Apps > Startup. On Linux, delete `~/.config/autostart/<name>.desktop`, or rename `<name>.desktop.oneclick-bak` back to `<name>.desktop` (the backup is kept).
- **Undo on Windows:** `windows\cleanup\startup_apps.ps1 -Undo` restores the newest backup from `%LOCALAPPDATA%\OneClickKit\startup-backup-*.json`.
- **Preview:** `windows\oneclick.bat startup` or `bash linux/oneclick.sh startup` (with `--apply` to review). The scripts also accept `-DryRun` and `--dry-run`.

## Developer settings and Git

`windows\install\dev_settings.bat` sets long paths and shows file extensions and hidden files. The Git setup scripts (`windows\install\setup_git.bat` and `linux/install/setup_git.sh`) set the Git user name, email and default branch if they are missing, and offer to create an SSH key for GitHub. Add the public key at https://github.com/settings/keys, or with `gh`. Both run inside first install and are previewed with `/dryrun` (Windows) or `--dry-run` (Linux).

## Self-update

Menu U, or `windows\oneclick.bat self-update --apply` (Linux: `bash linux/oneclick.sh self-update --apply`), runs `git pull --ff-only` when the repo is a git clone. Otherwise it prints the download link https://github.com/Nexvyn/OneClick-Kit.

## Windows protected your PC (SmartScreen)

The executable is not signed, so SmartScreen may block it. Click More info, then Run anyway. Only run it from the repo you trust.

## Restore point before updates

The Windows update step creates a System Restore point first (Checkpoint-Computer). If it fails, System Protection may be off or a point was made in the last 24 hours; the update still runs.

## Defender exclusion (optional)

Not applied by the kit. If pnpm installs are slow, [docs/shared-cache.md](docs/shared-cache.md#optional-microsoft-defender-exclusion-not-applied-by-the-kit) shows how to exclude only the shared cache folder, how to undo it, and the trade-off.

## Optional legacy system cleanup

The existing browser/system maintenance helpers remain separate from the unified launcher. They can close browser processes and clear system junk including Trash or Recycle Bin, so use their dry-run options and explicitly review them. The legacy Windows executable, built with `windows\build.bat`, makes no changes when opened without arguments and requires explicit confirmation with `--apply` for its combined maintenance workflow.

## Development and tests

```sh
node --test tests/development.test.mjs
```

See [development-profile.md](docs/development-profile.md) for tool selection and [shared-cache.md](docs/shared-cache.md) for project lifecycle controls. The executables are not signed; use the source and retain your normal security protections. Never publish private app exports or secrets.

## Files

- [README.md](README.md): this guide.
- [LICENSE](LICENSE): MIT license.
- [docs/applications.md](docs/applications.md): application list that Install can add, with the Windows and Linux source of each.
- [docs/debloat.md](docs/debloat.md): debloat list with every item and its mark.
- [docs/shared-cache.md](docs/shared-cache.md): shared cache layout and budgets.

## License

[MIT](LICENSE)

## Expanded one-click development setup

The approved profile now contains 50 tools. Run `windows\oneclick.bat install --apply` on Windows or `bash linux/oneclick.sh install --apply` on Linux, then answer Y at the prompt and choose browsers. Existing runtime commands and installed packages are detected before installing; package managers and official publisher releases download and install available tools in sequence. Installer or administrator prompts may still appear. The installer reports unavailable, project-local, platform-specific and failed items separately. No automatic account sign-in, security-policy changes or acceptance of third-party licenses.

**AI CLIs:** Claude Code, Codex, OpenCode, Antigravity and GitHub Copilot.

**Toolchains:** Git, Node.js/npm, Rustup/Rust/Cargo, sccache, pnpm, Bun, Yarn, Deno, Python, uv, Java JDK 21, Kotlin, Swift, Gradle Wrapper, Android SDK, Visual Studio Build Tools, Windows SDK and WebView2 Runtime.

**Utilities:** yt-dlp, PowerShell 7, Handy, Windows Terminal and CrystalDiskInfo.

Project dependencies (Biome, Vitest, Testing Library, Playwright, Tauri and Gradle Wrapper) remain project-pinned. Cloudflare Kitesurf is remote. Windows-only tools are skipped on Linux. Swift, Android SDK, Maestro and unsupported package/distribution combinations may require official setup; no substitute packages are installed. See the [full profile](profiles/development.json).
