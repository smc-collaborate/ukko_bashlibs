#!/usr/bin/env bash
set -eu


#############################
# Running inside docker image from here on
# Called in docker image started by 'do-run-in-docker'
#
#


THIS_EXE="$(readlink -f "${BASH_SOURCE[0]}")"
THIS_DIR="$(realpath -m "$(dirname "$THIS_EXE")")"

function withPrefix()
{
    local prefix="$1"
    sed --unbuffered "s/^/${prefix}/" || return 0
}

# shellcheck disable=SC2120
function withLeftBox()
{
    local prefix="${1:-}"
    echo       "${prefix}╭───────────────────────────────────────────────────────────────────────"
    withPrefix "${prefix}│ "
    echo       "${prefix}╰───────────────────────────────────────────────────────────────────────"
}

function dumpVersions()
{
    echo "Environment:"
    {
        echo -n "${NAME:-} ${VERSION:-}"
        if [[ "${PRETTY_NAME:-}" != "${NAME:-} ${VERSION_ID:-}"* ]] ; then
            echo -n " -- ${PRETTY_NAME:-}"
        fi
        echo ""

        python3 --version 2>/dev/null
        pip3 --version    2>/dev/null
        protoc --version  2>/dev/null
    } | withPrefix "  • "
}

echo "═══════════════════════════════════════════════════════════════════════════" >&2
source /etc/os-release

option_exit='--exit=on-success'
option_cmd_to_run=()
while [[ "$#" -gt 0 ]] ; do
    _arg="$1"
    shift 1 || true
    [[ "$_arg" == "--exit="* ]] && option_exit="$_arg" && continue
    [[ "$_arg" == 'run:' ]] && option_cmd_to_run+=("$@") && break
    echo "⚠️  Unknown argument: $_arg" >&2
done

echo "Running within docker image [${NAME:-} ${VERSION:-}] ($option_exit) cmd: ${option_cmd_to_run[*]}" >&2

if [[ -d "${THIS_DIR%/}/ssh_keys" ]] ; then
    #echo "Installing keys"

    # This can be made more secure by only copying specific files instead of the whole directory, but this is good enough for now and allows flexibility in what secrets are needed without having to change this script.
    mkdir -p ~/.ssh
    cp "${THIS_DIR%/}/ssh_keys/"* ~/.ssh/ || echo "⚠️  No secrets found in ${THIS_DIR%/}/ssh_keys/ to copy to ~/.ssh/"
    chmod 600 ~/.ssh/*     || echo "⚠️  No secrets found in ~/.ssh/ to set permissions on"
fi
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

for file in "${THIS_DIR%/}/pre-"*; do
    if [ -x "$file" ]; then
        echo "Processing: $file"
        "$file" || echo "⚠️  Failed to execute $file, but continuing with the rest of the startup script."
    fi
done
#########################################
#
#
cd /workspace/

return_value=0

"${option_cmd_to_run[@]}" || return_value=$?

for file in "${THIS_DIR%/}/post-"*; do
    if [ -x "$file" ]; then
        echo "Processing: $file"
        "$file" || echo "⚠️  Failed to execute $file, but continuing with the rest of the startup script."
    fi
done

dumpVersions  | withLeftBox

if [[ "$option_exit" == "--exit=no" ]] || [[ "$option_exit" == "--exit=on-success" && "$return_value" != 0 ]] ; then
    echo "═══════════════════════════════════════════════════════════════════════════"
    echo " Staying in docker image [$option_exit]"
    echo " To exit, type: exit"
    echo "════════════════════"
    bash
fi
echo "ℹ️  Exiting docker image with: exitCode=$return_value" >&2
echo "═══════════════════════════════════════════════════════════════════════════" >&2
exit "$return_value"

#
#
