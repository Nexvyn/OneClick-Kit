# OneClick Kit

One-click maintenance for Windows and Linux. The scripts are grouped by job:

| Folder | What it does | Runs in the one-click |
|---|---|---|
| `cleanup/` | Browser caches, system junk, developer caches (prunes pnpm and npm, clears yarn, bun, pip) | Yes, first |
| `update/` | The whole system: OS, drivers and firmware, store apps, all other apps | Yes, second |
| `install/` | Fresh PC: reinstall your apps, then set up the shared dev cache | No, run `first_install` on a new PC |

```
windows/   OneClickKit.exe (after build), build.bat, cleanup/, update/, install/, src/
linux/     oneclick.sh, cleanup/, update/, install/, lib/
docs/      shared-cache.md, convert-project-prompt.md
```

## Windows

**One click**

1. Run `windows\build.bat` once. It creates `windows\OneClickKit.exe` with the C# compiler that ships with Windows, so nothing needs to be installed.
2. Double-click `OneClickKit.exe` and accept the admin prompt.
3. A 10-second countdown starts. Press any key to start now, or Esc to cancel.
4. It runs browser cleanup, Windows cleanup, developer cache cleanup, then updates. At the end it shows a summary and asks before restarting.

**What it touches**

- Browser cleanup closes Chrome, Edge, Brave and Firefox and clears their cache for every profile. It never deletes history, cookies, passwords, logins or bookmarks.
- Windows cleanup clears your temp folder, Windows temp, old Windows Update downloads, the Delivery Optimization cache, crash reports and dumps, Windows logs older than 7 days, and the Recycle Bin. It reports how much space it freed. It does not clear Prefetch, because Windows uses Prefetch to start apps faster.
- Developer cleanup runs `pnpm store prune` (removes only packages no project uses), `npm cache verify` (removes only broken or unused entries), `yarn cache clean`, `bun pm cache rm` and `pip cache purge` for the tools you have. The npm cache and pnpm store can be your [shared cache](docs/shared-cache.md), so they are only pruned, never wiped.
- Updates cover Microsoft Defender definitions, Windows Update (including drivers and other Microsoft products, through PSWindowsUpdate, which is installed automatically), Microsoft Store apps and every winget app. It never restarts by itself.

**Fresh PC**

1. On your old PC, run `windows\install\save_my_apps.bat`. It writes `apps.json` next to the script. Commit that file if you want it in the repo.
2. On the new PC, clone the repo and run `windows\install\first_install.bat`. It installs the apps from `apps.json`, then runs `setup_shared_cache.bat`. That creates the [shared dev cache](docs/shared-cache.md), installs `sccache` and `pnpm` if they are missing, and points pnpm, npm, Cargo, sccache, Gradle and Puppeteer at it.
3. Restart the PC, then run `pnpm install` in each project. To move an existing project onto the shared cache, paste [convert-project-prompt.md](docs/convert-project-prompt.md) into that project's AI.

Each part also runs on its own: `install_apps.bat`, `setup_shared_cache.bat`.

## Linux

Supports apt (Ubuntu, Debian, Mint, Pop!_OS), dnf (Fedora), pacman (Arch, Manjaro) and zypper (openSUSE), plus Flatpak, Snap and fwupd firmware updates.

```bash
git clone https://github.com/Nexvyn/OneClick-Kit.git
cd OneClick-Kit
bash linux/oneclick.sh
```

Run it as your normal user, not with `sudo`. It asks for your password once. It runs the same four steps as on Windows, using your distro's tools, then shows a summary and asks before restarting.

**Fresh PC:** run `bash linux/install/save_my_apps.sh` on the old machine and commit the `packages-*.txt`, `flatpak.txt` and `snap.txt` files if you want them in the repo. On the new machine run `bash linux/install/first_install.sh`. It installs the apps, then sets up the [shared dev cache](docs/shared-cache.md) (settings go in a marked block in `~/.profile`).

## Preview first

Every script has a preview mode that changes nothing and prints what it would do:

- Windows: `OneClickKit.exe --dry-run`, or any script with `/dryrun`, for example `windows\cleanup\clean_windows_junk.bat /dryrun`
- Linux: `bash linux/oneclick.sh --dry-run`, or any script with `--dry-run`

## Run one step

Every script also works on its own. Double-click a `.bat` file, or run `bash linux/<folder>/<script>.sh`.

## Notes

- The Windows scripts are packed inside the exe, so run `build.bat` again after you edit one.
- The exe is unsigned. Windows SmartScreen or antivirus may warn about it if it is downloaded or shared. Building it yourself avoids that.
- This repo is public. If you commit your app lists, anyone can see which apps you use.
