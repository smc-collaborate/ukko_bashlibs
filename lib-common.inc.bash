# shellcheck shell=bash
################
#
#
# IMPORT THIS AS A 'source' script
#   source tools/lib-common.inc.bash
#

#==============================================================================================
#
# Start Region: Shared between lib-common.inc.bash & single file: git-shared-checkout
#

##############################################
#
# Evaluates git stored in:
#  * repo_fullDir
#
# Loads:
#  * gitInfo_description
#  * gitInfo_warning
#
# Also evaluates and triggers warnings based on:
#  * option_ref_type
#  * option_ref_value
#
gitInfo_description=''
gitInfo_warning=''
function load_gitInfo()
{
    local hash=''
    local branch=''

    local alwaysGiveBranch="${1:-no}"
    gitInfo_description=''
    gitInfo_warning=''

    if [[ ! -d "$repo_fullDir" ]] ; then
        gitInfo_warning="MISSING"
        return
    elif [[ "$option_ref_type" == 'hash-only' ]] ; then
        gitInfo_description="only:#${option_ref_value}"
    elif [[ -n "$(find "$repo_fullDir" -maxdepth 0 -empty)" ]] ; then
        gitInfo_description="<EMPTY>"
    elif ! hash="$(git -C "$repo_fullDir" describe --always --dirty 2>/dev/null)"; then
        gitInfo_warning="<INVALID_GIT>"
    else
        branch="$(git -C "$repo_fullDir" branch --show-current 2>/dev/null || true)"
        gitInfo_description="${branch}@${hash}"
        our_hash="${hash%-dirty}"

        if [[ "$option_ref_type" == "hash" ]] && [[ "${our_hash}" != "$option_ref_value" ]]; then
            gitInfo_warning="Hash is not the expected value: #$option_ref_value"
        elif [[ "$option_ref_type" == "branch" ]] && [[ "$branch" != "$option_ref_value" ]]; then
            gitInfo_warning="Branch is not the expected value: ${option_ref_value:-}"
        elif [[ "$option_ref_type" == "hash" ]] ; then
            if [[ "${hash}" == *-dirty ]]; then
                gitInfo_description="🔓  "
            else
                gitInfo_description="🔒  "
            fi
        elif [[ "$option_ref_type" == "branch" ]] ; then
            if [[ "$alwaysGiveBranch" == "yes" ]] ; then
                gitInfo_description="🔓  ${gitInfo_description}"
            else
                gitInfo_description="🔓  @${hash}"
            fi
        elif [[ "$option_ref_type" == "tag" ]] ; then
            tag_hash="$(git -C "$repo_fullDir" rev-list -n 1 "refs/tags/${option_ref_value}" 2>/dev/null || true)"
            if [[ -z "$tag_hash" ]] ; then
                gitInfo_warning="Unable to identify tag:${option_ref_value}"
            elif [[ "${tag_hash}" != "${our_hash}"* ]]; then
                gitInfo_warning="tag:${option_ref_value}=#${tag_hash:0:7}"
            else
                gitInfo_description+="🔓  "
            fi
        elif [[ -z "$option_ref_type" ]] ; then
            gitInfo_description="🔓  ${gitInfo_description}"
        else
            gitInfo_description+="🔓  "
        fi
        if [[ "$hash" == *-dirty ]] ; then
            [[ -n "$gitInfo_warning" ]] && gitInfo_warning+=" & "
            gitInfo_warning+="There are local changes"
        fi
    fi
}

