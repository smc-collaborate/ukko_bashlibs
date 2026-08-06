#!/bin/bash -eu


function main()
{
    hello world | grep -q "Hello World"
}


# shellcheck source=/dev/null
source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/libs/_loader-shim.inc.bash"
