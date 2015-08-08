#!/bin/bash
################################################
# take-stacks.sh
# take stack traces with the pcpu mapped to each thread
# this can be used to identify which threads are consuming cpu
# Author        Michael Jones <michael.jones@linux.com>
# Date          07/08/2015
################################################
#

TRACE_COUNT=10
TRACE_INTERVAL=1
JAVA_PID=$(ps -ef | grep java | grep -v grep | tail -1 | awk '{print $2}')
TMP_DIR="/tmp/$(date +"%Y-%m-%d")"

mkdir $TMP_DIR 2>/dev/null

for ((i=0; i<$TRACE_COUNT; i++)); do
  TRACETIME=$(date +"%s")
  EXINF=$(ps -eLo pcpu,lwp,sgi_p,maj_flt,min_flt,etimes,cmd | grep java | grep -v grep | sort -k1,1 -n | while read al; do nid=$(printf "0x%x\n" $(echo "$al" | awk '{print $2}')); echo "$nid $al"; done)
  jstack -l "$JAVA_PID" > $TMP_DIR/stack-$TRACETIME.out
  echo "$EXINF" | while read al; do
    NID=$(echo "$al" | awk '{print $1}')
    ESTR="$(echo "$al" | awk '{print "pcpu=" $2 " core=" $4 " page=" $5 " mpage=" $6 " secs=" $7}')"
    sed -i "s/nid=$NID/nid=$NID $ESTR/" $TMP_DIR/stack-$TRACETIME.out
  done
  sleep $TRACE_INTERVAL
done

