"""
water_analysis.py — Analyse mondiale de la consommation d'eau
=============================================================
3 analyses PySpark sur global_water_consumption.csv (2000-2024)
Lecture  : HDFS  hdfs://namenode:9000/input/global_water_consumption.csv
Écriture : HDFS  hdfs://namenode:9000/spark-output/water/
"""

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

# ── 0. Session Spark ─────────────────────────────────────────────────────────

spark = (
    SparkSession.builder
    .appName("WaterConsumptionAnalysis")
    # Accès HDFS via le namenode Hadoop du cluster
    .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000")
    .getOrCreate()
)
spark.sparkContext.setLogLevel("WARN")

HDFS_INPUT  = "hdfs://namenode:9000/input/global_water_consumption.csv"
HDFS_OUTPUT = "hdfs://namenode:9000/spark-output/water"

print("\n" + "="*65)
print("  WATER CONSUMPTION ANALYSIS — PySpark")
print("="*65)

# ── 1. Lecture du CSV ────────────────────────────────────────────────────────

df = (
    spark.read
    .option("header", "true")
    .option("inferSchema", "true")
    .csv(HDFS_INPUT)
)

# Renommage court pour éviter les espaces dans les noms de colonnes
df = (
    df
    .withColumnRenamed("Country",                                   "Country")
    .withColumnRenamed("Year",                                      "Year")
    .withColumnRenamed("Total Water Consumption (Billion Cubic Meters)",
                                                                    "TotalConsumption")
    .withColumnRenamed("Per Capita Water Use (Liters per Day)",     "PerCapita")
    .withColumnRenamed("Agricultural Water Use (%)",                "AgriUse")
    .withColumnRenamed("Industrial Water Use (%)",                  "IndustrialUse")
    .withColumnRenamed("Household Water Use (%)",                   "HouseholdUse")
    .withColumnRenamed("Rainfall Impact (Annual Precipitation in mm)",
                                                                    "Rainfall")
    .withColumnRenamed("Groundwater Depletion Rate (%)",            "GroundwaterDepletion")
)

print(f"\n📂 Dataset chargé : {df.count()} lignes × {len(df.columns)} colonnes")
print("   Colonnes :", df.columns)

# ════════════════════════════════════════════════════════════════════════════
# ANALYSE 1 — Top 10 pays consommateurs (moyenne 2000-2024)
# ════════════════════════════════════════════════════════════════════════════

print("\n" + "─"*65)
print("  ANALYSE 1 — Top 10 pays par consommation moyenne (2000-2024)")
print("─"*65)

top10 = (
    df
    .groupBy("Country")
    .agg(
        F.round(F.avg("TotalConsumption"), 3).alias("MoyenneConsommation_BCM"),
        F.count("Year").alias("NombreAnnees")
    )
    .orderBy(F.desc("MoyenneConsommation_BCM"))
    .limit(10)
)

top10.show(10, truncate=False)

top10.write.mode("overwrite").parquet(
    f"{HDFS_OUTPUT}/top10_consommateurs.parquet"
)
print(f"✅ Sauvegardé → {HDFS_OUTPUT}/top10_consommateurs.parquet")

# ════════════════════════════════════════════════════════════════════════════
# ANALYSE 2 — Évolution mondiale par année
# ════════════════════════════════════════════════════════════════════════════

print("\n" + "─"*65)
print("  ANALYSE 2 — Évolution mondiale par année")
print("─"*65)

evolution = (
    df
    .groupBy("Year")
    .agg(
        F.round(F.sum("TotalConsumption"),  2).alias("ConsommationTotale_BCM"),
        F.round(F.avg("PerCapita"),         1).alias("MoyennePerCapita_L_jour"),
        F.count("Country").alias("NombrePays")
    )
    .orderBy("Year")
)

evolution.show(25, truncate=False)

evolution.write.mode("overwrite").parquet(
    f"{HDFS_OUTPUT}/evolution_annuelle.parquet"
)
print(f"✅ Sauvegardé → {HDFS_OUTPUT}/evolution_annuelle.parquet")

# ════════════════════════════════════════════════════════════════════════════
# ANALYSE 3 — Pays à risque hydrique
#   Critères cumulatifs :
#     • GroundwaterDepletion > 3.0 %
#     • AgriUse             > 50  %
#     • Rainfall            < 1000 mm
# ════════════════════════════════════════════════════════════════════════════

print("\n" + "─"*65)
print("  ANALYSE 3 — Pays à risque hydrique (triple critère)")
print("─"*65)

risque = (
    df
    .filter(
        (F.col("GroundwaterDepletion") > 3.0) &
        (F.col("AgriUse")             > 50.0) &
        (F.col("Rainfall")            < 1000.0)
    )
    .select(
        "Country",
        "Year",
        F.round("TotalConsumption",      3).alias("ConsommationTotale_BCM"),
        F.round("GroundwaterDepletion",  2).alias("DepressionNappes_%"),
        F.round("AgriUse",               1).alias("UsageAgricole_%"),
        F.round("Rainfall",              1).alias("Precipitation_mm"),
    )
    .orderBy("Country", "Year")
)

total_risque = risque.count()
print(f"⚠️  {total_risque} enregistrements pays/année identifiés à risque hydrique")
risque.show(20, truncate=False)

risque.write.mode("overwrite").parquet(
    f"{HDFS_OUTPUT}/pays_a_risque.parquet"
)
print(f"✅ Sauvegardé → {HDFS_OUTPUT}/pays_a_risque.parquet")

# ── Résumé final ─────────────────────────────────────────────────────────────

print("\n" + "="*65)
print("  RÉSUMÉ DES SORTIES PARQUET")
print("="*65)
print(f"  • top10_consommateurs.parquet  → 10 lignes")
print(f"  • evolution_annuelle.parquet   → {evolution.count()} lignes (une par année)")
print(f"  • pays_a_risque.parquet        → {total_risque} lignes")
print(f"\n  Répertoire HDFS : {HDFS_OUTPUT}/")
print("="*65 + "\n")

spark.stop()