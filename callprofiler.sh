#!/bin/bash
#
# callprofiler
#

###########################################################################
#
# cscope command line searches
# cscope.out should have been built.
#
# cscope -d -R -L<n> where n is one of ...
# 0: Find this C symbol
# 1: Find this definition
# 2: Find functions called by this function
# 3: Find functions calling this function
# 4: Find this text string
# 6: Find this egrep pattern
# 7: Find this file
# 8: Find files #including this file
# 9: Find places where this symbol is assigned a value
#
###########################################################################

# Use unset in case these have been set elsewhere.
unset BLD && declare BLD="[1m"
unset UND && declare UND="[4m"
unset OFF && declare OFF="[0m"

# Contlol-C exit code
# see http://www.tldp.org/LDP/abs/html/exitcodes.html
unset CTLC_EXIT &&  declare -i CTLC_EXIT=130

# Other exit codes
declare -i EXIT_OK=0
declare -i EXIT_INVARG=1
declare -i EXIT_INVFIL=2
declare -i EXIT_INVDIR=3

declare -a exitmsgary=(
""
"Invalid number of arguments."
" is an invalid filename."
" is an invalid directory name."
)

exitme() {
	local exitval=$1
	local strarg=""
	local exitmsg

	if ([ $exitval -ne $EXIT_OK ] && [ $exitval -ne $CTLC_EXIT ]); then
		[ $# -eq 2 ] && strarg=$2
		[ ${#exitmsgary[@]} -gt $exitval ] \
			&& exitmsg="${exitmsgary[$exitval]}"

		echo -e "$BLD$strarg$exitmsg$OFF"

		[ $exitval -ne 0 ] && echo -e \
			"Type$BLD callprofiler -h$OFF for help."
	fi

	exit $exitval
}

# run if user hits control-c
#
control_c()
{
	echo -en "
Ctrl-c detected
Cleaning up and exiting.
"
	exitme $CTLC_EXIT
}


declare -i optcount=0

declare usagestr=$(
cat <<EOF

$(basename $0) [options] function directory

Trace callers of the named function. Without a named directory, the trace
will be kernel-wide.

NOTE: Must have cscope.out in the Current Working Directory.
      PWD must be the top of a linux kernel tree.
      Current Working Directory: $BLD$PWD$OFF

Arguments:
  function  - function to trace
  directory - limits search to the named directory and its subdirectories

Options:
  -h  - help
\0
EOF
)

usage() {
	echo -en "$usagestr"
	exitme 0
}



main() {
        # Trap for control-c
        trap control_c SIGINT

	while getopts h OPTION; do
    	    case "$OPTION" in
		h ) usage
let ++optcount
		    ;;
		* ) echo "unrecognized option -$OPTION"
		    echo -e "$usagestr"
		    exit 127
	    esac
	done

	shift $optcount
	[ $# -eq 2 ] || exitme $EXIT_INVARG


	exitme $EXIT_OK
}

main $@

exitme $EXIT_OK

