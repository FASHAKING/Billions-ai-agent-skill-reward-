# 🚀 Billions FAIAR Reward — Verified Agent Identity Installer

Qualify for the **Billions Network FAIAR reward** by adding the official
**Verified Agent Identity** skill to your AI agent (Claude Code, Cursor, etc.).
This repo gives you a **single command** that does everything for you.

---

## 🎁 About the FAIAR Reward

**FAIAR** (Future of AI Agent Reputation) is Billions Network's incentive
program for AI agents that prove a verified, on-chain identity. By installing
the `verified-agent-identity` skill, your agent becomes eligible to:

- ✅ Earn **FAIAR rewards** distributed by Billions Network
- ✅ Get listed as a **verified agent** in the Billions ecosystem
- ✅ Participate in upcoming **agent reputation drops & airdrops**
- ✅ Build a **verifiable reputation** that follows your agent across platforms

### Eligibility checklist
1. You have an AI agent installed locally (Claude Code, Cursor, Cline, etc.)
2. You install the **Verified Agent Identity** skill (this guide)
3. Your agent runs the verification once after install

That's it — no wallet purchase, no gas fees, no waitlist.

---

## ⚡ One-Line Install

### 🐧 Linux  /  🍎 macOS  /  📱 Termux (Android)
```bash
curl -sL https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent.sh | bash
```

### 🪟 Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent.ps1 | iex
```

> The installer **only prompts you when input is actually required** — namely
> when picking which AI agent to install the skill into. Everything else
> (Node install, package fetch, confirmations) runs automatically.

---

## 📋 Full Step-by-Step Walkthrough

### STEP 1 — Open your terminal

| Platform | How to open |
|---|---|
| **Linux** | `Ctrl + Alt + T` or your terminal app |
| **macOS** | `⌘ + Space` → "Terminal" |
| **Windows** | `Win + X` → **Windows PowerShell** (or **Terminal**) |
| **Android** | Install **Termux** from F-Droid, then open it |

### STEP 2 — Paste the one-line command for your platform

Copy the command from the **One-Line Install** section above and paste it
into your terminal. Press **Enter**.

🚦 The script will:
1. Detect your operating system
2. Check that **Node.js** + **npx** are installed (auto-installs if missing
   via `pkg` / `apt` / `dnf` / `pacman` / `brew` / `winget`)
3. Install the skill files: `npx clawhub@latest install verified-agent-identity`
4. **Set up your Billions identity** (see STEP 3)
5. **Generate a verification link** so you can connect this agent to your
   Billions account in the browser (see STEP 4)
6. Register the skill with the AI agent of your choice:
   `npx skills add BillionsNetwork/verified-agent-identity`

### STEP 3 — Billions identity

The agent needs an Ethereum identity (a private key) to be addressable by
Billions. The installer handles this for you in one of three ways, in order:

1. **Already on this machine?** If a key is detected at a known path (e.g.
   `~/.billions/identity.json` or in the skill folder) it is reused
   automatically — you'll just see a confirmation.
2. **`BILLIONS_PRIVATE_KEY` env var set?** It will be imported.
3. **Neither?** You're asked:
   - **`[1]` I already have a private key** — paste it (input is hidden) and it
     will be imported via `scripts/createNewEthereumIdentity.js --key <KEY>`.
   - **`[2]` Generate a brand-new identity for me** — runs
     `scripts/createNewEthereumIdentity.js` and prints the new key. **Back it
     up in a password manager before pressing ENTER** — it will not be shown
     again, and losing it means losing the identity (and any FAIAR rewards
     tied to it).

### STEP 4 — Link the agent to your Billions account

The installer asks for a short **agent name** and **description**, then runs:

```
node scripts/manualLinkHumanToAgent.js --challenge '{"name":"...","description":"..."}'
```

That command prints a verification URL on `billions.network`. **Open it in
your browser and sign in with your Billions account** — that handshake is
what tells Billions which account this agent belongs to. Press ENTER in the
terminal when done.

### STEP 5 — Choose your agent (only interactive picker)

You'll see a list of installed AI agents:

```
? Which agent do you want to install this skill to?
  ◯ Claude Code
  ◯ Cursor
  ◯ Cline
  ◯ Continue
  ...
