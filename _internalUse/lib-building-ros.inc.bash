# shellcheck shell=bash


########################################################################################################################
#
# ROS
#
export ROS_SOURCING=()
export ROS_DISTRO="${ROS_DISTRO:-}"

# shellcheck disable=SC2317
function setRosDistroIfNeeded()
{
    [[ "${AM_CLEANING:-}" == 'yes' ]] && return 0
    [[ -n "${ROS_DISTRO:-}" ]]  && return 0

    readarray -t distros <<< "$(find /opt/ros/ -maxdepth 1 -mindepth 1 -type d 2>/dev/null|| true)"

    if [[ ${#distros[@]} -eq 0 ]] || [[ -z "${distros[*]}" ]] ; then
        echo "❌  No ROS distros found in /opt/ros/"
        exit 1
    fi

    if [[ ${#distros[@]} -gt 1 ]] ; then
        echo "❌  Multiple ROS distros found in /opt/ros/:"
        for d in "${distros[@]}" ; do
            echo "    • ${d##*/}"
        done
        echo "    Please set the ROS_DISTRO environment variable to one of the above distros to continue."
        exit 1
    else
        export ROS_DISTRO="${ROS_DISTRO:-${distros[0]##*/}}"
        echo -e "ℹ️  Detected ROS_DISTRO: ${COLOUR[VIVID_BLUE_STDOUT]:-}${ROS_DISTRO}${COLOUR[OFF_STDOUT]:-}"
    fi
}

#
# Ensure that the requested ROS distro is available in /opt/ros/
# Accepts a list of suitable ROS distros
#
function do_rosEnsureDistro()
{
    local requested_distros=("$@")
    [[ "${AM_CLEANING:-}" == 'yes' ]] && return 0

    readarray -t distros <<< "$(find /opt/ros/ -maxdepth 1 -mindepth 1 -type d 2>/dev/null|| true)"

    function exitWithDistroError()
    {
        echo -e "❌  $*"
        if [[ "${#distros[@]}" -gt 0 ]] ; then
            echo "    Available ROS versions:"
            for d in "${distros[@]}" ; do
                echo "    • ${d##*/}"
            done
        fi

        if [[ "${#requested_distros[@]}" -gt 0 ]] ; then
            echo "    Acceptable ROS versions:"
            for d in "${requested_distros[@]}" ; do
                echo "    • ${d}"
            done
        fi

        [[ -n "${ROS_DISTRO:-}" ]] && echo -e "    Preferred ROS version:   ${COLOUR[VIVID_BLUE_STDOUT]:-}${ROS_DISTRO}${COLOUR[OFF_STDOUT]:-}"

        exit 1
    }
    [[ ${#distros[@]} -eq 0 ]] || [[ -z "${distros[*]}" ]] && exitWithDistroError "No ROS distros found in /opt/ros/"

    local matching_distros=()
    for arg in "${requested_distros[@]}" ; do
        for d in "${distros[@]}" ; do
            [[ "${d##*/}" == "${arg}" ]] && matching_distros+=( "${arg}" )
        done
    done


    [[ ${#matching_distros[@]} -eq 0 ]] && exitWithDistroError "Requested ROS distros [$(asCsvList "${requested_distros[@]}")] not found in /opt/ros/"

    local preferred_distro=""
    for d in "${matching_distros[@]}" ; do
        if [[ "$d" == "${ROS_DISTRO:-/dev/null}" ]] ; then
            preferred_distro="${ROS_DISTRO}"
            break
        fi
    done

    if [[ -n "${preferred_distro:-}" ]] ; then
        export ROS_DISTRO="${preferred_distro}"
        echo -e " ℹ️  Using requested ROS_DISTRO: ${COLOUR[VIVID_BLUE_STDOUT]:-}${ROS_DISTRO}${COLOUR[OFF_STDOUT]:-}"
        return 0
    fi

    [[ -z "${ROS_DISTRO:-}" ]] || exitWithDistroError "Requested ROS_DISTRO '${ROS_DISTRO}' not found in /opt/ros/"

    [[ "${#matching_distros[@]}" -gt 1 ]] && exitWithDistroError "Multiple suitable ROS distros found in /opt/ros/: [$(asCsvList "${matching_distros[@]}")]\n    Please set the ROS_DISTRO environment variable to one of the above distros to continue."

    export ROS_DISTRO="${matching_distros[0]}"
    echo -e " ℹ️  Using Found ROS_DISTRO: ${COLOUR[VIVID_BLUE_STDOUT]:-}${ROS_DISTRO}${COLOUR[OFF_STDOUT]:-}"
    return 0
}

# shellcheck disable=SC2317
function do_pyRosFile()
{
    local py_file="$1"
    shift 1 || true

    local py_run_params=()
    local pkg_args=()
    for arg in "$@"; do
        if [[ "$arg" == --ros-pkg=* ]]; then
            pkg_args+=( "${arg#*=}" )
        else
            py_run_params+=( "$arg" )
        fi

    done

    setRosDistroIfNeeded
    export ROS_SOURCING=( "source /opt/ros/${ROS_DISTRO}/setup.bash" )
    export ROS_PACKAGES=()

    do_rosPackages "${pkg_args[@]}"

    do_pyInstall_orClean "$py_file" --source-start "${ROS_SOURCING[@]}" --source-end "${py_run_params[@]}" "${py_run_params[@]}"
}

# shellcheck disable=SC2317
function do_rosPackages()
{
    setRosDistroIfNeeded

    #|x| if false ; then
    #|x|     echo "🔨  ROS2 Installation"
    #|x|     installPkgIfNeeded python3-empy
    #|x|     installPkgIfNeeded python3-rosdep
    #|x|     installPkgIfNeeded python3-colcon-common-extensions
    #|x|     #installPkgIfNeeded python3-ros-build-tools
    #|x|     #installPkgIfNeeded colcon-ros-bundle
    #|x| fi

    [[ -z "${ROS_PACKAGES:-}" ]] && export ROS_PACKAGES=()
    [[ -z "${ROS_SOURCING:-}" ]] && export ROS_SOURCING=( "source /opt/ros/${ROS_DISTRO}/setup.bash" )

    for package_dir in "$@" ; do

        if [[ ! -d "$package_dir" ]] ; then
            echo "❌  do_rosPackages : Failed to change directory to '$package_dir'" >&2
            return 1
        fi

        local dirname ; dirname="$(realpath -m "$package_dir")"

        local fname="${dirname}/install/local_setup.bash"
        ROS_SOURCING+=( "source ${fname@Q}" )

        ROS_PACKAGES+=(  "${dirname}" )

        module_name="$(basename "$package_dir")"

        if [[ "${AM_CLEANING:-}" == 'yes' ]] ; then
            echo "   🔨  ROS2 package: $module_name - Cleaning build artifacts"
            {
                echo "build"
                echo "install"
                echo "log"
                echo "__pycache__"
            }  | forceDelete "           "
            echo "Cleaned build, install, log & __pycache__ directories $* (${package_dir})"
        else
            echo "   🔨  Building ROS2 package: ${module_name} $* (in dir: ${package_dir})"
            set +u
            # shellcheck disable=SC1090
            source "/opt/ros/${ROS_DISTRO}/setup.bash"
            set -u
            [[ -d "${package_dir%/}/src" ]] && rosdep install -i --from-path "${package_dir%/}/src"  -y
            colcon build --packages-select "${module_name}" --base-paths "${package_dir%/}"
        fi
    done
}
