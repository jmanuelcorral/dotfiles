# CLI Cheatsheet

Quick reference for the most-used commands. Powers `dotfiles help`.
Run `dotfiles help <keyword>` to filter, or just `dotfiles help` for interactive search.

---

## Git

| Command | Description |
|---------|-------------|
| `git status` | Show working tree status |
| `git log --oneline -15` | Last 15 commits, compact |
| `git log --oneline --graph --all` | Visual branch graph |
| `git diff` | Unstaged changes |
| `git diff --staged` | Staged changes (before commit) |
| `git add -p` | Interactive stage by hunk |
| `git stash` | Stash uncommitted changes |
| `git stash pop` | Restore last stash |
| `git stash list` | Show all stashes |
| `git branch -a` | List all branches (local + remote) |
| `git checkout -b <name>` | Create and switch to branch |
| `git switch <name>` | Switch branch (modern syntax) |
| `git switch -c <name>` | Create + switch (modern) |
| `git pull --rebase` | Pull with rebase (avoids merge commits) |
| `git push -u origin HEAD` | Push current branch, set upstream |
| `git push --force-with-lease` | Force push safely |
| `git rebase -i HEAD~3` | Interactive rebase (last 3 commits) |
| `git cherry-pick <sha>` | Apply a commit from another branch |
| `git bisect start` | Start binary search for a bug |
| `git reset --soft HEAD~1` | Undo last commit, keep changes staged |
| `git reset --hard HEAD` | Discard all unstaged changes |
| `git clean -fd` | Remove untracked files + dirs |
| `git remote -v` | Show remotes |
| `git tag -a v1.0 -m "msg"` | Create annotated tag |

## GitHub CLI (gh)

| Command | Description |
|---------|-------------|
| `gh pr create` | Create pull request (interactive) |
| `gh pr create --draft` | Create draft PR |
| `gh pr list` | List open PRs |
| `gh pr view` | View current branch PR |
| `gh pr checkout <number>` | Check out a PR locally |
| `gh pr merge --squash` | Merge PR with squash |
| `gh issue create` | Create new issue |
| `gh issue list` | List issues |
| `gh issue view <number>` | View an issue |
| `gh repo clone <owner/repo>` | Clone a repository |
| `gh repo fork` | Fork current repo |
| `gh run list` | List GitHub Actions runs |
| `gh run watch` | Watch current Actions run |
| `gh auth status` | Check authentication status |
| `gh release create v1.0` | Create a release |

## PowerShell

| Command | Description |
|---------|-------------|
| `Get-Command <name>` | Find a command (like `which`) |
| `Get-Help <cmd> -Examples` | Show usage examples |
| `Get-Help <cmd> -Online` | Open online docs |
| `Get-ChildItem -Recurse` | Recursive directory listing |
| `Select-String <pattern> .\*.ps1` | Grep in files |
| `Get-History` | Show command history |
| `Invoke-History <n>` | Re-run history entry n |
| `Set-Location -` | Go to previous directory |
| `$PSVersionTable` | Show PowerShell version info |
| `Get-Module -ListAvailable` | List installed modules |
| `Import-Module <name>` | Load a module |
| `Install-Module <name> -Scope CurrentUser` | Install from PSGallery |
| `[pscustomobject]@{...}` | Create a quick object |
| `Get-Clipboard` / `Set-Clipboard` | Clipboard access |
| `Start-Process -Verb RunAs pwsh` | Open elevated PowerShell |

## Navigation

| Alias / Command | Description |
|-----------------|-------------|
| `z <keyword>` | Jump to frecent directory (zoxide) |
| `zi` | Interactive directory jump (zoxide + fzf) |
| `ll` | `eza --long --all --git` (or `Get-ChildItem -Force`) |
| `lt` | `eza --tree --level=2` |
| `..` | `cd ..` |
| `...` | `cd ../..` |
| `~` | Home directory |
| `cd -` | Go back to previous dir (PowerShell: `Set-Location -`) |
| `pushd` / `popd` | Directory stack |

## Files & Search

| Command | Description |
|---------|-------------|
| `bat <file>` | cat with syntax highlighting + line numbers |
| `bat --plain <file>` | bat without decorations |
| `eza -la --git` | ls with git status |
| `eza --tree --level=3` | Directory tree |
| `fd <pattern>` | Fast find by filename |
| `fd -e ps1` | Find all .ps1 files |
| `fd -t d <name>` | Find directories |
| `rg <pattern>` | Fast grep (ripgrep) |
| `rg <pattern> -t ps1` | Ripgrep, only .ps1 files |
| `rg -l <pattern>` | List files containing pattern |
| `rg -i <pattern>` | Case-insensitive search |
| `rg --hidden <pattern>` | Include hidden files |

## Fuzzy Finder (fzf)

| Command | Description |
|---------|-------------|
| `fzf` | Fuzzy-filter stdin |
| `ls \| fzf` | Pick a file interactively |
| `cat (ls \| fzf)` | Open selected file |
| `Ctrl+R` (PSFzf) | Fuzzy history search |
| `Alt+C` (PSFzf) | Fuzzy cd into directory |
| `Tab` | Multi-select in fzf |

## JSON / jq

| Command | Description |
|---------|-------------|
| `cat file.json \| jq '.'` | Pretty-print JSON |
| `jq '.key'` | Extract a key |
| `jq '.[] \| .name'` | Map over array |
| `jq 'select(.status == "open")'` | Filter objects |
| `jq -r '.name'` | Raw output (no quotes) |
| `jq -c`  | Compact output |

## dotfiles (this tool)

| Command | Description |
|---------|-------------|
| `dotfiles help` | Show this cheatsheet (interactive with fzf) |
| `dotfiles help <query>` | Filter cheatsheet by keyword |
| `dotfiles register <name>` | Register a script in bin/ |
| `dotfiles list` | List registered tools |
| `dotfiles update` | git pull + reload profile |
| `dotfiles edit` | Open dotfiles repo in editor |

---

> **Tip:** Run `dotfiles help git` to see only git commands.
> **Tip:** Run `dotfiles register gituseswitch -Description "Switch git user"` to register your own tools.

