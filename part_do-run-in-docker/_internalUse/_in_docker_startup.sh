#!/usr/bin/env bash
set -eu


#############################
# Running inside docker image from here on
# Called in docker image started by 'do-run-in-docker'
#
#


THIS_EXE="$(readlink -f "${BASH_SOURCE[0]}")"
EXE_DIR="$(realpath -m "$(dirname "$THIS_EXE")")"
# shellcheck disable=SC2034
PROJ_DIR="$EXE_DIR"

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

        for file in "${EXE_DIR%/}/post-"*; do
            if [ -x "$file" ]; then
                echo "Processed: $file"
            fi
        done
    } | withPrefix "  • "
}

echo "═══════════════════════════════════════════════════════════════════════════" >&2
source /etc/os-release

option_exit='--exit=on-success'
option_local_cmd_to_run=()
while [[ "$#" -gt 0 ]] ; do
    _arg="$1"
    shift 1 || true
    [[ "$_arg" == "--exit="* ]] && option_exit="$_arg" && continue
    [[ "$_arg" == 'run:' ]] && option_local_cmd_to_run+=("$@") && break
    echo "⚠️  Unknown argument: $_arg" >&2
done

echo "Running within docker image [${NAME:-} ${VERSION:-}] ($option_exit) cmd: ${option_local_cmd_to_run[*]}" >&2

if [[ -d "${EXE_DIR%/}/ssh_keys" ]] ; then
    #echo "Installing keys"

    # This can be made more secure by only copying specific files instead of the whole directory, but this is good enough for now and allows flexibility in what secrets are needed without having to change this script.
    mkdir -p ~/.ssh
    cp "${EXE_DIR%/}/ssh_keys/"* ~/.ssh/ || echo "⚠️  No secrets found in ${EXE_DIR%/}/ssh_keys/ to copy to ~/.ssh/"
    chmod 600 ~/.ssh/*     || echo "⚠️  No secrets found in ~/.ssh/ to set permissions on"
fi
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

for file in "${EXE_DIR%/}/pre-"*; do
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

"${option_local_cmd_to_run[@]}" || return_value=$?

for file in "${EXE_DIR%/}/post-"*; do
    if [ -x "$file" ]; then
        echo "Processing: $file"
        "$file" || echo "⚠️  Failed to execute $file, but continuing with the rest of the startup script."
    fi
done

dumpVersions  | withLeftBox

helpTxt="${option_local_cmd_to_run[*]@Q}"
if [[ "$return_value" != 0 ]] ; then
    echo "⚠️  Fail during run: $helpTxt"
else
    echo "ℹ️  Successfully ran: $helpTxt"
fi
if [[ "$option_exit" == "--exit=no" ]] || [[ "$option_exit" == "--exit=on-success" && "$return_value" != 0 ]] ; then
    echo "═══════════════════════════════════════════════════════════════════════════"
    echo " Staying in docker image [$option_exit]"
    echo " To exit, type: exit"
    echo "════════════════════"
    return_value=0
    bash || return_value="$?"
fi

if [[ "$return_value" == "0" ]] ; then
    echo "ℹ️  Exiting docker image" >&2
else
    echo "⚠️  Exiting docker image with exitCode=$return_value" >&2
fi
echo "═══════════════════════════════════════════════════════════════════════════" >&2
exit "$return_value"

#
#
