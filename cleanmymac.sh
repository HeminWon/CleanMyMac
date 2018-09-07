#!/usr/bin/env bash

bytesToHuman() {
    b=${1:-0}; d=''; s=0; S=(Bytes {K,M,G,T,E,P,Y,Z}iB)
    while ((b > 1024)); do
        d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
        b=$((b / 1024))
        let s++
    done
    result="$b$d ${S[$s]} of space was cleaned up :3"
    noti="来自 CleanMyMac"
    echo $result
    # osascript -e "display notification \"$result\" with title \"$noti\""
osascript << EOF
    display notification "\"$result\"" with title "来自 CleanMyMac"
EOF
}

##############################

#
brew update && brew upgrade && brew cu -a -y && mas upgrade

# <--------------------------
oldAvailable=$(df / | tail -1 | awk '{print $4}')

#
echo 'Cleanup XCode Derived Data and Archives...'
rm -rf ~/Library/Developer/Xcode/DerivedData/* &>/dev/null
rm -rf ~/Library/Developer/Xcode/Archives/* &>/dev/null

# Cleaning Up Homebrew.
brew cleanup

#Cleaning Up Ruby.
printf "Cleanup up Ruby.\n"
gem cleanup

clear && echo 'Success!'

newAvailable=$(df / | tail -1 | awk '{print $4}')
# -------------------------->
count=$((newAvailable-oldAvailable))
count=$(( $count * 512))
bytesToHuman $count