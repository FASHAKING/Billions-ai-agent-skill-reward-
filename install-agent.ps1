# ============================================================
#  Billions FAIAR — Verified Agent Identity installer (Windows)
#
#  Usage (PowerShell or Windows Terminal):
#    irm https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent.ps1 | iex
#
#  What this does, in order:
#    1. Decide what to do with the agent identity:
#         - reuse one already on disk if found, or
#         - import a private key you paste, or
#         - generate a brand-new one
#       Only the "generate" branch asks for the agent name & description.
#    2. Install Node.js (and Git) via winget if missing
#    3. Try `npx clawhub@latest install verified-agent-identity` first,
#       and fall back to `git clone` + npm install + commonly-missing
#       modules if clawhub fails.
#    4. Run scripts/createNewEthereumIdentity.js  (skipped if reusing)
#    5. Run scripts/manualLinkHumanToAgent.js    (only in "generate" mode)
#    6. Run `npx skills add BillionsNetwork/verified-agent-identity` so
#       you can register the skill with Claude Code / Cursor / etc.
# ============================================================

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

function Say   ($m) { Write-Host "==> " -ForegroundColor Cyan -NoNewline;   Write-Host $m -ForegroundColor White }
function Ok    ($m) { Write-Host "OK  " -ForegroundColor Green -NoNewline;  Write-Host $m }
function Warn  ($m) { Write-Host "!   " -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Die   ($m) { Write-Host "X   " -ForegroundColor Red -NoNewline;    Write-Host $m; exit 1 }

function Ask {
    param([string]$Prompt, [string]$Default = "")
    if ($Default) { $p = "? $Prompt [$Default]" } else { $p = "? $Prompt" }
    $reply = Read-Host $p
    if ([string]::IsNullOrWhiteSpace($reply)) { return $Default }
    return $reply
}

function AskSecret {
    param([string]$Prompt)
    $sec = Read-Host -AsSecureString "? $Prompt"
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
    finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

Say "Billions FAIAR — Verified Agent Identity installer"
Write-Host "    Platform detected: Windows PowerShell"
Write-Host ""

# ============================================================
#  STEP 0 — decide identity intent
# ============================================================

$SkillPaths = @(
    "$HOME\verified-agent-identity",
    "$HOME\.claude\skills\verified-agent-identity",
    "$HOME\.cursor\skills\verified-agent-identity",
    "$HOME\.cline\skills\verified-agent-identity",
    "$HOME\.continue\skills\verified-agent-identity",
    "$HOME\.config\clawhub\skills\verified-agent-identity",
    "$HOME\.clawhub\skills\verified-agent-identity"
)
$IdFiles = @(".identity","identity.json",".env","agent.json")

$ExistingKey = $null
$UseMode = $null
$ExistingDir = $null

# 1) BILLIONS_PRIVATE_KEY env var.
if ($env:BILLIONS_PRIVATE_KEY) {
    $ExistingKey = $env:BILLIONS_PRIVATE_KEY
    $UseMode = "env"
    Ok "Detected BILLIONS_PRIVATE_KEY environment variable - will import it."
}

# 2) Find a folder on disk that already has identity files.
if (-not $UseMode) {
    foreach ($d in $SkillPaths) {
        if (-not (Test-Path $d)) { continue }
        foreach ($f in $IdFiles) {
            if (Test-Path (Join-Path $d $f)) { $ExistingDir = $d; break }
        }
        if ($ExistingDir) { break }
    }
    if ($ExistingDir) {
        Write-Host ""
        Ok "Existing Billions identity found on this machine:"
        Write-Host "      $ExistingDir"
        $reuse = Ask "Reuse it?" "Y"
        if ([string]::IsNullOrWhiteSpace($reuse) -or $reuse -match "^(y|Y|yes|Yes)$") {
            $UseMode = "reuse"
        }
    }
}

# 3) Otherwise prompt import vs generate.
if (-not $UseMode) {
    Write-Host ""
    Write-Host "    No existing Billions identity is being reused. Pick one:"
    Write-Host "      [1] I already have a private key - let me paste it (input hidden)"
    Write-Host "      [2] Generate a brand-new identity for me"
    Write-Host ""
    $choice = Ask "Enter 1 or 2" "2"
    switch ($choice) {
        "1" {
            $ExistingKey = AskSecret "Paste your Ethereum private key (0x...)"
            if ([string]::IsNullOrWhiteSpace($ExistingKey)) { Die "Empty key. Aborting." }
            $UseMode = "import"
        }
        default { $UseMode = "generate" }
    }
}

# 4) Only ask for agent name / description in "generate" mode.
$AgentName = ""; $AgentDesc = ""
if ($UseMode -eq "generate") {
    Write-Host ""
    do {
        $AgentName = Read-Host "? Agent name (e.g. MyAgent)"
        if ([string]::IsNullOrWhiteSpace($AgentName)) { Warn "Agent name cannot be empty." }
    } while ([string]::IsNullOrWhiteSpace($AgentName))

    do {
        $AgentDesc = Read-Host "? Agent description (e.g. AI trading agent)"
        if ([string]::IsNullOrWhiteSpace($AgentDesc)) { Warn "Agent description cannot be empty." }
    } while ([string]::IsNullOrWhiteSpace($AgentDesc))
}

Write-Host ""
Write-Host "    Identity mode : $UseMode"
if ($AgentName) { Write-Host "    Agent name    : $AgentName" }
if ($AgentDesc) { Write-Host "    Description   : $AgentDesc" }
Write-Host ""

# ============================================================
#  STEP 1 — install Node.js + Git via winget if missing
# ============================================================
Say "Step 1 - installing Node.js & Git if missing"

function Install-WithWinget {
    param([string]$Id)
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Die "winget not available. Install $Id manually then re-run."
    }
    winget install $Id --accept-source-agreements --accept-package-agreements --scope user 2>$null
    if ($LASTEXITCODE -ne 0) {
        winget install $Id --accept-source-agreements --accept-package-agreements
    }
    if ($LASTEXITCODE -ne 0) { Die "$Id installation failed." }
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Warn "Node.js not found - installing..."
    Install-WithWinget "OpenJS.NodeJS.LTS"
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Die "Node.js installed but not yet in PATH. Reopen the terminal and re-run."
    }
}
Ok "Node $(node -v) - npx $(npx -v)"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Warn "Git not found - installing..."
    Install-WithWinget "Git.Git"
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Die "Git installed but not yet in PATH. Reopen the terminal and re-run."
    }
}
Ok "$(git --version)"

