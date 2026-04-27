import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../widgets/app_scaffold.dart';

class ImportPage extends StatelessWidget {
  final Subject subject;

  const ImportPage({
    super.key,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Importar - ${subject.name}',
      child: const Center(
        child: Text('Aquí anirà la funcionalitat d’importació.'),
      ),
    );
  }
}