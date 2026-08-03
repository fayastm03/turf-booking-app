import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/turf_repository.dart';
import '../domain/turf_models.dart';
import '../../../core/storage/local_storage.dart';

// ==========================================
// STATES
// ==========================================
abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchLoaded extends SearchState {
  final List<Turf> results;
  final List<String> recentSearches;
  final String query;
  final String? selectedCityId;
  final String? selectedSportId;
  final String? selectedCourtType; // "Indoor", "Outdoor", or null
  final String sortBy; // "price_asc", "price_desc", "rating_desc", "name_asc"

  const SearchLoaded({
    required this.results,
    required this.recentSearches,
    this.query = '',
    this.selectedCityId,
    this.selectedSportId,
    this.selectedCourtType,
    this.sortBy = 'name_asc',
  });

  SearchLoaded copyWith({
    List<Turf>? results,
    List<String>? recentSearches,
    String? query,
    String? selectedCityId,
    String? selectedSportId,
    String? selectedCourtType,
    String? sortBy,
    bool clearCity = false,
    bool clearSport = false,
    bool clearType = false,
  }) {
    return SearchLoaded(
      results: results ?? this.results,
      recentSearches: recentSearches ?? this.recentSearches,
      query: query ?? this.query,
      selectedCityId: clearCity
          ? null
          : (selectedCityId ?? this.selectedCityId),
      selectedSportId: clearSport
          ? null
          : (selectedSportId ?? this.selectedSportId),
      selectedCourtType: clearType
          ? null
          : (selectedCourtType ?? this.selectedCourtType),
      sortBy: sortBy ?? this.sortBy,
    );
  }

  @override
  List<Object?> get props => [
    results,
    recentSearches,
    query,
    selectedCityId,
    selectedSportId,
    selectedCourtType,
    sortBy,
  ];
}

class SearchFailure extends SearchState {
  final String error;

  const SearchFailure(this.error);

  @override
  List<Object?> get props => [error];
}

// ==========================================
// EVENTS
// ==========================================
abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class LoadSearchInit extends SearchEvent {}

class SearchQuerySubmitted extends SearchEvent {
  final String query;

  const SearchQuerySubmitted(this.query);

  @override
  List<Object?> get props => [query];
}

class UpdateFilters extends SearchEvent {
  final String? cityId;
  final String? sportId;
  final String? courtType;
  final String? sortBy;

  const UpdateFilters({this.cityId, this.sportId, this.courtType, this.sortBy});

  @override
  List<Object?> get props => [cityId, sportId, courtType, sortBy];
}

class ClearAllFilters extends SearchEvent {}

class ClearRecentSearchesRequested extends SearchEvent {}

