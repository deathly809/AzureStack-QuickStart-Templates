#!/bin/bash

#
#   The purpose of this script is to setup the environment for terasort
#   and then execute it.  This scripts should run on the jumpbox.
#
#   1. Install pre-reqs
#   2. Update terasort code due to bug.
#   3. Start Terasort in background
#   4. Schedule timeout script
#
#

HADOOP_SRC_PREFIX=hadoop-src
HADOOP_FILE_NAME="$HADOOP_SRC_PREFIX.tar.gz"

USER_NAME="${1}"
PASSWORD="${2}"
MAPPERS="${3}"
REDUCERS="${4}"
TIMEOUT="${5}"

export DEBIAN_FRONTEND=noninteractive

function install_prereqs() {
    apt-get update > /dev/null
    apt-get install -y maven openjdk-8-jdk > /dev/null
}

function update_terasort() {

    # Download source
    local RET_ERR=1
    while [[ $RET_ERR -ne 0 ]];
    do
        local HADOOP_URI=`shuf -n 1 sources.txt`
        Log "Downloading from $HADOOP_URI"
        timeout 120 wget --timeout 30 "$HADOOP_URI" -O "$HADOOP_FILE_NAME" > /dev/null
        RET_ERR=$?
    done

    # Extract
    tar -zxf $HADOOP_FILE_NAME  > /dev/null


    # Compile examples
    cd './hadoop-2.9.0-src/hadoop-mapreduce-project/hadoop-mapreduce-examples'

    # Fix known bug
    sed -i -e 's/(short) 10/(short) 1/g' src/main/java/org/apache/hadoop/examples/terasort/TeraInputFormat.java

    # Build!
    mvn package  > /dev/null

    # Replace in share
    cp target/hadoop-mapreduce-examples-2.9.0.jar /usr/local/hadoop/share/hadoop/mapreduce/
}

function run_terasort() {
    # Replace variables
    sed -i -e "s/MAPPERS/$MAPPERS/g" $PWD/terasort.sh
    sed -i -e "s/REDUCERS/$REDUCERS/g" $PWD/terasort.sh
    sed -i -e "s/USER_NAME/$USER_NAME/g" $PWD/terasort.sh
    sed -i -e "s/PASSWORD/$PASSWORD/g" $PWD/terasort.sh
    echo "$PWD/terasort.sh" | at now
}

function create_timeout_job {
    local TO=$1
    echo "$PWD/terminate.sh" | at now + $TO minutes
}

# Install missing things
install_prereqs

# Update terasort code to not be broken
update_terasort

# Create a job which will kill all YARN jobs
create_timeout_job $TIMEOUT

# Run terasort in the background
run_terasort
