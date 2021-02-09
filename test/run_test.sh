#!/usr/bin/env bash
#
# Test tor_ip_checke.sh
#

set -u
umask 0022
export LC_ALL=C
readonly SCRIPT_NAME=$(basename $0)

readonly TARGET=./../tor_ip_detector.sh
readonly PATH_TENL=./torbulkexitlist


COUNT_NG=0

ok() {
    echo "."
}
ng() {
    echo $@
    COUNT_NG=`expr $COUNT_NG + 1`
}


# work in test dir.
cd $(dirname $0)


#
# TEST
#
$TARGET -s -l $PATH_TENL ./ip_list.txt
if [ "$?" -eq "0" ]; then
    ok
else
    ng "NG! ip_list.txt is not contain Tor IP. but detected."
fi

$TARGET -s -l $PATH_TENL ./ip_list_contain_tor_ip.txt
if [ "$?" -eq "1" ]; then
    ok
else
    ng "NG! ip_list_contain_tor_ip.txt is contain Tor IP. but not detected."
fi


#
# Result
#
if [ "$COUNT_NG" -eq 0 ]; then
    echo "Test result: All test passed!"
else
    echo "Test result: $COUNT_NG errors."
fi

