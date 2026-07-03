#!/usr/bin/env bash
# Repo-wide lint for plugin.json / SKILL.md / marketplace.json manifests.
# Usage: manifest-lint.sh [path ...]   (defaults to the whole repo)
#
# Reuses the shared validators from the hooks-toolkit plugin (JSON syntax,
# required fields, kebab-case name, semver format) so there is one source of
# truth for those rules. On top of that it adds checks the per-edit hook
# can't do in isolation:
#   - name <-> directory match (plugin.json and SKILL.md)
#   - plugin.json version vs. its marketplace.json entry
#   - version bumped vs. the last committed version of the file
#   - marketplace.json "source" paths actually exist
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  echo "ERROR: not inside a git repository" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_TOOLKIT_SCRIPTS="$REPO_ROOT/plugins/hooks-toolkit/scripts"
VALIDATE_PLUGIN_JSON="$HOOKS_TOOLKIT_SCRIPTS/validate-plugin-json.sh"
VALIDATE_SKILL_FRONTMATTER="$HOOKS_TOOLKIT_SCRIPTS/validate-skill-frontmatter.sh"

shared_validators_available=true
if [ ! -x "$VALIDATE_PLUGIN_JSON" ] || [ ! -x "$VALIDATE_SKILL_FRONTMATTER" ]; then
  shared_validators_available=false
  echo "WARN: hooks-toolkit validators not found at $HOOKS_TOOLKIT_SCRIPTS — skipping shared JSON/frontmatter checks (name/dir, version-consistency, and version-bump checks below still run)" >&2
fi

errors=0
warnings=0

err() { echo "ERROR [$1]: $2" >&2; errors=$((errors + 1)); }
warn() { echo "WARN [$1]: $2" >&2; warnings=$((warnings + 1)); }

# Scope: explicit paths, or the whole repo.
if [ "$#" -gt 0 ]; then
  scan_roots=("$@")
else
  scan_roots=("$REPO_ROOT")
fi

plugin_manifests=()
skill_manifests=()
for root in "${scan_roots[@]}"; do
  while IFS= read -r -d '' f; do plugin_manifests+=("$f"); done \
    < <(find "$root" -path '*/.claude-plugin/plugin.json' -not -path '*/node_modules/*' -print0 2>/dev/null)
  while IFS= read -r -d '' f; do skill_manifests+=("$f"); done \
    < <(find "$root" -name 'SKILL.md' -not -path '*/node_modules/*' -print0 2>/dev/null)
done

marketplace_file="$REPO_ROOT/.claude-plugin/marketplace.json"

# --- version-bump helper -----------------------------------------------
# Warn if a manifest's version is unchanged from the last commit despite
# other content in the file having changed. There is no per-plugin git tag
# convention in this repo yet, so "last tag" is approximated as "last
# committed version of this file" — the closest real baseline available.
check_version_bump() {
  local file="$1" field_jq="$2"
  local rel="${file#"$REPO_ROOT"/}"
  git -C "$REPO_ROOT" cat-file -e "HEAD:$rel" 2>/dev/null || return 0 # new file, nothing to compare
  if git -C "$REPO_ROOT" diff --quiet HEAD -- "$rel" 2>/dev/null; then
    return 0 # no uncommitted changes to compare against
  fi
  local old_version new_version
  old_version=$(git -C "$REPO_ROOT" show "HEAD:$rel" 2>/dev/null | jq -r "$field_jq" 2>/dev/null)
  new_version=$(jq -r "$field_jq" "$file" 2>/dev/null)
  if [ -n "$old_version" ] && [ -n "$new_version" ] && [ "$old_version" = "$new_version" ]; then
    warn "$file" "content changed but version is still $new_version (bump it, or ignore if this is a non-release edit)"
  fi
}

# --- plugin.json checks --------------------------------------------------
for file in "${plugin_manifests[@]}"; do
  if $shared_validators_available; then
    err_file="/tmp/manifest-lint-plugin.$$.err"
    "$VALIDATE_PLUGIN_JSON" "$file" >/dev/null 2>"$err_file"
    shared_rc=$?
    if [ -s "$err_file" ]; then
      cat "$err_file" >&2
      if [ "$shared_rc" -ne 0 ]; then errors=$((errors + 1)); else warnings=$((warnings + 1)); fi
    fi
    rm -f "$err_file"
  fi

  name=$(jq -r '.name // ""' "$file" 2>/dev/null)
  version=$(jq -r '.version // ""' "$file" 2>/dev/null)
  plugin_dir="$(dirname "$(dirname "$file")")"
  dir_name="$(basename "$plugin_dir")"

  if [ -n "$name" ] && [ "$name" != "$dir_name" ]; then
    err "$file" "'name' ($name) does not match containing directory ($dir_name)"
  fi

  if [ -f "$marketplace_file" ] && [ -n "$name" ]; then
    market_version=$(jq -r --arg n "$name" '.plugins[]? | select(.name == $n) | .version // ""' "$marketplace_file" 2>/dev/null)
    if [ -n "$market_version" ] && [ -n "$version" ] && [ "$market_version" != "$version" ]; then
      err "$file" "version ($version) does not match marketplace.json entry for '$name' ($market_version)"
    fi
  fi

  check_version_bump "$file" '.version // ""'
done

# --- SKILL.md checks -------------------------------------------------------
for file in "${skill_manifests[@]}"; do
  if $shared_validators_available; then
    err_file="/tmp/manifest-lint-skill.$$.err"
    "$VALIDATE_SKILL_FRONTMATTER" "$file" >/dev/null 2>"$err_file"
    shared_rc=$?
    if [ -s "$err_file" ]; then
      cat "$err_file" >&2
      if [ "$shared_rc" -ne 0 ]; then errors=$((errors + 1)); else warnings=$((warnings + 1)); fi
    fi
    rm -f "$err_file"
  fi

  frontmatter=$(awk '/^---$/{c++; if(c==2) exit} c==1{print}' "$file")
  name=$(echo "$frontmatter" | grep -E '^name:' | sed 's/^name:[[:space:]]*//' | tr -d '"' || true)
  dir_name="$(basename "$(dirname "$file")")"

  if [ -n "$name" ] && [ "$name" != "$dir_name" ]; then
    err "$file" "'name' ($name) does not match containing directory ($dir_name)"
  fi
done

# --- marketplace.json checks -----------------------------------------------
if [ -f "$marketplace_file" ]; then
  if $shared_validators_available; then
    err_file="/tmp/manifest-lint-market.$$.err"
    "$VALIDATE_PLUGIN_JSON" "$marketplace_file" >/dev/null 2>"$err_file"
    shared_rc=$?
    if [ -s "$err_file" ]; then
      cat "$err_file" >&2
      if [ "$shared_rc" -ne 0 ]; then errors=$((errors + 1)); else warnings=$((warnings + 1)); fi
    fi
    rm -f "$err_file"
  fi

  while IFS=$'\t' read -r entry_name entry_source; do
    [ -z "$entry_name" ] && continue
    if [ ! -e "$REPO_ROOT/${entry_source#./}" ]; then
      err "$marketplace_file" "entry '$entry_name' source path does not exist: $entry_source"
    fi
  done < <(jq -r '.plugins[]? | [.name, .source] | @tsv' "$marketplace_file" 2>/dev/null)
fi

# --- summary ----------------------------------------------------------------
echo ""
echo "manifest-lint: ${#plugin_manifests[@]} plugin.json, ${#skill_manifests[@]} SKILL.md checked — $errors error(s), $warnings warning(s)"

if [ "$errors" -gt 0 ]; then
  exit 1
fi
exit 0
