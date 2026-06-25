# 🎮 Prisoner Dilemma — ETL Pipeline

> Pipeline de data engineering autour du dilemme du prisonnier itératif · Python · Ollama · Parquet · BigQuery · dbt

---

## 📌 Présentation

**Prisoner Dilemma ETL** est un pipeline de data engineering complet reproduisant l'expérience d'Axelrod (1981) à l'ère de l'IA.

Il simule un tournoi entre stratégies codées et agents IA locaux, transforme les données brutes via une architecture médaillon **Bronze → Silver → Gold**, et expose des tables analytiques prêtes à l'exploration.

### Pourquoi ce projet ?

| Besoin | Solution |
|--------|----------|
| 🎲 Générer des données originales | Simulation Python + agent IA via Ollama |
| 🗄️ Stocker en format analytique | Parquet → BigQuery |
| 🔄 Transformer et enrichir | dbt Cloud (Silver + Gold) |
| 📊 Analyser les comportements | Tables Gold directement interrogeables |

---

## 🏗️ Architecture

```
simulate.py  (Python + Ollama)
     │
     └─► Parquet Bronze  ──────────────► BigQuery
          data/bronze/                   dataset: prisoners
          tournament_*.parquet           table: tournament_bronze
                                               │
                                        ┌──────▼──────┐
                                        │  dbt Cloud  │
                                        │             │
                                        │   Silver    │
                                        │  (views)    │
                                        │             │
                                        │    Gold     │
                                        │  (tables)   │
                                        └──────┬──────┘
                                               │
                                        BigQuery
                                        dataset: dbt_lbouchet_prisoners
```

### Couches de données

| Couche | Stockage | Contenu |
|--------|----------|---------|
| **Bronze** | Parquet local → BigQuery `prisoners` | Données brutes issues de la simulation |
| **Silver** | BigQuery `dbt_lbouchet_prisoners` | Tours enrichis, colonnes dérivées, nettoyage |
| **Gold** | BigQuery `dbt_lbouchet_prisoners` | Agrégats analytiques prêts à l'emploi |

---

## ✅ Prérequis

