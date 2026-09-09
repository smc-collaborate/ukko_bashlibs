#!/bin/bash -eu
# shellcheck disable=SC2317

PROJ_DIR_REL="../"

function main()
{
    local result_max=0

    checkAllFilesMatch _loader-shim.inc.bash || result_max="$?"

    for proj in "${PROJ_DIR%/}/_sample-projects/"*; do
        if [[ -x "$proj/do-build-and-install.sh" ]] ; then
            local _result=0
            "$proj/do-build-and-install.sh" --with-docker --with-tests || _result="$?"
            if [[ "$_result" -gt "$result_max" ]] ; then
                result_max="$_result"
            fi
        fi
    done

    return "$result_max"
}

function checkAllFilesMatch()
{
    local fname="$1"
    local dir="${2:-.}"

    local numUniques

    numUniques="$(find "$dir" -name "$fname" -exec md5sum {} \; | awk '{ print $1 ; }' | sort -u | wc -l)"
    if [[ "$numUniques" -eq 1 ]] ; then
        echo "   ✓ All files named ${fname@Q} under $(displayPath "$dir") are identical"
        return 0
    elif [[ "$numUniques" -eq 0 ]] ; then
        echo "   ❌ No files named ${fname@Q} under $(displayPath "$dir") are found"
        return 0
    else
        echo "   ❌ All files named ${fname@Q} under $(displayPath "$dir") are not identical:"

        find . -name "$fname" -exec md5sum {} \; | withPrefix "      "

        return 1
    fi
}

source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/../lib-testing.inc.bash"
