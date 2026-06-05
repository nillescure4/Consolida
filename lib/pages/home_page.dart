import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/subject.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../pages/subject_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  final TextEditingController _subjectController = TextEditingController();

  int _refreshCounter = 0;

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No hi ha usuari autenticat.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _subjectsCollection {
    return _firestore.collection('users').doc(_userId).collection('subjects');
  }

  void _refreshHome() {
    if (!mounted) return;

    setState(() {
      _refreshCounter++;
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream() {
    return _firestore.collection('users').doc(_userId).snapshots();
  }

  Stream<List<Subject>> _subjectsStream() {
    return _subjectsCollection
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList(),
        );
  }

  Future<_HomeData> _loadHomeData(List<Subject> subjects) async {
    final sessions = <_HomeSession>[];
    final subjectStates = <String, _SubjectHomeState>{};

    for (final subject in subjects) {
      final materialSnapshot = await _subjectsCollection
          .doc(subject.id)
          .collection('processedMaterials')
          .limit(1)
          .get();

      final goalsSnapshot =
          await _subjectsCollection.doc(subject.id).collection('goals').get();

      final sessionsSnapshot = await _subjectsCollection
          .doc(subject.id)
          .collection('practiceSessions')
          .where('status', isEqualTo: 'pending')
          .get();

      final pendingSessions = <_HomeSession>[];

      for (final doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final scheduledDateRaw = data['scheduledDate'];

        if (scheduledDateRaw is! Timestamp) continue;

        final session = _HomeSession(
          subjectName: subject.name,
          goalTitle: data['goalTitle'] ?? 'Objectiu',
          scheduledDate: scheduledDateRaw.toDate(),
          durationMinutes: data['durationMinutes'] is int
              ? data['durationMinutes'] as int
              : 30,
        );

        sessions.add(session);
        pendingSessions.add(session);
      }

      final dueSessions = pendingSessions.where((session) {
        return _isDue(session.scheduledDate);
      }).toList();

      String? warningMessage;

      if (materialSnapshot.docs.isEmpty) {
        warningMessage = 'Falta importar material';
      } else if (goalsSnapshot.docs.isEmpty) {
        warningMessage = 'Falta crear un objectiu';
      } else if (dueSessions.isNotEmpty) {
        warningMessage =
            'Tens ${dueSessions.length} pràctica${dueSessions.length == 1 ? '' : 's'} pendent${dueSessions.length == 1 ? '' : 's'}';
      }

      subjectStates[subject.id] = _SubjectHomeState(
        warningMessage: warningMessage,
      );
    }

    sessions.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    return _HomeData(
      sessions: sessions,
      subjectStates: subjectStates,
    );
  }

  Future<void> _showUserGuide() async {

    Widget section(String title, List<String> paragraphs) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < paragraphs.length; i++) ...[
                    Text(
                      paragraphs[i],
                      textAlign: TextAlign.justify,
                      style: const TextStyle(
                        height: 1.4,
                      ),
                    ),
                    if (i < paragraphs.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Guia d’ús'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                section(
                  '1. Crea una assignatura',
                  [
                    'Comença creant una assignatura amb el botó +. Cada assignatura funciona com un espai independent amb els seus propis materials, objectius, pràctiques i progrés.',
                  ],
                ),
                section(
                  '2. Importa material',
                  [
                    'Dins de cada assignatura, ves a Importar i afegeix apunts, esquemes, resums o qualsevol material que vulguis consolidar. També és recomanable importar documents amb exercicis perquè després puguis practicar-los com a exercicis importats.',
                  ],
                ),
                section(
                  '3. Fixa objectius',
                  [
                    'Quan ja tinguis material importat, ves a Objectius. Allà pots definir si vols estudiar a curt termini, mitjà termini o llarg termini. Consolida generarà una proposta de sessions segons el temps disponible i la durada de pràctica que triïs.',
                    'Abans de guardar l’objectiu, pots revisar les sessions planificades, modificar-ne les dates, afegir sessions o eliminar-ne, sempre respectant la data límit de l’objectiu.',
                  ],
                ),
                section(
                  '4. Practica',
                  [
                    'A Practicar trobaràs diferents modalitats: resums, targetes de memòria, preguntes tipus test, preguntes obertes, exercicis importats, test d’errors i temporitzador. Les sessions pendents consumeixen el temps planificat; si no tens cap sessió pendent, pots practicar igualment com a pràctica extra.',
                    'Quan fallis preguntes, Consolida les guarda automàticament al Test d’errors perquè les puguis repetir més endavant. Quan les resolguis correctament, deixaran de quedar pendents.',
                    'Si importes nou material o vols actualitzar les activitats, pots utilitzar l’opció Regenerar activitats amb IA. Aquesta acció substituirà les activitats actuals per unes de noves generades a partir dels documents importats.',
                  ],
                ),
                section(
                  '5. Consulta el progrés',
                  [
                    'A Veure progrés pots veure sessions completades, sessions pendents, percentatges d’error, rendiment per modalitat i una comparació amb la corba de l’oblit.',
                  ],
                ),
                section(
                  '6. Sessions pendents i properes sessions',
                  [
                    'A la pàgina principal pots veure si tens sessions pendents acumulades i les properes sessions programades. També veuràs avisos dins de cada assignatura si falta importar material, crear objectius o practicar.',
                  ],
                ),
              ],


            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entès'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tancar sessió'),
          content: const Text('Segur que vols tancar la sessió?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
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

  Future<void> _addSubject() async {
    _subjectController.clear();

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nova assignatura'),
          content: TextField(
            controller: _subjectController,
            decoration: const InputDecoration(
              labelText: 'Nom de l’assignatura',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _subjectController.text.trim());
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;

    await _subjectsCollection.add({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _refreshHome();
  }

  Future<void> _openSubject(Subject subject) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubjectPage(subject: subject),
      ),
    );

    _refreshHome();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isDue(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(date.year, date.month, date.day);

    return sessionDay.isBefore(today) || sessionDay.isAtSameMomentAs(today);
  }

  String _getUserName(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    final firebaseUser = _auth.currentUser;

    final firestoreName = data?['name'];
    final displayName = firebaseUser?.displayName;
    final email = firebaseUser?.email;

    if (firestoreName is String && firestoreName.trim().isNotEmpty) {
      return firestoreName.trim();
    }

    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }

    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'usuari';
  }

  Widget _buildPendingSessionsCard(List<_HomeSession> sessions) {
    final dueSessions = sessions.where((session) {
      return _isDue(session.scheduledDate);
    }).toList();

    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          leading: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.primary,
            ),
          ),
          title: const Text(
            'Sessions pendents',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          subtitle: Text(
            dueSessions.isEmpty
                ? 'No tens cap pràctica pendent avui.'
                : 'Tens ${dueSessions.length} pràctica${dueSessions.length == 1 ? '' : 's'} pendent${dueSessions.length == 1 ? '' : 's'}.',
          ),
          children: [
            if (dueSessions.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Quan tinguis una sessió pendent, apareixerà aquí.'),
              )
            else
              ...dueSessions.map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${session.subjectName} · ${session.goalTitle}\n${_formatDate(session.scheduledDate)} · ${session.durationMinutes} min',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectsSection({
    required List<Subject> subjects,
    required Map<String, _SubjectHomeState> subjectStates,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text(
          'Assignatures',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (subjects.isEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _showUserGuide,
            icon: const Icon(Icons.help_outline),
            label: const Text('Guia d’ús'),
          ),
        ],
        const SizedBox(height: 12),
        if (subjects.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Encara no has creat cap assignatura.'),
            ),
          ),
        ...subjects.map(
          (subject) {
            final warning = subjectStates[subject.id]?.warningMessage;

            return Card(
              child: ListTile(
                title: Text(subject.name),
                subtitle: warning == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                warning,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSubject(subject),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUpcomingSessionsCard(List<_HomeSession> sessions) {
    final upcoming = sessions.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Properes sessions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (upcoming.isEmpty)
              const Text('No hi ha sessions programades.')
            else
              ...upcoming.map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${session.subjectName} · ${session.goalTitle}\n${_formatDate(session.scheduledDate)} · ${session.durationMinutes} min',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _manualRefresh() async {
    _refreshHome();
    await Future.delayed(const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '',
      automaticallyImplyLeading: false,
      actions: [
        TextButton.icon(
          onPressed: _showUserGuide,
          icon: const Icon(Icons.help_outline),
          label: const Text('Guia d’ús'),
        ),
        IconButton(
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: _addSubject,
        child: const Icon(Icons.add),
      ),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userStream(),
        builder: (context, userSnapshot) {
          final userName =
              userSnapshot.hasData ? _getUserName(userSnapshot.data!) : 'usuari';

          return StreamBuilder<List<Subject>>(
            stream: _subjectsStream(),
            builder: (context, subjectsSnapshot) {
              final subjects = subjectsSnapshot.data ?? [];

              return FutureBuilder<_HomeData>(
                key: ValueKey(_refreshCounter),
                future: _loadHomeData(subjects),
                builder: (context, homeSnapshot) {
                  final homeData = homeSnapshot.data ??
                      const _HomeData(
                        sessions: [],
                        subjectStates: {},
                      );

                  return RefreshIndicator(
                    onRefresh: _manualRefresh,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          'Hola, $userName',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Continua consolidant el teu aprenentatge.',
                        ),
                        const SizedBox(height: 18),
                        _buildPendingSessionsCard(homeData.sessions),
                        const SizedBox(height: 18),
                        _buildSubjectsSection(
                          subjects: subjects,
                          subjectStates: homeData.subjectStates,
                        ),
                        const SizedBox(height: 18),
                        _buildUpcomingSessionsCard(homeData.sessions),
                        const SizedBox(height: 80),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _HomeData {
  final List<_HomeSession> sessions;
  final Map<String, _SubjectHomeState> subjectStates;

  const _HomeData({
    required this.sessions,
    required this.subjectStates,
  });
}

class _SubjectHomeState {
  final String? warningMessage;

  const _SubjectHomeState({
    required this.warningMessage,
  });
}

class _HomeSession {
  final String subjectName;
  final String goalTitle;
  final DateTime scheduledDate;
  final int durationMinutes;

  const _HomeSession({
    required this.subjectName,
    required this.goalTitle,
    required this.scheduledDate,
    required this.durationMinutes,
  });
}