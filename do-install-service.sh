#!/bin/bash -eu
THIS_EXE="$(readlink -f "${BASH_SOURCE[0]}")"
THIS_DIR="$(realpath -m "$(dirname "$THIS_EXE")")"
#|Logging| echo "🛈  THIS_EXE = [$THIS_EXE], ORIG_PWD = [${ORIG_PWD:-NONE}]"
source "${THIS_DIR%/}/utils.inc.bash"

function give_help()
{
    echo "Usage: $0 [options] <service_name> <executable_and_parameters>"
    echo "Valid options: "
    echo "   • --remove"
    echo "   • --user=<username>"
    echo "   • --working-dir=<directory>"

}

function do_remove()
{
    local fname_whereInstalled="$1"
    local entryName ; entryName="$(basename "$fname_whereInstalled")"

    systemctl is-active  --quiet "${entryName}" && doRun systemctl stop "${entryName}"
    systemctl is-enabled --quiet "${entryName}" && doRun systemctl disable "${entryName}"

    if [[ ! -f "$fname_whereInstalled" ]] ; then
        echo "    • Confirmed removed     : $fname_whereInstalled"
    elif doRun --silent-if-ok rm -f "$fname_whereInstalled" ; then
        echo "    • Erased systemd entry  : $fname_whereInstalled"
    fi
}

function install_and_start_service()
{
    local return_value=0
    local executable_and_args=( "$@" )

    #
    # Have options
    # Rest is executable and arguments

    fname_service="/etc/systemd/system/${serviceName}.service"

    if [[ "$option_remove" == "yes" ]] ; then
        do_remove "$fname_service"
        exit "$?"
    fi

    {
        if [[ -n "$option_fname_service" ]] ; then
            cat "$option_fname_service"
        else
            echo "[Unit]"
            echo "Description=${serviceName}"
            echo "After=network.target"
            echo ""
            echo "[Service]"
            [[ -n "$option_user"        ]] && echo "User=${option_user}"
            [[ -n "$option_working_dir" ]] && echo "WorkingDirectory=${option_working_dir}"
            echo "ExecStart=${executable_and_args[*]@Q}"
            echo "Restart=always"
            echo "RestartSec=8"
            echo ""
            echo "[Install]"
            echo "WantedBy=multi-user.target"
        fi
    } > "$fname_service"

    echo "    • Installed: $fname_service"

    if [[ "$option_show_full" == "yes" ]] ; then
        withLeftBox "                 " < "$fname_service"
    else
        [[ -n "$option_user" ]] && echo "                 • user: $option_user"
    fi
    doRun systemctl daemon-reload
    doRun systemctl enable "${serviceName}.service"
    doRun systemctl restart "${serviceName}.service"
    service_pid="$(systemctl show -P MainPID  "${serviceName}.service")"
    sleep 1 # Give it a moment to start up before checking status
    return_value=0; status=$(systemctl is-active "${serviceName}.service") || return_value="$?"
    if [[ "$return_value" == 0 ]] ; then
        echo "      ✓ Confirmed Running   [PID: $service_pid]"
        {
            doRun-groupedOutput journalctl _PID="${service_pid}" --no-pager

            echo     "Use: "
            echo  -e "     • ${BOLD_BLUE_STDOUT:-}journalctl _PID=${service_pid} -f${NC_STDOUT:-} to follow the logs  (Ensure you have used 'flushCache' in the printing functions to avoid buffering delays)"
            echo  -e "     • ${BOLD_BLUE_STDOUT:-}systemctl status ${serviceName}.service${NC_STDOUT:-} to check the service status"
        } | withPrefix "         "
    else
        echo "      ❌  Not active  [$status:$return_value]"
        doRun-groupedOutput systemctl status  "${serviceName}.service" --no-pager | withPrefix "         "
    fi
    return "$return_value"

}

function systemd_enable()
{
    local name="$1"
    local returnValue=0

    doRun systemctl enable  "${name}" || returnValue="$?"

    status=$(systemctl is-enabled "${name}") || returnValue="$?"
    if [[ "$returnValue" == 0 ]] ; then
        echo "      ✓ Confirmed enabled"
    else
        echo "      ❌  Not enabled  [$status:$returnValue]"
        overallBashResult=3
        run-in-outline systemctl status "${name}"
    fi

    return "$returnValue"
}
function install_files_and_enable_only()
{
    local entries=()

    while [[ "$#" -gt 0 ]] ; do
        local src_file="$1"
        shift 1 || true

        if [[ "$option_remove" == "yes" ]] ; then
             do_remove "$fname_service" || true
        else
            local name ; name="$(basename "$src_file")"

            entries+=("$src_file")

            do_ensure_file_set "/etc/systemd/system/${name}" "$src_file" || echo "❌ Failed to link ${src_file@Q} to /etc/systemd/system/${name@Q}" >&2
            # doRun "cp" "$src_file" "D" && echo "    • Installed: $name"
        fi
    done

    doRun systemctl daemon-reload

    for name in "${entries[@]}" ; do
        systemd_enable "$name"
    done
}


if [[ "$EUID" -ne 0 ]] ; then
    echo "❌ Please run this script as root (e.g. with sudo)"
    exit 1
fi

option_remove=no
option_user=''
option_working_dir=''
option_show_full=yes
option_enable_files_only=no
option_fname_service=''
while [[ "${1:-}" == "--"* ]] ; do
    if [[ "${1:-}" == "--remove" ]] ; then
        option_remove=yes
    elif [[ "${1:-}" == "--files" ]] ; then
        option_enable_files_only=yes
    elif [[ "${1:-}" == --user=* ]] ; then
        option_user="${1#--user=}"
    elif [[ "${1:-}" == --working-dir=* ]] ; then
        option_working_dir="${1#--working-dir=}"
    elif [[ "${1:-}" == --fname-service=* ]] ; then
        option_fname_service="${1#--fname-service=}"
    else
        echo "❌ Invalid option: ${1:-}"
        give_help

        exit 1
    fi
    shift 1 || true
done

if [[ "$option_enable_files_only" == "yes" ]] ; then
    install_files_and_enable_only "$@"
elif [[ -n "${option_fname_service:-}" ]] ; then
    serviceName="$(basename "$option_fname_service" .service)"

    install_and_start_service "$@"
else
    serviceName="${1:-}"
    shift 1 || true

    install_and_start_service "$@"
fi
exit "$overallBashResult"
