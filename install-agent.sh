#!/usr/bin/env bash
# ============================================================
#  Billions FAIAR — Verified Agent Identity installer
#  Multi-platform (Termux / Linux / macOS)
#
#  Usage:
#    curl -sL https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent.sh | bash
#
#  What this does, in order:
#    1. Decide what to do with the agent identity:
#         - reuse one already on disk if found, or
#         - import a private key you paste, or
#         - generate a brand-new one
#       Only the "generate" branch asks for the agent name & description.
#    2. Install Node.js (and Git, in case the clawhub fallback is needed)
#    3. Try `npx clawhub@latest install verified-agent-identity` first
#       and fall back to `git clone BillionsNetwork/verified-agent-identity`
#       + npm install + commonly-missing modules if clawhub fails.
#    4. Run scripts/createNewEthereumIdentity.js  (skipped if reusing)
#    5. Run scripts/manualLinkHumanToAgent.js    (only in "generate" mode)
#    6. Run `npx skills add BillionsNetwork/verified-agent-identity`
#       so you can register the skill with Claude Code / Cursor / etc.
# ============================================================

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

say()  { printf "${CYAN}==>${NC} ${BOLD}%s${NC}\n" "$1"; }
ok()   { printf "${GREEN}✔${NC}  %s\n" "$1"; }
warn() { printf "${YELLOW}!${NC}  %s\n" "$1"; }
die()  { printf "${RED}✘${NC}  %s\n" "$1" >&2; exit 1; }

# A TTY for interactive prompts when running under `curl | bash`.
if [ -t 0 ]; then
    TTY=/dev/stdin
elif [ -e /dev/tty ]; then
    TTY=/dev/tty
else
    TTY=""
fi

ask() {
    # ask "Prompt" "default"
    local prompt="$1" default="${2:-}" reply
    if [ -z "$TTY" ]; then printf '%s' "$default"; return; fi
    if [ -n "$default" ]; then
        printf "${BOLD}? %s${NC} [${default}] " "$prompt" >&2
    else
        printf "${BOLD}? %s${NC} " "$prompt" >&2
    fi
    IFS= read -r reply <"$TTY" || reply=""
    printf '%s' "${reply:-$default}"
}

ask_secret() {
    local prompt="$1" reply
    [ -z "$TTY" ] && die "Need an interactive terminal to read a private key."
    printf "${BOLD}? %s${NC} " "$prompt" >&2
    stty -echo <"$TTY" 2>/dev/null || true
    IFS= read -r reply <"$TTY" || reply=""
    stty echo <"$TTY" 2>/dev/null || true
    printf '\n' >&2
    printf '%s' "$reply"
}

# --- platform detect ---------------------------------------------------------
PLATFORM="unknown"
case "$(uname -s)" in
    Linux*)
        if [ -n "${PREFIX:-}" ] && echo "$PREFIX" | grep -q "com.termux"; then
            PLATFORM="termux"
        else
            PLATFORM="linux"
        fi
        ;;
    Darwin*) PLATFORM="macos" ;;
    *)       PLATFORM="$(uname -s)" ;;
esac

say "Billions FAIAR — Verified Agent Identity installer"
echo "    Platform detected: ${BOLD}${PLATFORM}${NC}"
echo

# ============================================================
#  STEP 0 — decide identity intent BEFORE installing anything
# ============================================================

# Locations that may already hold an identity from a prior install.
SKILL_PATHS=(
    "$HOME/verified-agent-identity"
    "$HOME/.claude/skills/verified-agent-identity"
    "$HOME/.cursor/skills/verified-agent-identity"
    "$HOME/.cline/skills/verified-agent-identity"
    "$HOME/.continue/skills/verified-agent-identity"
    "$HOME/.config/clawhub/skills/verified-agent-identity"
    "$HOME/.clawhub/skills/verified-agent-identity"
)
ID_FILES=( ".identity" "identity.json" ".env" "agent.json" )

EXISTING_KEY=""
USE_MODE=""
EXISTING_DIR=""

# 1) Env var beats everything.
if [ -n "${BILLIONS_PRIVATE_KEY:-}" ]; then
    EXISTING_KEY="$BILLIONS_PRIVATE_KEY"
    USE_MODE="env"
    ok "Detected BILLIONS_PRIVATE_KEY environment variable — will import it."
fi

