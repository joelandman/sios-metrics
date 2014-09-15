#!/bin/bash
UT=`cat /proc/uptime | cut -d" " -f1`
echo "uptime:$UT"
