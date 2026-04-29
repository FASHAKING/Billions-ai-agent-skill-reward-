# Billions FAIAR — Verified Agent Identity

One-line installers for the Billions Network **Verified Agent Identity** skill.
Qualifies you for the Billions FAIAR reward.

## Quick install

### Linux / macOS / Termux (Android)
```bash
curl -sL https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent.sh | bash
```

### Windows PowerShell
```powershell
irm https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent.ps1 | iex
```

## What the installer does

1. Detects your platform and ensures Node.js / `npx` is installed
   (auto-installs via `pkg`, `apt`, `dnf`, `pacman`, `brew`, or `winget` when possible).
2. Runs `npx clawhub@latest install verified-agent-identity`.
3. Runs `npx skills add BillionsNetwork/verified-agent-identity`.

You'll only be prompted when the second step asks **which agent to install to**.
Use ↑/↓ to scroll, **Space** to select (e.g. Claude Code), **Enter** to confirm.

## Manual one-liners

If you'd rather skip the installer script:

**bash / zsh (Linux, macOS, Termux):**
```bash
npx clawhub@latest install verified-agent-identity && npx skills add BillionsNetwork/verified-agent-identity
```

**PowerShell:**
```powershell
npx clawhub@latest install verified-agent-identity; if ($LASTEXITCODE -eq 0) { npx skills add BillionsNetwork/verified-agent-identity }
```
