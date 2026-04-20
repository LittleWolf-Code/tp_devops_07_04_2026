# Rapport — TP Cloud Computing / DevOps
**Infrastructure Haute Disponibilité sur AWS avec Terraform**

---

## Table des matières

1. [Présentation du projet](#1-présentation-du-projet)
2. [Architecture globale](#2-architecture-globale)
3. [Structure du projet](#3-structure-du-projet)
4. [Modules Terraform](#4-modules-terraform)
5. [Choix des services AWS et comparaisons](#5-choix-des-services-aws-et-comparaisons)
6. [Déploiement et résultats](#6-déploiement-et-résultats)
7. [Bonnes pratiques appliquées](#7-bonnes-pratiques-appliquées)
8. [Limites et améliorations possibles](#8-limites-et-améliorations-possibles)

---

## 1. Présentation du projet

Ce projet consiste à déployer une application web PHP hautement disponible sur AWS en utilisant **Terraform** comme outil d'Infrastructure as Code (IaC).

L'application est un blog permettant de créer et lire des articles, avec une fonctionnalité de transcription audio via **AWS Transcribe**. Elle s'appuie sur une base de données **MariaDB** gérée par RDS et est distribuée sur plusieurs instances EC2 derrière un **Application Load Balancer**.

**Objectifs :**
- Haute disponibilité (multi-AZ)
- Scalabilité automatique (Auto Scaling Group)
- Infrastructure reproductible et modulaire (Terraform)
- Séparation réseau public/privé (VPC)

---

## 2. Architecture globale

![Infrastructure Schema](./imgs/infrastructure-schema.jpg)

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────┐
│                   VPC (10.0.0.0/16)              │
│                                                   │
│  ┌──────────────┐        ┌──────────────┐        │
│  │ Public AZ-1a │        │ Public AZ-1b │        │
│  │ 10.0.1.0/24  │        │ 10.0.2.0/24  │        │
│  │    [ALB]     │        │    [ALB]     │        │
│  │  [NAT GW]    │        │              │        │
│  └──────┬───────┘        └──────┬───────┘        │
│         │                       │                 │
│  ┌──────▼───────┐        ┌──────▼───────┐        │
│  │ Private AZ-1a│        │ Private AZ-1b│        │
│  │ 10.0.3.0/24  │        │ 10.0.4.0/24  │        │
│  │   [EC2 ASG]  │        │   [EC2 ASG]  │        │
│  │   [RDS Pri]  │        │   [RDS Sec]  │        │
│  └──────────────┘        └──────────────┘        │
└─────────────────────────────────────────────────┘
         │                        │
         └──────────┬─────────────┘
                    ▼
              [S3 Buckets]
         (sources app + audio)
```

**Flux de déploiement :**
1. Les fichiers PHP sont uploadés dans un bucket **S3**
2. Lors du lancement d'une instance EC2, le `user_data` télécharge les sources depuis S3
3. La configuration BDD est injectée dynamiquement via `sed`
4. L'**ALB** distribue le trafic entre les instances EC2 dans les subnets privés
5. Les instances accèdent à **RDS** via le réseau privé uniquement
6. **CloudWatch** surveille la CPU et déclenche le scaling automatique

---

## 3. Structure du projet

```
tp_devops_07_04_2026/
├── modules/
│   ├── alb_asg/                  # Load Balancer + Auto Scaling Group
│   │   ├── main.tf
│   │   ├── vars.tf
│   │   └── outputs.tf
│   ├── cloudwatch_cpu_alarms/    # Alarmes CPU + politiques de scaling
│   │   ├── main.tf
│   │   └── vars.tf
│   ├── ec2_role_allow_s3/        # IAM role pour accès S3 depuis EC2
│   │   ├── main.tf
│   │   ├── vars.tf
│   │   └── outputs.tf
│   ├── rds/                      # Base de données MariaDB
│   │   ├── main.tf
│   │   ├── vars.tf
│   │   └── outputs.tf
│   ├── s3/                       # Bucket sources application
│   │   ├── main.tf
│   │   ├── vars.tf
│   │   └── outputs.tf
│   ├── transcribe/               # Bucket audio AWS Transcribe
│   │   ├── main.tf
│   │   ├── vars.tf
│   │   └── outputs.tf
│   └── vpc/                      # Réseau VPC multi-AZ
│       ├── main.tf
│       ├── vars.tf
│       └── outputs.tf
├── src/                          # Sources de l'application PHP
│   ├── index.php
│   ├── db-config.php
│   ├── validation.php
│   ├── transcribe.php
│   └── articles.sql
├── keys/                         # Clés SSH (exclues du git)
├── image/                        # Captures d'écran
├── main.tf                       # Module racine
├── vars.tf                       # Variables globales
├── outputs.tf                    # Sorties (ALB DNS, RDS endpoint...)
└── .gitignore
```

Chaque module possède ses propres fichiers `main.tf`, `vars.tf` et `outputs.tf`, ce qui respecte les conventions Terraform et facilite la réutilisabilité.

---

## 4. Modules Terraform

### 4.1 Module `vpc`

**Rôle :** Crée l'ensemble du réseau isolé de l'infrastructure.

**Ressources créées :**

| Ressource | Description |
|---|---|
| `aws_vpc` | VPC principal (CIDR `10.0.0.0/16`) |
| `aws_subnet` × 4 | 2 subnets publics + 2 privés sur 2 AZ |
| `aws_internet_gateway` | Accès internet pour les subnets publics |
| `aws_eip` | IP statique pour le NAT Gateway |
| `aws_nat_gateway` | Accès internet sortant pour les subnets privés |
| `aws_route_table` × 2 | Tables de routage public/privé |

![Capture VPC](./image/capture%20vpc.png)
*VPC `tp-vpc` créé avec le CIDR `10.0.0.0/16`, distinct du VPC par défaut AWS (`172.31.0.0/16`)*

**Outputs exposés :** `vpc_id`, `public_subnet_1_id`, `public_subnet_2_id`, `private_subnet_1_id`, `private_subnet_2_id`

---

### 4.2 Module `s3`

**Rôle :** Héberge les fichiers sources de l'application pour le bootstrap des instances EC2.

**Ressources créées :**

| Ressource | Description |
|---|---|
| `aws_s3_bucket` | Bucket privé avec `force_destroy = true` |
| `aws_s3_object` × 5 | index.php, db-config.php, validation.php, transcribe.php, articles.sql |

L'utilisation de l'attribut `etag = filemd5(...)` permet à Terraform de détecter automatiquement les modifications de fichiers et de les re-uploader lors d'un `apply`.

![Capture S3](./image/s3%20capture.png)
*Les 2 buckets S3 créés : `tp-devops-app-sources-2026` (sources PHP) et `tp-devops-transcribe-audio-2026` (fichiers audio)*

---

### 4.3 Module `ec2_role_allow_s3`

**Rôle :** Fournit le profil IAM permettant aux instances EC2 d'accéder à S3.

> **Note AWS Academy :** Dans l'environnement Learner Lab, la création de rôles IAM est restreinte. Ce module utilise des `data sources` pour référencer les ressources pré-existantes `LabRole` et `LabInstanceProfile` fournis par AWS Academy.

```hcl
data "aws_iam_role" "lab_role" {
  name = var.role_name  # "LabRole"
}
data "aws_iam_instance_profile" "lab_profile" {
  name = var.instance_profile_name  # "LabInstanceProfile"
}
```

Dans un compte AWS classique, ce module créerait le rôle avec une politique `AmazonS3FullAccess`.

---

### 4.4 Module `rds`

**Rôle :** Déploie la base de données relationnelle MariaDB.

**Ressources créées :**

| Ressource | Description |
|---|---|
| `aws_security_group` | Autorise uniquement le port 3306 depuis le SG de l'ASG |
| `aws_db_subnet_group` | Groupe de subnets privés pour le placement RDS |
| `aws_db_instance` | Instance MariaDB 10.6, db.t3.micro, Multi-AZ |

**Paramètres clés :**
```hcl
engine            = "mariadb"
engine_version    = "10.6"
instance_class    = "db.t3.micro"
allocated_storage = 20
multi_az          = true
```

Le mot de passe est déclaré `sensitive = true` pour éviter son affichage dans les logs Terraform.

---

### 4.5 Module `alb_asg`

**Rôle :** Crée le load balancer et le groupe d'instances auto-scalantes.

**Ressources créées :**

| Ressource | Description |
|---|---|
| `aws_security_group` × 2 | SG ALB (port 80 public) + SG ASG (port 80 depuis ALB, port 22) |
| `aws_lb_target_group` | Cible HTTP/80 avec health check sur `/index.php` |
| `aws_lb` | Application Load Balancer public |
| `aws_lb_listener` | Listener HTTP/80 → forward vers target group |
| `aws_key_pair` | Clé SSH chargée depuis `./keys/terraform.pub` |
| `aws_launch_configuration` | Template AMI + type + profil IAM + user_data |
| `aws_autoscaling_group` | Min: 2, Desired: 2, Max: 4 instances |

![Capture EC2](./image/capture%20E2C.png)
*2 instances `tp-web-instance` en cours d'exécution sur des zones de disponibilité différentes (`us-east-1a` et `us-east-1b`), toutes les deux en type `t2.micro`*

Le `user_data` réalise le bootstrap complet des instances :
- Installation d'Apache, PHP 7.4, extensions MariaDB
- Téléchargement des sources depuis S3
- Configuration dynamique de la connexion BDD via `sed`
- Initialisation du schéma SQL

---

### 4.6 Module `cloudwatch_cpu_alarms`

**Rôle :** Surveille l'utilisation CPU et déclenche le scaling automatique.

**Ressources créées :**

| Ressource | Seuil | Action |
|---|---|---|
| `aws_autoscaling_policy` scale_up | — | +1 instance |
| `aws_autoscaling_policy` scale_down | — | -1 instance |
| `aws_cloudwatch_metric_alarm` high_cpu | CPU ≥ 80% pendant 4 min | Scale up |
| `aws_cloudwatch_metric_alarm` low_cpu | CPU ≤ 20% pendant 4 min | Scale down |

Chaque alarme évalue 2 périodes de 2 minutes avant de déclencher l'action, évitant les réactions sur des pics transitoires.

---

### 4.7 Module `transcribe`

**Rôle :** Crée le bucket S3 dédié aux fichiers audio pour AWS Transcribe.

Ce module est volontairement simple : il isole le bucket audio du bucket sources pour respecter le principe de séparation des responsabilités.

---

## 5. Choix des services AWS et comparaisons

### 5.1 Réseau — Amazon VPC

**Choix :** VPC custom avec subnets publics/privés sur 2 AZ

| Critère | VPC custom | VPC par défaut |
|---|---|---|
| Isolation réseau | Totale | Partielle |
| Subnets privés | Oui | Non (tout public) |
| Adapté à la production | Oui | Non |
| Complexité | Moyenne | Faible |

**Justification :** Les instances EC2 et RDS sont placées dans des subnets privés, inaccessibles directement depuis internet. Seul l'ALB est exposé publiquement. C'est l'architecture recommandée pour toute application en production.

**Chez d'autres providers :**
- **Azure** : Virtual Network (VNet) avec subnets et Network Security Groups
- **GCP** : VPC avec subnets régionaux et Cloud NAT

---

### 5.2 Compute — EC2 + Auto Scaling Group

**Choix :** EC2 `t2.micro` dans un ASG (min: 2, max: 4)

| Critère | EC2 + ASG | AWS ECS (Fargate) | AWS Lambda |
|---|---|---|---|
| Contrôle OS | Total | Partiel | Aucun |
| Scaling auto | Oui (ASG) | Oui (natif) | Oui (natif) |
| Adapté à PHP monolithique | Oui | Possible | Non |
| Coût idle | Fixe | Fixe (tâches) | Quasi nul |
| Complexité | Moyenne | Faible | Faible |

**Justification :** L'application PHP est une application web classique avec serveur Apache. EC2 est le choix naturel. L'ASG garantit la disponibilité (min: 2 instances) et l'élasticité sous charge.

**Chez d'autres providers :**
- **Azure** : Virtual Machine Scale Sets (VMSS)
- **GCP** : Managed Instance Groups (MIG)

---

### 5.3 Load Balancing — Application Load Balancer (ALB)

**Choix :** ALB sur les subnets publics, forwarding HTTP/80

| Critère | ALB | Network Load Balancer | Classic Load Balancer |
|---|---|---|---|
| Niveau OSI | 7 (HTTP) | 4 (TCP) | 4 et 7 |
| Routing par path/host | Oui | Non | Non |
| Health check HTTP | Oui | Basique | Basique |
| Adapté à PHP/HTTP | Oui | Overkill | Déprécié |

**Justification :** L'ALB est le choix adapté pour une application HTTP. Il permet des health checks sur `/index.php` et le routing intelligent.

**Chez d'autres providers :**
- **Azure** : Azure Application Gateway
- **GCP** : Cloud Load Balancing (HTTP(S))

---

### 5.4 Base de données — Amazon RDS MariaDB

**Choix :** RDS MariaDB 10.6 sur `db.t3.micro`, Multi-AZ

| Critère | RDS MariaDB | RDS MySQL | Aurora MySQL | EC2 + MariaDB |
|---|---|---|---|---|
| Gestion automatique | Oui | Oui | Oui | Non |
| Multi-AZ natif | Oui | Oui | Oui (clusters) | Non |
| Compatibilité MySQL | Totale | Native | Quasi-totale | Native |
| Coût | Faible | Faible | 2-3× plus élevé | Très faible |

**Justification :** MariaDB est 100% compatible MySQL, open-source et légèrement plus performant sur certaines charges. RDS prend en charge les sauvegardes automatiques, le patching et le failover Multi-AZ.

**Chez d'autres providers :**
- **Azure** : Azure Database for MariaDB / MySQL
- **GCP** : Cloud SQL (MySQL/PostgreSQL)

---

### 5.5 Stockage objet — Amazon S3

**Choix :** 2 buckets S3 (sources app + fichiers audio)

| Critère | S3 | EFS (NFS) | EBS |
|---|---|---|---|
| Accès multi-instances | Oui (HTTP/API) | Oui (montage NFS) | Non (1 instance) |
| Coût stockage (GB/mois) | ~$0.023 | ~$0.30 | ~$0.10 |
| Adapté aux fichiers statiques | Oui | Possible | Non |
| Durabilité | 99.999999999% | Haute | Haute |

**Justification :** S3 est idéal pour distribuer des fichiers statiques (PHP, SQL) à plusieurs instances lors du bootstrap. Le coût est quasi nul pour de petits fichiers.

**Chez d'autres providers :**
- **Azure** : Azure Blob Storage
- **GCP** : Google Cloud Storage

---

### 5.6 Monitoring — Amazon CloudWatch

**Choix :** Alarmes CloudWatch sur la métrique `CPUUtilization`

| Critère | CloudWatch | Datadog | Prometheus + Grafana |
|---|---|---|---|
| Intégration AWS native | Totale | Via agent | Via exporters |
| Déclenchement ASG | Natif | Via API | Via adaptateur |
| Coût | Inclus (métriques de base) | Payant | Open-source |

**Justification :** CloudWatch est intégré nativement à l'ASG et permet de déclencher des politiques de scaling sans infrastructure supplémentaire.

---

### 5.7 Transcription — AWS Transcribe (bonus)

**Choix :** AWS Transcribe pour la transcription audio-texte

| Critère | AWS Transcribe | Google Speech-to-Text | Azure Cognitive Speech |
|---|---|---|---|
| Intégration AWS | Native | Via API externe | Via API externe |
| Langues supportées | 100+ | 125+ | 100+ |
| Facturation | Par minute audio | Par 15 secondes | Par heure |

**Justification :** AWS Transcribe s'intègre naturellement avec S3 : les fichiers audio sont déposés dans un bucket, les résultats récupérés via l'API. Aucune infrastructure supplémentaire n'est nécessaire.

---

## 6. Déploiement et résultats

### 6.1 Prérequis

- Terraform (`terraform.exe` inclus dans le projet)
- AWS Academy Learner Lab démarré (voyant vert)
- PowerShell

### 6.2 Étapes de déploiement

**1. Configurer les credentials AWS Academy**
```powershell
# Éditer set-credentials.ps1 avec les valeurs depuis AWS Academy > AWS Details > Show
. .\set-credentials.ps1
```

**2. Générer la clé SSH**
```powershell
ssh-keygen -t rsa -b 2048 -f ./keys/terraform -N '""'
```

**3. Créer le fichier de variables**
```hcl
# terraform.tfvars (exclu du git)
db_password = "VotreMotDePasse!"
```

**4. Initialiser et déployer**
```powershell
.\terraform.exe init
.\terraform.exe plan
.\terraform.exe apply
```

**5. Résultat du déploiement**

```
Apply complete! Resources: 36 added, 0 changed, 0 destroyed.

Outputs:
alb_dns_name           = "tp-app-alb-520671347.us-east-1.elb.amazonaws.com"
rds_endpoint           = "tp-mariadb.cjuqu0gyquku.us-east-1.rds.amazonaws.com"
transcribe_bucket_name = "tp-devops-transcribe-audio-2026"
```

### 6.3 Infrastructure déployée

**VPC et réseau**

![Capture VPC](./image/capture%20vpc.png)
*VPC `tp-vpc` (10.0.0.0/16) créé et disponible en `us-east-1`*

**Instances EC2**

![Capture EC2](./image/capture%20E2C.png)
*2 instances `tp-web-instance` actives dans deux zones de disponibilité différentes (`us-east-1a` et `us-east-1b`), garantissant la haute disponibilité*

**Buckets S3**

![Capture S3](./image/s3%20capture.png)
*2 buckets créés : `tp-devops-app-sources-2026` héberge les fichiers PHP, `tp-devops-transcribe-audio-2026` reçoit les fichiers audio*

### 6.4 Application en fonctionnement

**Page principale — Blog**

![Capture page index](./image/capture%20de%20la%20page%20index.png)
*Application accessible via l'ALB. Le hostname `ip-10-0-3-151.ec2.internal` confirme que l'instance est bien dans le subnet privé `10.0.3.0/24` (AZ `us-east-1a`)*

**Page Transcribe**

![Capture page transcribe](./image/capture%20page%20transcribe.png)
*Page de transcription audio accessible sur `ip-10-0-4-149.ec2.internal` — une instance différente dans le subnet `10.0.4.0/24` (AZ `us-east-1b`), ce qui prouve que l'**ALB distribue bien le trafic** entre les deux zones*

### 6.5 Nettoyage

```powershell
.\terraform.exe destroy
```

> A effectuer **avant** de terminer la session AWS Academy pour éviter toute consommation de crédits inutile.

---

## 7. Bonnes pratiques appliquées

### Infrastructure as Code
- **Modularisation** : 7 modules indépendants avec leurs propres `vars.tf` et `outputs.tf`
- **Variables** : Toutes les valeurs configurables sont paramétrées, pas de hardcoding
- **Outputs** : Les valeurs utiles (DNS ALB, endpoint RDS) sont exposées comme outputs
- **Sensibilité** : Le mot de passe BDD est marqué `sensitive = true`

### Sécurité réseau
- EC2 et RDS dans des **subnets privés** — non exposés à internet
- **Security Groups** restrictifs : RDS n'accepte que le port 3306 depuis le SG de l'ASG
- Le SSH est configurable via la variable `ssh_allowed_cidr`

### Haute disponibilité
- **Multi-AZ** : Subnets sur `us-east-1a` et `us-east-1b`
- **RDS Multi-AZ** : Replica synchrone avec failover automatique
- **ASG minimum 2** : Toujours au moins 2 instances actives
- **Health checks ELB** : L'ASG retire automatiquement les instances défaillantes

### Gestion des secrets
- `terraform.tfvars` exclu du dépôt via `.gitignore`
- Les credentials AWS Academy stockés dans `set-credentials.ps1` (également exclu du git)

---

## 8. Limites et améliorations possibles

| Limite | Amélioration |
|---|---|
| HTTP uniquement (port 80) | Ajouter HTTPS avec certificat ACM + redirection HTTP→HTTPS |
| Mot de passe en variable | Utiliser AWS Secrets Manager |
| `aws_launch_configuration` déprécié | Migrer vers `aws_launch_template` |
| Pas de state backend distant | Utiliser S3 + DynamoDB pour le state Terraform |
| Module IAM spécifique AWS Academy | Créer le rôle IAM pour un compte AWS classique |
| Pas de notifications | Ajouter SNS pour alertes email lors des événements de scaling |
