#!/usr/bin/env bash

# ============================================================
#  Verified Agent Identity — Installer for macOS
#  GitHub: https://github.com/FASHAKING/Billions-ai-agent-skill-reward-
#
#  Usage:
#    curl -sL https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent-macos.sh | bash
#
#  Supported environments:
#    - macOS (Apple Silicon & Intel)
#
#  What this script does:
#    1. Installs Homebrew, Node.js, and Git if not already present
#    2. Detects an existing Billions identity (or asks you to import / create one)
#    3. Clones the verified-agent-identity repo
#    4. Installs all dependencies (including the commonly missing ones)
#    5. Creates / imports your Agent Ethereum Identity
#    6. Generates a verification URL so you can link this agent to your
#       Billions account in the browser
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                          ║${NC}"
    echo -e "${CYAN}║   ${BOLD}Verified Agent Identity — macOS Installer${NC}${CYAN}              ║${NC}"
    echo -e "${CYAN}║   ${NC}by BillionsNetwork${CYAN}                                     ║${NC}"
    echo -e "${CYAN}║                                                          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step()    { echo ""; echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${GREEN}  STEP $1: $2${NC}"; echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo ""; }
print_success() { echo -e "${GREEN}  [OK] $1${NC}"; }
print_warning() { echo -e "${YELLOW}  [!]  $1${NC}"; }
print_error()   { echo -e "${RED}  [X]  $1${NC}"; }
print_info()    { echo -e "${CYAN}  [i]  $1${NC}"; }

read_secret() {
    local __var="$1" prompt="$2" reply
    printf "  %s: " "$prompt" > /dev/tty
    stty -echo < /dev/tty
    IFS= read -r reply < /dev/tty
    stty echo < /dev/tty
    echo "" > /dev/tty
    eval "$__var=\$reply"
}

print_banner

if [ "$(uname)" != "Darwin" ]; then
    print_error "This script is for macOS only."
    print_info "For Linux/WSL, use: install-agent-codespaces.sh"
    print_info "For Termux,    use: install-agent.sh"
    exit 1
fi
print_info "Detected: macOS $(sw_vers -productVersion 2>/dev/null || echo '')"

INSTALL_DIR="$HOME/verified-agent-identity"

# --- Identity intent ---
EXISTING_KEY=""
USE_MODE=""

if [ -n "${BILLIONS_PRIVATE_KEY:-}" ]; then
    EXISTING_KEY="$BILLIONS_PRIVATE_KEY"
    USE_MODE="env"
    print_info "Detected BILLIONS_PRIVATE_KEY environment variable — will import it."
fi

if [ -z "$USE_MODE" ] && [ -d "$INSTALL_DIR" ]; then
    HAS_LOCAL_ID=""
    for f in "$INSTALL_DIR/.identity" \
             "$INSTALL_DIR/identity.json" \
             "$INSTALL_DIR/.env" \
             "$INSTALL_DIR/agent.json"; do
        [ -f "$f" ] && HAS_LOCAL_ID="$f" && break
    done
    if [ -n "$HAS_LOCAL_ID" ]; then
        echo -e "${BOLD}Existing Billions identity found on this Mac:${NC}"
        echo "    $HAS_LOCAL_ID"
        echo ""
        read -p "  Reuse it? [Y/n]: " REUSE < /dev/tty
        if [ -z "$REUSE" ] || [ "$REUSE" = "y" ] || [ "$REUSE" = "Y" ]; then
            USE_MODE="reuse"
        fi
    fi
fi

if [ -z "$USE_MODE" ]; then
    echo -e "${BOLD}No existing Billions identity is being reused. Pick one:${NC}"
    echo "    [1] I already have a private key — let me paste it (input hidden)"
    echo "    [2] Generate a brand-new identity for me"
    echo ""
    read -p "  Enter 1 or 2 [2]: " ID_CHOICE < /dev/tty
    case "${ID_CHOICE:-2}" in
        1)
            read_secret EXISTING_KEY "Paste your Ethereum private key (0x...)"
            [ -z "$EXISTING_KEY" ] && { print_error "Empty key. Aborting."; exit 1; }
            USE_MODE="import"
            ;;
        *)
            USE_MODE="generate"
            ;;
    esac
fi

# --- Agent name & description ---
echo ""
echo -e "${BOLD}Agent details:${NC}"
echo ""

read -p "  Enter your Agent Name (e.g., MyAgent): " AGENT_NAME < /dev/tty
while [ -z "$AGENT_NAME" ]; do
    print_warning "Agent name cannot be empty."
    read -p "  Enter your Agent Name: " AGENT_NAME < /dev/tty
done

read -p "  Enter your Agent Description (e.g., AI trading agent): " AGENT_DESC < /dev/tty
while [ -z "$AGENT_DESC" ]; do
    print_warning "Agent description cannot be empty."
    read -p "  Enter your Agent Description: " AGENT_DESC < /dev/tty
done

