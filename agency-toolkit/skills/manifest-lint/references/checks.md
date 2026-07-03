# manifest-lint checks

## Reused from hooks-toolkit (shared source of truth)

Run via `plugins/hooks-toolkit/scripts/validate-plugin-json.sh` and `validate-skill-frontmatter.sh`. If you need to change these rules, change them there — both the `PostToolUse` hook and this skill call the same script.

- Valid JSON (`plugin.json`, `marketplace.json`) / presence of `---` frontmatter delimiters (`SKILL.md`).
- Required fields: `name` + `description` on plugin manifests; `name` + `plugins[]` on `marketplace.json`; `name` + `description` in SKILL.md frontmatter.
- `name` must be kebab-case.
- `version`, if present, should look like semver (`X.Y.Z`) — warning only, doesn't fail.
- SKILL.md over 500 lines — warning, move detail into `references/`.

## New in manifest-lint (repo-wide only)

### name ↔ directory match

- `plugin.json`: `name` must equal the directory containing `.claude-plugin/` (e.g. `plugins/hooks-toolkit/.claude-plugin/plugin.json` → name must be `hooks-toolkit`).
- `SKILL.md`: `name` must equal its parent directory (e.g. `skills/crisp-response/SKILL.md` → name must be `crisp-response`).
- Deliberately scoped to `*/.claude-plugin/plugin.json` only — `.github/plugin/plugin.json` files (used by some forked plugins for a GitHub App manifest) are a different mechanism and excluded.
- Fix: rename the directory or the `name` field, whichever is correct.

### plugin.json ↔ marketplace.json version consistency

- For each `plugin.json`, look up the matching entry in `.claude-plugin/marketplace.json` by `name` and compare `version`.
- Fix: bump whichever one is stale so both agree.

### version bump vs. last commit

- There's no per-plugin git tag convention in this repo (`git tag` currently returns nothing), so "bumped since last release" can't be checked against a tag. Instead: if a manifest file has uncommitted changes AND its `version` field is identical to the version at `HEAD` for that file, warn.
- This only catches the "I edited a plugin.json / SKILL.md right now and forgot to bump" case — it says nothing about releases that already landed.
- If this repo adopts a tagging convention later (e.g. `<plugin-name>@X.Y.Z`, as hinted at in `skills/make-a-monorepo/SKILL.md`), update `check_version_bump()` in `scripts/manifest-lint.sh` to prefer `git describe --match "<plugin-name>@*"` over the `HEAD` comparison.
- Not a false-positive risk for intentional non-release edits (typo fixes, wording tweaks) — it's a warning, not an error, and won't fail the run.

### marketplace.json source paths exist

- Each `plugins[].source` must resolve to an existing path relative to the repo root.
- Fix: correct the path, or remove the stale entry if the plugin was deleted.
