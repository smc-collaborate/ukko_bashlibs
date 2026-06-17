#!/bin/bash -eu

THIS_DIR_REL="../"

function apps_doInstallOrClean()
{
    part_git-shared-checkout/git-shared-checkout --install
    do_exeInstall_orClean part_do-run-in-docker/do-run-in-docker
}

source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/../lib-building.inc.bash"
