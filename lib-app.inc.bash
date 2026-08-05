# shellcheck shell=bash
# shellcheck disable=SC2317

BUILD_FUNCS_DIR="$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")"
source "${BUILD_FUNCS_DIR%/}/lib-common.inc.bash"


APP_PARAMS=("$@")

function exitWithVersion()
{
    echo "$CMD_AS_DISPLAY ${APP_VERSION:-v?.?.?}"
    exit 0
}

if [[ -n "${APP_VERSION:-}" ]]; then
    # Do outside of all the wrappers so that it is always available, even if there is a problem with the wrapper setup
    for arg in "$@"; do
        [[ "$arg" == '--version' ]] && exitWithVersion
    done
fi


#==============================================================================================
#
# This is a standard template for bash scripts that uses:
#  * APP_VERSION     | Optional but recommended
#  * APP_DESCRIPTION | Optional
#
#  * app_help        | Optional but recommended
#  * app_load_param  | Optional but recommended
#  * app_run         | Required
#
# Example usage:
#
# ╭─────────────────────────────────────────────────────────────────────────────────────
# │ #!/usr/bin/env bash
# │  set -eu
# │  APP_VERSION="1.0.0"
# │  APP_DESCRIPTION="This app says 'hello'"
# │
# │ function app_help()
# │ {
# │     echo -e "Usage: ${COLOUR[VIVID_BLUE_USED]:-}$CMD_AS_DISPLAY [--person=<name>]${COLOUR[OFF_USED]:-}"
# │     echo -e "       --person=<name>    Specify the name to greet (default: 'fred')"
# │ }
# │
# │ function app_load_param_defaults()
# │ {
# │     option_person='fred'
# │ }
# │
# │ function app_load_param_option_name_value()
# │ {
# │     [[ "$1" == '--person' ]] && option_person="$2" && return 0
# │
# │     return 1
# │ }
# │ function app_run()
# │ {
# │     echo "Hello: $option_person"
# │     giveWarning "This is a warning message - these are sent to stderr"
# │     echo "This is some more output"
# │     echo -e "Hidden coding help is available with: ${COLOUR[VIVID_BLUE_STDOUT]:-}$CMD_AS_DISPLAY --code-help${COLOUR[OFF_STDOUT]:-}"
# │ }
# │ # shellcheck disable=SC1091
# │ source "$(git-shared-checkout git@github.com:smc-collaborate/ukko_bashlibs --ref="${UKKO_BASHLIBS_REF:-}")/lib-common.inc.bash"
# ╰─────────────────────────────────────────────────────────────────────────────────────
#
# It makes available:
#
#    $EXE_NAME
#    $THIS_EXE
#    do_errorExitWithSuggestion  "<optional error message>"
#    do_with_check <command...>  - Run a command and exit with an error message if it fails
#    giveWarning "<warning message>" - Give a warning message that will be shown at the end of processing (if any)
#

function padRight()
{
    local width="$1"
    local text="$2"

    [[ "$width" -lt 0 ]] && width=0
    printf "%-${width}s" "$text"
}

