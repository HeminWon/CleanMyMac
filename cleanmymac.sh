#!/usr/bin/env bash

# osascript -e 'display notification "😄 已清除Xcode编译缓存..." with title "来自 CleanMyMac"' 

bytesToHuman() {
    b=${1:-0}; d=''; s=0; S=(Bytes {K,M,G,T,E,P,Y,Z}iB)
    while ((b > 1024)); do
        d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
        b=$((b / 1024))
        let s++
    done
    echo "$b$d ${S[$s]} of space was cleaned up :3"
    osascript -e 'display notification "缓存已经清除！" with title "来自 CleanMyMac"' 
}

oldAvailable=$(df / | tail -1 | awk '{print $4}')

echo 'Cleanup XCode Derived Data and Archives...'
rm -rf ~/Library/Developer/Xcode/DerivedData/* &>/dev/null
rm -rf ~/Library/Developer/Xcode/Archives/* &>/dev/null

clear && echo 'Success!'

newAvailable=$(df / | tail -1 | awk '{print $4}')
count=$((newAvailable-oldAvailable))
count=$(( $count * 512))
bytesToHuman $count