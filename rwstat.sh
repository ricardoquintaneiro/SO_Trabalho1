#!/bin/bash

printf "%-14s%-9s%6s%11s%12s%11s%14s%14s\n" "COMM" "USER" "PID" "READB" "WRITEB" "RATER"\
        "RATEW" "DATE"

while IFS= read -r line
do
        comm=$(cat /proc/$line/comm)
        if [ $comm == "rwstat.sh" ]; then
                break
        fi
        user=$(ps -o user $line | grep -v 'USER')
        read1=$(cat /proc/$line/io | grep "rchar:" | awk '{print $2}')
        write1=$(cat /proc/$line/io | grep "wchar:" | awk '{print $2}')
        sleep 2
        write2=$(cat /proc/$line/io | grep "wchar:" | awk '{print $2}')
        read2=$(cat /proc/$line/io | grep "rchar:" | awk '{print $2}')
        rater=$(echo "scale=2; ($read2-$read1) / 2" | bc)
        ratew=$(echo "scale=2; ($write2-$write1) / 2" | bc)
        readb=$(cat /proc/$line/io | grep "rchar:" | awk '{print $2}')
        writeb=$(cat /proc/$line/io | grep "wchar:" | awk '{print $2}')
        date_epoch=$(stat -c %Y /proc/$line)
        date_readable=$(date -d @$date_epoch +%b' '%e' '%k:%M)
        printf "%-14s%-9s%6s%11s%12s%11s%14s%14s\n" "$comm" "$user" "$line" "$readb" "$writeb"\
                "$rater" "$ratew" "$date_readable"
done < <(ps | awk '{print $1}' | grep -x -E '[0-9]+')
#ls -l /proc/ | grep -v 'root' | awk '{print $9}' | grep -x -E '[0-9]+' | sort -n)