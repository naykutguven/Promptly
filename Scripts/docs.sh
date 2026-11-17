#!/bin/bash
set -euo pipefail

repository_root="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

help() {
    cat <<'EOF'
Usage: ./Scripts/docs.sh COMMAND

Commands:
  install     Install lychee with Homebrew if it is missing.
  lint-links  Check relative links and heading anchors in tracked and untracked,
              non-ignored Markdown files. External URLs are not checked.
  help        Show this help.

A command is required. This script is for local validation; CI does not run it.
EOF
}

install_lychee() {
    if command -v lychee > /dev/null 2>&1; then
        printf '%s is already installed.\n' "$(lychee --version)"
        return
    fi
    command -v brew > /dev/null 2>&1 ||
        fail "Homebrew is missing. Install it from https://brew.sh, or put lychee on PATH."
    brew install lychee
}

lint_links() {
    command -v lychee > /dev/null 2>&1 || fail "lychee is missing. Run ./Scripts/docs.sh install."
    local file
    local files=()
    while IFS= read -r -d '' file; do
        # Skip index entries whose files were deleted but not yet staged.
        [[ -f "$file" ]] && files+=("$file")
    done < <(git ls-files --cached --others --exclude-standard -z -- '*.md')
    [[ ${#files[@]} -gt 0 ]] || fail "No Markdown files found."
    lychee --offline --include-fragments --no-progress --root-dir "$repository_root" "${files[@]}"
}

[[ $# -le 1 ]] || fail "Expected one command; got $#. Run ./Scripts/docs.sh help to list commands."
# An empty or blank argument, such as an unset variable, is a missing command.
[[ $# -eq 1 && -n "${1//[[:space:]]/}" ]] ||
    fail "Missing command. Usage: ./Scripts/docs.sh COMMAND. Run ./Scripts/docs.sh help to list commands."

case "$1" in
    help|--help|-h) help ;;
    install) install_lychee ;;
    lint-links) lint_links ;;
    *) fail "Unknown command: $1. Run ./Scripts/docs.sh help to list commands." ;;
esac
