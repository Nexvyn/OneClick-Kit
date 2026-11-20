# Convert a project to the shared cache

Paste this into the AI of each project. Set up the shared cache first (see [shared-cache.md](shared-cache.md)).

```
Convert this project to the shared cache. Use pnpm only.

1. Tell me the size of node_modules and of any local target, build and .gradle folders, then wait for my yes.
2. If package-lock.json or yarn.lock exists, run `pnpm import` first.
3. After my yes, delete only: node_modules, local target folders, the old lockfile (package-lock.json or yarn.lock). Nothing else.
4. Run `pnpm install`.
5. Run the project's build and tests.
6. Confirm to me in 3 lines: new node_modules size, build result, test result.
```
