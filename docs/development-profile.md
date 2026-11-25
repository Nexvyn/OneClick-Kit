# Development profile

The approved tool list is maintained in [profiles/development.json](../profiles/development.json). It contains the 25 selected tools and no additional applications. Project dependencies are installed only within the relevant project; remote-only services are references, not desktop installs.

With Node.js installed, preview the profile:

```sh
node tools/plan-development.mjs
node tools/plan-development.mjs traycer cursor moon helium
```

The planner is read-only. It rejects unknown tool IDs, prints the official sources and indicates desktop availability for explicitly restricted applications. The existing first-install workflow is unchanged by this initial PR. Actual installation adapters and project lifecycle commands are follow-up implementation work under #1.

## Compact cache policy

- Total disposable development data: 35 GiB retention target, warning at 25 GiB, aim for 40 GiB free.
- Cargo target and intermediate outputs: separate workspace/worktree directories, warning at 4 GiB, retention target 5 GiB per workspace.
- Shared sccache: 5 GiB.
- Idle workspace dependency cleanup eligibility after 24 hours; generated build outputs after 48 hours.
- Budgets are soft targets. Never interrupt active builds or delete unreviewed data.
- Preserve lockfiles and use the existing package manager. Keep active and pinned workspaces intact.
- Shared download caches remain separate by package manager. Keep package links on the same filesystem where supported.

No cleanup or installation is executed by the planner. Existing cache settings remain unchanged until the migration implementation is reviewed.
