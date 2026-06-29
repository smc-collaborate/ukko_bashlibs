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
    # |x| echo "doFail:  Previous: failFound='${failFound:-}'  didOverallFail='${didOverallFail:-}'  TEST_SUPPORT_EXIT_ON_FAIL='${TEST_SUPPORT_EXIT_ON_FAIL:-}'" >&2
    failFound='yes'
    didOverallFail='yes'  #
    local msg="${1:-Test Failed}"
    shift || true
    echo -e "❌  $msg"

    for line in "$@"; do
        echo -e "❌  $line"
    done
    return 1
}


function hasFailedSoExitIfChosen()
{
    # |ExtraLogging| echo "!!!  hasFailedSoExitIfChosen.a(): failFound='${failFound:-}'  didOverallFail='${didOverallFail:-}'  TEST_SUPPORT_EXIT_ON_FAIL='${TEST_SUPPORT_EXIT_ON_FAIL:-}'" >&2
    didOverallFail='yes'
    failFound='yes'
    # |ExtraLogging| echo "!!!  hasFailedSoExitIfChosen.b(): failFound='${failFound:-}'  didOverallFail='${didOverallFail:-}'  TEST_SUPPORT_EXIT_ON_FAIL='${TEST_SUPPORT_EXIT_ON_FAIL:-}'" >&2

    if [[ "${TEST_SUPPORT_EXIT_ON_FAIL:-}" == "yes" ]] ; then
        echo -e "    Ending testing due to ${COLOUR[VIVID_RED_USED]:-}export TEST_SUPPORT_EXIT_ON_FAIL=yes${COLOUR[OFF_USED]:-}"
        exit 1
    elif [[ "${_test_support_exit_on_fail_warned:-}" != "yes" ]] ; then
        echo -e "⚠️  To exit on the first failure in future, ${COLOUR[VIVID_RED_USED]:-}export TEST_SUPPORT_EXIT_ON_FAIL=yes${COLOUR[OFF_USED]:-}\n"
        _test_support_exit_on_fail_warned='yes'
    fi
    # |ExtraLogging| echo "!!!  hasFailedSoExitIfChosen.z(): failFound='${failFound:-}'  didOverallFail='${didOverallFail:-}'  TEST_SUPPORT_EXIT_ON_FAIL='${TEST_SUPPORT_EXIT_ON_FAIL:-}'" >&2
}
function doFailAndExitIfChosen()
{
    # |ExtraLogging| echo "!!!  doFailAndExitIfChosen.start(): failFound='${failFound:-}'  didOverallFail='${didOverallFail:-}'  TEST_SUPPORT_EXIT_ON_FAIL='${TEST_SUPPORT_EXIT_ON_FAIL:-}'" >&2
    # |ExtraLogging| echo "!!!  doFailAndExitIfChosen.b(): Running $*">&2
    doFail "$@" || true

    hasFailedSoExitIfChosen
    # |ExtraLogging|  echo "ukkoVerify[Fail]:  Previous: failFound='${failFound:-}'  didOverallFail='${didOverallFail:-}' " >&2

}
# shellcheck disable=SC2317
function progressCheck_hasFailed()
{
    [[ "$failFound" == 'yes' ]]
}

