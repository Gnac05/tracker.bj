# Tracker Bénin

Application mobile Flutter + Firebase pour le Bénin :

- **Essence** : stations-service où la disponibilité d'essence est certifiée, de la plus proche à la plus éloignée.
- **Pharmacies** : pharmacies de garde de la semaine (liste officielle), de la plus proche à la plus éloignée.
- **Itinéraire** Google Maps en un geste, appel direct des pharmacies.
- **Signalement** : tout utilisateur indique s'il y a de l'essence ou non, avec une photo prise sur place (appareil photo uniquement, jamais la galerie).
- **Avis des usagers** : note de 1 à 5 étoiles et commentaire sur chaque station et pharmacie, note moyenne et avis des autres visibles par tous.
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
| Avis | Derniers avis des usagers, tous lieux confondus : recherche, filtres (notes basses, stations, pharmacies) et suppression. |
| Signalements | Voir la photo, la distance entre l'utilisateur et la station, puis **Certifier** (met à jour la station) ou **Rejeter**. |
| Garde de la semaine | Choisir la période, cocher les pharmacies de la liste officielle, **Publier**. |
| Stations / Pharmacies | Ajouter, modifier, supprimer. Le formulaire se remplit depuis Google Maps (voir ci-dessous) ou avec « Utiliser ma position ». |

Un administrateur connecté voit aussi une corbeille sur chaque avis pour le supprimer (modération).

### Import depuis Google Maps

Dans Google Maps : ouvrir le lieu → **Partager** → **Copier**, puis coller dans la carte « Importer depuis Google Maps » du formulaire. Sont acceptés :

- un lien complet `https://www.google.com/maps/place/...` ;
- un lien court `https://maps.app.goo.gl/...` (résolu par l'application, mobile uniquement) ;
- des coordonnées copiées par appui long sur la carte (`6.3654, 2.4183`).

Le nom et la position viennent du lien ; le quartier, la ville et le département sont complétés par géocodage inverse (géocodeur du téléphone, puis OpenStreetMap Nominatim en secours). Aucune clé d'API n'est nécessaire.

Si le lien ne contient pas les coordonnées exactes du lieu, la position est retrouvée par recherche du nom et signalée comme **approximative** : il faut alors la vérifier ou coller les coordonnées.

## Données Firestore

| Collection | Champs |
| --- | --- |
| `stations` | `name`, `address`, `city`, `department`, `lat`, `lng`, `status` (`available` / `unavailable` / `unknown`), `statusUpdatedAt`, `ratingSum`, `ratingCount` |
| `pharmacies` | `name`, `address`, `city`, `department`, `phone`, `lat`, `lng`, `dutyStart`, `dutyEnd`, `ratingSum`, `ratingCount` |
| `reviews` | ID `<lieu>_<uid>` ; `placeId`, `placeType` (`station` / `pharmacy`), `userId`, `authorName`, `rating` (1 à 5), `comment`, `updatedAt` |
| `reports` | `stationId`, `stationName`, `hasFuel`, `userId`, `photoUrl`, `distanceMeters`, `status` (`pending` / `approved` / `rejected`), `createdAt`, `reviewedAt`, `reviewedBy` |
| `admins` | un document par UID administrateur |

## Structure du code

- `lib/services/` : `Repository` (interface), `FirebaseRepository`, `DemoRepository`, `LocationService`
- `lib/screens/` : accueil, onglets Essence et Pharmacies, signalement
- `lib/admin/` : connexion et back office
- `firestore.rules`, `storage.rules` : sécurité côté serveur