function dump_gitInfoOnDir()
{
    local _dir="$1"

    repo_fullDir="$_dir"

    y="${repo_fullDir#"$SHARED_GIT_DIR/"}"

    repo_friendlyName="${y%/*}"
    repo_friendlyName="${repo_friendlyName/\//:}"
    _dispDir="${SHARED_GIT_DIR_DISPLAY%/}/$y"
    _checkoutDirPart="${y##*/}"
    _repoDirPart="${y%/*}"

    if [[ "$_checkoutDirPart" == "default_branch" ]]; then
        option_ref_type=""
        option_ref_value=""
        _checkoutKindValue=""
    else
        option_ref_type="${_checkoutDirPart%%_*}"
        option_ref_value="${_checkoutDirPart#*_}"
        _checkoutKindValue="$option_ref_type:$option_ref_value"
    fi

    # Load:
    # * gitInfo_description
    # * gitInfo_warning
    load_gitInfo 'yes'

    ##########
    # Summarise

    local repo_caption="$repo_friendlyName"
    [[ -n $gitInfo_description ]] &&  repo_caption+=" $gitInfo_description"
    local _dirAsPrinted="$_dispDir"

    [[ -z "$gitInfo_warning"   ]] || gitInfo_warning=" ${COLOUR[VIVID_RED_STDERR]:-}⚠️  $gitInfo_warning${COLOUR[OFF_STDERR]:-}"
    _checkoutDirPart="${y##*/}"
    _repoDirPart="${y%/*}"
    echo -en  " •  ${SHARED_GIT_DIR_DISPLAY%/}/${COLOUR[VIVID_BLUE_STDOUT]:-}${_repoDirPart}${COLOUR[OFF_STDOUT]:-}/${_checkoutDirPart} "

    _maxLen=80
    _a="${#_repoDirPart}"
    _b="${#_checkoutDirPart}"

    printf "%-*s" "$((_maxLen - _a - _b - 3))" ""
    echo -e "${COLOUR[VIVID_BLUE_STDOUT]:-}${gitInfo_description}${COLOUR[OFF_STDOUT]:-}$gitInfo_warning"
}

function displayPathList()
{
    local result=''
    local value

    for value in "$@" ; do
        [[ -z "$result" ]] || result+=','
        x="$(quoteIfNeeded "$(displayPath "$value")")"
        result+="$x"
    done

    [[ "$#" == 1 ]] || result="[$result]"
    echo -n "$result"
}

