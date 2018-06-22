#!/bin/bash

#
#   The purpose of this script is to run terasort and upload results to blob storage.
#
#
#   Need to use sed to replace the following parameters:
#       MAPPERS
#       REDUCERS
#       USER_NAME
#       PASSWORD
#       TENANT_ID
#       CONTAINER
#       ARM_ENDPOINT
#       STORAGE_ENDPOINT
#

# Helper functions
function CloudUpload() {
    az storage blob upload --container-name 'CONTAINER' --file "$1" --name "$1"
}

# Run as
export HADOOP_USER_NAME=hadoop
EXAMPLES='/usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.9.0.jar'

# Hadoop folders
UNSORTED=/home/hadoop/unsorted
SORTED=/home/hadoop/sorted
VALIDATED=/home/hadoop/validated

# Teragen
yarn jar $EXAMPLES -Dmapreduce.job.maps=MAPPERS -Dmapreduce.job.reduces=REDUCERS teragen 10000000000 $UNSORTED > teragen.stdout 2> teragen.stderr

# Terasort
yarn jar $EXAMPLES -Dmapreduce.job.maps=MAPPERS -Dmapreduce.job.reduces=REDUCERS terasort $UNSORTED $SORTED > terasort.stdout 2> terasort.stderr

# Teravalidate
yarn jar $EXAMPLES -Dmapreduce.job.maps=MAPPERS -Dmapreduce.job.reduces=REDUCERS teravalidate $SORTED $VALIDATED > teravalidate.stdout 2> teravalidate.stderr

# Copy to storage share
az cloud register --name Tenant \
        --endpoint-resource-manager 'ARM_ENDPOINT' \
        --suffix-storage-endpoint 'STORAGE_ENDPOINT' \
        --profile 2017-03-09-profile
az login --username 'USER_NAME' --password 'PASSWORD' --tenant 'TENANT_ID'

export AZURE_STORAGE_ACCOUNT='STORAGE_ACCOUNT'
export AZURE_STORAGE_KEY=`az storage account keys list --output tsv | head -n 1 | awk '{print $3}'`

# Upload to the container
CloudUpload teragen.stdout
CloudUpload teragen.stderr

CloudUpload terasort.stdout
CloudUpload terasort.stderr

CloudUpload teravalidate.stdout
CloudUpload teravalidate.stderr

# Notify that we are done
echo "SUCCESS" >> RESULTS.txt
CloudUpload RESULTS.txt

# Remove all at jobs in the queue
for i in `atq | awk '{print $1}'`;do atrm $i;done
