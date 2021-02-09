#!/usr/bin/env bash
#------------------------------------------------------------------------------
#
# Tor IP Detector
#
#------------------------------------------------------------------------------
set -u
umask 0022
export LC_ALL=C
readonly SCRIPT_NAME=$(basename $0)


#
# Prepare temp dir
#
unset TEMP_DIR
on_exit() {
    [[ -n "${TEMP_DIR}" ]] && rm -rf "${TEMP_DIR}";
}
trap on_exit EXIT
trap 'trap - EXIT; on_exit; exit -1' INT PIPE TERM
readonly TEMP_DIR=$(mktemp -d "/tmp/${SCRIPT_NAME}.tmp.XXXXXX")


#
# Constants
#
readonly URL_TOR_EXIT_NODE_LIST=https://check.torproject.org/torbulkexitlist
readonly PATH_TOR_EXIT_NODE_LIST=$TEMP_DIR/torbulkexitlist


#
# Usage
#
usage () {
    cat << __EOS__
Usage:
    ${SCRIPT_NAME} [-h] [-l TOR_EXIT_NODE_LIST_FILE_PAHT] [IP_LIST_FILE_PATH]
    ${SCRIPT_NAME} ./path/to/ip_list_you_want_to_check.txt

Description:
    Read the IP list, and check if it is the Tor IP.

Argument:
    IP_LIST_FILE_PATH   Path to the file listing IP

Options:
    -h  show usage.
    -l  specify file path of tor exit node list.
        if not specified, download the tor exit node list from $URL_TOR_EXIT_NODE_LIST.
    -s  do not write anything to standard output.
        exit immediately with zero status.
        if tor IP detected, exit status will be 1.

Options for dev:
    -b  download the tor exit node list from $URL_TOR_EXIT_NODE_LIST.

__EOS__
}


#
# OPTIONS
#
OPT_PATH_TOR_EXIT_NODE_LIST=
OPT_SILENT_MODE=false


#
# Utils
#
echos() {
    if [ "$OPT_SILENT_MODE" = "true" ]; then
        : # SHHHHHHH!
    else
        echo $@
    fi
}

err() {
    if [ "$OPT_SILENT_MODE" != "true" ]; then
        echo -e "Error: $@\n" 1>&2
        usage
    fi
    exit 1
}

check_need_commands() {
    if type curl >/dev/null 2>&1; then :
    else
        err "'curl' command not found!"
    fi
}


download_tor_exit_node_list() {
    # download list and save into TEMP_DIR
    cd $TEMP_DIR
    curl -sL $URL_TOR_EXIT_NODE_LIST -o $PATH_TOR_EXIT_NODE_LIST
    cd - > /dev/null
}


parse_args() {
    while getopts hl:sb flag; do
        case "${flag}" in
            h )
                usage
                exit 0
                ;;

            l )
                OPT_PATH_TOR_EXIT_NODE_LIST=${OPTARG}
                ;;

            s )
                OPT_SILENT_MODE=true
                ;;


            #
            # Options for development.
            #
            b )
                download_tor_exit_node_list
                cp $PATH_TOR_EXIT_NODE_LIST ./
                echo "output: ./$(basename $PATH_TOR_EXIT_NODE_LIST)"
                exit 0
                ;;

            * )
                usage
                exit 0
                ;;
        esac
    done
}



#
# Entrypoint
#
main() {
    # tenl ... Tor Exit Node List
    local path_tenl=
    local path_ip_list=
    local detect_count=0
    local check_count=0

    parse_args $@
    shift `expr $OPTIND - 1`

    check_need_commands

    #----- Prepare the tor exit node list.
    if [ -z "$OPT_PATH_TOR_EXIT_NODE_LIST" ]; then
        download_tor_exit_node_list
        path_tenl=$PATH_TOR_EXIT_NODE_LIST
    else
        path_tenl=$OPT_PATH_TOR_EXIT_NODE_LIST
    fi

    #----- IP List
    if [ -z "${1:-}" ]; then
        :   # read IP form /dev/stdin instead
    else
        path_ip_list="${1}"
    fi

    #----- Check IP
    while read line
    do
        cat $path_tenl | grep -q $line
        ret=$?

        if [ $ret -eq 1 ]; then :
        else
            echos "Tor IP Detected: $line"
            detect_count=`expr $detect_count + 1`
        fi
        check_count=`expr $check_count + 1`
    done < "${path_ip_list:-/dev/stdin}"

    if [ $detect_count -ne 0 ]; then
        echos "Tor IP: $detect_count / $check_count"

        # if silent mode, exit with 1
        if [ "$OPT_SILENT_MODE" = "true" ]; then
            exit 1
        fi
    else
        echos "Tor IP was not detected."
    fi

    exit 0
}

main $@
exit 0

