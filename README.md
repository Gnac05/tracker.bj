# Tracker Bénin

Application mobile Flutter + Firebase pour le Bénin :

- **Essence** : stations-service où la disponibilité d'essence est certifiée, de la plus proche à la plus éloignée.
- **Pharmacies** : pharmacies de garde de la semaine (liste officielle), de la plus proche à la plus éloignée.
- **Itinéraire** Google Maps en un geste, appel direct des pharmacies.
- **Signalement** : tout utilisateur indique s'il y a de l'essence ou non, avec une photo prise sur place (appareil photo uniquement, jamais la galerie).
- **Back office intégré** (icône bouclier en haut à droite) : certification des signalements, annuaire des stations et des pharmacies, publication hebdomadaire de la liste de garde.

## Essayer tout de suite (mode démo)

Tant que Firebase n'est pas configuré, l'application démarre avec des données fictives en mémoire.

```bash
flutter run
```

Dans ce mode, n'importe quel e-mail et mot de passe ouvrent le back office.

## Mise en service Firebase

1. Créer un projet sur <https://console.firebase.google.com> puis activer :
   - **Authentication** : fournisseurs *Anonyme* et *E-mail/Mot de passe* ;
   - **Firestore Database** (région conseillée : `europe-west1`) ;
   - **Storage** (nécessite la formule Blaze sur les nouveaux projets).
2. Relier l'application (remplace `lib/firebase_options.dart`) :

   ```bash
   npm install -g firebase-tools
   ```

   ```bash
   dart pub global activate flutterfire_cli
   ```

   ```bash
   firebase login
   ```

   ```bash
   flutterfire configure
   ```

3. Publier les règles de sécurité et l'index :

   ```bash
   firebase deploy --only firestore,storage
   ```

4. Créer un administrateur :
   - console → Authentication → *Ajouter un utilisateur* (e-mail + mot de passe) ;
   - copier son **UID** ;
   - console → Firestore → collection `admins` → nouveau document dont l'**ID est cet UID** (un champ `name` suffit).

## Utilisation du back office

| Onglet | Rôle |
| --- | --- |
| Signalements | Voir la photo, la distance entre l'utilisateur et la station, puis **Certifier** (met à jour la station) ou **Rejeter**. |
| Garde de la semaine | Choisir la période, cocher les pharmacies de la liste officielle, **Publier**. |
| Stations / Pharmacies | Ajouter, modifier, supprimer. La position se saisit sur place (« Utiliser ma position ») ou depuis Google Maps. |

## Données Firestore

| Collection | Champs |
| --- | --- |
| `stations` | `name`, `address`, `city`, `lat`, `lng`, `status` (`available` / `unavailable` / `unknown`), `statusUpdatedAt` |
| `pharmacies` | `name`, `address`, `city`, `phone`, `lat`, `lng`, `dutyStart`, `dutyEnd` |
| `reports` | `stationId`, `stationName`, `hasFuel`, `userId`, `photoUrl`, `distanceMeters`, `status` (`pending` / `approved` / `rejected`), `createdAt`, `reviewedAt`, `reviewedBy` |
| `admins` | un document par UID administrateur |

## Structure du code

- `lib/services/` : `Repository` (interface), `FirebaseRepository`, `DemoRepository`, `LocationService`
- `lib/screens/` : accueil, onglets Essence et Pharmacies, signalement
- `lib/admin/` : connexion et back office
- `firestore.rules`, `storage.rules` : sécurité côté serveur
