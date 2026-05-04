import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../models/imported_file.dart';
import '../models/subject.dart';
import '../services/import_service.dart';
import '../services/material_processing_service.dart';
import '../widgets/app_scaffold.dart';

class ImportPage extends StatefulWidget {
  final Subject subject;

  const ImportPage({
    super.key,
    required this.subject,
  });

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final ImportService _importService = ImportService();
  final MaterialProcessingService _materialProcessingService =
      MaterialProcessingService();

  bool _isImporting = false;

  Future<void> _importFile() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final importedFile = await _importService.pickAndSaveFileLocally(
        widget.subject.id,
      );

      if (importedFile == null) {
        return;
      }

      if (_isProcessable(importedFile.type)) {
        await _materialProcessingService.processImportedFile(
          subjectId: widget.subject.id,
          file: importedFile,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fitxer importat i processat correctament.'),
          ),
        );
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Fitxer importat. Aquest format encara no es pot processar.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error important o processant el fitxer: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _openFile(ImportedFile file) async {
    final localFile = File(file.localPath);

    if (!await localFile.exists()) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aquest fitxer ja no existeix al dispositiu.'),
        ),
      );

      return;
    }

    await OpenFilex.open(file.localPath);
  }

  Future<void> _deleteFile(ImportedFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Esborrar fitxer'),
          content: Text(
            'Segur que vols esborrar "${file.name}" del dispositiu?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Esborrar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _importService.deleteFile(
        subjectId: widget.subject.id,
        file: file,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fitxer esborrat.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error esborrant el fitxer: $error'),
        ),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getFileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'txt':
        return Icons.description;
      case 'doc':
      case 'docx':
        return Icons.article;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  bool _isProcessable(String type) {
    final normalized = type.toLowerCase();

    return normalized == 'pdf' ||
        normalized == 'txt' ||
        normalized == 'docx';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Importar - ${widget.subject.name}',
      floatingActionButton: FloatingActionButton(
        onPressed: _isImporting ? null : _importFile,
        child: _isImporting
            ? const CircularProgressIndicator()
            : const Icon(Icons.upload_file),
      ),
      child: StreamBuilder<List<ImportedFile>>(
        stream: _importService.getFiles(widget.subject.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error carregant fitxers: ${snapshot.error}'),
            );
          }

          final files = snapshot.data ?? [];

          if (files.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 48,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Encara no has importat cap material.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Prem el botó + per afegir apunts, PDFs o documents.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];

              return Card(
                child: ListTile(
                  leading: Icon(
                    _getFileIcon(file.type),
                  ),
                  title: Text(file.name),
                  subtitle: Text(
                    '${file.type.toUpperCase()} · ${_formatFileSize(file.sizeBytes)}',
                  ),
                  onTap: () => _openFile(file),
                  trailing: IconButton(
                    onPressed: () => _deleteFile(file),
                    icon: const Icon(Icons.delete),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}