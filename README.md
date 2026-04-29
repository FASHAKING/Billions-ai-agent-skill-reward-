# 🚀 Verified Agent Identity — Setup Guide

Qualify for the **Billions Network FAIAR reward** by giving your AI agent a
verified on-chain identity and linking it to your Billions account. Pick your
platform below and run the one-command installer.

---

## 🎁 About the FAIAR Reward

**FAIAR** (Future of AI Agent Reputation) is Billions Network's incentive
program for AI agents that prove a verified identity. By installing the
`verified-agent-identity` skill, your agent becomes eligible to:

- ✅ Earn **FAIAR rewards** distributed by Billions Network
- ✅ Get listed as a **verified agent** in the Billions ecosystem
- ✅ Participate in upcoming **agent reputation drops & airdrops**
- ✅ Build a **verifiable reputation** that follows your agent across platforms

### Eligibility checklist

1. You have a Billions account (created in the browser at
   [billions.network](https://billions.network))
2. You install the **Verified Agent Identity** skill (this guide)
3. You complete the in-browser verification link the installer prints at the
   end — that's the step that ties the agent to your Billions account

---

## ⚡ One-Line Install — pick your platform

### 📱 Termux (Android)

```bash
curl -sL https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent.sh | bash
```

### 🪟 Windows (PowerShell / Windows Terminal)

```powershell
irm https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent-windows.ps1 | iex
```

> **Requirements:** Windows 10/11 with PowerShell 5.1+. The script will
> auto-install Node.js and Git via `winget` if they are missing.

### 🍎 macOS (Terminal)

```bash
curl -sL https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent-macos.sh | bash
```

> Works on both Apple Silicon (M1/M2/M3/M4) and Intel Macs. The script will
> auto-install Homebrew, Node.js, and Git if they are missing.

### 🐧 Linux / WSL / GitHub Codespaces / Gitpod

```bash
curl -sL https://raw.githubusercontent.com/FASHAKING/Billions-ai-agent-skill-reward-/main/install-agent-codespaces.sh | bash
```

> Works on any Ubuntu/Debian-based Linux environment. Also supports Fedora,
> CentOS, and Alpine.

---

## 🔄 What the installers do

Each installer follows the same flow:

1. **Installs Node.js and Git** (if not already present) using the right
   package manager for your OS (`pkg`, `apt`, `dnf`, `pacman`, `brew`,
   `winget`).
2. **Sets up the Billions identity for your agent** — and this is where the
   answer to *"which Billions account does this agent belong to?"* lives:
   - If `BILLIONS_PRIVATE_KEY` is set in your environment, it's imported.
   - Else, if a previous install is found at `~/verified-agent-identity` with
     an existing identity file, you'll be asked whether to **reuse** it.
   - Else, you pick:
     - `[1]` **Import an existing private key** — paste it (input is hidden).
     - `[2]` **Generate a brand-new identity** — the new key is printed once.
       **Back it up before pressing ENTER** — it will not be shown again.
3. **Clones** [BillionsNetwork/verified-agent-identity](https://github.com/BillionsNetwork/verified-agent-identity)
   into `~/verified-agent-identity` (only if not reusing).
4. **Installs dependencies** via `clawhub`, with a fallback to `npm install`,
   and pre-installs the modules that are commonly missing
   (`shell-quote`, `@iden3/js-iden3-auth`, `ethers@6`, `uuid`).
5. **Creates / imports your Agent Ethereum Identity** by running
   `node scripts/createNewEthereumIdentity.js` (with `--key <KEY>` if you're
   importing).
6. **Generates a verification URL** by running
   `node scripts/manualLinkHumanToAgent.js --challenge '{...}'` with the
   agent name and description you entered. Open this URL in your browser and
   sign in with your Billions account — that handshake is what tells Billions
   *which account this agent belongs to*.

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
attached, and FAIAR rewards have nowhere to go.

---

## 📋 Manual Step-by-Step

<details>
<summary><b>Termux (Android)</b></summary>

```bash
# 1. Update and install prerequisites
pkg update && pkg upgrade
pkg install nodejs git

# 2. Clone the skill repo
cd ~
git clone https://github.com/BillionsNetwork/verified-agent-identity.git
cd verified-agent-identity

# 3. Install dependencies
npx clawhub@latest install verified-agent-identity --force
npm install shell-quote @iden3/js-iden3-auth ethers@6 uuid

# 4a. Create a new identity...
node scripts/createNewEthereumIdentity.js
# 4b. ...or import an existing private key
node scripts/createNewEthereumIdentity.js --key <your-ethereum-private-key>

# 5. Link your Billions account (prints a URL — open it in your browser)
node scripts/manualLinkHumanToAgent.js --challenge '{"name":"MyAgent","description":"AI agent"}'
```

</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
# 1. Install Node.js and Git
winget install OpenJS.NodeJS.LTS
winget install Git.Git

# 2. Clone the skill repo
cd $HOME
git clone https://github.com/BillionsNetwork/verified-agent-identity.git
cd verified-agent-identity

# 3. Install dependencies
npx clawhub@latest install verified-agent-identity
npm install shell-quote @iden3/js-iden3-auth ethers@6 uuid

# 4a. Create a new identity...
node scripts/createNewEthereumIdentity.js
# 4b. ...or import an existing private key
node scripts/createNewEthereumIdentity.js --key <your-ethereum-private-key>

# 5. Link your Billions account
node scripts/manualLinkHumanToAgent.js --challenge '{"name":"MyAgent","description":"AI agent"}'
```

</details>

<details>
<summary><b>macOS</b></summary>

```bash
# 1. Install Homebrew (if not already), then Node.js + Git
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install node git

# 2. Clone the skill repo
cd ~
git clone https://github.com/BillionsNetwork/verified-agent-identity.git
cd verified-agent-identity

# 3. Install dependencies
npx clawhub@latest install verified-agent-identity
npm install shell-quote @iden3/js-iden3-auth ethers@6 uuid

# 4a. Create a new identity...
node scripts/createNewEthereumIdentity.js
# 4b. ...or import an existing private key
node scripts/createNewEthereumIdentity.js --key <your-ethereum-private-key>

# 5. Link your Billions account
node scripts/manualLinkHumanToAgent.js --challenge '{"name":"MyAgent","description":"AI agent"}'
```

</details>

<details>
<summary><b>Linux / WSL / Codespaces</b></summary>

```bash
# 1. Install Node.js and Git
sudo apt-get update && sudo apt-get install -y nodejs npm git
# (or dnf / yum / apk equivalents on your distro)

# 2. Clone the skill repo
cd ~
git clone https://github.com/BillionsNetwork/verified-agent-identity.git
cd verified-agent-identity

# 3. Install dependencies
npx clawhub@latest install verified-agent-identity
npm install shell-quote @iden3/js-iden3-auth ethers@6 uuid

# 4a. Create a new identity...
node scripts/createNewEthereumIdentity.js
# 4b. ...or import an existing private key
node scripts/createNewEthereumIdentity.js --key <your-ethereum-private-key>

# 5. Link your Billions account
node scripts/manualLinkHumanToAgent.js --challenge '{"name":"MyAgent","description":"AI agent"}'
```

</details>

---

## 🆘 Common Error Fixes

**`Cannot find module 'shell-quote'`**
```bash
npm install shell-quote
```

**`Cannot find module '@iden3/js-iden3-auth'`**
```bash
npm install @iden3/js-iden3-auth
```

> **Note:** The one-command installers pre-install these modules
> automatically.

---

## 🔗 Links

- **Billions Network:** https://billions.network
- **FAIAR program:** https://billions.network/faiar
- **Verified Agent Identity skill:** https://github.com/BillionsNetwork/verified-agent-identity

---

Built with ❤️ by [fashaking](https://x.com/FASHAKING3) for the Billions Community
