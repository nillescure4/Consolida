import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ai_generated_activity.dart';

class AiActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No hi ha usuari autenticat.');
    }

    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> activityDoc(String subjectId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subjects')
        .doc(subjectId)
        .collection('aiActivities')
        .doc('main');
  }

  Stream<AiGeneratedActivity?> watchActivity(String subjectId) {
    return activityDoc(subjectId).snapshots().map((doc) {
      if (!doc.exists) return null;

      final data = doc.data();

      if (data == null) return null;

      return AiGeneratedActivity.fromJson(data);
    });
  }

  Future<void> saveActivity({
    required String subjectId,
    required AiGeneratedActivity activity,
  }) async {
    await activityDoc(subjectId).set({
      ...activity.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteActivity(String subjectId) async {
    await activityDoc(subjectId).delete();
  }
}