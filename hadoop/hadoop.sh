#!/bin/bash

### BEGIN INIT INFO
# Provides :    Hadoop
# Required-Start :
# Required-Stop :
# Default-Start :
# Default-Stop :
# Short-Description : ensure Hadoop daemons are started.
### END INIT INFO

set -e

# Load stuff
source /etc/profile

ROLE='UNKNOWN'
HOST=`hostname`

if [[ "$HOST" =~ "NameNode" ]];
then
    ROLE='NameNode'
elif if [[ "$HOST" =~ "ResourceManager" ]];
then
    ROLE='ResourceManager'
elif if [[ "$HOST" =~ "MapReduceJobHistory" ]];
then
    ROLE='MapReduceJobHistory'
else
    echo -n "Invalid Role"
    exit 1
fi

desc="Hadoop ${ROLE} node daemon"

start() {
    echo -n $"Starting $desc: "
    case "$1" in
        NameNode)
            daemon --user hdfs ${HADOOP_HOME}/hadoop/bin/start-dfs.sh
            $RETVAL=$?
        ;;
        ResourceManager)
            daemon --user yarn ${HADOOP_HOME}/hadoop/bin/start-yarn.sh
            $RETVAL=$?
        ;;
        MapReduceJobHistory)
            daemon --user mapred $HADOOP_PREFIX/sbin/mr-jobhistory-daemon.sh --config $HADOOP_CONF_DIR start historyserver
            $RETVAL=$?
        ;;
    esac
    return $RETVAL
}

stop() {
    echo -n $"Stopping $desc: "
    case "$1" in
        NameNode)
            /bin/su hdfs ${HADOOP_HOME}/hadoop/bin/stop-dfs.sh
            $RETVAL=$?
        ;;
        ResourceManager)
            /bin/su yarn ${HADOOP_HOME}/hadoop/bin/stop-yarn.sh
            $RETVAL=$?
        ;;
        MapReduceJobHistory)
            /bin/su mapred $HADOOP_PREFIX/sbin/mr-jobhistory-daemon.sh --config $HADOOP_CONF_DIR stop historyserver
            $RETVAL=$?
        ;;
    esac
    return $RETVAL
}

restart() {
    stop
    start
}

case "$1" in
    start)
        start
    ;;
    stop)
        stop
    ;;
    restart)
        restart
    ;;
    *)
        echo $"Usage: $0 {start|stop|restart}"
        exit 1
esac

exit $RETVAL
