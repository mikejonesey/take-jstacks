#!/bin/bash

STACKCWD="/tmp/$(date +"%Y-%m-%d")"
LAST_STACK="$STACKCWD/$(ls -1rt /tmp/$(date +"%Y-%m-%d") | tail -1)"
cat "$LAST_STACK" | grep "^\"" | sed 's/ /@/g;s/pcpu=\([0-9\.]*\)/pcpu= \1 /' | sort -n -k2 | sed 's/@/ /g'

