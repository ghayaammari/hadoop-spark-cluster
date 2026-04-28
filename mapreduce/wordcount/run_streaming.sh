#!/bin/bash
# ============================================================
# run_streaming.sh - SalesPerCategory avec Hadoop Streaming (Python)
#
# À exécuter depuis le container namenode.
# ============================================================

set -e

HDFS_INPUT="/user/root/purchases/input"
HDFS_OUTPUT="/user/root/purchases/output_python"
STREAMING_JAR=$(ls $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar)
MAPPER="/mapreduce/wordcount/mapper.py"
REDUCER="/mapreduce/wordcount/reducer.py"

echo "=========================================="
echo " Job MapReduce Streaming (Python)"
echo " Total ventes par catégorie"
echo "=========================================="

echo "[1/3] Préparation HDFS..."
hdfs dfs -mkdir -p "$HDFS_INPUT"
hdfs dfs -rm -r -f "$HDFS_OUTPUT"
hdfs dfs -put -f /mapreduce/wordcount/input/purchases.txt "$HDFS_INPUT/"

echo "[2/3] Lancement du job Streaming..."
hadoop jar $STREAMING_JAR \
    -mapper "python3 $MAPPER" \
    -reducer "python3 $REDUCER" \
    -input "$HDFS_INPUT" \
    -output "$HDFS_OUTPUT" \
    -file "$MAPPER" \
    -file "$REDUCER"

echo "[3/3] Résultats - Top catégories :"
echo "------------------------------------------"
hdfs dfs -cat "$HDFS_OUTPUT/part-00000" | sort -k2 -rn
echo "------------------------------------------"
echo "=========================================="
