import 'package:flutter/material.dart';

import '../models/goal_type.dart';
import '../models/practice_session.dart';
import '../models/study_goal.dart';
import '../models/subject.dart';
import '../services/objective_service.dart';
import '../utils/spaced_repetition.dart';
import '../widgets/app_scaffold.dart';

class ObjectivesPage extends StatefulWidget {
  final Subject subject;

  const ObjectivesPage({
    super.key,
    required this.subject,
  });

  @override
  State<ObjectivesPage> createState() => _ObjectivesPageState();
}

class _ObjectivesPageState extends State<ObjectivesPage> {
  final ObjectiveService _objectiveService = ObjectiveService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _customMinutesController =
      TextEditingController();

  GoalType _selectedType = GoalType.shortTerm;
  DateTime? _targetDate;
  int _selectedMinutes = 30;
  bool _useCustomMinutes = false;

  final List<int> _minuteOptions = [
    10,
    15,
    20,
    25,
    30,
  ];

  Future<void> _selectTargetDate() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );

    if (pickedDate == null) return;

    setState(() {
      _targetDate = pickedDate;
    });
  }

  int _getMinutes() {
    if (!_useCustomMinutes) {
      return _selectedMinutes;
    }

    return int.tryParse(_customMinutesController.text.trim()) ?? 30;
  }

  String? _validateForm() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      return 'Has d’escriure un nom per a l’objectiu.';
    }

    final minutes = _getMinutes();

    if (minutes <= 0) {
      return 'La durada de la sessió ha de ser positiva.';
    }

    if (_selectedType == GoalType.longTerm) {
      return null;
    }

    if (_targetDate == null) {
      return 'Has de seleccionar una data objectiu.';
    }

    final now = DateTime.now();
    final differenceDays = _targetDate!.difference(now).inDays;

    if (_selectedType == GoalType.shortTerm && differenceDays > 183) {
      return 'Per a curt termini, la data ha de ser fins a 6 mesos.';
    }

    if (_selectedType == GoalType.mediumTerm && differenceDays <= 183) {
      return 'Per a mitjà termini, la data ha de ser de més de 6 mesos.';
    }

    return null;
  }

  Future<void> _createRecommendedPlan() async {
    final error = _validateForm();

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    final title = _titleController.text.trim();
    final minutes = _getMinutes();

    final recommendedDates = generateSpacedPracticeDates(
      type: _selectedType,
      startDate: DateTime.now(),
      targetDate: _targetDate,
      minutesPerSession: minutes,
    );

    final editedDates = await _showRecommendedPlanDialog(
      title: title,
      dates: recommendedDates,
      minutes: minutes,
    );

    if (editedDates == null || editedDates.isEmpty) return;

    final goal = StudyGoal(
      id: '',
      title: title,
      type: _selectedType,
      targetDate: _targetDate,
      minutesPerSession: minutes,
    );

    await _objectiveService.saveGoalWithSessions(
      subjectId: widget.subject.id,
      subjectName: widget.subject.name,
      goal: goal,
      dates: editedDates,
    );

    if (!mounted) return;

    _titleController.clear();
    _customMinutesController.clear();

    setState(() {
      _targetDate = null;
      _selectedMinutes = 30;
      _useCustomMinutes = false;
      _selectedType = GoalType.shortTerm;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pla de pràctica guardat.'),
      ),
    );
  }

  Future<List<DateTime>?> _showRecommendedPlanDialog({
    required String title,
    required List<DateTime> dates,
    required int minutes,
  }) async {
    final editableDates = List<DateTime>.from(dates);

    return showDialog<List<DateTime>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> editDate(int index) async {
              final now = DateTime.now();

              final pickedDate = await showDatePicker(
                context: context,
                initialDate: editableDates[index],
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: now.add(const Duration(days: 3650)),
              );

              if (pickedDate == null) return;

              setDialogState(() {
                editableDates[index] = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                );

                editableDates.sort((a, b) => a.compareTo(b));
              });
            }

            Future<void> addDate() async {
              final now = DateTime.now();

              final pickedDate = await showDatePicker(
                context: context,
                initialDate: now,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: now.add(const Duration(days: 3650)),
              );

              if (pickedDate == null) return;

              setDialogState(() {
                editableDates.add(
                  DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                  ),
                );

                editableDates.sort((a, b) => a.compareTo(b));
              });
            }

            void deleteDate(int index) {
              setDialogState(() {
                editableDates.removeAt(index);
              });
            }

            return AlertDialog(
              title: const Text('Pla recomanat'),
              content: SizedBox(
                width: double.maxFinite,
                height: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    const SizedBox(height: 12),
                    Text('Durada per sessió: $minutes min'),
                    const SizedBox(height: 12),
                    const Text('Pots editar, afegir o eliminar sessions:'),
                    const SizedBox(height: 8),
                    Expanded(
                      child: editableDates.isEmpty
                          ? const Center(
                              child: Text('No hi ha cap sessió.'),
                            )
                          : ListView.builder(
                              itemCount: editableDates.length,
                              itemBuilder: (context, index) {
                                final date = editableDates[index];

                                return Card(
                                  child: ListTile(
                                    leading: Text('${index + 1}'),
                                    title: Text(
                                      '${date.day}/${date.month}/${date.year}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () => editDate(index),
                                          icon: const Icon(Icons.edit),
                                        ),
                                        IconButton(
                                          onPressed: () => deleteDate(index),
                                          icon: const Icon(Icons.delete),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: addDate,
                      icon: const Icon(Icons.add),
                      label: const Text('Afegir sessió'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, null);
                  },
                  child: const Text('Cancel·lar'),
                ),
                ElevatedButton(
                  onPressed: editableDates.isEmpty
                      ? null
                      : () {
                          Navigator.pop(
                            context,
                            List<DateTime>.from(editableDates),
                          );
                        },
                  child: const Text('Acceptar pla'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteGoal(StudyGoal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Esborrar objectiu'),
          content: Text(
            'Segur que vols esborrar "${goal.title}" i totes les seves sessions?',
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
              child: const Text('Esborrar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await _objectiveService.deleteGoal(
      subjectId: widget.subject.id,
      subjectName: widget.subject.name,
      goalId: goal.id,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customMinutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Objectius - ${widget.subject.name}',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nou objectiu',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nom de l’objectiu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<GoalType>(
              value: _selectedType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tipus d’objectiu',
                border: OutlineInputBorder(),
              ),
              items: GoalType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.label),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedType = value;

                  if (_selectedType == GoalType.longTerm) {
                    _targetDate = null;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedType != GoalType.longTerm)
              OutlinedButton(
                onPressed: _selectTargetDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    _targetDate == null
                        ? 'Seleccionar data objectiu'
                        : 'Data objectiu: ${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _useCustomMinutes ? -1 : _selectedMinutes,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Durada de la sessió',
                border: OutlineInputBorder(),
              ),
              items: [
                ..._minuteOptions.map(
                  (minutes) => DropdownMenuItem(
                    value: minutes,
                    child: Text('$minutes minuts'),
                  ),
                ),
                const DropdownMenuItem(
                  value: -1,
                  child: Text('Personalitzada'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  if (value == -1) {
                    _useCustomMinutes = true;
                  } else {
                    _useCustomMinutes = false;
                    _selectedMinutes = value;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            if (_useCustomMinutes)
              TextField(
                controller: _customMinutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minuts personalitzats',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _createRecommendedPlan,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Generar pla recomanat'),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Objectius creats',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<StudyGoal>>(
              stream: _objectiveService.getGoals(widget.subject.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final goals = snapshot.data ?? [];

                if (goals.isEmpty) {
                  return const Text('Encara no hi ha objectius.');
                }

                return Column(
                  children: goals.map((goal) {
                    return Card(
                      child: ListTile(
                        title: Text(goal.title),
                        subtitle: Text(
                          '${goal.type.label} · ${goal.minutesPerSession} min',
                        ),
                        trailing: IconButton(
                          onPressed: () => _deleteGoal(goal),
                          icon: const Icon(Icons.delete),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Sessions programades',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<PracticeSession>>(
              stream: _objectiveService.getPracticeSessions(widget.subject.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final sessions = snapshot.data ?? [];

                if (sessions.isEmpty) {
                  return const Text('Encara no hi ha sessions programades.');
                }

                return Column(
                  children: sessions.map((session) {
                    final date = session.scheduledDate;

                    return Card(
                      child: ListTile(
                        title: Text(session.goalTitle),
                        subtitle: Text(
                          '${date.day}/${date.month}/${date.year} · ${session.durationMinutes} min · ${session.status}',
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}