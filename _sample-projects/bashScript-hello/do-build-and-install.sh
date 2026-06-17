#!/bin/bash -eu

export VERIFY_ON_BUILD_ENVIRONMENTS="ubuntu:22.04,ubuntu:24.04,ubuntu:26.04,ubuntu:latest"


function apps_doInstallOrClean()
{
    do_exeInstall_orClean "hello.sh"
}



# shellcheck source=/dev/null
source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/libs/shim-lib-building.inc.bash"
