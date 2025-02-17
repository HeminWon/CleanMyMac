#!/usr/bin/env bash

# https://brew.sh/
# https://github.com/buo/homebrew-cask-upgrade

set -e
# set -x

displayNotification() {
    local description="${1}"
    local title="${2}"
    echo "$description - $title"
    osascript <<EOF
    display notification "$description" with title "$title"
EOF
}

bytesToHumanReadable() {
    local bytes
    bytes=$(numfmt --to=iec <<<"${1}")
    local result="$bytes of space was cleaned up :3"
    local noti="来自 CleanMyMac"
    displayNotification "$result" "$noti"
}

available() {
    df / | awk 'NR==2 {print $4}'
}

updateBrew() {
    echo "Updating Homebrew..."
    arch -arm64 brew update &&
        arch -arm64 brew upgrade &&
        arch -arm64 brew upgrade --cask --greedy
}

updateMas() {
    echo "Updating Mac App Store..."
    mas upgrade
}

clearCocoapods() {
    echo "Cleaning CocoaPods..."
    pod cache clean --all
}

clearXcode() {
    echo "Cleaning Xcode..."
    xcrun simctl delete unavailable
    rm -rf ~/Library/Developer/Xcode/DerivedData/* &>/dev/null
    rm -rf ~/Library/Developer/Xcode/Archives/* &>/dev/null
    rm -rf ~/Library/Developer/Xcode/Products/* &>/dev/null

    cd ~/Library/Developer/Xcode/iOS\ DeviceSupport || return
    local ifile
    ifile=$(ls | sort -rV | head -n1)
    ls | grep -v "${ifile}" | xargs -I {} rm -rf "{}"
}

clearCache() {
    echo "Cleaning cache directories..."
    rm -rf ~/Library/Caches/*
    rm -rf ~/Library/Application\ Support/*/Cache/*
    rm -rf ~/Library/Containers/*/Data/Library/Caches/*
    rm -rf ~/Library/Developer/Xcode/iOS\ Device\ Logs/*
    rm -rf ~/Library/Developer/Xcode/DerivedData/*

    echo "Cache directories cleaned."
}

clearLogs() {
    echo "Cleaning application logs..."
    rm -rf ~/Library/Logs/*
    sudo rm -rf /Library/Logs/*
    echo "Application logs cleaned."
}

clearTrash() {
    echo "Emptying Trash..."
    rm -rf ~/.Trash/*
    echo "Trash emptied."
}

displayDialog() {
    local effect="${1}"
    local text="${2}"
    local detailDes="Do you wish to ${effect} ${text} software?"
    osascript <<EOF
    display dialog "$detailDes" buttons {"Yes", "No"} default button "No"
EOF
}

shouldProceed() {
    local action="${1}"
    local name="${2}"
    local res
    res=$(displayDialog "$action" "$name")
    [[ "$res" == "button returned:Yes" ]]
}

main() {
    ############################## Update
    if shouldProceed "update" "brew"; then
        updateBrew
    else
        echo "Keeping brew"
    fi

    if shouldProceed "update" "AppStore"; then
        updateMas
    else
        echo "Keeping mas"
    fi

    ############################## Clear
    oldAvailable=$(available)

    if type "pod" > /dev/null 2>&1; then
        if shouldProceed "clear" "cocoapods"; then
            clearCocoapods
        else
            echo "Don't clean up CocoaPods"
        fi
    fi

    # Clean Xcode
    if shouldProceed "clear" "xcode"; then
        clearXcode
    else
        echo "Don't clean up Xcode"
    fi

    # Clean cache directories
    if shouldProceed "clean cache of" "xcode"; then
        clearCache
    else
        echo "Don't clean up cache"
    fi

    clearLogs

    clearTrash

    # Clean up Homebrew
    echo "Cleaning up Homebrew..."
    arch -arm64 brew cleanup

    # Clean up Ruby
    echo "Cleaning up Ruby..."
    gem cleanup

    clear && echo 'Success!'

    newAvailable=$(available)
    count=$((newAvailable - oldAvailable))
    count=$((count * 512))
    bytesToHumanReadable "$count"
}

# Call the main function to execute the script
main
