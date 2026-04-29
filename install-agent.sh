#!/usr/bin/env bash
# Billions FAIAR — Verified Agent Identity installer
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

# Pick a TTY for prompts when running under `curl | bash`.
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
  if [ -z "$TTY" ]; then
    printf '%s' "$default"
    return
  fi
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

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

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

# --- Node.js -----------------------------------------------------------------
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

# --- Step 1: install skill files --------------------------------------------
say "Step 1/4 — installing verified-agent-identity skill files"
if ! yes | npx --yes clawhub@latest install verified-agent-identity; then
  die "clawhub install failed. Aborting before identity setup."
fi

# --- Step 2: locate skill directory -----------------------------------------
say "Step 2/4 — locating the skill directory"
SKILL_DIR=""
for c in \
  "$HOME/.claude/skills/verified-agent-identity" \
  "$HOME/.cursor/skills/verified-agent-identity" \
  "$HOME/.cline/skills/verified-agent-identity" \
  "$HOME/.continue/skills/verified-agent-identity" \
  "$HOME/.config/clawhub/skills/verified-agent-identity" \
  "$HOME/.clawhub/skills/verified-agent-identity"; do
  [ -d "$c" ] && SKILL_DIR="$c" && break
done
if [ -z "$SKILL_DIR" ]; then
  warn "Could not auto-detect skill directory; searching \$HOME..."
  SKILL_DIR=$(find "$HOME" -maxdepth 6 -type d -name "verified-agent-identity" 2>/dev/null | head -n 1 || true)
fi
[ -z "$SKILL_DIR" ] && die "Skill directory not found. Cannot continue."
ok "Skill directory: $SKILL_DIR"

run_in_skill() { ( cd "$SKILL_DIR" && "$@" ); }

# --- Step 3: identity --------------------------------------------------------
echo
say "Step 3/4 — Billions identity"

EXISTING_ID=""
for p in \
  "$SKILL_DIR/.identity" \
  "$SKILL_DIR/identity.json" \
  "$SKILL_DIR/.billions/identity.json" \
  "$HOME/.billions/identity.json" \
  "$HOME/.billions/identity" \
  "$HOME/.config/billions/identity.json"; do
  if [ -f "$p" ]; then EXISTING_ID="$p"; break; fi
done

if [ -n "${BILLIONS_PRIVATE_KEY:-}" ]; then
  ok "Found a Billions private key in BILLIONS_PRIVATE_KEY env var. Importing it."
  run_in_skill node scripts/createNewEthereumIdentity.js --key "$BILLIONS_PRIVATE_KEY" \
    || die "Failed to import identity from BILLIONS_PRIVATE_KEY."
elif [ -n "$EXISTING_ID" ]; then
  ok "Existing Billions identity detected on this machine:"
  echo "    $EXISTING_ID"
  warn "Reusing it — skipping key creation."
else
  echo
  echo "    No existing Billions identity was found on this machine."
  echo "    Pick one of:"
  echo "      [1] I have a private key — let me paste it (input will be hidden)"
  echo "      [2] Generate a brand-new identity for me"
  echo
  CHOICE=$(ask "Enter 1 or 2" "2")
  case "$(lower "$CHOICE")" in
    1|import|existing|y|yes)
      KEY=$(ask_secret "Paste your Ethereum private key (0x...)")
      [ -z "$KEY" ] && die "Empty key. Aborting."
      run_in_skill node scripts/createNewEthereumIdentity.js --key "$KEY" \
        || die "Failed to import identity."
      ok "Imported your existing Billions identity."
      ;;
    *)
      warn "Generating a brand-new Ethereum identity..."
      run_in_skill node scripts/createNewEthereumIdentity.js \
        || die "Failed to generate a new identity."
      echo
      printf "${RED}${BOLD}!! IMPORTANT — BACK UP THE PRIVATE KEY PRINTED ABOVE !!${NC}\n"
      printf "${RED}This key IS your agent's Billions identity. If you lose it, you\n"
      printf "lose the identity (and any FAIAR rewards tied to it).\n"
      printf "Save it in a password manager NOW. It will not be shown again.${NC}\n"
      echo
      _=$(ask "Press ENTER once you have backed up the key" "")
      ;;
  esac
fi

# --- Step 4: link to Billions account ---------------------------------------
echo
say "Step 4/4 — link this agent to your Billions account"
AGENT_NAME=$(ask "Agent name" "My Verified Agent")
AGENT_DESC=$(ask "Short description" "AI agent verified via Billions FAIAR")

# Escape double quotes for safe JSON embedding.
esc_name=$(printf '%s' "$AGENT_NAME" | sed 's/"/\\"/g')
esc_desc=$(printf '%s' "$AGENT_DESC" | sed 's/"/\\"/g')
CHALLENGE="{\"name\":\"${esc_name}\",\"description\":\"${esc_desc}\"}"

echo
say "Generating the verification link..."
run_in_skill node scripts/manualLinkHumanToAgent.js --challenge "$CHALLENGE" \
  || die "Failed to generate the verification link."

echo
warn "Open the link printed above in your browser and sign in with your Billions account."
warn "That is what tells Billions which account this agent belongs to."
_=$(ask "Press ENTER once you've completed the link in your browser" "")

# --- Register skill with the AI agent ---------------------------------------
echo
say "Registering the skill with your AI agent (pick one when prompted)"
warn "Use ↑/↓ to scroll, SPACE to select (e.g. Claude Code), ENTER to confirm."
if [ -n "$TTY" ] && [ "$TTY" != "/dev/stdin" ]; then
  npx --yes skills add BillionsNetwork/verified-agent-identity <"$TTY"
else
  npx --yes skills add BillionsNetwork/verified-agent-identity
fi

echo
ok "Verified Agent Identity skill installed and linked to your Billions account."
say "You're qualified for the Billions FAIAR reward 🎉"
echo
printf "Built with ❤️ by \033]8;;https://x.com/FASHAKING3\033\\fashaking\033]8;;\033\\ for the Billions Community\n"
