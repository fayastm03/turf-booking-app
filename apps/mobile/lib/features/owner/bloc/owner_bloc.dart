import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/owner_repository.dart';

// ==========================================
// STATES
// ==========================================
abstract class OwnerState extends Equatable {
  const OwnerState();

  @override
  List<Object?> get props => [];
}

class OwnerInitial extends OwnerState {}

class OwnerLoading extends OwnerState {}

class OwnerLoaded extends OwnerState {
  final List<dynamic> turfs;
  final List<dynamic> templates;
  final Map<String, dynamic>? analytics; // Owner financial summary metrics
  final bool isActionInProgress;
  final String? actionError;
  final String? actionSuccessMsg;

  const OwnerLoaded({
    required this.turfs,
    this.templates = const [],
    this.analytics,
    this.isActionInProgress = false,
    this.actionError,
    this.actionSuccessMsg,
  });

  OwnerLoaded copyWith({
    List<dynamic>? turfs,
    List<dynamic>? templates,
    Map<String, dynamic>? analytics,
    bool? isActionInProgress,
    String? actionError,
    String? actionSuccessMsg,
    bool clearStatus = false,
    bool clearAnalytics = false,
  }) {
    return OwnerLoaded(
      turfs: turfs ?? this.turfs,
      templates: templates ?? this.templates,
      analytics: clearAnalytics ? null : (analytics ?? this.analytics),
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      actionError: clearStatus ? null : (actionError ?? this.actionError),
      actionSuccessMsg: clearStatus
          ? null
          : (actionSuccessMsg ?? this.actionSuccessMsg),
    );
  }

  @override
  List<Object?> get props => [
    turfs,
    templates,
    analytics,
    isActionInProgress,
    actionError,
    actionSuccessMsg,
  ];
}

class OwnerFailure extends OwnerState {
  final String error;

  const OwnerFailure(this.error);

  @override
  List<Object?> get props => [error];
}

// ==========================================
// EVENTS
// ==========================================
abstract class OwnerEvent extends Equatable {
  const OwnerEvent();

  @override
  List<Object?> get props => [];
}

class LoadOwnerTurfs extends OwnerEvent {}

class RegisterTurfRequested extends OwnerEvent {
  final String name;
  final String description;
  final String address;
  final String cityId;
  final double basePricePerHour;
  final String openingTime;
  final String closingTime;
  final List<String> images;
  final List<String> amenities;

  const RegisterTurfRequested({
    required this.name,
    required this.description,
    required this.address,
    required this.cityId,
    required this.basePricePerHour,
    required this.openingTime,
    required this.closingTime,
    this.images = const [],
    this.amenities = const [],
  });

  @override
  List<Object?> get props => [
    name,
    description,
    address,
    cityId,
    basePricePerHour,
    openingTime,
    closingTime,
    images,
    amenities,
  ];
}

class AddCourtRequested extends OwnerEvent {
  final String turfId;
  final String name;
  final String type;
  final double pricePerHour;
  final List<String> sports;

  const AddCourtRequested({
    required this.turfId,
    required this.name,
    required this.type,
    required this.pricePerHour,
    required this.sports,
  });

  @override
  List<Object?> get props => [turfId, name, type, pricePerHour, sports];
}

class GenerateSlotsRequested extends OwnerEvent {
  final String turfId;
  final String startDate;
  final String endDate;

