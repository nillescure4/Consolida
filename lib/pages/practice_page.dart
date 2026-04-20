import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../widgets/app_scaffold.dart';

class PracticePage extends StatelessWidget {
  final Subject subject;

  const PracticePage({
    super.key,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Practicar - ${subject.name}',
      child: const Center(
        child: Text('Aquí anirà la funcionalitat de pràctica.'),
      ),
    );
  }
}