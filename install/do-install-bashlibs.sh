#!/bin/bash -eu

ENV_ROOT=_none_
SUGGEST_HOW_TO_INSTALL_TO_ROOT=no
THIS_DIR_REL="../"

function apps_doInstallOrClean()
{
    do_exeInstall_orClean git-shared-checkout
    do_exeInstall_orClean do-run-in-docker
}

source "$(dirname "${BASH_SOURCE[0]}")/../lib-build-funcs.inc.bash"
