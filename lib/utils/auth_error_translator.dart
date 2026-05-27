import 'package:firebase_auth/firebase_auth.dart';

String translateAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'El correu electrònic no és vàlid.';
      case 'user-disabled':
        return 'Aquest compte ha estat desactivat.';
      case 'user-not-found':
        return 'No existeix cap compte amb aquest correu.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'El correu o la contrasenya no són correctes.';
      case 'email-already-in-use':
        return 'Ja existeix un compte amb aquest correu.';
      case 'weak-password':
        return 'La contrasenya és massa feble.';
      case 'operation-not-allowed':
        return 'Aquest mètode d’inici de sessió no està habilitat.';
      case 'network-request-failed':
        return 'No s’ha pogut connectar. Revisa la connexió a internet.';
      case 'too-many-requests':
        return 'S’han fet massa intents. Torna-ho a provar més tard.';
      case 'missing-password':
        return 'Introdueix la contrasenya.';
      case 'missing-email':
        return 'Introdueix el correu electrònic.';
      default:
        return 'S’ha produït un error. Torna-ho a provar.';
    }
  }

  return 'S’ha produït un error. Torna-ho a provar.';
}