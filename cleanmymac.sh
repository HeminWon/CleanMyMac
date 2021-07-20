#!/usr/bin/env bash

# https://brew.sh/
# https://github.com/buo/homebrew-cask-upgrade

set -e
# set -x

displayNotification() {
    description="${1}"
	title="${2}"
    echo "$description - $title"
    # osascript -e "display notification \"$description\" with title "\"$title\""
osascript << EOF
    display notification "\"$description\"" with title "\"$title\""
EOF
}

bytesToHumanReadable() {
    bytes=`echo "${1}" | numfmt --to=iec`
    result="$bytes of space was cleaned up :3"
    noti="来自 CleanMyMac"
    displayNotification "$result" "$noti"
}

available () {
    echo `df / | tail -1 | awk '{print $4}'`
}

####
updateBrew () {
    echo "update brew"
    brew update && brew upgrade && brew cu -a -y
}

updateMas() {
    echo "update mas"
    mas upgrade
}

clearCocoapods() {
    echo "clean cocoapods"
    pod cache clean --all
}

clearXcode() {
    xcrun simctl delete unavailable
    rm -rf ~/Library/Developer/Xcode/DerivedData/* &>/dev/null
    rm -rf ~/Library/Developer/Xcode/Archives/* &>/dev/null
    # rm -rf ~/Library/Developer/CoreSimulator/Devices/* &>/dev/null
    rm -rf ~/Library/Developer/Xcode/Products/* &>/dev/null

    cd ~/Library/Developer/Xcode/iOS\ DeviceSupport
    ifile=`ls | sort -rV | head -n1`
    ls | grep -v "${ifile}" | tr "\n" "\0" | xargs -0 rm -rf
}

####
display () {
    effect="${1}"
    text="${2}"
    detailDes="Do you wish to $effect $text software?"
osascript << EOF
    display dialog "$detailDes" buttons {"Yes", "No"} default button "No"
EOF
}

displayDialog () {
    res=$(display "${1}" "${2}")
    # echo $res
    if [ "$res" = "button returned:Yes" ]; then
        echo true
    else
        echo false
    fi
}

displayUpdate () {
    bool=$(displayDialog "update" "${1}")
    if [[ "$bool" == true ]]; then
        echo true
    else
        echo false
    fi
}

displayClear () {
    bool=$(displayDialog "clear" "${1}")
    if [[ "$bool" == true ]]; then
        echo true
    else
        echo false
    fi
}


##############################update
boolBrew=$(displayUpdate "brew")
if [[ "$boolBrew" == true ]]; then
    updateBrew
else
    echo "keep brew"
fi

boolMas=$(displayUpdate "mas")
if [[ "$boolMas" == true ]]; then
    updateMas
else
    echo "keep mas"
fi

##############################clear
# <--------------------------
oldAvailable=$(available)

boolCocoapods=$(displayClear "cocoapods")
if [[ "$boolMas" == true ]]; then
    clearCocoapods
else
    echo "Don't clean up cocoapods"
fi

# xcode
echo 'Cleanup Xcode'
clearXcode

# Cleaning Up Homebrew.
brew cleanup

#Cleaning Up Ruby.
printf "Cleanup up Ruby.\n"
gem cleanup

clear && echo 'Success!'

newAvailable=$(available)
# -------------------------->
count=$((newAvailable-oldAvailable))
count=$(( $count * 512))
bytesToHumanReadable $count