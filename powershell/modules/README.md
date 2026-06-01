# powershell/modules/ — Drop-in PowerShell extensions

Any `*.ps1` file placed here is automatically dot-sourced by `profile.ps1`
in **alphabetical order**, _after_ the four core files
(`aliases.ps1` → `psreadline.ps1` → `prompt.ps1` → `completions.ps1`).

## Use this for

- Project-specific functions (e.g. `work-helpers.ps1`)
- Experimental features before they graduate to a core file
- Machine-specific overrides that shouldn't live in the repo

## Naming convention

`descriptive-name.ps1` — all lowercase with hyphens, e.g. `docker-helpers.ps1`

## Notes

- Each file is dot-sourced in the caller's scope, so functions and variables
  you define here are available at the prompt.
- Files here are **not** run with `-ErrorAction Stop`; a broken module will
  print a warning but won't break the entire profile.
- Do **not** put secrets here — this directory is tracked by git.

