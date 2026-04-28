import 'package:flutter/material.dart';

import '../models/subject.dart';
import '../services/subject_service.dart';
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
  final SubjectService _subjectService = SubjectService();
  final TextEditingController _nameController = TextEditingController();

  late String subjectName;

  @override
  void initState() {
    super.initState();
    subjectName = widget.subject.name;
  }

  void _openPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => page,
      ),
    );
  }

  Future<void> _showSettingsDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Configuració de l’assignatura'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Canviar nom'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Esborrar assignatura'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRenameDialog() async {
    _nameController.text = subjectName;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Canviar nom'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nou nom',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = _nameController.text.trim();

                if (newName.isEmpty) return;

                await _subjectService.updateSubjectName(
                  subjectId: widget.subject.id,
                  newName: newName,
                );

                if (!context.mounted) return;

                setState(() {
                  subjectName = newName;
                });

                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Esborrar assignatura'),
          content: Text(
            'Segur que vols esborrar "$subjectName"?\n\nAquesta acció no es pot desfer.',
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

    await _subjectService.deleteSubject(widget.subject.id);

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: subjectName,
      actions: [
        IconButton(
          onPressed: _showSettingsDialog,
          icon: const Icon(Icons.settings),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<bool>(
          stream: _subjectService.hasPendingPracticeToday(widget.subject.id),
          builder: (context, practiceSnapshot) {
            final hasPendingPractice = practiceSnapshot.data ?? false;

            return StreamBuilder<bool>(
              stream: _subjectService.hasNoObjectives(widget.subject.id),
              builder: (context, objectivesSnapshot) {
                final hasNoObjectives = objectivesSnapshot.data ?? false;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SubjectOptionButton(
                      text: 'Importar',
                      onTap: () => _openPage(
                        ImportPage(subject: widget.subject),
                      ),
                    ),
                    _SubjectOptionButton(
                      text: 'Practicar',
                      showWarning: hasPendingPractice,
                      warningText: 'Tens pràctica pendent',
                      onTap: () => _openPage(
                        PracticePage(subject: widget.subject),
                      ),
                    ),
                    _SubjectOptionButton(
                      text: 'Visualitzar',
                      onTap: () => _openPage(
                        VisualizePage(subject: widget.subject),
                      ),
                    ),
                    _SubjectOptionButton(
                      text: 'Objectius',
                      showWarning: hasNoObjectives,
                      warningText: 'Falta definir objectius',
                      onTap: () => _openPage(
                        ObjectivesPage(subject: widget.subject),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SubjectOptionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool showWarning;
  final String? warningText;

  const _SubjectOptionButton({
    required this.text,
    required this.onTap,
    this.showWarning = false,
    this.warningText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showWarning)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                  ),
                ),
              Flexible(
                child: Text(
                  warningText == null || !showWarning
                      ? text
                      : '$text · $warningText',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}