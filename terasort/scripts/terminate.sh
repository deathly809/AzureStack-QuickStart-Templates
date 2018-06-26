#!/bin/bash

#
#   Kills all running YARN applications
#

# Attempt to kill application
function kill_terasort() {
    JOBS=`yarn application -list --appstates RUNNING | awk -F"\t" '{print $1}'`

    # Kill them
    for job in $JOBS;
    do
        yarn application -kill -appId $job
    done
}

# write_output

kill_terasort

