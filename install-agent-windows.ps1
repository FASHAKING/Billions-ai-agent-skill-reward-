# ============================================================
#  Verified Agent Identity — All-in-One Installer for Windows
#  GitHub: https://github.com/FASHAKING/Billions-ai-agent-skill-reward-
#
#  Usage (run in PowerShell or Windows Terminal):
#    irm https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent-windows.ps1 | iex
#
#  What this script does:
#    1. Checks for Node.js and Git (installs via winget if missing)
#    2. Detects an existing Billions identity (or asks you to import / create one)
#    3. Clones the verified-agent-identity repo
#    4. Installs all dependencies (including the commonly missing ones)
#    5. Creates / imports your Agent Ethereum Identity
#    6. Generates a verification URL so you can link this agent to your
#       Billions account in the browser
# ============================================================

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

function Write-Banner {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                          ║" -ForegroundColor Cyan
    Write-Host "  ║   Verified Agent Identity — Windows Installer            ║" -ForegroundColor Cyan
    Write-Host "  ║   by BillionsNetwork                                     ║" -ForegroundColor Cyan
    Write-Host "  ║                                                          ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$StepNum, [string]$StepDesc)
    Write-Host ""
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "    STEP $StepNum : $StepDesc" -ForegroundColor Green
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
}

function Write-Success { param([string]$Msg) Write-Host "    [OK] $Msg" -ForegroundColor Green }
function Write-Warn    { param([string]$Msg) Write-Host "    [!]  $Msg" -ForegroundColor Yellow }
function Write-Err     { param([string]$Msg) Write-Host "    [X]  $Msg" -ForegroundColor Red }
function Write-Info    { param([string]$Msg) Write-Host "    [i]  $Msg" -ForegroundColor Cyan }

function Read-Secret {
    param([string]$Prompt)
    $sec = Read-Host -AsSecureString $Prompt
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
    finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

Write-Banner

$InstallDir = Join-Path $HOME "verified-agent-identity"

# --- Identity intent ---
$ExistingKey = $null
$UseMode = $null

if ($env:BILLIONS_PRIVATE_KEY) {
    $ExistingKey = $env:BILLIONS_PRIVATE_KEY
    $UseMode = "env"
    Write-Info "Detected BILLIONS_PRIVATE_KEY environment variable - will import it."
}

if (-not $UseMode -and (Test-Path $InstallDir)) {
    $hasLocal = $null
    foreach ($f in @(".identity","identity.json",".env","agent.json")) {
        $p = Join-Path $InstallDir $f
        if (Test-Path $p) { $hasLocal = $p; break }
    }
    if ($hasLocal) {
        Write-Host "  Existing Billions identity found on this PC:" -ForegroundColor White
        Write-Host "      $hasLocal"
        Write-Host ""
        $reuse = Read-Host "    Reuse it? [Y/n]"
        if ([string]::IsNullOrWhiteSpace($reuse) -or $reuse -eq "y" -or $reuse -eq "Y") {
            $UseMode = "reuse"
        }
    }
}

if (-not $UseMode) {
    Write-Host "  No existing Billions identity is being reused. Pick one:" -ForegroundColor White
    Write-Host "      [1] I already have a private key - let me paste it (input hidden)"
    Write-Host "      [2] Generate a brand-new identity for me"
    Write-Host ""
    $idChoice = Read-Host "    Enter 1 or 2 [2]"
    switch ($idChoice) {
        "1" {
            $ExistingKey = Read-Secret "    Paste your Ethereum private key (0x...)"
            if ([string]::IsNullOrWhiteSpace($ExistingKey)) { Write-Err "Empty key. Aborting."; exit 1 }
            $UseMode = "import"
        }
        default { $UseMode = "generate" }
    }
}

# --- Agent name & description ---
Write-Host ""
Write-Host "  Agent details:" -ForegroundColor White
Write-Host ""

do {
    $AgentName = Read-Host "    Enter your Agent Name (e.g., MyAgent)"
    if ([string]::IsNullOrWhiteSpace($AgentName)) { Write-Warn "Agent name cannot be empty." }
} while ([string]::IsNullOrWhiteSpace($AgentName))

do {
    $AgentDesc = Read-Host "    Enter your Agent Description (e.g., AI trading agent)"
    if ([string]::IsNullOrWhiteSpace($AgentDesc)) { Write-Warn "Agent description cannot be empty." }
} while ([string]::IsNullOrWhiteSpace($AgentDesc))

Write-Host ""
Write-Info "Agent Name: $AgentName"
Write-Info "Agent Description: $AgentDesc"
Write-Info "Identity mode: $UseMode"
Write-Host ""

$Confirm = Read-Host "    Proceed with installation? (y/n)"
if ($Confirm -ne "y" -and $Confirm -ne "Y") {
    Write-Warn "Installation cancelled by user."
    exit 0
}

# ============================================================
#  STEP 1: Node.js and Git
# ============================================================
Write-Step "1/5" "Checking for Node.js and Git"

$NodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $NodeCmd) {
    Write-Warn "Node.js not found. Attempting to install via winget..."
    $HasWinget = Get-Command winget -ErrorAction SilentlyContinue
    if ($HasWinget) {
        Write-Info "Trying user-scope install (no admin required)..."
        winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements --scope user 2>$null
        $WingetExit = $LASTEXITCODE
        if ($WingetExit -ne 0) {
            Write-Warn "User-scope install not available. Trying machine-scope (may require admin)..."
            winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
            $WingetExit = $LASTEXITCODE
        }
        if ($WingetExit -ne 0) { Write-Err "Node.js installation failed (exit $WingetExit). Install from https://nodejs.org and re-run."; exit 1 }
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
        $NodeCmd = Get-Command node -ErrorAction SilentlyContinue
        if (-not $NodeCmd) { Write-Err "Node.js installed but not yet in PATH. Reopen your terminal and re-run."; exit 1 }
    } else {
        Write-Err "winget not available. Install Node.js manually from https://nodejs.org"; exit 1
    }
}
Write-Success "Node.js version: $(node -v)"
Write-Success "npm version: $(npm -v)"

$GitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $GitCmd) {
    Write-Warn "Git not found. Attempting to install via winget..."
    $HasWinget = Get-Command winget -ErrorAction SilentlyContinue
    if ($HasWinget) {
        Write-Info "Trying user-scope install (no admin required)..."
        winget install Git.Git --accept-source-agreements --accept-package-agreements --scope user 2>$null
        $WingetExit = $LASTEXITCODE
        if ($WingetExit -ne 0) {
            Write-Warn "User-scope install not available. Trying machine-scope (may require admin)..."
            winget install Git.Git --accept-source-agreements --accept-package-agreements
            $WingetExit = $LASTEXITCODE
        }
        if ($WingetExit -ne 0) { Write-Err "Git installation failed (exit $WingetExit). Install from https://git-scm.com and re-run."; exit 1 }
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
        $GitCmd = Get-Command git -ErrorAction SilentlyContinue
        if (-not $GitCmd) { Write-Err "Git installed but not yet in PATH. Reopen your terminal and re-run."; exit 1 }
    } else {
        Write-Err "winget not available. Install Git manually from https://git-scm.com"; exit 1
    }
}
Write-Success "Git version: $(git --version)"

# ============================================================
#  STEP 2: Clone (or reuse) the repo
# ============================================================
Write-Step "2/5" "Preparing verified-agent-identity repository"

if ($UseMode -eq "reuse") {
    Write-Info "Reusing existing folder at: $InstallDir"
} else {
    if (Test-Path $InstallDir) {
        Write-Warn "Existing folder found. Removing for a fresh install..."
        Remove-Item -Recurse -Force $InstallDir
    }
    git clone https://github.com/BillionsNetwork/verified-agent-identity.git $InstallDir
    Write-Success "Repository cloned successfully."
}
Set-Location $InstallDir
Write-Info "Working directory: $(Get-Location)"

# ============================================================
#  STEP 3: Install dependencies
# ============================================================
Write-Step "3/5" "Installing project dependencies"

npx --yes clawhub@latest install verified-agent-identity
Write-Success "clawhub dependencies installed."

Write-Info "Installing commonly required modules to prevent errors..."
npm install shell-quote          ; Write-Success "Installed: shell-quote"
npm install @iden3/js-iden3-auth ; Write-Success "Installed: @iden3/js-iden3-auth"
npm install ethers@6             ; Write-Success "Installed: ethers v6"
npm install uuid                 ; Write-Success "Installed: uuid"
Write-Success "All dependencies installed."

# ============================================================
#  STEP 4: Identity
# ============================================================
Write-Step "4/5" "Setting up your Agent Ethereum Identity"

switch ($UseMode) {
    "reuse" {
        Write-Info "Skipping identity creation - reusing existing key."
    }
    { $_ -in "env","import" } {
        Write-Info "Importing your existing private key..."
        node scripts/createNewEthereumIdentity.js --key $ExistingKey
        $ExistingKey = $null
        Write-Success "Identity imported."
    }
    "generate" {
        node scripts/createNewEthereumIdentity.js
        Write-Host ""
        Write-Host "  !! IMPORTANT - BACK UP THE PRIVATE KEY PRINTED ABOVE !!" -ForegroundColor Red
        Write-Host "  This key IS your agent's Billions identity. If you lose it," -ForegroundColor Red
        Write-Host "  you lose the identity (and any FAIAR rewards tied to it)." -ForegroundColor Red
        Write-Host "  Save it in a password manager NOW. It will not be shown again." -ForegroundColor Red
        Write-Host ""
        Read-Host "    Press ENTER once you have backed up the key" | Out-Null
        Write-Success "New identity generated."
    }
}

# ============================================================
#  STEP 5: Link to Billions account
# ============================================================
Write-Step "5/5" "Generating Billions account verification link"

Write-Host ""
Write-Info "Using Agent Name: $AgentName"
Write-Info "Using Agent Description: $AgentDesc"
Write-Host ""

# Pass challenge JSON via env var to avoid PowerShell quoting issues with external commands
$env:AGENT_CHALLENGE = ConvertTo-Json -Compress @{ name = $AgentName; description = $AgentDesc }
node -e "const cp = require('child_process'); cp.execFileSync('node', ['scripts/manualLinkHumanToAgent.js', '--challenge', process.env.AGENT_CHALLENGE], {stdio: 'inherit'})"

# ============================================================
#  DONE
# ============================================================
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║                                                          ║" -ForegroundColor Green
Write-Host "  ║    Installation Complete!                                ║" -ForegroundColor Green
Write-Host "  ║                                                          ║" -ForegroundColor Green
Write-Host "  ╠══════════════════════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "  ║                                                          ║" -ForegroundColor Green
Write-Host "  ║   NEXT STEPS:                                            ║" -ForegroundColor Green
Write-Host "  ║   1. Copy the verification URL printed above             ║" -ForegroundColor Green
Write-Host "  ║   2. Open it in your browser                             ║" -ForegroundColor Green
Write-Host "  ║   3. Sign in with your Billions account / connect wallet ║" -ForegroundColor Green
Write-Host "  ║   4. Verify - and you're done!                           ║" -ForegroundColor Green
Write-Host "  ║                                                          ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
