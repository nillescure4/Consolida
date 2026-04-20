import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../widgets/app_scaffold.dart';

class VisualizePage extends StatelessWidget {
  final Subject subject;

  const VisualizePage({
    super.key,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Visualitzar - ${subject.name}',
      child: const Center(
        child: Text('Aquí anirà la funcionalitat de visualització.'),
      ),
    );
  }
}