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
    local local_repo_link="$1"
    shift 1 || true

    if [[ "${AM_CLEANING}" == 'yes' ]] ; then
        do_remove_link "$local_repo_link"
        return $?
    else

        local dir
        dir="$(git-shared-checkout "$@" )"

        do_ensure_link "$local_repo_link" "${dir%/}/"
    fi
}


# shellcheck disable=SC2317
function installLibIfNeeded()
{
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

    if [[ "${AM_CLEANING}" == 'yes' ]] ; then
        do_remove_link "$dest_dir"
        return $?
    else


        echo -e "   Linking ${COLOUR[VIVID_BLUE_STDOUT]:-}$(displayPath "$dest_dir_parent")/${libname}${COLOUR[OFF_STDOUT]:-} → Shared ${COLOUR[VIVID_BLUE_STDOUT]:-}${git_url} ${lib_ver}${COLOUR[OFF_STDOUT]:-} ($lib_ver_reason)"

        do_ensure_linked_git_checkout  "${dest_dir}" "$git_url" --ref="${lib_ver}"

        local description
        if ! description="$(git -C "$dest_dir" describe --always --dirty  2>/dev/null)" ; then
            echo "   ❌ Invalid git repository at $(displayPath "$dest_dir") for ${git_url}"
            return 1

        fi

        [[ "$description" == *-dirty ]] && description="${description} ⚠️  With uncommited changes"
        echo "    • GitHash: ${description}"
    fi
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
