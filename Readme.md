# Hadoop + Spark Cluster avec Docker

Cluster Big Data distribué avec **1 NameNode** et **3 DataNodes**, Spark intégré sur YARN.

---

## Architecture

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
│  │Spark    │ │Spark    │ │Spark    │               │
│  │Worker   │ │Worker   │ │Worker   │               │
│  └─────────┘ └─────────┘ └─────────┘               │
└─────────────────────────────────────────────────────┘
```

---

## Technologies utilisées

| Composant | Version | Rôle |
|-----------|---------|------|
| Ubuntu | 22.04 | OS de base des containers |
| Java | OpenJDK 11 | Runtime pour Hadoop et Spark |
| Hadoop | 3.3.6 | HDFS + YARN |
| Spark | 3.5.3 | Moteur de calcul distribué |
| Docker | 20+ | Containerisation |
| Docker Compose | v2 | Orchestration des containers |

---

## Structure du projet

```
hadoop-spark-cluster/
├── Dockerfile                  # Image unique pour tous les noeuds
├── docker-compose.yml          # Définition des 4 containers
├── config/
│   ├── core-site.xml           # Configuration HDFS (adresse du NameNode)
│   ├── hdfs-site.xml           # Réplication HDFS (facteur = 2)
│   ├── mapred-site.xml         # MapReduce sur YARN
│   ├── yarn-site.xml           # Configuration YARN
│   └── workers                 # Liste des DataNodes
└── scripts/
    ├── start-namenode.sh       # Démarre NameNode + ResourceManager
    └── start-datanode.sh       # Démarre DataNode + NodeManager
```

---

## Prérequis

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installé
- Au moins **8 GB de RAM** disponible
- Au moins **20 GB d'espace disque**

Vérifier l'installation :
```bash
docker --version        # 20+
docker compose version  # v2+
```

---

## Installation et démarrage

### 1. Cloner / créer le projet

```bash
mkdir hadoop-spark-cluster
cd hadoop-spark-cluster
# Créer tous les fichiers décrits dans la section Structure
```

### 2. Important — fins de ligne (Windows uniquement)

Sur Windows, les fichiers `.sh` doivent avoir des fins de ligne **LF** (pas CRLF).

Dans VS Code : ouvrir chaque `.sh` → cliquer sur `CRLF` en bas à droite → choisir `LF` → sauvegarder.

### 3. Build et démarrage

```bash
docker compose build    # ~10 min (télécharge Hadoop + Spark)
docker compose up -d    # Démarre les 4 containers
```

### 4. Vérifier que tout tourne

```bash
docker ps
```

Tu dois voir 4 containers avec status `Up` :
- `namenode`
- `datanode1`
- `datanode2`
- `datanode3`

---

## Interfaces Web

| Interface | URL | Description |
|-----------|-----|-------------|
| HDFS NameNode | http://localhost:9870 | État du cluster HDFS, DataNodes connectés |
| YARN Resource Manager | http://localhost:8088 | Jobs en cours, ressources disponibles |
| Spark History Server | http://localhost:18080 | Historique des jobs Spark |
| DataNode 1 | http://localhost:9864 | État du DataNode 1 |
| DataNode 2 | http://localhost:9865 | État du DataNode 2 |
| DataNode 3 | http://localhost:9866 | État du DataNode 3 |

---

## Vérification du cluster

### Entrer dans le NameNode

```bash
docker exec -it namenode bash
```

### Vérifier HDFS

```bash
# Rapport complet du cluster
hdfs dfsadmin -report

# Résultat attendu :
# Live datanodes (3): ...
```

### Vérifier les processus

```bash
jps
# Résultat attendu :
# NameNode
# ResourceManager
```

### Tester HDFS

```bash
# Créer un dossier
hdfs dfs -mkdir -p /user/root

# Créer un fichier de test
echo "Hello Hadoop Spark" > /tmp/test.txt

# Envoyer dans HDFS
hdfs dfs -put /tmp/test.txt /user/root/

# Lire le fichier depuis HDFS
hdfs dfs -cat /user/root/test.txt
```

---

## Lancer un job Spark

### Exemple : calcul de Pi (SparkPi)

Depuis l'intérieur du container namenode :

```bash
spark-submit --master yarn --deploy-mode client --num-executors 2 --executor-memory 512m --class org.apache.spark.examples.SparkPi $SPARK_HOME/examples/jars/spark-examples_*.jar 10
```

Résultat attendu à la fin des logs :
```
Pi is roughly 3.1420391420391423
```


## Comment fonctionne Spark sur YARN

```
spark-submit
     │
     ▼
YARN ResourceManager    ← reçoit la demande de ressources
     │
     ├──► DataNode1 (Spark Executor) ← exécute les tâches
     ├──► DataNode2 (Spark Executor) ← exécute les tâches
     └──► DataNode3 (Spark Executor) ← exécute les tâches
                │
                ▼
           Résultat final
```

Spark utilise YARN comme **gestionnaire de ressources** — il ne gère pas lui-même où s'exécutent les tâches, il délègue ça à YARN qui connaît l'état de chaque noeud.

---

## Commandes utiles

### Gestion des containers

```bash
# Démarrer le cluster
docker compose up -d

# Arrêter le cluster (données conservées)
docker compose down

# Arrêter et supprimer toutes les données
docker compose down -v

# Voir les logs d'un container
docker compose logs namenode
docker compose logs datanode1

# Entrer dans un container
docker exec -it namenode bash
docker exec -it datanode1 bash
```

### Commandes HDFS

```bash
# Lister les fichiers
hdfs dfs -ls /

# Créer un dossier
hdfs dfs -mkdir /monDossier

# Uploader un fichier
hdfs dfs -put fichier.txt /monDossier/

# Télécharger un fichier
hdfs dfs -get /monDossier/fichier.txt .

# Supprimer un fichier
hdfs dfs -rm /monDossier/fichier.txt

# Rapport du cluster
hdfs dfsadmin -report
```

### Commandes YARN

```bash
# Lister les applications en cours
yarn application -list

# Tuer une application
yarn application -kill application_XXXXX
```

---

## Auteur
                            **Ghaya Ammari**
Projet réalisé dans le cadre du cours **Big Data — 2ème année ingénierie**.