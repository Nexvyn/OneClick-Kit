# Development profile

[profiles/development.json](../profiles/development.json) contains the 25 approved tools and retention settings.

With Node.js installed:

```sh
node tools/plan-development.mjs
node tools/install-development.mjs
node tools/install-development.mjs --apply cursor github-cli
```

The first two commands preview available choices without installing anything. Installation requires explicit tool IDs and --apply. The installer uses exact approved WinGet IDs or available distribution packages through apt; existing matching installs are skipped. Tools lacking verified adapters are listed with their official links for manual installation. Project-specific packages, toolchains needing additional prerequisites, and remote services are not installed globally. No extra standalone applications are added to the manifest.

For cache setup and project commands, see [shared-cache.md](shared-cache.md).

The existing exported-app restore remains a separate opt-in workflow. Do not use it if you want only the curated profile.

The first-install scripts now use the curated profile by default. With no arguments they preview; pass --apply plus specific tool IDs to apply and configure the shared cache. Install Node.js from its official source first if it is missing. To restore an exported app list, use the existing install_apps script explicitly.
