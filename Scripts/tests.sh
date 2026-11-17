#!/bin/bash
set -euo pipefail

repository_root="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

derived_data="$repository_root/build/DerivedData"
# Sanitizer builds use their own products so they never replace the normal build.
tsan_derived_data="$repository_root/build/DerivedData-TSan"
output_directory="$repository_root/build/Tests"
xcodebuild_arguments=(-project Promptly.xcodeproj -scheme Promptly -destination 'platform=macOS,arch=arm64')
# Ad-hoc signing keeps local and CI builds identical and needs no certificates.
signing_overrides=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=)
test_options=(
    -parallel-testing-enabled NO
    -test-timeouts-enabled YES
    -maximum-test-execution-time-allowance 120
    -testLanguage en
    -testRegion US
)
# A jq definition of a coverage report entry's line coverage, in percent to one decimal.
coverage_percent='def percent: .lineCoverage * 1000 | round / 10;'

# Prints an error or warning; on GitHub Actions, as an annotation on the run.
print_message() {
    local level="$1" message
    shift
    message="$*"
    if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
        # Workflow commands need percent signs and line breaks escaped.
        message="${message//'%'/%25}"
        message="${message//$'\r'/%0D}"
        message="${message//$'\n'/%0A}"
        printf '::%s::%s\n' "$level" "$message"
    else
        printf '%s: %s\n' "$level" "$message" >&2
    fi
}

error() {
    print_message error "$@"
}

warning() {
    print_message warning "$@"
}

fail() {
    error "$@"
    exit 1
}

help() {
    cat <<'EOF'
Usage: ./Scripts/tests.sh COMMAND

Debug build and tests:
  build-for-testing    Build the app and both test targets with code coverage.
  test-unit            Run the built unit tests with code coverage.
  test-ui              Run the built UI tests. They take over the screen.
  build-and-test-unit  Build and run the unit tests with code coverage.

Release and sanitizers:
  build-release        Build the Apple silicon Release app.
  test-tsan            Build and run the unit tests with Thread Sanitizer.

Reports:
  summarize            Print the latest test counts and coverage in build/Tests.
  help                 Show this help.

A command is required. test-unit and test-ui never rebuild: run build-for-testing
first. Agents should use build-and-test-unit after code changes. Test commands
fail when no test passes or any test fails. Results and full logs go to
build/Tests; xcodebuild output is condensed with xcsift when it is installed.
Every build keeps App Sandbox. Collecting coverage requires xcodebuild to read
the app's container; where macOS refuses that, the run warns and reports no
coverage. Requires an Apple silicon Mac.
EOF
}

require_apple_silicon() {
    [[ "$(sysctl -n hw.optional.arm64 2> /dev/null)" == 1 ]] ||
        fail "Promptly development requires an Apple silicon Mac."
}

relative_path() {
    printf '%s\n' "${1#"$repository_root"/}"
}

modified_time() {
    stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$1"
}

# Runs xcodebuild, saving its full log and returning xcodebuild's exit status.
run_xcodebuild() {
    local name="$1" log="$output_directory/$1.log" statuses
    shift
    require_apple_silicon
    mkdir -p "$output_directory"
    printf 'Running xcodebuild for %s; full log: %s\n' "$name" "$(relative_path "$log")"
    set +e
    if command -v xcsift > /dev/null 2>&1; then
        xcodebuild "$@" 2>&1 | tee "$log" | xcsift -f toon -w
    else
        xcodebuild "$@" 2>&1 | tee "$log"
    fi
    statuses=("${PIPESTATUS[@]}")
    set -e
    return "${statuses[0]}"
}

# Saves and prints a result bundle's test counts and rejects empty or failing runs.
check_test_results() {
    local name="$1" bundle="$output_directory/$1.xcresult" results="$output_directory/$1.json"
    xcrun xcresulttool get test-results summary --path "$bundle" > "$results" || {
        rm -f "$results"
        error "Could not read test results from $(relative_path "$bundle")."
        return 1
    }
    jq -r --arg name "$name" \
        '"\($name): \(.passedTests) passed, \(.failedTests) failed, \(.skippedTests) skipped"' "$results"
    jq -e '.passedTests > 0 and .failedTests == 0' "$results" > /dev/null || {
        error "$name must run at least one passing test and have no failures."
        return 1
    }
}

# Saves and prints line coverage per target from a result bundle. Coverage is
# informational, so missing coverage is a warning, not a failure.
report_coverage() {
    local name="$1" bundle="$output_directory/$1.xcresult" report="$output_directory/$1-coverage.json"
    [[ -e "$bundle" ]] || return 0
    if ! xcrun xccov view --report --only-targets --json "$bundle" > "$report" 2> /dev/null; then
        rm -f "$report"
        # Xcode copies the sandboxed app's coverage data out of its container, which
        # macOS refuses unless the app running xcodebuild may access other apps' data.
        warning "No code coverage in $(relative_path "$bundle"). If its issues include \"Failed to" \
            "download profiles … Operation not permitted\", allow the app running xcodebuild to" \
            "access data from other apps."
        return 0
    fi
    jq -r "$coverage_percent"' .[] | "Coverage \(.name): \(percent)% (\(.coveredLines) of \(.executableLines) lines)"' \
        "$report"
}

