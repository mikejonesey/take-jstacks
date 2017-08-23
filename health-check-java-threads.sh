#!/bin/bash
################################################
# health-check-java-threads.sh
# Check what java threads are doing and look for common issues
# Author        Michael Jones <michael.jones@linux.com>
# Date          2017-01-28
################################################
#

REQUIRED_TOOLS=(strace)

for tool in $REQUIRED_TOOLS; do
	which $tool &>/dev/null
	if [ "$?" != "0" ]; then
		echo "$tool is required, please install it"
	fi
done

processID=$(ps -ef | grep -i "java.*Xmx" | grep -v grep | tail -1 | awk '{print $2}')

for lwp in $(ps -L --pid $processID | awk '{print $2}' | tail -n +3); do
	if [ ! -d "/proc/$processID/task/$lwp" ]; then
		echo "$lwp gone..."
		continue
	fi
	echo "checking $lwp..."
	processdata=$(timeout 2 strace -qq -p $lwp 2>&1)
	timeout 2 strace -qq -p $lwp -c -S calls
	if [ -n "$(echo "$processdata" | grep "futex.*Connection timed out")" ]; then
		# Thread is polling or failing to connect...
		#if []; then
			echo "Thread $lwp is strugging to connect, check mysql settings for &autoReconnect=true"
		#fi 
	fi
done

