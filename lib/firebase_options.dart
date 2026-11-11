// FICHIER PROVISOIRE.
//
// Il sera remplacé automatiquement par la commande :
//
//   flutterfire configure
//
// Tant que Firebase n'est pas configuré, l'application démarre en
// « mode démo » avec des données locales fictives (voir README.md).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase n\'est pas encore configuré. Lancez « flutterfire configure ».',
    );
  }
}
