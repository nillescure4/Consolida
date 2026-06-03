import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
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
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      throw Exception('No s’ha pogut llegir el contingut del fitxer.');
    }

    switch (extension) {
      case 'txt':
        return String.fromCharCodes(bytes);

      case 'pdf':
        return _extractTextFromPdf(bytes);

      case 'docx':
        return _extractTextFromDocx(bytes);

      default:
        throw Exception(
          'Format no suportat encara. Formats suportats: PDF, DOCX i TXT.',
        );
    }
  }

  String _extractTextFromPdf(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();
    return text;
  }

  String _extractTextFromDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentFile = archive.findFile('word/document.xml');

    if (documentFile == null) {
      throw Exception('No s’ha pogut trobar el contingut del DOCX.');
    }

    final xmlString = String.fromCharCodes(documentFile.content as List<int>);
    final document = XmlDocument.parse(xmlString);

    final buffer = StringBuffer();

    for (final node in document.findAllElements('w:t')) {
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