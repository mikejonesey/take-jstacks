#!/bin/bash
################################################
# take-stacks.sh
# take stack traces with the pcpu mapped to each thread
# this can be used to identify which threads are consuming cpu
# Additional Info added to JAVA Thread Dumps:
#   - pcpu (percentage of cpu usage on the current core)
#   - cpu core
#   - page faults major + minor
#   - etimes (how long the process has been running)
# Author        Michael Jones <michael.jones@linux.com>
# Date          07/08/2015
################################################
#

TRACE_COUNT=1
TRACE_INTERVAL=1
JAVA_PID=$(ps -ef | grep java | grep -v grep | tail -1 | awk '{print $2}')
TMP_DIR="/tmp/$(date +"%Y-%m-%d")"

mkdir $TMP_DIR 2>/dev/null

ps -o etimes &>/dev/null
if [ "$?" == "0" ]; then
	etimes_valid=true
else
	etimes_valid=false
fi

for ((i=0; i<$TRACE_COUNT; i++)); do
	TRACETIME=$(date +"%s")
	if [ $etimes_valid == true ]; then
		EXINF=$(ps -eLo pcpu,lwp,sgi_p,maj_flt,min_flt,etimes,cmd | grep java | grep -v grep | sort -k1,1 -n | while read al; do 
			LWP=$(echo "$al" | awk '{print $2}')
			nid=$(printf "0x%x\n" $(echo "$al" | awk '{print $2}'))
			if [ -f "/proc/$JAVA_PID/task/$LWP/stack" ]; then
				CSTACK_CMD=$(cat /proc/$JAVA_PID/task/$LWP/stack | head -1 | sed 's/.*\] //;s/+.*//;s/^[_]*//')
				if [ -z "$CSTACK_CMD" ]; then
					CSTACK_CMD="c-2"
				fi
			else
				CSTACK_CMD="c-1"
			fi
			if [ -f "/proc/$JAVA_PID/task/$LWP/syscall" ]; then
				syscall=$(cat /proc/$JAVA_PID/task/$LWP/syscall | awk '{print $1}')
				syscall_cmd=$(grep " $syscall$" /usr/include/asm/unistd_64.h | awk '{print $2}' | sed 's/.*_//;s/ //')
				if [ -z "$syscall_cmd" ]; then
					syscall_cmd="s-2"
				fi
			else
				syscall_cmd="s-1"
			fi
			echo "$nid $syscall_cmd $cstack_cmd $al"
		done)
	else
		SYS_BOOTTIME=$(cat /proc/stat | grep btime | awk '{print $2}') # boot time, in seconds since the Epoch (January 1, 1970)
		SYS_JIFFPS=$(getconf CLK_TCK) # jiffies ps
		SYS_CURTIME=$(date +"%s") # time since epo
		SYS_UPTIME=$(($SYS_CURTIME-$SYS_BOOTTIME)) # uptime in secs
		EXINF=$(ps -eLo pcpu,lwp,sgi_p,maj_flt,min_flt,cmd | grep java | grep -v grep | sort -k1,1 -n | while read al; do
			LWP=$(echo "$al" | awk '{print $2}')
			if [ -f "/proc/$JAVA_PID/task/$LWP/stat" ]; then
				nid=$(printf "0x%x\n" $LWP)
				THREAD_STIME=$(cat /proc/$JAVA_PID/task/$LWP/stat | awk '{print $22}')
				THREAD_ETIME=$(bc <<< "scale=2; $SYS_UPTIME - ($THREAD_STIME/$SYS_JIFFPS)")
				TIMESTAMP=$(date -d@$(($SYS_CURTIME-$(echo "$THREAD_ETIME" | sed 's/\..*//'))) +"%Y-%m-%d_%H:%M:%S")
				etimes="$THREAD_STIME $THREAD_ETIME $TIMESTAMP"
			else
				etimes="-1 -1 -1"
			fi
			if [ -f "/proc/$JAVA_PID/task/$LWP/stack" ]; then
				cstack_cmd=$(cat /proc/$JAVA_PID/task/$LWP/stack | head -1 | sed 's/.*\] //;s/+.*//;s/^[_]*//')
				if [ -z "$cstack_cmd" ]; then
					cstack_cmd="c-2"
				fi
			else
				cstack_cmd="c-1"
			fi
			if [ -f "/proc/$JAVA_PID/task/$LWP/syscall" ]; then
				syscall=$(cat /proc/$JAVA_PID/task/$LWP/syscall | awk '{print $1}')
				syscall_cmd=$(grep " $syscall$" /usr/include/asm/unistd_64.h | awk '{print $2}' | sed 's/.*_//;s/ //')
				if [ -z "$syscall_cmd" ]; then
					syscall_cmd="s-2"
				fi
			else
				syscall_cmd="s-1"
			fi
			echo "$nid $syscall_cmd $cstack_cmd $etimes $al"
		done)
	fi
	which jcmd &>/dev/null && jcmd $JAVA_PID Thread.print -l >$TMP_DIR/stack-$TRACETIME.out || (which jstack &>/dev/null && jstack -l "$JAVA_PID" > $TMP_DIR/stack-$TRACETIME.out || (echo "No stack" && exit 1))
	echo "$EXINF" | while read al; do
		NID=$(echo "$al" | awk '{print $1}')
		NIDs=$(echo "$NID" | sed 's/0x//')
		if [ $etimes_valid == true ]; then
			ESTR="pid=$((16#$NIDs)) $(echo "$al" | awk '{print "pcpu=" $4 " core=" $6 " majpage=" $7 " minpage=" $8 " syscall=" $2 " cstack=" $3 " secs=" $9}')"
		else
			ESTR="pid=$((16#$NIDs)) $(echo "$al" | awk '{print "pcpu=" $7 " core=" $9 " majpage=" $10 " minpage=" $11 " syscall=" $2 " cstack=" $3 " secs=" $5 " time=" $6}')"
		fi
		sed -i "s/nid=$NID/nid=$NID $ESTR/" $TMP_DIR/stack-$TRACETIME.out
	done
	sleep $TRACE_INTERVAL
done

