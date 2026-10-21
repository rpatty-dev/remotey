---
name: remotey
description: "Remotey Computer-Use & Remote Work PC Automation Skill. Enables AI agents (Antigravity, Claude, Cursor, OpenDevin) to act as the autonomous brain controlling a remote Windows desktop over Tailscale or local network. Provides capabilities to capture live desktop screenshots, click exact UI coordinates, move the mouse, type text, trigger hotkeys, scroll, and execute PowerShell/CMD commands on the remote Windows desktop."
---

# Remotey Computer-Use Skill 🖥️

Connect your AI Agent (Antigravity, Claude, Cursor) as the autonomous "Brain" controlling a remote Windows PC.

## Architecture

```
┌──────────────────────────────────────┐          Tailscale Encrypted Tunnel          ┌──────────────────────────────────────┐
│        AI Agent Brain (Mac/Linux)    │ ───────────────────────────────────────────> │        Remote Windows Desktop        │
│  - Antigravity / Claude / Cursor     │               HTTP / JSON (7777)             │  - Pure PowerShell & Win32 API       │
│  - Reads screen via Vision           │ <─────────────────────────────────────────── │  - Real mouse / keyboard simulation  │
│  - Decides coordinates & actions     │          Fast Screenshots (<100ms)           │  - Full shell execution              │
└──────────────────────────────────────┘                                              └──────────────────────────────────────┘
```

## Quick Reference Commands

All commands can be invoked using `remotey` (or `npx remotey`):

| Action | Command | Description |
|---|---|---|
| **Status Check** | `remotey status` | Checks connection, resolution, cursor position, active window title |
| **Take Screenshot** | `remotey screenshot /tmp/screen.png` | Captures primary display to PNG file |
| **Click Mouse** | `remotey click <x> <y> [left\|right]` | Moves cursor and simulates mouse click |
| **Double Click** | `remotey dblclick <x> <y>` | Simulates double-click at coordinate |
| **Right Click** | `remotey rightclick <x> <y>` | Simulates right-click context menu |
| **Move Cursor** | `remotey move <x> <y>` | Smoothly moves mouse cursor |
| **Type Text** | `remotey type "Hello World"` | Types text into active focused element |
| **Send Key** | `remotey key enter` | Presses single key (`enter`, `tab`, `esc`, `backspace`) |
| **Hotkey Shortcut** | `remotey hotkey "win+r"` | Triggers shortcut (`ctrl+c`, `alt+tab`, `win+r`) |
| **Scroll Screen** | `remotey scroll -200` | Scrolls mouse wheel down (`-200`) or up (`200`) |
| **Run Shell** | `remotey run "<cmd>"` | Executes command in remote Windows PowerShell |

## Autonomous Computer-Use Workflow for AI Agents

When given a user instruction to operate the remote machine:

1. **Inspect State**:
   ```bash
   remotey status
   remotey screenshot /tmp/screen.png
   ```
2. **Analyze Screen**:
   Inspect `/tmp/screen.png` to find UI coordinates for target buttons, inputs, or menus.
3. **Act**:
   ```bash
   remotey click <x> <y>
   remotey type "Search Query"
   remotey key enter
   ```
4. **Verify**:
   Capture a fresh screenshot to confirm the action took effect before continuing.
