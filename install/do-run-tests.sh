#!/bin/bash -eu
THIS_DIR_REL="../"
function main()
{
    for proj in "${THIS_DIR%/}/_sample-projects/"*; do
        if [[ -x "$proj/do-build-and-install.sh" ]] ; then
            "$proj/do-build-and-install.sh" --with-docker --with-tests
        fi
    done
}

source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/../lib-testing.inc.bash"