  const GenerateSlotsRequested({
    required this.turfId,
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [turfId, startDate, endDate];
}

class LoadCourtTemplatesRequested extends OwnerEvent {
  final String courtId;

  const LoadCourtTemplatesRequested(this.courtId);

  @override
  List<Object?> get props => [courtId];
}

class CreateCourtTemplateRequested extends OwnerEvent {
  final String courtId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final double? priceOverride;

  const CreateCourtTemplateRequested({
    required this.courtId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.priceOverride,
  });

  @override
  List<Object?> get props => [
    courtId,
    dayOfWeek,
    startTime,
    endTime,
    priceOverride,
  ];
}

class LoadOwnerAnalyticsRequested extends OwnerEvent {}

class ClearOwnerStatus extends OwnerEvent {}

// ==========================================
// BLOC
// ==========================================
class OwnerBloc extends Bloc<OwnerEvent, OwnerState> {
  final OwnerRepository _ownerRepository;

  OwnerBloc(this._ownerRepository) : super(OwnerInitial()) {
    on<LoadOwnerTurfs>(_onLoadOwnerTurfs);
    on<RegisterTurfRequested>(_onRegisterTurf);
    on<AddCourtRequested>(_onAddCourt);
    on<GenerateSlotsRequested>(_onGenerateSlots);
    on<LoadCourtTemplatesRequested>(_onLoadCourtTemplates);
    on<CreateCourtTemplateRequested>(_onCreateCourtTemplate);
    on<LoadOwnerAnalyticsRequested>(_onLoadOwnerAnalytics);
    on<ClearOwnerStatus>(_onClearOwnerStatus);
  }

  Future<void> _onLoadOwnerTurfs(
    LoadOwnerTurfs event,
    Emitter<OwnerState> emit,
  ) async {
    emit(OwnerLoading());
    try {
      final list = await _ownerRepository.getOwnerTurfs();
      emit(OwnerLoaded(turfs: list));
    } catch (e) {
      emit(OwnerFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onRegisterTurf(
    RegisterTurfRequested event,
    Emitter<OwnerState> emit,
  ) async {
    final currentState = state;
    if (currentState is OwnerLoaded) {
      emit(currentState.copyWith(isActionInProgress: true, clearStatus: true));
      try {
        await _ownerRepository.registerTurf(
          name: event.name,
          description: event.description,
          address: event.address,
          cityId: event.cityId,
          basePricePerHour: event.basePricePerHour,
          openingTime: event.openingTime,
          closingTime: event.closingTime,
          images: event.images,
          amenities: event.amenities,
        );

        final list = await _ownerRepository.getOwnerTurfs();
        emit(
          currentState.copyWith(
            turfs: list,
            isActionInProgress: false,
            actionSuccessMsg:
                'Turf facility registered successfully! Pending admin approval.',
          ),
        );
      } catch (e) {
        emit(
          currentState.copyWith(
            isActionInProgress: false,
            actionError: e.toString().replaceAll('Exception: ', ''),
          ),
        );
      }
    }
  }

  Future<void> _onAddCourt(
    AddCourtRequested event,
    Emitter<OwnerState> emit,
  ) async {
    final currentState = state;
    if (currentState is OwnerLoaded) {
      emit(currentState.copyWith(isActionInProgress: true, clearStatus: true));
      try {
        await _ownerRepository.addCourt(
          turfId: event.turfId,
          name: event.name,
          type: event.type,
          pricePerHour: event.pricePerHour,
          sports: event.sports,
        );

        final list = await _ownerRepository.getOwnerTurfs();
        emit(
          currentState.copyWith(
            turfs: list,
            isActionInProgress: false,
            actionSuccessMsg: 'Court/pitch added successfully!',
          ),
        );
      } catch (e) {
        emit(
          currentState.copyWith(
            isActionInProgress: false,
            actionError: e.toString().replaceAll('Exception: ', ''),
          ),
        );
      }
    }
  }

  Future<void> _onGenerateSlots(
    GenerateSlotsRequested event,
    Emitter<OwnerState> emit,
  ) async {
    final currentState = state;
    if (currentState is OwnerLoaded) {
      emit(currentState.copyWith(isActionInProgress: true, clearStatus: true));
      try {
        final result = await _ownerRepository.generateSlots(
          event.turfId,
          event.startDate,
          event.endDate,
        );
        final count = result['count'] ?? 0;
        emit(
          currentState.copyWith(
            isActionInProgress: false,
            actionSuccessMsg:
                'Successfully generated $count slots matching templates date ranges!',
          ),
        );
      } catch (e) {
        emit(
          currentState.copyWith(
            isActionInProgress: false,
            actionError: e.toString().replaceAll('Exception: ', ''),
          ),
        );
      }
    }
  }

  Future<void> _onLoadCourtTemplates(
    LoadCourtTemplatesRequested event,
    Emitter<OwnerState> emit,
  ) async {
    final currentState = state;
    if (currentState is OwnerLoaded) {
      try {
        final templates = await _ownerRepository.getCourtTemplates(
          event.courtId,
        );
        emit(currentState.copyWith(templates: templates));
      } catch (e) {
        emit(
          currentState.copyWith(
            actionError: e.toString().replaceAll('Exception: ', ''),
          ),
        );
      }
    }
  }

  Future<void> _onCreateCourtTemplate(
    CreateCourtTemplateRequested event,
    Emitter<OwnerState> emit,
  ) async {
    final currentState = state;
    if (currentState is OwnerLoaded) {
      emit(currentState.copyWith(isActionInProgress: true, clearStatus: true));
      try {
        await _ownerRepository.createCourtTemplate(
          event.courtId,
          event.dayOfWeek,
          event.startTime,
          event.endTime,
          event.priceOverride,
        );

        final templates = await _ownerRepository.getCourtTemplates(
          event.courtId,
        );
        emit(
          currentState.copyWith(
            templates: templates,
            isActionInProgress: false,
            actionSuccessMsg: 'Slot template added successfully!',
          ),
        );
      } catch (e) {
        emit(
          currentState.copyWith(
            isActionInProgress: false,
            actionError: e.toString().replaceAll('Exception: ', ''),
          ),
        );
      }
    }
  }

  Future<void> _onLoadOwnerAnalytics(
    LoadOwnerAnalyticsRequested event,
    Emitter<OwnerState> emit,
  ) async {
    final currentState = state;
    if (currentState is OwnerLoaded) {
      emit(currentState.copyWith(isActionInProgress: true, clearStatus: true));
      try {
        final analytics = await _ownerRepository.getOwnerAnalytics();
        emit(
          currentState.copyWith(
            analytics: analytics,
            isActionInProgress: false,
          ),
        );
      } catch (e) {
        emit(
          currentState.copyWith(
            isActionInProgress: false,
            actionError: e.toString().replaceAll('Exception: ', ''),
          ),
        );
      }
    }
  }

  void _onClearOwnerStatus(ClearOwnerStatus event, Emitter<OwnerState> emit) {
    final currentState = state;
    if (currentState is OwnerLoaded) {
      emit(currentState.copyWith(clearStatus: true));
    }
  }
}