function giveCodeHelp()
{
    # this is dumped with the hidden option '--code-help'

    echo " This is a standard template for bash scripts that uses:"
    echo "  * APP_VERSION                                   | Optional but recommended"
    echo "  * APP_DESCRIPTION                               | Optional"
    echo ""
    echo "  * app_help()                                    | Optional but recommended"
    echo "  * app_load_param_defaults()                     | Optional but recommended"
    echo "  * app_load_param_option_name_value(name,value)  | Optional but recommended"
    echo "  * app_load_param_direct_value(value)            | Optional"
    echo "  * app_run()                                     | Required"
    echo ""
    echo " It makes available:"
    echo ""
    echo  "    Name                 │ Description                                     │ Value"
    echo  "    ─────────────────────┼─────────────────────────────────────────────────┼────────────────────────"
    echo "    \$EXE_NAME            │ The name of the executable (e.g. 'myscript.sh') │ ${EXE_NAME:-❓  Not defined}"
    echo "    \$THIS_EXE            │ The full path to the executable                 │ ${THIS_EXE:-❓  Not defined}"
    echo "    \$EXE_DIR             │ The directory of the executable                 │ ${EXE_DIR:-❓  Not defined}"
    echo "    \$PROJ_DIR            │ The root directory of the project               │ ${PROJ_DIR:-❓  Not defined}"
    echo "    \$THIS_EXE_AS_DISPLAY │ The display path of the executable              │ ${THIS_EXE_AS_DISPLAY:-❓  Not defined}"
    echo "    \$CMD_AS_DISPLAY      │ The executable in a form that can be run        │ ${CMD_AS_DISPLAY:-❓  Not defined}"
    echo ""
    echo "    do_exitWithHelp  '<optional error message>'"
    echo "    do_errorExitWithSuggestion  '<error message>'"
    echo "    do_with_check <command...>  - Run a command and exit with an error message if it fails"
    echo "    giveWarning '<warning message>' - Give a warning message that will be shown at the end of processing (if any)"
    echo "   "

    colours_show
}

# shellcheck disable=SC2317
function do_errorExitWithSuggestion()
{
    local fatal_error_message="${1:-}"
    {
        echo -e "${COLOUR[VIVID_RED_STDERR]:-}❌  $fatal_error_message${COLOUR[OFF_STDERR]:-}"
        echo -e "Suggest: ${COLOUR[VIVID_BLUE_STDOUT]:-}$CMD_AS_DISPLAY --help${COLOUR[OFF_STDOUT]:-}"
    } >&2
    exit 1
}

function do_errorExitWithSuggestion()
{
    local fatal_error_message="${1:-}"
    {
        echo -e "${COLOUR[VIVID_RED_STDERR]:-}❌  $fatal_error_message${COLOUR[OFF_STDERR]:-}"
        echo -e "Suggest: ${COLOUR[VIVID_BLUE_STDOUT]:-}$CMD_AS_DISPLAY --help${COLOUR[OFF_STDOUT]:-}"
    } >&2
    exit 1
}

function do_exitWithHelp()
{
    local fatal_error_message="${1:-}"

    [[ -n "$fatal_error_message" ]] && echo -e "${COLOUR[VIVID_RED_STDERR]:-}❌  $fatal_error_message${COLOUR[OFF_STDERR]:-}" >&2
    {

        colours_setUsed 'STDOUT'

        [[ -n "${APP_DESCRIPTION:-}" ]] && echo -e "$CMD_AS_DISPLAY: $APP_DESCRIPTION"
        if declare -F app_help >/dev/null 2>&1 ; then
            app_help
            echo ""
            echo -e "Additional functions:"
        else
            echo -e "Usage: ${COLOUR[VIVID_BLUE_USED]:-}$CMD_AS_DISPLAY <parameters>${COLOUR[OFF_USED]:-}"
            echo -e ""
            echo -e "Parameters:"
        fi
        echo -e "     --help     : Give this help message"
        [[ -n "${APP_VERSION:-}" ]] && echo -e "     --version  : Give version : ${COLOUR[VIVID_BLUE_USED]:-}$APP_VERSION${COLOUR[OFF_USED]:-}"

        _installDirShow="$(displayPath "$INSTALL_DIR")"
        [[ ":$PATH:" == *":${INSTALL_DIR}:"* ]] || _installDirShow+="${COLOUR[VIVID_RED_USED]:-}  ⚠️  This should be added to \$PATH${COLOUR[OFF_USED]:-}"
        if [[ "${APP_SELF_INSTALL:-}" == "yes" ]] ; then
            if [[ "$INSTALLATION_NOTE" == "OK" ]] ; then
                echo -e "     --uninstall: Uninstalls from $_installDirShow"
            else
                echo -e "     --install  : Installs to $_installDirShow "
            fi
        fi
        echo -e "     --colours=no|yes   (Default: yes)" # |auto  (Default 'auto')"
        echo ""
        echo "Runs with shared checkout:"
        echo -n "     •  "
        dump_sharedCheckout_gitInfoOnDir ""

    } | withLeftBox

    if [[ -n "$fatal_error_message" ]]; then
        exit 1
    else
        exit 0
    fi
}
function do_withOptionalTiming()
{
    local with_timing="$1"
    shift 1
    local result=0

    if [[ "${with_timing:-}" == 'yes' ]]; then
        TIMEFORMAT=$'\n-- Total Time Summary ---\nReal:  %3Rs\nUser:  %3Us\nSys:   %3Ss\nCPU:   %P%%\n----------------------'
        time "$@" || result="$?"
    else
        "$@" || result="$?"
    fi
    # |!!>| echo "!!!!!!!!! do_withOptionalTiming[$*] : Result: $result" >&2
    return "$result"
}