function displayPath()
{
    local fname_in="$1"

    shift 1 || true

    local trailingFile
    local pathToReview

    if [[ "${1:-}" == "--link-src" ]] ; then
        shift 1 || true
        local dir="${fname_in%/*}"

        pathToReview="${dir:-"${PWD}"}"
        trailingFile="${fname_in##*/}"
    else
        pathToReview="$fname_in"
        trailingFile=''
    fi

    local max_back=4
    if [[ "${1:-}" == "--max-back="* ]] ; then
        max_back="${1#--max-back=}"
        shift 1 || true
    fi
    skip_relative_if_contains="$(printf -v spaces "%*s" "$max_back" "" && echo "${spaces// /../}")"
    skip_relative_if_contains="${skip_relative_if_contains%/}"

    local orig=''
    local relPath=''
    local result

    if [[ -n "$pathToReview" ]] ; then
        orig="$(realpath "${pathToReview}")"
        relPath="$(realpath --relative-to="${ORIG_PWD%/}/" "${orig}")"
    fi
    result="${orig/#$HOME/\~}"

    [[ "${1:-}" == "--run-path" ]] && [[ "$relPath" != *"/"* ]] && [[ "$relPath" != "./"* ]] && [[ "$relPath" != "." ]] && relPath="./${relPath}"
    [[ "$relPath" != *"${skip_relative_if_contains}"* ]] && [[ "${#result}" -gt  "${#relPath}" ]] && result="$relPath"
        skip_relative_if_contains="${skip_relative_if_contains%/}"

    if [[ "${1:-}" == "--run-path" ]] ; then
        # Is this exe available in PATH ?

        if [[ -n "$trailingFile" ]] ; then
            local exe_dir="${orig%/}"
            local exe_name="$trailingFile"
        else
            local exe_dir="${orig%/*}"
            local exe_name="${fname_in##*/}"
        fi

        IFS=: read -r -d '' -a path_array < <(printf '%s:\0' "$PATH")
        # Loop through the array elements
        for pathDir in "${path_array[@]}"; do
            [[ -n "$pathDir" ]] || pathDir="$PWD"
            if [[ "$pathDir" == "$exe_dir" ]] ; then
                quoteIfNeeded "$exe_name"
                return 0  #< This can't be beaten for shortness - No path!
            fi
        done
    fi
    local fname_out
    if [[ -z "$result" ]] ; then
        fname_out="$orig"
    elif [[ -z "$trailingFile" ]] ; then
        fname_out="$result"
    else
        fname_out="${result%/}/$trailingFile"
    fi

    if [[ "${1:-}" == "--run-path" ]] ; then
        fname_out="$(quoteIfNeeded "$fname_out")"
    fi

    echo -n "$fname_out"
}



function relativeToOrigPwd()
{
  realpath --relative-to="${ORIG_PWD%/}/" "${1}"
}


function _quoteIfNeeded()
{
    local permitDoubleQuoting="${1}"
    shift 1

    local value
    local result=''

    for value in "$@" ; do
        [[ -n "$result" ]] && echo -n " "

        issues=''
        result="$value"

        doubleQuotable="${permitDoubleQuoting:-yes}"
        [[ "$value" == ''    ]] && issues+='[empty]'
        [[ "$value" == *"'"* ]] && issues+='[singleQuotes]'
        [[ "$value" == *'"'* ]] && issues+='[doubleQuotes]' && doubleQuotable='no'
        [[ "$value" == *" "* ]] && issues+='[spaces]'
        [[ "$value" == *'`'* ]] && issues+='[backticks]'    && doubleQuotable='no'
        [[ "$value" == *'$'* ]] && issues+='[dollarSigns]'  && doubleQuotable='no'
        [[ "$value" == *'|'* ]] && issues+='[pipes]'
        [[ "$value" == *'&'* ]] && issues+='[ampersands]'
        [[ "$value" == *'('* ]] && issues+='[openParens]'
        [[ "$value" == *')'* ]] && issues+='[closeParens]'
        [[ "$value" == *'{'* ]] && issues+='[openBraces]'
        [[ "$value" == *'}'* ]] && issues+='[closeBraces]'
        [[ "$value" == *'['* ]] && issues+='[openBrackets]'
        [[ "$value" == *']'* ]] && issues+='[closeBrackets]'
        [[ "$value" == *'<'* ]] && issues+='[lessThan]'
        [[ "$value" == *'>'* ]] && issues+='[greaterThan]'
        [[ "$value" == *';'* ]] && issues+='[semicolons]'
        # shellcheck disable=SC1003
        [[ "$value" == *'\'* ]] && issues+='[backslashes]'


        if [[ -n "$issues" ]] ; then
            if [[ "$doubleQuotable" == 'yes' ]] ; then
                result="\"${value}\""
            elif [[ "$issues" != *'[singleQuotes]'* ]] ; then
                result="'${value}'"
            else
                result="$(printf "%q" "$value")"
            fi
            #|Logging| printf "   Value \`%s\` will be quote protected: %s\n" "$value" "$result" >&2
        fi

        echo -n "$result"
    done
    return 0
}

function quoteIfNeeded()
{
    _quoteIfNeeded "yes" "$@"
}

##################################################
#
# Colours
#
declare -A COLOUR=()
declare -A COLOUR_CODES=(
        [RED]='\033[0;31m'
        [GREEN]='\033[0;32m'
        [YELLOW]='\033[0;33m'
        [BLUE]='\033[0;34m'

        [VIVID_RED]='\033[1;31m'
        [VIVID_GREEN]='\033[1;32m'
        [VIVID_YELLOW]='\033[1;33m'
        [VIVID_BLUE]="\033[1;34m"

        [OFF]='\033[0m'
)

UKKO_COLOURS_CHOSEN=''

function colours_setUsed()
{
    local kind="${1:-stdout}"  # stdout,stderr
    UKKO_COLOURS_USED_SUFFIX="_${kind^^}"
    for colourName in "${!COLOUR_CODES[@]}"; do
        contents="${COLOUR[${colourName}${UKKO_COLOURS_USED_SUFFIX}]:-}"
        if [[ -z "$contents" ]] ; then
            unset "COLOUR[${colourName}_USED]"
        else
            COLOUR["${colourName}_USED"]="$contents"
        fi
    done
}
function colours_load()
{
    local arg="${1:-auto}"  # yes|no|auto

    UKKO_COLOURS_CHOSEN="--colours=$arg"

    if [[ "$arg" == 'auto' ]] ; then
        [[ -t 1 ]] || UKKO_COLOURS_CHOSEN+=", stdout redirected"
        [[ -t 2 ]] || UKKO_COLOURS_CHOSEN+=", stderr redirected"
    fi

    # |x| echo "colours_load($arg): $UKKO_COLOURS_CHOSEN" >&2
    local kind
    local colourName
    local colourCode

    COLOUR=()

    for kind in "_STDOUT" "_STDERR" "_FORCED"; do

        _colour=yes
        if [[ "$arg" == 'no' ]] ; then
            [[ "$kind" == "_FORCED" ]] || _colour=no
        elif [[ "$arg" == 'auto' ]] ; then
            [[ "$kind" == "_STDOUT" ]] && [[ ! -t 1 ]] && _colour=no
            [[ "$kind" == "_STDERR" ]] && [[ ! -t 2 ]] && _colour=no
        fi

        if [[ "$_colour" == 'yes' ]]; then

            for colourName in "${!COLOUR_CODES[@]}"; do
                local colourCode="${COLOUR_CODES[$colourName]}"

                local codeName="${colourName}"
                [[ -n "$kind" ]] && codeName+="$kind"

                COLOUR["${codeName}"]="$colourCode"
            done
        fi
    done

    colours_setUsed "stdout"
}

colours_load "yes"

#
##################################################################################

overallBashResult=0
function doRun()
{
    local silent_if_ok=no

    if [[ "${1:-}" == "--silent-if-ok" ]] ; then
        silent_if_ok=yes
        shift 1 || true
    fi
    local expected_result=0
    if [[ "${1:-}" == "--expect-exit-code="* ]] ; then
        expected_result="${1#--expect-exit-code=}"
        shift 1 || true
    fi

    local result=0

    local tmpfile ; tmpfile="$(mktemp "/tmp/doRun.XXXXXX")"


    "$@" &> "$tmpfile" || result=$?

    local exitCodeNote=''

    [[ "$result" -ne 0 ]] && exitCodeNote="[Exit code: $result]"

    if [[ "$result" == "$expected_result" ]]; then
        [[ "$silent_if_ok" == "yes" ]] && return 0
        echo "      ✓ Ran${exitCodeNote}: $*"
    else
        echo "      ✗ Ran${exitCodeNote}: $*"UK
        echo "        ❌ Responded with: $result"
        # shellcheck disable=SC2034
        overallBashResult="$result"
    fi
    [[ -s "$tmpfile" ]] && withLeftBox "             " < "$tmpfile"

    rm -f "$tmpfile"
    return $result
}

function withPrefix()
{
    local prefix="$1"
    sed --unbuffered "s/^/${prefix}/" || return 0
}

function withLeftBox()
{
    local prefix="${1:-}"
    echo       "${prefix}╭───────────────────────────────────────────────────────────────────────"
    withPrefix "${prefix}│ "
    echo       "${prefix}╰───────────────────────────────────────────────────────────────────────"
}

function doRun-groupedOutput()
{
    local result
    echo                   "╭───────────────────────────────────────────────────────────────────────"
    "$@" 2>&1 | withPrefix "│ "
    result="${PIPESTATUS[0]}"
    echo                   "╰───────────────────────────────────────────────────────────────────────"
    return "$result"
}

function doWithSuccessMsg()
{
    local success_msg="$1"

    shift 1 || true

    doRun --silent-if-ok "$@" || return $?

    echo "$success_msg"
}

function sudoIfNeeded() {
    export DEBIAN_FRONTEND=noninteractive
    if [[ "$(id -u)" -ne 0 ]] ; then
        sudo sudo ORIG_PWD="${ORIG_PWD:-}" "$@"
    else
        "$@"
    fi
}


function do_remove_link()
{
    local link="$1"
    local optional_unless_target="${2:-}"

    if [[ -L "$link" ]] ; then
        if [[ -n "${optional_unless_target}" ]] && [[ "$(readlink -f "$link")" == "$(readlink -f "$optional_unless_target")" ]] ; then
            echo "    • Keeping link : $(displayPath "$link" --link-src) → $(displayPath "$optional_unless_target")"
        else
            doWithSuccessMsg "    • Unlinked existing: $(displayPath "$link" --link-src)"  unlink "$link"  || return $?
        fi
    elif [[ -e "$link" ]] ; then
        doWithSuccessMsg "    • Removed existing file/directory: $(displayPath "$link" --link-src)"  rm -rf "$link" || return $?
    fi
}

function do_ensure_link()
{
    local link="$1"
    local target="$2"

    if [[ "${AM_CLEANING:-}" == 'yes' ]] ; then
        do_remove_link "$link" || return $?
    elif [[ -L "$link" ]] && [[ "$(readlink -f "$link")" == "$(readlink -f "$target")" ]] ; then
        printf "    • Link confirmed: %-24s → %s\n" "$(displayPath "$link" --link-src)" "$(displayPath "$target")"
    else
        do_remove_link "$link" || return $?
        target_parent="$(dirname "$target")"
        [[ -d "$target_parent" ]] || doWithSuccessMsg "    • Created parent : $(displayPath "$target_parent")"  mkdir -p "$target_parent" || return $?
        doWithSuccessMsg "    • Created link: $(displayPath "$link" --link-src) → $(displayPath "$target")"  ln -s "$target" "$link" || return $?
    fi

    return 0
}

function forceDelete()
{
    local result='0'
    local prefix="${1:-}"
    while IFS= read -r target; do
        if [[ -e "$target" ]] ; then

            rm -rf "$target" &>/dev/null || true
            if [[ ! -e "$target" ]] ; then
                echo "✓ Deleted $target "
            elif [[ "$(id -u)" -ne 0 ]] && sudoIfNeeded rm -rf "$target" ; then
                echo "✓ Deleted $target (with sudo)"
            else
                echo "✗ Failed to delete '$target'"
                result=1
            fi
        fi
    done
    return $result
}
function do_ensure_file_set()
{
    local dest_fname="$1"
    local src_fname="$2"
    local gave_success_msg="no"

    if [[ -L "$dest_fname" ]] || [[ ! -f "$dest_fname" ]] || ! cmp --silent "$dest_fname" "$src_fname" ; then
        do_remove_link "$dest_fname"  || return $?
        doWithSuccessMsg "    • Updated file: $(displayPath "$dest_fname")"  cp "$src_fname" "$dest_fname" || return $?
        gave_success_msg='yes'
    fi


    local src_attr ; src_attr=$(stat --printf="%a" "$src_fname")
    local dst_attr ; dst_attr=$(stat --printf="%a" "$dest_fname")
    if [[ "$src_attr" != "$dst_attr" ]] ; then
        doWithSuccessMsg "    • Updated permissions for $(displayPath "$dest_fname") : $dst_attr → $src_attr"  chmod "$src_attr" "$dest_fname" || return $?
        gave_success_msg='yes'
    fi


    [[ "$gave_success_msg" == 'yes' ]] || echo "    • File confirmed: $(displayPath "$dest_fname")"
    return 0
}

#
# End Region: Shared bewteen lib-common.inc.bash & single file: git-shared-checkout
#
#==============================================================================================

function asCsvList()
{
    local _first='yes'
    for arg in "$@" ; do
        [[ "$_first" == 'yes' ]] || echo -n ", "
        _first='no'
        quoteIfNeeded "$arg"
    done
}

function asQuotableText()
{
    _quoteIfNeeded "no" "$@"
}

function asQuotedText()
{
    echo -n '"'
    asQuotableText "$@"
    echo -n '"'
}

function extraVerboseLogging()
{
    true # echo "🛈  $*" >&2
}

function print_verbose()
{
    echo -e "ℹ️  $*" >&2
}


if [[ -z "${ORIG_PWD:-}" ]] ; then
  #|Logging| echo "🛈  Setting ORIG_PWD to [$(pwd)]"
  export ORIG_PWD ; ORIG_PWD="$(pwd)"
  extraVerboseLogging "ORIG_PWD                   = [${ORIG_PWD}]"
#|Logging|else
#|Logging|  echo "🛈  ORIG_PWD already set to [${ORIG_PWD}]"
fi

#|x|if [[ -z "${THIS_EXE_FROM_ORIGINAL_PWD:-}" ]] ; then
#|x|  export THIS_EXE_FROM_ORIGINAL_PWD ;
#|x|  if [[ $0 == /* ]] ; then
#|x|    THIS_EXE_FROM_ORIGINAL_PWD="$0"
#|x|  else
#|x|    THIS_EXE_FROM_ORIGINAL_PWD="$(relativeToOrigPwd "$0")"
#|x|    if [[ "${THIS_EXE_FROM_ORIGINAL_PWD}" != *"/"* ]] ; then
#|x|      THIS_EXE_FROM_ORIGINAL_PWD="./${THIS_EXE_FROM_ORIGINAL_PWD}"
#|x|    fi
#|x|  fi
#|x|  extraVerboseLogging "THIS_EXE_FROM_ORIGINAL_PWD = [${THIS_EXE_FROM_ORIGINAL_PWD}]"
#|x|fi

if [[ -z "${ORIG_PARAMS:-}" ]] ; then
  export ORIG_PARAMS ; ORIG_PARAMS=("$@")
  extraVerboseLogging "ORIG_PARAMS                = [${ORIG_PARAMS[*]}]"
fi


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
if [[ -z "${THIS_EXE:-}" ]] ; then
    THIS_EXE="${BASH_SOURCE[-1]}"
    if [[ "${THIS_EXE}" == '../' ]] || [[ "${THIS_EXE}" == './' ]] ; then
        THIS_EXE="${ORIG_PWD%/}/${THIS_EXE}"
    fi

    THIS_EXE="$(realpath -m "${THIS_EXE}")"
fi
[[ -n "${EXE_DIR:-}"  ]] || EXE_DIR="$(realpath -m "$(dirname "${THIS_EXE}")")"
[[ -n "${PROJ_DIR:-}" ]] || PROJ_DIR="$(realpath -m "${EXE_DIR%/}/${PROJ_DIR_REL:-}")"
# shellcheck disable=SC2034
UKKO_BASHLIBS_DIR="$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")"
THIS_EXE_AS_DISPLAY="$(displayPath "$THIS_EXE")"
EXE_DIR_AS_DISPLAY="$(displayPath "$EXE_DIR")"

CMD_AS_DISPLAY="$(displayPath "$0" --link-src --run-path)"
[[ -z "${ORIG_EXE_RUN:-}" ]] && export ORIG_EXE_RUN="${THIS_EXE}"
[[ -z "${ORIG_EXE_DIR:-}" ]] && export ORIG_EXE_DIR="${EXE_DIR}"
[[ -z "${ORIG_EXE_RUN_AS_DISPLAY:-}" ]] && export ORIG_EXE_RUN_AS_DISPLAY="${THIS_EXE_AS_DISPLAY}"
[[ -z "${ORIG_EXE_DIR_AS_DISPLAY:-}" ]] && export ORIG_EXE_DIR_AS_DISPLAY="${EXE_DIR_AS_DISPLAY}"
[[ -z "${ORIG_EXE_CMD_AS_DISPLAY:-}" ]] && export ORIG_EXE_CMD_AS_DISPLAY="${CMD_AS_DISPLAY}"


#==============================================================================================

#
#
#

function dump_sharedCheckout_gitInfoOnDir()
{
    local _dir="${1:-$UKKO_BASHLIBS_DIR}"
    local _padding="${2:-0}"

    local shared_topLevelDir
    shared_topLevelDir="$(realpath -m "${UKKO_BASHLIBS_DIR%/}/../../../../")"
    local shared_topLevelDirAsDisplay
    shared_topLevelDirAsDisplay="$(displayPath "$shared_topLevelDir")"

    repo_fullDir="$(realpath -m "$_dir")"

    y="${repo_fullDir#"$shared_topLevelDir/"}"

    repo_friendlyName="${y%/*}"
    repo_friendlyName="${repo_friendlyName/\//:}"
    _dispDir="${shared_topLevelDirAsDisplay%/}/$y"
    _checkoutDirPart="${y##*/}"
    _repoDirPart="${y%/*}"

    if [[ "$_checkoutDirPart" == "default_branch" ]]; then
        option_ref_type=""
        option_ref_value=""
        _checkoutKindValue=""
    else
        option_ref_type="${_checkoutDirPart%%_*}"
        option_ref_value="${_checkoutDirPart#*_}"
        _checkoutKindValue="$option_ref_type:$option_ref_value"
    fi

    # Load:
    # * gitInfo_description
    # * gitInfo_warning
    load_gitInfo 'no'

    ##########
    # Summarise

    local repo_caption="$repo_friendlyName"
    [[ -n $gitInfo_description ]] &&  repo_caption+=" $gitInfo_description"
    local _dirAsPrinted="$_dispDir"

    [[ -z "$gitInfo_warning"   ]] || gitInfo_warning=" ${COLOUR[VIVID_RED_STDOUT]:-}⚠️  $gitInfo_warning${COLOUR[OFF_STDOUT]:-}"
    _checkoutDirPart="${y##*/}"
    _repoDirPart="${y%/*}"
    echo -en  "${shared_topLevelDirAsDisplay%/}/${COLOUR[VIVID_BLUE_STDOUT]:-}${_repoDirPart}${COLOUR[OFF_STDOUT]:-}/${_checkoutDirPart} "

    _a="${#_repoDirPart}"
    _b="${#_checkoutDirPart}"

    _padTo="$((_padding - _a - _b - 3))"
    [[ "$_padTo" -gt 0 ]] && printf "%-*s" "$_padTo" ""
    echo -e "${COLOUR[VIVID_BLUE_STDOUT]:-}${gitInfo_description}${COLOUR[OFF_STDOUT]:-}$gitInfo_warning"
}
