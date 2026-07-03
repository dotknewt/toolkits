# plugins/

This directory holds distributable plugin bundles. Each plugin is a directory with a `.claude-plugin/plugin.json` manifest and may contain agents, skills, commands, hooks, and MCP servers.

The local marketplace at `/.claude-plugin/marketplace.json` registers plugins from `./` and skills from `/skills/`.

## Versioning

When a change to a plugin deviates from `origin/main`, bump the plugin's version in **three** places (they must match):

1. `plugins/<name>/.claude-plugin/plugin.json` — the `version` field.
2. `.claude-plugin/marketplace.json` — the matching plugin entry's `version` field.
3. The "Key plugins" table row below.

Pick the tier by the size of the change, not by which file was touched:

- **Patch (`0.0.1`)** — bug fixes, wording tweaks, small edits to an existing agent / skill / command / hook body, trigger-description tuning, renames that don't change how users invoke the plugin. This is the default tier for anything that modifies an artifact already on `main`.
- **Minor (`0.1.0`)** — adding *or* removing a whole artifact: a new agent file, a new skill directory, a new slash-command file, a new hook entry, or the reverse. Also applies when most of an artifact is rewritten.
- **Major (`1.0.0`)** — reserved for breaking reorganizations: renamed slash commands, renamed skills, removed public entry points. No plugin has needed one yet.

**When in doubt, pick the lower tier.** A wrong-low bump is easy to correct on the next change; a wrong-high bump wastes the version space and misrepresents the changelog.

## Key plugins

| Plugin | Version | Purpose | Primary entry points |
|---|---|---|---|
| `agency-toolkit` | 1.0.3 | Build new plugins, agents, skills, commands, hooks | `plugin-validator` agent, `agent-creator` agent, `/create-plugin` command, `/create-skill` command, `/create-agent` command, `/pin-plugins` command, `manifest-lint` skill |
| `github-toolkit` | 1.1.2 | Scaffold `.github/` metadata; branch hygiene; issue/CI workflows | `/github-scaffold` command, `branch-warden` agent, `issue-filer` agent |
| `instruction-management` | 1.5.2 | Audit and maintain AGENTS.md; nudges revision on busy sessions | `instruction-management` skill (orchestrates `revise-instructions` and `restructure-instructions` sub-skills by default) |
| `hooks-toolkit` | 1.0.0 | Composable safety/hygiene hooks — force-push guard, secret scanner, manifest validators, branch nudges, dirty-tree check | hook scripts under `hooks/` |
| `ludus-toolkit` | 0.1.0 | Ludus cyber-range toolkit — CLI/range-config/environment/troubleshooting skills, bundled Ludus MCP server | 4 `ludus-*` skills, `mcp/ludus` MCP server |
| `docker-toolkit` | 0.1.0 | Build and validate Docker artifacts — multi-stage Dockerfiles, dockerizing MCP servers for the Docker MCP Gateway | `multi-stage-dockerfile` skill, `dockerize-mcp-server` skill, `dockerize-mcp-server` agent |
