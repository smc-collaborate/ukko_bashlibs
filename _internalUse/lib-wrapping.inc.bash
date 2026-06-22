# shellcheck shell=bash
# shellcheck disable=SC2317

#
# Just has doRunWithWrapping() which does wrapping based on :
#  RUN_WITH_WRAPPING_MODE='tree' 'left-boxed' or not set
#
if [[ "${RUN_WITH_WRAPPING_MODE:-}" == 'left-boxed' ]] ; then
    function doRunWithWrapping()
    {
        local _result=0
        doRun-groupedOutput "$@" || _result="$?"
        return "$_result"
    }
elif [[ "${RUN_WITH_WRAPPING_MODE:-}" == 'tree' ]] ; then

    function doRunWithWrapping()
    {
        treeOutput_Setup ""
        {
            local xxx=0
            "$@" || xxx="$?"
            return "$xxx"
        } 2>&1 | withPrefix "${output_prefix_mid}"

        _result="${PIPESTATUS[0]}"
        treeOutput_Done "$_result"
        return "$_result"
    }
    function treeOutput_Setup()
    {
        local title="${1:-}"
        output_isBase='no'
        output_prefix_mid=""
        output_prefix_end=""

        if [[ -z "${BASE_TREE_SCRIPT:-}" ]] ; then
            export BASE_TREE_SCRIPT="$THIS_EXE"
            output_isBase='yes'
        fi
        [[ -n "$title" ]] || title="Running:⚡  ${COLOUR[YELLOW_USED]:-}${CMD_AS_DISPLAY}${COLOUR[OFF_USED]:-}"

        if [[ "${output_isBase}" == "yes" ]] ; then
            title="Full Process Started: ${title}"
            output_isBase='no'
            echo         -e "$title"
            output_prefix_mid="│  "
            output_prefix_end="└──"
        else
            echo         -e "$title"
            output_prefix_mid="│  "
            output_prefix_end="└──"
        fi
    }

    function treeOutput_Done()
    {
        local result_code="${1:-0}"

        local icon
        local suffix

        if [[ "$result_code" -eq 0 ]] ; then
            icon="✅  "
            suffix="Completed successfully"
        elif [[ "$result_code" -eq 1 ]] ; then
            icon="❌  "
            suffix="Failed"
        else
            icon="❌  "
            suffix="Failed with error code $result_code"
        fi
        [[ "${output_isBase}" != "yes" ]] && echo -n "${output_prefix_end}"
        echo -en "${icon} "
        [[ -n "${APPS_NAME:-}" ]] || echo -en "${APPS_NAME:-"$CMD_AS_DISPLAY"}: "
        echo -e "$suffix"
    }
else
    function doRunWithWrapping()
    {
        local _result=0
        "$@" || _result="$?"
        return "$_result"
    }
fi
