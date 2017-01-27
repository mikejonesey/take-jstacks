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
		EXINF=$(ps -eLo pcpu,lwp,sgi_p,maj_flt,min_flt,etimes,cmd | grep java | grep -v grep | sort -k1,1 -n | while read al; do nid=$(printf "0x%x\n" $(echo "$al" | awk '{print $2}')); echo "$nid $al"; done)
	else
		SYS_BOOTTIME=$(cat /proc/stat | grep btime | awk '{print $2}') # boot time, in seconds since the Epoch (January 1, 1970)
		SYS_JIFFPS=$(getconf CLK_TCK) # jiffies ps
		SYS_CURTIME=$(date +"%s") # time since epo
		SYS_UPTIME=$(($SYS_CURTIME-$SYS_BOOTTIME)) # uptime in secs
		# without etimes we'll rely on procfs;
		# Status information about the process.  This is used by ps(1).  It is defined in the kernel source file fs/proc/array.c
		#   starttime %llu (was %lu before Linux 2.6)
                #   The time in jiffies the process started after system boot.
		# procps calcs;
		# time = utime+stime/Hertz
		# etime = seconds_since_boot - (unsigned long)(pp->start_time / Hertz);
		# unsigned long long Hertz = find_elf_note(AT_CLKTCK);
		EXINF=$(ps -eLo pcpu,lwp,sgi_p,maj_flt,min_flt,cmd | grep java | grep -v grep | sort -k1,1 -n | while read al; do
			LWP=$(echo "$al" | awk '{print $2}')
			if [ -f "/proc/$JAVA_PID/task/$LWP/stat" ]; then
				nid=$(printf "0x%x\n" $LWP)
				JIFFTHREADTIME=$(cat /proc/$JAVA_PID/task/$LWP/stat | awk '{print $22}')
				THREADTIME=$(bc <<< "scale=2; $SYS_UPTIME - ($JIFFTHREADTIME/$SYS_JIFFPS)")
				TIMESTAMP=$(date -d@$(($SYS_CURTIME-$(echo "$THREADTIME" | sed 's/\..*//'))) +"%Y-%m-%d_%H:%M:%S")
				# Todo jiff time to time...
				etimes="$JIFFTHREADTIME $THREADTIME $TIMESTAMP"
			else
				etimes="-1 -1 -1"
			fi
			echo "$nid $etimes $al"
		done)
	fi
	jstack -l "$JAVA_PID" > $TMP_DIR/stack-$TRACETIME.out
	echo "$EXINF" | while read al; do
		NID=$(echo "$al" | awk '{print $1}')
		if [ $etimes_valid == true ]; then
			ESTR="$(echo "$al" | awk '{print "pcpu=" $2 " core=" $4 " page=" $5 " mpage=" $6 " secs=" $7}')"
		else
			ESTR="$(echo "$al" | awk '{print "pcpu=" $5 " core=" $7 " page=" $8 " mpage=" $9 " jifftime=" $2 " secs=" $3 " time=" $4}')"
		fi
		sed -i "s/nid=$NID/nid=$NID $ESTR/" $TMP_DIR/stack-$TRACETIME.out
	done
	sleep $TRACE_INTERVAL
done

