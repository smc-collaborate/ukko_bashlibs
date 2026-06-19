# shellcheck shell=bash
# shellcheck disable=SC2317

################
#
#
# IMPORT THIS AS A 'source' script
#   source ukko_bashlibs/lib-testing.inc.bash
#
#
# Example usage:
#
#| ╭─────────────────────────────────────────────────────────
#| │ #!/bin/bash -eu
#| │
#| │ function testSetup()
#| │ {
#| │     testStart "simpleTcpStreamer"
#| │     runningChecks_haltIfRunning "simpleTcpStreamer.py"
#| │ }
#| │
#| │ function testCleanup()
#| │ {
#| │     runningChecks_haltIfRunning "simpleTcpStreamer.py"
#| │ }
#| │
#| │ function testRun()
#| │ {
#| │     simpleTcpStreamer --tcpPort=12302 &
#| │     sleep 2
#| │
#| │     lines_received="$(nc -w 5 localhost 12302)"
#| │     lines_expected="$(printf "Hello world: %s\n" {1..100})"
#| │     doMatch_direct "$lines_received" "$lines_expected" "Received"  "Expected"
#| │
#| │     runningChecks_failIfRunning "simpleTcpStreamer.py"
#| │  }
#| │
#| │ BUILD_FUNCS_DIR="$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/../ukko_bashlibs/"
#| │ # shellcheck source=../ukko_bashlibs/lib-testing.inc.bash
#| │ source "${BUILD_FUNCS_DIR%/}/lib-testing.inc.bash"
#| ╰─────────────────────────────────────────────────────────
############################



failFound='no'
testName='<NONE>'
# shellcheck disable=SC2317
function testStart()
{
    testName="${1:-Test}"
    failFound='no'
    echo "🔍  Starting test: $testName"
}

# shellcheck disable=SC2317
function testEnd()
{
    if [[ "$failFound" == 'yes' ]] ; then
        echo "❌  Test '$testName' failed"
        testName='<NONE>'
        return 1
    else
        echo "✅  Test '$testName' passed"
        testName='<NONE>'
        return 0
    fi
}

# shellcheck disable=SC2317
function doFail()
{
    failFound='yes'
    local msg="${1:-Test Failed}"
    shift || true
    echo "❌  $msg"

    for line in "$@"; do
        echo "❌  $line"
    done
    return 1
}

# shellcheck disable=SC2317
function progressCheck_hasFailed()
{
    [[ "$failFound" == 'yes' ]]
}

# shellcheck disable=SC2317
function progressCheck_hasNotFailedYet()
{
    [[ "$failFound" != 'yes' ]]
}

# shellcheck disable=SC2317
function _getRunningPids()
{
    local exeName="$1"

    pgrep -f "${exeName}" || true
}

# shellcheck disable=SC2317
function runningChecks_failIfNotRunning()
{
    local exeName="$1"
    devices_running="$(_getRunningPids "${exeName}")"

    if [[ -z "${devices_running}" ]] ; then
        doFail "${exeName} is not currently running"
    else
        echo " ✓  ${exeName} is running (PIDs: [$devices_running])"
    fi
}

# shellcheck disable=SC2317
function runningChecks_failIfRunning()
{
    local exeName="$1"
    local permit_wait_seconds="${2:-10}"

    x=1
    while [[ "$x" -le "${permit_wait_seconds}" ]] || [[ "$x" == 1 ]]; do

        devices_running="$(_getRunningPids "${exeName}")"
        [[ -z "${devices_running}" ]] && break

        echo "ℹ️  ${exeName} is currently running (PIDs: [$devices_running]) rechecking $x/${permit_wait_seconds}..."
        ((x++))
        sleep 1
    done

    devices_running="$(_getRunningPids "${exeName}")"

    if [[ -n "${devices_running}" ]] ; then
        doFail "${exeName} is still running (PIDs: [$devices_running])"
    elif [[ "$x" -gt 1 ]]; then
        echo " ✓  ${exeName} has stopped running after $x seconds"
    else
        echo " ✓  ${exeName} is not running"
    fi
}

# shellcheck disable=SC2317
function runningChecks_haltIfRunning()
{
    local exeName="$1"

    devices_running="$(_getRunningPids "${exeName}")"

    if [[ -z "${devices_running}" ]] ; then
        echo " ✓  ${exeName} is not currently running"
        return 0
    fi
    echo "ℹ️  ${exeName} is running"
    echo "ℹ️  Halting ${exeName} (PIDs:$devices_running)"

    halt_failure='no'

    for pid in $devices_running; do
        if ! kill -9 "$pid"; then
            doFail "Failed to stop ${exeName} with PID $pid, please check the output above"
            halt_failure='yes'
        fi
    done

    sleep 2 # # Give the servers some time to die
    [[ "$halt_failure" == 'yes' ]] && return 1

    echo "ℹ️  Halted ${exeName} (PIDs: [$devices_running])"
}

# shellcheck disable=SC2317
function doMatch_direct()
{
    local value1="$1"
    local value2="$2"
    local label1="${3:-Generated}"
    local label2="${4:-Expected}"
    if [[ "$value1" != "$value2" ]]; then
        doFail "$label1 does not match $label2"
    else
        echo "✅  $label1 matches $label2"
    fi
}

