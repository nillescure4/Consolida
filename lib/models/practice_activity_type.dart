enum PracticeActivityType {
  flashcards,
  summary,
  multipleChoice,
  openQuestions,
  exercises,
  errorTest,
}

extension PracticeActivityTypeExtension on PracticeActivityType {
  String get title {
    switch (this) {
      case PracticeActivityType.flashcards:
        return 'Flashcards';
      case PracticeActivityType.summary:
        return 'Llegir resum';
      case PracticeActivityType.multipleChoice:
        return 'Preguntes tipus test';
      case PracticeActivityType.openQuestions:
        return 'Preguntes obertes';
      case PracticeActivityType.exercises:
        return 'Exercicis amb solució';
      case PracticeActivityType.errorTest:
        return 'Test d’errors';
    }
  }

  String get description {
    switch (this) {
      case PracticeActivityType.flashcards:
        return 'Practica amb targetes generades només del material importat.';
      case PracticeActivityType.summary:
        return 'Llegeix un resum generat només a partir del material importat.';
      case PracticeActivityType.multipleChoice:
        return 'Respon preguntes tipus test basades només en el contingut importat.';
      case PracticeActivityType.openQuestions:
        return 'Respon preguntes obertes per practicar recuperació activa.';
      case PracticeActivityType.exercises:
        return 'Resol exercicis amb solució basats en el material importat.';
      case PracticeActivityType.errorTest:
        return 'Repeteix preguntes tipus test que vas fallar.';
    }
  }
}