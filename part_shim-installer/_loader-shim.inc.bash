
##############################################
#
# SHIM Template for loading ukko_bashlibs in a way that is compatible with both direct sourcing and via git-shared-checkout
#
# Rev v0.0.5-wip
#
# After sourcing this file:
#    * `UKKO_BASHLIBS_DIR` is the actual directory of the ukko_bashlibs
#
# To use this:
#
# ╭─────────────────────────────────────────────────────────────────────────────────────
# │ #!/usr/bin/env bash
# │
# │ function main()
# │ {
# │     hello --person=world | grep -q "Hello: world"
# │ }
# │
# │ # shellcheck source=/dev/null
# │ source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/libs/.loader-shim.inc.bash"
# ╰─────────────────────────────────────────────────────────────────────────────────────
#
export UKKO_SHIM_VERSION=v0.0.5-wip

UKKO_BASHLIBS_REF_PREFERRED=ver:v0.0.7

##############################################
#
#
#
function ukkoBashLibsInstall()
{
    # Sets 'UKKO_BASHLIBS_DIR'
    # or returns with FAILURE

    #|No Local| export UKKO_BASHLIBS_LOCAL_DIR="${RUNNER_DIR%/}/ukko_bashlibs"
    #|No Local| if [[ -d "${UKKO_BASHLIBS_LOCAL_DIR}" ]] ; then
    #|No Local|
    #|No Local|     #
    #|No Local|     # Method 1 - 'ukko_bashlibs' is already mapped
    #|No Local|     #
    #|No Local|     UKKO_BASHLIBS_DIR="$(readlink -m "${UKKO_BASHLIBS_LOCAL_DIR}")"
    #|No Local|     _ukko_lib_reason="Mapped directory"
    #|No Local| else
        #
        # Method 2 - Find 'UKKO_BASHLIBS_DIR' value and map it
        #
        if [[ -n "${UKKO_BASHLIBS_DIR:-}" ]] && [[ -d "${UKKO_BASHLIBS_DIR}" ]] ; then
            #
            # Method 2.1 - UKKO_BASHLIBS_DIR is set and valid
            #
            _ukko_lib_reason="\$UKKO_BASHLIBS_DIR defined"
        elif _searchParentPath "$RUNNER_DIR" >&2 ; then

            #
            # Method 2.2 - Found it in parent directories
            #
            _ukko_lib_reason="Found in parent directory"
            # |No Local| UKKO_BASHLIBS_LOCAL_DIR="${UKKO_BASHLIBS_DIR}"
        elif _downloadItFromCloud "${UKKO_BASHLIBS_REF_PREFERRED:-}" >&2 ; then
            #
            # Method 2.3 - Download it with git-shared-checkout
            #
            _ukko_lib_reason="git-shared-checkout (${download_refNote:-})"
        else
            echo "❌ Failed to find or download 'ukko_bashlibs' library.  Searched in parent directories and attempted to download with git-shared-checkout." >&2
            echo "    Suggestion: An older version of 'git-shared-checkout' may be causing issues.  Consider 'git-shared-checkout --uninstall' before re-running."
            return 1
        fi
    #|No Local|
    #|No Local|    if [[ "$UKKO_BASHLIBS_LOCAL_DIR" != "$UKKO_BASHLIBS_DIR" ]] ; then
    #|No Local|        # shellcheck source=/dev/null
    #|No Local|        source "${UKKO_BASHLIBS_DIR%/}/lib-common.inc.bash"
    #|No Local|        do_ensure_link "$UKKO_BASHLIBS_LOCAL_DIR" "$UKKO_BASHLIBS_DIR" || echo "❌ Failed to create link from '${UKKO_BASHLIBS_LOCAL_DIR}' to '${UKKO_BASHLIBS_DIR}'" >&2
    #|No Local|    fi
    #|No Local| fi
    PATH="${UKKO_BASHLIBS_DIR%/}/install_/_runPaths:$PATH"
}

function _searchParentPath()
{
    fabs="$(dirname "$(readlink -m "${1}")")"

    while [[ "$fabs" != "/" ]] && [[ -z "${UKKO_BASHLIBS_DIR:-}" ]]; do
        [[ -f "$fabs/lib-common.inc.bash" ]] && UKKO_BASHLIBS_DIR="$fabs" && return 0
        fabs="$(dirname "$fabs")" || true
    done

    return 1
}

