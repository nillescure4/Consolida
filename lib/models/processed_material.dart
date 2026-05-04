import 'package:cloud_firestore/cloud_firestore.dart';

class ProcessedMaterial {
  final String id;
  final String fileId;
  final String fileName;
  final String extractedText;
  final int wordCount;
  final DateTime? createdAt;

  const ProcessedMaterial({
    required this.id,
    required this.fileId,
    required this.fileName,
    required this.extractedText,
    required this.wordCount,
    this.createdAt,
  });

  factory ProcessedMaterial.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return ProcessedMaterial(
      id: doc.id,
      fileId: data?['fileId'] ?? '',
      fileName: data?['fileName'] ?? '',
      extractedText: data?['extractedText'] ?? '',
      wordCount: data?['wordCount'] ?? 0,
      createdAt: data?['createdAt'] is Timestamp
          ? (data?['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}