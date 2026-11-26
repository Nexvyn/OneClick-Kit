# Debloat list

What the **Debloat** option removes or turns off after a fresh install, and why.
Each item has one of four marks:

| Mark | Meaning |
|---|---|
| **Yes** | Done by default. Safe, and nobody needs it. |
| **Ask** | You are asked Y/N first. The answer defaults to No. Useful to some people. |
| **No** | Not done. Too risky, not bloat, or can't be done reliably by a script. |
| **Never** | Protected. The script refuses to touch it. |

Before any change on Windows, the script:

- creates a System Restore point;
- saves every setting's old value to `%LOCALAPPDATA%\OneClickKit\debloat-backup-<date>.json`, so `debloat --undo` can put them back;
- writes a log next to the backup.

Removed Store apps can be reinstalled from the Microsoft Store.

Useful apps are never removed: Calculator, Notepad, Paint, Photos, Snipping Tool, Terminal, Camera, Clock, Sound Recorder, media players, LibreOffice and file managers.

---

## Windows 10 and 11

### Microsoft apps

| App | Package | Mark | Why |
|---|---|---|---|
| Clipchamp | Clipchamp.Clipchamp | Yes | Promo video editor |
| Solitaire Collection | Microsoft.MicrosoftSolitaireCollection | Yes | Ads inside |
| Microsoft News | Microsoft.BingNews | Yes | Feed of ads and news |
| Bing Finance, Sports, Travel | Microsoft.BingFinance, .BingSports, .BingTravel | Yes | Old feed apps |
| Bing Search app | Microsoft.BingSearch | Yes | Pushes Bing |
| Microsoft 365 hub | Microsoft.MicrosoftOfficeHub | Yes | Office sales page |
| Teams (personal) | MicrosoftTeams, MSTeams | Yes | Starts with Windows. Work Teams is a separate install |
| People | Microsoft.People | Yes | Unused contacts app |
| Tips / Get Started | Microsoft.Getstarted | Yes | Tips and promotions |
| Get Help | Microsoft.GetHelp | No | Some troubleshooters open it |
| Feedback Hub | Microsoft.WindowsFeedbackHub | Yes | Asks for feedback |
| Family | MicrosoftCorporationII.MicrosoftFamily | Yes | Promo for family accounts |
| Dev Home | Microsoft.Windows.DevHome | Yes | Discontinued by Microsoft |
| 3D Builder, 3D Viewer, Print 3D | Microsoft.3DBuilder, .Microsoft3DViewer, .Print3D | Yes | Old 3D apps |
| Paint 3D | Microsoft.MSPaint | Yes | Old. The normal Paint is Microsoft.Paint and is kept |
| Mixed Reality Portal | Microsoft.MixedReality.Portal | Yes | Only for VR headsets |
| Cortana | Microsoft.549981C3F5F10 | Yes | Discontinued |
| Skype | Microsoft.SkypeApp | Yes | Discontinued |
| Paid Wi-Fi, Messaging, Mobile Plans, Wallet | Microsoft.OneConnect, .Messaging, .Wallet, Microsoft.MicrosoftMobilePlans | Yes | Old, unused |
| Copilot app | Microsoft.Copilot, Microsoft.Windows.Ai.Copilot.Provider | Yes | Also turned off by setting below |
| Maps | Microsoft.WindowsMaps | Ask | Some people use offline maps |
| Weather | Microsoft.BingWeather | Ask | Useful to some |
| To Do | Microsoft.Todos | Ask | Useful to some |
| Movies and TV | Microsoft.ZuneVideo | Ask | Plays videos |
| Outlook (new) | Microsoft.OutlookForWindows | Ask | Needed if you use Outlook mail |
| Phone Link | Microsoft.YourPhone, MicrosoftWindows.CrossDevice | Ask | Needed to link an Android or iPhone |
| Journal, Whiteboard | Microsoft.MicrosoftJournal, Microsoft.Whiteboard | Ask | Pen users use them |
| Power Automate | Microsoft.PowerAutomateDesktop | Ask | Some automate tasks with it |
| PC Manager | Microsoft.MicrosoftPCManager | Ask | Duplicates built-in tools |
| OneDrive | winget Microsoft.OneDrive | Ask | Needed if you sync files |
| Xbox apps | Microsoft.GamingApp, .XboxApp, .XboxGamingOverlay, .XboxGameOverlay, .XboxSpeechToTextOverlay, .Xbox.TCUI | Ask ("Do you play PC games?" No = remove) | Games need them |
| Xbox Identity Provider, Gaming Services | Microsoft.XboxIdentityProvider, Microsoft.GamingServices | No | Many games break without them |
| Microsoft Edge | Microsoft.Edge | Ask, with a warning | Windows only allows it in Europe (EEA). Elsewhere uninstall fails or Windows puts it back. If removal fails, the script says so and moves on |
| Edge WebView2 Runtime | Microsoft.EdgeWebView2Runtime | Never | Many apps need it, including Teams, Office and Tauri apps |