# 2) Look for a folder on disk with identity files.
if [ -z "$USE_MODE" ]; then
    for d in "${SKILL_PATHS[@]}"; do
        [ -d "$d" ] || continue
        for f in "${ID_FILES[@]}"; do
            if [ -f "$d/$f" ]; then
                EXISTING_DIR="$d"
                break 2
            fi
        done
    done
    if [ -n "$EXISTING_DIR" ]; then
        echo
        ok "Existing Billions identity found on this machine:"
        echo "      $EXISTING_DIR"
        REUSE=$(ask "Reuse it?" "Y")
        case "$(echo "$REUSE" | tr '[:upper:]' '[:lower:]')" in
            ""|y|yes) USE_MODE="reuse" ;;
        esac
    fi
fi

# 3) Otherwise ask import vs generate.
if [ -z "$USE_MODE" ]; then
    echo
    echo "    No existing Billions identity is being reused. Pick one:"
    echo "      [1] I already have a private key — let me paste it (input hidden)"
    echo "      [2] Generate a brand-new identity for me"
    echo
    CHOICE=$(ask "Enter 1 or 2" "2")
    case "$(echo "$CHOICE" | tr '[:upper:]' '[:lower:]')" in
        1|import|existing|y|yes)
            EXISTING_KEY=$(ask_secret "Paste your Ethereum private key (0x...)")
            [ -z "$EXISTING_KEY" ] && die "Empty key. Aborting."
            USE_MODE="import"
            ;;
        *)
            USE_MODE="generate"
            ;;
    esac
fi

# 4) Only ask for agent name & description in "generate" mode.
AGENT_NAME=""
AGENT_DESC=""
if [ "$USE_MODE" = "generate" ]; then
    # Without a TTY, ask returns the empty default forever and the
    # validation loop spins. Bail out with a clear message instead.
    [ -z "$TTY" ] && die "generate mode needs an interactive terminal for the agent name & description. Re-run from a terminal, or set BILLIONS_PRIVATE_KEY to import an existing key."
    echo
    AGENT_NAME=$(ask "Agent name (e.g. MyAgent)" "")
    while [ -z "$AGENT_NAME" ]; do
        warn "Agent name cannot be empty."
        AGENT_NAME=$(ask "Agent name" "")
    done
    AGENT_DESC=$(ask "Agent description (e.g. AI trading agent)" "")
    while [ -z "$AGENT_DESC" ]; do
        warn "Agent description cannot be empty."
        AGENT_DESC=$(ask "Agent description" "")
    done
fi

echo
echo "    Identity mode : ${BOLD}${USE_MODE}${NC}"
[ -n "$AGENT_NAME" ] && echo "    Agent name    : ${AGENT_NAME}"
[ -n "$AGENT_DESC" ] && echo "    Description   : ${AGENT_DESC}"
echo

# ============================================================
#  STEP 1 — install Node.js (and Git for the clawhub fallback)
# ============================================================
say "Step 1 — installing Node.js & Git if missing"

need_node=0; need_git=0
command -v node >/dev/null 2>&1 || need_node=1
command -v npx  >/dev/null 2>&1 || need_node=1
command -v git  >/dev/null 2>&1 || need_git=1

if [ $need_node -eq 1 ] || [ $need_git -eq 1 ]; then
    case "$PLATFORM" in
        termux)
            yes | pkg update -y 2>&1
            [ $need_node -eq 1 ] && yes | pkg install -y nodejs
            [ $need_git  -eq 1 ] && yes | pkg install -y git
            ;;
        macos)
            if ! command -v brew >/dev/null 2>&1; then
                die "Homebrew not found. Install it from https://brew.sh and re-run."
            fi
            [ $need_node -eq 1 ] && brew install node
            [ $need_git  -eq 1 ] && brew install git
            ;;
        linux)
            if   command -v apt-get >/dev/null 2>&1; then
                sudo apt-get update -y
                [ $need_node -eq 1 ] && sudo apt-get install -y nodejs npm
                [ $need_git  -eq 1 ] && sudo apt-get install -y git
            elif command -v dnf >/dev/null 2>&1; then
                [ $need_node -eq 1 ] && sudo dnf install -y nodejs npm
                [ $need_git  -eq 1 ] && sudo dnf install -y git
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -Sy --noconfirm
                [ $need_node -eq 1 ] && sudo pacman -S --noconfirm nodejs npm
                [ $need_git  -eq 1 ] && sudo pacman -S --noconfirm git
            elif command -v apk >/dev/null 2>&1; then
                [ $need_node -eq 1 ] && sudo apk add --no-cache nodejs npm
                [ $need_git  -eq 1 ] && sudo apk add --no-cache git
            else
                die "No supported package manager. Install Node.js + Git manually."
            fi
            ;;
        *) die "Unsupported platform. Install Node.js + Git manually." ;;
    esac
