# shellcheck shell=bash


#=================================================================================================================
#
# For Python Projects
#

# shellcheck disable=SC2317
function do_setupPython3()
{
    do_setupPython3_Done='yes'
    installPkgIfNeeded python3
    if [[ "$AM_CLEANING" == 'yes' ]] ; then
        pyApp_cleanIfNeeded
    else
        python3_subver="$(python3 --version | sed 's|^Python 3\.||g' | sed 's|\..*$||g')"

        local _devReason=''
        source /etc/os-release
        if [[ "${PRETTY_NAME:-}" == *"development"* ]] ; then
            _devReason="$PRETTY_NAME"
        elif [[ "${1:-}" == '--dev' ]] ; then
            _devReason='--dev provided'
        fi
        if [[ -n "$_devReason" ]] ; then
            echo -e "   Detected ${COLOUR[VIVID_BLUE_STDOUT]:-}Python 3.${python3_subver}${COLOUR[OFF_STDOUT]:-}  -- Installing development packages [$_devReason]"
            installPkgIfNeeded build-essential    #< Depending on environment, this may be needed to build some Python dependencies (e.g., 'cryptography' package)
            installPkgIfNeeded python3-dev
        else
            echo -e "   Detected ${COLOUR[VIVID_BLUE_STDOUT]:-}Python 3.${python3_subver}${COLOUR[OFF_STDOUT]:-}  in ${PRETTY_NAME:-}"
        fi

        export PYTHON_VERSION="3.${python3_subver}"
        do_pythonEnvIfNeeded
    fi


}
function pyApp_cleanIfNeeded()
{
    if [[ "${AM_CLEANING}" == 'yes' ]] ; then
        echo "   Cleaning python cache files" # from $(pwd)"
        find "${EXE_DIR}" -type d -name '.venv' | forceDelete "     "
        find "${EXE_DIR}" -type d -name '__pycache__' | forceDelete "     "
        find "${EXE_DIR}"         -name '*.pyc' | forceDelete "     "
        find "${EXE_DIR}"         -name '*.pyo' | forceDelete "     "
        find "${EXE_DIR}"         -name '*.pyd' | forceDelete "     "
    fi
}

#=================================================================================================================
#
# Python Environment setup and management
#
function do_pythonEnvIfNeeded()
{
    [[ -z "${PYTHON_ENV_HERE:-}" ]] && set_PYTHON_ENV_HERE "${EXE_DIR}"
    if [[  "${PYTHON_ENV_HERE}" != "_none_" ]] ; then
        installPkgIfNeeded python3-pip
        [[ "$AM_CLEANING" == 'yes' ]] || installPkgIfNeeded "python3.${python3_subver}-venv"
        do_setupPythonVenv_orClean ''
    fi
}

function set_PYTHON_ENV_HERE()
{
    function _failAtLocation()
    {
        local failLocation="$1"

        FATAL_FAILURE_NO_RETURN "ERROR: Could not find requirements*.txt in ${COLOUR[VIVID_BLUE_STDOUT]:-}${startPath}${COLOUR[OFF_STDOUT]:-} or any parent directory up to ${COLOUR[VIVID_BLUE_STDOUT]:-}${failLocation}${COLOUR[OFF_STDOUT]:-}\nDefine the location manually as 'PYTHON_ENV_HERE' (or PYTHON_ENV_HERE=_none_) if needed."
    }
    local startPath="${1:-}"
    [[ -n "${startPath}" ]] || FATAL_FAILURE_NO_RETURN "set_PYTHON_ENV_HERE(): No start path provided"
    PYTHON_ENV_HERE="$(realpath -m "${startPath%/}")"
    local counter=0
    while true ; do
        readarray -t _found < <(find "${PYTHON_ENV_HERE%/}" -maxdepth 1 -type f -name "requirements*.txt") || true
        [[ "${#_found[@]}" -gt 0 ]] && return 0
        if [[ "${PYTHON_ENV_HERE}" == "/" ]] || [[ -z "${PYTHON_ENV_HERE}" ]] ; then
            _failAtLocation "/"
        elif [[ "${PYTHON_ENV_HERE%/}" == "${HOME%/}" ]] ; then
            _failAtLocation "${HOME}"
        else
            counter=$((counter + 1))
            [[ $counter -gt 9 ]] && _failAtLocation "$counter levels up: ${PYTHON_ENV_HERE}"
        fi
        PYTHON_ENV_HERE="$(dirname "${PYTHON_ENV_HERE%/}")"
    done
}

