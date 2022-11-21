#!/bin/bash

declare -A readsArray
declare -A writesArray

sleep_time=2

while IFS= read -r line
do
        cat /proc/$line/comm &> /dev/null
        if [ $? == 1 ]; then
                continue
        fi
        comm=$(cat /proc/$line/comm)
        if [ "$comm" == "rwstat.sh" ]; then
                continue
        fi
        cat /proc/$line/io &> /dev/null
        if [ $? == 1 ]; then
                continue
        fi
        readsArray[$line]=$(cat /proc/$line/io | grep "rchar:" | awk '{print $2}')
        writesArray[$line]=$(cat /proc/$line/io | grep "wchar:" | awk '{print $2}')
done < <(ls -l /proc/ | awk '{print $9}' | grep -x -E '[0-9]+')

sleep $sleep_time

printf "%-20s%-9s%6s%11s%12s%11s%14s%14s\n" "COMM" "USER" "PID" "READB" "WRITEB" "RATER"\
        "RATEW" "DATE"

for pid in "${!readsArray[@]}"; do
        comm=$(cat /proc/$pid/comm)
        user=$(ps -o user $pid | grep -v 'USER')
        write2=$(cat /proc/$pid/io | grep "wchar:" | awk '{print $2}')
        read2=$(cat /proc/$pid/io | grep "rchar:" | awk '{print $2}')
        rater=$(echo "scale=2; ($read2-${readsArray[$pid]}) / $sleep_time" | bc)
        ratew=$(echo "scale=2; ($write2-${writesArray[$pid]}) / $sleep_time" | bc)
        readb=$(cat /proc/$pid/io | grep "rchar:" | awk '{print $2}')
        writeb=$(cat /proc/$pid/io | grep "wchar:" | awk '{print $2}')
        date_epoch=$(stat -c %Y /proc/$pid)
        date_readable=$(date -d @$date_epoch +%b' '%e' '%k:%M)
        printf "%-20s%-9s%6s%11s%12s%11s%14s%14s\n" "$comm" "$user" "$pid" "$readb" "$writeb"\
                "$rater" "$ratew" "$date_readable"
done