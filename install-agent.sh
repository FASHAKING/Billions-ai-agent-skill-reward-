#!/usr/bin/env bash
# Billions FAIAR — Verified Agent Identity installer
# Usage:
#   curl -sL https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent.sh | bash

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

# Detect platform
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

# Ensure Node.js + npx
if ! command -v node >/dev/null 2>&1 || ! command -v npx >/dev/null 2>&1; then
  warn "Node.js / npx not found. Attempting to install..."
  case "$PLATFORM" in
    termux)
      pkg update -y && pkg install -y nodejs
      ;;
    macos)
      if command -v brew >/dev/null 2>&1; then
        brew install node
      else
        die "Homebrew not found. Install Node.js from https://nodejs.org/ then re-run."
      fi
      ;;
    linux)
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -y && sudo apt-get install -y nodejs npm
      elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y nodejs npm
      elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm nodejs npm
      else
        die "No supported package manager found. Install Node.js from https://nodejs.org/ then re-run."
      fi
      ;;
    *)
      die "Unsupported platform. Install Node.js manually from https://nodejs.org/ then re-run."
      ;;
  esac
fi

ok "Node $(node -v) — npx $(npx -v)"
echo

# Step 1 — auto-confirm the y/n prompt
say "Step 1/2 — installing clawhub verified-agent-identity"
if ! yes | npx --yes clawhub@latest install verified-agent-identity; then
  die "Step 1 failed (clawhub install). Aborting before Step 2 to avoid a partial install."
fi

echo
# Step 2 — interactive agent picker (this is the only step that needs you)
say "Step 2/2 — adding BillionsNetwork/verified-agent-identity skill"
warn "When prompted, use ↑/↓ to scroll, SPACE to select your agent (e.g. Claude Code), ENTER to confirm."
# Re-attach stdin to the terminal so the picker works under 'curl | bash'
if [ -t 0 ]; then
  npx --yes skills add BillionsNetwork/verified-agent-identity
elif [ -e /dev/tty ]; then
  npx --yes skills add BillionsNetwork/verified-agent-identity </dev/tty
else
  warn "No interactive TTY available; running non-interactively."
  npx --yes skills add BillionsNetwork/verified-agent-identity
fi

echo
ok "Verified Agent Identity skill installed."
say "You're qualified for the Billions FAIAR reward 🎉"
echo
printf "Built with ❤️ by \033]8;;https://x.com/FASHAKING3\033\\fashaking\033]8;;\033\\ for the Billions Community\n"
