#!/bin/bash

declare -A readsArray
declare -A writesArray
declare -A pid_data

sleep_time=10

# FAZER UM USAGE!!!

usage() { echo "Usage: $0 [-s <45|90>] [-p <string>]" 1>&2; exit 1; }

#

while getopts ":c:s:e:u:m:M:p:r:w:" o; do
    case "${o}" in
        c)
                c=${OPTARG}
                ;;
        s)
                s=${OPTARG}
                ;;
        e)
                e=${OPTARG}    
                ;;
        u)
                u=${OPTARG}
                ;;
        m)
                m=${OPTARG}
                ;;
        M)
                M=${OPTARG}
                ;;
        p)
                p=${OPTARG}
                ;;
        r)
                reverse="r"
                ;;
        w)
                column=5
                ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# MUDAR ESTE IF

if [ -z "${s}" ] || [ -z "${p}" ]; then
    usage
fi


while IFS= read -r line
do
        cat /proc/$line/comm &> /dev/null
        if [ $? == 1 ]; then
                continue
        fi
        if [ "$line" < "$m" ]; then
                continue
        fi
        if [ "$line" > "$M" ]; then
                continue
        fi
        comm=$(cat /proc/$line/comm)
        if [ "$comm" !=~ "$c" ]; then
                continue
        fi
        # if [ "$comm" == "rwstat.sh" ]; then
        #         continue
        # fi
        cat /proc/$line/io &> /dev/null
        if [ $? == 1 ]; then
                continue
        fi
        readsArray[$line]=$(cat /proc/$line/io | grep "rchar:" | awk '{print $2}')
        writesArray[$line]=$(cat /proc/$line/io | grep "wchar:" | awk '{print $2}')
done < <(ls -l /proc/ | awk '{print $9}' | grep -x -E '[0-9]+')

sleep $sleep_time

for pid in "${!readsArray[@]}"; do
        cat /proc/$line/comm &> /dev/null # NÃO ESQUECER DE DAR MERGE NO CÓDIGO DO ALEX
        if [ $? == 1 ]; then
                continue
        fi
        date_epoch=$(stat -c %Y /proc/$pid)
        if [ "$s" > "$date_epoch" ]; then
                continue
        fi
        if [ "$e" < "$date_epoch" ]; then
                continue
        fi
        comm=$(cat /proc/$pid/comm)
        user=$(ps -o user $pid | grep -v 'USER')
        if [ "$u" != "$user" ]; then
                continue
        fi
        write2=$(cat /proc/$pid/io | grep "wchar:" | awk '{print $2}')
        read2=$(cat /proc/$pid/io | grep "rchar:" | awk '{print $2}')
        rater=$(echo "scale=2; ($read2-${readsArray[$pid]}) / $sleep_time" | bc)
        ratew=$(echo "scale=2; ($write2-${writesArray[$pid]}) / $sleep_time" | bc)
        # readsArray[$pid]=read2
        # writesArray[$pid]=write2
        pid_data[$pid]="$comm" "$user" "$pid" "$read2" "$write2"\
                "$rater" "$ratew" "$date_epoch"
done

printf "%-20s%-9s%6s%11s%12s%11s%14s%14s\n" "COMM" "USER" "PID" "READB" "WRITEB" "RATER"\
        "RATEW" "DATE"

# reverse="" 
# column=4
# sort -"$reverse"n -k"$column"



# if [ "$i" == "$p" ]; then
        #         continue
        # fi
# fazer i=p check




# date_readable=$(date -d @$date_epoch +%b' '%e' '%k:%M)
# printf "%-20s%-9s%6s%11s%12s%11s%14s%14s\n" "$comm" "$user" "$pid" "$read2" "$write2"\
                # "$rater" "$ratew" "$date_readable"