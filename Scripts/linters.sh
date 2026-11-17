#!/bin/bash
set -euo pipefail

repository_root="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

# Upgrade a pin deliberately: change its version, download URL, and SHA-256 together,
# then rerun the affected lint commands.
swift_format_version="6.4.4"
swiftlint_version="0.65.1"
swiftlint_url="https://github.com/realm/SwiftLint/releases/download/$swiftlint_version/portable_swiftlint.zip"
swiftlint_checksum="c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0"
actionlint_version="1.7.12"
actionlint_url="https://github.com/rhysd/actionlint/releases/download/v$actionlint_version/actionlint_${actionlint_version}_darwin_arm64.tar.gz"
actionlint_checksum="aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f"
shellcheck_version="0.11.0"
shellcheck_url="https://github.com/koalaman/shellcheck/releases/download/v$shellcheck_version/shellcheck-v$shellcheck_version.darwin.aarch64.tar.gz"
shellcheck_checksum="339b930feb1ea764467013cc1f72d09cd6b869ebf1013296ba9055ab2ffbd26f"

tools_directory="$repository_root/.build/quality-tools"
source_directories=(Promptly PromptlyTests PromptlyUITests)
swift_format_arguments=(--recursive --configuration "$repository_root/.swift-format" "${source_directories[@]}")

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

help() {
    cat <<EOF
Usage: ./Scripts/linters.sh COMMAND

SwiftLint:
  check-swiftlint     Check for SwiftLint $swiftlint_version (repository install, then PATH).
  install-swiftlint   Install pinned SwiftLint in .build/quality-tools.
  lint-swift          Lint Swift sources with SwiftLint.

swift-format (included with Xcode 27.2):
  check-swift-format  Check for swift-format $swift_format_version via xcrun.
  lint-swift-format   Check Swift formatting without changing files.
  format-swift        Format Swift sources in place.

actionlint:
  check-actionlint    Check for actionlint $actionlint_version (repository install, then PATH).
  install-actionlint  Install pinned actionlint in .build/quality-tools.
  lint-actions        Lint GitHub Actions workflows, including shell blocks with ShellCheck.

ShellCheck:
  check-shellcheck    Check for ShellCheck $shellcheck_version (repository install, then PATH).
  install-shellcheck  Install pinned ShellCheck in .build/quality-tools.
  lint-shell          Lint tracked and untracked, non-ignored .sh, .bash, and .ksh files.

Composed commands:
  check-tools         Check all four tools, reporting every failure.
  install             Install SwiftLint, actionlint, and ShellCheck, reporting every failure.
  help                Show this help.

A command is required. Checks and linters never install tools, and only
format-swift modifies source files. Installs require an Apple silicon Mac and
verify the pinned archive's SHA-256 and the installed version.
EOF
}

# Prints the version an executable reports, in the format used by the pins.
tool_version() {
    local command="$1" executable="$2" output
    case "$command" in
        swiftlint)
            "$executable" version
            ;;
        actionlint)
            output="$("$executable" -version)" || return
            printf '%s\n' "${output%%$'\n'*}"
            ;;
        shellcheck)
            output="$("$executable" --version)" || return
            sed -n 's/^version: //p' <<< "$output"
            ;;
    esac
}

# Prints the pinned repository install, or a matching executable on PATH.
resolve_tool() {
    local command="$1" name="$2" version="$3" executable actual
    executable="$tools_directory/$command/$version/$command"
    if [[ ! -x "$executable" ]]; then
        executable="$(command -v "$command")" ||
            fail "$name is missing. Run ./Scripts/linters.sh install-$command."
    fi
    actual="$(tool_version "$command" "$executable")" || fail "Could not run $executable."
    [[ "$actual" == "$version" ]] ||
        fail "Expected $name $version; found ${actual:-an unknown version} at $executable. Run ./Scripts/linters.sh install-$command."
    printf '%s\n' "$executable"
}

report_tool() {
    printf '%s %s is ready: %s\n' "$1" "$2" "${3#"$repository_root"/}"
}

check_tool() {
    local executable
    executable="$(resolve_tool "$@")"
    report_tool "$2" "$3" "$executable"
}

# Promptly supports Apple silicon only, and the pinned downloads are arm64 builds.
require_apple_silicon() {
    [[ "$(sysctl -n hw.optional.arm64 2> /dev/null)" == 1 ]] ||
        fail "Promptly development requires an Apple silicon Mac."
}

