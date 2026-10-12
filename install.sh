#!/usr/bin/env bash
# Install the subagent-routing rule for Cursor, Claude Code, and Codex.
# Bash port of install.ps1. It runs on macOS (bash 3.2), Linux, and Git Bash.
#
# Renders rules/subagent-routing.md with your tier models and the absolute path of
# the details file, then:
#   --cursor  writes out/cursor-rule.md and copies it to the clipboard. Cursor keeps
#             User Rules in its settings, so you paste the rule there yourself.
#   --claude  writes a marked block into CLAUDE.md in the Claude Code config directory
#             ($CLAUDE_CONFIG_DIR or ~/.claude).
#   --codex   writes a marked block into AGENTS.md (or a non-empty AGENTS.override.md)
#             in the Codex home directory ($CODEX_HOME or ~/.codex).
# Run it again to change tiers; it replaces only its own block. --uninstall removes
# the blocks (for Codex, from both AGENTS.md and AGENTS.override.md). A backup of each
# changed file is kept as <file>.subagent-routing.bak. Text outside the block keeps its
# bytes, line endings (also a mix of CRLF and LF) and BOM. If the file did not end with
# a newline, install adds one and says so in the begin marker; uninstall removes it.
#
# Example:
#   ./install.sh --claude --light haiku --standard sonnet --strong opus
#
# Options:
#   --cursor --claude --codex          select the agents (at least one)
#   --light M --standard M --strong M  model for each tier (left out: placeholder)
#   --uninstall                        remove what a previous run installed
#   --no-clipboard                     with --cursor: do not copy to the clipboard
#   --home DIR                         for tests: use DIR as the home directory and
#                                      ignore CLAUDE_CONFIG_DIR and CODEX_HOME
#   -h, --help                         show this help

set -euo pipefail

begin_prefix='<!-- >>> subagent-routing'
end_prefix='<!-- <<< subagent-routing'
root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

WORK=''
TMP_TARGET=''
RESULT=''

cleanup() {
  if [ -n "$TMP_TARGET" ]; then
    rm -f "$TMP_TARGET"
  fi
  if [ -n "$WORK" ]; then
    rm -rf "$WORK"
  fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

usage() {
  echo 'Usage: ./install.sh [--cursor] [--claude] [--codex] [--light <model>] [--standard <model>] [--strong <model>] [--uninstall] [--no-clipboard]'
  echo 'Select at least one agent. Tiers you leave out stay as placeholders.'
}

help_text() {
  usage
  cat <<'HELP'

  --cursor                   write out/cursor-rule.md and copy it to the clipboard
  --claude                   write a block into CLAUDE.md ($CLAUDE_CONFIG_DIR or ~/.claude)
  --codex                    write a block into AGENTS.md or a non-empty
                             AGENTS.override.md ($CODEX_HOME or ~/.codex)
  --light M --standard M --strong M
                             model for each tier (left out: placeholder)
  --uninstall                remove what a previous run installed
  --no-clipboard             with --cursor: do not copy to the clipboard
  --home DIR                 for tests: use DIR as the home directory and ignore
                             CLAUDE_CONFIG_DIR and CODEX_HOME
  -h, --help                 show this help

Run it again to change tiers; it replaces only its own block. A backup of each
changed file is kept as <file>.subagent-routing.bak.
Example: ./install.sh --claude --light haiku --standard sonnet --strong opus
HELP
}

# Under Git Bash, MSYS, and Cygwin, show and render Windows paths so that Windows
# agents can open them. Elsewhere the path stays as it is.
display_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s\n' "$1"
  fi
}

cursor=0
claude=0
codex=0
uninstall=0
no_clipboard=0
light=''
standard=''
strong=''
home_override=''

