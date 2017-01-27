# take-jstacks
A script that takes java stacks, and extends them with cpu info.

# Usage
./take-jstacks.sh

# Normal jstack:
    "ajp-apr-8009-exec-20" daemon prio=10 tid=0x00007f933001a000 nid=0x2d33 waiting on condition [0x00007f9320c52000]
    ...

# Modified jstack:
    "ajp-apr-8009-exec-20" daemon prio=10 tid=0x00007f933001a000 nid=0x2d33 pcpu=0.4 core=* page=0 mpage=106 jifftime=1896102089 secs=8060.11 time=2017-01-27_16:21:19 waiting on condition [0x00007f9320c52000]
    ...
