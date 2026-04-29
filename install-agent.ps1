# Billions FAIAR — Verified Agent Identity installer (Windows PowerShell)
#
# What this does, in order:
#   1) Make sure Node.js + npx exist
#   2) Install the verified-agent-identity skill files (clawhub)
#   3) Set up the Billions identity:
#        - reuse one already on the machine if found
#        - else import a private key you paste, or generate a fresh one
#   4) Generate a verification link so you can connect this agent
#      to your Billions account in the browser
#   5) Register the skill with your AI agent (Claude Code, Cursor, ...)
#
# Usage:
#   irm https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent.ps1 | iex

$ErrorActionPreference = "Stop"

function Say($msg)  { Write-Host "==> " -ForegroundColor Cyan -NoNewline;   Write-Host $msg -ForegroundColor White }
function Ok($msg)   { Write-Host "OK  " -ForegroundColor Green -NoNewline;  Write-Host $msg }
function Warn($msg) { Write-Host "!   " -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Die($msg)  { Write-Host "X   " -ForegroundColor Red -NoNewline;    Write-Host $msg; exit 1 }

function Ask($prompt, $default) {
    if ($default) { $p = "? $prompt [$default]" } else { $p = "? $prompt" }
    $reply = Read-Host $p
    if ([string]::IsNullOrWhiteSpace($reply)) { return $default }
    return $reply
}

function AskSecret($prompt) {
    $sec = Read-Host -AsSecureString "? $prompt"
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
    finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

Say "Billions FAIAR — Verified Agent Identity installer"
Write-Host "    Platform detected: Windows PowerShell"
Write-Host ""

# --- Node.js -----------------------------------------------------------------
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
Ok "Node $(node -v) - npx $(npx -v)"
Write-Host ""

# --- Step 1: install skill files --------------------------------------------
Say "Step 1/4 - installing verified-agent-identity skill files"
npx --yes clawhub@latest install verified-agent-identity
if ($LASTEXITCODE -ne 0) { Die "clawhub install failed. Aborting before identity setup." }

# --- Step 2: locate skill directory -----------------------------------------
Say "Step 2/4 - locating the skill directory"
$candidates = @(
    "$HOME\.claude\skills\verified-agent-identity",
    "$HOME\.cursor\skills\verified-agent-identity",
    "$HOME\.cline\skills\verified-agent-identity",
    "$HOME\.continue\skills\verified-agent-identity",
    "$HOME\.config\clawhub\skills\verified-agent-identity",
    "$HOME\.clawhub\skills\verified-agent-identity"
)
$skillDir = $null
foreach ($c in $candidates) {
    if (Test-Path $c) { $skillDir = $c; break }
}
if (-not $skillDir) {
    Warn "Could not auto-detect skill directory; searching `$HOME..."
    $found = Get-ChildItem -Path $HOME -Recurse -Directory -Filter "verified-agent-identity" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $skillDir = $found.FullName }
}
if (-not $skillDir) { Die "Skill directory not found. Cannot continue." }
Ok "Skill directory: $skillDir"

# --- Step 3: identity --------------------------------------------------------
Write-Host ""
Say "Step 3/4 - Billions identity"

$existingId = $null
$idCandidates = @(
    "$skillDir\.identity",
    "$skillDir\identity.json",
    "$skillDir\.billions\identity.json",
    "$HOME\.billions\identity.json",
    "$HOME\.billions\identity",
    "$HOME\.config\billions\identity.json"
)
foreach ($p in $idCandidates) {
    if (Test-Path $p) { $existingId = $p; break }
}

Push-Location $skillDir
try {
    if ($env:BILLIONS_PRIVATE_KEY) {
        Ok "Found a Billions private key in BILLIONS_PRIVATE_KEY env var. Importing it."
        node scripts/createNewEthereumIdentity.js --key $env:BILLIONS_PRIVATE_KEY
        if ($LASTEXITCODE -ne 0) { Die "Failed to import identity from BILLIONS_PRIVATE_KEY." }
    }
    elseif ($existingId) {
        Ok "Existing Billions identity detected on this machine:"
        Write-Host "    $existingId"
        Warn "Reusing it - skipping key creation."
    }
    else {
        Write-Host ""
        Write-Host "    No existing Billions identity was found on this machine."
        Write-Host "    Pick one of:"
        Write-Host "      [1] I have a private key - let me paste it (input will be hidden)"
        Write-Host "      [2] Generate a brand-new identity for me"
        Write-Host ""
        $choice = Ask "Enter 1 or 2" "2"
        switch -Regex ($choice.ToLower()) {
            '^(1|import|existing|y|yes)$' {
                $key = AskSecret "Paste your Ethereum private key (0x...)"
                if (-not $key) { Die "Empty key. Aborting." }
                node scripts/createNewEthereumIdentity.js --key $key
                if ($LASTEXITCODE -ne 0) { Die "Failed to import identity." }
                Ok "Imported your existing Billions identity."
            }
            default {
                Warn "Generating a brand-new Ethereum identity..."
                node scripts/createNewEthereumIdentity.js
                if ($LASTEXITCODE -ne 0) { Die "Failed to generate a new identity." }
                Write-Host ""
                Write-Host "!! IMPORTANT - BACK UP THE PRIVATE KEY PRINTED ABOVE !!" -ForegroundColor Red
                Write-Host "This key IS your agent's Billions identity. If you lose it, you" -ForegroundColor Red
                Write-Host "lose the identity (and any FAIAR rewards tied to it)." -ForegroundColor Red
                Write-Host "Save it in a password manager NOW. It will not be shown again." -ForegroundColor Red
                Write-Host ""
                Read-Host "Press ENTER once you have backed up the key" | Out-Null
            }
        }
    }

    # --- Step 4: link to Billions account -----------------------------------
    Write-Host ""
    Say "Step 4/4 - link this agent to your Billions account"
    $agentName = Ask "Agent name" "My Verified Agent"
    $agentDesc = Ask "Short description" "AI agent verified via Billions FAIAR"
    $challenge = (@{ name = $agentName; description = $agentDesc } | ConvertTo-Json -Compress)

    Write-Host ""
    Say "Generating the verification link..."
    node scripts/manualLinkHumanToAgent.js --challenge $challenge
    if ($LASTEXITCODE -ne 0) { Die "Failed to generate the verification link." }

    Write-Host ""
    Warn "Open the link printed above in your browser and sign in with your Billions account."
    Warn "That is what tells Billions which account this agent belongs to."
    Read-Host "Press ENTER once you've completed the link in your browser" | Out-Null
}
finally {
    Pop-Location
}

# --- Register skill with the AI agent ---------------------------------------
Write-Host ""
Say "Registering the skill with your AI agent (pick one when prompted)"
Warn "Use Up/Down to scroll, SPACE to select your agent (e.g. Claude Code), ENTER to confirm."
npx --yes skills add BillionsNetwork/verified-agent-identity
if ($LASTEXITCODE -ne 0) { Die "skills add failed." }

Write-Host ""
Ok "Verified Agent Identity skill installed and linked to your Billions account."
Say "You're qualified for the Billions FAIAR reward!"
Write-Host ""
Write-Host "Built with " -NoNewline
Write-Host "♥" -ForegroundColor Red -NoNewline
Write-Host " by " -NoNewline
Write-Host "fashaking (https://x.com/FASHAKING3)" -ForegroundColor Cyan -NoNewline
Write-Host " for the Billions Community"
