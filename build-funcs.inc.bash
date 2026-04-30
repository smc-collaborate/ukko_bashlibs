# shellcheck shell=bash
################
#
#
# IMPORT THIS AS A 'source' script
#   source bashlib/build-funcs.inc.bash
#


############################################################################################################################################################
# A customisable python installer.
#
# 1. Setup build environment -- Runs: "${THIS_DIR%}/tools/do-setup-build-environment.sh"  -or-  apps_doSetupBuildEnvironment() if found
#
# 2. If apps_showHeaderTitle() is defined, it will be called to show a header title for the app being built.
#
# 3. Runs: apps_doInstallOrClean() to install the app's files, or clean them if --clean is passed.
#
# 4. Create Python .venv and install dependencies if needed.
#    It expects the 'requirements*.txt' to be in '$ENV_ROOT' (if defined) or '$THIS_DIR')
#
# 5. If there are '.proto' files in the 'proto*' subdirectories, they will be compiled to Python using 'protoc' and the generated files will be placed in '$THIS_DIR/proto_gen'.
#
# 6. Customising includes:
#     -- ENV_ROOT=                   - Use __none__ to skip creating a virtual environment and installing dependencies there.
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
#| │ THIS_DIR="$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")"
#| │ source "${THIS_DIR%/}/../tools/build-funcs.inc.bash"
#| ╰─────────────────────────────────────────────────────────
############################

BUILD_FUNCS_DIR="$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")"
source "${BUILD_FUNCS_DIR%/}/utils.inc.bash"

if [[ -z "${APPS_NAME:-}" ]] ; then
    APPS_NAME="${THIS_DIR##*/}"
fi
function set_ENV_ROOT()
{
    if [[ -z "${ENV_ROOT:-}" ]] ; then
        ENV_ROOT="$(realpath -m "${THIS_DIR%/}")"
        counter=0
        failLocation=''
        while [[ -z "${failLocation}" ]] ; do
            readarray -t _found < <(find "${ENV_ROOT%/}" -maxdepth 1 -type f -name "requirements*.txt") || true
            [[ "${#_found[@]}" -gt 0 ]] && break
            if [[ "${ENV_ROOT}" == "/" ]] || [[ -z "${ENV_ROOT}" ]] ; then
                failLocation="/"
            elif [[ "${ENV_ROOT%/}" == "${HOME%/}" ]] ; then
                failLocation="${HOME}"
            else
                counter=$((counter + 1))
                [[ $counter -gt 9 ]] && failLocation="$counter levels up: ${ENV_ROOT}"
            fi
            ENV_ROOT="$(dirname "${ENV_ROOT%/}")"
        done
        if [[ -n "${failLocation}" ]] ; then
            echo -e "❌  ERROR: Could not find requirements*.txt in ${BOLD_BLUE_STDOUT:-}${THIS_DIR}${NC_STDOUT:-} or any parent directory up to ${BOLD_BLUE_STDOUT:-}${failLocation}${NC_STDOUT:-}"
            echo    "    Define the location manually as 'ENV_ROOT' environment variable if needed."

            exit 1
        fi
    fi
}

set_ENV_ROOT

[[ -z "${SUGGEST_HOW_TO_INSTALL_TO_ROOT:-}" ]] && SUGGEST_HOW_TO_INSTALL_TO_ROOT=yes

