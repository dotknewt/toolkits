---
name: manifest-lint
description: On-demand repo-wide lint for plugin.json, SKILL.md, and marketplace.json manifests — checks required fields, kebab-case naming, name-to-directory match, semver format, plugin.json/marketplace.json version consistency, and whether a manifest's version was bumped after a content edit. Invoke explicitly (e.g. "run manifest-lint", "/manifest-lint") — this skill does not auto-trigger.
version: 0.1.0
disable-model-invocation: true
---

# Manifest Lint

Validates every `plugin.json`, `SKILL.md`, and `marketplace.json` in the repo in one pass. Built because this repo carries ~25+ hand-rolled manifest files and the same class of bug (name/directory drift, stale versions) keeps slipping in.

## Relationship to hooks-toolkit

The `hooks-toolkit` plugin already validates manifests via `PostToolUse(Write|Edit)` hooks — but only the one file you just touched, and only at edit time. This skill reuses those exact same validators (`plugins/hooks-toolkit/scripts/validate-plugin-json.sh` and `validate-skill-frontmatter.sh`) as the source of truth for JSON syntax, required fields, kebab-case names, and semver format, so the rules never drift between the two. On top of that shared base, it adds checks that only make sense with a whole-repo view:

- **name ↔ directory match** — a `plugin.json`'s `name` field vs. the directory it lives in; a `SKILL.md`'s `name` field vs. its parent directory. (Neither the hook nor the `plugin-validator` agent currently checks this.)
- **plugin.json ↔ marketplace.json version consistency** — flags when a plugin's manifest version and its `marketplace.json` registry entry have drifted apart.
- **version bump vs. last commit** — warns when a manifest's content changed but its `version` field didn't. There's no per-plugin git tag convention in this repo yet, so "last tag" is approximated as the version at `HEAD` for that file — the closest real baseline available. See `references/checks.md` for the exact semantics and how to extend this once/if a tagging convention exists.
- **marketplace.json source paths exist** — each `plugins[].source` entry actually resolves to a path in the repo.

## Usage

The script resolves the repo root itself via `git rev-parse --show-toplevel`, so invoke it by that root rather than relying on `${CLAUDE_PLUGIN_ROOT}` being set in the Bash tool's shell (that variable is only guaranteed inside hook/command subprocesses, not an arbitrary Bash call the model makes while running a skill):

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
bash "$REPO_ROOT/plugins/agency-toolkit/skills/manifest-lint/scripts/manifest-lint.sh"                     # whole repo
bash "$REPO_ROOT/plugins/agency-toolkit/skills/manifest-lint/scripts/manifest-lint.sh" plugins/some-plugin # scoped
```

Errors go to stderr as `ERROR [file]: message`, non-fatal issues as `WARN [file]: message`, followed by a one-line summary. Exit code is `1` if any `ERROR` was found, `0` otherwise (warnings alone don't fail the run).

If `hooks-toolkit`'s scripts aren't found at `plugins/hooks-toolkit/scripts/`, the shared checks are skipped with a warning — the new repo-wide checks still run.

See `references/checks.md` for the full list of checks and how to fix each one.
