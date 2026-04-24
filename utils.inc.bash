# shellcheck shell=bash
################
#
#
# IMPORT THIS AS A 'source' script
#   source tools/utils.inc.bash
#
function displayPath()
{
    local result
    local other

    #|x|echo "[displayPath $*]"
    result="$(realpath "${1}")"
    other="$(realpath --relative-to="${ORIG_PWD%/}/" "${result}")"

    result="${result/#$HOME/\~}"


    #|x|echo "[so_far:$result|other:$other]"

    [[ "${#result}" -gt  "${#other}" ]] && result="$other"



    echo "$result"
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
if [[ -t 1 ]] ; then
    # Enable colors only if output is a terminal
    export RED='\033[0;31m'
    export GREEN='\033[0;32m'
    export YELLOW='\033[1;33m'
    export BLUE='\033[0;34m'
    export BOLD_BLUE="\033[1;34m"
    export NC='\033[0m' # No Color
    extraVerboseLogging "Colors enabled for output"
else
    # Disable colors if output is not a terminal (e.g., when redirected to a file)
    export RED=''
    export GREEN=''
    export YELLOW=''
    export BLUE=''
    export BOLD_BLUE=''
    export NC=''
    extraVerboseLogging "Colors disabled for output"
fi

if [[ -z "${ORIG_PWD:-}" ]] ; then
  export ORIG_PWD ; ORIG_PWD="$(pwd)"
  extraVerboseLogging "ORIG_PWD                   = [${ORIG_PWD}]"
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