while [ $# -gt 0 ]; do
  case $1 in
    --cursor) cursor=1 ;;
    --claude) claude=1 ;;
    --codex) codex=1 ;;
    --uninstall) uninstall=1 ;;
    --no-clipboard) no_clipboard=1 ;;
    --light | --standard | --strong | --home)
      if [ $# -lt 2 ]; then
        printf 'Option %s needs a value.\n' "$1" >&2
        usage >&2
        exit 2
      fi
      case $1 in
        --light) light=$2 ;;
        --standard) standard=$2 ;;
        --strong) strong=$2 ;;
        --home) home_override=$2 ;;
      esac
      shift
      ;;
    -h | --help)
      help_text
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ "$cursor" -eq 0 ] && [ "$claude" -eq 0 ] && [ "$codex" -eq 0 ]; then
  usage >&2
  exit 1
fi

# Model ids and Cursor-style parameters such as name[effort=high]; nothing that can
# break the rule text. Same set as ^[A-Za-z0-9._:/=,+\[\]-]+$ (listed letter by
# letter so that the result does not depend on the locale).
check_model() {
  case $2 in
    *[!]ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._:/=,+[-]*)
      die "Invalid $1 model '$2'. Use the model id only, for example claude-sonnet-5-5 or sonnet."
      ;;
  esac
}
check_model light "$light"
check_model standard "$standard"
check_model strong "$strong"

