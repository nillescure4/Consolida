import 'package:flutter/material.dart';

import '../data/fake_subjects.dart';
import '../models/subject.dart';
import '../services/auth_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/subject_card.dart';
import 'subject_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final List<Subject> subjects = List.from(fakeSubjects);

  void _createSubject() {
    final newSubject = Subject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Nova assignatura ${subjects.length + 1}',
    );

    setState(() {
      subjects.add(newSubject);
    });
  }

  void _openSubject(Subject subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubjectPage(subject: subject),
      ),
    );
  }

  Future<void> _signOut() async {
    await _authService.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Les meves assignatures',
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: _createSubject,
        child: const Icon(Icons.add),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: subjects.isEmpty
            ? const Center(
                child: Text('Encara no has creat cap assignatura.'),
              )
            : ListView.builder(
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return SubjectCard(
                    subject: subject,
                    onTap: () => _openSubject(subject),
                  );
                },
              ),
      ),
    );
  }
}