function do_protoGenerate_orClean()
{
    local msg_on_none_found="${1:-}"
    local found_proto_file='no'

    local dirsToReview=()

    for relative_dir in . common  ; do
        for fulldir in "${THIS_DIR%/}/${relative_dir}/proto_"*/ ; do
            #|Logging| echo "Checking for proto files in ${fulldir} ..."
            [[ -d "${fulldir}" ]] && dirsToReview+=("${fulldir}")
        done
    done
        for fulldir in "${dirsToReview[@]}" ; do
        pushd "${fulldir}" >/dev/null || true
            printable_dir="${fulldir#"${THIS_DIR%/}"/}"
            if [[ "${AM_CLEANING}" == 'yes' ]] && [[ -d "_generated" ]] ; then
                echo "   Proto directory[$printable_dir] - Cleaning _generated directory"
                rm -rf _generated #//-
            fi


            if [[ "${AM_CLEANING}" != 'yes' ]] ; then
                echo "   Proto directory[$printable_dir] - Generating protobuf code under _generated:"
                for proto_file in *.proto; do
                    [[ -f "$proto_file" ]] || continue
                    echo "    • ${printable_dir%/}/$proto_file"
                    found_proto_file='yes'
                done
                rm -rf _tmp_generated
                mkdir -p _tmp_generated
                if [[ "$(protoc --version)" == "libprotoc 3.12"*  ]] ; then
                    # Very old version of protobuf
                    # shellcheck disable=SC2035
                    protoc --experimental_allow_proto3_optional --python_out _tmp_generated *.proto
                else
                    # shellcheck disable=SC2035
                    protoc --python_out _tmp_generated *.proto
                fi


                readarray -t dirs <<< "$(find _tmp_generated -type d)"
                for dir in "${dirs[@]}" ; do
                    touch "${dir%/}/__init__.py"
                done
                touch "./__init__.py"
                mkdir -p _generated
                rsync -P -c -r _tmp_generated/* _generated | grep -v '^sending incremental file list$' || true
                rm -rf _tmp_generated
            fi

        popd >/dev/null || true
    done
    [[ "${found_proto_file}" == 'no' ]] && [[ -n "${msg_on_none_found}" ]] && echo "${msg_on_none_found}"
    return 0
}

function pyApp_cleanIfNeeded()
{
    if [[ "${clean_param}" == '--clean' ]] ; then
        echo "   Cleaning python cache files" # from $(pwd)"

        find . -name '*.pyc' -delete
        find . -name '*.pyo' -delete
        find . -name '*.pyd' -delete
        find . -name '__pycache__' -exec rm -rf {} +
    fi
}

function do_gitLfsCheck()
{
    local file_name="$1"
    local expected_size="${2:-}"

    if [[ ! -f "${file_name}" ]] ; then
        echo "❌ FAIL FAILURE: File not found: ${file_name}"
        exit 1
    fi

    local actual_size
    actual_size="$(stat -c %s "${file_name}")"


    if [[ -z "${expected_size}" ]] ; then
        [[ "$actual_size" -gt 1024 ]] && return 0

        echo "❌ $file_name is only $actual_size bytes long, which seems too small"
    else
        [[ "${actual_size}" == "${expected_size}" ]] && return 0

        echo "❌ $file_name is $actual_size bytes long instead of $expected_size"
    fi
        echo "This is usually caused by a cloning the repository without git-lfs installed"
        echo ""
        echo "To install git-lfs:"
        echo "╭───────────────────────────────────────────────────────────────────────────────────────────────────╮"
        echo "│ curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash     │"
        echo "│ sudo apt-get install git-lfs                                                                      │"
        echo "│ git lfs install                                                                                   │"
        echo "╰───────────────────────────────────────────────────────────────────────────────────────────────────╯"
        echo ""
        echo "After that, run: git lfs pull     -or- reclone the repository"
        exit 13
 }

#
# Ensure tools are installed
#
function exitWithError()
{
    local msg="${*##❌}"

    local lines=()
    local prefix="❌  "

    msg="$(echo -e "$msg")"
    readarray -t lines <<< "$msg"
    for x in "${lines[@]}" ; do
        echo -e "$prefix$x"
        prefix='    '
    done
    exit 1
}
function setupBuildEnvironment()
{
    [[ "$(type -t apps_doSetupBuildEnvironment)" != 'function' ]] && [[ ! -f "${THIS_DIR%/}/tools/do-setup-build-environment.sh" ]] && return 0 # No setup needed

    if [[ "${clean_param}" == '--clean' ]] ; then
        echo "   Clearing   Build Environment"
    else
        echo "   Setting up Build Environment"
    fi


    {
        if [[ "$(type -t apps_doSetupBuildEnvironment)" == 'function' ]] ; then
            apps_doSetupBuildEnvironment                                  || exitWithError "❌  Failed to setup build environment[apps_doSetupBuildEnvironment()]: Please check the output above."
        fi
        if [[ -f "${THIS_DIR%/}/tools/do-setup-build-environment.sh" ]] ; then
            [[  -x "${THIS_DIR%/}/tools/do-setup-build-environment.sh" ]] || exitWithError "❌  Failed to smpetup build environment[${THIS_DIR%/}/tools/do-setup-build-environment.sh]: Not executable"
            "${THIS_DIR%/}/tools/do-setup-build-environment.sh"           || exitWithError "❌  Failed to setup build environment[${THIS_DIR%/}/tools/do-setup-build-environment.sh]: Please check the output above."
        fi
    } | sed 's/^/   │ /'
    [[ "${PIPESTATUS[0]}" == 0 ]] || exit 1
    echo "   └─ Done"
}

function do_setupPython3()
{
    installPkgIfNeeded python3
    if [[ "$AM_CLEANING" != 'yes' ]] ; then
        python3_subver="$(python3 --version | sed 's|^Python 3\.||g' | sed 's|\..*$||g')"

        if [[ "${1:-}" == '--dev' ]] ; then
            echo -e "   Detected ${BOLD_BLUE_STDOUT:-}Python 3.${python3_subver}${NC_STDOUT:-}  -- Installing development packages"
            installPkgIfNeeded build-essential    #< Depending on environment, this may be needed to build some Python dependencies (e.g., 'cryptography' package)
            installPkgIfNeeded python3-dev
        else
            echo -e "   Detected ${BOLD_BLUE_STDOUT:-}Python 3.${python3_subver}${NC_STDOUT:-}  -- Not installing development packages"
        fi
    fi

    if [[  "${ENV_ROOT}" != "_none_" ]] ; then
        installPkgIfNeeded python3-pip
        [[ "$AM_CLEANING" == 'yes' ]] || installPkgIfNeeded "python3.${python3_subver}-venv"
        do_setupPythonVenv_orClean ''
    fi
}
#
#
function do_setupPythonVenv_orClean()
{
    ###############################
    #
    [[ "${ENV_ROOT}" == "_none_" ]] && return 0 # Skip if ENV_ROOT is set to _none_

    [[ -n "${1:-}" ]] && ENV_ROOT="${1}"
    [[ -z "${ENV_ROOT:-}" ]] && ENV_ROOT="${THIS_DIR}"

    [[ "${ENV_ROOT_SETUP_SKIP:-}" == "${ENV_ROOT}" ]] && echo "   Using Python .venv: $ENV_ROOT" && return 0

    if [[ "${clean_param}" == '--clean' ]] ; then
        echo "   Clearing virtual environment in ${ENV_ROOT%/}/.venv" | sed "s|$HOME|~|g"
        rm -rf "${ENV_ROOT%/}/.venv" || true
        return 0
    fi

    pushd "${ENV_ROOT%/}" >/dev/null || true
    {
        {
            python3_subver="$(python3 --version | sed 's|^Python 3\.||g' | sed 's|\..*$||g')"

            echo "   Setting up virtual environment for Python 3.${python3_subver} in ${ENV_ROOT%/}/.venv" | sed "s|$HOME|~|g"
            requirements_fname=''
            if [[ -f "requirements-python3.${python3_subver}.txt" ]] ; then
                requirements_fname="requirements-python3.${python3_subver}.txt"
            else
                echo "   ⚠️  No requirements-python3.${python3_subver}.txt found"

                readarray -t _found < <(find . -mindepth 1 -maxdepth 1 -type f -name "requirements*.txt") || true
                for f in "${_found[@]}" ; do
                    echo "       • Found requirements file: ${f##./}"
                done

                if [[ -f "requirements-default.txt" ]] ; then
                    requirements_fname="requirements-default.txt"
                    echo "      • Using '$requirements_fname' as fallback"
                else
                    exitWithError "Failed to setup Python virtual environment: No requirements suitable file found"
                fi
            fi
            [[ -d .venv ]] && [[ ! -w .venv ]] && exitWithError "The virtual environment '${ENV_ROOT%/}/.venv' is not writable.\nTry ${BOLD_BLUE_STDOUT:-}sudo ${THIS_EXE_FROM_ORIGINAL_PWD:-"$0"} --clean${NC_STDOUT:-} to remove it"
            python3 -m venv .venv
            if [[ -f ".venv/bin/activate" ]] ; then
                # shellcheck disable=SC1091
                source .venv/bin/activate # to enter the virtual environment
            elif [[ -f ".venv/local/bin/activate" ]] ; then
                # shellcheck disable=SC1091
                source .venv/local/bin/activate # to enter the virtual environment (some virtualenv versions put it here)
            else
                exitWithError "Failed to setup Python virtual environment\nActivate script not found after creating virtual environment"
            fi


            echo "   Installing requirements from ${requirements_fname}"
            pip install -r "${requirements_fname}" # | grep -v '^Requirement already satisfied:' || true

            if [[ -d "/usr/share/fonts/truetype/dejavu" ]] ; then
                #
                # Install fonts for QT apps - otherwise it complains about not finding them
                #

                mkdir -p ".venv/lib/python3.${python3_subver}/site-packages/cv2/qt"
                unlink ".venv/lib/python3.${python3_subver}/site-packages/cv2/qt/fonts" 2>/dev/null || true
                ln -s /usr/share/fonts/truetype/dejavu ".venv/lib/python3.${python3_subver}/site-packages/cv2/qt/fonts"
            else
                true
            fi
        } # | sed 's/^/   │ /'
        [[ "${PIPESTATUS[0]}" == 0 ]] || exitWithError "❌  Failed to setup Python virtual environment: Please check the output above."
        echo "   └─ Done"
    }
    popd >/dev/null || true
}
function sudoIfNeeded() {
    export DEBIAN_FRONTEND=noninteractive
    if [[ "$(id -u)" -ne 0 ]] ; then
        sudo "$@"
    else
        "$@"
    fi
}

function installPkgIfNeeded()
{
    [[ "${clean_param:-}" == '--clean' ]] && return 0

    local package="$1"

    if [[ -z "$package" ]] ; then
        echo "❌  installPkgIfNeeded called with empty package name"
        return 1
    elif ! dpkg -s "$package" >/dev/null 2>&1 ; then
        echo "⚡  $package needs to be installed"
        sudoIfNeeded apt-get install -y "$package"
    fi
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
        echo -e "   ❌ FAILED TO INSTALL: ${__exe_name}   Confirm installation issues with ${BOLD_BLUE_STDOUT:-}${__exe_name} --version${NC_STDOUT:-}"
        return 1
    fi
    echo -e "    • Installed: ${BOLD_BLUE_STDOUT:-}${_version}${NC_STDOUT:-}" | sed '1!s/^/                 /'

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

function do_pyInstall_orClean()
{
    local _PYAPP_RUN   ; _PYAPP_RUN="$(realpath -m "${1}")"
    local _PYAPP_ENV=''; [[ "$ENV_ROOT" == "_none_" ]] || _PYAPP_ENV="$(realpath -m "${ENV_ROOT%/}/.venv")"
    local _exe_name    ; _exe_name="$(basename "$_PYAPP_RUN" '.py')"
    shift 1 || true # Remove the processed argument


    if [[ "${_PYAPP_ENV}" == "_none_" ]] && [[ -f "${_PYAPP_RUN}" ]] && [[ "$*" == '' ]] ; then
        #
        # Is this suitable for a direct link instead?
        #
        if [[ -x "${_PYAPP_RUN}" ]] && head -n 1 "$_PYAPP_RUN" | grep '^#!/' 2>/dev/null 1>/dev/null ; then
            echo "ℹ️  $_exe_name is treated as direct link to $(basename "$_PYAPP_RUN")"
            do_exeInstall_orClean "$_PYAPP_RUN" || return 1
            return 0
        fi
        echo "⚡  If $_exe_name is made executable with '#!/bin/python3' at the top it could be created as a direct link"
    fi

    local INSTALL_DIR="${HOME%/}/.local/bin" ; [[ "$EUID" -eq 0 ]] && INSTALL_DIR="/usr/local/bin"
    local _PYAPP_INSTALL_SOURCE ; _PYAPP_INSTALL_SOURCE="${INSTALL_DIR}/${_exe_name}"


    do_clearDestinationFile "$_PYAPP_INSTALL_SOURCE" || return 1
    [[ "${AM_CLEANING}" == 'yes' ]] && return 0

    [[ -f "$_PYAPP_RUN" ]] || FATAL_FAILURE_NO_RETURN "Python script not found: $_PYAPP_RUN"
    mkdir -p "${INSTALL_DIR}"
    {
        echo '#!/bin/bash -eu'
        #| echo 'echo "BASH_SOURCE[0]=${BASH_SOURCE[0]}"'
        # shellcheck disable=SC2016
        echo 'export PYAPP_INSTALL_SOURCE="$(realpath -m "${BASH_SOURCE[0]}")"'
        # shellcheck disable=SC2016
        [[ -z "${_PYAPP_ENV}" ]] || echo "export PYAPP_ENV=\"${_PYAPP_ENV}\""
        # shellcheck disable=SC2016
        echo "export PYAPP_RUN=\"${_PYAPP_RUN}\""

        #| echo 'echo " • PYAPP_INSTALL_SOURCE="$(realpath -m "${BASH_SOURCE[0]}")""'
        #| echo 'echo " • PYAPP_ENV=\"${PYAPP_ENV}\""'
        #| echo 'echo " • PYAPP_RUN=\"${PYAPP_RUN}\""'

        echo ''
        if [[ -n "${_PYAPP_ENV}" ]] ; then
            # shellcheck disable=SC2016
            echo '"${PYAPP_ENV}/bin/python" "${PYAPP_RUN}"' "$@" '"$@"'
        else
            # shellcheck disable=SC2016
            echo 'python3                   "${PYAPP_RUN}"' "$@" '"$@"'
        fi
    } > "$_PYAPP_INSTALL_SOURCE"
    chmod +x "$_PYAPP_INSTALL_SOURCE"

    echo "    • Created: $(displayPath "$_PYAPP_INSTALL_SOURCE") -> $(displayPath "$_PYAPP_RUN")"
    do_dumpInstalledExe "$_exe_name"
}



function do_exeInstall_orClean()
{
    local script="$1"
    shift 1 || true

    local INSTALL_DIR="${HOME%/}/.local/bin" ; [[ "$EUID" -eq 0 ]] && INSTALL_DIR="/usr/local/bin"
    local _EXE_RUN ; _EXE_RUN="$(realpath -m "${script}")"
    local _exe_name  ; _exe_name="$(basename "$_EXE_RUN")"

    _exe_name="${_exe_name%.*}" # Remove extension for the installed executable name


    local _EXE_INSTALL_LINK="${INSTALL_DIR}/${_exe_name}"

    do_clearDestinationFile "$_PYAPP_INSTALL_SOURCE" || return 1
    [[ "${AM_CLEANING}" == 'yes' ]] && return 0

    [[ -f "$_EXE_RUN" ]] || FATAL_FAILURE_NO_RETURN "Executable not found: $_EXE_RUN"

    ln -s "$_EXE_RUN" "$_EXE_INSTALL_LINK"
    echo "    • Linked: $(displayPath "$_EXE_INSTALL_LINK")  -> $(displayPath "$_EXE_RUN")"
    do_dumpInstalledExe "$_exe_name"
}

function do_remove_link()
{
    local link="$1"
    local optional_unless_target="${2:-}"
    if [[ -L "$link" ]] ; then
        if [[ -n "${optional_unless_target}" ]] && [[ "$(readlink -f "$link")" == "$(readlink -f "$optional_unless_target")" ]] ; then
            echo "    • Link confirmed: $(displayPath "$link") -> $(displayPath "$optional_unless_target")"
            return 0
        fi
        unlink "$link"
        echo "    • Unlinked existing: $(displayPath "$link")"
    elif [[ -e "$link" ]] ; then
        rm -rf "$link"
        echo "    • Removed existing file/directory: $(displayPath "$link")"
    fi
}

function do_ensure_link()
{
    local link="$1"
    local target="$2"
    if [[ "${AM_CLEANING}" == 'yes' ]] ; then
        do_remove_link "$link"
        return $?
    fi

    if [[ -L "$link" ]] && [[ "$(readlink -f "$link")" == "$(readlink -f "$target")" ]] ; then
            echo "    • Link confirmed: $link -> $(displayPath "$target")"
            return 0
        fi

    do_remove_link "$link"
    ln -s "$target" "$link"
    echo "    • Created link: $link -> $(displayPath "$target")"
}

function do_ensure_linked_git_checkout()
{
    local local_repo_link="$1"
    local repo="$2"

    if [[ "${AM_CLEANING}" == 'yes' ]] ; then
        do_remove_link "$local_repo_link"
        return $?
    else

        local dir
        dir="$(git-shared-checkout "$repo")"

        do_ensure_link "$local_repo_link" "${dir%/}/"
    fi
}

function do_serviceInstall_orClean()
{
    exe_name="${1:-}"
    exe_full_path="$(realpath -m "$2")"

    shift 2 || true # Remove the first two arguments, so that $@ now contains only the arguments to the service executable

    fail_msg=""
    if [[ "${AM_CLEANING}" == 'yes' ]] ; then
        sudoIfNeeded "${BUILD_FUNCS_DIR%/}/do-install-service.sh" --remove "$exe_name"|| fail_msg="remove"
    elif [[ ! -f "${exe_full_path}" ]]; then
        FATAL_FAILURE_NO_RETURN "Executable not found: $(displayPath "${exe_full_path}")"
    elif [[ ! -x "${exe_full_path}" ]]; then
        FATAL_FAILURE_NO_RETURN "Not executable      : $(displayPath "${exe_full_path}")"
    else
        sudoIfNeeded "${BUILD_FUNCS_DIR%/}/do-install-service.sh" "--user=$USER" "--working-dir=$THIS_DIR" "$exe_name" "$exe_full_path" "$@"|| fail_msg="install"
    fi

    [[ -z "$fail_msg" ]] && return 0

    echo "❌ Failed to $fail_msg service: $exe_name"
    return 1
}

function do_serviceInstall_py_orClean()
{
    local script="${1:-}"
    shift 1

    [[ -f "${script}" ]] || FATAL_FAILURE_NO_RETURN "Python Script not found: $(displayPath "${script}")"

    local exe="/usr/bin/python3"

    [[ "$ENV_ROOT" == "_none_" ]] || exe="$(realpath -m "${ENV_ROOT%/}/.venv")/bin/python"

    do_serviceInstall_orClean "$(basename "$script" '.py')" "$exe" "$script" "$@" || return 1
    return 0
}

cd "${THIS_DIR%/}" || true



if [[ "$(type -t main)" != 'function' ]] ; then

    function main()
    {
        if [[ "$(type -t apps_showHeaderTitle)" == 'function' ]] ; then
            apps_showHeaderTitle
            [[ "${AM_CLEANING:-}" == 'yes' ]] && echo "   Cleaning all outputs"
        else

            if [[ "${AM_CLEANING:-}" == 'yes' ]] ; then
                echo "🔨 Cleaning ${APPS_NAME}"
            else
                echo "🔨 Building ${APPS_NAME}"
            fi
        fi

        pyApp_cleanIfNeeded

        if [[ " $* " == *" --only=source_generate "* ]] ; then
            echo -n "   Only generating sources, not generating applications"
             [[ "${ENV_ROOT:-}" == '_none_' ]] || echo -n " or build virtual environments"
            echo ""
            do_protoGenerate_orClean "    ⚠️  No proto files found - No sources generated"
        else
            #|x|echo "   ℹ️ Generating build environment etc etc etc ...  (Params: $*)"
            setupBuildEnvironment

            do_protoGenerate_orClean

            cd "${THIS_DIR}" || true

            if [[ "$(type -t apps_checkSourceValidity)" == 'function' ]] ; then
                apps_checkSourceValidity
            fi

            found_list=""
            if [[ "$(type -t apps_doBuildOrClean)" == 'function' ]] ; then
                apps_doBuildOrClean
                found_list+='[apps_buildOrClean]'
            fi
            if [[ "$(type -t apps_doInstallOrClean)" == 'function' ]] ; then
                apps_doInstallOrClean
                found_list+='[apps_doInstallOrClean]'
            fi
            [[ -n "${found_list}" ]] || FATAL_FAILURE_NO_RETURN "No main(), apps_doBuildOrClean() or apps_doInstallOrClean() function found to run in ${BASH_SOURCE[0]}"
        fi
    }

fi

if [[ "${1:-}" == '--clean' ]] || [[ "${1:-}" == '--fresh' ]] || [[ "${1:-}" == '--remove' ]] ; then
    orig_pram="${1:-}"
    shift || true # Remove the first argument if it is --clean or --fresh
    clean_param="--clean"
    export AM_CLEANING='yes'
    main "$@"
    if [[ "${orig_pram:-}" == '--fresh' ]] ; then
        echo "   Fresh clean done - now building ..."
    else
        echo "   Clean done - All outputs cleaned"
        exit 0
    fi
fi
clean_param=""
export AM_CLEANING='no'

main "$@"
