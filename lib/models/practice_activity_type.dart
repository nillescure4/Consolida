enum PracticeActivityType {
  summary,
  flashcards,
  multipleChoice,
  openQuestions,
  exercises,
  errorTest,
  timer,
}

extension PracticeActivityTypeExtension on PracticeActivityType {
  String get title {
    switch (this) {
      case PracticeActivityType.summary:
        return 'Llegir resum';
      case PracticeActivityType.flashcards:
        return 'Flashcards';
      case PracticeActivityType.multipleChoice:
        return 'Preguntes tipus test';
      case PracticeActivityType.openQuestions:
        return 'Preguntes obertes';
      case PracticeActivityType.exercises:
        return 'Exercicis';
      case PracticeActivityType.errorTest:
        return 'Test d’errors';
      case PracticeActivityType.timer:
        return 'Temporitzador';
    }
  }

  String get description {
    switch (this) {
      case PracticeActivityType.summary:
        return 'Llegeix un resum generat a partir del material importat.';
      case PracticeActivityType.flashcards:
        return 'Practica amb targetes de pregunta i resposta.';
      case PracticeActivityType.multipleChoice:
        return 'Respon preguntes amb diferents opcions.';
      case PracticeActivityType.openQuestions:
        return 'Practica preguntes obertes i compara la resposta.';
      case PracticeActivityType.exercises:
        return 'Resol exercicis detectats en els documents importats.';
      case PracticeActivityType.errorTest:
        return 'Repeteix les preguntes que has fallat anteriorment.';
      case PracticeActivityType.timer:
        return 'Rellotge lliure per practicar pel teu compte.';
    }
  }
}