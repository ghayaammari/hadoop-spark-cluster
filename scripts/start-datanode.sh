#!/bin/bash
service ssh start

# Wait for NameNode to be ready
sleep 10

# Start Hadoop daemons
hdfs datanode &
yarn nodemanager &

# Keep container alive
tail -f $HADOOP_HOME/logs/*.log 2>/dev/null || tail -f /dev/null