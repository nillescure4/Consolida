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
              .map(
                (doc) => Subject.fromFirestore(doc),
              )
              .toList(),
        );
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