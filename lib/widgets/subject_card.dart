import 'package:flutter/material.dart';

import '../models/subject.dart';

class SubjectCard extends StatelessWidget {
  final Subject subject;
  final VoidCallback onTap;
  final bool hasPendingPracticeToday;
  final bool hasNoObjectives;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.onTap,
    this.hasPendingPracticeToday = false,
    this.hasNoObjectives = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasAlert = hasPendingPracticeToday || hasNoObjectives;

    String? subtitle;

    if (hasPendingPracticeToday && hasNoObjectives) {
      subtitle = 'Pràctica pendent i falta definir objectius';
    } else if (hasPendingPracticeToday) {
      subtitle = 'Avui tens pràctica pendent';
    } else if (hasNoObjectives) {
      subtitle = 'Encara no has definit cap objectiu';
    }

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
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}