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


function install_tools () {


    function install_cli() {
        $count = 0;
        $installFinished = $false;
        while (!$installFinished -and $count -lt 5)
        {
            pip install --pre azure-cli --extra-index-url https://azurecliprod.blob.core.windows.net/edge > azurecliinstall.log 2>&1
            if (-not $LASTEXITCODE)
            {
                $installFinished = $true
                echo "CLI installed successfully"
            }
        else
            {
                ${count}++
                echo "Error code from the CLI installation - ${LASTEXITCODE}"
                echo "Could not install CLI.  Trying again (${count} / 5)"
                sleep 5m
            }
        }
        if (!$installFinished)
        {
            echo "Could not install Azure CLI"
            exit 1
        }
        sudo cat /var/lib/waagent/Certificates.pem >> ~/lib/azure-cli/lib/python2.7/site-packages/certifi/cacert.pem
    }

    # Add debugging symbols repos
    echo "deb http://ddebs.ubuntu.com $(lsb_release -cs) main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list.d/ddebs.list
    echo "deb http://ddebs.ubuntu.com $(lsb_release -cs)-updates main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list.d/ddebs.list
    echo "deb http://ddebs.ubuntu.com $(lsb_release -cs)-proposed main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list.d/ddebs.list

    # Add keys
    wget -O - http://ddebs.ubuntu.com/dbgsym-release-key.asc | sudo apt-key add - >> /dev/null

    echo "deb [trusted=yes] https://repo.iovisor.org/apt/xenial xenial-nightly main" | sudo tee /etc/apt/sources.list.d/iovisor.list

    # Update
    sudo apt-get update

    # Install debugging symbols
    sudo apt-get install linux-image-`uname -r`-dbgsym

    # Install perf tools
    sudo apt install -y bmon sysstat linux-tools-`uname -r` perf-tools-unstable bcc-tools libssl-dev libffi-dev python-dev build-essential

    # Install the CLI and certificate
    install_cli

    $SAMPLES=((60 / $INTERVAL))

    # Run cron job every minute.
    sed -i -e "s+^5-55/10+*/1+g" /etc/cron.d/sysstat
    # record data for 60 seconds.
    sed -i -e "s/1 1$/1 $SAMPLES/g" /etc/cron.d/sysstat
    # Enable performance monitoring
    sed -i -e "s/false/true/g" /etc/default/sysstat

    # Restart service
    sudo service sysstat restart
}

function create_timeout_job {
    local $TO = $1
    echo "sed -i -e 's/true/false/g' /etc/default/sysstat; sudo service sysstat restart" | at now + $TO minutes
}

# Install the tools
install_tools

create_timeout_job $TIMEOUT
