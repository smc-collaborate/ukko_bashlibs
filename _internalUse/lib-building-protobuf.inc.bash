





function do_protoGenerate_orClean()
{
    local msg_on_none_found="${1:-}"
    local found_proto_file='no'

    local dirsToReview=()

    for relative_dir in . common  ; do
        for fulldir in "${PROJ_DIR%/}/${relative_dir}/proto_"*/ ; do
            #|Logging| echo "Checking for proto files in ${fulldir} ..."
            [[ -d "${fulldir}" ]] && dirsToReview+=("${fulldir}")
        done
    done
        for fulldir in "${dirsToReview[@]}" ; do
        pushd "${fulldir}" >/dev/null || true
            printable_dir="${fulldir#"${PROJ_DIR%/}"/}"
            if [[ "${AM_CLEANING}" == 'yes' ]] && [[ -d "_generated" ]] ; then
                echo "   Proto directory[$printable_dir] - Cleaning _generated directory"
                echo '_generated' | forceDelete "           "
            fi


            if [[ "${AM_CLEANING}" != 'yes' ]] ; then
                echo "   Proto directory[$printable_dir] - Generating protobuf code under _generated:"
                for proto_file in *.proto; do
                    [[ -f "$proto_file" ]] || continue
                    echo "    • ${printable_dir%/}/$proto_file"
                    found_proto_file='yes'
                done
                echo '_tmp_generated' | forceDelete "           "
                mkdir -p _tmp_generated
                if [[ "$(protoc --version)" == "libprotoc 3.12"*  ]] ; then
                    # Very old version of protobuf
                    # shellcheck disable=SC2035
                    protoc --experimental_allow_proto3_optional --python_out _tmp_generated *.proto
                else
                    # shellcheck disable=SC2035
                    protoc --python_out _tmp_generated *.proto
                fi


                readarray -t dirs <<< "$(find _tmp_generated -type d)"
                for dir in "${dirs[@]}" ; do
                    touch "${dir%/}/__init__.py"
                done
                touch "./__init__.py"
                mkdir -p _generated
                rsync -P -c -r _tmp_generated/* _generated | grep -v '^sending incremental file list$' || true
                rm -rf _tmp_generated
            fi

        popd >/dev/null || true
    done
    [[ "${found_proto_file}" == 'no' ]] && [[ -n "${msg_on_none_found}" ]] && echo "${msg_on_none_found}"
    return 0
}