# ============================================================
#  STEP 2 — clawhub first, git clone fallback
# ============================================================
Say "Step 2 - installing skill files (clawhub first, git clone fallback)"

$WorkingDir = $null
$ClawhubOk = $false

try {
    npx --yes clawhub@latest install verified-agent-identity
    if ($LASTEXITCODE -eq 0) {
        $ClawhubOk = $true
        Ok "clawhub install succeeded."
        foreach ($d in $SkillPaths) {
            if ((Test-Path $d) -and (Test-Path (Join-Path $d "scripts\createNewEthereumIdentity.js"))) {
                $WorkingDir = $d; break
            }
        }
        if (-not $WorkingDir) {
            $found = Get-ChildItem -Path $HOME -Recurse -Directory -Filter "verified-agent-identity" -ErrorAction SilentlyContinue |
                Where-Object { Test-Path (Join-Path $_.FullName "scripts\createNewEthereumIdentity.js") } |
                Select-Object -First 1
            if ($found) { $WorkingDir = $found.FullName }
        }
        if (-not $WorkingDir) { Warn "clawhub installed but scripts/ folder was not found - falling back to git clone." }
    }
} catch {
    Warn "clawhub install threw: $($_.Exception.Message)"
}

if (-not $WorkingDir) {
    Warn "Falling back to: git clone + npm install + commonly-missing modules"
    $FallbackDir = Join-Path $HOME "verified-agent-identity"
    Set-Location $HOME
    if ($UseMode -eq "reuse" -and (Test-Path $FallbackDir)) {
        Ok "Reusing existing folder at $FallbackDir (no fresh clone)."
    } else {
        if (Test-Path $FallbackDir) {
            Warn "Existing folder $FallbackDir will be removed for a fresh install."
            Remove-Item -Recurse -Force $FallbackDir
        }
        git clone https://github.com/BillionsNetwork/verified-agent-identity.git $FallbackDir
    }
    Set-Location $FallbackDir
    if (-not (Test-Path "package.json")) { npm init -y }
    npm install
    npm install shell-quote `@iden3/js-iden3-auth ethers`@6 uuid
    $WorkingDir = $FallbackDir
}

