#!/bin/bash
#
# rd

[ "$MYDIR" ] || declare MYDIR=$(dirname $(which $(basename $0)))
[ "$MYLIB" ] || declare MYLIB=$MYDIR/lib

[ "$ui_loaded" ]            || source $MYLIB/ui.source

declare repomap="$HOME/.config/patchreview/repomap"
declare repolist="$HOME/.config/patchreview/repolist"
declare usagestr=$(
cat <<EOF

$(basename $0) [reponame | show]

Description:
	cd to a directory denoted by "repodir"

	Create a ~/.config/patchreview/repomap file to map names
	to repo directories, with the name in the first field and
	the directory in the second. E.g...
	rh7 /work/7/kernel
	rh8 /work/7/kernel

Arguments:
	show 	 -  dumps the contents of ~/.config/patchreview/repomap

	reponame - the name mapped to a specific directory in the
	           ~/.config/patchreview/repomap file

	If you do not present a name from the repomap firle as an arugment,
	you will get a numbered list of repo directories stored in your
	repolist file.

	If that file does not exist, then create it by putting the names
	of your repo directories in ...
	~/.config/patchreview/repomap

\0
EOF
)

declare norepolist=$(
cat <<EOF

The $repolist file containing a list of your repo directories does
not exist. Please create it.
\0
EOF
)

declare nomatch=$(
cat <<EOF

The repo name you submitted could not be found in
$repomap.

EOF
)

usage() {
	echo -en "$usagestr"
	exit 1
}

cd_fromrepolist() {
	local repod=
	local dary=()
	local dndx=0
	local dnum=

	dary=($(cat $repolist))
	for ((dndx = 0; dndx < ${#dary[@]}; ++dndx)); do
		echo -e "$MNU$((dndx+1)). $OFF${dary[dndx]}"
	done

	loop_range_q 1 ${#dary[@]} dnum || return 1
	repod=${dary[dnum-1]}

	[ -d "$repod" ] || {
		echo -e "$WRN$repod is not a directory!$OFF"
		exit 1
	}

	cd "$repod"
}

main() {
	[ ${#@} -eq 1 ] || usage

	local arg="$1"
	local repod=

	if [ -f "$repomap" ]; then
		[ "$arg" == "show" ] && { cat "$repomap"; exit 0; }
	fi

	line=$(grep $arg $repomap)

	if [ -z "$line" ]; then
		echo -e "$nomatch"
		[ -f "$repolist" ] || { echo -e "$norepolist"; exit 1; }
		cd_fromrepolist
	fi

	repod=$(echo $line | cut -d' ' -f2)
	cd $repod
	pwd
}

main $@

exit 0

