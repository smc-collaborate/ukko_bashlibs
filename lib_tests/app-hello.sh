#!/usr/bin/env bash
 set -eu
 APP_VERSION="1.0.0"
 APP_DESCRIPTION="This app says 'hello'"

function app_help()
{
    echo -e "Usage: ${COLOUR[VIVID_BLUE_HELP]:-}$CMD_AS_DISPLAY [--person=<name>]${COLOUR[OFF_HELP]:-}"
    echo -e "       --person=<name>    Specify the name to greet (default: 'fred')"
}

function app_load_param_defaults()
{
    option_person='fred'
}

function app_load_param_option_name_value()
{
    [[ "$1" == '--person' ]] && option_person="$2" && return 0

    return 1
}
function app_run()
{
    echo "Hello: $option_person"
    giveWarning "This is a warning message - these are sent to stderr"
    echo "This is some more output"
    echo -e "Hidden coding help is available with: ${COLOUR[VIVID_BLUE_STDOUT]:-}$CMD_AS_DISPLAY --code-help${COLOUR[OFF_STDOUT]:-}"
}
# shellcheck disable=SC1091
source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/../lib-app.inc.bash"
