# AGENTS

## Project structure and module organization

This repository backs up and restores a personal Arch Linux/Omarchy setup. Root Bash scripts provide the entry points: `export.sh` captures packages and dotfiles, `install.sh` restores the setup, and `personaliza-meu-omarchy.sh` applies appearance settings.

- `dotfiles/` mirrors paths under `$HOME`, including hidden `.config/` directories.
- `packages/` contains pacman, AUR, and Flatpak lists plus manual installation notes.
- `webapps/webapps.txt` stores one `Name|URL` entry per webapp.
- `tests/` contains Bats suites, miniature fixtures, and shared mocks in `test_helper/common.bash`.
- `.github/workflows/` runs CI and releases; `.github/scripts/` generates release notes and changelog sections.

## Build, test, and development commands

There is no compilation step. Install `bats-core`, `shellcheck`, and `shfmt` for local checks.

```bash
bats -r tests                         # Run all suites
bats tests/install.bats               # Run restore tests only
mapfile -t scripts < <(git ls-files '*.sh')
shellcheck "${scripts[@]}"             # Check tracked shell scripts
shfmt -d -i 2 -ci "${scripts[@]}"       # Verify formatting
shfmt -w -i 2 -ci "${scripts[@]}"       # Apply formatting
```

Run these commands in Bash. `./personaliza-meu-omarchy.sh -n -y` previews appearance changes on an Omarchy machine. `./export.sh` refreshes repository data from the source machine; `./install.sh` changes the destination machine.

## Coding style and naming conventions

Use Bash shebangs, `set -euo pipefail`, two-space indentation, and the existing shfmt settings. Quote path and variable expansions; pass package arguments as arrays. Follow existing lowercase function names and uppercase configuration constants. Preserve each application's native dotfile syntax and established filenames.

## Testing guidelines

Run the existing suite before and after script changes. Add regression cases to the relevant `tests/*.bats` file using descriptive `@test` names. Exercise real scripts with temporary homes, small fixtures, and mocked system commands. Never test restoration against the contributor's actual home. No numeric coverage threshold is configured.

## Commit and pull request guidelines

Use Conventional Commits, as in `fix(install): preserve existing configuration` or `docs: clarify restore instructions`. Follow `feature/*` → `develop` → `main`. Describe behavior changes and validation in PRs; link related issues and include screenshots for appearance changes. Ensure Bats, ShellCheck, and formatting checks pass.

## Configuration safety

Review exported files before committing. Exclude credentials, tokens, browser profiles, caches, and generated theme output according to `.gitignore`. Preserve restore backups and the appearance script's limited scope.