### Third-party promo apps

Only promo apps that come preinstalled are removed. If you install the same app yourself, it is not touched.

| App | Mark | Why |
|---|---|---|
| Candy Crush (Saga, Soda), Bubble Witch, FarmVille, Disney Magic Kingdoms, Asphalt, Royal Revolt, WildTangent games | Yes | Preinstalled game ads |
| Booking.com, Amazon, shopping app stubs | Yes | Preinstalled ads |
| Facebook, Instagram, TikTok, Netflix, LinkedIn, Spotify promo stubs | Ask | Many people use these. They are listed with names so you can decide |
| Trial antivirus (McAfee, Norton), trial VPNs (ExpressVPN, NordVPN), Dropbox and Adobe trials | Ask | Remove only if you have other protection. Windows Security takes over when a trial is removed |

### PC maker apps (HP, Dell, Lenovo, ASUS, Acer, MSI)

| Kind | Mark | Examples |
|---|---|---|
| Welcome, registration, tips, game bundles, app deals | Ask (each one found is shown by name) | HP JumpStart, HP Welcome, HP Documentation, Dell Customer Connect, Lenovo Welcome, Lenovo App Explorer, ASUS GiftBox, ASUS AppDeals, Acer Collection, Acer Jumpstart, MSI App Player |
| Fan, thermal, power mode, firmware, drivers, special keys, support assistant | Never | HP Support Assistant, OMEN Gaming Hub or Command Center, HP System Event Utility, Dell Command Update, Lenovo Vantage, Armoury Crate, MSI Center, AMD and NVIDIA control panels |

The script only offers OEM apps on a fixed list of promo names. It never removes an OEM app because of who made it.

### Ads and suggestions (turned off, one setting each)

All **Yes**. They change only your user's settings and can be undone.

- Start menu: ads, recommended apps, suggestions, account nags, suggested pinned apps
- Windows installing "suggested" or sponsored apps on its own
- Lock screen: ads, tips, fun facts. Spotlight wallpaper itself stays
- Settings home page promotions, Welcome screen after updates, "Finish setting up your device"
- Tips and suggestion notifications
- File Explorer: OneDrive and Microsoft 365 ads
- Search: Bing web results, search highlights and the search box's Copilot
- Widgets news feed and the taskbar Widgets button
- Edge promo notifications, set by Edge policy. Edge then shows "managed by your organization". That is normal for a policy setting

### Data collection

| Setting | Mark |
|---|---|
| Advertising ID | Yes |
| Tailored experiences, personalized offers | Yes |
| Optional diagnostic data, set to Required only (the lowest Home and Pro allow) | Yes |
| Feedback requests | Yes |
| App launch tracking (for Start suggestions) | Yes |
| Activity history | Yes |
| Typing and inking personalization data | Yes |
| Online speech recognition | Ask (voice typing needs it) |
| Location | No (you set it per app in Settings) |
| Cloud clipboard | No (off by default already) |

### AI features

| Feature | Mark |
|---|---|
| Copilot (taskbar, keyboard key, search) | Yes |
| Recall and its snapshots | Yes (turned off; on Copilot+ PCs the feature is also removed) |
| Click to Do | Yes |
| Edge Copilot sidebar | Yes |
| AI in Paint, Notepad, Photos | No (inside useful apps; turn off in each app) |

