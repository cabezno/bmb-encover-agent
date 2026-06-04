<p align="center">
  <img src="assets/banner.png" alt="BlackMagicBox Encover Agent" width="100%">
</p>

# BlackMagicBox Encover Agent â˜¤

<p align="center">
  <a href="https://bmb-encover.blackmagicbox.com/docs/"><img src="https://img.shields.io/badge/Docs-bmb--agent.blackmagicbox.com-FFD700?style=for-the-badge" alt="Documentation"></a>
  <a href="https://discord.gg/Encover"><img src="https://img.shields.io/badge/Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="https://github.com/cabezno/bmb-encover-agent/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License: MIT"></a>
  <a href="https://blackmagicbox.com"><img src="https://img.shields.io/badge/Built%20by-Nous%20Research-blueviolet?style=for-the-badge" alt="Built by Encover"></a>
</p>

**The self-improving AI agent built by [Encover](https://blackmagicbox.com).** It's the only agent with a built-in learning loop â€” it creates skills from experience, improves them during use, nudges itself to persist knowledge, searches its own past conversations, and builds a deepening model of who you are across sessions. Run it on a $5 VPS, a GPU cluster, or serverless infrastructure that costs nearly nothing when idle. It's not tied to your laptop â€” talk to it from Telegram while it works on a cloud VM.

Use any model you want â€” [Nous Portal](https://portal.blackmagicbox.com), [OpenRouter](https://openrouter.ai) (200+ models), [NVIDIA NIM](https://build.nvidia.com) (Nemotron), [Xiaomi MiMo](https://platform.xiaomimimo.com), [z.ai/GLM](https://z.ai), [Kimi/Moonshot](https://platform.moonshot.ai), [MiniMax](https://www.minimax.io), [Hugging Face](https://huggingface.co), OpenAI, or your own endpoint. Switch with `bmb model` â€” no code changes, no lock-in.

<table>
<tr><td><b>A real terminal interface</b></td><td>Full TUI with multiline editing, slash-command autocomplete, conversation history, interrupt-and-redirect, and streaming tool output.</td></tr>
<tr><td><b>Lives where you do</b></td><td>Telegram, Discord, Slack, WhatsApp, Signal, and CLI â€” all from a single gateway process. Voice memo transcription, cross-platform conversation continuity.</td></tr>
<tr><td><b>A closed learning loop</b></td><td>Agent-curated memory with periodic nudges. Autonomous skill creation after complex tasks. Skills self-improve during use. FTS5 session search with LLM summarization for cross-session recall. <a href="https://github.com/plastic-labs/honcho">Honcho</a> dialectic user modeling. Compatible with the <a href="https://agentskills.io">agentskills.io</a> open standard.</td></tr>
<tr><td><b>Scheduled automations</b></td><td>Built-in cron scheduler with delivery to any platform. Daily reports, nightly backups, weekly audits â€” all in natural language, running unattended.</td></tr>
<tr><td><b>Delegates and parallelizes</b></td><td>Spawn isolated subagents for parallel workstreams. Write Python scripts that call tools via RPC, collapsing multi-step pipelines into zero-context-cost turns.</td></tr>
<tr><td><b>Runs anywhere, not just your laptop</b></td><td>Six terminal backends â€” local, Docker, SSH, Daytona, Singularity, and Modal. Daytona and Modal offer serverless persistence â€” your agent's environment hibernates when idle and wakes on demand, costing nearly nothing between sessions. Run it on a $5 VPS or a GPU cluster.</td></tr>
<tr><td><b>Research-ready</b></td><td>Batch trajectory generation, Atropos RL environments, trajectory compression for training the next generation of tool-calling models.</td></tr>
</table>

---

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/Encover/bmb-encover/main/scripts/install.sh | bash
```

Works on Linux, macOS, WSL2, and Android via Termux. The installer handles the platform-specific setup for you.

> **Android / Termux:** The tested manual path is documented in the [Termux guide](https://bmb-encover.blackmagicbox.com/docs/getting-started/termux). On Termux, BAG installs a curated `.[termux]` extra because the full `.[all]` extra currently pulls Android-incompatible voice dependencies.
>
> **Windows:** Native Windows is not supported. Please install [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) and run the command above.
>
> **Windows (portable community flow):** See [README_WINDOWS_PORTABLE.md](README_WINDOWS_PORTABLE.md) for an unofficial local setup path.
>
> **Quickstart (Windows):** See [QUICKSTART_WINDOWS.md](QUICKSTART_WINDOWS.md) for the 2-minute setup.

After installation:

```bash
source ~/.bashrc    # reload shell (or: source ~/.zshrc)
hermes              # start chatting!
```

---

## Getting Started

```bash
hermes              # Interactive CLI â€” start a conversation
hermes model        # Choose your LLM provider and model
bmb tools        # Configure which tools are enabled
bmb config set   # Set individual config values
bmb gateway      # Start the messaging gateway (Telegram, Discord, etc.)
bmb setup        # Run the full setup wizard (configures everything at once)
hermes claw migrate # Migrate from OpenClaw (if coming from OpenClaw)
bmb update       # Update to the latest version
hermes doctor       # Diagnose any issues
```

ðŸ“– **[Full documentation â†’](https://bmb-encover.blackmagicbox.com/docs/)**

## CLI vs Messaging Quick Reference

BMB has two entry points: start the terminal UI with `bag`, or run the gateway and talk to it from Telegram, Discord, Slack, WhatsApp, Signal, or Email. Once you're in a conversation, many slash commands are shared across both interfaces.

| Action | CLI | Messaging platforms |
|---------|-----|---------------------|
| Start chatting | `bag` | Run `bmb gateway setup` + `bmb gateway start`, then send the bot a message |
| Start fresh conversation | `/new` or `/reset` | `/new` or `/reset` |
| Change model | `/model [provider:model]` | `/model [provider:model]` |
| Set a personality | `/personality [name]` | `/personality [name]` |
| Retry or undo the last turn | `/retry`, `/undo` | `/retry`, `/undo` |
| Compress context / check usage | `/compress`, `/usage`, `/insights [--days N]` | `/compress`, `/usage`, `/insights [days]` |
| Browse skills | `/skills` or `/<skill-name>` | `/<skill-name>` |
| Interrupt current work | `Ctrl+C` or send a new message | `/stop` or send a new message |
| Platform-specific status | `/platforms` | `/status`, `/sethome` |

For the full command lists, see the [CLI guide](https://bmb-encover.blackmagicbox.com/docs/user-guide/cli) and the [Messaging Gateway guide](https://bmb-encover.blackmagicbox.com/docs/user-guide/messaging).

---

## Documentation

All documentation lives at **[bmb-encover.blackmagicbox.com/docs](https://bmb-encover.blackmagicbox.com/docs/)**:

| Section | What's Covered |
|---------|---------------|
| [Quickstart](https://bmb-encover.blackmagicbox.com/docs/getting-started/quickstart) | Install â†’ setup â†’ first conversation in 2 minutes |
| [CLI Usage](https://bmb-encover.blackmagicbox.com/docs/user-guide/cli) | Commands, keybindings, personalities, sessions |
| [Configuration](https://bmb-encover.blackmagicbox.com/docs/user-guide/configuration) | Config file, providers, models, all options |
| [Messaging Gateway](https://bmb-encover.blackmagicbox.com/docs/user-guide/messaging) | Telegram, Discord, Slack, WhatsApp, Signal, Home Assistant |
| [Security](https://bmb-encover.blackmagicbox.com/docs/user-guide/security) | Command approval, DM pairing, container isolation |
| [Tools & Toolsets](https://bmb-encover.blackmagicbox.com/docs/user-guide/features/tools) | 40+ tools, toolset system, terminal backends |
| [Skills System](https://bmb-encover.blackmagicbox.com/docs/user-guide/features/skills) | Procedural memory, Skills Hub, creating skills |
| [Memory](https://bmb-encover.blackmagicbox.com/docs/user-guide/features/memory) | Persistent memory, user profiles, best practices |
| [MCP Integration](https://bmb-encover.blackmagicbox.com/docs/user-guide/features/mcp) | Connect any MCP server for extended capabilities |
| [Cron Scheduling](https://bmb-encover.blackmagicbox.com/docs/user-guide/features/cron) | Scheduled tasks with platform delivery |
| [Context Files](https://bmb-encover.blackmagicbox.com/docs/user-guide/features/context-files) | Project context that shapes every conversation |
| [Architecture](https://bmb-encover.blackmagicbox.com/docs/developer-guide/architecture) | Project structure, agent loop, key classes |
| [Contributing](https://bmb-encover.blackmagicbox.com/docs/developer-guide/contributing) | Development setup, PR process, code style |
| [CLI Reference](https://bmb-encover.blackmagicbox.com/docs/reference/cli-commands) | All commands and flags |
| [Environment Variables](https://bmb-encover.blackmagicbox.com/docs/reference/environment-variables) | Complete env var reference |

---

## Migrating from OpenClaw

If you're coming from OpenClaw, BAG can automatically import your settings, memories, skills, and API keys.

**During first-time setup:** The setup wizard (`bmb setup`) automatically detects `~/.openclaw` and offers to migrate before configuration begins.

**Anytime after install:**

```bash
hermes claw migrate              # Interactive migration (full preset)
hermes claw migrate --dry-run    # Preview what would be migrated
hermes claw migrate --preset user-data   # Migrate without secrets
hermes claw migrate --overwrite  # Overwrite existing conflicts
```

What gets imported:
- **SOUL.md** â€” persona file
- **Memories** â€” MEMORY.md and USER.md entries
- **Skills** â€” user-created skills â†’ `~/.bmb/skills/openclaw-imports/`
- **Command allowlist** â€” approval patterns
- **Messaging settings** â€” platform configs, allowed users, working directory
- **API keys** â€” allowlisted secrets (Telegram, OpenRouter, OpenAI, Anthropic, ElevenLabs)
- **TTS assets** â€” workspace audio files
- **Workspace instructions** â€” AGENTS.md (with `--workspace-target`)

See `bmb claw migrate --help` for all options, or use the `openclaw-migration` skill for an interactive agent-guided migration with dry-run previews.

---

## Contributing

We welcome contributions! See the [Contributing Guide](https://bmb-encover.blackmagicbox.com/docs/developer-guide/contributing) for development setup, code style, and PR process.

Quick start for contributors â€” clone and go with `setup-bmb.sh`:

```bash
git clone https://github.com/cabezno/bmb-encover-agent.git
cd bmb-encover
./setup-bmb.sh     # installs uv, creates venv, installs .[all], symlinks ~/.local/bin/bmb
./bmb              # auto-detects the venv, no need to `source` first
```

Manual path (equivalent to the above):

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv venv venv --python 3.11
source venv/bin/activate
uv pip install -e ".[all,dev]"
scripts/run_tests.sh
```

> **RL Training (optional):** The RL/Atropos integration (`environments/`) ships via the `atroposlib` and `tinker` dependencies pulled in by `.[all,dev]` â€” no submodule setup required.

---

## Community

- ðŸ’¬ [Discord](https://discord.gg/Encover)
- ðŸ“š [Skills Hub](https://agentskills.io)
- ðŸ› [Issues](https://github.com/cabezno/bmb-encover-agent/issues)
- ðŸ”Œ [HermesClaw](https://github.com/AaronWong1999/bmbclaw) â€” Community WeChat bridge: Run BlackMagicBox Encover Agent and OpenClaw on the same WeChat account.

---

## License

MIT â€” see [LICENSE](LICENSE).

Built by [Encover](https://blackmagicbox.com).
# Fri May 15 16:44:40 -03 2026
# Fri May 15 22:37:05 -03 2026
# trigger Sat May 16 01:58:07 -03 2026
# fix flutter Sat May 16 04:38:58 -03 2026
# Sun May 17 12:38:13 -03 2026

