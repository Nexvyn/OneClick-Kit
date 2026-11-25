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

The run command gives each canonical workspace or worktree a distinct hashed target directory under the configured cache root. Use the actual Cargo workspace root (not a member crate). A plain Cargo invocation uses its existing configuration; configure your IDE tasks to use the wrapper if you want the centralized project-specific directory. Existing project configuration is not rewritten. If a project overrides Cargo's intermediate build directory, review it separately.

Activate restores missing dependencies using the existing lockfile and package manager; existing installations are preserved. Pin/unpin controls retention. Deactivate only after stopping external IDEs, builds, tests and watchers. The registry tracks cooperating commands, not all processes. The run wrapper holds a lock until the child command exits.

Status reports logical sizes, deduplicating identifiable hardlinks, and warns at the configured budgets. It is not an exact physical allocation measurement. Plan lists idle candidates without modifying data. The cleanup command is deliberately manual:

```sh
node tools/devcache.mjs clean /path/to/project deps --apply --confirm-idle
node tools/devcache.mjs clean /path/to/project target --apply --confirm-idle
```

Only use it after checking that all external processes have stopped, the directory has no manual edits, and any required release artifacts are backed up. It refuses active/pinned projects, recent projects, linked top-level directories and tracked dependencies. There is no unattended cleanup.

## Retention policy

25 GiB warning; 35 GiB total retention target; aim for 40 GiB free. Cargo per workspace: warning at 4 GiB, target 5 GiB. Shared sccache: 5 GiB. Idle dependencies are eligible after 24 hours; build outputs after 48 hours. Allow exceptions for active builds. These are soft limits, not quotas.

The ordinary developer-cache maintenance step preserves package downloads. Use tool-specific approved pruning only after reviewing space and dependencies. Do not disable antivirus scanning for executable dependency caches. Keep different operating systems and toolchains isolated, and do not sync live caches.

See [development-profile.md](development-profile.md) for the approved tools and installation workflow.
