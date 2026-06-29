# shellcheck shell=bash
# shellcheck disable=SC2317

################
#
#
# IMPORT THIS AS A 'source' script
#   source bashlib/lib-building.inc.bash
#

############################################################################################################################################################
# A customisable python installer.
#
# 1. Setup build environment -- Runs: "${PROJ_DIR%}/tools/do-setup-build-environment.sh"  -or-  apps_doSetupBuildEnvironment() if found
#
# 2. If apps_showHeaderTitle() is defined, it will be called to show a header title for the app being built.
#
# 3. Runs: apps_doInstallOrClean() to install the app's files, or clean them if --clean is passed.
#
# 4. Create Python .venv and install dependencies if needed.
#    It expects the 'requirements*.txt' to be in '$PYTHON_ENV_HERE' (if defined) or '$PROJ_DIR')
#
# 5. If there are '.proto' files in the 'proto*' subdirectories, they will be compiled to Python using 'protoc' and the generated files will be placed in '$EXE_DIR/proto_gen'.
#
# 6. Customising includes:
#     -- PYTHON_ENV_HERE=            - Use _none_ to skip creating a virtual environment and installing dependencies there.
#                                      Otherwise assumes that the app being built is a python app that supports --version
#     -- apps_checkSourceValidity()  - If defined, it will be called to check if the source files are valid (e.g. git-lfs files are properly pulled)
#     -- APPS_NAME="My App"          - To set a custom name for the app being built (used in header titles and messages)
#                                      If not provided, it will be set to the name of the directory where this script is located.
#
# Example usage:
#
#| ╭─────────────────────────────────────────────────────────
#| │ #!/bin/bash -eu
#| │
#| │ function apps_doInstallOrClean()
#| │ {
#| │     do_pyInstall_orClean cmds/smc-jsonbin-pack.py
#| │     do_pyInstall_orClean cmds/smc-jsonbin-unpack.py
#| │ }
#| │
#| │ source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/libs/shim-lib-building.inc.bash"
#| ╰─────────────────────────────────────────────────────────
############################

APP_VERSION="v0.1.1"
APP_DESCRIPTION="Build & Installs"

BUILD_PARAMS=("$@")

function app_help()
{
    if [[ -n "${VERIFY_ON_BUILD_ENVIRONMENTS:-}" ]] ; then
        _msg1=" [--with-docker[=dry-run/={docker-image}]]"
        _msg2=()
        _msg2+=("   --with-docker[=all]    : Additionally re-run the build/test process in the docker containers: ${VERIFY_ON_BUILD_ENVIRONMENTS}\n")
        _msg2+=("   --with-docker=dry-run  : As 'above, but as a dry run only")
        _msg2+=("   --with-docker=(One of: ${VERIFY_ON_BUILD_ENVIRONMENTS}) As above, but only in the specified docker image.  It stays in the docker image afterwards for testing")
        _msg2+=("                           When 'all' is chosen, the standard build is done at the end as well")
    else
        _msg1=""
        _msg2=()
    fi

    echo "Usage: ${COLOUR[VIVID_BLUE_USED]:-}${CMD_AS_DISPLAY} [--remove | --fresh] [--with-tests]${_msg1} -- [other params for build functions ...]${COLOUR[OFF_USED]:-}"
    echo ""
    echo "   --with-tests[=on]    : Run tests after building"
    echo "   --with-tests=modules : Run tests after building - including module level tests recursively"
    for x in "${_msg2[@]}" ; do
        echo "$x"
    done

    echo ""
    echo "   --only=source_generate : Only generate sources without building applications or setting up virtual environments"
    echo "   --stats      : Shows timing stats"
    echo "   --no-precommit : Disables pre-commit checks (if any are setup)"
    echo ""
    echo "   --clean      : Clean all outputs (build artifacts, generated sources, installed applications, etc)"
    echo "   --fresh      : Clean all outputs and then build (same as --clean followed by normal execution)"
    echo "   --remove     : Alias of --clean"
    echo "   --uninstall  : Alias of --clean"
    echo ""
    echo "Any additional parameters passed after '--' are passed to the build functions"
    echo " eg: apps_doBuildOrClean and can be used to customize the build process"
}


