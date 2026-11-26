# Application list

Everything the **Install** operation can install, generated from `profiles/development.json` and `tools/browsers.mjs` and the installer routes in `tools/install-development.mjs`. The installer never adds other standalone applications.

Preview with `windows/oneclick.bat install` or `bash linux/oneclick.sh install`. Install with `--apply`. Each item is tried in this order: the first route that exists on the machine wins. Items with no route are reported with their official link.

## Browsers (you choose)

Install asks which browsers to add. Nothing is installed when you choose none. Edge is already part of Windows and is shown as installed there.

| Browser | Windows source | Linux source | Link |
|---|---|---|---|
| Google Chrome | WinGet `Google.Chrome` | Flatpak `com.google.Chrome` | https://www.google.com/chrome/ |
| Mozilla Firefox | WinGet `Mozilla.Firefox` | Flatpak `org.mozilla.firefox` | https://www.mozilla.org/firefox/ |
| Brave | WinGet `Brave.Brave` | Flatpak `com.brave.Browser` | https://brave.com/ |
| Microsoft Edge | WinGet `Microsoft.Edge` | Flatpak `com.microsoft.Edge` | https://www.microsoft.com/edge |
| Opera | WinGet `Opera.Opera` | Flatpak `com.opera.Opera` | https://www.opera.com/ |
| Vivaldi | WinGet `Vivaldi.Vivaldi` | Flatpak `com.vivaldi.Vivaldi` | https://vivaldi.com/ |

## Developer tools

