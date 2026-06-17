{
    echo "❓  | Deprecated - use 'lib-building.inc.bash' instead of 'build-funcs.inc.bash'"
    echo "❓  | Path:"
    for x in "${BASH_SOURCE[@]}" ; do
        echo "❓  |   - $x"
    done
} >&2
source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/lib-building.inc.bash"
