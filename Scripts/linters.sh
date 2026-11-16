#!/bin/bash
set -euo pipefail

repository_root="$(CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

# Upgrade these pins deliberately with the configurations and validation record.
swift_format_version="6.4.4"
swiftlint_version="0.65.1"
swiftlint_checksum="c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0"
swiftlint_directory="$repository_root/.build/quality-tools/swiftlint/$swiftlint_version"
swiftlint_binary="$swiftlint_directory/swiftlint"
source_directories=(Promptly PromptlyTests PromptlyUITests)

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_formatter() {
    local actual
    actual="$(xcrun swift-format --version)" || fail "Select Xcode 27.2 with DEVELOPER_DIR or xcode-select."
    [[ "$actual" == "$swift_format_version" ]] ||
        fail "Expected swift-format $swift_format_version from Xcode 27.2; found $actual."
}

require_swiftlint() {
    local actual
    [[ -x "$swiftlint_binary" ]] || fail "SwiftLint is missing. Run ./Scripts/quality.sh bootstrap."
    actual="$("$swiftlint_binary" version)" || fail "Could not run $swiftlint_binary."
    [[ "$actual" == "$swiftlint_version" ]] ||
        fail "Expected SwiftLint $swiftlint_version; found $actual. Run ./Scripts/quality.sh bootstrap."
}

bootstrap() {
    require_formatter
    if [[ -x "$swiftlint_binary" ]] && [[ "$("$swiftlint_binary" version)" == "$swiftlint_version" ]]; then
        printf 'SwiftLint %s is ready.\n' "$swiftlint_version"
        return
    fi

    mkdir -p "$swiftlint_directory"
    # Keep the last installed executable until its replacement is verified.
    swiftlint_install_directory="$(mktemp -d "$swiftlint_directory/.install.XXXXXX")"
    trap 'rm -rf "$swiftlint_install_directory"' EXIT
    local archive checksum actual
    archive="$swiftlint_install_directory/swiftlint.zip"
    # A final attempt can extend the retry window by 45s; leave room in CI's 3-minute setup step.
    curl --silent --show-error --fail --location --retry 2 --retry-max-time 90 \
        --connect-timeout 15 --max-time 45 \
        "https://github.com/realm/SwiftLint/releases/download/$swiftlint_version/portable_swiftlint.zip" \
        --output "$archive"
    checksum="$(shasum -a 256 "$archive")"
    [[ "${checksum%% *}" == "$swiftlint_checksum" ]] || fail "SwiftLint archive checksum does not match the pinned release."
    unzip -p "$archive" swiftlint > "$swiftlint_install_directory/swiftlint"
    chmod +x "$swiftlint_install_directory/swiftlint"
    actual="$("$swiftlint_install_directory/swiftlint" version)"
    [[ "$actual" == "$swiftlint_version" ]] || fail "Downloaded SwiftLint has unexpected version $actual."
    mv -f "$swiftlint_install_directory/swiftlint" "$swiftlint_binary"
    printf 'Installed SwiftLint %s in .build/quality-tools.\n' "$swiftlint_version"
}

format_check() {
    xcrun swift-format lint --strict --recursive \
        --configuration "$repository_root/.swift-format" "${source_directories[@]}"
}

lint() {
    "$swiftlint_binary" lint --strict --no-cache \
        --config "$repository_root/.swiftlint.yml" "${source_directories[@]}"
}

[[ $# -le 1 ]] || fail "Usage: ./Scripts/quality.sh [bootstrap|format|format-check|lint|check]"
case "${1:-check}" in
    bootstrap)
        bootstrap
        ;;
    format)
        require_formatter
        xcrun swift-format format --in-place --recursive \
            --configuration "$repository_root/.swift-format" "${source_directories[@]}"
        ;;
    format-check)
        require_formatter
        format_check
        ;;
    lint)
        require_swiftlint
        lint
        ;;
    check)
        require_formatter
        require_swiftlint
        printf 'Checking with swift-format %s and SwiftLint %s.\n' "$swift_format_version" "$swiftlint_version"
        # Report both sets of findings even when the first check fails.
        status=0
        format_check || status=1
        lint || status=1
        exit "$status"
        ;;
    *)
        fail "Usage: ./Scripts/quality.sh [bootstrap|format|format-check|lint|check]"
        ;;
esac
