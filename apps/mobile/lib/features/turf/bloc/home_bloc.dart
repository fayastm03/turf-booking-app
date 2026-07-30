import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/turf_repository.dart';
import '../domain/turf_models.dart';

// ==========================================
// STATES
// ==========================================
abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<City> cities;
  final List<Sport> sports;
  final List<Turf> turfs;
  final City? selectedCity;
  final Sport? selectedSport;

  const HomeLoaded({
    required this.cities,
    required this.sports,
    required this.turfs,
    this.selectedCity,
    this.selectedSport,
  });

  HomeLoaded copyWith({
    List<City>? cities,
    List<Sport>? sports,
    List<Turf>? turfs,
    City? selectedCity,
    Sport? selectedSport,
    bool clearSport = false,
  }) {
    return HomeLoaded(
      cities: cities ?? this.cities,
      sports: sports ?? this.sports,
      turfs: turfs ?? this.turfs,
      selectedCity: selectedCity ?? this.selectedCity,
      selectedSport: clearSport ? null : (selectedSport ?? this.selectedSport),
    );
  }

  @override
  List<Object?> get props => [cities, sports, turfs, selectedCity, selectedSport];
}

class HomeFailure extends HomeState {
  final String error;

  const HomeFailure(this.error);

  @override
  List<Object?> get props => [error];
}

// ==========================================
// EVENTS
// ==========================================
abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class LoadHomeData extends HomeEvent {}

class SelectCity extends HomeEvent {
  final City city;

  const SelectCity(this.city);

  @override
  List<Object?> get props => [city];
}

class SelectSport extends HomeEvent {
  final Sport? sport; // Null means all sports

  const SelectSport(this.sport);

  @override
  List<Object?> get props => [sport];
}

// ==========================================
// BLOC
// ==========================================
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final TurfRepository _turfRepository;

  HomeBloc(this._turfRepository) : super(HomeInitial()) {
    on<LoadHomeData>(_onLoadHomeData);
    on<SelectCity>(_onSelectCity);
    on<SelectSport>(_onSelectSport);
  }

  Future<void> _onLoadHomeData(LoadHomeData event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    try {
      final cities = await _turfRepository.getCities();
      final sports = await _turfRepository.getSports();

      // Find a default city (e.g. Bangalore if exists, otherwise first city)
      City? defaultCity;
      if (cities.isNotEmpty) {
        defaultCity = cities.firstWhere(
          (c) => c.name.toLowerCase() == 'bangalore',
          orElse: () => cities.first,
        );
      }

      final turfs = await _turfRepository.getTurfs(
        cityId: defaultCity?.id,
      );

      emit(HomeLoaded(
        cities: cities,
        sports: sports,
        turfs: turfs,
        selectedCity: defaultCity,
      ));
    } catch (e) {
      emit(HomeFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onSelectCity(SelectCity event, Emitter<HomeState> emit) async {
    final currentState = state;
    if (currentState is HomeLoaded) {
      emit(HomeLoading());
      try {
        final turfs = await _turfRepository.getTurfs(
          cityId: event.city.id,
          sportId: currentState.selectedSport?.id,
        );
        emit(currentState.copyWith(
          selectedCity: event.city,
          turfs: turfs,
        ));
      } catch (e) {
        emit(HomeFailure(e.toString().replaceAll('Exception: ', '')));
      }
    }
  }

  Future<void> _onSelectSport(SelectSport event, Emitter<HomeState> emit) async {
    final currentState = state;
    if (currentState is HomeLoaded) {
      emit(HomeLoading());
      try {
        final turfs = await _turfRepository.getTurfs(
          cityId: currentState.selectedCity?.id,
          sportId: event.sport?.id,
        );
        emit(currentState.copyWith(
          selectedSport: event.sport,
          clearSport: event.sport == null,
          turfs: turfs,
        ));
      } catch (e) {
        emit(HomeFailure(e.toString().replaceAll('Exception: ', '')));
      }
    }
  }
}
