#!/bin/bash -eu

export VERIFY_ON_BUILD_ENVIRONMENTS="ubuntu-apt:22.04,ubuntu-apt:24.04,ubuntu-apt:26.04,ubuntu-apt:latest"


function apps_doInstallOrClean()
{
    do_exeInstall_orClean "hello.sh"
}



# shellcheck source=/dev/null
source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/libs/shim-lib-building.inc.bash"