function _downloadItFromCloud()
{
    local ref="${1:-}"

    download_refNote=''
    UKKO_BASHLIBS_REF="${UKKO_BASHLIBS_REF_FORCE:-"${ref}"}"
    UKKO_BASHLIBS_URL="${UKKO_BASHLIBS_URL:-git@github.com:smc-collaborate/ukko_bashlibs}"
    if  [[ "${UKKO_BASHLIBS_REF}" != "${UKKO_BASHLIBS_REF_PREFERRED:-}" ]] ; then
        if [[ "${UKKO_BASHLIBS_REF_FORCE:-}" == "${UKKO_BASHLIBS_REF:-}" ]] ; then
            echo -n "⚠️  UKKO_BASHLIBS_REF_FORCE=$UKKO_BASHLIBS_REF_FORCE"
        else
            echo -n "⚠️  UKKO_BASHLIBS_REF=$UKKO_BASHLIBS_REF"
            [[ -n "${UKKO_BASHLIBS_REF_FORCE:-}" ]] && echo -n " (\$UKKO_BASHLIBS_REF_FORCE=${UKKO_BASHLIBS_REF_FORCE@Q})"
        fi
        [[ -n "${UKKO_BASHLIBS_REF_PREFERRED:-}" ]] && echo -n " (Preferred: '${UKKO_BASHLIBS_REF_PREFERRED:-}')"
        echo ""
    fi
    download_refNote="ref '${UKKO_BASHLIBS_REF}' from ${UKKO_BASHLIBS_URL}"

    if ! ensure_installed_direct_if_needed git-shared-checkout "$UKKO_BASHLIBS_URL" "${UKKO_BASHLIBS_REF}" ; then
        echo "❌ Failed to install 'git-shared-checkout' from ${UKKO_BASHLIBS_URL} with ref '${UKKO_BASHLIBS_REF}'" >&2
        download_refNote+=" | ❌  FAILED"
        return 1
    fi

    UKKO_BASHLIBS_DIR="$(git-shared-checkout "$UKKO_BASHLIBS_URL" --ref="${UKKO_BASHLIBS_REF:-}")"  && return 0
    download_refNote+=" | ❌  FAILED"
    return 1
}

function ensure_installed_direct_if_needed()
{
    local destRef="${1:-}"
    local git_url="${2:-}"
    local git_ref="${3:-}"

    local exe_name="${destRef##*/}"
    # |ExtraLogging| echo "! $0 $@"
    # |ExtraLogging| echo " - destRef=${destRef@Q}"
    # |ExtraLogging| echo " - exe_name=${exe_name@Q}"
    # |ExtraLogging| echo " - git_url=${git_url@Q}"
    # |ExtraLogging| echo " - git_ref=${git_ref@Q}"


    command -v "$exe_name" &> /dev/null && return 0

    local url_part=''


    ##############################################
    # Handle ver:
    # (The first found of: [tag:###,branch:###,branch:###-wip])
    if [[ "${git_ref}" == "ver:"* ]] ; then
        local option_ref_value="${git_ref#ver:}"
        # shellcheck disable=SC2016
        readarray -t _revMarkers < <(cd /tmp && git ls-remote  "$git_url") || FATAL_FAILURE_NO_RETURN "Unable to access repository '$git_url'"

        function _findRef()
        {
            local suffix="$1"
            for ref in "${_revMarkers[@]}" ; do
                [[ "$ref" == *"refs/${suffix}" ]] && return 0
            done
            return 1
        }

        if _findRef "tags/${option_ref_value}" ; then
            option_ref_type='tag'
            echo "ℹ️  Found ${option_ref_type}: ${option_ref_value}" >&2
        elif _findRef "heads/${option_ref_value}" ; then
            option_ref_type='branch'
            echo "ℹ️  Found ${option_ref_type}: ${option_ref_value}" >&2
        elif _findRef "heads/${option_ref_value}-wip" ; then
            option_ref_type='branch'
            option_ref_value="${option_ref_value}-wip"
            echo "ℹ️  Found ${option_ref_type}: ${option_ref_value}" >&2
        else
            {
                echo "ℹ️  Reviewed:"
                for x in "${_revMarkers[@]}" ; do
                    echo "  •  $x"
                done
            } >&2
            FATAL_FAILURE_NO_RETURN "Neither tag:{$option_ref_value} nor branch:${option_ref_value} nor branch:${option_ref_value}-wip could be found in the repository '$git_url'"
        fi

        git_ref="${option_ref_type}:${option_ref_value}"
    fi

    if [[ -z "${git_ref}" ]] ; then
        url_part="refs/heads/main"
    elif [[ "${git_ref}" == "branch:"* ]]; then
        url_part="refs/heads/${git_ref#branch:}"
    elif [[ "${git_ref}" == "tag:"* ]]; then
        url_part="refs/tags/${git_ref#tag:}"
    elif [[ "${git_ref}" == "hash:"* ]]; then
        url_part="${git_ref#hash:}"
    else
        FATAL_FAILURE_NO_RETURN "Invalid format for git_ref: ${git_ref@Q}.\nExpected formats:\n • branch:<branch_name>\n • tag:<tag_name>\n • hash:<hash_value>\n • ver:<version>"
    fi

    local exe_url="${git_url#git@}"
    exe_url="${exe_url/://}"
    exe_url="${exe_url#https://}"

    if [[ "$exe_url" == "github.com/"* ]] ; then
        exe_url="raw.githubusercontent.com/${exe_url#github.com/}"
    fi
    exe_url="https://${exe_url%%.git}/$url_part/$destRef"

    INSTALL_DIR="${HOME%/}/.local/bin" ; [[ "$EUID" -eq 0 ]] && INSTALL_DIR="/usr/local/bin"
    local exe_path ; exe_path="${INSTALL_DIR%/}/$exe_name"

    [[ -L "$exe_path" ]] && unlink "$exe_path"

    if ! command -v "wget" &> /dev/null  ; then

        if [[ "$(id -u)" == 0 ]] && ! apt-cache show wget &>/dev/null; then
            #
            # Apt-cache hasn't been setup yet - common in fresh docker images
            #
            echo "⚡  'apt-get' needs updating"
            _sudoIfNeeded apt-get update
            _sudoIfNeeded apt-get install -y git
            ##|x| [[ -n "${THIS_DIR:-}" ]] && _sudoIfNeeded git config --global --add safe.directory "${THIS_DIR%/}/#"
        fi

        ! _sudoIfNeeded apt-get install -y wget && echo "❌  Failed to install 'wget'"                                                                                                           >&2 && return 1
    fi

    ! wget -O "$exe_path" "$exe_url"        && echo "❌  Failed to download '$exe_name' from $exe_url"                                                                                       >&2 && return 1
    ! chmod +x "$exe_path"                  && echo "❌  Failed to make ${exe_path@Q} executable"                                                                                            >&2 && return 1
    ! [[ ":$PATH:" == *":$INSTALL_DIR:"* ]] && echo "❌  '$exe_name' installed to ${INSTALL_DIR@Q} but it is NOT in PATH.  You must add ${INSTALL_DIR@Q} to your PATH environment variable." >&2 && return 1


    echo "✅  '$exe_name' installed successfully to ${INSTALL_DIR@Q} and is available in PATH" >&2
}


