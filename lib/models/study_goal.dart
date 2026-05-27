import 'package:cloud_firestore/cloud_firestore.dart';
import 'goal_type.dart';

class StudyGoal {
  final String id;
  final String title;
  final GoalType type;
  final DateTime? targetDate;
  final int minutesPerSession;
  final DateTime? createdAt;

  const StudyGoal({
    required this.id,
    required this.title,
    required this.type,
    this.targetDate,
    required this.minutesPerSession,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type.value,
      'targetDate': targetDate == null ? null : Timestamp.fromDate(targetDate!),
      'minutesPerSession': minutesPerSession,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory StudyGoal.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return StudyGoal(
      id: doc.id,
      title: data?['title'] ?? '',
      type: GoalTypeExtension.fromValue(data?['type'] ?? 'shortTerm'),
      targetDate: data?['targetDate'] is Timestamp
          ? (data?['targetDate'] as Timestamp).toDate()
          : null,
      minutesPerSession: data?['minutesPerSession'] ?? 30,
      createdAt: data?['createdAt'] is Timestamp
          ? (data?['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}