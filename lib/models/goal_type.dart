enum GoalType {
  shortTerm,
  mediumTerm,
  longTerm,
}

extension GoalTypeExtension on GoalType {
  String get value {
    switch (this) {
      case GoalType.shortTerm:
        return 'shortTerm';
      case GoalType.mediumTerm:
        return 'mediumTerm';
      case GoalType.longTerm:
        return 'longTerm';
    }
  }

  String get label {
    switch (this) {
      case GoalType.shortTerm:
        return 'Consolidació a curt termini (fins a 6 mesos)';
      case GoalType.mediumTerm:
        return 'Consolidació a mitjà termini (més de 6 mesos)';
      case GoalType.longTerm:
        return 'Consolidació a llarg termini (temps indefinit)';
    }
  }

  static GoalType fromValue(String value) {
    switch (value) {
      case 'shortTerm':
        return GoalType.shortTerm;
      case 'mediumTerm':
        return GoalType.mediumTerm;
      case 'longTerm':
        return GoalType.longTerm;
      default:
        return GoalType.shortTerm;
    }
  }
}