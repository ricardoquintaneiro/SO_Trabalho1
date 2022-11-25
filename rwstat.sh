#!/bin/bash

# Aqui, em vez de declararmos arrays para read e write, podemos declarar uma matrix, em que cada linha é um processo e cada coluna é uma informação relativa ao processo

declare -A matrix

declare -A readsArray
declare -A writesArray
declare -A pid_data

# O código estará separado em 4 grandes áreas:
# VP-Verificação de Parâmetros -> lugar onde se verifica que parâmetros estão presentes nos argumentos, e onde é feita a sua validação
# LRP-Leitura e Registo de Processos -> lugar onde é feita a leitura do /proc/ e onde se guarda os valores relevantes relativos a processos
# OID-Ordenação de Informação para Display -> lugar onde, tendo a lista de processos a demonstrar, se faz a sua ordenação, de acordo com os argumentos        
# DI-Display de Informação -> lugar onde se faz a escrita para a consola dos processos que queremos listar

column=4
reverse=""

# Mensagem que demonstra quais opções podem ser utilizadas ao executar este ficheiro. Esta mensagem aparece quando os argumentos de entrada não estão bem formatados.
usage() { echo "Usage: $0 [-c <regex>] [-s <mindate>] [-e <maxdate>] [-u <user>] [-m <minPID>] [-M <maxPID>] [-p <num>] [-r] [-w] <sleepT>" 1>&2; exit 1; }

# VP - Verificação de Processos

regex_positive_int='^[0-9]+$'

while getopts ":c:s:e:u:m:M:p:r:w:" o; do
    case "${o}" in
        c)
                c=${OPTARG}
                ;;
        s)
                s=$(date -d '${OPTARG}' +"%s")
                if ! [ $? == 0 ]; then
                        continue
                fi
                ;;
        e)
                e=$(date -d '${OPTARG}' +"%s")
                if ! [ $? == 0 ]; then
                        continue
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
                if ! [[ $P =~ $regex_positive_int ]] ; then
                        usage
                fi
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

if [ -z "$1" ] || ! [[ $1 =~ $regex_positive_int ]] ; then
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
        if [ $? == 1 ] || { ! [ -z "${m}" ] && [ "$line" < "$m" ]; } || { ! [ -z "${M}" ] && [ "$line" < "$M" ]; }; then
                continue
        fi

        comm=$(cat /proc/$line/comm)
        # Condição que verifica se o nome do processo cumpre o regex que pode (ou não) ser dado
        if ! [ -z "${c}" ] && ! [[ "$comm" =~ "$c" ]]; then
                continue
        fi

        # Condição que impede a listagem do próprio programa como um dos processos
        # if [ "$comm" == "rwstat.sh" ]; then
        #         continue
        # fi

        user=$(ps -o user $pid | grep -v 'USER')
        # Condição que verifica se o user do processo é o mesmo que o que pode (ou não) ser dado
        if ! [ -z "${u}" ] && ! [ "$u" == "$user" ]; then
                continue
        fi

        date_epoch=$(stat -c %Y /proc/$pid)
        # Condição que verifica se a data do processo está de acordo com o intervalo que pode (ou não) ser dado
        if { ! [ -z "${s}" ] && [ "$date_epoch" < "$s" ]; } || { ! [ -z "${e}" ] && [ "$date_epoch" < "$e" ]; }; then
                continue
        fi
        date_readable=$(date -d @$date_epoch +%b' '%e' '%k:%M)

        # Aqui no fim, podemos registar a informação que já temos (nome, data, user) e guardar num array ou num string, para termos menos trabalho no fim

        matrix[$i,1]=$comm
        matrix[$i,2]=$user
        matrix[$i,3]=$line
        matrix[$i,4]=$(cat /proc/$line/io | grep "rchar:" | awk '{print $2}')
        matrix[$i,5]=$(cat /proc/$line/io | grep "wchar:" | awk '{print $2}')
        matrix[$i,6]=$date_readable

        #pid_data[$line]="$comm" "$user" "$line" "$(cat /proc/$line/io | grep "rchar:" | awk '{print $2}')" "$(cat /proc/$line/io | grep "wchar:" | awk '{print $2}')"\
                 #"$date_readable"

        #readsArray[$line]=$(cat /proc/$line/io | grep "rchar:" | awk '{print $2}')
        #writesArray[$line]=$(cat /proc/$line/io | grep "wchar:" | awk '{print $2}')
        i=$((i + 1))
done < <(ls -l /proc/ | awk '{print $9}' | grep -x -E '[0-9]+')

# Este sleep tem que ser feito para podermos calcular o rateR e o rateW, que necessitam de uma medição de tempo
sleep $sleep_time



# OID - Ordenação de Informação para Display


printf "%-20s%-9s%6s%11s%12s%11s%14s%14s\n" "COMM" "USER" "PID" "READB" "WRITEB" "RATER"\
        "RATEW" "DATE"

for k in "${!matrix[@]}"
do
    echo $k ' - ' ${matrix["$k,3"]}
done |
sort -"$reverse"n -k"$3"

# DI - Display de Informação

# for pid in "${!readsArray[@]}"; do
#         date_epoch=$(stat -c %Y /proc/$pid)
#         comm=$(cat /proc/$pid/comm)
#         user=$(ps -o user $pid | grep -v 'USER')
#         write2=$(cat /proc/$pid/io | grep "wchar:" | awk '{print $2}')
#         read2=$(cat /proc/$pid/io | grep "rchar:" | awk '{print $2}')
#         rater=$(echo "scale=2; ($read2-${readsArray[$pid]}) / $sleep_time" | bc)
#         ratew=$(echo "scale=2; ($write2-${writesArray[$pid]}) / $sleep_time" | bc)
#         # readsArray[$pid]=read2
#         # writesArray[$pid]=write2
#         pid_data[$pid]="$comm" "$user" "$pid" "$read2" "$write2"\
#                 "$rater" "$ratew" "$date_epoch"
# done



# for pid in "${!pid_data[@]}"; do
#         finalw=$(cat /proc/$pid/io | grep "wchar:" | awk '{print $2}')
#         finalr=$(cat /proc/$pid/io | grep "rchar:" | awk '{print $2}')
#         ratew=$(echo "scale=2; ($finalw-${pid_data[$5]}) / $sleep_time" | bc)
#         rater=$(echo "scale=2; ($finalr-${pid_data[$4]}) / $sleep_time" | bc)
#         # pid_data[$line]="$comm" "$user" "$line" "$(cat /proc/$line/io | grep "rchar:" | awk '{print $2}')" "$(cat /proc/$line/io | grep "wchar:" | awk '{print $2}')"\
#                  #"$date_readable"
#         printf "%-20s%-9s%6s%11s%12s%11s%14s%14s\n" "${pid_data[$pid,1]}" "${pid_data[$pid,2]}" "${pid_data[$pid,3]}" "$finalw" "$finalr"\
#                 "$rater" "$ratew" "${pid_data[$pid,6]}"
# done |
# sort -"$reverse"n -k"$column"

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