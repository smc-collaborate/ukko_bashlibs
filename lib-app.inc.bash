
BUILD_FUNCS_DIR="$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")"
source "${BUILD_FUNCS_DIR%/}/lib-common.inc.bash"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
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
    echo "    \$THIS_DIR            │ The directory of the executable                 │ ${THIS_DIR:-❓  Not defined}"
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
        echo -e "     --colours=no|yes|auto  (Default 'auto')"
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


function app_load_param_validate_from_list()
{
    local name="$1"
    local value="$2"

    shift 2 || true
    #echo "ℹ️  Validating value for $name$value against expected values: [$(asCsvList "$@")]"

    for arg in "$@"; do
        [[ "$arg" == "$value" ]] && return 0
    done
    do_errorExitWithSuggestion "Invalid value for ${name}<value>.  <value> is ${value@Q}, but expected one of [$(asCsvList "$@")]"
}

function load_params()
{
    local am_processing_options='yes'
    function _app_get_param_defaults()
    {
        declare -F app_load_param_defaults  &> /dev/null  || return 0 ; app_load_param_defaults
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
                echo "$(basename "$THIS_EXE") $APP_VERSION"
                exit 0
            elif [[ "$arg" == '--help' ]]; then
                giveStdHelp='yes'
            elif [[ "$arg" == '--colours=no' ]] || [[ "$arg" == '--colours=yes' ]] || [[ "$arg" == '--colours=auto' ]]; then
                colours_load "${arg#--colours=}"
            elif [[ "${APP_SELF_INSTALL:-}" == "yes" ]] ; then
                if [[ "$INSTALLATION_NOTE" == "OK" ]] && [[ "$arg" == "--uninstall" ]] ; then
                    (sleep 0.5 && rm -f "$THIS_EXE" && echo "Removed $THIS_EXE") &
                    exit 0
                elif [[ "$arg" == "--install" ]] ; then # Always permit 'install' even if the app is already installed, as this can be used to fix an installation that is not working (e.g. due to missing copy or missing PATH entry)
                    do_install_directly
                    exit 0
                fi
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
        [[ "$caption" == "$*" ]] || echo -e "Command: ${COLOUR[VIVID_BLUE_STDERR]:-}$*${COLOUR[OFF_STDERR]:-}" >&2
        exit 1
    fi
}



function do_install_directly()
{
    if [[ "$INSTALLATION_NOTE" == "OK" ]]; then
        echo -e "${COLOUR[VIVID_GREEN_STDOUT]:-}✅ $app_name_and_version is already successfully installed to  ${INSTALL_DIR@Q}${COLOUR[OFF_STDOUT]:-}"
        return 0
    fi

    if [[ "$INSTALLATION_NOTE" == *"[NotCopied]"* ]] ; then
        if ! do_ensure_file_set  "$INSTALL_DIR_WITH_EXE" "$THIS_EXE" ; then
            echo "❌  Failed to copy $THIS_EXE to $INSTALL_DIR_WITH_EXE"
            return 1
        fi
    fi

    if [[ "$INSTALLATION_NOTE" == *"[DirNotInPath]"* ]] ; then
        echo "⚠️  $app_name_and_version installed to ${INSTALL_DIR@Q} but it is NOT in PATH. Please add ${INSTALL_DIR@Q} to your PATH environment variable." >&2
        return 1
    fi
     echo "✅  $app_name_and_version installed successfully to ${INSTALL_DIR@Q} and is available in PATH"
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


colours_load 'auto'

# |x| echo "ℹ️  !! RUNNING:  $0 $*" >&2
load_params "$@"

app_run "$@"
