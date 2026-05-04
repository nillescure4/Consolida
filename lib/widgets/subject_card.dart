import 'package:flutter/material.dart';

import '../models/subject.dart';

class SubjectCard extends StatelessWidget {
  final Subject subject;
  final VoidCallback onTap;
  final bool hasPendingPracticeToday;
  final bool hasNoObjectives;
  final bool hasNoImportedFiles;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.onTap,
    this.hasPendingPracticeToday = false,
    this.hasNoObjectives = false,
    this.hasNoImportedFiles = false,
  });

  @override
  Widget build(BuildContext context) {
    String? alertText;

    if (hasNoImportedFiles) {
      alertText = 'Falta material importat';
    } else if (hasNoObjectives) {
      alertText = 'Falten objectius';
    } else if (hasPendingPracticeToday) {
      alertText = 'Pràctica pendent';
    }

    final hasAlert = alertText != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: hasAlert
            ? const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
              )
            : null,
        title: Text(subject.name),
        subtitle: hasAlert ? Text(alertText) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}