function app_init()
{
    [[ -z "${APPS_NAME:-}"                      ]] && APPS_NAME="${PROJ_DIR##*/}"
    [[ -z "${SUGGEST_HOW_TO_INSTALL_TO_ROOT:-}" ]] && SUGGEST_HOW_TO_INSTALL_TO_ROOT=no
    APP_DESCRIPTION+=" ${APPS_NAME}"
}

function app_load_param_defaults()
{
    option_with_docker='no'
    option_with_tests="${RUN_TESTS_RECURSIVELY:-no}"   # This is exported so inherits the value in the calling shell
    option_build_kind_param=''
    option_stats='no'
    option_precommit='yes'
    option_only=''

    option_direct_values=()
}

function app_load_param_direct_value()
{
    option_direct_values+=("$1")
    return 0
}

function app_load_param_option_name_value()
{
    if [[ -n "${VERIFY_ON_BUILD_ENVIRONMENTS:-}" ]] ; then

        IFS=',' read -ra _docker_images_array <<< "$VERIFY_ON_BUILD_ENVIRONMENTS"

        param_choose_from_list "!with-docker" "$1" "$2" "dry-run" "all" "no" "${_docker_images_array[@]}" && option_with_docker="${2:-all}" && return 0
    fi
    param_choose_from_list '!with-tests' "$1" "$2" "modules" "yes" "no" && option_with_tests="${2:-yes}" && return 0
    [[ "$1" == '--clean'      ]] && option_build_kind_param="$1" && return 0
    [[ "$1" == '--fresh'      ]] && option_build_kind_param="$1" && return 0
    [[ "$1" == '--remove'     ]] && option_build_kind_param="$1" && return 0
    [[ "$1" == '--uninstall'  ]] && option_build_kind_param="$1" && return 0

    [[ "$1" == '--stats'  ]] && option_stats='yes' && return 0

    [[ "$1" == '--no-precommit'  ]] && option_precommit='no' && return 0
    param_choose_from_list "only" "$1" "$2" "source_generate" && option_only="$2" && return 0

    return 1
}


function app_run()
{
    local _final_result=0
    local _show_final_summary='no'

    export RUN_TESTS_RECURSIVELY=''
    if [[ "${option_with_tests}" == 'modules' ]] ; then
        RUN_TESTS_RECURSIVELY="$option_with_tests"
    elif [[ "${option_with_tests}" != 'yes' ]] ; then
        option_with_tests='no'
    fi
    if [[ "${EXPORT_BUILD_TOP_LEVEL_ALREADY_DONE:-}" != 'yes' ]] ; then
        export EXPORT_BUILD_TOP_LEVEL_ALREADY_DONE='yes'
        _show_final_summary='yes'
    fi

    do_withOptionalTiming "${option_stats:-no}" do_completeBuildAndTesting "$@" || _final_result="$?"

    # |x| [[ "$_show_final_summary" == 'yes' ]] && echo -e "\n${COLOUR[VIVID_BLUE_USED]:-}===== Finished ${APPS_NAME:-} with result: $_final_result =====${COLOUR[OFF_USED]:-}\n"
    [[ "$_show_final_summary" == 'yes' ]] && bashlibs_warn_on_version_if_needed

    return "$_final_result"
}

export GIT_SHARED_CHECKOUT_QUIET='yes'

