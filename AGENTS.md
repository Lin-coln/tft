# Repository instructions

## SDK submodule is read-only

- Do not create, edit, delete, rename, format, or stage any file under `sdk/`.
- Do not run commands that change the `sdk` submodule checkout, its Git state, or the submodule pointer in this repository.
- Treat `sdk/` as read-only even when a task uses SDK interfaces or a build depends on SDK changes. If the task cannot be completed without changing `sdk/`, stop and explain the blocker to the user.
