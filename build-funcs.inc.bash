{
    echo "❓  | Deprecated - use 'lib-build-funcs.inc.bash' instead of 'build-funcs.inc.bash'"
    echo "❓  | Path:"
    for x in "${BASH_SOURCE[@]}" ; do
        echo "❓  |   - $x"
    done
} >&2
source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/lib-build-funcs.inc.bash"
