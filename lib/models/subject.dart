import 'package:cloud_firestore/cloud_firestore.dart';

class Subject {
  final String id;
  final String name;
  final DateTime? createdAt;

  const Subject({
    required this.id,
    required this.name,
    this.createdAt,
  });

  factory Subject.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return Subject(
      id: doc.id,
      name: data?['name'] ?? '',
      createdAt: data?['createdAt'] is Timestamp
          ? (data?['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}