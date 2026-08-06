#!/bin/bash -eu
export VERIFY_ON_BUILD_ENVIRONMENTS="ubuntu-apt:22.04,ubuntu-apt:24.04,ubuntu-apt:26.04,ubuntu-apt:latest"



function apps_doInstallOrClean()
{
    installEditablePythonPkgs "git@github.com:smc-collaborate/ukko_pylibs"  --ref='ver:v0.2.2'
    do_pyInstall_orClean "hello.py"
}

# shellcheck source=/dev/null
source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/libs/_loader-shim.inc.bash"
