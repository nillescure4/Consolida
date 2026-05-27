import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:xml/xml.dart';

import '../models/imported_file.dart';
import '../models/processed_material.dart';

class MaterialProcessingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No hi ha usuari autenticat.');
    }

    return user.uid;
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

  Stream<List<ProcessedMaterial>> getProcessedMaterials(String subjectId) {
    return processedMaterialsCollection(subjectId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProcessedMaterial.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> processImportedFile({
    required String subjectId,
    required ImportedFile file,
  }) async {
    final extractedText = await extractTextFromFile(file);

    final cleanedText = _cleanText(extractedText);

    if (cleanedText.trim().isEmpty) {
      throw Exception(
        'No s’ha pogut extreure text del fitxer. Pot ser un PDF escanejat o un document sense text seleccionable.',
      );
    }

    await processedMaterialsCollection(subjectId).add({
      'fileId': file.id,
      'fileName': file.name,
      'fileType': file.type,
      'extractedText': cleanedText,
      'wordCount': _countWords(cleanedText),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> extractTextFromFile(ImportedFile file) async {
    final extension = file.type.toLowerCase();
    final localFile = File(file.localPath);

    if (!await localFile.exists()) {
      throw Exception('El fitxer no existeix al dispositiu.');
    }

    switch (extension) {
      case 'txt':
        return localFile.readAsString();

      case 'pdf':
        return ReadPdfText.getPDFtext(file.localPath);

      case 'docx':
        return _extractTextFromDocx(localFile);

      default:
        throw Exception(
          'Format no suportat encara. Formats suportats: PDF, DOCX i TXT.',
        );
    }
  }

  Future<String> _extractTextFromDocx(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final documentFile = archive.findFile('word/document.xml');

    if (documentFile == null) {
      throw Exception('No s’ha pogut trobar el contingut del DOCX.');
    }

    final xmlString = String.fromCharCodes(documentFile.content as List<int>);
    final document = XmlDocument.parse(xmlString);

    final buffer = StringBuffer();

    final textNodes = document.findAllElements('w:t');

    for (final node in textNodes) {
      buffer.write(node.innerText);
      buffer.write(' ');
    }

    return buffer.toString();
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
  }

  int _countWords(String text) {
    if (text.trim().isEmpty) return 0;

    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
  }

  Future<bool> isFileAlreadyProcessed({
    required String subjectId,
    required String fileId,
  }) async {
    final snapshot = await processedMaterialsCollection(subjectId)
        .where('fileId', isEqualTo: fileId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}