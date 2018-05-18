#!/bin/bash
#
# Jumpbox setup
#
#	This will setup the jumpbox and also configure each hadoop node
#

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' EXIT SIGHUP SIGINT SIGQUIT
exec 1>> /mnt/hadoop_extension.log 2>&1
# Everything below will go to the file 'hadoop_extension.log':

############################################################
#
# 	Constants
#
#
# Hadoop Home Location
HADOOP_HOME=/usr/local/hadoop
# Local hadoop archive
HADOOP_FILE_NAME="hadoop.tar.gz"
# Get the role of this node
USERS=("hdfs" "mapred" "yarn")
# Name of the machine
HOSTNAME=`hostname`
# Default hadoop user
HADOOP_USER="hadoop"

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
ADMIN_USER="$3"

# How many worker nodes
ADMIN_PASSWORD="$4"

############################################################
#
# 	Create the list of master and worker nodes in the
#	cluster
#

NODES=("${CLUSTER_NAME}NameNode" "${CLUSTER_NAME}ResourceManager" "${CLUSTER_NAME}JobHistory")
# Add workers
for i in `seq 0 $((NUMBER_NODES - 1))`;
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

add_hadoop_user () {
    echo -n "Creating user $HADOOP_USER"

    addgroup "hadoop"

    # Create user
    useradd -m -G hadoop -s /bin/bash $HADOOP_USER

    # Location of SSH files
    SSH_DIR=/home/$HADOOP_USER/.ssh

    # Create directory
    mkdir -p $SSH_DIR

    # Key name
    KEY_NAME=$SSH_DIR/id_rsa

    # Remove existing (should not be any)
    rm -rf $KEY_NAME

    # Generate key with empty passphrase
    ssh-keygen -t rsa -N "" -f $KEY_NAME

    # Add to my own authorized keys
    cat $SSH_DIR/id_rsa.pub >> $SSH_DIR/authorized_keys

    # Copy missing files
    for file in ${FILES[@]};
    do
        if [ ! -f "/home/$HADOOP_USER/$file" ]; then
            echo "Missing the file $file for user $HADOOP_USER"
            cp "/home/$ADMIN_USER/$file" "/home/$HADOOP_USER/$file"
        fi
    done

    # Disable key checking
    echo -e "Host *" >> /home/$HADOOP_USER/.ssh/config
    echo -e "    StrictHostKeyChecking no" >> /home/$HADOOP_USER/.ssh/config

    chown -R $HADOOP_USER:$HADOOP_USER /home/$HADOOP_USER
}


############################################################
#
# 	Copy public keys from all nodes to all other nodes.
#
copy_users () {
    for FROM in ${NODES[@]}; do
        for TO in ${NODES[@]}; do
            for U in ${USERS[@]}; do

                echo -e "$FROM -> $TO for $U"

                echo -e "Copy locally"
                sshpass -p $ADMIN_PASSWORD scp -o StrictHostKeyChecking=no $ADMIN_USER@$FROM:/home/$U/.ssh/id_rsa.pub .

                echo -e "Add to remote authorized_keys on host $TO for user $U"
                cat id_rsa.pub | sshpass -p $ADMIN_PASSWORD ssh -o StrictHostKeyChecking=no $ADMIN_USER@$TO "sudo tee -a /home/$U/.ssh/authorized_keys"

                echo -e "Remove local copy"
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
    REBOOT_CMD='nohup sh -c "sleep 1 && sudo reboot" > /dev/null 2&>1 &'
    for N in ${NODES[@]}; do
        echo "Restarting node $N"
        sshpass -p $ADMIN_PASSWORD ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 $ADMIN_USER@$N $REBOOT_CMD
    done
}


############################################################
#
#	Downloads and extracts hadoop into the correct folder
#
#

install_hadoop () {

    # Download Hadoop from a random source
    RET_ERR=1
    while [[ $RET_ERR -ne 0 ]];
    do
        HADOOP_URI=`shuf -n 1 sources.txt`
        echo -n "Downloading from $HADOOP_URI"
        timeout 120 wget --timeout 30 "$HADOOP_URI" -O "$HADOOP_FILE_NAME"
        RET_ERR=$?
    done

    # Extract
    tar -xvzf $HADOOP_FILE_NAME > /dev/null
    rm $HADOOP_FILE_NAME

    # Move files to /usr/local
    mkdir -p ${HADOOP_HOME}
    mv hadoop-2.9.0/* ${HADOOP_HOME}

    # Create log directory
    mkdir ${HADOOP_HOME}/logs

    # Setup permissions
    chmod 664 *.xml
    chown $ADMIN_USER *.xml

    # Copy configuration files
    cp *.xml ${HADOOP_HOME}/etc/hadoop/ -f


    # Update hadoop configuration
    sed -i -e "s+CLUSTER_NAME+$CLUSTER_NAME+g" $HADOOP_HOME/etc/hadoop/core-site.xml
    sed -i -e "s+CLUSTER_NAME+$CLUSTER_NAME+g" $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    sed -i -e "s+CLUSTER_NAME+$CLUSTER_NAME+g" $HADOOP_HOME/etc/hadoop/yarn-site.xml
    sed -i -e "s+\${JAVA_HOME}+'$JAVA_HOME'+g" $HADOOP_HOME/etc/hadoop/hadoop-env.sh

    #
    # Global profile environment variables
    #
    echo -e "export HADOOP_HOME=$HADOOP_HOME"                       >> /etc/profile.d/hadoop.sh
    echo -e 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin'  >> /etc/profile.d/hadoop.sh

    # Hadoop group owns hadoop installation
    chown $ADMIN_USER:hadoop -R $HADOOP_HOME

    # Hadoop group can do anything owner can do
    chmod -R g=u $HADOOP_HOME
}


# Pre-install all required programs
preinstall

# Add the hadoop user so we can submit jobs from here
add_hadoop_user

# Copy public keys around
copy_users

# Restart all Hadoop nodes
restart_nodes

# install hadoop.
install_hadoop

# install GUI
nohup bash -c 'sudo apt-get install --yes lubuntu-desktop && sudo reboot' &

echo -e "Success"
exit 0
