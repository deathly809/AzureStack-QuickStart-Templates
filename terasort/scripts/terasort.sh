#!/bin/bash

#
#   The purpose of this script is to run terasort
#
#
#   Need to use sed to replace the following parameters:
#       MAPPERS
#       REDUCERS
#       USER_NAME
#       PASSWORD
#

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

# Remove all at jobs in the queue
for i in `atq | awk '{print $1}'`;do atrm $i;done