```

🎯 **Use ↑ / ↓ arrow keys** to scroll
🎯 **Press SPACE** to select your agent (e.g. *Claude Code*)
🎯 **Press ENTER** to confirm

### STEP 6 — Done ✅

You should see:
```
✔  Verified Agent Identity skill installed.
==> You're qualified for the Billions FAIAR reward 🎉
```

Your agent is now a **Verified Agent** and eligible for the FAIAR reward.

---

## 🔍 Verifying the install

Open your AI agent and run:
```
/skills
```
You should see **verified-agent-identity** in the list.

Or check the skills directory:
- **Claude Code**: `~/.claude/skills/verified-agent-identity/`
- **Cursor / Cline**: `~/.cursor/skills/` or your agent's skills folder

---

## 🆘 Troubleshooting

<details>
<summary><b>"npx: command not found"</b></summary>

The installer auto-installs Node.js, but if it fails:
- **Termux:** `pkg install nodejs`
- **Linux (Debian/Ubuntu):** `sudo apt install nodejs npm`
- **Linux (Fedora):** `sudo dnf install nodejs npm`
- **macOS:** `brew install node`  (install Homebrew first from https://brew.sh)
- **Windows:** download installer from https://nodejs.org/
</details>

<details>
<summary><b>"Permission denied" on Linux/macOS</b></summary>

Don't run the curl command with `sudo`. If a step needs root (e.g. installing
Node), the script will call `sudo` itself.
</details>

<details>
<summary><b>The agent picker doesn't show my agent</b></summary>

Make sure your agent is installed and has been launched at least once so its
config directory exists. Then re-run the one-line command.
</details>

<details>
<summary><b>I want to skip the auto-installer and run it manually</b></summary>

```bash
# 1. Install skill files
npx clawhub@latest install verified-agent-identity

# 2. Identity — either generate a new one...
cd ~/.claude/skills/verified-agent-identity   # or wherever your skill lives
node scripts/createNewEthereumIdentity.js

#    ...or import an existing private key
node scripts/createNewEthereumIdentity.js --key <your-ethereum-private-key>

# 3. Link this agent to your Billions account (opens a URL to billions.network)
node scripts/manualLinkHumanToAgent.js --challenge '{"name":"My Agent","description":"AI agent verified via Billions FAIAR"}'

# 4. Register the skill with your AI agent
npx skills add BillionsNetwork/verified-agent-identity
```
</details>

<details>
<summary><b>How does the agent know which Billions account to link to?</b></summary>

It doesn't — until you tell it. The link happens in two pieces:

1. The agent gets its own **Ethereum identity** (a keypair generated locally
   by `scripts/createNewEthereumIdentity.js`, or one you import with
   `--key`). That's the agent's address.
2. `scripts/manualLinkHumanToAgent.js` produces a **verification URL** on
   `billions.network`. When you open that URL while signed in to your
   Billions account, Billions records the binding *human account ↔ agent
   address*. That browser sign-in is the only place your Billions account
   identity comes from — the installer never asks for it directly.

If you skip step 2, the agent has an identity but no Billions account
attached, and FAIAR rewards have nowhere to go.
</details>

---

## 🔐 Security note

This installer runs two `npx` commands published by **Billions Network** and
**Clawhub**. You can audit the script before running it:

```bash
curl -sL https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent.sh | less
```

---

## 🔗 Links

- **Billions Network:** https://billions.network
- **FAIAR program:** https://billions.network/faiar
- **Verified Agent Identity skill:** https://github.com/BillionsNetwork/verified-agent-identity

---

Built with ❤️ by [fashaking](https://x.com/FASHAKING3) for the Billions Community
