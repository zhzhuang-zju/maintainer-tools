#!/usr/bin/env bash
# Generate a contributors avatar collage (contributors.png).
#
# The contributor list is fully configurable via input. You can supply it as:
#   * CLI args:       ./make-contributors-collage.sh -o out.png userA userB @userC
#   * A list file:    ./make-contributors-collage.sh -f users.txt -o out.png
#   * stdin:          printf "userA\n@userB\n" | ./make-contributors-collage.sh -o out.png
#   * A markdown table (parses '@username' tokens, preserves order):
#                     ./make-contributors-collage.sh -m karmada-v1.18.md -o out.png
#
# Avatars are downloaded from https://github.com/<username>.png on demand and
# cached locally so re-runs are fast. Image composition is done by the sibling
# PowerShell script make-contributors-collage.ps1.

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  make-contributors-collage.sh [options] [user ...]

Options:
  -o, --output FILE       Output PNG path (required).
  -f, --users-file FILE   Read usernames from FILE (one per line; '@' optional).
  -m, --markdown FILE     Parse usernames from a Markdown file (cells like '@user').
      --cols N            Avatars per row (default: 6).
      --cell-cm CM        Avatar size in cm (default: 2.5).
      --dpi N             DPI used to convert cm -> pixels (default: 300).
      --cache-dir DIR     Avatar cache directory (default: temp dir).
  -h, --help              Show this help.

Usernames may also be supplied via stdin (one per line). Sources are merged in
this order: stdin, --users-file, --markdown, positional args. Duplicates are
removed while preserving first-seen order.
EOF
}

OUTPUT=""
USERS_FILE=""
MARKDOWN_FILE=""
COLS=6
CELL_CM=2.5
DPI=300
CACHE_DIR=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)      OUTPUT="$2"; shift 2 ;;
    -f|--users-file)  USERS_FILE="$2"; shift 2 ;;
    -m|--markdown)    MARKDOWN_FILE="$2"; shift 2 ;;
    --cols)           COLS="$2"; shift 2 ;;
    --cell-cm)        CELL_CM="$2"; shift 2 ;;
    --dpi)            DPI="$2"; shift 2 ;;
    --cache-dir)      CACHE_DIR="$2"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    --)               shift; while [[ $# -gt 0 ]]; do POSITIONAL+=("$1"); shift; done ;;
    -*)               echo "Unknown option: $1" >&2; usage; exit 2 ;;
    *)                POSITIONAL+=("$1"); shift ;;
  esac
done

if [[ -z "$OUTPUT" ]]; then
  echo "ERROR: --output is required" >&2
  usage
  exit 2
fi

RAW=()

# 1) stdin (only if piped/redirected).
if [[ ! -t 0 ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    RAW+=("$line")
  done
fi

# 2) users file.
if [[ -n "$USERS_FILE" ]]; then
  if [[ ! -f "$USERS_FILE" ]]; then
    echo "ERROR: users file not found: $USERS_FILE" >&2; exit 1
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    RAW+=("$line")
  done < "$USERS_FILE"
fi

# 3) markdown file: extract '@username' tokens in document order.
if [[ -n "$MARKDOWN_FILE" ]]; then
  if [[ ! -f "$MARKDOWN_FILE" ]]; then
    echo "ERROR: markdown file not found: $MARKDOWN_FILE" >&2; exit 1
  fi
  while IFS= read -r tok; do
    RAW+=("$tok")
  done < <(grep -oE '@[A-Za-z0-9][A-Za-z0-9-]*' "$MARKDOWN_FILE" || true)
fi

# 4) positional args.
if [[ ${#POSITIONAL[@]} -gt 0 ]]; then
  for a in "${POSITIONAL[@]}"; do
    [[ -n "$a" ]] && RAW+=("$a")
  done
fi

# Normalize: trim, strip leading '@', drop empties/comments, validate, dedupe.
declare -A SEEN
USERS=()
if [[ ${#RAW[@]} -gt 0 ]]; then
  for entry in "${RAW[@]}"; do
    entry="${entry#"${entry%%[![:space:]]*}"}"
    entry="${entry%"${entry##*[![:space:]]}"}"
    [[ -z "$entry" ]] && continue
    [[ "$entry" == \#* ]] && continue
    entry="${entry#@}"
    if ! [[ "$entry" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]]; then
      continue
    fi
    if [[ -z "${SEEN[$entry]:-}" ]]; then
      SEEN[$entry]=1
      USERS+=("$entry")
    fi
  done
fi

if [[ ${#USERS[@]} -eq 0 ]]; then
  echo "ERROR: no usernames provided. Use args, --users-file, --markdown, or stdin." >&2
  exit 1
fi

echo "Contributors (${#USERS[@]}): ${USERS[*]}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS1="$SCRIPT_DIR/make-contributors-collage.ps1"
if [[ ! -f "$PS1" ]]; then
  echo "ERROR: missing helper script: $PS1" >&2
  exit 1
fi

if command -v pwsh >/dev/null 2>&1; then
  PS_EXE="pwsh"
elif command -v powershell >/dev/null 2>&1; then
  PS_EXE="powershell"
elif command -v powershell.exe >/dev/null 2>&1; then
  PS_EXE="powershell.exe"
else
  echo "ERROR: PowerShell (pwsh or powershell) not found in PATH." >&2
  exit 1
fi

to_win_path() {
  local p="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$p"
  else
    echo "$p"
  fi
}

PS1_WIN="$(to_win_path "$PS1")"
OUT_WIN="$(to_win_path "$OUTPUT")"

CACHE_ARGS=()
if [[ -n "$CACHE_DIR" ]]; then
  mkdir -p "$CACHE_DIR"
  CACHE_ARGS+=(-CacheDir "$(to_win_path "$CACHE_DIR")")
fi

# PowerShell's [string[]] parameter accepts a comma-separated list on the CLI.
USERS_CSV="$(IFS=,; echo "${USERS[*]}")"

"$PS_EXE" -NoProfile -ExecutionPolicy Bypass -File "$PS1_WIN" \
  -Users "$USERS_CSV" \
  -OutputFile "$OUT_WIN" \
  -Cols "$COLS" \
  -CellCm "$CELL_CM" \
  -Dpi "$DPI" \
  "${CACHE_ARGS[@]}"

