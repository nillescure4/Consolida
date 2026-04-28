import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/subject.dart';
import '../services/auth_service.dart';
import '../services/subject_service.dart';
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
  final SubjectService _subjectService = SubjectService();

  final TextEditingController _subjectController = TextEditingController();

  Future<void> createSubjectDialog() async {
    _subjectController.clear();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nova assignatura'),
          content: TextField(
            controller: _subjectController,
            decoration: const InputDecoration(
              labelText: 'Nom',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = _subjectController.text.trim();

                if (name.isEmpty) return;

                await _subjectService.createSubject(name);

                if (!context.mounted) return;

                Navigator.pop(context);
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  void openSubject(Subject subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubjectPage(subject: subject),
      ),
    );
  }

  Future<void> signOut() async {
    final user = FirebaseAuth.instance.currentUser;

    final displayName = user?.displayName?.trim();
    final email = user?.email?.trim() ?? '';

    final accountLabel = displayName != null && displayName.isNotEmpty
        ? '$displayName ($email)'
        : email;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar tancament de sessió'),
          content: Text(
            'Vols tancar sessió amb el compte:\n\n$accountLabel?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Tancar sessió'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await _authService.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Les meves assignatures',
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          onPressed: signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: createSubjectDialog,
        child: const Icon(Icons.add),
      ),
      child: StreamBuilder<List<Subject>>(
        stream: _subjectService.getSubjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final subjects = snapshot.data ?? [];

          if (subjects.isEmpty) {
            return const Center(
              child: Text('Encara no tens assignatures'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final subject = subjects[index];

                return StreamBuilder<bool>(
                  stream: _subjectService.hasPendingPracticeToday(subject.id),
                  builder: (context, practiceSnapshot) {
                    final hasPendingPractice =
                        practiceSnapshot.data ?? false;

                    return StreamBuilder<bool>(
                      stream: _subjectService.hasNoObjectives(subject.id),
                      builder: (context, objectivesSnapshot) {
                        final hasNoObjectives =
                            objectivesSnapshot.data ?? false;

                        return SubjectCard(
                          subject: subject,
                          hasPendingPracticeToday: hasPendingPractice,
                          hasNoObjectives: hasNoObjectives,
                          onTap: () => openSubject(subject),
                        );
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}