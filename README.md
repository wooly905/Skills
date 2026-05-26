# Skills

A collection of [Agent Skills](https://agentskills.io/) that work across Claude Code, GitHub Copilot (VS Code), and Cursor.

## Installation

All skills follow the [Agent Skills open standard](https://agentskills.io/specification). Copy the desired skill folder to your user-level skills directory to make it available across all projects.

### Shared path (Claude Code + GitHub Copilot + Cursor)

`~/.claude/skills/` is the only user-level path natively supported by all three tools.

> **Platform**: Windows only. The installer and the bundled `youtube-transcript` skill use PowerShell and `winget`; macOS and Linux are not supported.

Install all skills:

```powershell
.\install.ps1
```

Install a single skill:

```powershell
.\install.ps1 -Skill youtube-transcript
```

### Alternative paths (tool-specific)

| Tool | User-level paths |
|------|-----------------|
| Claude Code | `~/.claude/skills/<name>/` |
| GitHub Copilot (VS Code) | `~/.copilot/skills/<name>/` or `~/.agents/skills/<name>/` |
| Cursor | `~/.cursor/skills/<name>/` or `~/.agents/skills/<name>/` |

> **Recommended**: Use `~/.claude/skills/` — it's the only path all three tools share.

## Available Skills

| Skill | Description |
|-------|-------------|
| [youtube-transcript](./youtube-transcript/) | Download YouTube audio and generate transcripts (txt, srt, vtt, tsv, json) using OpenAI Whisper with GPU acceleration |

## Adding a New Skill

1. Create a folder named after your skill (lowercase, hyphens only)
2. Add a `SKILL.md` with YAML frontmatter (`name`, `description`) and instructions
3. Include any scripts, references, or assets in the same folder
4. Update this README's "Available Skills" table

```
my-new-skill/
├── SKILL.md           # Required
├── scripts/           # Optional
├── references/        # Optional
└── assets/            # Optional
```

## Compatibility

- **Standard**: [Agent Skills (agentskills.io)](https://agentskills.io/)
- **Tools**: Claude Code, GitHub Copilot, Cursor, and any agent supporting the standard
