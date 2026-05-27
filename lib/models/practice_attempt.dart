import 'package:cloud_firestore/cloud_firestore.dart';

class PracticeAttempt {
  final String id;
  final String sessionId;
  final String activityType;
  final bool isCorrect;
  final DateTime? createdAt;

  const PracticeAttempt({
    required this.id,
    required this.sessionId,
    required this.activityType,
    required this.isCorrect,
    this.createdAt,
  });

  factory PracticeAttempt.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return PracticeAttempt(
      id: doc.id,
      sessionId: data?['sessionId'] ?? '',
      activityType: data?['activityType'] ?? '',
      isCorrect: data?['isCorrect'] ?? false,
      createdAt: data?['createdAt'] is Timestamp
          ? (data?['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}