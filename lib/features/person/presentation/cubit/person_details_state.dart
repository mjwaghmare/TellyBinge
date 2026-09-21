import 'package:flutter/foundation.dart';

@immutable
sealed class PersonDetailsState {
  const PersonDetailsState();
}

class PersonDetailsInitial extends PersonDetailsState {
  const PersonDetailsInitial();
}

class PersonDetailsLoading extends PersonDetailsState {
  const PersonDetailsLoading();
}

class PersonDetailsSuccess extends PersonDetailsState {
  final Map<String, dynamic> person;
  final List<Map<String, dynamic>> allWorks;
  final List<Map<String, dynamic>> displayedWorks;
  final String selectedFilter; // 'all', 'movie', 'tv'

  const PersonDetailsSuccess({
    required this.person,
    required this.allWorks,
    required this.displayedWorks,
    this.selectedFilter = 'all',
  });

  int get movieCount =>
      allWorks.where((w) => w['media_type'] == 'movie').length;
  int get tvCount => allWorks.where((w) => w['media_type'] == 'tv').length;
  int get totalCount => allWorks.length;

  PersonDetailsSuccess copyWith({
    Map<String, dynamic>? person,
    List<Map<String, dynamic>>? allWorks,
    List<Map<String, dynamic>>? displayedWorks,
    String? selectedFilter,
  }) {
    return PersonDetailsSuccess(
      person: person ?? this.person,
      allWorks: allWorks ?? this.allWorks,
      displayedWorks: displayedWorks ?? this.displayedWorks,
      selectedFilter: selectedFilter ?? this.selectedFilter,
    );
  }

  static bool _listMapEquals(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!mapEquals(a[i], b[i])) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PersonDetailsSuccess &&
        mapEquals(other.person, person) &&
        _listMapEquals(other.allWorks, allWorks) &&
        _listMapEquals(other.displayedWorks, displayedWorks) &&
        other.selectedFilter == selectedFilter;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(person.keys),
        Object.hashAll(person.values),
        allWorks.length,
        displayedWorks.length,
        selectedFilter,
      );
}

class PersonDetailsError extends PersonDetailsState {
  final String message;

  const PersonDetailsError(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonDetailsError && other.message == message;

  @override
  int get hashCode => message.hashCode;
}
