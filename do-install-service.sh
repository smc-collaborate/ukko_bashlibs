#!/bin/bash -eu
THIS_EXE="$(readlink -f "${BASH_SOURCE[0]}")"
THIS_DIR="$(realpath -m "$(dirname "$THIS_EXE")")"

source "${THIS_DIR%/}/utils.inc.bash"

function give_help()
{
    echo "Usage: $0 [options] <service_name> <executable_and_parameters>"
    echo "Valid options: "
    echo "   * --remove"
    echo "   * --user=<username>"
    echo "   * --working-dir=<directory>"

}

function do_remove()
{
    local fname_service="$1"

    systemctl is-active  --quiet "${serviceName}.service" && doRun systemctl stop "${serviceName}.service"
    systemctl is-enabled --quiet "${serviceName}.service" && doRun systemctl disable "${serviceName}.service"

    if [[ -f "$fname_service" ]] ; then
        doRun --silent-if-ok rm -f "$fname_service"
        echo "    • Erased systemd service: $fname_service"
    else
        echo "    • Confirmed removed     : $fname_service"
    fi
}
function main()
{
    local return_value=0
    #
    # Have options
    # Rest is executable and arguments

    fname_service="/etc/systemd/system/${serviceName}.service"

    if [[ "$option_remove" == "yes" ]] ; then
        return_value=0; do_remove "$fname_service" || return_value="$?"
        exit "$return_value"
    fi

    {
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
    } > "$fname_service"

    echo "    • Installed: $fname_service"

    if [[ "$option_show_full" == "yes" ]] ; then
        echo     "                 ┌───────────────────────────────────────────────────────────────────────"
        sed  "s/^/                 │ /" < "$fname_service"
        echo     "                 └───────────────────────────────────────────────────────────────────────"
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
        echo                                          "        ┌───────────────────────────────────────────────────────────────────────"
        journalctl _PID="${service_pid}"    | sed "s/^/        │ /"
        echo                                          "        └───────────────────────────────────────────────────────────────────────"
        echo                                          "         Use: "
        echo                                       -e "              • ${BOLD_BLUE_STDOUT:-}journalctl _PID=${service_pid} -f${NC_STDOUT:-} to follow the logs  (Ensure you have used 'flushCache' in the printing functions to avoid buffering delays)"
        echo                                       -e "              • ${BOLD_BLUE_STDOUT:-}systemctl status ${serviceName}.service${NC_STDOUT:-} to check the service status"
    else
        echo "      ❌  Not active  [$status:$return_value]"
        echo                                             "      ┌───────────────────────────────────────────────────────────────────────"
        systemctl status  "${serviceName}.service" | sed "s/^/      │ /"
        echo                                             "      └───────────────────────────────────────────────────────────────────────"
    fi
    return "$return_value"

}

function doRun()
{
    local silent_if_ok=no

    if [[ "${1:-}" == "--silent-if-ok" ]] ; then
        silent_if_ok=yes
        shift 1 || true
    fi

    local result=0

    local tmpfile ; tmpfile="$(mktemp "/tmp/${serviceName}.doRun.XXXXXX")"


    "$@" &> "$tmpfile" || result=$?

    if [[ "$result" == 0 ]]; then
        [[ "$silent_if_ok" == "yes" ]] && return 0
        echo "      ✓ Ran: $*"
    else
        echo "      ✗ Ran: $*"
        echo "        ❌ Responded with Failure: $result"
    fi
    if [[ -s "$tmpfile" ]] ; then
           echo "             ┌───────────────────────────────────────────────────────────────────────"
        sed "s/^/             │ /" < "$tmpfile"
           echo "             └───────────────────────────────────────────────────────────────────────"
    fi
    rm -f "$tmpfile"
    return $result
}

if [[ "$EUID" -ne 0 ]] ; then
    echo "❌ Please run this script as root (e.g. with sudo)"
    exit 1
fi

option_remove=no
option_user=''
option_working_dir=''
option_show_full=yes
while [[ "${1:-}" == "--"* ]] ; do
    if [[ "${1:-}" == "--remove" ]] ; then
        option_remove=yes
    elif [[ "${1:-}" == --user=* ]] ; then
        option_user="${1#--user=}"
    elif [[ "${1:-}" == --working-dir=* ]] ; then
        option_working_dir="${1#--working-dir=}"
    else
        echo "❌ Invalid option: ${1:-}"
        give_help

        exit 1
    fi
    shift 1 || true
done


serviceName="${1:-}"
shift 1
executable_and_args=("$@")

main "$@"
