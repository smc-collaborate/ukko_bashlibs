#!/usr/bin/env bash
# shellcheck disable=SC2034
set -eu
APP_VERSION="1.0.0"
APP_DESCRIPTION="This app says 'hello'"

function app_help()
{
    echo -e "Usage: ${COLOUR[VIVID_BLUE_USED]:-}$CMD_AS_DISPLAY [--person=<name>]${COLOUR[OFF_USED]:-}"
    echo -e "       --person=<name>    Specify the name to greet (default: 'fred')"
}

function app_load_param_defaults()
{
    option_person='fred'
}

function app_load_param_option_name_value()
{
    [[ "$1" == '--person=' ]] && option_person="$2" && return 0

    return 1
}
function app_run()
{
    echo "Hello: $option_person"
    giveWarning "This is a warning message - these are sent to stderr"
    echo "This is some more output"
    echo -e "Hidden coding help is available with: ${COLOUR[VIVID_BLUE_STDOUT]:-}$CMD_AS_DISPLAY --code-help${COLOUR[OFF_STDOUT]:-}"

    if [[ "$option_person" == "10" ]] ; then
        hello "world"
        echo "Said hello to the world"
    fi
}
# shellcheck source=/dev/null
source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/libs/shim-lib-app.inc.bash"