function do_completeBuildAndTesting()
{
    local _fullResult=0
    local _doBuild='yes'
    local msg_suffix=''


    #
    # First: Do on docker if requested
    #
    if [[ "$option_with_docker" != 'no' ]] ; then
        if [[ "$_fullResult" != 0 ]] ; then
            echo "Process failed in host environment with result: $_fullResult"
            echo "Not running in docker environments: ${VERIFY_ON_BUILD_ENVIRONMENTS}"
        else
            echo "Process completed in host environment with success"
            echo "Verifying that in the docker environments: ${VERIFY_ON_BUILD_ENVIRONMENTS}"

            run_cmd=(do-run-in-docker)
            if [[ "$option_with_docker" == 'all' ]] ; then
                run_cmd+=("$VERIFY_ON_BUILD_ENVIRONMENTS" "--exit=yes")
            elif  [[ "$option_with_docker" == 'dry-run' ]] ; then
                run_cmd+=("$VERIFY_ON_BUILD_ENVIRONMENTS" "--dry-run")
            else
                run_cmd+=("$option_with_docker"           "--exit=no")
            fi
            run_cmd+=(-- "${0}")
            for x in "${BUILD_PARAMS[@]}" ; do
                [[ "$x" == '--with-docker'* ]] || run_cmd+=( "$x" )
            done
            echo -e "Running: ${COLOUR[VIVID_BLUE_USED]:-}$(quoteIfNeeded "${run_cmd[@]}")${COLOUR[OFF_USED]:-}"
            local runResult=0
            "${run_cmd[@]}" || runResult="$?"
            [[ "$runResult" -gt "$_fullResult" ]] && _fullResult="$runResult"
            echo -e "Ran    : ${COLOUR[VIVID_BLUE_USED]:-}$(quoteIfNeeded "${run_cmd[@]}")${COLOUR[OFF_USED]:-}"
        fi
    fi

    [[ "$option_with_docker" != 'no' ]] && [[ "$option_with_docker" != 'all' ]] && return "$_fullResult"

    ##################################################################
    #
    # Do a build in the host environment
    #

    #
    # Step 1 - Clean  first ?
    #
    if [[ ",--clean,--remove,--fresh,--uninstall," == *",${option_build_kind_param},"* ]] ; then
        doActions "AM_CLEANING=yes" || _fullResult="$?"

        if [[ -n "${UKKO_BASHLIBS_LOCAL_DIR:-}" ]] ; then
            if [[ -L "${UKKO_BASHLIBS_LOCAL_DIR:-}" ]] ; then
                msg_suffix+="\n   Also removed link at $(displayPath "${UKKO_BASHLIBS_LOCAL_DIR}" --link-src )"
                do_remove_link "${UKKO_BASHLIBS_LOCAL_DIR:-}" || _fullResult="$?"
            else
                msg_suffix+="\n   Didn't touch: $(quoteIfNeeded "$(displayPath "${UKKO_BASHLIBS_LOCAL_DIR:-}" --link-src )")"
            fi
        fi
        [[ "${_fullResult}" == 0 ]] && echo -e "   Clean done - All outputs cleaned${msg_suffix}"

        [[ "$option_build_kind_param" == '--fresh' ]] || _doBuild='no'
    fi


    #
    # Step 2 - Then Build
    #
    if [[ "${_fullResult}" == 0 ]] && [[ "${_doBuild}" = 'yes' ]] ; then
        doActions "AM_CLEANING=no"  || _fullResult="$?"
    fi

    #
    # Step 3 - Run Tests if requested
    #
    if [[ "$_fullResult" == 0 ]] && [[ "${_doBuild}" == 'yes' ]] && [[ "$option_with_tests" != 'no' ]] ; then
        runTests || _fullResult="$?"
    fi


    if [[ "$_fullResult" == 0 ]] && [[ "${_doBuild}" == 'yes' ]] ; then
        echo -e "   Build and testing completed successfully${msg_suffix}"
    else
        echo -e "   Build and/or testing failed with result: $_fullResult${msg_suffix}"
    fi
    return "$_fullResult"
}

