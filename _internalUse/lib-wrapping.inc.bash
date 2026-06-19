# shellcheck shell=bash
# shellcheck disable=SC2317

#
# Just has doRunWithWrapping() which does wrapping based on :
#  RUN_WITH_WRAPPING_MODE='tree'
#
if [[ "${RUN_WITH_WRAPPING_MODE:-}" != 'tree' ]] ; then
    function doRunWithWrapping()
    {
        local _result=0
        "$@" || _result="$?"
        return "$_result"
    }

else

    function doRunWithWrapping()
    {
        # echo "ℹ️  Tree output mode enabled for ${APPS_NAME:-?APP?}" >&2
        treeOutput_Setup ""
        {
            local xxx=0
            "$@" || xxx="$?"
            return "$xxx"
        } 2>&1 | withPrefix "${tree_prefix_mid}"

        _result="${PIPESTATUS[0]}"
        treeOutput_Done "$_result"
        return "$_result"
    }

    function treeOutput_Setup()
    {
        local title="${1:-}"
        treeOutput_isBase='no'
        tree_prefix_mid=""
        tree_prefix_end=""


        if [[ -z "${BASE_TREE_SCRIPT:-}" ]] ; then
            export BASE_TREE_SCRIPT="$THIS_EXE"
            treeOutput_isBase='yes'
        fi

        [[ -n "$title" ]] || title="Running:⚡  ${COLOUR[YELLOW_USED]:-}${CMD_AS_DISPLAY}${COLOUR[OFF_USED]:-}"

        if [[ "${treeOutput_isBase}" == "yes" ]] ; then
            echo -e "Full Process Started: ${title}"
        else
            echo         -e "├── $title"
            tree_prefix_mid="│   │  "
            tree_prefix_end="│   "
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
        [[ "${treeOutput_isBase}" != "yes" ]] && echo -n "${tree_prefix_end}└─ "
        echo -en "${icon} "
        [[ -n "${APPS_NAME:-}" ]] || echo -en "${APPS_NAME:-<APP>}: "
        echo -e "$suffix"
    }
fi
