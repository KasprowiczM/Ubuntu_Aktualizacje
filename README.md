# 🚀 Ubuntu_Aktualizacje

**Automated System Maintenance & Inventory Suite for Ubuntu 24.04**

[![Validate Config](https://github.com/KasprowiczM/Ubuntu_Aktualizacje/actions/workflows/validate.yml/badge.svg)](https://github.com/KasprowiczM/Ubuntu_Aktualizacje/actions/workflows/validate.yml)
[![AI-Orchestrated](https://img.shields.io/badge/AI-Orchestrated-blueviolet?style=flat-square)](#-ai-orchestration--agents)
[![Maintainer: mk](https://img.shields.io/badge/Maintainer-mk-blue?style=flat-square)](https://github.com/KasprowiczM)

---

## 💎 Overview

`Ubuntu_Aktualizacje` is a professional-grade, single-command update engine designed for **Ubuntu 24.04 (Dell Precision 5520)**. It orchestrates multiple package managers, hardware drivers, and system firmware updates with extreme reliability and full traceability.

### ✨ Key Features
- **Unified Orchestration**: One command to rule APT, Snap, Homebrew, npm, pip/pipx, Flatpak, and NVIDIA.
- **AI-Native Workflow**: Deeply integrated with **Claude Code**, **Gemini CLI**, and **Codex** with pre-configured expert agents.
- **Live Inventory**: Automatically regenerates `APPS.md` (ignored) after every run to track machine-specific state.
- **Safety First**: Uses `set -euo pipefail`, dry-run support, and intelligent sudo-handling (dropping to user for brew/npm).
- **Weekly Automation**: Built-in systemd timers for unattended weekly maintenance (excluding critical drivers).

---

## 🤖 AI Orchestration & Agents

This repository is optimized for **AI-driven development**. It features a robust model hierarchy to balance performance, cost, and safety.

### 🎭 Model Hierarchy & Roles
| Role | Profile | Claude Model | Gemini Model | Task Profile |
|:---:|:---:|:---:|:---:|:---|
| **Orchestrator** | `default` | **Sonnet 4.6** | **3.1 Pro** | Planning, complex refactors, and daily work. |
| **Advisor** | `advisor` | **Opus 4.7** | **3.1 Pro** | **Read-only** architecture review & security audits. |
| **Worker** | `worker-fast`| **Haiku 4.6** | **3.0 Flash** | Boilerplate, tests, docs, and simple fixes. |

> [!IMPORTANT]
> **PLANNING RULE**: Agents follow a strict rule—no code changes until 95% confidence is reached.
> All agent rules are organized via **Progressive Disclosure**:
> - [AGENTS.md](file:///home/mk/Dev_Env/Ubuntu_Aktualizacje/AGENTS.md) — Central indexing of AI rules.
> - [CLAUDE.md](file:///home/mk/Dev_Env/Ubuntu_Aktualizacje/CLAUDE.md) — Claude-specific workflow.
> - [docs/agents/workflow.md](file:///home/mk/Dev_Env/Ubuntu_Aktualizacje/docs/agents/workflow.md) — Detailed profiling & delegation rules.

---

## 📦 What Gets Updated?

| Scope | Package Manager | Includes |
|:---|:---|:---|
| **System** | **APT** | OS updates, Chrome, VSCode, Docker, NVIDIA, Brave, Rclone. |
| **User Space** | **Homebrew** | CLI tools (gemini, claude, etc.), Node.js, GCC, Ripgrep. |
| **Sandboxed** | **Snap / Flatpak**| Firefox, Thunderbird, KeePassXC, htop, desktop apps. |
| **Languages** | **npm / pip / pipx**| Global node packages, Python user libraries, isolated tools. |
| **Hardware** | **NVIDIA / fwupd** | GPU drivers (safe-held), Dell BIOS/Firmware updates. |

---

## ⚡ Quick Start

### 1. Execute Full Update
```bash
./update-all.sh
```

### 2. Available Options
| Flag | Description |
|:---|:---|
| `--dry-run` | Preview all actions without modifying the system. |
| `--nvidia` | Explicitly allow NVIDIA driver upgrade via APT (default is **held**). |
| `--only <group>`| Run one group (e.g., `apt`, `brew`, `npm`, `inventory`). |
| `--no-drivers` | Skip NVIDIA status checks and firmware updates. |
| `--no-notify` | Disable desktop notifications upon completion. |

---

## 🛠️ Project Structure & Architecture

Detailed architecture can be found in [docs/agents/architecture.md](file:///home/mk/Dev_Env/Ubuntu_Aktualizacje/docs/agents/architecture.md).

- **`config/*.list`**: The **Single Source of Truth**. Add packages here.
- **`scripts/update-*.sh`**: Modular, idempotent update scripts.
- **`lib/*.sh`**: Reusable Bash library for colors, detection, and git integration.
- **`setup.sh`**: Universal bootstrap for new machines (`--discover`, `--check`, `--rollback`).

---

## 🚢 Deployment & CI

### Migration to New Machine
```bash
# 1. Discover current state
./setup.sh --discover

# 2. Commit config files
bash lib/git-push.sh commit "Capture state" main

# 3. On new machine
./setup.sh
```

### CI Pipeline
Every push triggers [validate.yml](file:///home/mk/Dev_Env/Ubuntu_Aktualizacje/.github/workflows/validate.yml) which performs:
1. **Config Validation** (syntax check of `.list` files).
2. **Shell Audit** (`bash -n` on all scripts).
3. **Secret Scan** (ensures PAT tokens are not committed).
4. **Consistency Check** (verifies presence of critical files).

---

## 📖 Troubleshooting

- **DKMS failures**: Run `./scripts/rebuild-dkms.sh` after kernel updates.
- **APT multiple sources**: `update-apt.sh` auto-detects MEGA sync duplicates.
- **Brew permissions**: Scripts automatically fix root-owned `__pycache__` in the Cellar.
- **Inventory issues**: Run `./scripts/update-inventory.sh` manually to force refresh.

---

*Maintained by mk · Dell Precision 5520 · Ubuntu 24.04 LTS*
*AI Orchestration enabled via [AGENTS.md](file:///home/mk/Dev_Env/Ubuntu_Aktualizacje/AGENTS.md)*
