import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/goal_type.dart';
import '../models/practice_session.dart';
import '../models/practice_timer_state.dart';
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

  CollectionReference<Map<String, dynamic>> goalsCollection(String subjectId) {
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
              .map((doc) => StudyGoal.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<PracticeSession>> getPracticeSessions(String subjectId) {
    return sessionsCollection(subjectId)
        .orderBy('scheduledDate')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PracticeSession.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<PracticeTimerState> watchPracticeTimerState(String subjectId) {
    return sessionsCollection(subjectId).snapshots().map((snapshot) {
      final now = DateTime.now();
      final todayOnly = DateTime(now.year, now.month, now.day);

      QueryDocumentSnapshot<Map<String, dynamic>>? duePendingSession;
      QueryDocumentSnapshot<Map<String, dynamic>>? completedTodaySession;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final scheduledDateRaw = data['scheduledDate'];

        if (scheduledDateRaw is! Timestamp) {
          continue;
        }

        final scheduledDate = scheduledDateRaw.toDate();
        final scheduledDateOnly = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
        );

        final status = data['status'] ?? 'pending';

        final isTodayOrPast = scheduledDateOnly.isBefore(todayOnly) ||
            scheduledDateOnly.isAtSameMomentAs(todayOnly);

        final isToday = scheduledDateOnly.isAtSameMomentAs(todayOnly);

        if (status == 'pending' && isTodayOrPast) {
          duePendingSession ??= doc;
        }

        if (status == 'completed' && isToday) {
          completedTodaySession ??= doc;
        }
      }

      if (duePendingSession != null) {
        final data = duePendingSession.data();

        final durationMinutes = data['durationMinutes'] is int
            ? data['durationMinutes'] as int
            : 30;

        final remainingSeconds = data['remainingSeconds'] is int
            ? data['remainingSeconds'] as int
            : durationMinutes * 60;

        return PracticeTimerState(
          sessionId: duePendingSession.id,
          remainingSeconds: remainingSeconds,
          durationMinutes: durationMinutes,
          hasDueSession: true,
          completedToday: false,
        );
      }

      if (completedTodaySession != null) {
        final data = completedTodaySession.data();

        final durationMinutes = data['durationMinutes'] is int
            ? data['durationMinutes'] as int
            : 30;

        return PracticeTimerState(
          sessionId: completedTodaySession.id,
          remainingSeconds: 0,
          durationMinutes: durationMinutes,
          hasDueSession: false,
          completedToday: true,
        );
      }

      return const PracticeTimerState(
        sessionId: null,
        remainingSeconds: 0,
        durationMinutes: 0,
        hasDueSession: false,
        completedToday: false,
      );
    });
  }

  Future<void> saveGoalWithSessions({
    required String subjectId,
    required StudyGoal goal,
    required List<DateTime> dates,
  }) async {
    final goalRef = goalsCollection(subjectId).doc();

    final batch = _firestore.batch();

    batch.set(goalRef, {
      'title': goal.title,
      'type': goal.type.value,
      'targetDate': goal.targetDate == null
          ? null
          : Timestamp.fromDate(goal.targetDate!),
      'minutesPerSession': goal.minutesPerSession,
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (final date in dates) {
      final sessionRef = sessionsCollection(subjectId).doc();

      batch.set(sessionRef, {
        'goalId': goalRef.id,
        'goalTitle': goal.title,
        'scheduledDate': Timestamp.fromDate(date),
        'durationMinutes': goal.minutesPerSession,
        'remainingSeconds': goal.minutesPerSession * 60,
        'status': 'pending',
        'emailSent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> updateRemainingSeconds({
    required String subjectId,
    required String sessionId,
    required int remainingSeconds,
  }) async {
    await sessionsCollection(subjectId).doc(sessionId).update({
      'remainingSeconds': remainingSeconds,
      'lastPracticedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completePracticeSession({
    required String subjectId,
    required String sessionId,
  }) async {
    await sessionsCollection(subjectId).doc(sessionId).update({
      'remainingSeconds': 0,
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGoal({
    required String subjectId,
    required String goalId,
  }) async {
    final sessionsSnapshot = await sessionsCollection(subjectId)
        .where('goalId', isEqualTo: goalId)
        .get();

    final batch = _firestore.batch();

    for (final doc in sessionsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(goalsCollection(subjectId).doc(goalId));

    await batch.commit();

    await cleanOrphanPracticeSessions(subjectId);
  }

  Future<void> cleanOrphanPracticeSessions(String subjectId) async {
    final goalsSnapshot = await goalsCollection(subjectId).get();
    final existingGoalIds = goalsSnapshot.docs.map((doc) => doc.id).toSet();

    final sessionsSnapshot = await sessionsCollection(subjectId).get();

    final batch = _firestore.batch();
    bool hasUpdates = false;

    for (final sessionDoc in sessionsSnapshot.docs) {
      final data = sessionDoc.data();
      final goalId = data['goalId'];

      if (goalId == null ||
          goalId is! String ||
          !existingGoalIds.contains(goalId)) {
        batch.delete(sessionDoc.reference);
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }
}