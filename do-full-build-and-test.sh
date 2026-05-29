#!/bin/bash -eu

BUILDING_DIR="$(pwd)"

DO_SETUP_RAW_ENVIRONMENT=no

function doFullBuild()
{
    exe_to_run=""
    checks_done=()
    for check_exe in "do-build-and-install" "do-build" ; do
        x="${BUILDING_DIR}/${check_exe}.sh"
        checks_done+=("$x")
        if [[ -x "$x" ]] ; then
            exe_to_run="$x"
            echo "✅ Found builder: $exe_to_run"
            break
        fi
    done

    if [[ -z "$exe_to_run" ]] ; then
        echo "❌ Required builder not found or not executable"
        echo "   Checked:"
        for x in "${checks_done[@]}" ; do
            echo "    - $x"
        done
        doExitWithCode 3
    fi

    if [[ "$DO_SETUP_RAW_ENVIRONMENT" == "yes" ]] ; then
        doSetupRawEnvironment
    fi

    if ! "$exe_to_run" --fresh ; then
        echo "❌ Build Failed, please check the output above."
        doExitWithCode 2
    else
        echo "✅ Build Succeeded."
    fi

}

function doFullTests()
{
    dirs_to_check=(
        "${BUILDING_DIR%/}/"
        "${BUILDING_DIR%/}/tests/"
    )

    ALL_TESTS_EXE=''
    for dir in "${dirs_to_check[@]}" ; do
        exe="${dir%/}/do-all-tests.sh"
        if [[ -x "$exe" ]] ; then
            ALL_TESTS_EXE="$exe"
            break
        fi
    done

    if [[ -z "$ALL_TESTS_EXE" ]] ; then
        echo "⚠️  'do-all-tests.sh' not available - skipping tests"
        doExitWithCode 1
    fi

    echo "    Running all tests: $ALL_TESTS_EXE"
    if ! "$ALL_TESTS_EXE" ; then
        echo "❌  Tests Failed, please check the output above."
        doExitWithCode 4
    fi


    echo "✅  Tests Succeeded."
}


function dumpVersions()
{
    echo "---------------------"
    source /etc/os-release
    echo "| Environment:"
    {
        echo "$PRETTY_NAME"

        if command -v python3 &> /dev/null ; then
            python3 --version
        else
            echo "python3: Not found"
        fi
        if command -v protoc &> /dev/null ; then
            protoc --version
        else
            echo "protoc : Not found"
        fi
    } | sed 's/^/|  - /'
    echo "--------------------"
}

function doExitWithCode()
{
    local code="$1"

    [[ "${DO_SETUP_RAW_ENVIRONMENT:-}" == "yes" ]] && dumpVersions

    echo "--------------------"
    echo "Exiting with code: $code"
    echo ""
    echo ""
    exit "$code"
}
function doFullBuildAndTest()
{
    echo "--------------------"

    if [[ "${1:-}" == "--raw-environment" ]] ; then
        DO_SETUP_RAW_ENVIRONMENT="yes"
        shift 1
    fi

    doFullBuild "$@"
    doFullTests

    #|git| if git status &> /dev/null ; then
    #|git|     echo "✅  git available - running pre-commit checks"
    #|git|     pre-commit run --all-files || echo "⚠️  pre-commit run failed, please check the output above."
    #|git| else
    #|git|     echo "⚠️  git not available - skipping pre-commit checks."
    #|git| fi

    doExitWithCode 0
}

function doSetupRawEnvironment()
{
    echo "Raw environment: Additional setup"
    source /etc/os-release

    mkdir -p "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
    apt-get update

    #########################################
    #
    #|Extras| apt-get install -y git
    #|Extras| git config --global --add safe.directory /app

    #########################################
    #
    #|Extras| if [[ "$VERSION_CODENAME" == "jammy" ]] ; then
    #|Extras|     export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
    #|Extras| fi
}

source "$(dirname "${BASH_SOURCE[0]}")/build-funcs.inc.bash"

doFullBuildAndTest "$@"
#
#
