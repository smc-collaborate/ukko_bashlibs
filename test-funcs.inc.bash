{
    echo "❓  | Deprecated - use 'lib-testing.inc.bash' instead of 'test-funcs.inc.bash'"
    echo "❓  | Path:"
    for x in "${BASH_SOURCE[@]}" ; do
        echo "❓  |   - $x"
    done
} >&2
source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/lib-testing.inc.bash"