echo ""
print_info "Agent Name: ${AGENT_NAME}"
print_info "Agent Description: ${AGENT_DESC}"
print_info "Identity mode: ${USE_MODE}"
echo ""
read -p "  Proceed with installation? (y/n): " CONFIRM < /dev/tty
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    print_warning "Installation cancelled by user."
    exit 0
fi

# ============================================================
#  STEP 1: Install Homebrew, Node.js, Git
# ============================================================
print_step "1/5" "Checking and installing Homebrew, Node.js, and Git"

if command -v brew &>/dev/null; then
    print_success "Homebrew already installed: $(brew --version | head -1)"
else
    print_info "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/tty
    if   [ -f "/opt/homebrew/bin/brew" ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f "/usr/local/bin/brew"   ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
    command -v brew &>/dev/null || { print_error "Homebrew install failed. https://brew.sh"; exit 1; }
    print_success "Homebrew installed."
fi

if command -v node &>/dev/null; then
    print_success "Node.js already installed: $(node -v)"
else
    print_info "Node.js not found. Installing via Homebrew..."
    brew install node
    command -v node &>/dev/null || { print_error "Node.js install failed."; exit 1; }
    print_success "Node.js installed: $(node -v)"
fi

if command -v git &>/dev/null; then
    print_success "Git already installed: $(git --version)"
else
    print_info "Git not found. Installing via Homebrew..."
    brew install git
    print_success "Git installed: $(git --version)"
fi

print_success "Node.js version: $(node -v)"
print_success "npm version: $(npm -v)"
print_success "Git version: $(git --version)"

# ============================================================
#  STEP 2: Clone (or reuse) the repo
# ============================================================
print_step "2/5" "Preparing verified-agent-identity repository"

cd "$HOME"
if [ "$USE_MODE" = "reuse" ]; then
    print_info "Reusing existing folder at: $INSTALL_DIR"
    cd "$INSTALL_DIR"
else
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Existing folder found. Removing for a fresh install..."
        rm -rf "$INSTALL_DIR"
    fi
    git clone https://github.com/BillionsNetwork/verified-agent-identity.git
    cd verified-agent-identity
    print_success "Repository cloned successfully."
fi
print_info "Working directory: $(pwd)"

# ============================================================
#  STEP 3: Install dependencies
# ============================================================
print_step "3/5" "Installing project dependencies"

if npx --yes clawhub@latest install verified-agent-identity 2>&1; then
    print_success "clawhub dependencies installed."
else
    print_warning "clawhub failed — falling back to npm install..."
    npm install 2>&1
    print_success "npm dependencies installed."
fi

print_info "Installing commonly required modules to prevent errors..."
npm install shell-quote 2>&1            && print_success "Installed: shell-quote"
npm install @iden3/js-iden3-auth 2>&1   && print_success "Installed: @iden3/js-iden3-auth"
npm install ethers@6 2>&1               && print_success "Installed: ethers v6"
npm install uuid 2>&1                   && print_success "Installed: uuid"
print_success "All dependencies installed."

# ============================================================
#  STEP 4: Identity
# ============================================================
print_step "4/5" "Setting up your Agent Ethereum Identity"

case "$USE_MODE" in
    reuse)
        print_info "Skipping identity creation — reusing existing key."
        ;;
    env|import)
        print_info "Importing your existing private key..."
        node scripts/createNewEthereumIdentity.js --key "$EXISTING_KEY"
        unset EXISTING_KEY
        print_success "Identity imported."
        ;;
    generate)
        node scripts/createNewEthereumIdentity.js
        echo ""
        echo -e "${RED}${BOLD}!! IMPORTANT — back up the private key printed above !!${NC}"
        echo -e "${RED}This key IS your agent's Billions identity. If you lose it,${NC}"
        echo -e "${RED}you lose the identity (and any FAIAR rewards tied to it).${NC}"
        echo -e "${RED}Save it in a password manager NOW. It will not be shown again.${NC}"
        echo ""
        read -p "  Press ENTER once you have backed up the key... " _ < /dev/tty
        print_success "New identity generated."
        ;;
esac

# ============================================================
#  STEP 5: Link to Billions account
# ============================================================
print_step "5/5" "Generating Billions account verification link"

echo ""
print_info "Using Agent Name: ${AGENT_NAME}"
print_info "Using Agent Description: ${AGENT_DESC}"
echo ""

node scripts/manualLinkHumanToAgent.js --challenge "{\"name\":\"${AGENT_NAME}\",\"description\":\"${AGENT_DESC}\"}"

# ============================================================
#  DONE
# ============================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║    Installation Complete!                                ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║${NC}   ${BOLD}NEXT STEPS:${NC}${GREEN}                                              ║${NC}"
echo -e "${GREEN}║${NC}   1. Copy the verification URL printed above${GREEN}            ║${NC}"
echo -e "${GREEN}║${NC}   2. Open it in your browser${GREEN}                              ║${NC}"
echo -e "${GREEN}║${NC}   3. Sign in with your Billions account / connect wallet${GREEN} ║${NC}"
echo -e "${GREEN}║${NC}   4. Verify — and you're done!${GREEN}                            ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
