#!/bin/bash
FILES="./Kconfig"
CONFIGS=
ARCHES="aarch64
ppc64le
s390x
x86_64"

usage()
{
    echo "find-configs <arch> [-t|--toplevel] [-h|--help]"
}

validate_arch()
{
    for a in $ARCHES; do
	[ "$a" = "$arch" ] && return
    done

    echo "invalid arch: $arch"
    echo "valid arches:" $ARCHES
    usage && exit
}

set_vars()
{
    local top=$(git rev-parse --show-toplevel)
    local dir=$(pwd)
    PREFIX=${dir#${top}/}

    [ -z "$PREFIX" ] && echo "unable to determine PREFIX" && exit

    CONFIG_FILE=$(ls ${top}/redhat/configs/kernel-*-${arch}.config 2>/dev/null)

    [ -z "$CONFIG_FILE" ] && echo "unable to determine config file" && exit
}

find_files()
{
    results=$(find . -name Kconfig | grep -vF "./Kconfig")
    for result in $results; do
	[ -z "$FILES" ] && FILES="$result" || FILES="$FILES $result"
    done
}

parse_file_configs()
{
    results=$(grep "^config\|^menuconfig" $1 | awk '{print $2}')
    for result in $results; do
	config="CONFIG_${result}"
	[ -z "$CONFIGS" ] && CONFIGS="$config" || CONFIGS="$CONFIGS $config"
    done
}

parse_files()
{
    for file in $FILES; do
	parse_file_configs $file
    done
}

check_for_missing_file()
{
    local file
    for file in $FILES; do
	[ "$1" = "$file" ] && return
    done
    # this should never happen :-)
    echo "MISSING: $1"
    exit
}

find_includes()
{
    local result
    local results=$(grep "^source" $1 | awk '{print $2}' | tr -d '"')
    for result in $results; do
	local path=${result#${PREFIX}}
	path=".${path}"
	check_for_missing_file $path
    done
}

find_missing_files()
{
    local file
    for file in $FILES; do
	find_includes $file
    done;
}

check_configs()
{
    for config in $CONFIGS; do
	result=$(grep "$config \|$config\=" $CONFIG_FILE)
	if [ -z "$result" ]; then
	    echo "$config does not exist"
	else
	    echo "$result"
	fi
    done
}

arch=
search=true
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
	-h|--help)
	    usage && exit;
	    ;;

	-t|--toplevel)
	    search=false
	    ;;

	*)
	    [ ! -z "$arch" ] && usage && exit
	    arch=$key
	    ;;
    esac
    shift
done

validate_arch
set_vars

[ "$search" = "true" ] && find_files
parse_files
[ "$search" = "true" ] && find_missing_files
check_configs
