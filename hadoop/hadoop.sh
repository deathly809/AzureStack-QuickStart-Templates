
source /etc/profile.d/hadoop26-env.sh
source /etc/profile.d/jdk.sh
source /etc/init.d/functions
source ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh
source ${HADOOP_HOME}/etc/hadoop/yarn-env.sh

RETVAL=0
PIDFILE="${YARN_PID_DIR}/hadoop-yarn-nodemanager.pid"

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
            /bin/su hdfs ${HADOOP_HOME}/hadoop/bin/start-dfs.sh
            $RETVAL=$?
        ;;
        ResourceManager)
            /bin/su yarn ${HADOOP_HOME}/hadoop/bin/start-yarn.sh
            $RETVAL=$?
        ;;
        MapReduceJobHistory)
            /bin/su mapred $HADOOP_PREFIX/sbin/mr-jobhistory-daemon.sh --config $HADOOP_CONF_DIR start historyserver
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

checkstatus(){
    echo $"$desc $(status -p $PIDFILE)"
    RETVAL=$?
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
    status)
        checkstatus
    ;;
    restart)
        restart
    ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart}"
        exit 1
esac

exit $RETVAL
