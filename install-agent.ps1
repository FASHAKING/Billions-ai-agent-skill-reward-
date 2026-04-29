# Billions FAIAR — Verified Agent Identity installer (Windows PowerShell)
# Usage:
#   irm https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent.ps1 | iex

$ErrorActionPreference = "Stop"

function Say($msg)  { Write-Host "==> " -ForegroundColor Cyan -NoNewline;  Write-Host $msg -ForegroundColor White }
function Ok($msg)   { Write-Host "OK  " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Warn($msg) { Write-Host "!   " -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Die($msg)  { Write-Host "X   " -ForegroundColor Red -NoNewline; Write-Host $msg; exit 1 }

Say "Billions FAIAR — Verified Agent Identity installer"
Write-Host "    Platform detected: Windows PowerShell"
Write-Host ""

# Ensure Node.js + npx
$nodeOk = (Get-Command node -ErrorAction SilentlyContinue) -and (Get-Command npx -ErrorAction SilentlyContinue)
if (-not $nodeOk) {
    Warn "Node.js / npx not found. Attempting install via winget..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path","User")
    } else {
        Die "winget not available. Install Node.js from https://nodejs.org/ then re-run."
    }
}

Ok "Node $(node -v) — npx $(npx -v)"
Write-Host ""

# Step 1
Say "Step 1/2 — installing clawhub verified-agent-identity"
npx --yes clawhub@latest install verified-agent-identity
if ($LASTEXITCODE -ne 0) { Die "Step 1 failed." }

Write-Host ""
# Step 2
Say "Step 2/2 — adding BillionsNetwork/verified-agent-identity skill"
Warn "When prompted, use Up/Down to scroll, SPACE to select your agent (e.g. Claude Code), ENTER to confirm."
npx --yes skills add BillionsNetwork/verified-agent-identity
if ($LASTEXITCODE -ne 0) { Die "Step 2 failed." }

Write-Host ""
Ok "Verified Agent Identity skill installed."
Say "You're qualified for the Billions FAIAR reward!"
Write-Host ""
Write-Host "Built with " -NoNewline
Write-Host "♥" -ForegroundColor Red -NoNewline
Write-Host " by fashaking — " -NoNewline
Write-Host "https://x.com/FASHAKING3" -ForegroundColor Cyan