function bashlibs_warn_on_version_if_needed()
{
    if [[ -n "${UKKO_BASHLIBS_REF_FORCE:-}" ]] && [[ "${UKKO_BASHLIBS_REF_FORCE:-}" != "${UKKO_BASHLIBS_REF_PREFERRED:-}" ]] ; then
        echo -n "⚠️  UKKO_BASHLIBS_REF_FORCE=$UKKO_BASHLIBS_REF_FORCE"
        [[ -n "${UKKO_BASHLIBS_REF_PREFERRED:-}" ]] && echo -n " (Preferred: '${UKKO_BASHLIBS_REF_PREFERRED:-}')"
        echo ""
    fi
}



# Return with no argument if name starts with '!'
#
# param_choose_from_list "exit" "$1" "$2" fred mary tom
# ---------------|-----------------------|--------------
#  selected_name | Params $1,$2          | Result
# ---------------|-----------------------|--------------
#   value        | --value= fred           -> true
#   value        | --value= mary           -> true
#   value        | --value= tom            -> true
#  !value        | --value= fred           -> true
#  !value        | --value= mary           -> true
#  !value        | --value= tom            -> true
# ---------------|-----------------------|--------------
#   value        | --value                 ->      FALSE
#  !value        | --value                 -> true
# ---------------|-----------------------|--------------
#   value        | --value= other          ->      FALSE
#  !value        | --value= other          ->      FALSE
#   value        | --value=                ->      FALSE
#  !value        | --value=                ->      FALSE
# ---------------|-----------------------|--------------
function param_choose_from_list()
{
    function _param_choose_from_list()
    {
        local name_for_comparison="$1"
        local decorated_name_passed="$2"
        local value_passed="$3"

        if [[ "$name_for_comparison" == '--'* ]] || [[ "$name_for_comparison" == *'=' ]] ; then
            local _bad="$name_for_comparison"
            name_for_comparison="${name_for_comparison#--}"
            name_for_comparison="${name_for_comparison%=}"
            echo -e "⚠️  Deprecated - param_choose_####() ${name_for_comparison@Q} rather than ${_bad@Q}" >&2
        fi

        if [[ "${name_for_comparison}" == '!'* ]] ; then
            name_for_comparison="${name_for_comparison#'!'}"
            # Accept default if the name is passed without '=value' (e.g. '--exit' rather than '--exit=yes' or '--exit=no')
            [[ "$decorated_name_passed" == "--${name_for_comparison}" ]] && return 0
        fi

        [[ "$decorated_name_passed" == "--${name_for_comparison}=" ]] || return 1


        shift 3 || true

        app_load_param_validate_from_list "--${name_for_comparison}=" "${value_passed}" "$@"
    }
    local _result=0
    _param_choose_from_list "$@" || _result=$?


    # |Logging| echo "ℹ️  param_choose_from_list($*) : Result: ${_result}" >&2
    return "$_result"
}

