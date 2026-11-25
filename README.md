# OneClick Kit

A Windows and Linux development-machine toolkit for fresh installation, shared caches, project cleanup and routine maintenance. Designed for small SSDs and reproducible project environments.

## Quick start

**One entry point:** `windows\oneclick.bat` or `bash linux/oneclick.sh`. Running without arguments is a read-only preview. Select `install`, `update`, `clean`, `cache`, or `all`; add `--apply` and explicitly confirm to execute. The `all` operation installs the approved profile, configures shared caches, updates managed software and offers a separate confirmation for eligible idle outputs. It never silently clears browsers, Trash, system files or shared download stores.

| Workflow | Windows | Linux |
| --- | --- | --- |
| Preview everything (safe default) | `windows\oneclick.bat` | `bash linux/oneclick.sh` |
| All operations | `windows\oneclick.bat all --apply` | `bash linux/oneclick.sh all --apply` |
| Install approved tools | `windows\oneclick.bat install --apply` | `bash linux/oneclick.sh install --apply` |
| Configure shared caches | `windows\oneclick.bat cache --apply` | `bash linux/oneclick.sh cache --apply` |
| Preview idle cleanup | `windows\oneclick.bat clean` | `bash linux/oneclick.sh clean` |
| Apply idle cleanup | `windows\oneclick.bat clean --apply` | `bash linux/oneclick.sh clean --apply` |
| Update only | `windows\oneclick.bat update --apply` | `bash linux/oneclick.sh update --apply` |

Run from a checked-out repository. On a fresh machine, the confirmed install operation can bootstrap Node.js through a supported package manager; otherwise install it from its official source. Project cache commands require Node.js. On Windows, update and all operations require an elevated terminal; the launcher refuses to proceed without it. No restart is initiated by the unified launcher.

## Approved tools

These are the 25 approved tools in [profiles/development.json](profiles/development.json). The installer never adds other standalone applications.

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

Install adapters currently cover selected WinGet packages on Windows and supported apt packages on Linux. Tools without an adapter are reported with official links; project dependencies remain project-pinned, and remote services require separate setup. The all-tools option installs only supported adapters, not every item in the catalog. Required compiler/runtime prerequisites are documented separately by each tool. The old exported application setup is still available through the separate `save_my_apps` and `install_apps` scripts; it is not part of the curated profile.

## Shared development cache

Shared package downloads (npm, pnpm, Yarn, Bun, pip and uv), eligible Rust compiler artifacts (sccache), and supported Gradle and browser downloads are configured centrally. Project-specific Rust build outputs are isolated by workspace/worktree. The project runner sets the appropriate target directory; normal Cargo invocations retain their existing configuration.

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

The clean-idle launchers preview registered inactive projects and their eligible generated dependency and build directories. With `--apply` they show the exact paths and ask for explicit interactive confirmation. Close editors, dev servers, tests and watches; preserve release artifacts and custom files before confirming. Active, pinned, recently used or unsafe paths are skipped. Shared package download stores are preserved to make restores faster. No unattended bulk deletion.

## Update only

Run the update-only launcher with `--apply` to update without invoking cleanup.

- Windows: Windows Update and supported drivers, Defender definitions, Microsoft Store update requests and WinGet-managed applications.
- Linux: the detected apt, dnf, pacman or zypper package manager, Flatpak, Snap and supported firmware through fwupd.

Coverage depends on installed package managers and supported devices; independently installed apps may require their own updater. Restart is never automatic without user confirmation.

## Optional legacy system cleanup

The existing browser/system maintenance helpers remain separate from the unified launcher. They can close browser processes and clear system junk including Trash or Recycle Bin, so use their dry-run options and explicitly review them. The legacy Windows executable, built with `windows\build.bat`, makes no changes when opened without arguments and requires explicit confirmation with `--apply` for its combined maintenance workflow.

## Development and tests

```sh
node --test tests/development.test.mjs
```

See [development-profile.md](docs/development-profile.md) for tool selection and [shared-cache.md](docs/shared-cache.md) for project lifecycle controls. The executables are not signed; use the source and retain your normal security protections. Never publish private app exports or secrets.

## License

[MIT](LICENSE)
