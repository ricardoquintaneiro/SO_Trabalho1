#!/bin/bash

# Aqui, em vez de declararmos arrays para read e write, podemos declarar uma matrix, em que cada linha é um processo e cada coluna é uma informação relativa ao processo

export LANG=en_US.UTF-8
export LANGUAGE=en
declare -A matrix
column=6
reverse=""


# Mensagem que demonstra quais opções podem ser utilizadas ao executar este ficheiro. Esta mensagem aparece quando os argumentos de entrada não estão bem formatados.
usage() { echo "Usage: $0 [-c <regex>] [-s <mindate>] [-e <maxdate>] [-u <user>]\
 [-m <minPID>] [-M <maxPID>] [-p <num>] [-r] [-w] <sleepT>" 1>&2; exit 1; }

# VP - Verificação de Processos

regex_positive_int='^[0-9]+$'

while getopts "c:s:e:u:m:M:p:rw" o; do
    case "${o}" in
        c)
                c="^${OPTARG}$"
                ;;
        s)
                s=$(date -d "${OPTARG}" +"%s")
                if ! [ $? == 0 ]; then
                        usage
                fi
                ;;
        e)
                e=$(date -d "${OPTARG}" +"%s")
                if ! [ $? == 0 ]; then
                        usage
                fi
                ;;
        u)
                u=${OPTARG}
                ;;
        m)
                m=${OPTARG}
                if ! [[ $m =~ $regex_positive_int ]] ; then
                        usage
                fi
                ;;
        M)
                M=${OPTARG}
                if ! [[ $M =~ $regex_positive_int ]] ; then
                        usage
                fi
                ;;
        p)
                p=${OPTARG}
                if ! [[ $p =~ $regex_positive_int ]] || [[ $p -eq 0 ]]; then
                        usage
                fi
                ;;
        r)
                reverse="r"
                ;;
        w)
                column=7
                ;;
        *)
                usage
                ;;
    esac
done
shift $((OPTIND-1))

if [ -z "$1" ] || ! [ -z "$2" ] ||
 ! [[ $1 =~ $regex_positive_int ]] || [[ $1 -eq 0 ]]; then
        usage
fi
sleep_time=$1

# LRP - Leitura e Registo de Processos
i=1
while IFS= read -r line
do
        # Condição que verifica se existe/temos acesso à pasta io, necessária para obter os valores de write e read
        cat /proc/$line/io &> /dev/null
        if ! [ $? == 0 ]; then
                continue
        fi

        cat /proc/$line/comm &> /dev/null
        # Condição que verifica se temos permissão para aceder ao processo, bem como se o PID pertence ao intervalo que pode (ou não) ser dado
        if ! [ $? == 0 ] || { ! [ -z "${m}" ] && [ "$line" -lt "$m" ]; } || { ! [ -z "${M}" ] && [ "$line" -gt "$M" ]; }; then
                continue
        fi

        comm=$(cat /proc/$line/comm)
        # Condição que verifica se o nome do processo cumpre o regex que pode (ou não) ser dado
        if ! [ -z "${c}" ] && ! [[ $comm =~ $c ]]; then
                continue
        fi

        user=$(ps -o user $line | grep -v 'USER')
        # Condição que verifica se o user do processo é o mesmo que o que pode (ou não) ser dado
        if ! [ -z "${u}" ] && ! [ "$u" == "$user" ]; then
                continue
        fi

        date_epoch=$(stat -c %Y /proc/$line)
        # Condição que verifica se a data do processo está de acordo com o intervalo que pode (ou não) ser dado
        if { ! [ -z "${s}" ] && [ "$date_epoch" -lt "$s" ]; } || { ! [ -z "${e}" ] && [ "$date_epoch" -gt "$e" ]; }; then
                continue
        fi
        date_readable=$(date -d @$date_epoch +%b' '%e' '%k:%M)

        # Aqui no fim, podemos registar a informação que já temos (nome, data, user) e guardar num array ou num string, para termos menos trabalho no fim

        matrix[$i,1]=$comm
        matrix[$i,2]=$user
        matrix[$i,3]=$line
        matrix[$i,4]=$(cat /proc/$line/io | grep "rchar:" | awk '{print $2}')
        matrix[$i,5]=$(cat /proc/$line/io | grep "wchar:" | awk '{print $2}')
        matrix[$i,8]=$date_readable
        i=$((i + 1))

done < <(ls -l /proc/ | awk '{print $9}' | grep -x -E '[0-9]+')

# Este sleep tem que ser feito para podermos calcular o rateR e o rateW, que necessitam de uma medição de tempo
sleep $sleep_time

# OID - Ordenação de Informação para Display

for ((j=1;j<$i;j++)) do
        cat /proc/${matrix[$j,3]}/comm &> /dev/null
        if ! [ $? == 0 ]; then
                continue
        fi
        finalr=$(cat /proc/${matrix[$j,3]}/io | grep "rchar:" | awk '{print $2}')
        finalw=$(cat /proc/${matrix[$j,3]}/io | grep "wchar:" | awk '{print $2}')
        matrix[$j,4]=$(echo "scale=2; ($finalr-${matrix[$j,4]})" | bc)
        matrix[$j,5]=$(echo "scale=2; ($finalw-${matrix[$j,5]})" | bc)
        matrix[$j,6]=$(echo "scale=2; ${matrix[$j,4]} / $sleep_time" | bc | awk '{printf "%.2f\n", $0}')
        matrix[$j,7]=$(echo "scale=2; ${matrix[$j,5]} / $sleep_time" | bc | awk '{printf "%.2f\n", $0}')

done

# DI - Display de Informação

printf "%-20s%-9s%6s%11s%12s%12s%14s%14s\n" "COMM" "USER" "PID" "READB" "WRITEB" "RATER"\
        "RATEW" "DATE"

for ((j=1;j<$i;j++)) do
        cat /proc/${matrix[$j,3]}/comm &> /dev/null
        if ! [ $? == 0 ]; then
                continue
        fi
        printf "%-20s \b%-9s \b%6s \b%11s \b%12s \b%12s \b%14s \b%14s\n" "${matrix[$j,1]}" "${matrix[$j,2]}" "${matrix[$j,3]}" "${matrix[$j,4]}" "${matrix[$j,5]}"\
                "${matrix[$j,6]}" "${matrix[$j,7]}" "${matrix[$j,8]}"
done |
 sort -t $'\b' -"$reverse"g -k"$column" |
  ( ! [ -z "$p" ] && awk "NR<=$p" || awk "NR>0")