if [ -f "$root/VERSION" ]; then
  version=''
  IFS= read -r version <"$root/VERSION" || true
  version=${version%$'\r'}
  version=${version#"${version%%[![:space:]]*}"}
  version=${version%"${version##*[![:space:]]}"}
else
  die "VERSION file not found in $root."
fi

if [ -n "$home_override" ]; then
  claude_dir=$home_override/.claude
  codex_dir=$home_override/.codex
else
  claude_dir=${CLAUDE_CONFIG_DIR:-}
  codex_dir=${CODEX_HOME:-}
  if [ -z "$claude_dir" ] || [ -z "$codex_dir" ]; then
    [ -n "${HOME:-}" ] || die 'HOME is not set. Use --home <dir>.'
    [ -n "$claude_dir" ] || claude_dir=$HOME/.claude
    [ -n "$codex_dir" ] || codex_dir=$HOME/.codex
  fi
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/subagent-routing.XXXXXX")

# Replace every occurrence of $2 in $1 with $3. The result is in REPLACED.
# Plain string splitting: no pattern or '&' handling in the replacement text.
replace_all() {
  local rest=$1 out=''
  while [[ $rest == *"$2"* ]]; do
    out=$out${rest%%"$2"*}$3
    rest=${rest#*"$2"}
  done
  REPLACED=$out$rest
}

# Render the rule template. The result is in BODY.
render_rule() {
  local template_file=$root/rules/subagent-routing.md
  local details_file=$root/skills/subagent-routing/SKILL.md
  local template details light_value standard_value strong_value
  [ -f "$template_file" ] || die "Rule template not found: $template_file"
  [ -f "$details_file" ] || die "Details file not found: $details_file"
  details=$(display_path "$details_file")
  light_value=${light:-<light-model>}
  standard_value=${standard:-<standard-model>}
  strong_value=${strong:-<strong-model>}
  template=$(cat "$template_file")
  replace_all "$template" '{{LIGHT_MODEL}}' "$light_value"
  replace_all "$REPLACED" '{{STANDARD_MODEL}}' "$standard_value"
  replace_all "$REPLACED" '{{STRONG_MODEL}}' "$strong_value"
  replace_all "$REPLACED" '{{DETAILS_PATH}}' "$details"
  BODY=$REPLACED
  while [[ $BODY == *$'\n' || $BODY == *$'\r' ]]; do
    BODY=${BODY%?}
  done
}

# Follow symbolic links so that a linked CLAUDE.md (for example from a dotfiles
# repository) keeps being a link and the real file gets the change.
resolve_link() {
  local path=$1 target count=0
  while [ -L "$path" ] && [ "$count" -lt 40 ]; do
    target=$(readlink "$path")
    case $target in
      /*) path=$target ;;
      *) path=${path%/*}/$target ;;
    esac
    count=$((count + 1))
  done
  printf '%s\n' "$path"
}

first_bytes() {
  head -c "$2" "$1" | od -An -tx1 | tr -d ' \n'
}

# has_block <path>: the file exists and has a line that starts with the begin marker.
# grep runs without -q so that it reads all input (no SIGPIPE under pipefail).
has_block() {
  [ -f "$1" ] || return 1
  if [ "$(first_bytes "$1" 3)" = 'efbbbf' ]; then
    tail -c +4 "$1" | grep "^$begin_prefix" >/dev/null
  else
    grep "^$begin_prefix" "$1" >/dev/null
  fi
}

cat >"$WORK/edit.awk" <<'AWK'
# Reads the block file (begin line, the same begin line with the "added a final
# newline" flag, rule body, end line), then the current text of the target file.
# Writes the new text to stdout.
#
# Every line of the target keeps its own terminator: CRLF, LF, or none (only the last
# line can lack one; endsnl says whether the text ends with LF). A lone CR is content.
# Lines that the script adds end with nl: CRLF if the text has any CRLF, else LF.
# When install has to give the last line a terminator, it uses the flagged begin
# marker, so that uninstall can take the terminator away again.
# Exit status: 0 ok, 3 damaged markers, 4 nothing to remove.
FNR == NR {
    sub(/\r$/, "")
    nb++
    if (nb == 1) {
        begin_plain = $0
    } else if (nb == 2) {
        begin_flagged = $0
    } else {
        blk[nb - 2] = $0
    }
    next
}
{
    rec[++n] = $0
}
END {
    nblk = nb - 2
    crlf = 0
    for (i = 1; i <= n; i++) {
        if (i < n || endsnl == 1) {
            line = rec[i]
            if (sub(/\r$/, "", line)) {
                crlf = 1
                rec[i] = line
                term[i] = "\r\n"
            } else {
                term[i] = "\n"
            }
        } else {
            term[i] = ""
        }
    }

    nbeg = 0
    nend = 0
    for (i = 1; i <= n; i++) {
        if (index(rec[i], bp) == 1) {
            bidx[++nbeg] = i
        }
        if (index(rec[i], ep) == 1) {
            eidx[++nend] = i
        }
    }
    if (nbeg > 1 || nend > 1 || nbeg != nend || (nbeg == 1 && eidx[1] < bidx[1])) {
        exit 3
    }

    nl = crlf ? "\r\n" : "\n"
    flagged = 0
    if (nbeg == 1 && index(rec[bidx[1]], "; added a final newline)") > 0) {
        flagged = 1
    }
    if (remove == 1) {
        if (nbeg == 0) {
            exit 4
        }
        s = bidx[1]
        e = eidx[1]
        # Also remove the blank line that the installer put before the block.
        if (s > 1 && rec[s - 1] == "") {
            s--
        }
        # Install added a terminator to the last line: take it away again, but only
        # if the block is still at the end (text after it must not merge with the line).
        if (flagged && e == n && s > 1) {
            term[s - 1] = ""
        }
        for (i = 1; i < s; i++) put(i)
        for (i = e + 1; i <= n; i++) put(i)
    } else if (nbeg == 1) {
        for (i = 1; i < bidx[1]; i++) put(i)
        put_block()
        for (i = eidx[1] + 1; i <= n; i++) put(i)
    } else {
        if (n > 0 && term[n] == "") {
            # An added LF after a final CR would read back as CRLF; add CRLF so that the
            # next run finds the same lines.
            if (rec[n] ~ /\r$/) {
                nl = "\r\n"
            }
            term[n] = nl
            flagged = 1
        }
        for (i = 1; i <= n; i++) put(i)
        if (n > 0) printf "%s", nl
        put_block()
    }
}
function put(i) {
    printf "%s%s", rec[i], term[i]
}
function put_block(   j) {
    printf "%s%s", (flagged ? begin_flagged : begin_plain), nl
    for (j = 1; j <= nblk; j++) printf "%s%s", blk[j], nl
}
AWK

# update_block <path> <remove: 0|1>. The result text is in RESULT.
update_block() {
  local path=$1 remove=$2
  local real existing=0 bom=0 endsnl=0 awk_status=0 parent tmp

  if [ -f "$path" ]; then
    existing=1
  fi
  if [ "$existing" -eq 0 ] && [ "$remove" -eq 1 ]; then
    RESULT='not installed'
    return 0
  fi

  real=$(resolve_link "$path")
  : >"$WORK/old"
  if [ "$existing" -eq 1 ]; then
    if [ "$(first_bytes "$real" 3)" = 'efbbbf' ]; then
      bom=1
      tail -c +4 "$real" >"$WORK/old"
    else
      cat "$real" >"$WORK/old"
    fi
    if [ "$(tail -c 1 "$WORK/old" | od -An -tx1 | tr -d ' \n')" = '0a' ]; then
      endsnl=1
    fi
  fi

  # The first two lines are the begin marker without and with the flag that says
  # "install gave the last line of the file a final newline".
  {
    printf '%s\n' "$begin_prefix v$version (managed by install script; run it again to change tiers) -->"
    printf '%s\n' "$begin_prefix v$version (managed by install script; run it again to change tiers; added a final newline) -->"
    printf '%s\n' "$BODY"
    printf '%s\n' "$end_prefix -->"
  } >"$WORK/block"

  # BINMODE=3 keeps gawk under Git Bash and Cygwin from dropping the CR of CRLF line
  # ends. Other awks treat it as an unused variable. LC_ALL=C makes awk read bytes, so
  # that text in any encoding comes back unchanged.
  LC_ALL=C awk -v BINMODE=3 -v bp="$begin_prefix" -v ep="$end_prefix" -v remove="$remove" -v endsnl="$endsnl" \
    -f "$WORK/edit.awk" "$WORK/block" "$WORK/old" >"$WORK/new" || awk_status=$?
  case $awk_status in
    0) ;;
    3) die "The subagent-routing block in $(display_path "$path") is damaged (unmatched or repeated markers). Fix it by hand, then run again." ;;
    4)
      RESULT='not installed'
      return 0
      ;;
    *) die "awk failed with status $awk_status while editing $(display_path "$path")." ;;
  esac

  if [ "$existing" -eq 1 ] && cmp -s "$WORK/new" "$WORK/old"; then
    RESULT='already up to date'
    return 0
  fi

  if [ "$existing" -eq 1 ]; then
    cp -f "$path" "$path.subagent-routing.bak"
  fi
  # Zero bytes left: the file held only the block (or nothing else). A file that held
  # only white space or only a BOM comes back as it was.
  if [ "$remove" -eq 1 ] && [ ! -s "$WORK/new" ] && [ "$bom" -eq 0 ]; then
    if [ -L "$path" ]; then
      # Deleting a link would leave the block in the real file behind it. Empty that
      # file instead, so that the link stays and the block is gone.
      : >"$path"
      RESULT='removed'
    else
      rm -f "$path"
      RESULT='removed (the file held only this block; backup kept)'
    fi
    return 0
  fi

  parent=${real%/*}
  if [ ! -d "$parent" ]; then
    mkdir -p "$parent"
  fi
  # Write a temporary file next to the target, then move it into place. For an
  # existing file, copy it first so that its permissions stay the same.
  tmp=$real.subagent-routing.tmp.$$
  TMP_TARGET=$tmp
  if [ "$existing" -eq 1 ]; then
    cp -p "$real" "$tmp"
  fi
  {
    if [ "$bom" -eq 1 ]; then
      printf '\357\273\277'
    fi
    cat "$WORK/new"
  } >"$tmp"
  mv -f "$tmp" "$real"
  TMP_TARGET=''

  if [ "$remove" -eq 1 ]; then
    RESULT='removed'
  elif [ "$existing" -eq 1 ]; then
    RESULT='installed'
  else
    RESULT='installed (new file)'
  fi
}

# clip_with <text> <command> [args...]: pipe the text into a clipboard command.
clip_with() {
  local text=$1
  shift
  command -v "$1" >/dev/null 2>&1 || return 1
  printf '%s' "$text" | "$@" >/dev/null 2>&1
}

copy_to_clipboard() {
  clip_with "$1" pbcopy ||
    clip_with "$1" wl-copy ||
    clip_with "$1" xclip -selection clipboard ||
    clip_with "$1" xsel --clipboard --input ||
    clip_with "$1" clip.exe
}

render_rule

placeholders=''
add_placeholder() {
  if [ -n "$placeholders" ]; then
    placeholders="$placeholders, $1"
  else
    placeholders=$1
  fi
}
[ -n "$light" ] || add_placeholder light
[ -n "$standard" ] || add_placeholder standard
[ -n "$strong" ] || add_placeholder strong

if [ "$claude" -eq 1 ]; then
  target=$claude_dir/CLAUDE.md
  update_block "$target" "$uninstall"
  echo "Claude Code: $RESULT - $(display_path "$target")"
fi

if [ "$codex" -eq 1 ]; then
  agents_md=$codex_dir/AGENTS.md
  override=$codex_dir/AGENTS.override.md
  if [ "$uninstall" -eq 1 ]; then
    # An earlier run may have written to either file, so clean both.
    update_block "$agents_md" 1
    echo "Codex: $RESULT - $(display_path "$agents_md")"
    if [ -f "$override" ]; then
      update_block "$override" 1
      echo "Codex: $RESULT - $(display_path "$override")"
    fi
  else
    target=$agents_md
    if [ -f "$override" ] && [ -s "$override" ]; then
      # Codex reads only the override file when it is not empty.
      target=$override
    fi
    update_block "$target" 0
    echo "Codex: $RESULT - $(display_path "$target")"
    if [ "$target" = "$override" ] && has_block "$agents_md"; then
      echo "Codex: warning - $(display_path "$agents_md") still has a subagent-routing block. Codex ignores it while AGENTS.override.md is not empty. Run with --uninstall --codex to remove both blocks, then install again."
    fi
  fi
fi

if [ "$cursor" -eq 1 ]; then
  out_dir=$root/out
  out_file=$out_dir/cursor-rule.md
  out_display=$(display_path "$out_file")
  if [ "$uninstall" -eq 1 ]; then
    rm -f "$out_file"
    echo 'Cursor: remove the User Rule titled subagent-routing in Cursor Settings > Rules.'
  else
    mkdir -p "$out_dir"
    TMP_TARGET=$out_file.tmp.$$
    printf '%s\n' "$BODY" >"$TMP_TARGET"
    mv -f "$TMP_TARGET" "$out_file"
    TMP_TARGET=''
    copied=0
    if [ "$no_clipboard" -eq 0 ] && copy_to_clipboard "$BODY"; then
      copied=1
    fi
    where=$out_display
    if [ "$copied" -eq 1 ]; then
      where="$out_display and on the clipboard"
    fi
    echo "Cursor: the rule is in $where."
    echo '  Add it in Cursor Settings > Rules > User Rules with the title subagent-routing (replace the old one if it exists),'
    echo "  or ask a Cursor agent: Add the content of $out_display as a user rule titled subagent-routing."
  fi
fi

if [ "$uninstall" -eq 0 ]; then
  if [ -n "$placeholders" ]; then
    echo "Placeholders left for: $placeholders. Run again with --light, --standard, --strong to fill them."
  fi
  echo 'Start a new chat or session so that the agent loads the rule. To update, run git pull and this script again.'
fi
