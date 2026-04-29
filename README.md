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
3. You complete the in-browser verification link the installer prints at the
   end (only needed for brand-new identities — see the FAQ below)

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

> The installers prompt you only when input is actually required. If a
> Billions identity is already on disk, or you have the private key, you
> won't be asked for an agent name or description — those are only requested
> when generating a brand-new identity.

---

## 🔄 What the installer does

The single multi-platform script handles **Termux / Linux / macOS** (the
PowerShell script is the Windows equivalent). Both go through the same flow:

1. **Decide identity intent** — before anything is installed:
   - If `BILLIONS_PRIVATE_KEY` is set in your environment, it's imported.
   - Else, if a previous install is found at one of:
     `~/verified-agent-identity`, `~/.claude/skills/verified-agent-identity`,
     `~/.cursor/skills/verified-agent-identity`,
     `~/.cline/skills/verified-agent-identity`,
     `~/.continue/skills/verified-agent-identity`,
     `~/.config/clawhub/skills/verified-agent-identity`,
     `~/.clawhub/skills/verified-agent-identity` —
     and contains an identity file (`.identity`, `identity.json`, `.env`,
     or `agent.json`), you're asked **`Reuse it? [Y/n]`**.
   - Else you pick:
     - `[1]` **Import an existing private key** — paste it (input is hidden).
     - `[2]` **Generate a brand-new identity** — the new key is printed once.
       **Back it up before pressing ENTER** — it will not be shown again.
   - **Agent name & description are only requested in the "generate"
     branch.** Reuse / env / import skip those prompts.

2. **Install Node.js + Git** (if missing) using the right package manager
   for your OS (`pkg`, `apt-get`, `dnf`, `pacman`, `apk`, `brew`, `winget`).

3. **Install the skill files** — try clawhub first:
   ```
   npx clawhub@latest install verified-agent-identity
   ```
   …and **fall back to a git clone** if clawhub fails or the scripts can't
   be located afterwards. The fallback clones
   [BillionsNetwork/verified-agent-identity](https://github.com/BillionsNetwork/verified-agent-identity)
   into `~/verified-agent-identity`, then runs `npm install` plus the
   commonly-missing modules: `shell-quote`, `@iden3/js-iden3-auth`,
   `ethers@6`, `uuid`.

4. **Set up the agent's Ethereum identity**:
   - `reuse`: skipped — the existing key is left alone.
   - `env` / `import`: `node scripts/createNewEthereumIdentity.js --key <KEY>`
   - `generate`: `node scripts/createNewEthereumIdentity.js`, followed by
     a back-up-now warning and an ENTER gate.

5. **Link to your Billions account** — only runs in `generate` mode (a
   reused or imported identity is already linked elsewhere). Runs:
   ```
   node scripts/manualLinkHumanToAgent.js --challenge '{"name":"...","description":"..."}'
   ```
   Open the URL it prints in your browser and sign in with your Billions
   account — that handshake is what binds the agent to your account.

6. **Register the skill with your AI agent**:
   ```
   npx skills add BillionsNetwork/verified-agent-identity
   ```
   Pick Claude Code / Cursor / Cline / Continue / etc. with `↑/↓` + `SPACE`
   + `ENTER`.

---

## 🔐 How does the agent know which Billions account to link to?

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
attached, and FAIAR rewards have nowhere to go. (That's why the installer
only skips step 2 when it has good reason to believe you've already done it
on another machine — i.e. you provided the key or it was already on disk.)

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
<summary><b>"Cannot find module 'shell-quote' / '@iden3/js-iden3-auth'"</b></summary>

```bash
npm install shell-quote @iden3/js-iden3-auth ethers@6 uuid
```

The installer pre-installs these in the git-clone fallback path, but if you
ran the manual steps you may need to install them yourself.
</details>

<details>
<summary><b>The agent picker doesn't show my agent</b></summary>

Make sure your agent is installed and has been launched at least once so its
config directory exists. Then re-run the one-line command.
</details>

<details>
<summary><b>I want to skip the auto-installer and run it manually</b></summary>

```bash
# 1. Try clawhub first
npx clawhub@latest install verified-agent-identity

# 2. If clawhub fails — clone the repo and install deps manually
cd ~
git clone https://github.com/BillionsNetwork/verified-agent-identity.git
cd verified-agent-identity
npm install shell-quote @iden3/js-iden3-auth ethers@6 uuid

# 3a. Generate a new identity...
node scripts/createNewEthereumIdentity.js
# 3b. ...or import an existing private key
node scripts/createNewEthereumIdentity.js --key <your-ethereum-private-key>

# 4. Link your Billions account (only needed for new identities)
node scripts/manualLinkHumanToAgent.js --challenge '{"name":"My Agent","description":"AI agent verified via Billions FAIAR"}'

# 5. Register the skill with your AI agent
npx skills add BillionsNetwork/verified-agent-identity
```

PowerShell:
```powershell
npx clawhub@latest install verified-agent-identity
# ...same Node-script calls as above; see install-agent.ps1 for the
# exact PowerShell-quoting trick used for --challenge.
npx skills add BillionsNetwork/verified-agent-identity
```
</details>

---

## 🔐 Security note

This installer runs `npx` commands published by **Billions Network** and
**Clawhub**, and may clone the public
[BillionsNetwork/verified-agent-identity](https://github.com/BillionsNetwork/verified-agent-identity)
repo as a fallback. You can audit the script before running it:

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