# Return with no argument if name starts with '!'
#
# param_choose_yes_no "exit" "$1" "$2"
# ---------------|-----------------------|--------------
#  selected_name | Params $1,$2          | Result
# ---------------|-----------------------|--------------
#   exit         | --exit= yes             -> true
#   exit         | --exit= no              -> true
#  !exit         | --exit= yes             -> true
#  !exit         | --exit= no              -> true
# ---------------|-----------------------|--------------
#   exit         | --exit                  ->      FALSE
#  !exit         | --exit                  -> true
# ---------------|-----------------------|--------------
#   exit         | --exit= other           ->      FALSE
#  !exit         | --exit= other           ->      FALSE
#   exit         | --exit=                 ->      FALSE
#  !exit         | --exit=                 ->      FALSE
# ---------------|-----------------------|--------------
function param_choose_yes_no()
{
    param_choose_from_list "$@" "yes" "no"
}

#
# ref_name="$1"
# provided_name="$2"
# provided_value_txt="$3"
# min_value
# max_value
function param_int()
{
    local ref_name="$1"
    local provided_name="$2"
    local provided_value_txt="$3"
    local min_value="${4:-}"
    local max_value="${5:-}"

    [[ "$ref_name" == "$provided_name" ]] || return 1

    local caption="${!ref_name}[${min_value}…${max_value}]"
    print_extraVerbose "$caption : Validating ${provided_value_txt@Q}"

    [[ "$provided_value_txt" =~ ^[+-]?[0-9]+$ ]] || do_errorExitWithSuggestion "Invalid value for $caption: ${provided_value_txt@Q} is not an integer"

    local provided_value="$provided_value_txt"
    [[ -n "$min_value" ]] && [[ "$provided_value" -lt "$min_value" ]] && do_errorExitWithSuggestion "Invalid value for $caption: ${provided_value@Q} is less than minimum allowed value of $min_value"
    [[ -n "$max_value" ]] && [[ "$provided_value" -gt "$max_value" ]] && do_errorExitWithSuggestion "Invalid value for $caption: ${provided_value@Q} is greater than maximum allowed value of $max_value"

    return 0
}

function app_load_param_validate_from_list()
{
    local name="$1"
    local value="$2"

    shift 2 || true
    print_extraVerbose  "app_load_param_validate_from_list[$name,$value]: ($*) : Validating value for $name$value against expected values: [$(asCsvList "$@")]"

    for arg in "$@"; do
        [[ "$arg" == "$value" ]] && return 0
    done

    if [[ "$#" == 1 ]]; then
        do_errorExitWithSuggestion "Invalid value for $name<value>.  Expected: ${1@Q}, but got ${value@Q}"
    else
        do_errorExitWithSuggestion "Invalid value for ${name}<value>.  <value> is ${value@Q}, but expected one of [$(asCsvList "$@")]"
    fi
}

