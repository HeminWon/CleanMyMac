#!/usr/bin/env bash

set -e
set -x

doFunction() {
    description="${1}"
    title="${2}"
    title1="dfsdf"
    echo "$description - $title"
    # display notification "\"$description\"" with title "\"$title\""
    # osascript -e 'display dialog "$description"'
    # osascript -e 'display dialog "Do you wish to update $description software?" buttons {"Yes", "No"} default button "No"'
# osascript << EOF
#     say "$title1" using "Alex"
# EOF
}

doFucntion1 () {
    text="${1}"
    text1="Do you wish to update $text software?"
osascript << EOF
    display dialog "$text1" buttons {"Yes", "No"} default button "No"
    # say "$text" using "Alex"
EOF
}

filerDo () {
    res=$(doFucntion1 "${1}")
    # echo $res
    if [ "$res" = "button returned:Yes" ]; then
        echo true
    else
        echo false
    fi
}

res1=$(filerDo "hello world")