if [[ "$(type -t main)" != 'function' ]] ; then
    function main()
    {
        testSetup
        if progressCheck_hasNotFailedYet; then
            testRun
        else
            echo "Unable to start test - Setup failed"
        fi
        testCleanup
        testEnd
    }
fi

# shellcheck disable=SC2317
function get_GOLD_REF_DIR()
{
    [[ -n "${GOLD_REF_DIR:-}" ]] && return 0

    export PARENT_DIR ; PARENT_DIR="$(dirname "${EXE_DIR}")"
    export GRANDPARENT_DIR ; GRANDPARENT_DIR=$(dirname "${PARENT_DIR}")
    #export SAMPLES_DIR="${PARENT_DIR}/samples"

    msgs=()
    msgs+=("⚠️  - EXE_DIR        =$EXE_DIR")
    msgs+=("⚠️  - PARENT_DIR      =$PARENT_DIR")
    msgs+=("⚠️  - GRANDPARENT_DIR =$GRANDPARENT_DIR")
    #msgs+=("⚠️    - SAMPLES_DIR    =$SAMPLES_DIR")

    for dir in "${PROJ_DIR:-}" "${GRANDPARENT_DIR}" "${PARENT_DIR}" "${EXE_DIR}" "-end-"; do
        [[ -z "${dir}" ]] && continue
        if [[ "${dir}" == "-end-" ]] ; then
            echo "⚠️  \$GOLD_REF_DIR : Not found - defaulting to missing: ${GOLD_REF_DIR}"
            for msg in "${msgs[@]}" ; do
                echo "$msg"
            done
            FATAL_FAILURE_NO_RETURN "Unable to find 'testing/gold_refs' directory"
        fi


        export GOLD_REF_DIR="${dir%/}/testing/gold_refs"
        msgs+=("⚠️  -  Reviewed        ${GOLD_REF_DIR}")

        if [[ -d "$GOLD_REF_DIR" ]] ; then
            print_verbose "\$GOLD_REF_DIR = ${GOLD_REF_DIR}"
            break
        fi
    done

}

# shellcheck disable=SC2317
function find_and_run_tests()
{
    dirs_to_review=("${EXE_DIR%/}" "${EXE_DIR%/}/testing" "${EXE_DIR%/}/tests" "$@")

    tests=()

    for dir in "${dirs_to_review[@]}"; do
        for file in "${dir%/}"/test_*.sh; do
            [[ -f "$file" ]] && tests+=("$file")
        done
    done

    if [[ "${#tests[@]}" -eq 0 ]] ; then
        local _errs=("No 'test_*.sh' scripts found in:")

        for x in "${dirs_to_review[@]}"; do
            _errs+=(" • $(displayPath "${x}")")
        done
        doFail "${_errs[@]}"
    fi

    for line in "${tests[@]}"; do
        "${line}" || doFail "Failed $(displayPath "${line}")"
    done
}

# shellcheck disable=SC2317
function ukkoVerify()
{
    # --output-format=json-full
    echo -e -n "${BOLD_BLUE_STDOUT:-}"
    echo "ukkoTestCommand verify $*"
    echo -e  "${NC_STDOUT:-}"
    ukkoTestCommand verify "$@" && return 0

    didFail='yes'

    if [[ "${TEST_SUPPORT_EXIT_ON_FAIL:-}" == "yes" ]] ; then
        echo -e "Exiting due to ${BOLD_RED_STDOUT:-}export TEST_SUPPORT_EXIT_ON_FAIL=yes${NC_STDOUT:-}"
        exit 1
    elif [[ "${_test_support_exit_on_fail_warned:-}" != "yes" ]] ; then
        echo -e "⚠️  To exit on the first failure in future, ${BOLD_RED_STDOUT:-}export TEST_SUPPORT_EXIT_ON_FAIL=yes${NC_STDOUT:-}"
        _test_support_exit_on_fail_warned='yes'
    fi
}


function app_init()
{
    # |!!>| set -x
    if [[ -z "${APPS_NAME:-}" ]] ; then
        APPS_NAME="$(basename "${0}" ".sh")"
        [[ "$APPS_NAME" == "test_"* ]] || APPS_NAME="Testing ${PROJ_DIR##*/}"
    fi
    # shellcheck disable=SC2034
    TEST_SCRIPT_NAME="$APPS_NAME"
    # |!!>| set +x
}


function app_run()
{
    cd "$PROJ_DIR" || FATAL_FAILURE_NO_RETURN "Failed to change directory to ${PROJ_DIR}"
    [[ "$(type -t setupForMain)" == 'function' ]] && setupForMain "$@"

    main "$@" || didFail='yes'
    [[ "${didFail:-}" == 'yes' ]] && echo "✗ Failed Tests" && return 1

    echo "✓ Passed Tests"

    return 0
}

[[ -z "${RUN_WITH_WRAPPING_MODE:-}" ]] && export RUN_WITH_WRAPPING_MODE='left-boxed'


BUILD_FUNCS_DIR="$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")"
source "${BUILD_FUNCS_DIR%/}/lib-app.inc.bash"