- **Python >= 3.10** installé
- **Ollama** installé ([ollama.com/download](https://ollama.com/download))
- **Compte Google Cloud** avec BigQuery activé
- **dbt Cloud** connecté à BigQuery

---

## 🚀 Installation & Démarrage

### 1. Cloner le repo

```bash
git clone https://github.com/<ton-repo>/prisoner-dilemma-etl.git
cd prisoner-dilemma-etl
```

### 2. Installer les dépendances Python

```bash
pip install -r requirements.txt
```

### 3. Installer le modèle Ollama

```powershell
ollama pull llama3.2
```

Vérifier qu'Ollama fonctionne :

```powershell
ollama run llama3.2 "Réponds uniquement par COOPERATE ou DEFECT."
```

Réponse attendue : `COOPERATE` ou `DEFECT`

---

## 🎲 Étape 1 — Générer les données (Bronze)

```powershell
python simulate.py
```

### Stratégies simulées

| Stratégie | Type | Description |
|-----------|------|-------------|
| `always_cooperate` | Codée | Coopère à chaque tour sans exception |
| `always_defect` | Codée | Trahit à chaque tour sans exception |
| `tit_for_tat` | Codée | Copie le dernier choix de l'adversaire |
| `grim_trigger` | Codée | Coopère jusqu'à la première trahison, puis trahit définitivement |
| `random` | Codée | Choix aléatoire à chaque tour |
| `ollama_agent` | IA (Ollama) | Décide en fonction de l'historique via llama3.2 |

### Matchups du tournoi

```
tit_for_tat      vs always_defect
tit_for_tat      vs always_cooperate
grim_trigger     vs random
always_cooperate vs always_defect
ollama_agent     vs tit_for_tat
ollama_agent     vs always_defect
```

Chaque match : **2000 tours** — Matrice de gains :

| Joueur A \ Joueur B | COOPERATE | DEFECT |
|---------------------|-----------|--------|
| **COOPERATE**       | 3 / 3     | 0 / 5  |
| **DEFECT**          | 5 / 0     | 1 / 1  |

### Sortie

Fichier Parquet généré dans `data/bronze/tournament_YYYYMMDD_HHMMSS_<run_id>.parquet`

### Structure du Parquet Bronze

| Colonne | Type | Description |
|---------|------|-------------|
| `run_id` | string | Identifiant unique du run (8 caractères) |
| `tour` | int | Numéro du tour (1 à 2000) |
| `player_a` | string | Stratégie du joueur A |
| `player_b` | string | Stratégie du joueur B |
| `choice_a` | string | `COOPERATE` ou `DEFECT` |
| `choice_b` | string | `COOPERATE` ou `DEFECT` |
| `gain_a` | int | Gain du joueur A ce tour (0, 1, 3 ou 5) |
| `gain_b` | int | Gain du joueur B ce tour (0, 1, 3 ou 5) |
| `cumul_a` | int | Score cumulé du joueur A depuis le début du match |
| `cumul_b` | int | Score cumulé du joueur B depuis le début du match |

> ⚠️ Le match `ollama_agent` est significativement plus lent (~10-15 min pour 2000 tours selon la machine). Ne pas interrompre le script.

---

## 🗄️ Étape 2 — Charger dans BigQuery (Bronze)

### Créer les datasets BigQuery

Dans la [console BigQuery](https://console.cloud.google.com/bigquery), créer deux datasets en région **EU** :

| Dataset | Usage |
|---------|-------|
| `prisoners` | Table brute Bronze |
| `dbt_lbouchet_prisoners` | Modèles Silver et Gold dbt |

### Uploader le Parquet

```
Dataset prisoners
  → Créer une table
  → Source        : Upload → sélectionner le fichier .parquet
  → Format        : Parquet
  → Nom de table  : tournament_bronze
  → Créer
```

---

## 🔄 Étape 3 — Transformations dbt (Silver + Gold)

### Connexion dbt Cloud

Vérifier que la connexion BigQuery dans dbt Cloud pointe vers :

| Paramètre | Valeur |
|-----------|--------|
| Location | `EU` |
| Dataset cible | `dbt_lbouchet_prisoners` |

### Lancer dbt

```bash
dbt run
```

Ou depuis dbt Cloud : **Deploy → Run Now**

### Modèles dbt

```
models/
├── sources.yml                       ← source: prisoners.tournament_bronze
├── models.yml                        ← documentation
├── silver/
│   └── silver_rounds.sql             ← enrichissement + colonnes dérivées
└── gold/
    ├── gold_tournament_summary.sql   ← classement final des stratégies
    ├── gold_matchup_matrix.sql       ← confrontation croisée A vs B
    ├── gold_behavioral_drift.sql     ← évolution coopération par 100 tours
    └── gold_forgiveness_index.sql    ← indice de pardon après trahison
```

### Tables produites dans `dbt_lbouchet_prisoners`

| Table | Type dbt | Description |
|-------|----------|-------------|
| `silver_rounds` | View | Tours enrichis : booléens, exploitation, tranche temporelle |
| `gold_tournament_summary` | Table | Classement final + taux de coopération + ranking |
| `gold_matchup_matrix` | Table | Résultat de chaque confrontation A vs B |
| `gold_behavioral_drift` | Table | Évolution du comportement par tranche de 100 tours |
| `gold_forgiveness_index` | Table | Fréquence de retour à la coopération après trahison |

---

## 📊 Étape 4 — Analyse exploratoire

Les tables Gold sont directement interrogeables dans BigQuery.

### Exemples de requêtes

**Classement final des stratégies :**
```sql
SELECT strategy, total_score, cooperation_rate_pct, ranking
FROM `dbt_lbouchet_prisoners.gold_tournament_summary`
ORDER BY ranking
```

**Résultat d'une confrontation spécifique :**
```sql
SELECT player_a, player_b, final_score_a, final_score_b, match_winner
FROM `dbt_lbouchet_prisoners.gold_matchup_matrix`
WHERE player_a = 'tit_for_tat'
```

**Évolution comportementale de l'agent IA :**
```sql
SELECT tour_bucket, cooperation_rate_pct
FROM `dbt_lbouchet_prisoners.gold_behavioral_drift`
WHERE strategy = 'ollama_agent'
ORDER BY tour_bucket
```

**Quelle stratégie pardonne le plus ?**
```sql
SELECT strategy, forgiveness_index_pct, forgiveness_rank
FROM `dbt_lbouchet_prisoners.gold_forgiveness_index`
ORDER BY forgiveness_rank
```

---

## 🔁 Runs multiples

Chaque exécution de `simulate.py` génère un `run_id` unique. En uploadant plusieurs Parquets dans `tournament_bronze`, tous les runs coexistent dans BigQuery.

**Comparer deux runs :**
```sql
SELECT run_id, strategy, total_score, cooperation_rate_pct
FROM `dbt_lbouchet_prisoners.gold_tournament_summary`
ORDER BY run_id, ranking
```

---

## 📋 Commandes utiles

```bash
# Générer les données
python simulate.py

# Lancer uniquement les modèles Silver
dbt run --select silver

# Lancer uniquement les modèles Gold
dbt run --select gold

# Vérifier la qualité des données
dbt test

# Voir la documentation dbt
dbt docs generate && dbt docs serve
```

---

## 🗂️ Structure du repo

```
prisoner-dilemma-etl/
│
├── simulate.py              # Génération des données + agent Ollama
├── requirements.txt         # pandas, pyarrow, requests
├── README.md
├── .gitignore               # data/bronze/ ignoré
│
├── data/
│   └── bronze/              # Parquets générés (non versionnés)
│
└── models/
    ├── sources.yml
    ├── models.yml
    ├── silver/
    │   └── silver_rounds.sql
    └── gold/
        ├── gold_tournament_summary.sql
        ├── gold_matchup_matrix.sql
        ├── gold_behavioral_drift.sql
        └── gold_forgiveness_index.sql
```

---

## 🛠️ Stack technique

| Technologie | Usage |
|-------------|-------|
| Python 3.10+ | Simulation du tournoi + génération Parquet |
| Ollama (llama3.2) | Agent IA local — décisions de jeu |
| Parquet (pyarrow) | Format de stockage Bronze |
| Google BigQuery | Entrepôt de données (EU) |
| dbt Cloud | Transformations Silver + Gold |

---

*Projet ETL — Ynov M2 DATAE+IA · 2025-2026*