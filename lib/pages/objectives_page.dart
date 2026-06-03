import 'package:flutter/material.dart';

import '../models/goal_type.dart';
import '../models/practice_session.dart';
import '../models/study_goal.dart';
import '../models/subject.dart';
import '../services/objective_service.dart';
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
  final TextEditingController _customMinutesController = TextEditingController();

  GoalType _selectedType = GoalType.shortTerm;
  DateTime? _targetDate;
  int _minutesPerSession = 30;
  bool _useCustomMinutes = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _customMinutesController.dispose();
    super.dispose();
  }

  bool get _needsTargetDate => _selectedType != GoalType.longTerm;

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDayMonth(DateTime date) {
    return '${date.day}/${date.month}';
  }

  String _goalTypeText(GoalType type) {
    switch (type) {
      case GoalType.shortTerm:
        return 'Curt termini (≤ 6 mesos)';
      case GoalType.mediumTerm:
        return 'Mitjà termini (> 6 mesos)';
      case GoalType.longTerm:
        return 'Llarg termini (indefinit)';
    }
  }

  int? _currentMinutes() {
    if (!_useCustomMinutes) return _minutesPerSession;

    final value = int.tryParse(_customMinutesController.text.trim());
    if (value == null || value <= 0) return null;

    return value;
  }

  bool _isTargetDateValidForType(DateTime targetDate) {
    final now = _dateOnly(DateTime.now());
    final target = _dateOnly(targetDate);
    final sixMonthsLimit = DateTime(now.year, now.month + 6, now.day);

    switch (_selectedType) {
      case GoalType.shortTerm:
        return !target.isAfter(sixMonthsLimit);
      case GoalType.mediumTerm:
        return target.isAfter(sixMonthsLimit);
      case GoalType.longTerm:
        return true;
    }
  }

  String _targetDateErrorMessage() {
    switch (_selectedType) {
      case GoalType.shortTerm:
        return 'Per a un objectiu de curt termini, la data límit ha de ser com a màxim d’aquí a 6 mesos.';
      case GoalType.mediumTerm:
        return 'Per a un objectiu de mitjà termini, la data límit ha de ser posterior a 6 mesos.';
      case GoalType.longTerm:
        return '';
    }
  }

  DateTime _initialDateForPicker() {
    final now = DateTime.now();

    if (_targetDate != null) return _targetDate!;

    switch (_selectedType) {
      case GoalType.shortTerm:
        return now.add(const Duration(days: 30));
      case GoalType.mediumTerm:
        return DateTime(now.year, now.month + 7, now.day);
      case GoalType.longTerm:
        return now.add(const Duration(days: 365));
    }
  }

  DateTime _firstDateForPicker() {
    final now = DateTime.now();

    switch (_selectedType) {
      case GoalType.shortTerm:
        return now;
      case GoalType.mediumTerm:
        return DateTime(now.year, now.month + 6, now.day + 1);
      case GoalType.longTerm:
        return now;
    }
  }

  DateTime _lastDateForPicker() {
    final now = DateTime.now();

    switch (_selectedType) {
      case GoalType.shortTerm:
        return DateTime(now.year, now.month + 6, now.day);
      case GoalType.mediumTerm:
      case GoalType.longTerm:
        return now.add(const Duration(days: 3650));
    }
  }

  List<DateTime> _generateDates({
    required GoalType type,
    required DateTime startDate,
    DateTime? targetDate,
    required int minutesPerSession,
  }) {
    final start = _dateOnly(startDate);

    if (type == GoalType.longTerm) {
      final end = start.add(const Duration(days: 365));

      final baseDates = [
        start.add(const Duration(days: 18)),
        start.add(const Duration(days: 55)),
        start.add(const Duration(days: 128)),
        start.add(const Duration(days: 255)),
        start.add(const Duration(days: 365)),
      ];

      return _adjustNumberOfSessionsToMinutes(
        baseDates: baseDates,
        start: start,
        end: end,
        minutesPerSession: minutesPerSession,
      );
    }

    if (targetDate == null) return [];

    final end = _dateOnly(targetDate);
    final totalDays = end.difference(start).inDays;

    if (totalDays <= 0) return [start];

    final percentages = type == GoalType.shortTerm
        ? [0.05, 0.15, 0.35, 0.65, 1.0]
        : [0.05, 0.12, 0.25, 0.50, 0.80, 1.0];

    final baseDates = <DateTime>[];

    for (final percentage in percentages) {
      final date = start.add(
        Duration(days: (totalDays * percentage).round()),
      );

      final fixedDate = date.isAfter(end) ? end : date;

      if (!_containsSameDay(baseDates, fixedDate)) {
        baseDates.add(fixedDate);
      }
    }

    return _adjustNumberOfSessionsToMinutes(
      baseDates: baseDates,
      start: start,
      end: end,
      minutesPerSession: minutesPerSession,
    );
  }

  List<DateTime> _adjustNumberOfSessionsToMinutes({
    required List<DateTime> baseDates,
    required DateTime start,
    required DateTime end,
    required int minutesPerSession,
  }) {
    if (minutesPerSession >= 30 || baseDates.isEmpty) return baseDates;

    final multiplier = (30 / minutesPerSession).ceil();
    final desiredCount = baseDates.length * multiplier;
    final totalDays = end.difference(start).inDays;

    if (totalDays <= 0) return baseDates;

    final dates = <DateTime>[];

    for (int i = 1; i <= desiredCount; i++) {
      final ratio = i / desiredCount;
      final date = start.add(
        Duration(days: (totalDays * ratio).round()),
      );

      final fixedDate = date.isAfter(end) ? end : date;

      if (!_containsSameDay(dates, fixedDate)) {
        dates.add(fixedDate);
      }
    }

    return dates;
  }

  bool _containsSameDay(List<DateTime> dates, DateTime date) {
    return dates.any(
      (item) =>
          item.year == date.year &&
          item.month == date.month &&
          item.day == date.day,
    );
  }

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _initialDateForPicker(),
      firstDate: _firstDateForPicker(),
      lastDate: _lastDateForPicker(),
    );

    if (picked == null) return;

    if (!_isTargetDateValidForType(picked)) {
      _showMessage(_targetDateErrorMessage());
      return;
    }

    setState(() {
      _targetDate = picked;
    });
  }

  Future<void> _saveGoal() async {
    final title = _titleController.text.trim();
    final minutes = _currentMinutes();

    if (title.isEmpty) {
      _showMessage('Introdueix el nom de l’objectiu.');
      return;
    }

    if (minutes == null) {
      _showMessage('Introdueix una durada vàlida per a la sessió.');
      return;
    }

    if (_needsTargetDate && _targetDate == null) {
      _showMessage('Selecciona una data límit.');
      return;
    }

    if (_needsTargetDate &&
        _targetDate != null &&
        !_isTargetDateValidForType(_targetDate!)) {
      _showMessage(_targetDateErrorMessage());
      return;
    }

    final proposedDates = _generateDates(
      type: _selectedType,
      startDate: DateTime.now(),
      targetDate: _targetDate,
      minutesPerSession: minutes,
    );

    final acceptedDates = await _openProposedSessionsDialog(
      dates: proposedDates,
      minutes: minutes,
      type: _selectedType,
    );

    if (acceptedDates == null || acceptedDates.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final goal = StudyGoal(
        id: '',
        title: title,
        type: _selectedType,
        targetDate: _targetDate,
        minutesPerSession: minutes,
        createdAt: DateTime.now(),
      );

      await _objectiveService.saveGoalWithSessions(
        subjectId: widget.subject.id,
        subjectName: widget.subject.name,
        goal: goal,
        dates: acceptedDates,
      );

      _titleController.clear();
      _customMinutesController.clear();

      setState(() {
        _selectedType = GoalType.shortTerm;
        _targetDate = null;
        _minutesPerSession = 30;
        _useCustomMinutes = false;
      });

      _showMessage('Objectiu creat correctament.');
    } catch (error) {
      _showMessage('Error creant objectiu: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<List<DateTime>?> _openProposedSessionsDialog({
    required List<DateTime> dates,
    required int minutes,
    required GoalType type,
  }) async {
    final editableDates = List<DateTime>.from(dates)
      ..sort((a, b) => a.compareTo(b));

    return showDialog<List<DateTime>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            Future<void> editDate(int index) async {
              final oldDate = editableDates[index];

              final picked = await showDatePicker(
                context: context,
                initialDate: oldDate,
                firstDate: DateTime.now(),
                lastDate:
                    _targetDate ?? DateTime.now().add(const Duration(days: 3650)),
              );

              if (picked == null) return;

              if (_targetDate != null &&
                  _dateOnly(picked).isAfter(_dateOnly(_targetDate!))) {
                _showMessage('La sessió no pot ser posterior a la data límit.');
                return;
              }

              dialogSetState(() {
                editableDates[index] = picked;
                editableDates.sort((a, b) => a.compareTo(b));
              });
            }

            Future<void> addDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate:
                    _targetDate ?? DateTime.now().add(const Duration(days: 3650)),
              );

              if (picked == null) return;

              if (_targetDate != null &&
                  _dateOnly(picked).isAfter(_dateOnly(_targetDate!))) {
                _showMessage('La sessió no pot ser posterior a la data límit.');
                return;
              }

              dialogSetState(() {
                if (!_containsSameDay(editableDates, picked)) {
                  editableDates.add(picked);
                  editableDates.sort((a, b) => a.compareTo(b));
                }
              });
            }

            return AlertDialog(
              title: const Text('Sessions proposades'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Abans de crear l’objectiu pots modificar, afegir o eliminar sessions.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (type == GoalType.longTerm)
                        const Text(
                          'Per llarg termini es mostren les sessions del primer any. Els anys següents es repetiran els mateixos dies de l’any.',
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 12),
                      ...editableDates.asMap().entries.map(
                        (entry) {
                          final index = entry.key;
                          final date = entry.value;

                          return Card(
                            child: ListTile(
                              title: Text(_formatDate(date)),
                              subtitle: Text('$minutes minuts'),
                              leading: const Icon(Icons.event),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => editDate(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      dialogSetState(() {
                                        editableDates.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel·lar'),
                ),
                ElevatedButton(
                  onPressed: editableDates.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context, editableDates);
                        },
                  child: const Text('Acceptar planificació'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  List<PracticeSession> _sessionsForGoal(
    List<PracticeSession> sessions,
    String goalId,
  ) {
    final result = sessions.where((session) => session.goalId == goalId).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    return result;
  }

  Future<bool> _confirmDeleteSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar sessió'),
          content: const Text(
            'Segur que vols eliminar aquesta sessió? Aquesta acció no es pot desfer.',
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
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
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    return confirm == true;
  }

  Future<void> _openSessionDialog({
    required StudyGoal goal,
    PracticeSession? session,
  }) async {
    DateTime selectedDate = session?.scheduledDate ?? DateTime.now();
    final fixedMinutes = session?.durationMinutes ?? goal.minutesPerSession;

    final result = await showDialog<_SessionDialogResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            final isAfterLimit = goal.targetDate != null &&
                _dateOnly(selectedDate).isAfter(_dateOnly(goal.targetDate!));

            return AlertDialog(
              title: Text(
                session == null ? 'Afegir sessió' : 'Editar sessió',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data de la sessió'),
                    subtitle: Text(_formatDate(selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: goal.targetDate ??
                            DateTime.now().add(
                              const Duration(days: 3650),
                            ),
                      );

                      if (picked == null) return;

                      dialogSetState(() {
                        selectedDate = picked;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Durada'),
                    subtitle: Text('$fixedMinutes minuts'),
                  ),
                  if (session?.isCompleted == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Aquesta sessió ja està completada automàticament.',
                      ),
                    ),
                  if (isAfterLimit)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'La sessió no pot ser posterior a la data límit de l’objectiu.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              actions: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (session != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(
                            context,
                            const _SessionDialogResult(delete: true),
                          );
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar sessió'),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Cancel·lar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isAfterLimit
                                ? null
                                : () {
                                    Navigator.pop(
                                      context,
                                      _SessionDialogResult(
                                        date: selectedDate,
                                      ),
                                    );
                                  },
                            child: const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    if (result.delete && session != null) {
      final confirmed = await _confirmDeleteSession();

      if (!confirmed) return;

      await _objectiveService.deletePracticeSession(
        subjectId: widget.subject.id,
        subjectName: widget.subject.name,
        sessionId: session.id,
      );

      _showMessage('Sessió eliminada correctament.');
      return;
    }

    if (result.date == null) return;

    if (goal.targetDate != null &&
        _dateOnly(result.date!).isAfter(_dateOnly(goal.targetDate!))) {
      _showMessage('La sessió no pot ser posterior a la data límit.');
      return;
    }

    if (session == null) {
      await _objectiveService.addPracticeSession(
        subjectId: widget.subject.id,
        subjectName: widget.subject.name,
        goalId: goal.id,
        goalTitle: goal.title,
        scheduledDate: result.date!,
        durationMinutes: fixedMinutes,
      );
    } else {
      await _objectiveService.updatePracticeSession(
        subjectId: widget.subject.id,
        subjectName: widget.subject.name,
        sessionId: session.id,
        scheduledDate: result.date!,
        durationMinutes: fixedMinutes,
        completed: session.isCompleted,
      );
    }
  }

  Future<void> _deleteGoal(StudyGoal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar objectiu'),
          content: Text(
            'Vols eliminar "${goal.title}" i totes les seves sessions?',
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
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
              child: const Text('Eliminar'),
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

  Widget _buildJustifiedText(String text) {
    return Text(
      text,
      textAlign: TextAlign.justify,
    );
  }

  Widget _buildExplanationTile() {
    return Card(
      child: ExpansionTile(
        title: const Text('Com es decideixen les sessions?'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _buildJustifiedText(
            'Les sessions es decideixen segons el temps disponible fins a l’objectiu. Això es deu a que el gap òptim entre pràctiques augmenta quan augmenta el temps fins a la prova, però proporcionalment és més petit per a objectius llargs (Cepeda et al., 2008). Per això l’app diferencia entre curt termini (≤ 6 mesos), mitjà termini (> 6 mesos) i llarg termini (indefinit).',
          ),
          const SizedBox(height: 8),
          _buildJustifiedText(
            'També s’utilitzen intervals creixents: les primeres pràctiques apareixen més properes i les últimes més separades. Això es deu a que la pràctica amb intervals progressivament més llargs pot ajudar a la consolidació de la memòria (Kang et al., 2014).',
          ),
          const SizedBox(height: 8),
          _buildJustifiedText(
            'La sessió base és de 30 minuts (Khalafi et al., 2024). Si l’usuari tria sessions més curtes, l’app genera més sessions perquè el temps total de pràctica sigui equivalent. Per exemple, una sessió de 15 minuts genera aproximadament el doble de sessions que una de 30 minuts. Si es tria 30 minuts, es manté la planificació base.',
          ),
        ],
      ),
    );
  }

  Widget _buildGoalForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Nou objectiu',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nom de l’objectiu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<GoalType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Tipus d’objectiu',
                border: OutlineInputBorder(),
              ),
              items: GoalType.values
                  .map(
                    (type) => DropdownMenuItem<GoalType>(
                      value: type,
                      child: Text(_goalTypeText(type)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedType = value;
                  _targetDate = null;
                });
              },
            ),
            const SizedBox(height: 12),
            if (_needsTargetDate)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data límit'),
                subtitle: Text(
                  _targetDate == null
                      ? 'Selecciona una data'
                      : _formatDate(_targetDate!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickTargetDate,
              )
            else
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Llarg termini (indefinit)'),
                subtitle: Text(
                  'Es generen sessions d’aquest any i, a partir del segon any, es repeteixen els mateixos dies de l’any.',
                ),
              ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _useCustomMinutes,
              title: const Text('Durada personalitzada'),
              onChanged: (value) {
                setState(() {
                  _useCustomMinutes = value;
                  if (!value) {
                    _customMinutesController.clear();
                  }
                });
              },
            ),
            if (_useCustomMinutes)
              TextField(
                controller: _customMinutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minuts per sessió',
                  border: OutlineInputBorder(),
                ),
              )
            else
              DropdownButtonFormField<int>(
                value: _minutesPerSession,
                decoration: const InputDecoration(
                  labelText: 'Durada de cada sessió',
                  border: OutlineInputBorder(),
                ),
                items: const [10, 15, 20, 25, 30]
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value minuts'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _minutesPerSession = value;
                  });
                },
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveGoal,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Proposar sessions'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard({
    required StudyGoal goal,
    required List<PracticeSession> sessions,
  }) {
    final isLongTerm = goal.type == GoalType.longTerm;
    final createdAt = goal.createdAt ?? DateTime.now();
    final secondYear = createdAt.year + 1;

    final firstYearSessions = isLongTerm
        ? sessions.where((session) {
            final limit = createdAt.add(const Duration(days: 365));
            return !session.scheduledDate.isAfter(limit);
          }).toList()
        : sessions;

    final recurringDays = firstYearSessions
        .map((session) => _formatDayMonth(session.scheduledDate))
        .toSet()
        .toList();

    return Card(
      child: ExpansionTile(
        title: Text(goal.title),
        subtitle: Text(
          '${_goalTypeText(goal.type)} · ${goal.minutesPerSession} min'
          '${goal.targetDate == null ? '' : ' · límit ${_formatDate(goal.targetDate!)}'}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isLongTerm
                        ? 'Sessions d’aquest any'
                        : 'Sessions programades',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Afegir sessió',
                  onPressed: () => _openSessionDialog(goal: goal),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar objectiu',
                  onPressed: () => _deleteGoal(goal),
                ),
              ],
            ),
          ),
          if (firstYearSessions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aquest objectiu encara no té sessions.'),
            ),
          ...firstYearSessions.map(
            (session) => ListTile(
              title: Text(
                '${_formatDate(session.scheduledDate)} · ${session.durationMinutes} min',
              ),
              subtitle: Text(
                session.isCompleted
                    ? 'Completada${session.completedAt == null ? '' : ' el ${_formatDate(session.completedAt!)}'}'
                    : 'Pendent',
              ),
              trailing: Icon(
                session.isCompleted
                    ? Icons.check_circle_outline
                    : Icons.schedule,
              ),
              onTap: () => _openSessionDialog(
                goal: goal,
                session: session,
              ),
            ),
          ),
          if (isLongTerm && recurringDays.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'A partir de l’any $secondYear: ${recurringDays.join(', ')}',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoalsList({
    required List<StudyGoal> goals,
    required List<PracticeSession> sessions,
  }) {
    if (goals.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Encara no hi ha objectius creats.'),
        ),
      );
    }

    return Column(
      children: goals.map((goal) {
        return _buildGoalCard(
          goal: goal,
          sessions: _sessionsForGoal(sessions, goal.id),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Objectius - ${widget.subject.name}',
      child: StreamBuilder<List<StudyGoal>>(
        stream: _objectiveService.getGoals(widget.subject.id),
        builder: (context, goalsSnapshot) {
          final goals = goalsSnapshot.data ?? [];

          return StreamBuilder<List<PracticeSession>>(
            stream: _objectiveService.getPracticeSessions(widget.subject.id),
            builder: (context, sessionsSnapshot) {
              final sessions = sessionsSnapshot.data ?? [];

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildExplanationTile(),
                  const SizedBox(height: 16),
                  _buildGoalForm(),
                  const SizedBox(height: 24),
                  Text(
                    'Sessions programades',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildGoalsList(
                    goals: goals,
                    sessions: sessions,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SessionDialogResult {
  final DateTime? date;
  final bool delete;

  const _SessionDialogResult({
    this.date,
    this.delete = false,
  });
}