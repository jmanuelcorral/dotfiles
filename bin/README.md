# bin/ — Your Personal Scripts

Place your own scripts here. They'll be added to PATH automatically.

## How to Add a Tool

1. **Add your script:**
   ```
   bin/gituseswitch        # bash/zsh script (needs shebang)
   bin/mybackup.ps1        # PowerShell script
   ```

2. **Make it executable (Unix):**
   ```bash
   chmod +x bin/gituseswitch
   ```

3. **Register it for the help system:**
   ```
   dotfiles register gituseswitch --description "Switch git user configs"
   ```

4. **Verify:**
   ```
   dotfiles help           # should show your tool
   gituseswitch --help     # should work
   ```

## Script Guidelines

- Include a shebang for Unix scripts: `#!/usr/bin/env bash`
- PowerShell scripts should have `.ps1` extension
- Cross-platform scripts: use PowerShell Core (`#!/usr/bin/env pwsh`)
- Add `--help` support to your scripts for discoverability