fi
ok "Node $(node -v) — npx $(npx -v)"
command -v git >/dev/null 2>&1 && ok "$(git --version)"

# ============================================================
#  STEP 2 — install skill files (clawhub first, git clone fallback)
# ============================================================
say "Step 2 — installing skill files (clawhub first, git clone fallback)"

WORKING_DIR=""
CLAWHUB_OK=0

if yes | npx --yes clawhub@latest install verified-agent-identity 2>&1; then
    ok "clawhub install succeeded."
    CLAWHUB_OK=1
    # Try to find where clawhub put the skill.
    for d in "${SKILL_PATHS[@]}"; do
        if [ -d "$d" ] && [ -f "$d/scripts/createNewEthereumIdentity.js" ]; then
            WORKING_DIR="$d"
            break
        fi
    done
    if [ -z "$WORKING_DIR" ]; then
        FOUND=$(find "$HOME" -maxdepth 6 -type d -name "verified-agent-identity" 2>/dev/null \
                | while read -r p; do
                    [ -f "$p/scripts/createNewEthereumIdentity.js" ] && echo "$p"
                done | head -n 1)
        [ -n "$FOUND" ] && WORKING_DIR="$FOUND"
    fi
    [ -z "$WORKING_DIR" ] && warn "clawhub installed but no scripts/ folder was located — falling back to git clone."
fi

if [ -z "$WORKING_DIR" ]; then
    warn "Falling back to: git clone + npm install + commonly-missing modules"
    # In reuse mode, target the directory we actually detected the
    # identity in (e.g. ~/.claude/skills/verified-agent-identity) so
    # the rest of the flow runs against the folder the user approved.
    if [ "$USE_MODE" = "reuse" ] && [ -n "$EXISTING_DIR" ]; then
        FALLBACK_DIR="$EXISTING_DIR"
    else
        FALLBACK_DIR="$HOME/verified-agent-identity"
    fi
    cd "$HOME"
    if [ "$USE_MODE" = "reuse" ] && [ -d "$FALLBACK_DIR" ]; then
        ok "Reusing existing folder at $FALLBACK_DIR (no fresh clone)."
    else
        if [ -d "$FALLBACK_DIR" ]; then
            warn "Existing folder $FALLBACK_DIR will be removed for a fresh install."
            rm -rf "$FALLBACK_DIR"
        fi
        git clone https://github.com/BillionsNetwork/verified-agent-identity.git "$FALLBACK_DIR"
    fi
    WORKING_DIR="$FALLBACK_DIR"
fi

ok "Working directory: $WORKING_DIR"
cd "$WORKING_DIR"

# Install Node dependencies inside the skill folder regardless of how it
# got there (clawhub does NOT run `npm install`, so the SDK modules
# required by scripts/createNewEthereumIdentity.js would otherwise be
# missing — e.g. `Cannot find module '@0xpolygonid/js-sdk'`).
say "Installing skill Node dependencies"
if [ ! -f "package.json" ]; then npm init -y; fi
npm install
npm install \
    @0xpolygonid/js-sdk \
    @iden3/js-iden3-auth \
    shell-quote \
    ethers@6 \
    uuid

# ============================================================
#  STEP 3 — set up the agent's Ethereum identity
# ============================================================
say "Step 3 — agent identity"

