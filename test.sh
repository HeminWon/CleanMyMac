#!/bin/bash

# spin() {
#   local i=0
#   local sp='/-\|'
#   local n=${#sp}
#   printf ' '
#   sleep 0.1
#   while true; do
#     printf '\b%s' "${sp:i++%n:1}"
#     sleep 0.1
#   done
# }
spin() {
    while true; do
        for j in '\' '|' '/' '-'
        do
            printf "\t%c%c%c%c%c ${1} %c%c%c%c%c\r" \
            "$j" "$j" "$j" "$j" "$j" "$j" "$j" "$j" "$j" "$j"
            sleep 0.1
        done
    done
}
# spin
spin "test" & spinpid=$!
# spin & spinpid=$!
# long-running commands here
echo "开始执行！"
sleep 3
echo "\r\n执行成功！"
kill "$spinpid"