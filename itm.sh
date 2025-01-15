#!/bin/bash
#
# itm - a script to display itm dates for variouos releases.
#
# This script uses an associative array to map the release to a descriptor
# string containing the ITM1 date string.

declare myfullpath=
myfullpath="$(realpath "$0")"

declare -i psfw=0	# print same field width - see print_same()
declare -i arel=0	# index in reltbl descriptor string to release name
declare -i astart=1	# index in reltbl descriptor string to ITM start date

declare current_release
current_release="9.6"

# Release table
# Maps the release to strings that act as descriptors for the
# release.
#
declare -A reltbl
#      rel   ITM1 date
#      ----  ----------------
reltbl[8.5]="ITM1:2021-03-08"
reltbl[8.6]="ITM1:2021-09-06"
reltbl[8.7]="ITM1:2022-03-07"
reltbl[8.8]="ITM1:2022-09-05"
reltbl[8.9]="ITM1:2022-03-06"
reltbl[8.10]="ITM1:2023-09-04"
reltbl[9.5]="ITM1:2024-03-04"
reltbl[9.6]="ITM1:2024-09-02"
reltbl[9.7]="ITM1:2025-03-03"
reltbl[10.0-Beta]="${reltbl[9.5]}"
reltbl[10.0]="${reltbl[9.6]}"
reltbl[10.1]="${reltbl[9.7]}"

get_psfw() {
	local key;
	local gprel
	local -i fw

	for key in "${!reltbl[@]}"; do
		fw=${#key}
		(( fw > psfw )) && psfw=$((fw + 10))
	done;
}

print_releases() {
	local key
	local val
	local tmpfil
	local curdate=
	local curkeys=
	local line
	local date

	tmpfil=$(mktemp)
	get_psfw

	for key in "${!reltbl[@]}"; do
		echo "$key ${reltbl[$key]}"
	done | sort -t: -k2,2 > "$tmpfil"

	while read -r line; do
		key="${line%% *}"	# extract the key
		val="${line#* }"	# Extract the value (date)
		date="${val#*:}"	# Get the date part after the colon

		if [[ "$date" == "$curdate" ]]; then
			curkeys+="/$key" # Append to curkeys if date matches
		else
			if [[ -n "$curdate" ]]; then
				printf "%-*s ITM1:%s\n" $psfw "$curkeys" "$curdate"
			fi

			curdate="$date"
			curkeys="$key"
		fi
	done < "$tmpfil"

	if [[ -n "$curdate" ]]; then
		printf "%-*s ITM1:%s\n" $psfw "$curkeys" "$curdate"
	fi

	rm -f "$tmpfil"
}

usage()
{
    echo "itm.sh [itm] [-a|--all] [-n|--next] [-p|--prev] [-r|--rel] [-s|--show] [-h|--help]"
    echo "  itm         : specific itm (1-36) or all if not specified"
    echo "  -a|--all    : show all 36 itms (instead of 26)"
    echo "  -n|--next   : show next release"
    echo "  -p|--prev   : show prev release"
    echo "  -s|--show   : show all releases supported by this script"
    echo "  -r|--rel	: add a new release and ITM1 start date"
    echo "  -f|--find   : find releases having same ITM dates"
    echo "  -h|--help   : show this menu"
}

print_itm()
{
    index=$1
    id="ITM${index}"

    case "$index" in
	1)
	    trailer="Start - Planning"
	    ;;
	10)
	    trailer="End - Planning"
	    ;;
	12)
	    trailer="Test 1 (start)"
	    ;;
	20)
	    trailer="Test 2 (start)"
	    ;;
	26)
	    trailer="BETA"
	    ;;
	32)
	    trailer="Release Candidate"
	    ;;
	34)
	    trailer="Zero Day"
	    ;;
	36)
	    trailer="GA"
	    ;;
	*)
	    trailer=""
	    ;;
    esac

    printf "${bold}%-5s %s %s${normal}\n" $id $end "$trailer"
}

set_start_date()
{
    start=$(date -d "$end - 6 days" "+%Y-%m-%d")
}

decrement_dates()
{
    end=$(date -d "$end - $1 days" "+%Y-%m-%d")
    set_start_date
}

increment_dates()
{
    end=$(date -d "$end + $1 days" "+%Y-%m-%d")
    set_start_date
}

set_bold()
{
    tstart=$(date -d "$start days" "+%s")
    tend=$(date -d "$end days" "+%s")

    if [ "$today" -ge "$tstart" ] && [ "$today" -le "$tend" ]; then
	bold="$(tput bold)* "
    else
	bold="$normal  "
    fi
}

display_all_itms()
{
    [ "$all" = "true" ] && last=36 || last=26
    for ((i=1; i<=$last; ++i)); do
	set_bold 7
	print_itm $i
	increment_dates 7
    done
}

display_itm()
{
    end=$(echo $1 | cut -d : -f 2)
    set_start_date

    if [ "$itm" = "all" ]; then
	display_all_itms $1
    else
	adjust=$(((itm-1)*7))
	increment_dates $adjust
	print_itm $itm
    fi
}

today=$(date "+%Y-%m-%d")
today=$(date -d "$today days" "+%s")
normal=$(tput sgr0)
bold="$normal  "

rel="$current_release"
start="${reltbl[$rel]}"

itm=all
all=false
while [[ $# > 0 ]]; do
    key="$1"
    case $key in
	# next release
	-a|--all)
	    all=true;
	    ;;
	-h|--help)
	    usage && exit
	    ;;
	-n|--next)
	    echo "WARNING: Estimated start date"
	    rel="9.6/10.0GA"
	    start=
	    ;;
	-p|--prev)
	    rel="8.10/9.4"
	    all=true
	    start=
	    ;;
	-s|--show)
	    print_releases
	    exit 0
	    ;;
	*)
	    [ $itm != "all" ] && usage && exit
	    itm=$key
	    ;;
    esac
    shift # past argument or value
done

if [ "$itm" != "all" ]; then
    if [[ $itm -lt 1 ]] || [[ $itm -gt 36 ]]; then
	echo "ITM${itm} is invalid (range 1:36)"
	exit
    fi
fi

printf "RELEASE: $rel\n"
display_itm $start

