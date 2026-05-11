#!/usr/bin/env bash
# =============================================================================
# run_water.sh — Pipeline analyse consommation d'eau (adapté pour YARN)
# =============================================================================
# Structure attendue (tout dans le meme dossier sparkjobs/) :
#   sparkjobs/
#     global_water_consumption.csv
#     water_analysis.py
#     run_water.sh                <- ce fichier
# =============================================================================
# Lancer depuis le dossier sparkjobs/ :
#   cd sparkjobs
#   bash run_water.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}== $* ==${RESET}\n"; }

# Fichiers dans le meme dossier que ce script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_FILE="$SCRIPT_DIR/global_water_consumption.csv"
PYSPARK_SCRIPT="$SCRIPT_DIR/water_analysis.py"

# Verifications
[ -f "$CSV_FILE" ]       || error "global_water_consumption.csv introuvable dans $SCRIPT_DIR"
[ -f "$PYSPARK_SCRIPT" ] || error "water_analysis.py introuvable dans $SCRIPT_DIR"

docker ps --filter "name=^namenode$" --filter "status=running" --format '{{.Names}}' | grep -q "namenode" \
    || error "Container 'namenode' non demarre. Lancez : docker compose up -d"

info "Cluster detecte :"
docker ps --filter "name=namenode\|datanode" --format "  - {{.Names}} : {{.Status}}"

# ETAPE A - Copie du CSV dans namenode
header "ETAPE A - Copie du CSV vers namenode"
docker cp "$CSV_FILE" namenode:/tmp/global_water_consumption.csv
success "Copie -> namenode:/tmp/global_water_consumption.csv"

# ETAPE B - Upload dans HDFS
header "ETAPE B - Upload dans HDFS (/input/)"
docker exec namenode bash -c "hdfs dfs -mkdir -p /input" || true
docker exec namenode bash -c "hdfs dfs -rm -f /input/global_water_consumption.csv || true"
docker exec namenode bash -c "hdfs dfs -put /tmp/global_water_consumption.csv /input/global_water_consumption.csv"
docker exec namenode bash -c "hdfs dfs -ls /input/"
success "Disponible : hdfs://namenode:9000/input/global_water_consumption.csv"

# ETAPE C - spark-submit via YARN
header "ETAPE C - Lancement spark-submit (master : YARN)"
docker cp "$PYSPARK_SCRIPT" namenode:/tmp/water_analysis.py
docker exec namenode bash -c "hdfs dfs -rm -r -f /spark-output/water || true"
docker exec namenode bash -c "hdfs dfs -mkdir -p /spark-output/water"

info "Soumission du job -> suivre sur http://localhost:8088"
echo ""

docker exec namenode bash -c "
    spark-submit \
        --master yarn \
        --deploy-mode client \
        --executor-memory 512m \
        --num-executors 3 \
        --executor-cores 1 \
        --driver-memory 512m \
        --conf spark.hadoop.fs.defaultFS=hdfs://namenode:9000 \
        /tmp/water_analysis.py
"

echo ""
success "Job Spark termine !"

# ETAPE D - Lecture des resultats
header "ETAPE D - Resultats dans HDFS"
docker exec namenode bash -c "hdfs dfs -ls -R /spark-output/water/"
echo ""

docker exec namenode bash -c "
python3 - <<'PYEOF'
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName('ReadWaterResults') \
    .config('spark.hadoop.fs.defaultFS', 'hdfs://namenode:9000') \
    .getOrCreate()
spark.sparkContext.setLogLevel('ERROR')

base = 'hdfs://namenode:9000/spark-output/water'

print('\n' + '='*65)
print('  RESULTATS - ANALYSE 1 : Top 10 pays consommateurs')
print('='*65)
spark.read.parquet(f'{base}/top10_consommateurs.parquet').show(10, truncate=False)

print('\n' + '='*65)
print('  RESULTATS - ANALYSE 2 : Evolution mondiale par annee')
print('='*65)
spark.read.parquet(f'{base}/evolution_annuelle.parquet').orderBy('Year').show(25, truncate=False)

print('\n' + '='*65)
print('  RESULTATS - ANALYSE 3 : Pays a risque hydrique')
print('='*65)
risque = spark.read.parquet(f'{base}/pays_a_risque.parquet')
print(f'  Enregistrements a risque : {risque.count()}')
risque.show(20, truncate=False)

print('\n  Distribution par pays :')
risque.groupBy('Country').count().orderBy('count', ascending=False).show(20, truncate=False)

print('\n  Distribution par annee :')
risque.groupBy('Year').count().orderBy('Year').show(25, truncate=False)

print('\n' + '='*65)
print('  Tous les resultats lus avec succes !')
print('='*65 + '\n')
spark.stop()
PYEOF
"

echo ""
success "Pipeline complet termine !"
echo ""
echo "Interfaces Web :"
echo "  - HDFS NameNode UI     : http://localhost:9870"
echo "  - YARN ResourceManager : http://localhost:8088"
echo "  - Spark History Server : http://localhost:18080"
echo ""