function checkForExitDueToFailure()
{
    echo "!!!  checkForExitDueToFailure: failFound='${failFound:-}'  didOverallFail='${didOverallFail:-}'  TEST_SUPPORT_EXIT_ON_FAIL='${TEST_SUPPORT_EXIT_ON_FAIL:-}'" >&2
    [[ "$failFound" == 'yes' ]] && hasFailedSoExitIfChosen
    return 0
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
    export UBERPARENT_DIR ; UBERPARENT_DIR=$(dirname "${GRANDPARENT_DIR}")
    #export SAMPLES_DIR="${PARENT_DIR}/samples"

    msgs=()
    msgs+=("⚠️  - EXE_DIR        =$EXE_DIR")
    msgs+=("⚠️  - PARENT_DIR      =$PARENT_DIR")
    msgs+=("⚠️  - GRANDPARENT_DIR =$GRANDPARENT_DIR")
    msgs+=("⚠️  - UBERPARENT_DIR  =$UBERPARENT_DIR")

    for dir in "${UBERPARENT_DIR}" "${GRANDPARENT_DIR}" "${PARENT_DIR}" "${PROJ_DIR:-}"  "${EXE_DIR}" "-end-"; do
        #print_extraVerbose "get_GOLD_REF_DIR: Reviewing: ${dir}"
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
            print_extraVerbose " ✓ \$GOLD_REF_DIR = ${GOLD_REF_DIR}"
            break
        else
            print_extraVerbose " ✗ \$GOLD_REF_DIR = ${GOLD_REF_DIR}"
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
        doFailAndExitIfChosen "${_errs[@]}"
    fi

    for line in "${tests[@]}"; do
        echo -e "Run test script: $(displayBluePath "$line")"
        quoteIfNeeded

        "${line}" || doFailAndExitIfChosen "Failed $(displayPath "${line}")"
    done
}

# shellcheck disable=SC2317
function ukkoVerify()
{
    # --output-format=json-full
    # |x| echo "ukkoVerify[Start]:  Previous: failFound='${failFound:-}'  didOverallFail='${didOverallFail:-}' " >&2
    echo -en "${COLOUR[VIVID_BLUE_USED]:-}"
    echo -n "ukkoTestCommand verify $(quoteIfNeeded "$@")"
    echo -e "${COLOUR[OFF_USED]:-}"
    ukkoTestCommand verify "$@" || hasFailedSoExitIfChosen
}

function ukkoVerifyWithMsg()
{
    local caption="${1:-}"
    shift 1 || true
    local params=("$@")

    ukkoVerify "${params[@]}" || doFailAndExitIfChosen "Failed to $caption" "$(quoteIfNeeded "${params[@]}")" || return 1
}

if [[ -z "${appUnderTest:-}" ]] ; then

    _src="${BASH_SOURCE[-2]:-}"
    _src="${_src##*/}"

    if [[ "${_src}" == *"-testSupport.inc.bash" ]] ; then
       appUnderTest="${_src%-testSupport.inc.bash}"
    else
       appUnderTest="<Call setAppUnderTest() to set the application to be tested>"
    fi
fi


function setAppUnderTest()
{
    appUnderTest="${1:-}"

    #echo "ℹ️  Set appUnderTest to: $(displayPath "${appUnderTest}")"
    # Typically 'AUT_VERSION' is set too ..

}

# Verify '$appUnderTest' with the given parameters, and compare the output to the reference file.
function ukkoVerifyBasicAppUnderTest()
{
    local params=("$@")

    local fname="params"

    for x in "${params[@]}"; do
        fname+="_${x// /_}"
    done

    fname+=".txt.subst.ref"

    ukkoVerify     --stdout="file:${GOLD_REF_DIR%/}/basic/${fname}"           -- "$appUnderTest" "${params[@]}"

}


function noteInBlue()
{
    echo -n "${1}"
    shift 1 || true
    echo -e -n "${COLOUR[VIVID_BLUE_STDOUT]:-}"
    echo -n -- "$@"
    echo -e  "${COLOUR[OFF_STDOUT]:-}"
}

function noteInBlue_cmd()
{
    echo -n "${1}"
    shift 1 || true
    echo -e -n "${COLOUR[VIVID_BLUE_STDOUT]:-}"
    quoteIfNeeded "$@"
    echo -e  "${COLOUR[OFF_STDOUT]:-}"
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

    main "$@" || didOverallFail='yes'
    [[ "${didOverallFail:-}" == 'yes' ]] && echo "✗ Failed Tests" && return 1

    echo "✓ Passed Tests"

    return 0
}

[[ -z "${RUN_WITH_WRAPPING_MODE:-}" ]] && export RUN_WITH_WRAPPING_MODE='left-boxed'


BUILD_FUNCS_DIR="$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")"
source "${BUILD_FUNCS_DIR%/}/lib-app.inc.bash"
