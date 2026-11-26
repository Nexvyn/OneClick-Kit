# Convert a project to the shared cache

Run the shared cache setup first. Then paste this into the AI of each project:

```text
Convert this project to the shared cache. Use pnpm only.

1. Tell me the size of node_modules and of any local target, build and
   .gradle folders, then wait for my yes.
2. If package-lock.json or yarn.lock exists, run `pnpm import` first.
3. After my yes, delete only: node_modules, local target folders and the
   old lockfile (package-lock.json or yarn.lock). Nothing else.
4. Run `pnpm install`.
5. For Rust, build through the OneClick Kit wrapper so the project gets its
   own target folder in the shared cache:
   node <kit>/tools/devcache.mjs run <project> -- cargo build
   Do not set target-dir or CARGO_TARGET_DIR yourself.
6. Run the project's build and tests.
7. Confirm to me in 3 lines: new node_modules size, build result, test result.
```

Replace `<kit>` with the folder of OneClick Kit and `<project>` with the project folder.
