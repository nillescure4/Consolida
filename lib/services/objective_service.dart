import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/practice_session.dart';
import '../models/practice_timer_state.dart';
import '../models/study_goal.dart';
import 'notification_service.dart';

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
          (snapshot) =>
              snapshot.docs.map((doc) => StudyGoal.fromFirestore(doc)).toList(),
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

      final duePendingSessions = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final scheduledDateRaw = data['scheduledDate'];

        if (scheduledDateRaw is! Timestamp) continue;

        final scheduledDate = scheduledDateRaw.toDate();
        final scheduledDateOnly = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
        );

        final status = data['status'] ?? 'pending';

        final isTodayOrPast = scheduledDateOnly.isBefore(todayOnly) ||
            scheduledDateOnly.isAtSameMomentAs(todayOnly);

        if (status == 'pending' && isTodayOrPast) {
          duePendingSessions.add(doc);
        }
      }

      duePendingSessions.sort((a, b) {
        final aDate = (a.data()['scheduledDate'] as Timestamp).toDate();
        final bDate = (b.data()['scheduledDate'] as Timestamp).toDate();
        return aDate.compareTo(bDate);
      });

      if (duePendingSessions.isNotEmpty) {
        final session = duePendingSessions.first;
        final data = session.data();

        final durationMinutes = data['durationMinutes'] is int
            ? data['durationMinutes'] as int
            : 30;

        final remainingSeconds = data['remainingSeconds'] is int
            ? data['remainingSeconds'] as int
            : durationMinutes * 60;

        return PracticeTimerState(
          sessionId: session.id,
          remainingSeconds: remainingSeconds,
          durationMinutes: durationMinutes,
          hasDueSession: true,
          completedToday: false,
          goalTitle: data['goalTitle'] ?? 'Objectiu',
          scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
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
    required String subjectName,
    required StudyGoal goal,
    required List<DateTime> dates,
  }) async {
    final goalRef = goalsCollection(subjectId).doc();
    final batch = _firestore.batch();

    batch.set(goalRef, {
      'title': goal.title,
      'type': goal.type.name,
      'targetDate':
          goal.targetDate == null ? null : Timestamp.fromDate(goal.targetDate!),
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
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    final today = DateTime.now();
    final hasPracticeToday = dates.any((date) {
      return date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    });

    if (hasPracticeToday) {
      await NotificationService.showInstantPendingPracticeNotification(
        subjectName: subjectName,
        goalTitle: goal.title,
      );
    }

    await schedulePendingPracticeNotificationForSubject(
      subjectId: subjectId,
      subjectName: subjectName,
    );
  }

  Future<void> addPracticeSession({
    required String subjectId,
    required String subjectName,
    required String goalId,
    required String goalTitle,
    required DateTime scheduledDate,
    required int durationMinutes,
  }) async {
    await sessionsCollection(subjectId).add({
      'goalId': goalId,
      'goalTitle': goalTitle,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'durationMinutes': durationMinutes,
      'remainingSeconds': durationMinutes * 60,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await schedulePendingPracticeNotificationForSubject(
      subjectId: subjectId,
      subjectName: subjectName,
    );
  }

  Future<void> updatePracticeSession({
    required String subjectId,
    required String subjectName,
    required String sessionId,
    required DateTime scheduledDate,
    required int durationMinutes,
    required bool completed,
  }) async {
    await sessionsCollection(subjectId).doc(sessionId).update({
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'durationMinutes': durationMinutes,
      'remainingSeconds': completed ? 0 : durationMinutes * 60,
      'status': completed ? 'completed' : 'pending',
      'completedAt': completed ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await schedulePendingPracticeNotificationForSubject(
      subjectId: subjectId,
      subjectName: subjectName,
    );
  }

  Future<void> deletePracticeSession({
    required String subjectId,
    required String subjectName,
    required String sessionId,
  }) async {
    await sessionsCollection(subjectId).doc(sessionId).delete();

    await schedulePendingPracticeNotificationForSubject(
      subjectId: subjectId,
      subjectName: subjectName,
    );
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
    required String subjectName,
    required String sessionId,
  }) async {
    await sessionsCollection(subjectId).doc(sessionId).update({
      'remainingSeconds': 0,
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'completedDate': Timestamp.fromDate(DateTime.now()),
    });

    await schedulePendingPracticeNotificationForSubject(
      subjectId: subjectId,
      subjectName: subjectName,
    );
  }

  Future<void> deleteGoal({
    required String subjectId,
    required String subjectName,
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

    await schedulePendingPracticeNotificationForSubject(
      subjectId: subjectId,
      subjectName: subjectName,
    );
  }

  Future<void> schedulePendingPracticeNotificationForSubject({
    required String subjectId,
    required String subjectName,
  }) async {
    final pendingSession = await _getNextDuePendingSession(subjectId);

    if (pendingSession == null) {
      await NotificationService.cancelSubjectNotifications(subjectId);
      return;
    }

    await NotificationService.scheduleDailyPendingPracticeNotification(
      subjectId: subjectId,
      subjectName: subjectName,
      goalTitle: pendingSession.data()['goalTitle'] ?? 'Objectiu',
      hour: 9,
      minute: 0,
    );
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _getNextDuePendingSession(
    String subjectId,
  ) async {
    final snapshot = await sessionsCollection(subjectId)
        .where('status', isEqualTo: 'pending')
        .get();

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    final dueSessions = snapshot.docs.where((doc) {
      final scheduledDateRaw = doc.data()['scheduledDate'];

      if (scheduledDateRaw is! Timestamp) return false;

      final scheduledDate = scheduledDateRaw.toDate();
      final scheduledDateOnly = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
      );

      return scheduledDateOnly.isBefore(todayOnly) ||
          scheduledDateOnly.isAtSameMomentAs(todayOnly);
    }).toList();

    dueSessions.sort((a, b) {
      final aDate = (a.data()['scheduledDate'] as Timestamp).toDate();
      final bDate = (b.data()['scheduledDate'] as Timestamp).toDate();
      return aDate.compareTo(bDate);
    });

    if (dueSessions.isEmpty) return null;

    return dueSessions.first;
  }
}