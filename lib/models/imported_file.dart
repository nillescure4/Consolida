import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

class ImportedFile {
  final String id;
  final String name;
  final String localPath;
  final String type;
  final int sizeBytes;
  final DateTime? createdAt;

  // AFEGIR
  final Uint8List? bytes;

  const ImportedFile({
    required this.id,
    required this.name,
    required this.localPath,
    required this.type,
    required this.sizeBytes,
    this.createdAt,

    // AFEGIR
    this.bytes,
  });

  factory ImportedFile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return ImportedFile(
      id: doc.id,
      name: data?['name'] ?? '',
      localPath: data?['localPath'] ?? '',
      type: data?['type'] ?? '',
      sizeBytes: data?['sizeBytes'] ?? 0,
      createdAt: data?['createdAt'] is Timestamp
          ? (data?['createdAt'] as Timestamp).toDate()
          : null,

      // Firestore no guarda els bytes
      bytes: null,
    );
  }
}