function load_params()
{
    local am_processing_options='yes'
    function _app_get_param_defaults()
    {
        declare -F app_load_param_defaults  &> /dev/null  || return 0
        app_load_param_defaults
    }
    function _app_get_param_review()
    {
        declare -F app_params_review  &> /dev/null  || return 0
        app_params_review
    }

    function _app_get_param_option_name_value()
    {
        declare -F app_load_param_option_name_value  &> /dev/null  && app_load_param_option_name_value "$1" "${2:-}"
    }


    function _app_get_param_direct_value()
    {
        declare -F app_load_param_direct_value  &> /dev/null  && app_load_param_direct_value "$1"
    }


    _app_get_param_defaults
    local giveCodeHelp='no'
    local giveStdHelp='no'

    for arg in "$@"; do
        [[ -z "$arg" ]] && continue
        if [[ "$am_processing_options" == "yes" ]] && [[ "$arg" == '-'* ]]; then
            if [[ "$arg" == '--' ]] ; then
                am_processing_options='no'
            elif [[ "$arg" == '--version' ]] && [[ -n "${APP_VERSION:-}" ]]; then
                exitWithVersion
            elif [[ "$arg" == '--help' ]]; then
                giveStdHelp='yes'
            elif [[ "$arg" == '--colours=no' ]] || [[ "$arg" == '--colours=yes' ]] || [[ "$arg" == '--colours=auto' ]]; then
                colours_load "${arg#--colours=}"
            elif [[ "${APP_SELF_INSTALL:-}" == "yes" ]] && [[ "$INSTALLATION_NOTE" == "OK" ]] && [[ "$arg" == "--uninstall" ]] ; then
                (sleep 0.5 && rm -f "$THIS_EXE" && echo "Removed $THIS_EXE") &
                exit 0
            elif [[ "${APP_SELF_INSTALL:-}" == "yes" ]] && [[ "$arg" == "--install" ]] ; then # Always permit 'install' even if the app is already installed, as this can be used to fix an installation that is not working (e.g. due to missing copy or missing PATH entry)
                do_install_directly "      "
                exit 0
            elif [[ "$arg" == '--code-help' ]] ; then
                giveCodeHelp='yes'
            elif [[ "$arg" == "--"*"="* ]] ; then
                _app_get_param_option_name_value "${arg%%=*}=" "${arg#*=}" || do_errorExitWithSuggestion "Unknown named option ${arg@Q}"
            else
                _app_get_param_option_name_value "${arg}"                  || do_errorExitWithSuggestion "Unknown option ${arg@Q}"
            fi
        else
            _app_get_param_direct_value "$arg" || do_errorExitWithSuggestion "Unknown direct argument ${arg@Q}"
        fi
    done

    if [[ "$giveCodeHelp" == "yes" ]]; then
        giveCodeHelp
        exit 0
    elif [[ "$giveStdHelp" == "yes" ]]; then
        do_exitWithHelp ""
    fi
    _app_get_param_review
}

function do_with_check()
{
    local caption="$*"

    local caption_decorated="$*"
    if [[ "$1" == '--caption='* ]]; then
        caption="${1#--caption=}"
        shift
    else
        caption_decorated="${COLOUR[VIVID_BLUE_STDERR]:-}$caption${COLOUR[OFF_STDERR]:-}"
    fi
    local status=0
    local suffix=''

    echo -e "Running : ${caption_decorated}" >&2
    "$@" || status=$?
    if [[ "$status" == 0 ]] ; then
        true #echo -e "          -- OK" >&2
    else
        [[ "$status" == 1 ]] || suffix=" with status $status"
        echo -e "Ran    :${COLOUR[VIVID_RED_STDERR]:-}$caption${COLOUR[OFF_STDERR]:-} -- Failed$suffix" >&2
        [[ "$caption" == "$*" ]] || echo -e "Command: ${COLOUR[VIVID_BLUE_STDERR]:-}$(quoteIfNeeded "$@")${COLOUR[OFF_STDERR]:-}" >&2
        exit 1
    fi
}


function do_install_directly()
{
    local prefix="${1:-}"
    if [[ "$INSTALLATION_NOTE" == "OK" ]]; then
        echo -e "${prefix}${COLOUR[VIVID_GREEN_STDOUT]:-}✅ $app_name_and_version is already successfully installed to  ${INSTALL_DIR@Q}${COLOUR[OFF_STDOUT]:-}"
        return 0
    fi

    if [[ "$INSTALLATION_NOTE" == *"[NotCopied]"* ]] ; then
        if ! do_ensure_file_set  "$INSTALL_DIR_WITH_EXE" "$THIS_EXE" ; then
            echo -e "${prefix}${COLOUR[VIVID_RED_STDERR]:-}❌  Failed to copy $THIS_EXE to $INSTALL_DIR_WITH_EXE${COLOUR[OFF_STDERR]:-}"
            return 1
        fi
    fi

    if [[ "$INSTALLATION_NOTE" == *"[DirNotInPath]"* ]] ; then
        echo -e "${prefix}${COLOUR[VIVID_RED_STDERR]:-}⚠️  $app_name_and_version installed to ${INSTALL_DIR@Q} but it is NOT in PATH. Please add ${INSTALL_DIR@Q} to your PATH environment variable.${COLOUR[OFF_STDERR]:-}" >&2
        return 1
    fi
     echo -e "${prefix}✅  ${COLOUR[VIVID_BLUE_STDOUT]:-}$app_name_and_version${COLOUR[OFF_STDOUT]:-} installed successfully to ${INSTALL_DIR@Q} and is available in PATH"
}


