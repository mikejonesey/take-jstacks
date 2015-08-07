#!/bin/bash
################################################
# take-stacks.sh
# take stack traces with the pcpu mapped to each thread
# this can be used to identify which threads are consuming cpu
# Author        Michael Jones <michael.jones@linux.com>
# Date          07/08/2015
################################################
#

TRACE_COUNT=1
JAVA_PID=$(ps -ef | grep java | grep -v grep | tail -1 | awk '{print $2}')

for ((i=0; i<$TRACE_COUNT; i++)); do
  TRACETIME=$(date +"%s")
  ps -eLo pcpu,pid,lwp,cmd | grep java | grep -v grep | awk '{print $1 " " $3}' | sort -k1,1 -n | while read al; do nid=$(printf "0x%x\n" $(echo "$al" | awk '{print $2}')); echo "$al $nid" | awk '{print $1 " " $3}'; done > /tmp/nid-rep-$TRACETIME.out
  jstack -l "$JAVA_PID" > /tmp/stack-$TRACETIME.out
  cat /tmp/nid-rep-$TRACETIME.out | while read al; do
    PCPU=$(echo "$al" | awk '{print $1}')
    NID=$(echo "$al" | awk '{print $2}')
    sed -i "s/nid=$NID/nid=$NID pcpu=$PCPU/" /tmp/stack-$TRACETIME.out
  done
done

