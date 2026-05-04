import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/practice_activity_type.dart';
import '../models/practice_item.dart';

class PracticeErrorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No hi ha usuari autenticat.');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> errorsCollection(
    String subjectId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subjects')
        .doc(subjectId)
        .collection('practiceErrors');
  }

  Future<void> saveError({
    required String subjectId,
    required PracticeItem item,
  }) async {
    final existing = await errorsCollection(subjectId)
        .where('type', isEqualTo: item.type.name)
        .where('question', isEqualTo: item.question)
        .where('answer', isEqualTo: item.answer)
        .limit(1)
        .get();

    final data = {
      'type': item.type.name,
      'question': item.question,
      'answer': item.answer,
      'options': item.options,
      'sourceFileName': item.sourceFileName,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update(data);
      return;
    }

    await errorsCollection(subjectId).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeError({
    required String subjectId,
    required PracticeItem item,
  }) async {
    if (item.id != null) {
      await errorsCollection(subjectId).doc(item.id).delete();
      return;
    }

    final existing = await errorsCollection(subjectId)
        .where('type', isEqualTo: item.type.name)
        .where('question', isEqualTo: item.question)
        .where('answer', isEqualTo: item.answer)
        .get();

    final batch = _firestore.batch();

    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Stream<List<PracticeItem>> getErrors(String subjectId) {
    return errorsCollection(subjectId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        final typeName = data['type'];

        final type = PracticeActivityType.values.firstWhere(
          (item) => item.name == typeName,
          orElse: () => PracticeActivityType.openQuestions,
        );

        return PracticeItem(
          id: doc.id,
          type: type,
          question: data['question'] ?? '',
          answer: data['answer'] ?? '',
          options: List<String>.from(data['options'] ?? []),
          sourceFileName: data['sourceFileName'] ?? '',
        );
      }).toList();
    });
  }
}