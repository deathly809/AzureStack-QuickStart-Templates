#!/bin/bash

############################################################
#
# 	Node setup script
#
#	This will setup hadoop on the node.  This also
#	formats and mounts the data-disk as well.
#


############################################################
#
# 	Enable logging.
#

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' EXIT SIGHUP SIGINT SIGQUIT
exec 1>>/mnt/hadoop_extension.log 2>&1

# Output commands and disable history expansion
set -v +H


############################################################
#
# 	Constants
#
#

# Error code
RET_ERR=0
# What we want to call it locally
HADOOP_FILE_NAME="hadoop.tar.gz"
# Where we mount the data disk
MOUNT="/media/data"
# Get the role of this node
ROLE=`hostname`
# Hadoop Users
USERS=("hdfs" "mapred" "yarn")
# Hadoop home
HADOOP_HOME=/usr/local/hadoop
# Admin USER
ADMIN_USER=`ls /home/`

############################################################
#
#	Variables from input
#
#

# Name of the cluster
CLUSTER_NAME="$1"

# Number of worker nodes
WORKERS="$2"

############################################################
#
# 	Install pre-reqs
#
#
preinstall () {
    # Java Runtime Environment
    sudo apt-get update;
    sudo apt-get install --yes default-jre

    # Setup JAVA
    JAVA_HOME=`readlink -f /usr/bin/java | sed 's:/bin/java::'`
    echo -e "export JAVA_HOME=$JAVA_HOME" >> /etc/profile.d/java.sh
}

############################################################
#
# 	Attach and format the disk, save config to FSTAB
#
#

attach_disks () {

    #
    # Locate the datadisk
    #

    # List all disks.
    DISKS=`lsblk -d | grep "disk" | grep -v "^f"  | awk -F ' ' '{print $1}'`

    # List all partitions.
    PARTS='lsblk | grep part'

    # Get the disk without any partitions.
    DD=`for d in $DISKS; do echo $PARTS | grep -vo $d && echo $d; done`

    #
    # Format/Create partitions
    #
    sudo parted /dev/$DD mklabel gpt
    sudo parted -a opt /dev/$DD mkpart primary ext4 0% 100%

    # write file-system lazily for performance reasons.
    sudo mkfs.ext4 -L datapartition /dev/${DD}1 -F -E lazy_itable_init=1

    # Create mount point
    mkdir $MOUNT -p

    #
    # Add to FSTAB
    #

    # Get the UUID
    UUID=`blkid /dev/${dd}1 -s UUID -o value`
    # Validate not already in FSTAB (Should never happen).
    grep "$UUID" /etc/fstab > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        # Append to the end of FSTAB
        LINE="UUID=\"$UUID\"\t$MOUNT\text4\tnoatime,nodiratime,nodev,noexec,nosuid\t1 2"
        echo -e "$LINE" >> /etc/fstab
    fi

    # mount
    mount $MOUNT
}

############################################################
#
# 	Add users for hadoop
#
#

add_users () {
    # Create hadoop user and group
    addgroup "hadoop"

    FILES=$('.profile' '.bashrc')

    # Create users and keys
    for user in "${USERS[@]}";
    do

        echo -n "Creating user $user"

        # Create user
        useradd -m -G hadoop -s /bin/bash $user
        echo "$user:$password" | chpasswd

        # Location of SSH files
        SSH_DIR=/home/$user/.ssh

        # Create directory
        mkdir -p $SSH_DIR
        touch "$SSH_DIR/authorized_keys"

        # Key name
        KEY_NAME=$SSH_DIR/id_rsa

        # Remove existing (should not be any)
        rm -rf $KEY_NAME

        # Generate key with empty passphrase
        ssh-keygen -t rsa -N "" -f $KEY_NAME

        # Add to my own autorhized keys
        cat "/home/$user/.ssh/id_rsa.pub >> /home/$user/.ssh/authorized_keys"

        # Copy missing files
        for file in ${FILES[@]};
        do
            if [ ! -f "/home/$user/$file" ]; then
                echo "Missing the file $file for user $user"
                cp "/home/$ADMIN_USER/$file" "/home/$user/$file"
            fi
        done

        # Disable key checking
        echo -e "Host *" >> /home/$user/.ssh/config
        echo -e "    StrictHostKeyChecking no" >> /home/$user/.ssh/config

        chown -R $user:$user /home/$user
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
    tar -xvzf $HADOOP_FILE_NAME
    rm $HADOOP_FILE_NAMEstart

    # Move files to /usr/local
    mkdir -p ${HADOOP_HOME}
    mv hadoop-2.9.0/* ${HADOOP_HOME}

    # Copy configuration files
    cp core-site.xml ${HADOOP_HOME}/etc/hadoop/ -f
    cp mapred-site.xml ${HADOOP_HOME}/etc/hadoop/ -f


    # Set environment variable for JAVA_HOME
    sed -i -e "s+\${JAVA_HOME}+'$JAVA_HOME'+g" $HADOOP_HOME/etc/hadoop/hadoop-env.sh

    #
    # Global profile environment variables
    #
    echo -e "export HADOOP_HOME=$HADOOP_HOME"                       >> /etc/profile.d/hadoop.sh
    echo -e 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin'  >> /etc/profile.d/hadoop.sh

    # Hadoop user own hadoop installation
    chown :hadoop -R $HADOOP_HOME

    # Hadoop group can do anything owner can do
    chmod -R g=u $HADOOP_HOME

    # HDFS owns everything on the data disk
    chown hdfs:hadoop -R $MOUNT

}


############################################################
#
# 	Create configuration files and set to startup at boot
#
#

setup_node () {

    setup_master() {

        # Copy startup script to init.d
        cp ${PWD}/hadoop.sh /etc/init.d/hadoop.sh
        chmod 755 /etc/init.d/hadoop.sh

        # create symlink
        sudo ln -s /etc/init.d/hadoop.sh /etc/rc2.d
        sudo mv /etc/rc2.d/hadoop.sh /etc/rc2.d/S70hadoop.sh

        # Create slaves file
        touch $HADOOP_HOME/etc/hadoop/slaves
        for i in `seq 0 $((WORKERS - 1))`;
        do
            echo "${CLUSTER_NAME}Worker${i}" >> $HADOOP_HOME/etc/hadoop/slaves
        done
    }

    if [[ $ROLE =~ Worker ]];
    then
        echo -n "Nothing to do for workers"
    elif [[ $ROLE =~ NameNode ]];
    then
        setup_master

        # format HDFS
        sudo -H -u hdfs bash -c "${HADOOP_HOME}/bin/hdfs namenode format"

    elif [[ $ROLE =~ ResourceManager ]];
    then
        setup_master
    elif [[ $ROLE =~ JobHistory ]];
    then
        setup_master
    else
        echo "ERROR"
        exit 999
    fi
}

############################################################
#
#	Run the functions above.
#
#

# Pre-install all required programs
preinstall

# Attach all data disks
attach_disks

# Add all Hadoop users
add_users

# Install hadoop
install_hadoop

# Setup this node for hadoop
setup_node

echo -e "Success"

exit 0
