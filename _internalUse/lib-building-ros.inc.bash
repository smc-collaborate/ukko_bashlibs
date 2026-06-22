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

    readarray -t distros <<< "$(find /opt/ros/ -maxdepth 1 -mindepth 1 -type d || true)"

    if [[ ${#distros[@]} -gt 1 ]] ; then
        echo "❌  Multiple ROS distros found in /opt/ros/:"
        for d in "${distros[@]}" ; do
            echo "    • ${d##*/}"
        done
        echo "    Please set the ROS_DISTRO environment variable to one of the above distros to continue."
        exit 1
    elif [[ ${#distros[@]} -eq 0 ]] ; then
        echo "❌  No ROS distros found in /opt/ros/"
        exit 1
    else
        export ROS_DISTRO="${ROS_DISTRO:-${distros[0]##*/}}"
        echo "ℹ️  Detected ROS_DISTRO: ${COLOUR[VIVID_BLUE_STDOUT]:-}${ROS_DISTRO}${COLOUR[OFF_STDOUT]:-}"
    fi
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

    if false ; then
        echo "🔨  ROS2 Installation"
        installPkgIfNeeded python3-empy
        installPkgIfNeeded python3-rosdep
        installPkgIfNeeded python3-colcon-common-extensions
        #installPkgIfNeeded python3-ros-build-tools
        #installPkgIfNeeded colcon-ros-bundle
    fi

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
