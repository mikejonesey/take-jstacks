#!/bin/bash
if [ "$(df /var | tail -1 | awk '{print $4}')" -lt "7340032" ]; then printf "not enough disk space... \nclean up first...\n"; exit 1; fi
sudo -u hybris mkdir /var/tmp/$(date +%Y-%m-%d) 2>/dev/null
sudo -u hybris /usr/lib/sun/current/bin/jmap -dump:live,format=b,file=/var/tmp/$(date +%Y-%m-%d)/heap-$(date +%s).bin $(ps -ef | grep -i java | grep -v grep | grep "hybris" | tail -1 | awk '{print $2}')