# Runs one xcodebuild test action into a fresh result bundle, then checks the results.
run_tests() {
    local name="$1" bundle="$output_directory/$1.xcresult" status=0
    shift
    # xcodebuild refuses to overwrite a result bundle, and an earlier run's results
    # must not be reported as this run's.
    rm -rf "$bundle" "$output_directory/$name.json" "$output_directory/$name-coverage.json"
    run_xcodebuild "$name" "$@" "${test_options[@]}" -resultBundlePath "$bundle" || status=$?
    check_test_results "$name" || status=1
    return "$status"
}

require_test_build() {
    compgen -G "$derived_data/Build/Products/*.xctestrun" > /dev/null ||
        fail "No test build found. Run ./Scripts/tests.sh build-for-testing first."
}

build_for_testing() {
    run_xcodebuild build-for-testing build-for-testing "${xcodebuild_arguments[@]}" \
        -configuration Debug -derivedDataPath "$derived_data" -enableCodeCoverage YES \
        "${signing_overrides[@]}"
}

test_unit() {
    local status=0
    require_test_build
    run_tests unit-tests test-without-building "${xcodebuild_arguments[@]}" \
        -configuration Debug -derivedDataPath "$derived_data" -only-testing:PromptlyTests \
        -enableCodeCoverage YES || status=$?
    report_coverage unit-tests
    return "$status"
}

test_ui() {
    require_test_build
    run_tests ui-tests test-without-building "${xcodebuild_arguments[@]}" \
        -configuration Debug -derivedDataPath "$derived_data" -only-testing:PromptlyUITests \
        -enableCodeCoverage NO
}

build_and_test_unit() {
    local status=0
    run_tests unit-tests test "${xcodebuild_arguments[@]}" \
        -configuration Debug -derivedDataPath "$derived_data" -only-testing:PromptlyTests \
        -enableCodeCoverage YES "${signing_overrides[@]}" || status=$?
    report_coverage unit-tests
    return "$status"
}

build_release() {
    local executable="$derived_data/Build/Products/Release/Promptly.app/Contents/MacOS/Promptly" architectures
    run_xcodebuild release-build build "${xcodebuild_arguments[@]}" \
        -configuration Release -derivedDataPath "$derived_data" "${signing_overrides[@]}"
    architectures="$(lipo -archs "$executable")" || fail "Could not read architectures of $(relative_path "$executable")."
    [[ "$architectures" == arm64 ]] || fail "Release app must be Apple silicon only; found: $architectures."
    printf 'Release app architectures: %s\n' "$architectures"
}

test_tsan() {
    # Xcode fails the test that triggers a report. Aborting on the first report also
    # fails the run for a race outside any test, such as during app launch.
    export TEST_RUNNER_TSAN_OPTIONS="halt_on_error=1"
    run_tests tsan-unit-tests test "${xcodebuild_arguments[@]}" \
        -configuration Debug -derivedDataPath "$tsan_derived_data" -only-testing:PromptlyTests \
        -enableThreadSanitizer YES -enableCodeCoverage NO "${signing_overrides[@]}"
}

# Prints a table of each test command's latest results, also for the GitHub job
# summary. Results stay until their command runs again, so rows can be older.
summarize() {
    local name results log coverage row table
    table="| Results | Passed | Failed | Skipped | Line coverage | Finished |"
    table+=$'\n'"| --- | --- | --- | --- | --- | --- |"
    for name in unit-tests ui-tests tsan-unit-tests; do
        results="$output_directory/$name.json"
        log="$output_directory/$name.log"
        if [[ -f "$results" ]]; then
            coverage="—"
            if [[ -f "$output_directory/$name-coverage.json" ]]; then
                coverage="$(jq -r "$coverage_percent"' map("\(.name) \(percent)%") | join(", ")' \
                    "$output_directory/$name-coverage.json")"
            fi
            row="$(jq -r --arg name "$name" --arg coverage "$coverage" --arg finished "$(modified_time "$results")" \
                '"| \($name) | \(.passedTests) | \(.failedTests) | \(.skippedTests) | \($coverage) | \($finished) |"' \
                "$results")"
        elif [[ -f "$log" ]]; then
            # The run started but left no readable results.
            row="| $name | no results; see $(relative_path "$log") | | | | $(modified_time "$log") |"
        else
            row="| $name | not run | | | | |"
        fi
        table+=$'\n'"$row"
    done
    printf '%s\n' "$table"
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        printf '%s\n' "$table" >> "$GITHUB_STEP_SUMMARY"
    fi
}

[[ $# -le 1 ]] || fail "Expected one command; got $#. Run ./Scripts/tests.sh help to list commands."
# An empty or blank argument, such as an unset variable, is a missing command.
[[ $# -eq 1 && -n "${1//[[:space:]]/}" ]] ||
    fail "Missing command. Usage: ./Scripts/tests.sh COMMAND. Run ./Scripts/tests.sh help to list commands."

case "$1" in
    help|--help|-h) help ;;
    build-for-testing) build_for_testing ;;
    test-unit) test_unit ;;
    test-ui) test_ui ;;
    build-and-test-unit) build_and_test_unit ;;
    build-release) build_release ;;
    test-tsan) test_tsan ;;
    summarize) summarize ;;
    *) fail "Unknown command: $1. Run ./Scripts/tests.sh help to list commands." ;;
esac
