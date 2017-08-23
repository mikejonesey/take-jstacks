#!/bin/bash
################################################
# stack2graph.sh
# Map java threads to diagram, showing thread relationships.
# Author        Michael Jones <michael.jones@linux.com>
# Date          07/03/2017
################################################
#

stacktrace="$1"

if [ ! -f "$stacktrace" ]; then
	echo "Usage: ./stack2graph.sh /path/to/stack.file"
	exit 1
fi

# Head...
echo "digraph \"Stacktrace Statistics\" {
overlap=scale
splines=true
sep=.1
node [style=filled]" > /tmp/mydot.out

echo "Type of Graph: "
echo "1. Super Block Graph" 
echo "2. Blocked and Running thread states"
echo "3. All thread states"
read -p "which type? " graphType

if [ "$graphType" == "1" ]; then

# blocked detail...
cat $stacktrace | grep BLOCK -A2 | grep "waiting" | awk '{print $5}' | sort -u | while read aline; do 
	cat $stacktrace | tr "\n" "~" | sed 's/~"/\n"/g' | grep "waiting to lock $aline" | while read ablocked; do
		blockedname=$(echo "$ablocked" | sed 's/ .*//;s/"//g')
		blockedtop=$(echo "$ablocked" | tr "~" "\n" | head -4 | tail -2 | grep -o "(.*)")
		blockedtopuk=$(echo "$ablocked" | tr "~" "\n" | grep "uk.co.por" | head -1 | grep -o "(.*)")
		if [ -n "$blockedtopuk" ]; then
			blockedtop="$blockedtop\\n...\\n$blockedtopuk"
		fi
		echo "\"$blockedname\" [fillcolor=\"#ff1d38\",label=\"$blockedname\n$blockedtop\",shape=note]"
	done
done >> /tmp/mydot.out

# holding lock...
cat $stacktrace | grep BLOCK -A2 | grep "waiting" | awk '{print $5}' | sort -u | while read aline; do 
	blockerstack=$(cat $stacktrace | tr "\n" "~" | sed 's/~"/\n"/g' | grep "locked $aline")
	blocker=$(echo "$blockerstack" | sed 's/^"//;s/".*//')
	blockerstate=$(echo "$blockerstack" | egrep -o "(BLOCKED|RUNNABLE|TIMED_WAITING \(on object monitor\)|TIMED_WAITING \(parking\)|TIMED_WAITING \(sleeping\)|WAITING \(on object monitor\)|WAITING \(parking\))")
	blockertop=$(echo "$blockerstack" | tr "~" "\n" | head -5 | tail -3)
	blockertopuk=$(echo "$blockerstack" | tr "~" "\n" | grep "uk.co.por" | head -1)
	if [ -n "$blockertopuk" ]; then
	  blockertop="$blockertop\\n...\\n$blockertopuk"
	fi
	if [ "$blockerstate" == "BLOCKED" ]; then
		# already exists...
		#continue
		echo "\"$blocker\" [fillcolor=\"#ff1d38\",label=\"$blocker\n$blockertop\",shape=box]"
	elif [ "$blockerstate" == "RUNNABLE" ]; then
		echo "\"$blocker\" [fillcolor=\"#268f49\",label=\"$blocker\n$blockertop\",shape=note]"
	elif [ "$blockerstate" == "TIMED_WAITING (on object monitor)" ]; then
		echo "\"$blocker\" [fillcolor=\"#3639cf\",label=\"$blocker\n$blockertop\",shape=note]"
	elif [ "$blockerstate" == "TIMED_WAITING (parking)" ]; then
		echo "\"$blocker\" [fillcolor=\"#3639cf\",label=\"$blocker\n$blockertop\",shape=note]"
	elif [ "$blockerstate" == "TIMED_WAITING (sleeping)" ]; then
		echo "\"$blocker\" [fillcolor=\"#3639cf\",label=\"$blocker\n$blockertop\",shape=note]"
	elif [ "$blockerstate" == "WAITING (on object monitor)" ]; then
		echo "\"$blocker\" [fillcolor=\"#5558cd\",label=\"$blocker\n$blockertop\",shape=note]"
	elif [ "$blockerstate" == "WAITING (parking)" ]; then
		echo "\"$blocker\" [fillcolor=\"#5558cd\",label=\"$blocker\n$blockertop\",shape=note]"
	fi
