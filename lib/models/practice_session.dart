import 'package:cloud_firestore/cloud_firestore.dart';

class PracticeSession {
  final String id;
  final String goalId;
  final String goalTitle;
  final DateTime scheduledDate;
  final int durationMinutes;
  final String status;
  final bool emailSent;

  const PracticeSession({
    required this.id,
    required this.goalId,
    required this.goalTitle,
    required this.scheduledDate,
    required this.durationMinutes,
    required this.status,
    required this.emailSent,
  });

  Map<String, dynamic> toMap() {
    return {
      'goalId': goalId,
      'goalTitle': goalTitle,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'durationMinutes': durationMinutes,
      'status': status,
      'emailSent': emailSent,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory PracticeSession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return PracticeSession(
      id: doc.id,
      goalId: data?['goalId'] ?? '',
      goalTitle: data?['goalTitle'] ?? '',
      scheduledDate: data?['scheduledDate'] is Timestamp
          ? (data?['scheduledDate'] as Timestamp).toDate()
          : DateTime.now(),
      durationMinutes: data?['durationMinutes'] ?? 30,
      status: data?['status'] ?? 'pending',
      emailSent: data?['emailSent'] ?? false,
    );
  }
}