#
#
# shellcheck disable=SC2317
function do_setupPythonVenv_orClean()
{
    ###############################
    #
    [[ "${PYTHON_ENV_HERE}" == "_none_" ]] && return 0 # Skip if PYTHON_ENV_HERE is set to _none_

    [[ -n "${1:-}" ]] && PYTHON_ENV_HERE="${1}"
    [[ -z "${PYTHON_ENV_HERE:-}" ]] && PYTHON_ENV_HERE="${EXE_DIR}"

    [[ "${PYTHON_ENV_SETUP_SKIP:-}" == "${PYTHON_ENV_HERE}" ]] && echo "   Using Python .venv: $(displayPath "${PYTHON_ENV_HERE}")" && return 0

    if [[ "${AM_CLEANING}" == 'yes' ]] ; then
        echo "   Clearing virtual environment in $(displayPath "${PYTHON_ENV_HERE%/}/.venv")"
        rm -rf "${PYTHON_ENV_HERE%/}/.venv" || true
        return 0
    fi

    pushd "${PYTHON_ENV_HERE%/}" >/dev/null || true
    {
        {
            python3_subver="$(python3 --version | sed 's|^Python 3\.||g' | sed 's|\..*$||g')"

            echo "   Setting up virtual environment for Python 3.${python3_subver} in $(displayPath "${PYTHON_ENV_HERE%/}/.venv")"
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
                    FATAL_FAILURE_NO_RETURN "Failed to setup Python virtual environment: No requirements suitable file found"
                fi
            fi
            [[ -d .venv ]] && [[ $(stat -c '%u' .venv) -ne $(id -u) ]] && [[ -w .venv ]] && rm -rf .venv  # Ensure that we are the owner of the
            [[ -d .venv ]] && [[ ! -w .venv ]] && FATAL_FAILURE_NO_RETURN "The virtual environment '${PYTHON_ENV_HERE%/}/.venv' is not writable.\nTry ${COLOUR[VIVID_BLUE_STDOUT]:-}${ORIG_EXE_CMD_AS_DISPLAY:-"$0"} --clean${COLOUR[OFF_STDOUT]:-}"
            python3 -m venv .venv
            if [[ -f ".venv/bin/activate" ]] ; then
                # shellcheck disable=SC1091
                source .venv/bin/activate # to enter the virtual environment
            elif [[ -f ".venv/local/bin/activate" ]] ; then
                # shellcheck disable=SC1091
                source .venv/local/bin/activate # to enter the virtual environment (some virtualenv versions put it here)
            else
                FATAL_FAILURE_NO_RETURN "Failed to setup Python virtual environment\nActivate script not found after creating virtual environment"
            fi

            echo "   │  Installing requirements from ${requirements_fname}"
            pip install -r "${requirements_fname}" | grep -v '^Requirement already satisfied:' | withPrefix "   │ "
            [[ "${PIPESTATUS[0]}" == 0 ]] || FATAL_FAILURE_NO_RETURN "pip install failure: Please check the output above."

            font_target=".venv/lib/python3.${python3_subver}/site-packages/cv2/qt/fonts"
            if [[ ! -d "/usr/share/fonts/truetype/dejavu" ]] && [[ -d "$font_target" ]] ; then
                #
                # Install fonts for QT apps - otherwise it complains about not finding them
                #
                do_ensure_link "/usr/share/fonts/truetype/dejavu" "$font_target"
            else
                true
            fi
        }  || FATAL_FAILURE_NO_RETURN "Failed to setup Python virtual environment: Please check the output above."
        echo "   └─ Done"
    }
    popd >/dev/null || true
}


# shellcheck disable=SC2317
function do_pyInstall_orClean()
{
    [[ "${do_setupPython3_Done:-}" == 'yes' ]] || do_setupPython3 ""

    local _PYAPP_RUN   ; _PYAPP_RUN="$(realpath -m "${1}")"
    local _exe_name    ; _exe_name="$(basename "$_PYAPP_RUN" '.py')"
    shift 1 || true # Remove the processed argument

    while [[ "${1:-}" == --uses-pkg=* ]] ; do
        local pkg="${1#--uses-pkg=}"
        installPkgIfNeeded "$pkg"
        shift 1 || true
    done

    local _PYAPP_INSTALL_SOURCE ; _PYAPP_INSTALL_SOURCE="${INSTALL_DIR}/${_exe_name}"


    do_clearDestinationFile "$_PYAPP_INSTALL_SOURCE" || return 1
    [[ "${AM_CLEANING}" == 'yes' ]] && return 0



    if [[ "${PYTHON_ENV_HERE}" == "_none_" ]] && [[ -f "${_PYAPP_RUN}" ]] && [[ "$*" == '' ]] ; then
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

    local _PYAPP_ENV=''; [[ "$PYTHON_ENV_HERE" == "_none_" ]] || _PYAPP_ENV="$(realpath -m "${PYTHON_ENV_HERE%/}/.venv")"


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

        echo ''

        if [[ "${1:-}" == '--source-start' ]] ; then
            echo 'set +u'

            shift 1 || true
            for arg in "$@"; do
                shift 1 || true
                if [[ "$arg" == '--source-end' ]] ; then
                    break
                fi
                echo "$arg"
            done
            echo 'set -u'
        fi

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

    echo "    • Created: $(displayPath "$_PYAPP_INSTALL_SOURCE") → $(displayPath "$_PYAPP_RUN")"
    do_dumpInstalledExe "$_exe_name"
}


#
#=================================================================================================================