done >> /tmp/mydot.out

else

# Nodes...
##################################################
# BLOCKED
##################################################
# blocked...
echo "//blocked" >> /tmp/mydot.out
cat $stacktrace | grep "java.lang.Thread.State: BLOCKED" -B1 | grep "^\"" | sed 's/" .*/"/;s/ /_/g' | awk '{print $1 " [fillcolor=\"#ff1d38\",label=" $1 "]"}' >> /tmp/mydot.out

##################################################
# RUNNABLE
##################################################
echo "//runnable" >> /tmp/mydot.out
cat $stacktrace | grep "java.lang.Thread.State: RUNNABLE" -B1 | grep "^\"" | sed 's/" .*/"/;s/ /_/g' | awk '{print $1 " [fillcolor=\"#268f49\",label=" $1 "]"}' >> /tmp/mydot.out

if [ "$graphType" == "3" ]; then
##################################################
# TIMED_WAITING (on object monitor)
##################################################
echo "//TIMED_WAITING (on object monitor)" >> /tmp/mydot.out
cat $stacktrace | grep "java.lang.Thread.State: TIMED_WAITING (on object monitor)" -B1 | grep "^\"" | sed 's/" .*/"/;s/ /_/g' | awk '{print $1 " [fillcolor=\"#3639cf\",label=" $1 "]"}' >> /tmp/mydot.out

##################################################
# TIMED_WAITING (parking)
##################################################
echo "//TIMED_WAITING (parking)" >> /tmp/mydot.out
cat $stacktrace | grep "java.lang.Thread.State: TIMED_WAITING (parking)" -B1 | grep "^\"" | sed 's/" .*/"/;s/ /_/g' | awk '{print $1 " [fillcolor=\"#3639cf\",label=" $1 "]"}' >> /tmp/mydot.out

##################################################
# TIMED_WAITING (sleeping)
##################################################
echo "//TIMED_WAITING (sleeping)" >> /tmp/mydot.out
cat $stacktrace | grep "java.lang.Thread.State: TIMED_WAITING (sleeping)" -B1 | grep "^\"" | sed 's/" .*/"/;s/ /_/g' | awk '{print $1 " [fillcolor=\"#3639cf\",label=" $1 "]"}' >> /tmp/mydot.out

##################################################
# WAITING (on object monitor)
##################################################
echo "//WAITING (on object monitor)" >> /tmp/mydot.out
cat $stacktrace | grep "java.lang.Thread.State: WAITING (on object monitor)" -B1 | grep "^\"" | sed 's/" .*/"/;s/ /_/g' | awk '{print $1 " [fillcolor=\"#5558cd\",label=" $1 "]"}' >> /tmp/mydot.out

##################################################
# WAITING (parking)
##################################################
echo "//WAITING (parking)" >> /tmp/mydot.out
cat $stacktrace | grep "java.lang.Thread.State: WAITING (parking)" -B1 | grep "^\"" | sed 's/" .*/"/;s/ /_/g' | awk '{print $1 " [fillcolor=\"#5558cd\",label=" $1 "]"}' >> /tmp/mydot.out

fi
fi

# Maps...
cat $stacktrace | grep BLOCK -A2 | grep "waiting" | awk '{print $5}' | sort -u | while read aline; do blocker=$(cat $stacktrace | tr "\n" "~" | sed 's/~"/\n"/g' | grep "locked $aline" | sed 's/^"//;s/".*//'); blocked=$(cat $stacktrace | tr "\n" "~" | sed 's/~"/\n"/g' | grep "waiting to lock $aline" | sed 's/ .*//;s/$/"/g;s/""$/"/g'); if [ -z "$blocker" ]; then blocker="$(echo "$blocked" | head -1 | sed 's/"//g')"; fi; echo "{ $blocked } -> \"$blocker\""; done >> /tmp/mydot.out

# Foot...
echo "}" >> /tmp/mydot.out

#cat /tmp/mydot.out | neato -Tps | convert - /tmp/out.png
cat /tmp/mydot.out | neato -Tps > /tmp/neat.out
cat /tmp/neat.out | convert -limit memory unlimited -limit disk unlimited - /tmp/out.png
geeqie /tmp/out.png
cp /tmp/out.png $stacktrace.png

