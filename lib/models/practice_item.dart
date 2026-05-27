import 'practice_activity_type.dart';

class PracticeItem {
  final String? id;
  final PracticeActivityType type;
  final String question;
  final String answer;
  final List<String> options;
  final String sourceFileName;

  const PracticeItem({
    this.id,
    required this.type,
    required this.question,
    required this.answer,
    this.options = const [],
    this.sourceFileName = '',
  });

  PracticeItem copyWith({
    String? id,
    PracticeActivityType? type,
    String? question,
    String? answer,
    List<String>? options,
    String? sourceFileName,
  }) {
    return PracticeItem(
      id: id ?? this.id,
      type: type ?? this.type,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      options: options ?? this.options,
      sourceFileName: sourceFileName ?? this.sourceFileName,
    );
  }
}