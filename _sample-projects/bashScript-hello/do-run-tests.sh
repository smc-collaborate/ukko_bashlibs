#!/bin/bash -eu


function main()
{
    hello --person=world | grep -q "Hello: world"
}

# shellcheck source=/dev/null
source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/libs/shim-lib-testing.inc.bash"
