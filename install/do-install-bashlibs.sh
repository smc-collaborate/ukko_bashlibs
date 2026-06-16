#!/bin/bash -eu

ENV_ROOT=_none_
SUGGEST_HOW_TO_INSTALL_TO_ROOT=no
THIS_DIR_REL="../"

function apps_doInstallOrClean()
{
    part_git-shared-checkout/git-shared-checkout --install
    do_exeInstall_orClean part_do-run-in-docker/do-run-in-docker
}

source "$(dirname "${BASH_SOURCE[0]}")/../lib-build-funcs.inc.bash"