# Downloads a pinned release archive, verifies its SHA-256 and version, and installs
# its executable in the ignored .build/quality-tools cache.
install_tool() (
    local command="$1" name="$2" version="$3" url="$4" checksum="$5" member="$6"
    local executable="$tools_directory/$command/$version/$command" actual install_directory archive
    require_apple_silicon
    if [[ -x "$executable" ]] && actual="$(tool_version "$command" "$executable")" && [[ "$actual" == "$version" ]]; then
        report_tool "$name" "$version" "$executable"
        return
    fi

    mkdir -p "${executable%/*}"
    # Keep any existing executable until its replacement is verified.
    install_directory="$(mktemp -d "${executable%/*}/.install.XXXXXX")"
    trap 'rm -rf "$install_directory"' EXIT
    archive="$install_directory/archive"
    # Each attempt is limited to 45 seconds; a final attempt can extend the 90-second retry window.
    curl --silent --show-error --fail --location --retry 2 --retry-max-time 90 \
        --connect-timeout 15 --max-time 45 "$url" --output "$archive"
    actual="$(shasum -a 256 "$archive")"
    [[ "${actual%% *}" == "$checksum" ]] || fail "$name archive checksum does not match the pinned release."
    tar -xOf "$archive" "$member" > "$install_directory/$command"
    chmod +x "$install_directory/$command"
    actual="$(tool_version "$command" "$install_directory/$command")" || fail "Could not run the downloaded $name."
    [[ "$actual" == "$version" ]] || fail "Downloaded $name has unexpected version ${actual:-unknown}."
    mv -f "$install_directory/$command" "$executable"
    printf 'Installed %s %s in .build/quality-tools.\n' "$name" "$version"
)

check_swift_format() {
    local actual
    command -v xcrun > /dev/null 2>&1 ||
        fail "xcrun is missing. Install and select Xcode 27.2 with DEVELOPER_DIR or xcode-select."
    actual="$(xcrun swift-format --version)" || fail "Select Xcode 27.2 with DEVELOPER_DIR or xcode-select."
    [[ "$actual" == "$swift_format_version" ]] ||
        fail "Expected swift-format $swift_format_version; found $actual. Select Xcode 27.2 with DEVELOPER_DIR or xcode-select."
    report_tool swift-format "$swift_format_version" "$(xcrun --find swift-format)"
}

lint_swift_format() {
    check_swift_format
    xcrun swift-format lint --strict "${swift_format_arguments[@]}"
}

format_swift() {
    check_swift_format
    xcrun swift-format format --in-place "${swift_format_arguments[@]}"
}

lint_swift() {
    local swiftlint
    swiftlint="$(resolve_tool swiftlint SwiftLint "$swiftlint_version")"
    report_tool SwiftLint "$swiftlint_version" "$swiftlint"
    "$swiftlint" lint --strict --no-cache \
        --config "$repository_root/.swiftlint.yml" "${source_directories[@]}"
}

lint_actions() {
    local actionlint shellcheck
    actionlint="$(resolve_tool actionlint actionlint "$actionlint_version")"
    shellcheck="$(resolve_tool shellcheck ShellCheck "$shellcheck_version")"
    report_tool actionlint "$actionlint_version" "$actionlint"
    report_tool ShellCheck "$shellcheck_version" "$shellcheck"
    "$actionlint" -config-file "$repository_root/.github/actionlint.yaml" -shellcheck "$shellcheck"
}

lint_shell() {
    local shellcheck script
    local scripts=()
    shellcheck="$(resolve_tool shellcheck ShellCheck "$shellcheck_version")"
    report_tool ShellCheck "$shellcheck_version" "$shellcheck"
    while IFS= read -r -d '' script; do
        scripts+=("$script")
    done < <(git ls-files --cached --others --exclude-standard -z -- '*.sh' '*.bash' '*.ksh')
    [[ ${#scripts[@]} -gt 0 ]] || fail "No shell scripts found."
    "$shellcheck" "${scripts[@]}"
}

run_all() {
    local command status=0
    for command in "$@"; do
        # A fresh shell preserves errexit inside each command, including installers.
        "$repository_root/Scripts/linters.sh" "$command" || status=1
    done
    return "$status"
}

[[ $# -le 1 ]] || fail "Expected one command; got $#. Run ./Scripts/linters.sh help to list commands."
# An empty or blank argument, such as an unset variable, is a missing command.
[[ $# -eq 1 && -n "${1//[[:space:]]/}" ]] ||
    fail "Missing command. Usage: ./Scripts/linters.sh COMMAND. Run ./Scripts/linters.sh help to list commands."

case "$1" in
    help|--help|-h)
        help
        ;;
    check-swiftlint) check_tool swiftlint SwiftLint "$swiftlint_version" ;;
    install-swiftlint)
        install_tool swiftlint SwiftLint "$swiftlint_version" "$swiftlint_url" "$swiftlint_checksum" swiftlint
        ;;
    lint-swift) lint_swift ;;
    check-swift-format) check_swift_format ;;
    lint-swift-format) lint_swift_format ;;
    format-swift) format_swift ;;
    check-actionlint) check_tool actionlint actionlint "$actionlint_version" ;;
    install-actionlint)
        install_tool actionlint actionlint "$actionlint_version" "$actionlint_url" "$actionlint_checksum" actionlint
        ;;
    lint-actions) lint_actions ;;
    check-shellcheck) check_tool shellcheck ShellCheck "$shellcheck_version" ;;
    install-shellcheck)
        install_tool shellcheck ShellCheck "$shellcheck_version" "$shellcheck_url" "$shellcheck_checksum" \
            "shellcheck-v$shellcheck_version/shellcheck"
        ;;
    lint-shell) lint_shell ;;
    check-tools)
        run_all check-swiftlint check-swift-format check-actionlint check-shellcheck
        ;;
    install)
        run_all install-swiftlint install-actionlint install-shellcheck
        ;;
    *)
        fail "Unknown command: $1. Run ./Scripts/linters.sh help to list commands."
        ;;
esac
