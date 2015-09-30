#!/bin/bash

usage() {
	echo
	echo "sol - Connect Serial Over Lan to a host's ipmi"
	echo
	echo "sol [user] ip"
	echo
	echo -e "\tuser - Optional. Default user is root, so if this argument"
	echo -e "\t       is omitted, the ipmi user will be root."
	echo
	exit 1
}

case $# in
	1 ) 	ip="$1"
		user="root"
		;;
	2 )	ip="$2"
		user="$1"
		;;
	* )	usage
		;;
esac

echo "ipmitool -I lanplus -U $user -H "$ip" -P '' sol activate"
ipmitool -I lanplus -U $user -H "$ip" -P '' sol activate
