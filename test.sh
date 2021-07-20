#!/usr/bin/env bash

# set -e
set -x

doFunction() {
    # cd ~/Library/Developer/Xcode/iOS\ DeviceSupport
    cd ~/Documents/HeminWon/test
    ifile=`ls | sort -rV | head -n1`
    # rm -rf !($ifile)
    ls | grep -v "${ifile}" | tr "\n" "\0" | xargs -0 rm -rf
}

doFunction