// ==========================================
// BLOC
// ==========================================
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final TurfRepository _turfRepository;
  final LocalStorage _localStorage;
  static const String _recentSearchesKey = 'recent_searches';

  SearchBloc(this._turfRepository, this._localStorage)
    : super(SearchInitial()) {
    on<LoadSearchInit>(_onLoadSearchInit);
    on<SearchQuerySubmitted>(_onSearchQuerySubmitted);
    on<UpdateFilters>(_onUpdateFilters);
    on<ClearAllFilters>(_onClearAllFilters);
    on<ClearRecentSearchesRequested>(_onClearRecentSearches);
  }

  Future<void> _onLoadSearchInit(
    LoadSearchInit event,
    Emitter<SearchState> emit,
  ) async {
    emit(SearchLoading());
    try {
      final recent = _getRecentSearches();
      final turfs = await _turfRepository.getTurfs();
      emit(SearchLoaded(results: turfs, recentSearches: recent));
    } catch (e) {
      emit(SearchFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onSearchQuerySubmitted(
    SearchQuerySubmitted event,
    Emitter<SearchState> emit,
  ) async {
    final currentState = state;
    if (currentState is SearchLoaded) {
      emit(SearchLoading());
      try {
        final query = event.query.trim();
        // Add query to recent searches
        final recent = List<String>.from(currentState.recentSearches);
        if (query.isNotEmpty && !recent.contains(query)) {
          recent.insert(0, query);
          if (recent.length > 5) recent.removeLast(); // Keep top 5
          await _localStorage.writeSetting(_recentSearchesKey, recent);
        }

        final turfs = await _turfRepository.getTurfs(
          cityId: currentState.selectedCityId,
          sportId: currentState.selectedSportId,
          search: query.isEmpty ? null : query,
        );

        // Apply local filtering for court type if selected
        var filteredTurfs = turfs;
        if (currentState.selectedCourtType != null) {
          filteredTurfs = turfs.where((turf) {
            return turf.courts.any(
              (court) =>
                  court.type.toLowerCase() ==
                  currentState.selectedCourtType!.toLowerCase(),
            );
          }).toList();
        }

        // Apply local sorting
        _sortTurfs(filteredTurfs, currentState.sortBy);

        emit(
          currentState.copyWith(
            results: filteredTurfs,
            recentSearches: recent,
            query: query,
          ),
        );
      } catch (e) {
        emit(SearchFailure(e.toString().replaceAll('Exception: ', '')));
      }
    }
  }

  Future<void> _onUpdateFilters(
    UpdateFilters event,
    Emitter<SearchState> emit,
  ) async {
    final currentState = state;
    if (currentState is SearchLoaded) {
      emit(SearchLoading());
      try {
        final cityId = event.cityId == 'all'
            ? null
            : (event.cityId ?? currentState.selectedCityId);
        final sportId = event.sportId == 'all'
            ? null
            : (event.sportId ?? currentState.selectedSportId);
        final courtType = event.courtType == 'all'
            ? null
            : (event.courtType ?? currentState.selectedCourtType);
        final sortBy = event.sortBy ?? currentState.sortBy;

        final turfs = await _turfRepository.getTurfs(
          cityId: cityId,
          sportId: sportId,
          search: currentState.query.isEmpty ? null : currentState.query,
        );

        var filteredTurfs = turfs;
        if (courtType != null) {
          filteredTurfs = turfs.where((turf) {
            return turf.courts.any(
              (court) => court.type.toLowerCase() == courtType.toLowerCase(),
            );
          }).toList();
        }

        _sortTurfs(filteredTurfs, sortBy);

        emit(
          currentState.copyWith(
            results: filteredTurfs,
            selectedCityId: cityId,
            selectedSportId: sportId,
            selectedCourtType: courtType,
            sortBy: sortBy,
            clearCity: event.cityId == 'all',
            clearSport: event.sportId == 'all',
            clearType: event.courtType == 'all',
          ),
        );
      } catch (e) {
        emit(SearchFailure(e.toString().replaceAll('Exception: ', '')));
      }
    }
  }

  Future<void> _onClearAllFilters(
    ClearAllFilters event,
    Emitter<SearchState> emit,
  ) async {
    final currentState = state;
    if (currentState is SearchLoaded) {
      emit(SearchLoading());
      try {
        final turfs = await _turfRepository.getTurfs(
          search: currentState.query.isEmpty ? null : currentState.query,
        );

        emit(
          currentState.copyWith(
            results: turfs,
            clearCity: true,
            clearSport: true,
            clearType: true,
            sortBy: 'name_asc',
          ),
        );
      } catch (e) {
        emit(SearchFailure(e.toString().replaceAll('Exception: ', '')));
      }
    }
  }

  Future<void> _onClearRecentSearches(
    ClearRecentSearchesRequested event,
    Emitter<SearchState> emit,
  ) async {
    final currentState = state;
    if (currentState is SearchLoaded) {
      await _localStorage.deleteSetting(_recentSearchesKey);
      emit(currentState.copyWith(recentSearches: []));
    }
  }

  List<String> _getRecentSearches() {
    final recent = _localStorage.readSetting(_recentSearchesKey);
    if (recent == null) return [];
    return List<String>.from(recent);
  }

  void _sortTurfs(List<Turf> turfs, String sortBy) {
    switch (sortBy) {
      case 'price_asc':
        turfs.sort((a, b) => a.basePricePerHour.compareTo(b.basePricePerHour));
        break;
      case 'price_desc':
        turfs.sort((a, b) => b.basePricePerHour.compareTo(a.basePricePerHour));
        break;
      case 'rating_desc':
        // rating is hardcoded to 4.8 / 4.9 for now, so fallback to name sort
        turfs.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'name_asc':
      default:
        turfs.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
  }
}
