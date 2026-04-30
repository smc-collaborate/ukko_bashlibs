#!/bin/bash -eu

############################################################
# This is basically equivalent to:
#
# docker run -it -v "$(pwd)":/app "ubuntu:24.04" bash
#
#    root@ab92bb7bcd54:/# cd app
#    root@ab92bb7bcd54:/app# do-build-and-install.sh --fresh
#
############################################################


####################################################################################
#
#

function runOnHost()
{
    ##################################################
    # Parse initial parameters
    #

    #
    # Step 1 - Default Values
    #
    WORKSPACE_DIR="${THIS_DIR%/}/../../"
    [[ -z "$*" ]] && GIVE_HELP='yes'
    RUNNING_PARAMS=()
    #
    # Step 2 - Parse parameters
    #
    for arg in "$@" ; do
        if [[ "$arg" == "--stay-in-docker" ]] ; then
            STAY_IN_DOCKER='yes'
        elif [[ "$arg" == "--help" ]] ; then
            GIVE_HELP='yes'
            STAY_IN_DOCKER='yes'
        elif [[ "$arg" == --running=* ]] ; then
            RUN_EXE="${arg#--running=}"
            arg=''
        elif [[ "$arg" == --workspace-dir=* ]] ; then
            WORKSPACE_DIR="${arg#--workspace-dir=}"
        else
            break
        fi

        [[ -n "$arg" ]] && RUNNING_PARAMS+=("$arg")

        shift 1 || true
    done

    RUNNING_PARAMS+=("$@")

    #
    # Step 3 - Validate parameters
    #
    [[ "${GIVE_HELP:-}" == "yes" ]] && STAY_IN_DOCKER='yes'
    WORKSPACE_DIR="$(realpath -m "${WORKSPACE_DIR}")"
    echo "B: RUN_EXE=$RUN_EXE"
    RUN_EXE_FROM_ORIG_PWD="$(realpath --relative-to="${ORIG_PWD%/}/" "${RUN_EXE}")"


    #
    # Step 4 - Remaining Parameters
    #
    image="${1:-ubuntu:22.04}"
    shift 1 || true

    #######################################################
    #

    v_param="${WORKSPACE_DIR%/}/:/workspace"


    docker_env_params=(run)

    [[ "${STAY_IN_DOCKER:-}" == "yes" ]] && docker_env_params+=(-it)
    docker_env_params+=(-v "${v_param}")

    BUILD_EXE="$(realpath -m "${THIS_DIR%/}/do-full-build-and-test.sh")"
    {
        #|x|THIS_EXE_IN_NEW_ENV="/workspace/$(realpath --relative-to="${WORKSPACE_DIR%/}/" "${THIS_EXE}")"

        #|x|BUILD_EXE_FROM_CD="$(realpath --relative-to="${ORIG_PWD%/}/" "${BUILD_EXE}")"
        BUILD_EXE_IN_NEW_ENV="/workspace/$(realpath --relative-to="${WORKSPACE_DIR%/}/" "${BUILD_EXE}")"

        SHARED_DIR_FROM_CD="$(realpath --relative-to="${PWD_FOR_DOCKER%/}/" "${WORKSPACE_DIR}")"
        SHARED_DIR_IN_NEW_ENV="/workspace/$(realpath --relative-to="${WORKSPACE_DIR%/}/" "${WORKSPACE_DIR}")"

        WORKSPACE_DIR_FROM_DOCKER_PWD="$(realpath --relative-to="${PWD_FOR_DOCKER%/}/" "${SHARED_DIR}")"
        WORKSPACE_DIR_IN_NEW_ENV="/workspace/$(realpath --relative-to="${WORKSPACE_DIR%/}/" "${SHARED_DIR}")"

        DOCKER_DIR_IN_NEW_ENV="/workspace/$(realpath --relative-to="${WORKSPACE_DIR%/}/" "${PWD_FOR_DOCKER}")"


        echo "Running in new environment:"
        #|x|printf "  •  %-50s  -> %s\n" "${THIS_EXE_FROM_ORIGINAL_PWD}" "$THIS_EXE_IN_NEW_ENV"
        #|x|printf "  •  %-50s  -> %s\n" "${BUILD_EXE_FROM_CD}" "$BUILD_EXE_IN_NEW_ENV"
        printf "  •  %-50s  -> %s\n" "${SHARED_DIR_FROM_CD}" "${SHARED_DIR_IN_NEW_ENV%/.}/"
        printf "  •  %-50s  -> %s\n" "${WORKSPACE_DIR_FROM_DOCKER_PWD}" "${WORKSPACE_DIR_IN_NEW_ENV}"

        if [[ "${DOCKER_DIR_IN_NEW_ENV%/}/" == "/workspace/../"* ]] ; then
            printf "❌•  %-50s  -> %s\n" "(pwd)" "${DOCKER_DIR_IN_NEW_ENV%/}/"
        else
            printf "  •  %-50s  -> %s\n" "(pwd)" "${DOCKER_DIR_IN_NEW_ENV%/}/"
            docker_env_params+=(-w "${DOCKER_DIR_IN_NEW_ENV%/}/")
        fi
    }

    docker_env_params+=("${image}")

    docker_exe_params=("${BUILD_EXE_IN_NEW_ENV}" --raw-environment "$@")

    if [[ "${STAY_IN_DOCKER:-}" == "yes" ]] ; then
        txtCmd=()
        txtCmd+=(     "$(asQuotableText "${docker_exe_params[@]}"                )" ';')
        txtCmd+=(echo                                                               ';')
        txtCmd+=(echo "$(asQuotableText '---------------------------------------')" ';')
        txtCmd+=(echo "$(asQuotableText 'Staying in Docker Container'            )" ';')
        txtCmd+=(echo "$(asQuotableText 'To exit, type: exit'                    )" ';')
        txtCmd+=(echo "$(asQuotableText '---------------------------------------')" ';')
        txtCmd+=(bash)
        docker_exe_params=(bash -c "${txtCmd[*]}")
    fi
    #################################################
    #
    if [[ -n "${GIVE_HELP:-}" ]] ; then
        echo "Description: Run a full build and test of the annotatedData application"
        echo "             on a specified docker image."
        echo ""
        echo -e "Usage      : ${BLUE_STDOUT:-}${RUN_EXE_FROM_ORIG_PWD} <docker-image> [--stay-in-docker] (build-parameters)${NC_STDOUT:-}"
        echo "             <docker-image>    : Docker image to use for testing (e.g. 'ubuntu:22.04')"
        echo "             --stay-in-docker  : Stay in the docker image after tests for further investigation"
        echo ""
        echo -e "Example    : ${BOLD_BLUE_STDOUT:-}${RUN_EXE_FROM_ORIG_PWD} $image --stay-in-docker${NC_STDOUT:-}"
    fi

    echo -e " -> ${BOLD_BLUE_STDOUT:-}docker $(quoteIfNeeded "${docker_env_params[@]}") \\\\${NC_STDOUT:-}"
    echo -e "    ${BOLD_BLUE_STDOUT:-}       $(quoteIfNeeded "${docker_exe_params[@]}")${NC_STDOUT:-}"

    [[ -n "${give_help:-}" ]] && exit 1

    if [[ "$(whereis docker | wc -w)" == 1 ]] ; then
        echo "❌ Docker not found. Please install Docker to use this"
        exit 1
    fi

    result_code=0
    docker  "${docker_env_params[@]}" "${docker_exe_params[@]}" || result_code=$?
    echo ""
    echo -e "ℹ️  Returning result code from docker: ${result_code}"
    if [[ "${STAY_IN_DOCKER:-}" != "yes" ]] ; then
        echo -e "ℹ️  If you wanted to stay in the docker image, try: ${BOLD_BLUE_STDOUT:-}${RUN_EXE_FROM_ORIG_PWD} --stay-in-docker ${RUNNING_PARAMS[*]}${NC_STDOUT:-}"
    fi
    exit "$result_code"
}
echo "!!! > $* < !!!"
THIS_EXE="$(readlink -m "${BASH_SOURCE[0]}")"
THIS_DIR="$(realpath -m "$(dirname "$THIS_EXE")")"
SHARED_DIR="$(realpath -m "${THIS_DIR%/}/../")"
if [[ -z "${ORIG_PWD:-}" ]] ; then
    ORIG_PWD="$(pwd)"
fi
RUN_EXE="$THIS_EXE"
PWD_FOR_DOCKER="$(pwd)"
source "${THIS_DIR%/}/utils.inc.bash"

runOnHost "$@"


#
#
