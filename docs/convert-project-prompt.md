# Convert a project to the shared cache

Paste into the AI for the project:

```text
Inspect the project root, current package manager, lockfile, Cargo workspace
and existing build/cache paths. Report sizes without deleting anything.
Preserve the existing lockfile, package manager, source, local patches and
configuration. Use the OneClick Kit devcache activate and run commands
from the documented workspace root. Use a unique Cargo target directory
and shared sccache; never share a mutable target across projects.
Run the existing build and tests, then report the results and disk usage.
Do not clean active workspaces. Plan cleanup for inactive generated outputs
only after the documented grace period and get explicit owner approval.
Do not change toolchains or migrate package managers without approval.
```
