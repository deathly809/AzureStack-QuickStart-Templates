#!/bin/bash

#
#   The purpose of this script is to monitor the status
#   of terasort and when finished upload performance data
#   to blob storage.
#
#   This script does a few things
#
#       1. Registers and logs into Azure Stack
#       2. Checks to see if the RESULTS.txt file exists
#       3. If this file exists we
#           a. Save performance data to a blob
#           b. Remove all cronjobs jobs for this user
#
#
#   Values you need to update:
#
#       ARM_ENDPOINT
#       STORAGE_ENDPOINT
#       TENANT_ID
#       USER_NAME
#       PASSWORD
#       STORAGE_ACCOUNT
#       CONTAINER
#

# Export needed values
export AZURE_STORAGE_ACCOUNT='STORAGE_ACCOUNT'
export AZURE_STORAGE_KEY=`az storage account keys list --output tsv | head -n 1 | awk '{print $3}'`

# Register, hope this does not blow up
az cloud register --name 'Tenant'                               \
                --endpoint-resource-manager 'ARM_ENDPOINT'         \
                --suffix-storage-endpoint 'STORAGE_ENDPOINT'      \
                --profile 2017-03-09-profile

# Set the cloud
az cloud set --name "Tenant"

# Login
az login    -u 'USER_NAME'          \
            -p 'PASSWORD'           \
            --tenant 'TENANT_ID'

# Check to see if done.
az storage blob exists  --container-name 'CONTAINER'     \
                        --name 'RESULT.txt'              \

$RESULT=$?
if [ $RESULT -eq 0 ];
then
    # Copy files to blob
    HOST=`hostname`
    FILE="perf_${HOST}.json"
    sadf -j -P ALL -- -A > $FILE
    az storage blob upload --container-name 'perf' --file $FILE --name $FILE
    crontab -r
fi
