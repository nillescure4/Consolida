import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/imported_file.dart';

class ImportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No hi ha usuari autenticat.');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> filesCollection(
    String subjectId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subjects')
        .doc(subjectId)
        .collection('importedFiles');
  }

  CollectionReference<Map<String, dynamic>> processedMaterialsCollection(
    String subjectId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subjects')
        .doc(subjectId)
        .collection('processedMaterials');
  }

  Stream<List<ImportedFile>> getFiles(String subjectId) {
    return filesCollection(subjectId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ImportedFile.fromFirestore(doc))
              .toList(),
        );
  }

  Future<ImportedFile?> pickAndSaveFileLocally(String subjectId) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'txt',
        'docx',
      ],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final pickedFile = result.files.single;

    if (pickedFile.path == null) {
      throw Exception('No s’ha pogut llegir la ruta del fitxer.');
    }

    final originalFile = File(pickedFile.path!);

    if (!await originalFile.exists()) {
      throw Exception('El fitxer seleccionat no existeix.');
    }

    final appDirectory = await getApplicationDocumentsDirectory();

    final subjectDirectory = Directory(
      p.join(
        appDirectory.path,
        'consolida',
        'users',
        userId,
        'subjects',
        subjectId,
        'imported_files',
      ),
    );

    if (!await subjectDirectory.exists()) {
      await subjectDirectory.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final safeFileName = pickedFile.name.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    final localFilePath = p.join(
      subjectDirectory.path,
      '${timestamp}_$safeFileName',
    );

    final copiedFile = await originalFile.copy(localFilePath);

    final fileExtension = pickedFile.extension ?? 'unknown';

    final docRef = await filesCollection(subjectId).add({
      'name': pickedFile.name,
      'localPath': copiedFile.path,
      'type': fileExtension,
      'sizeBytes': pickedFile.size,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ImportedFile(
      id: docRef.id,
      name: pickedFile.name,
      localPath: copiedFile.path,
      type: fileExtension,
      sizeBytes: pickedFile.size,
      createdAt: DateTime.now(),
    );
  }

  Future<void> deleteFile({
    required String subjectId,
    required ImportedFile file,
  }) async {
    final localFile = File(file.localPath);

    if (await localFile.exists()) {
      await localFile.delete();
    }

    final processedSnapshot = await processedMaterialsCollection(subjectId)
        .where('fileId', isEqualTo: file.id)
        .get();

    final batch = _firestore.batch();

    for (final doc in processedSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(filesCollection(subjectId).doc(file.id));

    await batch.commit();
  }
}