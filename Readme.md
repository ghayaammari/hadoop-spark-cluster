# MapReduce Python Streaming — Total des ventes par catégorie

Job MapReduce écrit en **Python avec Hadoop Streaming** sur un cluster Hadoop + Spark dockerisé.  
Le job analyse le fichier `purchases.txt` (4,1 millions de lignes) et calcule le **total des ventes par catégorie**.

---

## Architecture du cluster

```
┌─────────────────────────────────────────────────────┐
│                Docker Network: hadoop-net            │
│                                                      │
│   ┌─────────────────────────────────────────────┐   │
│   │            NameNode (master)                │   │
│   │   HDFS NameNode · YARN ResourceManager      │   │
│   │   Spark History Server                      │   │
│   │   Ports: 9870 · 8088 · 18080 · 9000         │   │
│   └──────────────┬──────────────────────────────┘   │
│                  │                                   │
│       ┌──────────┼──────────┐                        │
│       ▼          ▼          ▼                        │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐               │
│  │DataNode1│ │DataNode2│ │DataNode3│               │
│  │HDFS DN  │ │HDFS DN  │ │HDFS DN  │               │
│  │YARN NM  │ │YARN NM  │ │YARN NM  │               │
│  └─────────┘ └─────────┘ └─────────┘               │
└─────────────────────────────────────────────────────┘
```

---

## Technologies utilisées

| Composant | Version | Rôle |
|-----------|---------|------|
| Ubuntu | 22.04 | OS de base des containers |
| Java | OpenJDK 11 | Runtime pour Hadoop (requis même pour Python Streaming) |
| Python | 3.x | Écriture du Mapper et Reducer |
| Hadoop | 3.3.6 | HDFS + YARN + Hadoop Streaming |
| Spark | 3.5.3 | Moteur de calcul distribué |
| Docker | 20+ | Containerisation |
| Docker Compose | v2 | Orchestration des containers |

---

## Structure du projet

```
hadoop-spark-cluster/
├── Dockerfile                        # Image unique pour tous les noeuds
├── docker-compose.yml                # Définition des 4 containers
├── config/
│   ├── core-site.xml                 # Configuration HDFS
│   ├── hdfs-site.xml                 # Réplication HDFS (facteur = 2)
│   ├── mapred-site.xml               # MapReduce sur YARN
│   ├── yarn-site.xml                 # Configuration YARN
│   └── workers                       # Liste des DataNodes
├── scripts/
│   ├── start-namenode.sh             # Démarre NameNode + ResourceManager
│   └── start-datanode.sh             # Démarre DataNode + NodeManager
└── mapreduce/wordcount/
    ├── mapper.py                     # Mapper Python : extrait (catégorie, montant)
    ├── reducer.py                    # Reducer Python : somme par catégorie
    ├── run_streaming.sh              # Script : lance le job via Hadoop Streaming
    └── input/
        └── purchases.txt             # Données d'entrée (4,1M lignes)
```

---

## Comment fonctionne Hadoop Streaming

```
Hadoop Streaming
        │
        ├── mapper.py   : lit stdin ligne par ligne → écrit "catégorie\tmontant" sur stdout
        │                 (Hadoop distribue les lignes sur les DataNodes)
        │
        ├── [Sort & Shuffle automatique par Hadoop]
        │
        └── reducer.py  : lit stdin trié → accumule les montants → écrit "catégorie\ttotal"
```

Hadoop Streaming utilise `stdin` / `stdout` comme interface — **aucune compilation nécessaire**.  
Le JAR `hadoop-streaming-*.jar` (inclus dans Hadoop) s'occupe de tout le reste.

---

## Format des données d'entrée

Le fichier `purchases.txt` est un fichier TSV (séparé par tabulations) :

```
date        heure   ville        catégorie           montant   paiement
2012-01-01  09:00   San Jose     Men's Clothing      214.05    Amex
2012-01-01  09:00   Fort Worth   Women's Clothing    153.57    Visa
...
```

Le Mapper lit la **colonne 4** (catégorie) et la **colonne 5** (montant).

---

## Prérequis

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installé
- Au moins **8 GB de RAM** disponible
- Au moins **20 GB d'espace disque**

```bash
docker --version        # 20+
docker compose version  # v2+
```

---

## Installation et démarrage

### 1. Cloner le projet

```bash
git clone <url-du-repo>
cd hadoop-spark-cluster
```

### 2. Important — fins de ligne (Windows uniquement)

Sur Windows, les fichiers `.sh` et `.py` doivent avoir des fins de ligne **LF** (pas CRLF).  
Dans VS Code : ouvrir chaque fichier → cliquer sur `CRLF` en bas à droite → choisir `LF` → sauvegarder.

### 3. Build et démarrage

```bash
docker compose build    # ~10 min (télécharge Hadoop + Spark)
docker compose up -d    # Démarre les 4 containers
```

### 4. Vérifier que tout tourne

```bash
docker ps
# namenode, datanode1, datanode2, datanode3 → status Up
```

Attendre ~15 secondes puis vérifier que le NameNode est actif :

```bash
docker exec -it namenode bash -c "jps"
# Résultat attendu : NameNode + ResourceManager
```

---

## Lancer le job MapReduce Python

```bash
docker exec -it namenode bash
bash /mapreduce/wordcount/run_streaming.sh
```

Le script fait automatiquement :
1. Upload de `purchases.txt` dans HDFS
2. Lancement du job via `hadoop-streaming.jar` avec `mapper.py` et `reducer.py`
3. Affichage des résultats triés par chiffre d'affaires

### Résultat attendu

```
Men's Clothing        1234567.89
Women's Clothing      1198432.10
Consumer Electronics   987654.32
...
```

---

## Tester le pipeline localement (sans Docker)

Tu peux tester le mapper et reducer directement sur ta machine :

```bash
cat purchases.txt | python3 mapper.py | sort | python3 reducer.py
```

---

## Interfaces Web

| Interface | URL | Description |
|-----------|-----|-------------|
| HDFS NameNode | http://localhost:9870 | État du cluster HDFS |
| YARN Resource Manager | http://localhost:8088 | Jobs en cours |
| Spark History Server | http://localhost:18080 | Historique des jobs |


---

## Auteur
**Rihab Gharbi**  
Projet réalisé dans le cadre du cours **Big Data — 2ème année ingénierie**.