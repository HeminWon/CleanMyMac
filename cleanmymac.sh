#!/usr/bin/env bash

displayNotification() {
    description="${1}"
	title="${2}"
    echo "$description - $title"
    # osascript -e "display notification \"$description\" with title "\"$title\""
osascript << EOF
    display notification "\"$description\"" with title "\"$title\""
EOF
}

bytesToHuman() {
    b=${1:-0}; d=''; s=0; S=(Bytes {K,M,G,T,E,P,Y,Z}iB)
    while ((b > 1024)); do
        d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
        b=$((b / 1024))
        let s++
    done
    result="$b$d ${S[$s]} of space was cleaned up :3"
    noti="来自 CleanMyMac"
    displayNotification "$result" "$noti"
}

updateSoftware() {
    echo "update software..."
    brew update && brew upgrade && brew cu -a -y && mas upgrade
}

##############################

#
while true; do
    read -p "Do you wish to update all software? " yn
    case $yn in
        [yY][eE][sS]|[yY] ) updateSoftware; break;;
        [nN][oO]|[nN] ) echo "keep software..."; break;;
        * ) echo "Please answer yes or no.";;
    esac
done

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