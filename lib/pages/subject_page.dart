import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/processed_material.dart';
import '../models/study_goal.dart';
import '../models/subject.dart';
import '../services/material_processing_service.dart';
import '../services/objective_service.dart';
import '../widgets/app_scaffold.dart';
import 'import_page.dart';
import 'objectives_page.dart';
import 'practice_page.dart';
import 'visualize_page.dart';

class SubjectPage extends StatefulWidget {
  final Subject subject;

  const SubjectPage({
    super.key,
    required this.subject,
  });

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  final MaterialProcessingService _materialProcessingService =
      MaterialProcessingService();
  final ObjectiveService _objectiveService = ObjectiveService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late Subject _subject;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _subject = widget.subject;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No hi ha usuari autenticat.');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _subjectRef {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('subjects')
        .doc(_subject.id);
  }

  void _openPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _showBlockedMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  int _crossAxisCount(double width) {
    if (width >= 1100) return 4;
    return 2;
  }

  double _maxContentWidth(double width) {
    if (width >= 1100) return 1000;
    if (width >= 700) return 680;
    return double.infinity;
  }

  double _childAspectRatio(double width) {
    if (width >= 1100) return 1.05;
    if (width >= 700) return 1.15;
    return 1.05;
  }

  Future<void> _openSubjectSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Configuració de l’assignatura',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Canviar nom'),
                  onTap: () {
                    Navigator.pop(context);
                    _renameSubject();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Esborrar assignatura'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteSubject();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _renameSubject() async {
    _nameController.text = _subject.name;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Canviar nom'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom de l’assignatura',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _nameController.text.trim());
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty) return;

    await _subjectRef.update({
      'name': newName,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _subject = Subject(
        id: _subject.id,
        name: newName,
      );
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nom actualitzat correctament.')),
    );
  }

  Future<void> _confirmDeleteSubject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Esborrar assignatura'),
          content: Text(
            'Segur que vols esborrar "${_subject.name}"? També s’eliminaran els seus materials, objectius, sessions i dades de pràctica.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Esborrar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await _deleteSubject();

    if (!mounted) return;

    Navigator.pop(context);
  }

  Future<void> _deleteSubject() async {
    final subcollections = [
      'processedMaterials',
      'goals',
      'practiceSessions',
      'practiceErrors',
      'practiceAttempts',
      'aiActivities',
    ];

    for (final collectionName in subcollections) {
      await _deleteCollection(_subjectRef.collection(collectionName));
    }

    await _subjectRef.delete();
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    const batchSize = 300;

    while (true) {
      final snapshot = await collection.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (snapshot.docs.length < batchSize) break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _subject.name,
      actions: [
        IconButton(
          tooltip: 'Configuració',
          onPressed: _openSubjectSettings,
          icon: const Icon(Icons.settings),
        ),
      ],
      child: StreamBuilder<List<ProcessedMaterial>>(
        stream: _materialProcessingService.getProcessedMaterials(_subject.id),
        builder: (context, materialSnapshot) {
          final materials = materialSnapshot.data ?? [];
          final hasImportedMaterial = materials.isNotEmpty;

          return StreamBuilder<List<StudyGoal>>(
            stream: _objectiveService.getGoals(_subject.id),
            builder: (context, goalsSnapshot) {
              final goals = goalsSnapshot.data ?? [];
              final hasObjectives = goals.isNotEmpty;

              final canAccessObjectives = hasImportedMaterial;
              final canAccessPracticeAndProgress =
                  hasImportedMaterial && hasObjectives;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: _maxContentWidth(width),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: GridView.count(
                          crossAxisCount: _crossAxisCount(width),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: _childAspectRatio(width),
                          children: [
                            _SubjectOptionCard(
                              text: 'Importar',
                              icon: Icons.upload_file,
                              enabled: true,
                              onTap: () => _openPage(
                                ImportPage(subject: _subject),
                              ),
                            ),
                            _SubjectOptionCard(
                              text: 'Practicar',
                              icon: Icons.psychology_alt,
                              enabled: canAccessPracticeAndProgress,
                              disabledMessage: !hasImportedMaterial
                                  ? 'Primer has d’importar material en aquesta assignatura.'
                                  : 'Primer has de crear un objectiu per poder practicar.',
                              onTap: () => _openPage(
                                PracticePage(subject: _subject),
                              ),
                              onBlocked: _showBlockedMessage,
                            ),
                            _SubjectOptionCard(
                              text: 'Objectius',
                              icon: Icons.flag_outlined,
                              enabled: canAccessObjectives,
                              disabledMessage:
                                  'Primer has d’importar material abans de crear objectius.',
                              onTap: () => _openPage(
                                ObjectivesPage(subject: _subject),
                              ),
                              onBlocked: _showBlockedMessage,
                            ),
                            _SubjectOptionCard(
                              text: 'Veure progrés',
                              icon: Icons.analytics_outlined,
                              enabled: canAccessPracticeAndProgress,
                              disabledMessage: !hasImportedMaterial
                                  ? 'Primer has d’importar material en aquesta assignatura.'
                                  : 'Primer has de crear un objectiu per veure el progrés.',
                              onTap: () => _openPage(
                                VisualizePage(subject: _subject),
                              ),
                              onBlocked: _showBlockedMessage,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SubjectOptionCard extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final String? disabledMessage;
  final void Function(String message)? onBlocked;

  const _SubjectOptionCard({
    required this.text,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.disabledMessage,
    this.onBlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          if (enabled) {
            onTap();
            return;
          }
  
          if (disabledMessage != null && onBlocked != null) {
            onBlocked!(disabledMessage!);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 42,
                color: enabled
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : Colors.grey,
              ),
              const SizedBox(height: 14),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: enabled
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Colors.grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}