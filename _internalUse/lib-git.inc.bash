# shellcheck shell=bash
# shellcheck disable=SC2317

function git_with_location_params_nice()
{
    local git_location="${1:-}"
    local path

    path="$(displayPath "${git_location}")"

    echo -n "git"
    [[ "${path}" == "." ]] || echo -n " -C $(quoteIfNeeded "${path}")"
}


function do_gitLfsCheck()
{
    [[ "${AM_CLEANING:-}" == 'yes' ]] && return 0
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


function do_ensure_linked_git_checkout()
{
    # |Logging| echo "!!! do_ensure_linked_git_checkout.Start($*)" >&2

    local local_repo_link="$1"
    local dir
    shift 1 || true
    if [[ "${AM_CLEANING}" == 'yes' ]] ; then
        do_remove_link "$local_repo_link" || FATAL_FAILURE_NO_RETURN "Failed to remove link for ${local_repo_link}"
    else
        dir="$(git-shared-checkout "$@" )" || FATAL_FAILURE_NO_RETURN "Failed to checkout git repository"
        do_ensure_link "$local_repo_link" "${dir%/}/"  || FATAL_FAILURE_NO_RETURN "Failed to ensure link for ${local_repo_link}"
    fi

    # |Logging| echo "!!! do_ensure_linked_git_checkout.End()" >&2
    return 0
}


# shellcheck disable=SC2317
function installLibIfNeeded()
{
    local _result=0
    # |Logging| echo "!!! installLibIfNeeded.Start($*)" >&2

    local git_url="$1"
    local libname="${git_url##*/}"
    libname="${libname%.git}"

    local dest_dir_parent

    if [[ -d "${EXE_DIR%/}/libs" ]] ; then
        dest_dir_parent="${EXE_DIR%/}/libs"
    else
        dest_dir_parent="${EXE_DIR%/}"
    fi
    local dest_dir="${dest_dir_parent%/}/${libname}"
    ###############
    #
    # Version ?
    #
    local lib_ver="${2:-}"
    local lib_ver_reason="Directly chosen"

    lib_ver="${lib_ver#--ref=}"  #< Just in case it wasn't stripped properly

    if [[ -z "${lib_ver:-}" ]] ; then
        local libname_ver="${libname^^}_VER"
        local libname_ver_default="${libname_ver}_DEFAULT"

        local lib_ver="${!libname_ver:-}"

        if [[ -n "$lib_ver" ]] ; then
            lib_ver_reason="Set with \$${libname_ver}"
        else
            lib_ver="${!libname_ver_default:-}"
            if [[ -n "$lib_ver" ]] ; then
                lib_ver_reason="Set with \$${libname_ver_default}"
            else
                lib_ver_reason="⚠️  No version specified - \$${libname_ver} not set)"
            fi
        fi
    fi

    local ref="${lib_ver:-}"

    [[ -z "$ref" ]] || [[ "${ref}" == "--ref="* ]] || ref="--ref=${ref}"


    if [[ "${AM_CLEANING}" == 'yes' ]] ; then
        do_remove_link "$dest_dir" || FATAL_FAILURE_NO_RETURN "Failed to remove link for ${dest_dir}"
    else
        echo -e "   Linking ${COLOUR[VIVID_BLUE_STDOUT]:-}$(displayPath "$dest_dir_parent")/${libname}${COLOUR[OFF_STDOUT]:-} → Shared ${COLOUR[VIVID_BLUE_STDOUT]:-}${git_url} ${ref#--ref=}${COLOUR[OFF_STDOUT]:-} ($lib_ver_reason)"

         do_ensure_linked_git_checkout  "${dest_dir}" "$git_url" "${ref}" || FATAL_FAILURE_NO_RETURN "Failed to link ${git_url} (${ref#--ref=}) to ${dest_dir}"
        local description
        description="$(git -C "$dest_dir" describe --always --dirty  2>/dev/null)" || FATAL_FAILURE_NO_RETURN "   ❌ Invalid git repository at $(displayPath "$dest_dir") for ${git_url}"
        [[ "$description" == *-dirty ]] && description="${description} ⚠️  With uncommited changes"
        echo "    • GitHash: ${description}"
    fi
    # |Logging| echo "!!! installLibIfNeeded.End()=$_result" >&2

    return "$_result"
}

# shellcheck disable=SC2317
function installFromGit()
{
    [[ "${AM_CLEANING}" == 'yes' ]] && return 0

    local exeName=''

    if [[ "${1}" == '--app='* ]] ; then
        exeName="${1#--app=}"
        shift 1 || true
    else
        exeName="$(basename "${1:-}" ".git")"
    fi

    # |Logging| echo "!!! installFromGit[$exeName] using: $*" >&2

    local version

    version="$("$exeName" --version 2>/dev/null | head -n1 | awk '{print $2}')" || true

    if [[ -n "$version" ]] ; then
        echo "   Already installed: $exeName (Version $version)"
        return 0
    fi

    dir="$(git-shared-checkout "$@" )" || return 1

    if [[ -x "${dir%/}/do-build-and-install.sh" ]] ; then
        echo "   Installing: $exeName from $(displayPath "${dir}")"
        "${dir}/do-build-and-install.sh" || return $?
    elif [[ -x "${dir%/}/do-install.sh" ]] ; then
        echo "   Installing: $exeName from $(displayPath "${dir}")"
        "${dir}/do-install.sh" || return $?
    else
        echo "   ❌ No install script found for: $exeName at $(displayPath "${dir}")"
        return 1
    fi

    version="$("$exeName" --version 2>/dev/null | head -n1 | awk '{print $2}')"

    if [[ -n "$version" ]] ; then
        echo "   Installed: $exeName (Version $version)"
        return 0
    fi

    echo "   ❌ Failed to install: $exeName"
    return 1
}

function git_failIfSubmodulesArentCloned()
{
    # shellcheck disable=SC1091
    if git -C "${1}" submodule 2>/dev/null | grep '^-' ; then
        echo -e "⚠️  Submodules not loaded.  Please use: '${COLOUR[VIVID_BLUE_USED]:-}$(git_with_location_params_nice "${1}") submodule update --init --recursive${COLOUR[OFF_USED]:-}'"
        echo    "    (You could also have used 'git clone --recurse-submodules' when cloning originally)"
        exit 3
    fi
    return 0
}
