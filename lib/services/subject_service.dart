import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/subject.dart';

class SubjectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No hi ha usuari autenticat');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get subjectsCollection {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subjects');
  }

  Stream<List<Subject>> getSubjects() {
    return subjectsCollection
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Subject.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<bool> hasNoImportedFiles(String subjectId) {
    return subjectsCollection
        .doc(subjectId)
        .collection('importedFiles')
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isEmpty);
  }

  Stream<bool> hasNoObjectives(String subjectId) {
    return subjectsCollection
        .doc(subjectId)
        .collection('goals')
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isEmpty);
  }

  Stream<bool> hasPendingPracticeToday(String subjectId) {
    final today = DateTime.now();

    final todayOnly = DateTime(
      today.year,
      today.month,
      today.day,
    );

    return subjectsCollection
        .doc(subjectId)
        .collection('practiceSessions')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
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

        final isTodayOrPast =
            scheduledDateOnly.isBefore(todayOnly) ||
            scheduledDateOnly.isAtSameMomentAs(todayOnly);

        if (isTodayOrPast) {
          return true;
        }
      }

      return false;
    });
  }

  Future<void> createSubject(String name) async {
    await subjectsCollection.add({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSubjectName({
    required String subjectId,
    required String newName,
  }) async {
    await subjectsCollection.doc(subjectId).update({
      'name': newName,
    });
  }

  Future<void> deleteSubject(String subjectId) async {
    await subjectsCollection.doc(subjectId).delete();
  }
}