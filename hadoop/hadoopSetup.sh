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
exec 1>>hadoop_extension.log 2>&1

# Output commands and disable history expansion
set -v +H


############################################################
#
# 	Constants
#
#

# Download location of hadoop
HADOOP_URI='http://ftp.wayne.edu/apache/hadoop/common/hadoop-2.9.0/hadoop-2.9.0.tar.gz'
# What we want to call it locally
HADOOP_FILE_NAME="hadoop.tar.gz"
# Where we mount the data disk
MOUNT="/media/data"
# Get the role of this node
ROLE=`hostname`
# Hadoop Users
USERS=("hadoop" "hdfs" "mapred" "yarn")

############################################################
#
#	Variables from input
#
#

# Name of the cluster
CLUSTER_NAME="$1"

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
	echo -e "JAVA_HOME=$(readlink -f /usr/bin/java | sed 's:/bin/java::')" >> /etc/profile
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

	# Create users and keys
	for user in "${USERS[@]}";
	do
		# Create user
        useradd -m $user -G hadoop
        echo "$user:$password" | chpasswd

		# Location of SSH files
		SSH_DIR=/home/$user/.ssh

		# Key name
		KEY_NAME=$SSH_DIR/id_rsa

		# Remove existing (should not be any)
		rm -rf $KEY_NAME

		# Generate key with empty passphrase
		ssh-keygen -t rsa -N "" -f $KEY_NAME
	done
}

############################################################
#
#	Downloads and extracts hadoop into the correct folder
#
#

install_hadoop () {

	# Download
	wget "$HADOOP_URI" -O "$HADOOP_FILE_NAME"
	# Extract
	tar -xvzf $HADOOP_FILE_NAME
	# Remove archive
	rm *.gz
	# Move to /usr/local
	mv hadoop* /usr/local/hadoop

	#
	# Global profile environment variables
	#
	echo -e "export HADOOP_HOME=/usr/local/hadoop" >> /etc/profile
	echo -e "export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin" >> /etc/profile

	# Hadoop user own hadoop installation
	chown hduser:hadoop -R /usr/local/hadoop

    if [[ "$ROLE" =~ "Worker" ]];
    then
        # Create HDFS directories
        mkdir $MOUNT/tmp_fs
        mkdir $MOUNT/tmp_something

        # Hadoop user owns everything on the data disk
	    chown hduser:hadoop -R $MOUNT
    fi
}


############################################################
#
# 	Create configuration files and set to startup at boot
#
#

setup_node () {
	# Format HDFS
	sudo -H -u hadoop bash -c 'hdfs namenode format'

	if [[ $ROLE = "*Worker*" ]];
	then
		echo "Worker"
	elif [[ $ROLE == "*NameNode*" ]];
	then
        echo "NameNode"
	elif [[ $ROLE == "*WebProxy*" ]];
	then
		echo "WebProxy"
	elif [[ $ROLE == "*ResourceManager*" ]];
	then
		echo "Worker"
	elif [[ $ROLE == "*JobHistory*" ]];
	then
		echo "JobHistory"
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


# If a worker node we need to attach the disks
if [[ "$ROLE" =~ "Worker" ]]; then
    # Attach all data disks
    attach_disks
fi

# Add all Hadoop users
add_users

# Install hadoop
install_hadoop

# Setup this node for hadoop
setup_node

echo -e "Success"

exit 0
