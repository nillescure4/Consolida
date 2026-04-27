import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../widgets/app_scaffold.dart';
import 'import_page.dart';
import 'practice_page.dart';
import 'visualize_page.dart';
import 'objectives_page.dart';

class SubjectPage extends StatelessWidget {
  final Subject subject;

  const SubjectPage({
    super.key,
    required this.subject,
  });

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: subject.name,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SubjectOptionButton(
              text: 'Importar',
              onTap: () => _openPage(
                context,
                ImportPage(subject: subject),
              ),
            ),
            _SubjectOptionButton(
              text: 'Practicar',
              onTap: () => _openPage(
                context,
                PracticePage(subject: subject),
              ),
            ),
            _SubjectOptionButton(
              text: 'Visualitzar',
              onTap: () => _openPage(
                context,
                VisualizePage(subject: subject),
              ),
            ),
            _SubjectOptionButton(
              text: 'Objectius',
              onTap: () => _openPage(
                context,
                ObjectivesPage(subject: subject),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectOptionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SubjectOptionButton({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(text),
        ),
      ),
    );
  }
}