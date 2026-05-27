class AiFlashcard {
  final String question;
  final String answer;

  const AiFlashcard({
    required this.question,
    required this.answer,
  });

  factory AiFlashcard.fromJson(Map<String, dynamic> json) {
    return AiFlashcard(
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'answer': answer,
    };
  }
}

class AiDocumentSummary {
  final String fileName;
  final String summary;

  const AiDocumentSummary({
    required this.fileName,
    required this.summary,
  });

  factory AiDocumentSummary.fromJson(Map<String, dynamic> json) {
    return AiDocumentSummary(
      fileName: json['fileName'] ?? '',
      summary: json['summary'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'summary': summary,
    };
  }
}

class AiMultipleChoiceQuestion {
  final String question;
  final List<String> options;
  final String correctAnswer;

  const AiMultipleChoiceQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
  });

  factory AiMultipleChoiceQuestion.fromJson(Map<String, dynamic> json) {
    return AiMultipleChoiceQuestion(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
    };
  }
}

class AiOpenQuestion {
  final String question;
  final String suggestedAnswer;

  const AiOpenQuestion({
    required this.question,
    required this.suggestedAnswer,
  });

  factory AiOpenQuestion.fromJson(Map<String, dynamic> json) {
    return AiOpenQuestion(
      question: json['question'] ?? '',
      suggestedAnswer: json['suggestedAnswer'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'suggestedAnswer': suggestedAnswer,
    };
  }
}

class AiExercise {
  final String sourceFileName;
  final String exercise;
  final String solution;
  final bool solutionGeneratedByAi;

  const AiExercise({
    required this.sourceFileName,
    required this.exercise,
    required this.solution,
    required this.solutionGeneratedByAi,
  });

  factory AiExercise.fromJson(Map<String, dynamic> json) {
    return AiExercise(
      sourceFileName: json['sourceFileName'] ?? '',
      exercise: json['exercise'] ?? '',
      solution: json['solution'] ?? '',
      solutionGeneratedByAi: json['solutionGeneratedByAi'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sourceFileName': sourceFileName,
      'exercise': exercise,
      'solution': solution,
      'solutionGeneratedByAi': solutionGeneratedByAi,
    };
  }
}

class AiGeneratedActivity {
  final String summary;
  final List<AiDocumentSummary> documentSummaries;
  final List<AiFlashcard> flashcards;
  final List<AiMultipleChoiceQuestion> multipleChoiceQuestions;
  final List<AiOpenQuestion> openQuestions;
  final List<AiExercise> exercises;

  const AiGeneratedActivity({
    required this.summary,
    required this.documentSummaries,
    required this.flashcards,
    required this.multipleChoiceQuestions,
    required this.openQuestions,
    required this.exercises,
  });

  factory AiGeneratedActivity.fromJson(Map<String, dynamic> json) {
    return AiGeneratedActivity(
      summary: json['summary'] ?? '',
      documentSummaries: (json['documentSummaries'] as List? ?? [])
          .map(
            (item) => AiDocumentSummary.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      flashcards: (json['flashcards'] as List? ?? [])
          .map(
            (item) => AiFlashcard.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      multipleChoiceQuestions:
          (json['multipleChoiceQuestions'] as List? ?? [])
              .map(
                (item) => AiMultipleChoiceQuestion.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      openQuestions: (json['openQuestions'] as List? ?? [])
          .map(
            (item) => AiOpenQuestion.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      exercises: (json['exercises'] as List? ?? [])
          .map(
            (item) => AiExercise.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((exercise) => exercise.exercise.trim().isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'summary': summary,
      'documentSummaries':
          documentSummaries.map((item) => item.toMap()).toList(),
      'flashcards': flashcards.map((item) => item.toMap()).toList(),
      'multipleChoiceQuestions':
          multipleChoiceQuestions.map((item) => item.toMap()).toList(),
      'openQuestions': openQuestions.map((item) => item.toMap()).toList(),
      'exercises': exercises.map((item) => item.toMap()).toList(),
    };
  }
}