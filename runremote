#!/bin/bash
# runremote.sh (revised, not dependent upon /dev/stdin)
# usage: runremote.sh localscript remoteuser remotehost arg1 arg2 ...

realscript=$1
user=$2
host=$3
shift 3

# escape the arguments
declare -a args

count=0
for arg in "$@"; do
  args[count]=$(printf '%q' "$arg")
  count=$((count+1))
done

{
  printf '%s\n' "set -- ${args[*]}"
  cat "$realscript"
} | ssh $user@$host "bash -s"
