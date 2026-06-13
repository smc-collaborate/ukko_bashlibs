#!/usr/bin/env bash
 set -eu
 APP_VERSION="1.0.0"
 APP_DESCRIPTION="This app says 'hello'"

function app_help()
{
    echo -e "Usage: ${COLOUR_BOLD_BLUE}$CMD_AS_DISPLAY [--person=<name>]${COLOUR_OFF}"
    echo -e "       --person=<name>    Specify the name to greet (default: 'fred')"
}
function app_load_param()
{
    local load_type="$1"
    local value="${2:-}"
    case "$load_type" in
        'all-defaults')
            # set any default values for parameters here
            option_person='fred'
            ;;
        'option-arg')
            # process any options here (e.g. --my-option=value)
            if [[ "$value" == '--person='* ]]; then
                option_person="${value#--person=}"
            else
                return 1
            fi
            ;;
        'direct-arg')
            # process any direct arguments here (e.g. myscript.sh arg1 arg2)
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}
function app_run()
{
    echo "Hello: $option_person"
    giveWarning "This is a warning message - these are sent to stderr"
    echo "This is some more output"
    echo -e "Hidden coding help is available with with: ${COLOUR[BOLD_BLUE_STDOUT]:-}$CMD_AS_DISPLAY --code-help${COLOUR[OFF_STDOUT]:-}"
}
# shellcheck disable=SC1091
source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/../lib-app.inc.bash"
