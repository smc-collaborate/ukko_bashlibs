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


function installPkgIfNeeded_gitlfs()
{
    [[ "${AM_CLEANING:-}" == 'yes' ]] && return 0
    if ! git-lfs --version 2>/dev/null ; then
        echo "⚡  git-lfs needs to be installed"
        installPkgIfNeeded curl
        curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh > /tmp/git-lfs-deb.sh
        sudoIfNeeded chmod +x /tmp/git-lfs-deb.sh
        sudoIfNeeded apt-get install -y git-lfs
        git lfs >/dev/null 2>/dev/null || git lfs install
    fi
}



function do_gitLfsCheck()
{
    [[ "${AM_CLEANING:-}" == 'yes' ]] && return 0
    local filename="$1"
    local expected_size="${2:-}"

    if [[ ! -f "${filename}" ]] ; then
        echo "❌ FAIL FAILURE[git-lfs check]: File not found: ${filename}"
        exit 1
    fi

    function _filesizeCheck()
    {
        local option="${1:-}"

        local actual_size
        actual_size="$(stat -c %s "${filename}")"

        local fail_icon="⚡  "

        [[ "$option" == 'echo-if-successful' ]] && fail_icon="❌  "

        if [[ -z "${expected_size}" ]] ; then
            if [[ "$actual_size" -gt 1024 ]] ; then
                [[ "$option" == 'echo-if-successful' ]] && echo "✓  $filename is ≥ 1kiB in size - git lfs appears to be used correctly"
                return 0
            fi
            echo "$fail_icon git-lfs check: $filename is only $actual_size bytes long, which seems too small"
            return 1
        else
            if [[ "${actual_size}" == "${expected_size}" ]] ; then
                [[ "$option" == 'echo-if-successful' ]] && echo "✓  $filename is $expected_size bytes in size - git lfs appears to be used correctly"
                return 0
            fi

            echo "$fail_icon git-lfs check: $filename is $actual_size bytes long instead of $expected_size"
            return 1
        fi

        return 1
    }

    _filesizeCheck && return 0


    #################
    # Fix the issue
    #
    installPkgIfNeeded_gitlfs
    git lfs pull

    _filesizeCheck 'echo-if-successful' && return 0

    #################
    #
    echo "❌ FAIL FAILURE[git-lfs check]: Recovery was not successful"
    exit 1
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


    #########################
    # dest_parent?
    #
    local dest_dir_parent
    local parent_ukko_bashlibs_dir  ; parent_ukko_bashlibs_dir="$(dirname "${UKKO_BASHLIBS_LOCAL_DIR%/}")"
    if [[ -n "${LIBS_PARENT_DIR:-}" ]] ; then
        dest_dir_parent="$LIBS_PARENT_DIR"
    elif [[ -d "${EXE_DIR%/}/libs" ]] ; then
        dest_dir_parent="${EXE_DIR%/}/libs"
    elif [[ "${parent_ukko_bashlibs_dir%/}" == *"/common" ]] ; then
        dest_dir_parent="${parent_ukko_bashlibs_dir%/}"
    else
        dest_dir_parent="${EXE_DIR%/}"
    fi
    dest_dir_parent="$(realpath "${dest_dir_parent}")"
    mkdir -p "${dest_dir_parent}" || FATAL_FAILURE_NO_RETURN "Failed to create parent of lib dir: ${dest_dir_parent}"

    local dest_dir="${dest_dir_parent%/}/${libname}"

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
    local location="$1"
    # shellcheck disable=SC1091
    readarray -t _submodules < <(git -C "$location" submodule status --recursive 2>/dev/null)

    _notLoaded=()
    _updateAvailable=()
    for x in "${_submodules[@]}" ; do
        [[ "$x" == "-"* ]] && _noteLoaded+=( "$x" )
        [[ "$x" == "+"* ]] && _updateAvailable+=( "$x" )
    done

    function dumpHelp()
    {
        local location="$1"
        local topmsg="$2"
        local secondline="${3:-}"
        local colour="${4:-}"

        local colourStart=""
        local colourStop=""

        if [[ -n "$colour" ]] ; then
            colourStart="${COLOUR[$colour]:-}"
            colourStop="${COLOUR[OFF_USED]:-}"
        fi

        echo -e "${colourStart}${topmsg}${colourStop}: ${COLOUR[VIVID_BLUE_USED]:-}$(git_with_location_params_nice "$location") submodule update --init --recursive${COLOUR[OFF_USED]:-}"
        [[ -n "$secondline" ]] && echo -e "${colourStart}    $secondline${colourStop}"
        echo -e ""
        echo -e "${colourStart}    Key: -= Unloaded.   +=Update available${colourStop}"
        for x in "${_submodules[@]}" ; do
            echo -e "${colourStart}      $x${colourStop}"
        done
    }
    if [[ "${#_notLoaded[@]}" != 0 ]] ; then
        dumpHelp "$1" "⚠️  Submodules not loaded.  Please use" "(You could also have used 'git clone --recurse-submodules' when cloning originally)" "VIVID_RED_USED"
        echo    ""
        exit 3
    fi
    if [[ "${#_updateAvailable[@]}" != 0 ]] ; then
        dumpHelp "$1" "ℹ️  Submodule updates are available.  You can use"
        echo    ""
    fi
    return 0
}
