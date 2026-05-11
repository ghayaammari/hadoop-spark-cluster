#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  run_spark.sh — Pipeline complet du job Spark
#  A executer depuis l'interieur du container namenode :
#    docker exec -it namenode bash /mapreduce/wordcount/run_spark.sh
# ─────────────────────────────────────────────────────────────

set -e

echo "=================================================="
echo "  Pipeline Spark — SalesPerCategory"
echo "=================================================="

# ── Etape 1 : Verifier que purchases.txt est dans HDFS ────────
echo ""
echo "Etape 1 — Verification des donnees dans HDFS..."
if hdfs dfs -test -e /user/root/purchases/input/purchases.txt; then
    echo "  purchases.txt deja present dans HDFS."
else
    echo "  Upload de purchases.txt vers HDFS..."
    hdfs dfs -mkdir -p /user/root/purchases/input
    hdfs dfs -put /mapreduce/wordcount/input/purchases.txt \
              /user/root/purchases/input/
    echo "  Upload termine."
fi

# ── Etape 2 : Supprimer l'ancien output si existant ──────────
echo ""
echo "Etape 2 — Nettoyage de l'ancien output Spark..."
hdfs dfs -rm -r -f /user/root/purchases/output_spark
echo "  Nettoye."

# ── Etape 3 : Soumettre le job Spark a YARN ──────────────────
echo ""
echo "Etape 3 — Soumission du job Spark a YARN..."
echo "  (Suivre l'avancement sur http://localhost:8088)"
echo ""

spark-submit \
  --master yarn \
  --deploy-mode client \
  --executor-memory 512m \
  --num-executors 3 \
  --executor-cores 1 \
  /mapreduce/wordcount/sales_spark.py

# ── Etape 4 : Lire les resultats depuis HDFS ─────────────────
echo ""
echo "Etape 4 — Resultats stockes dans HDFS :"
hdfs dfs -ls /user/root/purchases/output_spark/

echo ""
echo "Contenu du fichier resultat :"
hdfs dfs -cat /user/root/purchases/output_spark/part-*.csv 2>/dev/null | head -30

echo ""
echo "=================================================="
echo "  Job Spark termine avec succes !"
echo "  Resultats : hdfs:///user/root/purchases/output_spark/"
echo "  History   : http://localhost:18080"
echo "=================================================="
