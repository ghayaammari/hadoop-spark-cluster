#!/bin/bash
# ============================================================
# run.sh - Compiler et lancer le job MapReduce SalesPerCategory
#
# À exécuter DEPUIS L'INTÉRIEUR du container namenode :
#   docker exec -it namenode bash
#   bash /mapreduce/wordcount/run.sh
# ============================================================

set -e

HDFS_INPUT="/user/root/purchases/input"
HDFS_OUTPUT="/user/root/purchases/output_java"
JAR_NAME="sales.jar"

echo "=========================================="
echo " Job MapReduce - Total ventes par catégorie (Java)"
echo "=========================================="

# ── Étape 1 : Upload purchases.txt dans HDFS ─────────────
echo ""
echo "[1/5] Upload de purchases.txt dans HDFS..."
hdfs dfs -mkdir -p "$HDFS_INPUT"
hdfs dfs -rm -r -f "$HDFS_OUTPUT"
hdfs dfs -put -f /mapreduce/wordcount/input/purchases.txt "$HDFS_INPUT/"
echo "     Fichier uploadé : $HDFS_INPUT/purchases.txt"

# ── Étape 2 : Compiler le code Java ──────────────────────
echo ""
echo "[2/5] Compilation..."
mkdir -p /tmp/sales_classes
javac -encoding UTF-8 -classpath "$(hadoop classpath)" \
      -d /tmp/sales_classes \
      /mapreduce/wordcount/SalesPerCategory.java
echo "     Compilation OK"

# ── Étape 3 : Créer le JAR ───────────────────────────────
echo ""
echo "[3/5] Création du JAR..."
jar -cvf /tmp/$JAR_NAME -C /tmp/sales_classes .
echo "     JAR créé : /tmp/$JAR_NAME"

# ── Étape 4 : Lancer le job MapReduce ────────────────────
echo ""
echo "[4/5] Lancement du job sur YARN..."
hadoop jar /tmp/$JAR_NAME SalesPerCategory "$HDFS_INPUT" "$HDFS_OUTPUT"

# ── Étape 5 : Afficher les résultats ─────────────────────
echo ""
echo "[5/5] Résultats - Top catégories par chiffre d'affaires :"
echo "------------------------------------------"
hdfs dfs -cat "$HDFS_OUTPUT/part-r-00000" | sort -k2 -rn
echo "------------------------------------------"
echo ""
echo "Résultats complets : hdfs dfs -cat $HDFS_OUTPUT/part-r-00000"
echo "=========================================="
echo " Job terminé avec succès !"
echo "=========================================="
