// Prise de photo en direct dans un navigateur.
//
// Sur mobile (Android / iOS), l'application ouvre l'appareil photo du
// téléphone via image_picker. Dans un navigateur, image_picker ouvrirait un
// sélecteur de fichiers (donc la galerie) : on utilise à la place le flux
// vidéo de la caméra (getUserMedia), sans aucun accès aux fichiers.
export 'live_camera_stub.dart'
    if (dart.library.js_interop) 'live_camera_web.dart';
