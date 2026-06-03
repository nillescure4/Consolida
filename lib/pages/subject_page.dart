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

  void _openPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  void _showBlockedMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.subject.name,
      child: StreamBuilder<List<ProcessedMaterial>>(
        stream: _materialProcessingService.getProcessedMaterials(
          widget.subject.id,
        ),
        builder: (context, materialSnapshot) {
          final materials = materialSnapshot.data ?? [];
          final hasImportedMaterial = materials.isNotEmpty;

          return StreamBuilder<List<StudyGoal>>(
            stream: _objectiveService.getGoals(widget.subject.id),
            builder: (context, goalsSnapshot) {
              final goals = goalsSnapshot.data ?? [];
              final hasObjectives = goals.isNotEmpty;

              final canAccessObjectives = hasImportedMaterial;
              final canAccessPracticeAndProgress =
                  hasImportedMaterial && hasObjectives;

              return Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.05,
                  children: [
                    _SubjectOptionCard(
                      text: 'Importar',
                      icon: Icons.upload_file,
                      enabled: true,
                      onTap: () => _openPage(
                        ImportPage(subject: widget.subject),
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
                        PracticePage(subject: widget.subject),
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
                        ObjectivesPage(subject: widget.subject),
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
                        VisualizePage(subject: widget.subject),
                      ),
                      onBlocked: _showBlockedMessage,
                    ),
                  ],
                ),
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
    return InkWell(
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
      child: Card(
        color: enabled
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade400,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 44,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
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