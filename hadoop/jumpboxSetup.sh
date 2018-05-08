#!/bin/bash
#
# Jumpbox setup
#
#	This will setup the jumpbox and also configure each hadoop node
#

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' EXIT SIGHUP SIGINT SIGQUIT
exec 1>>hadoop_extension.log 2>&1
# Everything below will go to the file 'hadoop_extension.log':

############################################################
#
# 	Constants
#
#

# Where we mount the data disk
MOUNT="/media/data"
# Get the role of this node
USERS=("hadoop" "hdfs" "mapred" "yarn")
# Name of the machine
HOSTNAME=`hostname`


# Output commands and disable history expansion
set -v +H

############################################################
#
#	Variables from input
#
#

# Name of the cluster
CLUSTER_NAME="$1"

# How many worker nodes
NUMBER_NODES="$2"

# How many worker nodes
PASSWORD="$3"

############################################################
#
# 	Create the list of master and worker nodes in the
#	cluster
#

NODES=("${CLUSTER_NAME}NameNode" "${CLUSTER_NAME}ResourceManager" "${CLUSTER_NAME}JobHistory")
# Add workers
for i in `seq 1 $NUMBER_NODES)`
do
	worker="${CLUSTER_NAME}Worker$i"
	NODES[$((i + 4))]=$worker
done


############################################################
#
# 	Create the list of master and worker nodes in the
#	cluster
#
preinstall () {
	# Install avahi-daemon and Java Runtime Environment
	sudo apt-get update
	sudo apt-get install --yes default-jre sshpass

	# Setup JAVA
	echo -e "JAVA_HOME=$(readlink -f /usr/bin/java | sed 's:/bin/java::')" >> /etc/profile
}


############################################################
#
# 	Copy public keys from all nodes to all other nodes.
#
copy_users () {
    for FROM in $NODES do
        for TO in $NODES do
            for U in $USERS do
                # Copy public key here
                sshpass -p $PASSWORD scp $FROM:/home/$U/.ssh/id_rsa.pub .

                # Add to remove authorized_keys
                cat id_rsa.pub >> sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no $TO 'cat >> /home/$U/.ssh/authorized_keys'

                # Remove public key
                rm -f id_rsa.pub
            done
        done
    done
}

############################################################
#
# 	Restart each node in the Hadoop cluster.  This will
#   cause Hadoop to start on each node.
#
restart_nodes () {
    for N in $NODES do
        sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no $TO 'echo $PASSWORD | sudo -S restart'
    done
}

# Pre-install all required programs
preinstall

# Copy public keys around
copy_users

# Restart all Hadoop nodes
restart_nodes

echo -e "Success"
