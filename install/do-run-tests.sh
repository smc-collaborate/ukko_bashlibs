#!/bin/bash -eu
PROJ_DIR_REL="../"
function main()
{
    checkAllFilesMatch _loader-shim.inc.bash

    for proj in "${PROJ_DIR%/}/_sample-projects/"*; do
        if [[ -x "$proj/do-build-and-install.sh" ]] ; then
            "$proj/do-build-and-install.sh" --with-docker --with-tests
            return 0
        fi
    done
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
