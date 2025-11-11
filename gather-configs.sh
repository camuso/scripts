#!/bin/bash
ARCHES="aarch64
ppc64le
s390x
x86_64"

find_release()
{
    local top=$(basename $(git rev-parse --show-toplevel))
    [[ "$top" == *"8"* ]] && rel="r8" && return
    [[ "$top" = *"9"* ]] && rel="r9" && return
    echo "unable to determine release" && exit
}

file=$(basename $(pwd))
find_release

for arch in $ARCHES; do
    filename="${file}.${arch}.${rel}.txt"
    find-configs.sh ${arch} > $filename
done