| Tool | Kind | Windows source | Linux source | Link |
|---|---|---|---|---|
| Traycer | Desktop app | verified GitHub release (MSI) | verified GitHub release | https://traycer.ai/download |
| Cursor | Desktop app | WinGet `Anysphere.Cursor` | apt `cursor` (distro package, when the distro has it) | https://cursor.com/ |
| Moon | CLI | npm `@moonrepo/cli` | npm `@moonrepo/cli` | https://moonrepo.dev/moon |
| GitHub CLI | CLI | WinGet `GitHub.cli` | apt `gh` (distro package, when the distro has it) | https://cli.github.com/ |
| Biome | Project dependency | Project or service (not installed globally) | Project or service (not installed globally) | https://biomejs.dev/ |
| Vitest | Project dependency | Project or service (not installed globally) | Project or service (not installed globally) | https://vitest.dev/ |
| Testing Library | Project dependency | Project or service (not installed globally) | Project or service (not installed globally) | https://testing-library.com/ |
| Playwright | Project dependency | Project or service (not installed globally) | Project or service (not installed globally) | https://playwright.dev/ |
| Lighthouse | On demand | Project or service (not installed globally) | Project or service (not installed globally) | https://developer.chrome.com/docs/lighthouse/ |
| Tauri | Project dependency | Project or service (not installed globally) | Project or service (not installed globally) | https://tauri.app/ |
| Swift | Toolchain | WinGet `Swift.Toolchain` | Official setup | https://swift.org/ |
| Kotlin | Toolchain | WinGet `JetBrains.Kotlin` | apt `kotlin` (distro package, when the distro has it) | https://kotlinlang.org/ |
| Maestro | CLI | Official setup | official publisher installer | https://docs.maestro.dev/ |
| Helium Browser | Desktop app | WinGet `ImputNet.Helium` | Flatpak `net.imput.helium` / verified GitHub release | https://helium.computer/ |
| Cloudflare Kitesurf | Remote service | Project or service (not installed globally) | Project or service (not installed globally) | https://developers.cloudflare.com/browser-run/kitesurf/ |
| Node.js | Toolchain | WinGet `OpenJS.NodeJS.LTS` | apt `nodejs` (distro package, when the distro has it) | https://nodejs.org/en/download |
| Notion | Desktop app | WinGet `Notion.Notion` | Official setup | https://www.notion.so/desktop |
| Discord | Desktop app | WinGet `Discord.Discord` | apt `discord` (distro package, when the distro has it) / Flatpak `com.discordapp.Discord` | https://discord.com/download |
| VLC | Desktop app | WinGet `VideoLAN.VLC` | apt `vlc` (distro package, when the distro has it) / Flatpak `org.videolan.VLC` | https://www.videolan.org/vlc/ |
| 7-Zip | Desktop app | WinGet `7zip.7zip` | apt `7zip` (distro package, when the distro has it) | https://www.7-zip.org/download.html |
| LocalSend | Desktop app | WinGet `LocalSend.LocalSend` | Flatpak `org.localsend.localsend_app` | https://localsend.org/ |
| FFmpeg | CLI | WinGet `Gyan.FFmpeg` | apt `ffmpeg` (distro package, when the distro has it) | https://ffmpeg.org/download.html |
| Figma | Desktop app | WinGet `Figma.Figma` | Official setup | https://www.figma.com/downloads/ |
| WizTree | Desktop app | WinGet `AntibodySoftware.WizTree` | Official setup | https://diskanalyzer.com/ |
| Syncthing | Desktop app | WinGet `Syncthing.Syncthing` | apt `syncthing` (distro package, when the distro has it) | https://syncthing.net/downloads/ |
| Claude Code CLI | CLI | WinGet `Anthropic.ClaudeCode` / npm `@anthropic-ai/claude-code` | npm `@anthropic-ai/claude-code` | https://code.claude.com/docs/en/setup |
| Codex CLI | CLI | npm `@openai/codex` | npm `@openai/codex` | https://developers.openai.com/codex/cli |
| OpenCode CLI | CLI | npm `@opencode/cli` | npm `@opencode/cli` | https://opencode.ai/ |
| Antigravity CLI | CLI | official publisher installer | official publisher installer | https://antigravity.google/docs/cli-getting-started |
| GitHub Copilot CLI | CLI | npm `@github/copilot` | npm `@github/copilot` | https://github.com/github/copilot-cli |
| Git | Toolchain | WinGet `Git.Git` | apt `git` (distro package, when the distro has it) | https://git-scm.com/downloads |
| Rustup / Rust / Cargo | Toolchain | WinGet `Rustlang.Rustup` | apt `rustup` (distro package, when the distro has it) / official publisher installer | https://rustup.rs/ |
| sccache | Toolchain | WinGet `Mozilla.sccache` | apt `sccache` (distro package, when the distro has it) | https://github.com/mozilla/sccache |
| pnpm | Toolchain | npm `pnpm` | npm `pnpm` | https://pnpm.io/installation |
| Bun | Toolchain | WinGet `Oven-sh.Bun` / npm `bun` | apt `bun` (distro package, when the distro has it) / npm `bun` | https://bun.sh/ |
| Yarn | Toolchain | npm `yarn@1` | npm `yarn@1` | https://yarnpkg.com/ |
| Deno | Toolchain | WinGet `DenoLand.Deno` / npm `deno` | apt `deno` (distro package, when the distro has it) / npm `deno` | https://deno.com/ |
| Python | Toolchain | WinGet `Python.Python.3.13` | apt `python3` (distro package, when the distro has it) | https://www.python.org/downloads/ |
| uv | Toolchain | WinGet `astral-sh.uv` | apt `uv` (distro package, when the distro has it) / official publisher installer | https://docs.astral.sh/uv/ |
| Java JDK 21 | Toolchain | WinGet `EclipseAdoptium.Temurin.21.JDK` | apt `openjdk-21-jdk` (distro package, when the distro has it) | https://adoptium.net/ |
| Gradle Wrapper | Project dependency | Project or service (not installed globally) | Project or service (not installed globally) | https://docs.gradle.org/current/userguide/gradle_wrapper.html |
| Android SDK | Toolchain | Official setup | Official setup | https://developer.android.com/tools |
| Visual Studio Build Tools | Toolchain | WinGet `Microsoft.VisualStudio.2022.BuildTools` | Official setup | https://visualstudio.microsoft.com/downloads/ |
| Windows SDK | Toolchain | WinGet `Microsoft.WindowsSDK.10.0.26100` | Official setup | https://developer.microsoft.com/windows/downloads/windows-sdk/ |
| WebView2 Runtime | Toolchain | WinGet `Microsoft.EdgeWebView2Runtime` | Official setup | https://developer.microsoft.com/microsoft-edge/webview2/ |
| yt-dlp | CLI | WinGet `yt-dlp.yt-dlp` | apt `yt-dlp` (distro package, when the distro has it) | https://github.com/yt-dlp/yt-dlp |
| PowerShell 7 | CLI | WinGet `Microsoft.PowerShell` | apt `powershell` (distro package, when the distro has it) / verified GitHub release | https://github.com/PowerShell/PowerShell |
| Handy | Desktop app | WinGet `cjpais.Handy` | Flatpak `com.pais.handy` / verified GitHub release | https://handy.computer/ |
| Windows Terminal | Desktop app | WinGet `Microsoft.WindowsTerminal` | Official setup | https://github.com/microsoft/terminal |
| CrystalDiskInfo | Desktop app | WinGet `CrystalDewWorld.CrystalDiskInfo` | Official setup | https://crystalmark.info/en/software/crystaldiskinfo/ |

## Removed by Debloat

Debloat is a separate operation that removes preinstalled apps, ads and tracking settings. It does not install anything from this list. See [debloat.md](debloat.md) for every item and its mark.

