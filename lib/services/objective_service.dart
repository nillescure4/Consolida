import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/practice_session.dart';
import '../models/study_goal.dart';

class ObjectiveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No hi ha usuari autenticat.');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> goalsCollection(
    String subjectId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subjects')
        .doc(subjectId)
        .collection('goals');
  }

  CollectionReference<Map<String, dynamic>> sessionsCollection(
    String subjectId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subjects')
        .doc(subjectId)
        .collection('practiceSessions');
  }

  Stream<List<StudyGoal>> getGoals(String subjectId) {
    return goalsCollection(subjectId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => StudyGoal.fromFirestore(doc),
              )
              .toList(),
        );
  }

  Stream<List<PracticeSession>> getPracticeSessions(String subjectId) {
    return sessionsCollection(subjectId)
        .orderBy('scheduledDate')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => PracticeSession.fromFirestore(doc),
              )
              .toList(),
        );
  }

  Future<void> saveGoalWithSessions({
    required String subjectId,
    required StudyGoal goal,
    required List<DateTime> dates,
  }) async {
    final batch = _firestore.batch();

    final goalRef = goalsCollection(subjectId).doc();

    batch.set(
      goalRef,
      goal.toMap(),
    );

    for (final date in dates) {
      final sessionRef = sessionsCollection(subjectId).doc();

      final session = PracticeSession(
        id: sessionRef.id,
        goalId: goalRef.id,
        goalTitle: goal.title,
        scheduledDate: date,
        durationMinutes: goal.minutesPerSession,
        status: 'pending',
        emailSent: false,
      );

      batch.set(
        sessionRef,
        session.toMap(),
      );
    }

    await batch.commit();
  }

  Future<void> deleteGoal({
    required String subjectId,
    required String goalId,
  }) async {
    await goalsCollection(subjectId).doc(goalId).delete();

    final sessions = await sessionsCollection(subjectId)
        .where('goalId', isEqualTo: goalId)
        .get();

    final batch = _firestore.batch();

    for (final doc in sessions.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}