function setupBuildEnvironment()
{

    [[ "${option_only}" == 'source_generate' ]] && echo "   Only generating sources, not generating applications or build virtual environments" && return 0

    [[ "$(type -t apps_doSetupBuildEnvironment)" != 'function' ]] && [[ ! -f "${EXE_DIR%/}/tools/do-setup-build-environment.sh" ]] && return 0 # No setup needed

    if [[ "${AM_CLEANING}" == 'yes' ]] ; then
        echo "   Clearing   Build Environment"
    else
        echo "   Setting up Build Environment"
    fi


    {
        if [[ "$(type -t apps_doSetupBuildEnvironment)" == 'function' ]] ; then
            apps_doSetupBuildEnvironment                                  || FATAL_FAILURE_NO_RETURN "Failed to setup build environment[apps_doSetupBuildEnvironment()]: Please check the output above."
        fi

        doSetupPrecommitEnvironment                                       || FATAL_FAILURE_NO_RETURN "Failed to setup precommit environment: Please check the output above."

        if [[ -f "${EXE_DIR%/}/tools/do-setup-build-environment.sh" ]] ; then
            [[  -x "${EXE_DIR%/}/tools/do-setup-build-environment.sh" ]] || FATAL_FAILURE_NO_RETURN "Failed to setup build environment[${EXE_DIR%/}/tools/do-setup-build-environment.sh]: Not executable"
            "${EXE_DIR%/}/tools/do-setup-build-environment.sh"           || FATAL_FAILURE_NO_RETURN "Failed to setup build environment[${EXE_DIR%/}/tools/do-setup-build-environment.sh]: Please check the output above."
        fi
    } | withPrefix "   │ "
    [[ "${PIPESTATUS[0]}" == 0 ]] || exit 1
    echo "   └─ Done"
}


function installPkgIfNeeded()
{
    [[ "${AM_CLEANING:-}" == 'yes' ]] && return 0

    if [[ "$*" == 0 ]] ; then
        echo "❌  installPkgIfNeeded : Called without package name(s)"
        return 1
    fi

    if [[ "$(id -u)" == 0 ]] && ! apt-cache show git &>/dev/null; then
        #
        # Apt-cache hasn't been setup yet - common in fresh docker images
        #
        echo "⚡  apt-get appears to need updating"
        apt-get update
    fi

    for package_filter in "$@" ; do
        local _packages=()

        # There isn't really a good alternative to 'apt list' like this ..
        readarray -t _packages <<< "$(apt list "${package_filter}" 2>/dev/null | grep '/' | awk -F/ '{print $1}')"
        if [[ "${#_packages[@]}" == 0 ]] ; then
            echo "❌  installPkgIfNeeded ${package_filter@Q} :  No matching packages found"
            return 1
        fi

        for package in "${_packages[@]}" ; do
            if ! dpkg -s "$package" >/dev/null 2>&1 ; then
                echo "⚡  $package needs to be installed"
                sudoIfNeeded apt-get install -y "$package"
            fi
        done
    done
}


function do_dumpInstalledExe()
{
    local __exe_name="$1"

    local _run_from_here
    local _version

    _run_from_here="$(command -v "${__exe_name}" 2>/dev/null || true)"

    if [[ -z "${_run_from_here}" ]] ; then
        echo "    ❌ ERROR: Executable not found after installation: ${__exe_name}"
        return 1
    fi
    if ! _version="$(${__exe_name} --version 2>/dev/null )" ; then
        echo -e "   ❌ FAILED TO INSTALL: ${__exe_name}   Confirm installation issues with ${COLOUR[VIVID_BLUE_STDOUT]:-}${__exe_name} --version${COLOUR[OFF_STDOUT]:-}"
        return 1
    fi
    echo -e "    • Installed: ${COLOUR[VIVID_BLUE_STDOUT]:-}${_version}${COLOUR[OFF_STDOUT]:-}" | sed --unbuffered '1!s/^/                 /'

    if [[ "${SUGGEST_HOW_TO_INSTALL_TO_ROOT:-}" == 'yes' ]] ; then
        if [[ "$_run_from_here" == "${HOME%/}/.local/bin/${__exe_name}" ]] ; then
            echo "                                                              (To install as root: sudo cp ~/.local/bin/${__exe_name} /usr/local/bin/)"
        fi
    fi
}


