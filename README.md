<div align="center">
  <img src="assets/remotey.svg" alt="Remotey Logo" width="180" height="180">
  <h1>Remotey 🖥️</h1>
  <p><strong>Autonomous Computer-Use for AI Agents (Antigravity, Claude, Cursor) connecting Mac to Windows</strong></p>

  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
  [![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%E2%86%92%20Windows-blue)](https://github.com/rpatty-dev/remotey)
  [![Tailscale](https://img.shields.io/badge/Tailscale-Encrypted%20Mesh-blueviolet)](https://tailscale.com)
  [![Zero Dependency](https://img.shields.io/badge/Agent-Pure%20PowerShell%20%2F%20.NET-brightgreen)](agent/)
</div>

---

## ⚡ What is Remotey?

**Remotey** transforms your local AI agent (Google Antigravity, Claude Desktop, Cursor, OpenDevin) on Mac or Linux into the autonomous **"Brain"** controlling a remote Windows desktop.

Instead of running slow, heavyweight VNC or Remote Desktop protocols, Remotey uses an ultra-fast, zero-dependency, native PowerShell TCP agent on Windows that exposes direct computer-use primitives over your private **Tailscale** mesh or LAN:

- 📸 **High-Speed Vision**: Captures screenshots in `<100ms` and pipes them directly to multimodal LLMs
- 🖱️ **Hardware-Level Mouse Control**: Direct `user32.dll` clicks, double-clicks, right-clicks, and smooth cursor positioning
- ⌨️ **Keyboard Simulation**: Native keystroke entry, hotkeys (`Win+R`, `Ctrl+C`, `Alt+Tab`), and multi-line text input
- ⚡ **Zero Dependencies on Windows**: Pure PowerShell 5.1+ and .NET Framework. No Python, no Node, no third-party installers required on the remote target
- 🔒 **End-to-End Encrypted**: Connects securely over your private Tailscale network with zero open public ports

---

## 📋 Prerequisites & Setup

Before running Remotey, ensure both machines are connected via **Tailscale** (or share a local LAN):

1. **Install Tailscale**: Download and install [Tailscale](https://tailscale.com/download) on both your Mac/client machine and your remote Windows PC.
2. **Log in to the same Tailnet**: Ensure both devices appear as "Connected" in your Tailscale admin console.
3. **Note the Windows Tailscale IP**: It starts with `100.x.y.z` (e.g. `100.71.60.14`).

> [!IMPORTANT]
> ### ⚠️ Critical Antivirus & Firewall Disclaimer
> If your Windows PC uses **third-party antivirus or endpoint security** (such as **ESET**, **Malwarebytes**, **Norton**, **Bitdefender**, **Kaspersky**, or **CrowdStrike**), their custom personal firewalls will often intercept and drop incoming Tailscale connections on port `7777`, even if Windows Defender Firewall has allowed the port!
>
> If you experience a `connection timeout` when running `remotey status`:
> 1. Check your 3rd-party antivirus firewall settings.
> 2. Add an inbound allow rule for **TCP port 7777** (or temporarily pause/allow the Tailscale network adapter `100.64.0.0/10`).
> 3. Verify connection with `remotey status`.

---

## 🚀 Quickstart (30 Seconds)

### Step 1: Start the Agent on your Windows PC

1. Download [`START.bat`](agent/START.bat) and [`remotey_server.ps1`](agent/remotey_server.ps1) onto your Windows PC into the same folder.
2. Double-click **`START.bat`** (Click **Yes** when Windows requests Administrator elevation to allow port 7777 in firewall).

You will see:
```text
🚀 Remotey Raw TCP Agent Starting...
[SUCCESS] Listening on 0.0.0.0:7777 (ALL INTERFACES)
Waiting for connection from Mac...
```

---

### Step 2: Use Instantly with `npx` (No Install Needed)

On your Mac or Linux terminal:

```bash
# Point to your Windows PC's Tailscale IP
export REMOTEY_TARGET="http://100.x.y.z:7777"

# Check connection & active window
npx remotey status

# Capture a live screenshot
npx remotey screenshot /tmp/desktop.png

# Click anywhere (x, y)
npx remotey click 500 300

# Type text into focused window
npx remotey type "Hello from Antigravity!"

# Send hotkey
npx remotey hotkey "win+r"
```

To permanently save your target URL so you don't need the environment variable:
```bash
npx remotey set-target http://100.x.y.z:7777
```

---

### Step 3: Install as an AI Agent Skill

Remotey comes pre-packaged with agent skill specifications for **Antigravity**, **Claude**, and **Cursor**:

```bash
npx remotey install-skill
```

This installs the `remotey` skill into `~/.agents/skills/remotey` and `~/.claude/skills/remotey`. Your AI agents will automatically recognize the skill and know how to autonomously inspect screens, click buttons, and operate your remote desktop.

---

## 🛠️ CLI Reference

| Command | Arguments | Description |
|---|---|---|
| `remotey status` | — | Print remote screen resolution, cursor position, active window, and host info |
| `remotey screenshot` | `[path]` | Capture screenshot (default: `/tmp/remotey_screen.png`) |
| `remotey click` | `<x> <y> [btn]` | Click at coordinate (`left` or `right`) |
| `remotey dblclick` | `<x> <y>` | Double click at coordinate |
| `remotey rightclick` | `<x> <y>` | Right click at coordinate |
| `remotey move` | `<x> <y>` | Move cursor to coordinate |
| `remotey type` | `"<text>"` | Type string into focused window |
| `remotey key` | `<key>` | Send key press (`enter`, `tab`, `esc`, `backspace`) |
| `remotey hotkey` | `"<combo>"` | Send shortcut (`ctrl+c`, `alt+tab`, `win+r`) |
| `remotey scroll` | `[amount]` | Scroll wheel (`-200` down, `200` up) |
| `remotey run` | `"<powershell>"` | Execute PowerShell command directly on host and get stdout |
| `remotey set-target` | `<url>` | Persist target URL to `~/.remotey/config.json` |
| `remotey install-skill`| `[agent]` | Install skill into `antigravity`, `claude`, or `cursor` |

---

## 🧠 Autonomous Computer-Use Loop

When an AI Agent is asked to accomplish a desktop task:

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│ 1. Screenshot   │ ───>  │ 2. Vision Model │ ───>  │ 3. Execute      │
│ remotey shot    │       │ locate buttons  │       │ remotey click   │
└─────────────────┘       └─────────────────┘       └─────────────────┘
         ▲                                                   │
         └────────────────── 4. Verify ──────────────────────┘
```

---

## 🛡️ Security & Architecture

- **No Public Cloud Relay**: Direct peer-to-peer over WireGuard/Tailscale.
- **Firewall Guard**: Restricts listening exclusively to the specified local port.
- **Zero Windows Bloat**: Does not require Python, Node.js, C++ compilers, or registry modifications.

---

## 📄 License

MIT © [Ryan Pattison](https://github.com/rpatty-dev)
