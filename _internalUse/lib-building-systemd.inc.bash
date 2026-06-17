# shellcheck shell=bash
# shellcheck disable=SC2317

function do_serviceInstall_orClean()
{
    exe_name="${1:-}"
    exe_full_path="$(realpath -m "$2")"

    shift 2 || true # Remove the first two arguments, so that $@ now contains only the arguments to the service executable

    fail_msg=""
    if [[ "${AM_CLEANING}" == 'yes' ]] ; then
        sudoIfNeeded "${BUILD_FUNCS_DIR%/}/_internalUse/do-install-service.sh" --remove "$exe_name"|| fail_msg="remove"
    elif [[ ! -f "${exe_full_path}" ]]; then
        FATAL_FAILURE_NO_RETURN "Executable not found: $(displayPath "${exe_full_path}")"
    elif [[ ! -x "${exe_full_path}" ]]; then
        FATAL_FAILURE_NO_RETURN "Not executable      : $(displayPath "${exe_full_path}")"
    else
        sudoIfNeeded "${BUILD_FUNCS_DIR%/}/_internalUse/do-install-service.sh" "--user=$USER" "--working-dir=$THIS_DIR" "$exe_name" "$exe_full_path" "$@"|| fail_msg="install"
    fi

    [[ -z "$fail_msg" ]] && return 0

    echo "❌ Failed to $fail_msg service: $exe_name"
    return 1
}

function do_systemdEntry()
{
    fail_msg=""
    if [[ "${AM_CLEANING}" == 'yes' ]] ; then
        sudoIfNeeded "${BUILD_FUNCS_DIR%/}/_internalUse/do-install-service.sh" --remove --files "$@" || fail_msg="remove"
    else
        sudoIfNeeded "${BUILD_FUNCS_DIR%/}/_internalUse/do-install-service.sh"          --files "$@"|| fail_msg="install"
    fi

    [[ -z "$fail_msg" ]] && return 0

    echo "❌ Failed to $fail_msg systemd entry: $*"
    return 1
}

function do_serviceInstall_py_orClean()
{
    local script="${1:-}"
    shift 1

    [[ -f "${script}" ]] || FATAL_FAILURE_NO_RETURN "Python Script not found: $(displayPath "${script}")"

    local exe="/usr/bin/python3"

    [[ "$PYTHON_ENV_HERE" == "_none_" ]] || exe="$(realpath -m "${PYTHON_ENV_HERE%/}/.venv")/bin/python"

    do_serviceInstall_orClean "$(basename "$script" '.py')" "$exe" "$script" "$@" || return 1
    return 0
}
