#!/usr/bin/env bash
# Tests for install.sh. Run: bash tests/test-install.sh
# Same checks as tests/test-install.ps1, in the same order.

# The single-quoted strings below hold literal backticks on purpose.
# shellcheck disable=SC2016
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
installer=$root/install.sh
# The installer renders a Windows path for the details file under Git Bash, MSYS, and Cygwin.
details=$root/skills/subagent-routing/SKILL.md
# shown <path>: the path the way the installer prints it.
shown() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s\n' "$1"
  fi
}
details=$(shown "$details")
passed=0
failed=0
failures=''
RC=0
OUT=''
H=''

TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/subagent-routing-test.XXXXXX")
out_dir_existed=0
if [ -d "$root/out" ]; then
  out_dir_existed=1
fi
cleanup() {
  rm -rf "$TEST_TMP"
  if [ "$out_dir_existed" -eq 0 ]; then
    rmdir "$root/out" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# run_installer <args...>: sets RC (exit code) and OUT (stdout and stderr together).
run_installer() {
  RC=0
  OUT=$("${BASH:-bash}" "$installer" "$@" 2>&1) || RC=$?
}

record_failure() {
  failed=$((failed + 1))
  failures="$failures
FAIL: $1 $OUT"
}

# assert_true <name> <command...>: passes when the command succeeds.
assert_true() {
  local name=$1
  shift
  if "$@"; then
    passed=$((passed + 1))
  else
    record_failure "$name"
  fi
}

# assert_false <name> <command...>: passes when the command fails.
assert_false() {
  local name=$1
  shift
  if "$@"; then
    record_failure "$name"
  else
    passed=$((passed + 1))
  fi
}

contains() { case $1 in *"$2"*) return 0 ;; esac; return 1; }
starts_with() { case $1 in "$2"*) return 0 ;; esac; return 1; }
matches() { [[ $1 =~ $2 ]]; }
same_bytes() { cmp -s "$1" "$2"; }
exit_is() { [ "$RC" -eq "$1" ]; }
exit_not_zero() { [ "$RC" -ne 0 ]; }
text_of() { cat "$1"; }
contains_all() {
  local text=$1 part
  shift
  for part in "$@"; do
    contains "$text" "$part" || return 1
  done
}
# starts_with_hex <file> <hex>: the file begins with these bytes.
starts_with_hex() { [ "$(head -c $((${#2} / 2)) "$1" | od -An -tx1 | tr -d ' \n')" = "$2" ]; }
ends_with_one_newline() {
  [ "$(tail -c 1 "$1" | od -An -tx1 | tr -d ' \n')" = 0a ] &&
    [ "$(tail -c 2 "$1" | od -An -tx1 | tr -d ' \n')" != 0a0a ]
}
refused_as_damaged() { [ "$RC" -ne 0 ] && matches "$OUT" damaged; }
block_count() {
  local n
  n=$(grep -c '^<!-- >>> subagent-routing' "$1" || true)
  printf '%s\n' "$n"
}
count_is() { [ "$(block_count "$1")" -eq "$2" ]; }
# The bytes of a file as one line of hex with single spaces: " 23 20 4d ...". (grep
# patterns with a CR byte do not work under Git Bash, so check line endings through
# the hex form.)
hex_of() {
  local hex
  hex=$(od -An -v -tx1 "$1" | tr -s ' \n' '  ')
  printf ' %s\n' "${hex# }"
}
# Every LF has a CR before it, and there is at least one line end.
all_crlf() {
  local hex rest
  hex=$(hex_of "$1")
  rest=${hex// 0d 0a/}
  [[ $hex == *" 0d 0a"* && $rest != *" 0a"* ]]
}
has_no_cr() {
  local hex
  hex=$(hex_of "$1")
  [[ $hex != *" 0d"* ]]
}
# mode_is_600 <file>: the file has exactly the permissions rw-------.
mode_is_600() { [ -n "$(find "$1" -prune -perm 600)" ]; }
is_absolute() { case $1 in /* | [A-Za-z]:[\\/]*) return 0 ;; esac; return 1; }
# block_gone <file>: the file is missing or has no block.
block_gone() { [ ! -e "$1" ] || [ "$(block_count "$1")" -eq 0 ]; }

home_n=0
# new_home: sets H to a new empty temp home. The name has a space on purpose.
new_home() {
  home_n=$((home_n + 1))
  H="$TEST_TMP/home $home_n"
  mkdir "$H"
}

# 1. No agent selected.
run_installer
assert_true 'no agent exits 1' exit_is 1

# 2. Fresh install with tiers.
new_home
run_installer --claude --codex --light haiku --standard sonnet --strong opus --home "$H"
claude_file=$H/.claude/CLAUDE.md
codex_file=$H/.codex/AGENTS.md
assert_true 'fresh install exits 0' exit_is 0
assert_true 'claude file created' test -f "$claude_file"
assert_true 'codex file created' test -f "$codex_file"
text=$(text_of "$claude_file")
assert_true 'one block' count_is "$claude_file" 1
assert_true 'tiers rendered' contains_all "$text" '- Light: `haiku`' '- Standard: `sonnet`' '- Strong: `opus`'
assert_true 'details path rendered' contains "$text" "$details"
assert_true 'details path is absolute' is_absolute "$details"
assert_false 'no template tokens' contains "$text" '{{'
assert_false 'no BOM on new file' starts_with_hex "$claude_file" ef

# 3. Running again changes nothing.
run_installer --claude --light haiku --standard sonnet --strong opus --home "$H"
assert_true 'rerun up to date' matches "$OUT" 'already up to date'

# 4. Changing a tier replaces the block in place.
run_installer --claude --light haiku --standard sonnet --strong 'claude-opus-5-5[effort=high]' --home "$H"
text=$(text_of "$claude_file")
assert_true 'tier change keeps one block' count_is "$claude_file" 1
assert_true 'tier change applied' contains "$text" '- Strong: `claude-opus-5-5[effort=high]`'
assert_false 'old tier gone' contains "$text" '- Strong: `opus`'
assert_true 'backup written' test -f "$claude_file.subagent-routing.bak"

# 5. Uninstall removes a file that held only the block.
run_installer --claude --codex --uninstall --home "$H"
assert_true 'uninstall exits 0' exit_is 0
assert_false 'block-only file removed' test -e "$claude_file"
assert_false 'uninstall skips a missing override file' contains "$OUT" 'AGENTS.override.md'

# 6. Existing content, CRLF and BOM are kept; uninstall restores the original bytes.
new_home
mkdir "$H/.claude" "$H/.codex"
claude_file=$H/.claude/CLAUDE.md
codex_file=$H/.codex/AGENTS.md
printf '# Mine\nkeep this line\n' >"$claude_file"
printf '\357\273\277# Codex rules\r\nkeep\r\n' >"$codex_file"
cp "$claude_file" "$H/claude.before"
cp "$codex_file" "$H/codex.before"
run_installer --claude --codex --home "$H"
text=$(text_of "$claude_file")
assert_true 'existing content kept' starts_with "$text" $'# Mine\nkeep this line\n\n<!-- >>> subagent-routing'
assert_true 'placeholders without tiers' contains_all "$text" '- Light: `<light-model>`' '- Strong: `<strong-model>`'
assert_true 'placeholder notice printed' matches "$OUT" 'Placeholders left for: light, standard, strong'
assert_true 'BOM kept' starts_with_hex "$codex_file" efbbbf
assert_true 'CRLF kept' all_crlf "$codex_file"
assert_true 'LF file stays LF' has_no_cr "$claude_file"
run_installer --claude --codex --uninstall --home "$H"
assert_true 'uninstall restores LF file' same_bytes "$claude_file" "$H/claude.before"
assert_true 'uninstall restores CRLF BOM file' same_bytes "$codex_file" "$H/codex.before"

# 6b. A symbolic link (for example into a dotfiles repository) stays a link, and the
# file behind it gets the change. Skipped where ln -s does not make a real link
# (Git Bash without MSYS=winsymlinks).
new_home
mkdir "$H/.claude" "$H/dotfiles"
printf '# Linked\n' >"$H/dotfiles/claude.md"
if ln -s "$H/dotfiles/claude.md" "$H/.claude/CLAUDE.md" 2>/dev/null && [ -L "$H/.claude/CLAUDE.md" ]; then
  cp "$H/dotfiles/claude.md" "$H/linked.before"
  run_installer --claude --home "$H"
  assert_true 'symlink stays a symlink' test -L "$H/.claude/CLAUDE.md"
  assert_true 'symlink target gets the block' count_is "$H/dotfiles/claude.md" 1
  run_installer --claude --uninstall --home "$H"
  assert_true 'symlink target restored' same_bytes "$H/dotfiles/claude.md" "$H/linked.before"
fi

# 6b2. A link whose file held only the block: uninstall keeps the link and empties the
# file behind it (deleting the link would leave the block in the file). Both a missing
# and an empty file behind the link are tried. Skipped like 6b.
for variant in missing empty; do
  new_home
  mkdir "$H/.claude" "$H/dotfiles"
  if [ "$variant" = empty ]; then
    : >"$H/dotfiles/claude.md"
  fi
  if ln -s "$H/dotfiles/claude.md" "$H/.claude/CLAUDE.md" 2>/dev/null && [ -L "$H/.claude/CLAUDE.md" ]; then
    run_installer --claude --home "$H"
    assert_true "block-only link ($variant file): install writes through the link" count_is "$H/dotfiles/claude.md" 1
    run_installer --claude --uninstall --home "$H"
    assert_true "block-only link ($variant file): uninstall exits 0" exit_is 0
    assert_true "block-only link ($variant file): link stays" test -L "$H/.claude/CLAUDE.md"
    assert_true "block-only link ($variant file): file behind it stays" test -f "$H/dotfiles/claude.md"
    assert_false "block-only link ($variant file): marker gone" contains "$(text_of "$H/dotfiles/claude.md")" 'subagent-routing'
    assert_true "block-only link ($variant file): file is empty" test ! -s "$H/dotfiles/claude.md"
    assert_true "block-only link ($variant file): reported as removed" contains "$OUT" "Claude Code: removed - $(shown "$H/.claude/CLAUDE.md")"
  else
    echo 'note: skipped the block-only symlink uninstall test (no native symlinks; try MSYS=winsymlinks:nativestrict)'
    break
  fi
done

# 6c. The permissions of an existing file stay the same. Skipped where chmod has no effect.
new_home
mkdir "$H/.claude"
printf '# Private\n' >"$H/.claude/CLAUDE.md"
chmod 600 "$H/.claude/CLAUDE.md"
if mode_is_600 "$H/.claude/CLAUDE.md"; then
  run_installer --claude --home "$H"
  assert_true 'permissions kept' mode_is_600 "$H/.claude/CLAUDE.md"
fi

# 7. A non-empty AGENTS.override.md receives the block instead of AGENTS.md.
new_home
mkdir "$H/.codex"
override=$H/.codex/AGENTS.override.md
printf 'override\n' >"$override"
run_installer --codex --home "$H"
assert_true 'override receives block' count_is "$override" 1
assert_false 'AGENTS.md left alone' test -e "$H/.codex/AGENTS.md"
assert_false 'no warning without a block in AGENTS.md' contains "$OUT" 'warning'

# 7b. Uninstall cleans AGENTS.md and a non-empty AGENTS.override.md that came later.
new_home
mkdir "$H/.codex"
agents_md=$H/.codex/AGENTS.md
override=$H/.codex/AGENTS.override.md
run_installer --codex --home "$H"
assert_true 'block went into AGENTS.md' count_is "$agents_md" 1
printf 'override\n' >"$override"
cp "$override" "$H/override.before"
run_installer --codex --uninstall --home "$H"
assert_true 'codex uninstall exits 0' exit_is 0
assert_true 'AGENTS.md block removed' block_gone "$agents_md"
assert_true 'output names AGENTS.md' contains "$OUT" "Codex: removed (the file held only this block; backup kept) - $(shown "$agents_md")"
assert_true 'output names the override' contains "$OUT" "Codex: not installed - $(shown "$override")"
assert_true 'override without a block left alone' same_bytes "$override" "$H/override.before"

# 7c. A block in AGENTS.md is ignored by Codex once a non-empty override exists: install
# warns, writes into the override, and uninstall then removes both blocks.
new_home
mkdir "$H/.codex"
agents_md=$H/.codex/AGENTS.md
override=$H/.codex/AGENTS.override.md
printf '# Mine\n' >"$agents_md"
cp "$agents_md" "$H/agents.before"
run_installer --codex --home "$H"
assert_true 'block went into AGENTS.md first' count_is "$agents_md" 1
assert_false 'no warning when AGENTS.md is the target' contains "$OUT" 'warning'
printf 'override\n' >"$override"
cp "$override" "$H/override.before"
run_installer --codex --home "$H"
assert_true 'install with override exits 0' exit_is 0
assert_true 'warning printed' contains "$OUT" 'still has a subagent-routing block'
assert_true 'warning names AGENTS.md' contains "$OUT" "Codex: warning - $(shown "$agents_md") still has a subagent-routing block."
assert_true 'warning says what to do' contains "$OUT" 'Run with --uninstall --codex to remove both blocks, then install again.'
assert_true 'block written into the override' count_is "$override" 1
assert_true 'AGENTS.md block untouched' count_is "$agents_md" 1
run_installer --codex --uninstall --home "$H"
assert_true 'uninstall restores AGENTS.md' same_bytes "$agents_md" "$H/agents.before"
assert_true 'uninstall restores the override' same_bytes "$override" "$H/override.before"
run_installer --codex --home "$H"
assert_false 'no warning after both blocks are gone' contains "$OUT" 'warning'

# 8. Invalid model name is refused and nothing is written.
new_home
run_installer --claude --light 'bad`name' --home "$H"
assert_true 'invalid model refused' exit_not_zero
assert_false 'invalid model writes nothing' test -e "$H/.claude/CLAUDE.md"
assert_false 'invalid model creates no directory' test -e "$H/.claude"

# 8b. A trailing newline makes a model name invalid, whichever tier it is for.
for tier in light standard strong; do
  run_installer --claude "--$tier" $'haiku\n' --home "$H"
  assert_true "$tier model with trailing newline refused" exit_not_zero
  assert_true "$tier model with trailing newline named in the error" contains "$OUT" "Invalid $tier model"
  assert_false "$tier model with trailing newline writes nothing" test -e "$H/.claude/CLAUDE.md"
  assert_false "$tier model with trailing newline creates no directory" test -e "$H/.claude"
done

# 9. A damaged block stops the installer and leaves the file unchanged.
mkdir "$H/.claude"
damaged=$H/.claude/CLAUDE.md
printf 'a\n<!-- >>> subagent-routing v0 -->\nhalf\n' >"$damaged"
cp "$damaged" "$H/damaged.before"
run_installer --claude --home "$H"
assert_true 'damaged block refused' refused_as_damaged
assert_true 'damaged file unchanged' same_bytes "$damaged" "$H/damaged.before"
# Repeated and out-of-order markers are damaged too.
printf '<!-- >>> subagent-routing v0 -->\nx\n<!-- <<< subagent-routing -->\n<!-- >>> subagent-routing v0 -->\ny\n<!-- <<< subagent-routing -->\n' >"$damaged"
cp "$damaged" "$H/damaged.before"
run_installer --claude --home "$H"
assert_true 'repeated markers refused' refused_as_damaged
assert_true 'repeated markers file unchanged' same_bytes "$damaged" "$H/damaged.before"
printf '<!-- <<< subagent-routing -->\nx\n<!-- >>> subagent-routing v0 -->\n' >"$damaged"
cp "$damaged" "$H/damaged.before"
run_installer --claude --uninstall --home "$H"
assert_true 'out-of-order markers refused' refused_as_damaged
assert_true 'out-of-order markers file unchanged' same_bytes "$damaged" "$H/damaged.before"

# 10. Cursor output has the rule without markers.
cursor_file=$root/out/cursor-rule.md
run_installer --cursor --no-clipboard --light claude-haiku-5-5 --home "$H"
cursor_text=$(text_of "$cursor_file")
assert_true 'cursor rule written' starts_with "$cursor_text" '# Subagent routing'
assert_true 'cursor rule has the light model' contains "$cursor_text" '- Light: `claude-haiku-5-5`'
assert_true 'cursor rule has no markers' count_is "$cursor_file" 0
assert_true 'cursor rule ends with one newline' ends_with_one_newline "$cursor_file"
run_installer --cursor --uninstall --home "$H"
assert_false 'cursor uninstall removes output' test -e "$cursor_file"

echo "passed: $passed, failed: $failed"
if [ "$failed" -gt 0 ]; then
  printf '%s\n' "$failures"
  exit 1
fi
