# ihudak-copilot-plugins

Ivan Gudak's private GitHub Copilot plugin marketplace.

## Plugins

| Plugin | Description |
|--------|-------------|
| [dev-workflows](dev-workflows/) | Structured development workflow skills: `impl:` for feature implementation, `fix-vuln:` for CVE remediation, `upgrade:` for dependency upgrades — with Opus review gate and parallel subagent execution |
| [obsidian-llm-wiki](obsidian-llm-wiki/) | Seven natural language prefixes for compiling Obsidian vault knowledge into a persistent, cross-referenced wiki; supports GitHub Copilot and Claude Code |

## Installation

### 1. Add this marketplace to GitHub Copilot (once)

```bash
copilot plugin marketplace add ivan-gudak/ihudak-copilot-plugins
```

### 2. Install plugins

```bash
copilot plugin install dev-workflows@ihudak-copilot-plugins
copilot plugin install obsidian-llm-wiki@ihudak-copilot-plugins
```

## Repository structure

```
ihudak-copilot-plugins/
├── dev-workflows/
│   ├── .plugin/plugin.json
│   ├── README.md
│   └── skills/
│       ├── impl/
│       ├── fix-vuln/
│       ├── upgrade/
│       └── <sub-agents>
├── obsidian-llm-wiki/
│   ├── .plugin/plugin.json
│   ├── README.md
│   └── skills/
│       ├── wiki-ingest/
│       ├── wiki-scan/
│       ├── wiki-query/
│       └── <other wiki skills>
└── .github/
    ├── copilot-instructions.md
    └── plugin/marketplace.json
```

## License

MIT — see [LICENSE](LICENSE).
