from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum, round as spark_round

# ─────────────────────────────────────────────
#  Initialisation de la session Spark
#  master=yarn  →  Spark utilise le cluster YARN
# ─────────────────────────────────────────────
spark = SparkSession.builder \
    .appName("SalesPerCategory_Spark") \
    .config("spark.yarn.historyServer.address", "namenode:18080") \
    .getOrCreate()

print("=" * 55)
print("  Job Spark — Total des ventes par categorie")
print("=" * 55)

# ─────────────────────────────────────────────
#  Lecture de purchases.txt depuis HDFS
#  Format : TSV (Tab-Separated Values)
#  Colonnes :
#    _c0 = date      _c1 = heure   _c2 = ville
#    _c3 = categorie _c4 = montant _c5 = paiement
# ─────────────────────────────────────────────
df = spark.read.csv(
    "hdfs://namenode:9000/user/root/purchases/input/purchases.txt",
    sep="\t",
    header=False,
    inferSchema=True
)

print(f"\nNombre total de lignes lues : {df.count():,}")
print("\nApercu des donnees :")
df.show(5, truncate=False)

# ─────────────────────────────────────────────
#  Transformation : groupBy + sum
#  Equivalent du Mapper + Reducer en MapReduce
#  Mais tout se passe EN MEMOIRE RAM (pas de disque)
# ─────────────────────────────────────────────
result = df.groupBy(col("_c3").alias("categorie")) \
           .agg(
               spark_round(spark_sum(col("_c4").cast("double")), 2)
               .alias("total_ventes")
           ) \
           .orderBy("total_ventes", ascending=False)

# ─────────────────────────────────────────────
#  Affichage des resultats
# ─────────────────────────────────────────────
print("\nResultats — Total des ventes par categorie :")
print("-" * 45)
result.show(50, truncate=False)

# ─────────────────────────────────────────────
#  Sauvegarde dans HDFS
#  Le resultat est ecrit dans output_spark/
# ─────────────────────────────────────────────
output_path = "hdfs://namenode:9000/user/root/purchases/output_spark"

result.write.csv(
    output_path,
    header=True,
    mode="overwrite"
)

print(f"\nResultats sauvegardes dans HDFS : {output_path}")
print("Job Spark termine avec succes.")
print("=" * 55)

spark.stop()