### Background activity

| Item | Mark |
|---|---|
| Edge Startup Boost, Edge running in background | Yes |
| Teams starting with Windows | Yes |
| Copilot starting with Windows | Yes |
| Xbox background game recording (Game DVR) | Yes |
| Delivery Optimization sharing updates with PCs on the internet (local network sharing stays) | Yes |
| OneDrive, Phone Link starting with Windows | Same answer as their Ask rows above |
| Printer, Bluetooth, Fax, Wireless display, Touch keyboard services | No (breaks hardware later, small gain) |
| Optional Windows features (Hyper-V, WSL, Sandbox) | No (developers need them) |
| Transparency, animations | No (looks, not bloat) |

### Never touched on Windows

Windows Security, Windows Update, Firewall, SmartScreen, Microsoft Store and App Installer (winget), WebView2, .NET and Visual C++ runtimes, Windows Recovery, drivers, Calculator, Notepad, Paint, Photos, Snipping Tool, Terminal, Camera, Clock, media players.

---

## Linux

Linux ships much less bloat. Bundled apps such as LibreOffice, Thunderbird and media players are **No**: they are real apps. Remove them yourself if you don't want them.

| Item | Distro | Mark | How |
|---|---|---|---|
| APT news in `apt` output | Ubuntu | Yes | `pro config set apt_news=false` |
| MOTD news | Ubuntu | Yes | `ENABLED=0` in `/etc/default/motd-news` |
| Ubuntu Pro ads in apt | Ubuntu | Yes | Comes with apt_news off |
| Ubuntu Insights / Ubuntu Report data sharing | Ubuntu | Yes | Opt out with the tool that exists |
| Apport crash-report popups | Ubuntu | Ask | Disable `apport` service |
| Popularity Contest | Debian, Ubuntu | Yes | Remove package `popularity-contest` if present |
| ABRT automatic crash reporting | Fedora | Ask | `abrt-auto-reporting disabled` |
| Welcome app at login (Mint Welcome, Manjaro Hello, EndeavourOS Welcome, Zorin, Pop) | Many | Yes | Turn off its autostart only; the app stays |
| Preinstalled games (aisleriot, gnome-mines, gnome-sudoku, gnome-mahjongg, kmines, kpat) | All | Ask | Package manager remove |
| CUPS, Avahi, Bluetooth, ModemManager services | All | No | Breaks printing, network discovery or Bluetooth later |
| Docker, databases, web servers | All | No | Not preinstalled bloat; you installed them |
| Desktop extensions, widgets, applets | All | No | Personal choice; change them in your desktop's settings |
| Orphan packages, unused Flatpak runtimes, old Snap revisions, package caches, old kernels | All | Already in **Clean** | Clean keeps the running kernel and one fallback |

---

## Not covered

- **macOS, BSD, ChromeOS, Android:** the kit supports Windows and Linux only.
- **Profiles** (Gaming, Privacy, Minimal and so on): instead, the "Ask" questions cover these cases. For example, answering "Do you play PC games?" with Yes keeps Xbox.
- **Kernel tuning:** not debloating.

## Sources

- [Win11Debloat default settings](https://github.com/Raphire/Win11Debloat/wiki/Default-Settings)
- [Microsoft: privacy settings for recommendations and offers](https://support.microsoft.com/en-gb/windows/privacy/privacy-settings-for-recommendations-offers-in-windows-11)
- [Microsoft: WebView2 distribution](https://learn.microsoft.com/microsoft-edge/webview2/concepts/distribution)
- [Microsoft: policy-based inbox app removal](https://learn.microsoft.com/en-us/windows/configuration/policy-based-inbox-app-removal/policy-based-inbox-app-removal)
- [Ubuntu: unnecessary packages](https://documentation.ubuntu.com/security/common-mistakes/unnecessary-packages/)
- [Ubuntu Insights](https://discourse.ubuntu.com/t/ubuntu-insights-how-telemetry-is-changing-on-ubuntu-desktop/73442/)
- [ArchWiki: system maintenance](https://wiki.archlinux.org/title/System_maintenance)
