#!/bin/bash
mytemp=`ls -l /root >/dev/null 2>&1 | grep manfred`
echo "Exitcode: $?"
