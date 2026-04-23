# shellcheck shell=bash
################
#
#
# IMPORT THIS AS A 'source' script
#   source ukko_bashlibs/test-funcs.inc.bash
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
#| │ # shellcheck source=../ukko_bashlibs/test-funcs.inc.bash
#| │ source "${BUILD_FUNCS_DIR%/}/test-funcs.inc.bash"
#| ╰─────────────────────────────────────────────────────────
############################

BUILD_FUNCS_DIR="$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")"
source "${BUILD_FUNCS_DIR%/}/utils.inc.bash"

failFound='no'
testName='<NONE>'
function testStart()
{
    testName="${1:-Test}"
    failFound='no'
    echo "🔍  Starting test: $testName"
}

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
function doFail()
{
    failFound='yes'
    local msg="$*"
    msg="${msg:-"Test Failed"}"
    echo "❌  $msg"
}

function progressCheck_hasFailed()
{
    [[ "$failFound" == 'yes' ]]
}

function progressCheck_hasNotFailedYet()
{
    [[ "$failFound" != 'yes' ]]
}

function _getRunningPids()
{
    local exeName="$1"

    pgrep -f "${exeName}" || true
}

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

main "$@"
