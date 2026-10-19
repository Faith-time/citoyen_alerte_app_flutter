# Alert Citoyen – Application mobile

Application mobile de signalement citoyen pour le Sénégal. Candidature Banlieue Smart Genius 2026, catégorie Smart Territory.

## Présentation
Alert Citoyen rend le signalement des problèmes locaux (éclairage, voirie, déchets, eau…) simple et visuel : catégories illustrées, photo ou vidéo, gravité, localisation automatique et option anonyme. Chaque signalement est suivi jusqu'à sa résolution.

## Quatre espaces
- **Citoyen** : signaler en 3 étapes, suivre ses signalements, voir l'avant / après des résolutions
- **Autorité** : recevoir, prendre en charge et assigner les signalements à ses agents
- **Agent de terrain** : tableau Kanban (en attente, en cours, terminé), itinéraire Google Maps, photo de preuve obligatoire pour clôturer
- **Mairie** : indicateurs et statistiques par statut, catégorie et gravité

## Technologies
Flutter · GetX · Firebase (connexion Google) · Google Maps · API REST Laravel (JWT)

## Lancer l'application sur un téléphone Android (débogage sans fil)

Le PC et le téléphone doivent être connectés au **même réseau Wi-Fi**.

### 1. Démarrer le backend
Lancer le serveur Laravel (voir le dépôt backend) :
```bash
php artisan serve --host=0.0.0.0 --port=8000
```

### 2. Configurer l'adresse de l'API
Sur le PC, récupérer son adresse IP avec la commande `ipconfig` (ligne « Adresse IPv4 »). La renseigner dans le fichier `À COMPLÉTER` :
```
http://ADRESSE_IP_DU_PC:8000
```

### 3. Activer le débogage sans fil sur le téléphone
Paramètres, Options pour les développeurs, Débogage sans fil : activer l'option.

### 4. Associer le téléphone avec le code d'association
Sur le téléphone, appuyer sur « Associer l'appareil avec un code d'association ». Le téléphone affiche une adresse IP, un **port d'association** et un **code à 6 chiffres**. Sur le PC :
```bash
adb pair IP_DU_TELEPHONE:PORT_ASSOCIATION
```
Saisir ensuite le code à 6 chiffres quand il est demandé.

### 5. Connecter le téléphone
Sur l'écran principal du débogage sans fil, le téléphone affiche son adresse IP et un **port de connexion**, différent du port d'association. Sur le PC :
```bash
adb connect IP_DU_TELEPHONE:PORT_CONNEXION
```

### 6. Lancer l'application
Vérifier que le téléphone est détecté, puis lancer :
```bash
flutter devices
flutter pub get
flutter run
```

Remarque : l'adresse IP du PC (étape 2) et celle du téléphone (étapes 4 et 5) sont deux adresses différentes. Les clés Firebase et Google Maps du projet doivent aussi être configurées.

## Backend
Dépôt Laravel : https://github.com/Faith-time/citoyen_alerte_app_laravel

## Statut
Prototype fonctionnel, pas encore testé auprès d'utilisateurs ni déployé.

## Auteure
Adji Fatime Bâ · Keur Massar, Dakar
