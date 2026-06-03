import 'package:cloud_firestore/cloud_firestore.dart';

class PracticeSession {
  final String id;
  final String goalId;
  final String goalTitle;
  final DateTime scheduledDate;
  final int durationMinutes;
  final int remainingSeconds;
  final String status;
  final DateTime? completedAt;

  const PracticeSession({
    required this.id,
    required this.goalId,
    required this.goalTitle,
    required this.scheduledDate,
    required this.durationMinutes,
    required this.remainingSeconds,
    required this.status,
    this.completedAt,
  });

  bool get isCompleted => status == 'completed';

  factory PracticeSession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return PracticeSession(
      id: doc.id,
      goalId: data['goalId'] ?? '',
      goalTitle: data['goalTitle'] ?? '',
      scheduledDate: data['scheduledDate'] is Timestamp
          ? (data['scheduledDate'] as Timestamp).toDate()
          : DateTime.now(),
      durationMinutes: data['durationMinutes'] is int
          ? data['durationMinutes'] as int
          : 30,
      remainingSeconds: data['remainingSeconds'] is int
          ? data['remainingSeconds'] as int
          : 1800,
      status: data['status'] ?? 'pending',
      completedAt: data['completedAt'] is Timestamp
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }
}