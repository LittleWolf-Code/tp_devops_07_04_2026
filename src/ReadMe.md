# Application PHP — Articles

Cette application codée en PHP permet de poster un article qui est ensuite sauvegardé sur une base de données MySQL.  le but de ce mini projet est de réaliser depuis Terraform une infrastructure AWS hautement disponible pour une application en php communiquant avec une base de données relationnelle.

Voici quelques indications sur deux fichiers sources que vous devez obligatoirement prendre en considération :

## Fichiers sources

**`db-config.php`** : contient la configuration requise pour que votre application communique avec votre base de données. Vous y retrouverez :
- `##DB_HOST##` : à remplacer par l'IP ou le nom DNS de votre base de données.
- `##DB_USER##` : à remplacer par le nom d'utilisateur de votre base de données.
- `##DB_PASSWORD##` : à remplacer par le mot de passe utilisateur de votre base de données.

**`articles.sql`** : contient la requête SQL à exécuter pour créer l'architecture de votre table dans votre base de données.

## Informations importantes

Avant de commencer, je vous demanderai de créer vos ressources Terraform sous forme de modules.

Vous pouvez utiliser cette arborescence :

```
├── modules/
│   ├── alb_asg/
│   ├── cloudwatch_cpu_alarms/
│   ├── ec2_role_allow_s3/
│   ├── rds/
│   ├── s3/
│   └── vpc/
├── src/
├── keys/
├── vars.tf
├── main.tf
├── outputs.tf
├── README.md
└── .gitignore
```

- `modules` : répertoire pour héberger nos différents modules.
- `src` : répertoire pour héberger les sources de notre application qui seront ensuite envoyées sur notre bucket S3.
- `keys` : répertoire pour héberger la paire de clés SSH, au cas où nous aurions besoin de nous connecter sur nos instances EC2.
- `vars.tf` : fichier de variables du module racine.
- `main.tf` : fichier de configuration principale du module racine.
- `outputs.tf` : fichier de variables de sortie du module racine.
- `README.md` : fichier de documentation principale de notre projet.
- `.gitignore` : fichier contenant une liste de fichiers/dossiers à ignorer lors d'un commit.

**Good Luck!**
