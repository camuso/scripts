#!/bin/bash

CNT=0
OFFSETOLD=0

NTPSERVER=clock.corp.redhat.com

# At Goldman, the server is: ntp2ny01.ny.fw.gs.com
# At Red Hat, the server is: clock.corp.redhat.com

date > /var/tmp/offset-calc.out
echo CNT,OFFSET,SKEW >> /var/tmp/offset-calc.out 2>&1

while :
do
   OFFSET=`ntpdate -q $NTPSERVER | head -1 | awk '{print $6}' | sed 's/,//g'`
   sleep 60
   SKEW=`echo "$OFFSET - $OFFSETOLD" | bc `
   OFFSETOLD=$OFFSET
   echo $CNT,$OFFSET,$SKEW >> /var/tmp/offset-calc.out 2>&1
   CNT=`expr $CNT + 1`
done
