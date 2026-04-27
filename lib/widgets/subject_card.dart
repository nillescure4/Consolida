import 'package:flutter/material.dart';
import '../models/subject.dart';

class SubjectCard extends StatelessWidget {
  final Subject subject;
  final VoidCallback onTap;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(subject.name),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}