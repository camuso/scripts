#!/bin/bash
R85_START="ITM1:2021-03-08"
R86_START="ITM1:2021-09-06"
R87_START="ITM1:2022-03-07"
R88_START="ITM1:2022-09-05"
R89_START="ITM1:2023-03-06"
R810_START="ITM1:2023-09-04"
R95_START="ITM1:2024-03-04"
R96_START="ITM1:2024-09-02"
R100_BETA_START="$R95_START"
R100_START="$R96_START"
R97_START="ITM1:2025-03-03"
R101_START="$R97_START"

declare -i arel=0	# index to release name
declare -i astart=1	# index to ITM start date

get_reltbl() {
	local idx="$1"
	local itm="$2"
	local val=

	IFS=' ' read -ra val <<< "$itm"
	echo "$val"
}

declare -A reltbl
# RHEL-8
reltbl[R85]="RHEL-8.5 ITM1:2021-03-08"
reltbl[R86]="RHEL-8.6 ITM1:2021-09-06"
reltbl[R87]="RHEL-8.7 ITM1:2022-03-07"
reltbl[R88]="RHEL-8.8 ITM1:2022-09-05"
reltbl[R89]="RHEL-8.9 ITM1:2022-03-06"
reltbl[R810]="RHEL-8.10 ITM1:2023-09-04"
# RHEL-9
reltbl[R95]="RHEL-9.5 ITM1:2024-03-04"
reltbl[R96]="RHEL-9.6 ITM1:2024-09-02"
reltbl[R97]="RHEL-9.7 ITM1:2025-03-03"
# RHEL-10
reltbl[R10B]="RHEL-10 Beta $(get_reltbl $astart ${reltbl[R95]})"
reltbl[R100]="RHEL-10.0 $(get_reltbl $astart ${reltbl[R96]})"
reltbl[R101]="RHEL-10.1 $(get_reltbl $astart ${reltbl[R97]})"

print_releases() {
	local akey

	for akey in "${!reltbl[@]}"; do
		echo "$(get_reltbl $arel "${reltbl[$akey]}")"
	done
}

usage()
{
    echo "itm.sh [itm] [-a|--all] [-n|--next] [-p|--prev] [-h|--help]"
    echo "  itm         : specific itm (1-36) or all if not specified"
    echo "  -a|--all    : show all 36 itms (instead of 26)"
    echo "  -n|--next   : show next release"
    echo "  -p|--prev   : show prev release"
    echo "  -r|--rel    : show all releases supported by this script"
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

start=$R96_START
rel="9.5/10.0 Public Beta"
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
	    start=$R96_START
	    ;;
	-p|--prev)
	    rel="8.10/9.4"
	    all=true
	    start=$R810_START
	    ;;
	-r|--rel)
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

