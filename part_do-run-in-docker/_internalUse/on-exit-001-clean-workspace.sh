#!/bin/env bash
set -eu

function main()
{
    echo "---------------------------------------------------"
    echo "Removing root owned entries in workspace: /workspace"
    remove_root_owned_files "/workspace"
    echo "---------------------------------------------------"

}

function remove_root_owned_files()
{
    local fullPath="$1"

    local file_user
    file_user="$(stat -c '%U' "$fullPath")"

    if [[ "$file_user" == 'root' ]] ; then
        echo " - Removing: $fullPath  -- User=root"
        # rm -rf "$fullPath"
        return 0
    fi
    [[ -f "$fullPath" ]] && return 0
    if [[ ! -d "$fullPath" ]] ; then
        echo " - $fullPath :    Warnings: File Type"
        return 0
    fi

    shopt -s dotglob
    shopt -s nullglob

    for entry in "$fullPath"/*; do
        remove_root_owned_files "$entry"
    done

    return 0
}

main "$@"
