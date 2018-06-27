#!/bin/bash

#
# This script does the following
#
#   1. Install all needed tools for monitoring and saving results.
#   2. Create a timeout job
#
#

USERNAME="${1}"
PASSWORD="${2}"
POLLING_INTERVAL="${3}"
TIMEOUT="${4}"

export DEBIAN_FRONTEND=noninteractive

function install_tools () {

    # Add debugging symbols repos
    echo "deb http://ddebs.ubuntu.com $(lsb_release -cs) main restricted universe multiverse" | tee -a /etc/apt/sources.list.d/ddebs.list
    echo "deb http://ddebs.ubuntu.com $(lsb_release -cs)-updates main restricted universe multiverse" | tee -a /etc/apt/sources.list.d/ddebs.list
    echo "deb http://ddebs.ubuntu.com $(lsb_release -cs)-proposed main restricted universe multiverse" | tee -a /etc/apt/sources.list.d/ddebs.list

    # Add keys
    wget -O - http://ddebs.ubuntu.com/dbgsym-release-key.asc | apt-key add - >> /dev/null

    echo "deb [trusted=yes] https://repo.iovisor.org/apt/xenial xenial-nightly main" | tee /etc/apt/sources.list.d/iovisor.list

    # Update
    apt-get update

    # Install debugging symbols
    DEBIAN_FRONTEND=noninteractive apt-get install -y linux-image-`uname -r`-dbgsym bmon sysstat linux-tools-`uname -r` perf-tools-unstable bcc-tools libssl-dev libffi-dev python-dev build-essential

    echo "Computing samples"
    SAMPLES=$((60/INTERVAL))
    if [ "$SAMPLES" -eq "0" ];
    then
        SAMPLES=1
    fi

    echo "Updating values"
    # Run cron job every minute.
    sed -i -e "s+^5-55/10+\*/1+g" /etc/cron.d/sysstat
    # record data for 60 seconds.
    sed -i -e "s/1 1$/1 $SAMPLES/g" /etc/cron.d/sysstat
    # Enable performance monitoring
    sed -i -e "s/false/true/g" /etc/default/sysstat

    # Restart service
    echo "Restarting sysstat"
    service sysstat restart
}

function create_timeout_job {
    local TO=$1
    echo "sed -i -e 's/true/false/g' /etc/default/sysstat; sudo service sysstat restart" | at now + $TO minutes
}

# Install the tools
install_tools

create_timeout_job $TIMEOUT