function do_clearDestinationFile()
{
    local fname_actual="$1"


    local note=''
    [[ "${AM_CLEANING}" == 'yes' ]] || note=' existing'


    if [[ -L "$fname_actual" ]] ; then
        unlink "$fname_actual"
        echo "    • Unlinked${note}: $(displayPath "$fname_actual")"
    elif [[ -f "$fname_actual" ]] ; then
        rm -f "$fname_actual"
        echo "    • Erased${note}: $(displayPath "$fname_actual")"
    elif [[ "${AM_CLEANING}" == 'yes' ]] ; then
        echo "    • Confirmed removed: $(displayPath "$fname_actual")"
    fi
}



function do_exeInstall_orClean()
{
    local script="$1"
    shift 1 || true

    local _EXE_RUN    ; _EXE_RUN="$(realpath -m "${script}")"
    local _exe_name   ; _exe_name="$(basename "$_EXE_RUN")"

    _exe_name="${_exe_name%.*}" # Remove extension for the installed executable name


    local link="${INSTALL_DIR}/${_exe_name}"

    if [[ "${AM_CLEANING}" == 'yes' ]] ; then
        do_remove_link "$link"
    else
        do_ensure_link "$link" "$_EXE_RUN" && do_dumpInstalledExe "$_exe_name"
    fi
}


function doSetupPrecommitEnvironment()
{
    [[ "$option_precommit" != 'yes' ]]  && return 0
    [[ "${AM_CLEANING}"    == 'yes' ]] && return 0

    echo "   Setting up Precommit Environment"

    if [[ "$(type -t apps_doSetupPrecommitEnvironment)" == 'function' ]] ; then
        apps_doSetupPrecommitEnvironment
    else

        installPkgIfNeeded git
        if ! git-lfs --version 2>/dev/null ; then
            echo "⚡  git-lfs needs to be installed"
            installPkgIfNeeded curl
            curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh > /tmp/git-lfs-deb.sh
            sudoIfNeeded chmod +x /tmp/git-lfs-deb.sh
            sudoIfNeeded apt-get install -y git-lfs
            git lfs >/dev/null 2>/dev/null || git lfs install
        fi
        installPkgIfNeeded pre-commit
        installPkgIfNeeded nodejs
        if cmp -s "${BUILD_FUNCS_DIR%/}/_hacks/^usr^lib^python3^dist-packages^nodeenv.py/old" /usr/lib/python3/dist-packages/nodeenv.py ; then

            echo "⚠️  nodeenv.py is not patched, Overwriting (this is needed for nodeenv to work properly)"
            sudoIfNeeded cp "${BUILD_FUNCS_DIR%/}/_hacks/^usr^lib^python3^dist-packages^nodeenv.py/new" /usr/lib/python3/dist-packages/nodeenv.py
        fi
    fi
}

