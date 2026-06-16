#!/bin/bash -eu

ENV_ROOT=_none_
SUGGEST_HOW_TO_INSTALL_TO_ROOT=no
THIS_DIR_REL="../"

function apps_doInstallOrClean()
{
    part_git-shared-checkout/git-shared-checkout --install
    do_exeInstall_orClean part_do-run-in-docker/do-run-in-docker
}

function apps_runTests()
{
    true
    #
    # No automatic tests included here
    # The reason is that to best way to test this module is to run the tests of the modules
    # that depend on it, and those tests are run in the context of those modules, not here.
    #
    # Since testing is recursive (testing a module also tests its dependencies), there must
    # be blank test function here to avoid throwing an error
}
source "$(dirname "${BASH_SOURCE[0]}")/../lib-build-funcs.inc.bash"
