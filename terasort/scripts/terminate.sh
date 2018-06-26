#!/bin/bash

#
#       USER_NAME
#       PASSWORD
#       TENANT_ID
#       CONTAINER
#       ARM_ENDPOINT
#       STORAGE_ENDPOINT
#
#

# Write output before we attempt to shutdown since it might throw error
function write_output() {
    echo "FAILED" >> RESULTS.txt

    az cloud register --name Tenant \
        --endpoint-resource-manager 'ARM_ENDPOINT' \
        --suffix-storage-endpoint 'STORAGE_ENDPOINT' \
        --profile 2017-03-09-profile

    az login --username 'USER_NAME' --password 'PASSWORD' --tenant 'TENANT_ID'

    export AZURE_STORAGE_ACCOUNT='STORAGE_ACCOUNT'
    export AZURE_STORAGE_KEY=`az storage account keys list --output tsv | head -n 1 | awk '{print $3}'`

    az storage blob upload --container-name 'CONTAINER' --file "RESULTS.txt" --name "RESULTS.txt"
}

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

