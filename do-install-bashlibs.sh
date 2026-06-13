#!/bin/bash -eu

ENV_ROOT=_none_
SUGGEST_HOW_TO_INSTALL_TO_ROOT=no

function apps_doInstallOrClean()
{
    do_exeInstall_orClean "${THIS_DIR%/}/git-shared-checkout"
}

source "$(dirname "${BASH_SOURCE[0]}")/lib-build-funcs.inc.bash"