hadWarning='no'
function giveWarning()
{
    # shellcheck disable=SC2034
    hadWarning='yes'
    [[ -n "$*" ]] && echo -e "${COLOUR[VIVID_RED_STDERR]:-}⚠️  $*${COLOUR[OFF_STDERR]:-}" >&2
}


EXE_NAME="$(basename "$THIS_EXE")"
app_name_and_version="${EXE_NAME}"
[[ "${APP_VERSION:-}" ]] && app_name_and_version+=" ($APP_VERSION)"

INSTALL_DIR="${HOME%/}/.local/bin" ; [[ "$EUID" -eq 0 ]] && INSTALL_DIR="/usr/local/bin"
INSTALL_DIR_WITH_EXE="${INSTALL_DIR%/}/$EXE_NAME"
INSTALLATION_NOTE=''
if [[ "$INSTALL_DIR_WITH_EXE" != "$THIS_EXE" ]]; then
    INSTALLATION_NOTE+='[NotCopied]'
elif ! [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
    INSTALLATION_NOTE+='[DirNotInPath]'
else
    INSTALLATION_NOTE+='OK'
fi


function colours_show()
{

        echo '╭─────────────────────────────────────────────────────────'
        {
            echo "Colour support is available in the script:"
            echo "  eg: echo -e \"This is \${COLOUR[VIVID_BLUE_STDOUT]:-}blue\${COLOUR[OFF_STDOUT]:-}\""
            echo "      echo -e \"This is \${COLOUR[VIVID_BLUE_STDERR]:-}blue\${COLOUR[OFF_STDERR]:-}\" >&2"
            echo ""
            echo "Redirection of stdout and stderr will automatically disable colours for that stream (e.g. \"echo test > out.txt\" or \"echo test 2> err.txt\")"
            echo "You can also force enable or disable colours with the --colours option (e.g. \"--colours=yes\" or \"--colours=no\")"
            echo ""

            if [[ "${#COLOUR[@]}" == 0 ]] ; then
                echo "There are no colours available in the current configuration:  ($UKKO_COLOURS_CHOSEN)"
            else

                echo "The colours available in the current configuration ($UKKO_COLOURS_CHOSEN) are:"

                for colourName in "${!COLOUR[@]}"; do
                    if [[ "$colourName" != "OFF"* ]]; then
                        if [[ "$colourName" == *"_STDOUT" ]]; then
                            offCode="OFF_STDOUT"
                        elif [[ "$colourName" == *"_STDERR" ]]; then
                            offCode="OFF_STDERR"
                        elif [[ "$colourName" == *"_FORCED" ]]; then
                            offCode="OFF_FORCED"
                        else
                            offCode="OFF"
                        fi

                        printf ' • echo -e %-34s%-22s%-28s → ' "\"\${COLOUR[$colourName]:-}\"" "${colourName@Q}" "\"\${COLOUR[$offCode]:-}\""
                        echo -e "${COLOUR[$colourName]}$colourName${COLOUR[$offCode]:-}"

                    fi
                done
            fi
            echo ""
            list=''
            for colourName in "${!COLOUR_CODES[@]}"; do
                if [[ "$colourName" != "OFF" ]] ; then
                [[ -z "$list" ]] || list+=","
                list+=" $colourName"
                fi
            done
            echo "The base colours are: ${list}"
            echo ""
        } | sed --unbuffered 's/^/│/g'
        echo '╰─────────────────────────────────────────────────────────'
}



#################
#

function app_dumpInfo()
{
    local reason="${1:-}"

    function dumpEntry_txt()
    {
        local name="$1"
        local value="$2"

        printf " • %-32s = %s\n" "${name}" "${value}"
    }

    function dumpEntry_var()
    {
        local name="$1"
        shift 1 || true

        local value_txt

        if [[ -v "$name" ]]; then
            local value="${!name}"
            value_txt="$(quoteIfNeeded "${value}")"
        elif [[ $(declare -p "$name" 2>/dev/null) == "declare -a"* ]]; then
            name="${name}[@]"
            value_txt="[$(asCsvList "${!name}")]"
        elif [[ $(declare -p "$name" 2>/dev/null) == "declare -A"* ]]; then
            value_txt="{"
            name="${name}[@]"
            for key in "${!name}" ; do
                local ref="${name[$key]}"
                value_txt+=" $(quoteIfNeeded "$key"): $(quoteIfNeeded "${!ref}")"
            done
            value_txt+="}"
        else
            value_txt="<not set>"
            return 0
        fi
        dumpEntry_txt "\$${name}" "$value_txt" "$*"

    }


    {
        [[ -n "$reason" ]] && echo -e "$reason\n"
        echo -n "$CMD_AS_DISPLAY"
        for x in "${APP_PARAMS[@]}" ; do
            echo -n ' '
            quoteIfNeeded "$x"
        done
        echo ""

        local options=("${!option_@}")
        for option in "${options[@]}" ; do
            dumpEntry_var "${option}" "${option@a}"
        done
        echo ""
        dumpEntry_var "APPS_NAME"
        dumpEntry_var "SUGGEST_HOW_TO_INSTALL_TO_ROOT"
        dumpEntry_var "VERIFY_ON_BUILD_ENVIRONMENTS"
        dumpEntry_var "PWD"
        dumpEntry_var "ORIG_PWD"
        dumpEntry_var "PROJ_DIR"
        dumpEntry_var "EXE_DIR"
        dumpEntry_var "EXE_DIR_AS_DISPLAY"
        dumpEntry_var "APP_SELF_INSTALL"
        [[ "${INSTALLATION_NOTE:-[NotCopied]}" == "[NotCopied]" ]] || dumpEntry_var "INSTALLATION_NOTE"
        dumpEntry_txt "colours"               "${UKKO_COLOURS_CHOSEN@Q}"

    } | withLeftBox >&2
}


function app_contentsFull()
{
    local value=0
    {
        local _runValue=0
        load_params "$@" || _runValue="$?"
         # |!!>| echo "!!> app_contentsFull.load_params() : $_runValue" >&2
        [[ "${UKKO_VERBOSITY:-}" == 'all' ]] && app_dumpInfo "ℹ️  Summarising parameters and environment:  \$UKKO_VERBOSITY=${UKKO_VERBOSITY@Q}"
        app_run "$@" || _runValue="$?"
        # |!!>| echo "!!> app_contentsFull.app_run() :  $_runValue" >&2

        return "$_runValue"
    } || value=0

    # |!!>| echo "!!> app_contentsFull: $value" >&2
    # |!!>| app_result_include "$?" 'app_contentsFull'

    # |!!>| app_result_include read-and-flush 'app_contentsFull'

    return "$value"
}


source "${BUILD_FUNCS_DIR%/}/_internalUse/lib-wrapping.inc.bash"
declare -F app_init  &> /dev/null  && app_init   # Must be outside of the 'full' as it sets up things for the tree ..

_xxa=0
# |!!>| echo "!!> lib-app Calling" >&2
doRunWithWrapping app_contentsFull "$@" || _xxa=$?
# |!!>| echo "!!> lib-app returned[$0] with $_xxa" >&2
exit "$_xxa"