Ok "Working directory: $WorkingDir"
Set-Location $WorkingDir

# ============================================================
#  STEP 3 — agent identity
# ============================================================
Say "Step 3 - agent identity"

switch ($UseMode) {
    "reuse" {
        Ok "Reusing existing identity at $WorkingDir - skipping key creation."
    }
    { $_ -in "env","import" } {
        node scripts/createNewEthereumIdentity.js --key $ExistingKey
        if ($LASTEXITCODE -ne 0) { Die "Failed to import identity." }
        $ExistingKey = $null
        Ok "Imported your existing private key."
    }
    "generate" {
        node scripts/createNewEthereumIdentity.js
        if ($LASTEXITCODE -ne 0) { Die "Failed to generate a new identity." }
        Write-Host ""
        Write-Host "!! IMPORTANT - BACK UP THE PRIVATE KEY PRINTED ABOVE !!" -ForegroundColor Red
        Write-Host "This key IS your agent's Billions identity. If you lose it," -ForegroundColor Red
        Write-Host "you lose the identity (and any FAIAR rewards tied to it)." -ForegroundColor Red
        Write-Host "Save it in a password manager NOW. It will not be shown again." -ForegroundColor Red
        Write-Host ""
        Read-Host "Press ENTER once you have backed up the key" | Out-Null
        Ok "New identity generated."
    }
}

# ============================================================
#  STEP 4 — link to your Billions account (generate mode only)
# ============================================================
if ($UseMode -eq "generate") {
    Say "Step 4 - link this agent to your Billions account"
    $env:AGENT_CHALLENGE = ConvertTo-Json -Compress @{ name = $AgentName; description = $AgentDesc }
    node -e "const cp = require('child_process'); cp.execFileSync('node', ['scripts/manualLinkHumanToAgent.js', '--challenge', process.env.AGENT_CHALLENGE], {stdio: 'inherit'})"
    if ($LASTEXITCODE -ne 0) { Die "Failed to generate the verification link." }
    Write-Host ""
    Warn "Open the URL printed above in your browser and sign in with your Billions account."
    Warn "That handshake is what binds this agent to your Billions account."
    Read-Host "Press ENTER once you've completed the link in your browser" | Out-Null
} else {
    Say "Step 4 - skipped (existing identity is already linked elsewhere)"
}

# ============================================================
#  STEP 5 — register skill with the AI agent of your choice
# ============================================================
Say "Step 5 - register the skill with your AI agent"
Warn "Use Up/Down to scroll, SPACE to select your agent (e.g. Claude Code), ENTER to confirm."
npx --yes skills add BillionsNetwork/verified-agent-identity
if ($LASTEXITCODE -ne 0) { Die "skills add failed." }

Write-Host ""
Ok "Verified Agent Identity skill installed."
Say "You're qualified for the Billions FAIAR reward!"
Write-Host ""
Write-Host "Built with " -NoNewline
Write-Host "♥" -ForegroundColor Red -NoNewline
Write-Host " by " -NoNewline
Write-Host "fashaking (https://x.com/FASHAKING3)" -ForegroundColor Cyan -NoNewline
Write-Host " for the Billions Community"