function doActions()
{
    export AM_CLEANING="${1##AM_CLEANING=}"
    if [[ "$(type -t apps_showHeaderTitle)" == 'function' ]] ; then
        apps_showHeaderTitle
        [[ "${AM_CLEANING:-}" == 'yes' ]] && echo "   Cleaning all outputs"
    elif [[ "${AM_CLEANING:-}" == 'yes' ]] ; then
        echo "🔨 Cleaning ${APPS_NAME}"
    else
        echo "🔨 Building ${APPS_NAME}"
    fi

    [[ "${AM_CLEANING:-}" != 'yes' ]] && [[ "${ENSURE_SUBMODULES_ARE_CLONED:-yes}" == 'yes' ]] && git_failIfSubmodulesArentCloned "${PROJ_DIR}"


    if [[ " $* " == *" --only=source_generate "* ]] ; then
        echo -n "   Only generating sources, not generating applications"
            [[ "${PYTHON_ENV_HERE:-}" == '_none_' ]] || echo -n " nor build virtual environments"
        echo ""
        do_protoGenerate_orClean "    ⚠️  No proto files found - No sources generated" || FATAL_FAILURE_NO_RETURN "Failed to generate proto files."
    else
        #|x|echo "   ℹ️ Generating build environment etc etc etc ...  (Params: $*)"
        setupBuildEnvironment "$@"  || FATAL_FAILURE_NO_RETURN "Failed to set up build environment."

        do_protoGenerate_orClean  || FATAL_FAILURE_NO_RETURN "Failed to generate proto files."

        cd "${PROJ_DIR:-}" || true

        found_list=""
        if [[ "$(type -t apps_checkSourceValidity)"          == 'function' ]] ; then
            apps_checkSourceValidity || FATAL_FAILURE_NO_RETURN "Source validity check failed."
        fi
        if [[ "$(type -t pre_doInstallOrClean)"              == 'function' ]] ; then
            pre_doInstallOrClean || FATAL_FAILURE_NO_RETURN "Failed to install pre-installation dependencies."
        fi
        if [[ "$(type -t apps_doBuildOrClean)"               == 'function' ]] ; then
            found_list+='[apps_doBuildOrClean]'
            apps_doBuildOrClean || FATAL_FAILURE_NO_RETURN "apps_doBuildOrClean() failed"
        fi
        if [[ "$(type -t apps_doInstallOrClean)"             == 'function' ]] ; then
            found_list+='[apps_doInstallOrClean]'
            apps_doInstallOrClean || FATAL_FAILURE_NO_RETURN "apps_doInstallOrClean() failed"
        fi
        if  [[ "$(type -t apps_doInstallTestingDependencies)" == 'function' ]] && [[ "$option_with_tests" != 'no' ]] ; then
            apps_doInstallTestingDependencies || FATAL_FAILURE_NO_RETURN "apps_doInstallTestingDependencies() failed"
        fi

        if [[ -z "${found_list}" ]] ; then
            _paths=()
            for x in "${BASH_SOURCE[@]}"; do
                [[ "${x}" == *'.inc.bash' ]] || _paths+=("${x}")
            done
            FATAL_FAILURE_NO_RETURN "No main(), apps_doBuildOrClean() or apps_doInstallOrClean() function found in $(displayPathList "${_paths[@]}")"
        fi
    fi
}








function runTests()
{
    local tests=("${EXE_DIR%/}/do-run-tests.sh"  "${PROJ_DIR%/}/testing/do-run-tests.sh")
    [[ "${EXE_DIR}" == "${PROJ_DIR}" ]] || tests=("${PROJ_DIR%/}/do-run-tests.sh")

    local tests_list=()
    for x in "${tests[@]}" ; do
        if [[ -x "${x}" ]] ; then
            echo "Running tests ...  ($(displayPath "${x}")"
            "${x}" || FATAL_FAILURE_NO_RETURN "Tests failed: Please check the output above."
            return 0
        fi
        tests_list+=("$(displayPath "${x}")")
    done
    FATAL_FAILURE_NO_RETURN "Tests failed: Missing [$(asCsvList "${tests_list[@]}")]"
}




BUILD_FUNCS_DIR="$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")"


source "${BUILD_FUNCS_DIR%/}/_internalUse/lib-git.inc.bash"
source "${BUILD_FUNCS_DIR%/}/_internalUse/lib-building-ros.inc.bash"
source "${BUILD_FUNCS_DIR%/}/_internalUse/lib-building-python.inc.bash"
source "${BUILD_FUNCS_DIR%/}/_internalUse/lib-building-systemd.inc.bash"
source "${BUILD_FUNCS_DIR%/}/_internalUse/lib-building-protobuf.inc.bash"


source "${BUILD_FUNCS_DIR%/}/lib-app.inc.bash"