function FATAL_FAILURE_NO_RETURN()
{
    local msg="${*##❌}"

    local lines=()
    local prefix="❌  FATAL FAILURE: "

    msg="$(echo -e "$msg")"
    readarray -t lines <<< "$msg"
    for x in "${lines[@]}" ; do
        echo -e "$prefix$x"
        prefix='    '
    done
    exit 1
}

function _sudoIfNeeded() {
    if [[ "$(id -u)" -ne 0 ]] ; then
        sudo ORIG_PWD="${ORIG_PWD:-}" "$@"
    else
        "$@"
    fi
}

RUNNER_DIR="$(dirname "${BASH_SOURCE[0]}")"

ukkoBashLibsInstall


# |ExtraLogging| echo "⚡  Loaded ukko_bashlibs : ${_ukko_lib_reason:-Unknown}" >&2
#
# Load directly if shim
# if 'shim-lib-<libname>.inc.bash' is a link to this file then 'lib-<libname>.inc.bash' is automatically sourced
_srcRef="${BASH_SOURCE[0]##*/}"
_callerRef="${BASH_SOURCE[1]:-}"
_callerRef="${_callerRef##*/}"
# |ExtraLogging| echo "⚡  srcRef=$_srcRef" >&2

_lib_fullname=''

if [[ "$_srcRef" == 'shim-lib-'*'.inc.bash' ]] ; then
    _libname="${_srcRef#shim-lib-}"
    _lib_fullname="lib-${_libname%.inc.bash}"
    # |ExtraLogging| echo "⚡  Detected shim for library '$_libname', loading it directly" >&2
    # |ExtraLogging| echo "⚡  Loading shim directly: ${UKKO_BASHLIBS_DIR%/}/lib-${_libname}.inc.bash" >&2
elif [[ -n "${LIB_TO_SHIM:-}" ]] ; then
    _lib_fullname="${LIB_TO_SHIM:-}"
elif [[ "${_callerRef}" == *install* ]] || [[ "${_callerRef}" == *build* ]] ; then
    _lib_fullname='lib-building'
elif [[ "${_callerRef}" == *test* ]] ; then
    _lib_fullname='lib-testing'
fi
if [[ -z "${_lib_fullname}" ]] ; then
    echo "❌  ${_callerRef}: Expected 'LIB_TO_SHIM=lib-building' -or- lib-app -or- lib-common -or- lib-testing before 'source --/${BASH_SOURCE[0]##*/}'" >&2
else
    # shellcheck source=/dev/null
    source "${UKKO_BASHLIBS_DIR%/}/${_lib_fullname}.inc.bash"
fi
