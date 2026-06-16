{
    echo "❓  | Deprecated - use 'libs-common.inc.bash' instead of 'utils.inc.bash'"
    echo "❓  | Path:"
    for x in "${BASH_SOURCE[@]}" ; do
        echo "❓  |   - $x"
    done
} >&2
source "$(dirname "$(realpath -m "${BASH_SOURCE[0]}")")/lib-common.inc.bash"
