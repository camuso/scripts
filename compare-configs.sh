#!/bin/bash
usage()
{
    echo "compare-configs.sh: <new relase file> <old release file>"
}

process_mismatch()
{
    local line=$1
    if [ "${line:0:1}" = "#" ]; then
	config=$(echo $line | awk '{print $2}')
    else
	config=$(echo $line | awk '{print $1}')
    fi
    config=$(echo $config | cut -d '=' -f 1)
    result=$(grep "$config \|$config=" $fileB)
    [ $? -ne 0 ] && echo "MISSING: $line" && return
    echo "CHANGE: \"$line\" was \"$result\""
}

process_line()
{
    local line=$1
    grep "$line" $fileB &> /dev/null
    [ $? -eq 0 ] && echo "MATCH: $line" && return
    process_mismatch "$line"
}

fileA=
fileB=
while [[ $# -gt 0 ]]; do
    key="$1"
    shift
    case $key in
	-h|--help)
	    usage && exit;
	    ;;
	*)
	    echo "$fileA $fileB $key"
	    [ -z "$fileA" ] && fileA="$key" && continue
	    [ -z "$fileB" ] && fileB="$key" && continue
	    usage && exit
	    ;;
    esac
done

[ -z "$fileB" ] && usage && exit

while read line; do
    process_line "$line"
done < $fileA


