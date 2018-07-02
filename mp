#!/bin/bash
#
# mp

main() {
	[ -d ../$pat ] || mkdir ../pat
	rm -f ../pat/*
	gitfor1pat ../pat 1 $1
}

main $@

exit 0