case "$USE_MODE" in
    reuse)
        ok "Reusing existing identity at $WORKING_DIR — skipping key creation."
        ;;
    env|import)
        node scripts/createNewEthereumIdentity.js --key "$EXISTING_KEY" \
            || die "Failed to import identity."
        unset EXISTING_KEY
        ok "Imported your existing private key."
        ;;
    generate)
        node scripts/createNewEthereumIdentity.js \
            || die "Failed to generate a new identity."
        echo
        # Upstream createNewEthereumIdentity.js sometimes only prints the
        # DID and silently writes the key to disk, so the "key printed
        # above" guidance is empty. Recursively scan WORKING_DIR for any
        # file containing a 0x-prefixed 64-hex string and surface it.
        PRINTED_KEY=""
        PRINTED_FILE=""
        # Search common identity files first (fast path), then fall
        # back to a recursive grep if those don't match.
        for f in .identity identity.json .env agent.json identity wallet.json keystore.json .agent .agent.json; do
            [ -f "$WORKING_DIR/$f" ] || continue
            k=$(grep -oE '0x[a-fA-F0-9]{64}' "$WORKING_DIR/$f" 2>/dev/null | head -n 1 || true)
            if [ -n "$k" ]; then
                PRINTED_KEY="$k"
                PRINTED_FILE="$WORKING_DIR/$f"
                break
            fi
        done
        if [ -z "$PRINTED_KEY" ]; then
            HIT=$(grep -rElI --exclude-dir=node_modules --exclude-dir=.git \
                    '0x[a-fA-F0-9]{64}' "$WORKING_DIR" 2>/dev/null | head -n 1 || true)
            if [ -n "$HIT" ]; then
                k=$(grep -oE '0x[a-fA-F0-9]{64}' "$HIT" 2>/dev/null | head -n 1 || true)
                if [ -n "$k" ]; then
                    PRINTED_KEY="$k"
                    PRINTED_FILE="$HIT"
                fi
            fi
        fi
        if [ -n "$PRINTED_KEY" ]; then
            printf "${BOLD}    Identity file : ${NC}%s\n" "$PRINTED_FILE"
            printf "${BOLD}    Private key   : ${RED}%s${NC}\n" "$PRINTED_KEY"
            echo
        else
            warn "Could not auto-detect the private key under $WORKING_DIR."
            warn "List the directory and look for a file containing a 0x... 64-hex string:"
            warn "    ls -la \"$WORKING_DIR\""
            warn "    grep -rEl '0x[a-fA-F0-9]{64}' \"$WORKING_DIR\" --exclude-dir=node_modules"
        fi
        printf "${RED}${BOLD}!! IMPORTANT — back up the private key shown above !!${NC}\n"
        printf "${RED}This key IS your agent's Billions identity. If you lose it,\n"
        printf "you lose the identity (and any FAIAR rewards tied to it).\n"
        printf "Save it in a password manager NOW. It will not be shown again.${NC}\n"
        echo
        _=$(ask "Press ENTER once you have backed up the key" "")
        ok "New identity generated."
        ;;
esac

# ============================================================
#  STEP 4 — link the agent to your Billions account
#  (only in "generate" mode — reuse/import are already linked)
# ============================================================
if [ "$USE_MODE" = "generate" ]; then
    say "Step 4 — link this agent to your Billions account"
    esc_name=$(printf '%s' "$AGENT_NAME" | sed 's/"/\\"/g')
    esc_desc=$(printf '%s' "$AGENT_DESC" | sed 's/"/\\"/g')
    CHALLENGE="{\"name\":\"${esc_name}\",\"description\":\"${esc_desc}\"}"
    node scripts/manualLinkHumanToAgent.js --challenge "$CHALLENGE" \
        || die "Failed to generate the verification link."
    echo
    warn "Open the URL printed above in your browser and sign in with your Billions account."
    warn "That handshake is what binds this agent to your Billions account."
    _=$(ask "Press ENTER once you've completed the link in your browser" "")
else
    say "Step 4 — skipped (existing identity is already linked elsewhere)"
fi

# ============================================================
#  STEP 5 — register skill with the AI agent of your choice
# ============================================================
say "Step 5 — register the skill with your AI agent"
warn "Use ↑/↓ to scroll, SPACE to select your agent (e.g. Claude Code), ENTER to confirm."
if [ -n "$TTY" ] && [ "$TTY" != "/dev/stdin" ]; then
    npx --yes skills add BillionsNetwork/verified-agent-identity <"$TTY"
else
    npx --yes skills add BillionsNetwork/verified-agent-identity
fi

echo
ok "Verified Agent Identity skill installed."
say "You're qualified for the Billions FAIAR reward 🎉"
echo
printf "Built with ❤️ by \033]8;;https://x.com/FASHAKING3\033\\fashaking\033]8;;\033\\ for the Billions Community\n"
