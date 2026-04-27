#!/bin/bash
export SPARK_DIST_CLASSPATH=$(hadoop classpath)
service ssh start

# Format HDFS only on first run
if [ ! -d "/opt/hadoop/data/namenode" ]; then
  hdfs namenode -format -force
fi

# Start Hadoop daemons
hdfs namenode &
yarn resourcemanager &

# Start Spark History Server (optional but useful)
$SPARK_HOME/sbin/start-history-server.sh

# Keep container alive
tail -f $HADOOP_HOME/logs/*.log 2>/dev/null || tail -f /dev/null