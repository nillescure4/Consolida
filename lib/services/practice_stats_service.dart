import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/practice_attempt.dart';
import '../models/practice_activity_type.dart';

class PracticeStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No hi ha usuari autenticat.');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> attemptsCollection(
    String subjectId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subjects')
        .doc(subjectId)
        .collection('practiceAttempts');
  }

  Future<void> registerAttempt({
    required String subjectId,
    required String sessionId,
    required PracticeActivityType activityType,
    required bool isCorrect,
  }) async {
    if (sessionId.isEmpty) return;

    await attemptsCollection(subjectId).add({
      'sessionId': sessionId,
      'activityType': activityType.name,
      'isCorrect': isCorrect,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<PracticeAttempt>> watchAttempts(String subjectId) {
    return attemptsCollection(subjectId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PracticeAttempt.fromFirestore(doc))
              .toList(),
        );
  }
}