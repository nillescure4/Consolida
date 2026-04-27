import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../widgets/app_scaffold.dart';

class ObjectivesPage extends StatelessWidget {
  final Subject subject;

  const ObjectivesPage({
    super.key,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Objectius - ${subject.name}',
      child: const Center(
        child: Text('Aquí anirà la funcionalitat d’objectius.'),
      ),
    );
  }
}