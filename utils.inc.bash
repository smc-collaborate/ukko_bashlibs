# shellcheck shell=bash
################
#
#
# IMPORT THIS AS A 'source' script
#   source tools/utils.inc.bash
#
function displayPath()
{
    local orig
    local result
    local relpath

    orig="$(realpath "${1}")"
    relpath="$(realpath --relative-to="${ORIG_PWD%/}/" "${orig}")"
    result="${orig/#$HOME/\~}"

    [[ "${#result}" -gt  "${#relpath}" ]] && result="$relpath"

    echo -n "$result"
    #|Logging| echo -n "[displayPath $*][real=$orig][relpath=${ORIG_PWD}+$relpath]"
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


# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export BOLD_BLUE="\033[1;34m"
export NC='\033[0m' # No Color

if [[ -t 1 ]] ; then
    # Enable colors only if stdout is a terminal
    export RED_STDOUT="$RED"
    export GREEN_STDOUT="$GREEN"
    export YELLOW_STDOUT="$YELLOW"
    export BLUE_STDOUT="$BLUE"
    export BOLD_BLUE_STDOUT="$BOLD_BLUE"
    export NC_STDOUT="$NC"
    extraVerboseLogging "Colors enabled for output [stdout]"
fi

if [[ -t 2 ]] ; then
    # Enable colors only if stderr is a terminal
    export RED_STDERR="$RED"
    export GREEN_STDERR="$GREEN"
    export YELLOW_STDERR="$YELLOW"
    export BLUE_STDERR="$BLUE"
    export BOLD_BLUE_STDERR="$BOLD_BLUE"
    export NC_STDERR="$NC"
    extraVerboseLogging "Colors enabled for output [stderr]"
fi

if [[ -z "${ORIG_PWD:-}" ]] ; then
  #|Logging| echo "🛈  Setting ORIG_PWD to [$(pwd)]"
  export ORIG_PWD ; ORIG_PWD="$(pwd)"
  extraVerboseLogging "ORIG_PWD                   = [${ORIG_PWD}]"
#|Logging|else
#|Logging|  echo "🛈  ORIG_PWD already set to [${ORIG_PWD}]"
fi

if [[ -z "${THIS_EXE_FROM_ORIGINAL_PWD:-}" ]] ; then
  export THIS_EXE_FROM_ORIGINAL_PWD ;
  if [[ $0 == /* ]] ; then
    THIS_EXE_FROM_ORIGINAL_PWD="$0"
  else
    THIS_EXE_FROM_ORIGINAL_PWD="$(relativeToOrigPwd "$0")"
    if [[ "${THIS_EXE_FROM_ORIGINAL_PWD}" != *"/"* ]] ; then
      THIS_EXE_FROM_ORIGINAL_PWD="./${THIS_EXE_FROM_ORIGINAL_PWD}"
    fi
  fi
  extraVerboseLogging "THIS_EXE_FROM_ORIGINAL_PWD = [${THIS_EXE_FROM_ORIGINAL_PWD}]"
fi

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
    THIS_EXE="${THIS_EXE_FROM_ORIGINAL_PWD}"
    if [[ "${THIS_EXE}" == '../' ]] || [[ "${THIS_EXE}" == './' ]] ; then
        THIS_EXE="${ORIG_PWD%/}/${THIS_EXE}"
    fi

    THIS_EXE="$(realpath -m "${THIS_EXE}")"
fi
[[ -n "${THIS_DIR:-}" ]] || THIS_DIR="$(realpath -m "$(dirname "${THIS_EXE}")")"


overallBashResult=0
function doRun()
{
    local silent_if_ok=no

    if [[ "${1:-}" == "--silent-if-ok" ]] ; then
        silent_if_ok=yes
        shift 1 || true
    fi

    local result=0

    local tmpfile ; tmpfile="$(mktemp "/tmp/doRun.XXXXXX")"


    "$@" &> "$tmpfile" || result=$?

    if [[ "$result" == 0 ]]; then
        [[ "$silent_if_ok" == "yes" ]] && return 0
        echo "      ✓ Ran: $*"
    else
        echo "      ✗ Ran: $*"
        echo "        ❌ Responded with Failure: $result"
        # shellcheck disable=SC2034
        overallBashResult="$result"
    fi
    if [[ -s "$tmpfile" ]] ; then
           echo "             ┌───────────────────────────────────────────────────────────────────────"
        sed "s/^/             │ /" < "$tmpfile"
           echo "             └───────────────────────────────────────────────────────────────────────"
    fi
    rm -f "$tmpfile"
    return $result
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
    local displayLink

    displayLink="$(displayPath "$link")"
    displayLink="${displayLink:-"$link"}"
    if [[ -L "$link" ]] ; then
        if [[ -n "${optional_unless_target}" ]] && [[ "$(readlink -f "$link")" == "$(readlink -f "$optional_unless_target")" ]] ; then
            echo "    • Link confirmed: $displayLink -> $(displayPath "$optional_unless_target")"
        else
            doWithSuccessMsg "    • Unlinked existing: $displayLink"  unlink "$link"  || return $?
        fi
    elif [[ -e "$link" ]] ; then
        doWithSuccessMsg "    • Removed existing file/directory: $displayLink"  rm -rf "$link" || return $?
    fi
}

function do_ensure_link()
{
    local link="$1"
    local target="$2"

    if [[ "${AM_CLEANING:-}" == 'yes' ]] ; then
        do_remove_link "$link" || return $?
    elif [[ -L "$link" ]] && [[ "$(readlink -f "$link")" == "$(readlink -f "$target")" ]] ; then
        echo "    • Link confirmed: $link -> $(displayPath "$target")"
    else
        do_remove_link "$link" || return $?
        doWithSuccessMsg "    • Created link: $link -> $(displayPath "$target")"  ln -s "$target" "$link" || return $?
    fi

    return 0
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
        doWithSuccessMsg "    • Updated permissions for $(displayPath "$dest_fname") : $dst_attr -> $src_attr"  chmod "$src_attr" "$dest_fname" || return $?
        gave_success_msg='yes'
    fi


    [[ "$gave_success_msg" == 'yes' ]] || echo "    • File confirmed: $(displayPath "$dest_fname")"
    return 0
}
