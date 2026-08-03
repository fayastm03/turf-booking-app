import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/turf_repository.dart';
import '../domain/turf_models.dart';

// ==========================================
// STATES
// ==========================================
abstract class TurfDetailState extends Equatable {
  const TurfDetailState();

  @override
  List<Object?> get props => [];
}

class TurfDetailInitial extends TurfDetailState {}

class TurfDetailLoading extends TurfDetailState {}

class TurfDetailLoaded extends TurfDetailState {
  final Turf turf;
  final List<Slot> slots;
  final List<dynamic> reviews; // Custom review list logs
  final DateTime selectedDate;
  final Court? selectedCourt;
  final Slot? selectedSlot;
  final bool isLoadingSlots;
  final bool isSubmittingReview;
  final String? reviewError;
  final bool reviewSuccess;

  const TurfDetailLoaded({
    required this.turf,
    required this.slots,
    required this.selectedDate,
    this.reviews = const [],
    this.selectedCourt,
    this.selectedSlot,
    this.isLoadingSlots = false,
    this.isSubmittingReview = false,
    this.reviewError,
    this.reviewSuccess = false,
  });

  List<Slot> get courtSlots {
    if (selectedCourt == null) return [];
    return slots.where((slot) => slot.courtId == selectedCourt!.id).toList();
  }

  TurfDetailLoaded copyWith({
    Turf? turf,
    List<Slot>? slots,
    List<dynamic>? reviews,
    DateTime? selectedDate,
    Court? selectedCourt,
    Slot? selectedSlot,
    bool? isLoadingSlots,
    bool? isSubmittingReview,
    String? reviewError,
    bool? reviewSuccess,
    bool clearSlot = false,
    bool clearReviewStatus = false,
  }) {
    return TurfDetailLoaded(
      turf: turf ?? this.turf,
      slots: slots ?? this.slots,
      reviews: reviews ?? this.reviews,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedCourt: selectedCourt ?? this.selectedCourt,
      selectedSlot: clearSlot ? null : (selectedSlot ?? this.selectedSlot),
      isLoadingSlots: isLoadingSlots ?? this.isLoadingSlots,
      isSubmittingReview: isSubmittingReview ?? this.isSubmittingReview,
      reviewError: clearReviewStatus ? null : (reviewError ?? this.reviewError),
      reviewSuccess: clearReviewStatus
          ? false
          : (reviewSuccess ?? this.reviewSuccess),
    );
  }

  @override
  List<Object?> get props => [
    turf,
    slots,
    reviews,
    selectedDate,
    selectedCourt,
    selectedSlot,
    isLoadingSlots,
    isSubmittingReview,
    reviewError,
    reviewSuccess,
  ];
}

class TurfDetailFailure extends TurfDetailState {
  final String error;

  const TurfDetailFailure(this.error);

  @override
  List<Object?> get props => [error];
}

// ==========================================
// EVENTS
// ==========================================
abstract class TurfDetailEvent extends Equatable {
  const TurfDetailEvent();

  @override
  List<Object?> get props => [];
}

class LoadTurfDetails extends TurfDetailEvent {
  final String turfId;

  const LoadTurfDetails(this.turfId);

  @override
  List<Object?> get props => [turfId];
}

class ChangeSelectedDate extends TurfDetailEvent {
  final DateTime date;

  const ChangeSelectedDate(this.date);

  @override
  List<Object?> get props => [date];
}

class ChangeSelectedCourt extends TurfDetailEvent {
  final Court court;

  const ChangeSelectedCourt(this.court);

  @override
  List<Object?> get props => [court];
}

class SelectBookingSlot extends TurfDetailEvent {
  final Slot? slot;

  const SelectBookingSlot(this.slot);

  @override
  List<Object?> get props => [slot];
}

class SubmitReviewRequested extends TurfDetailEvent {
  final int rating;
  final String? comment;

  const SubmitReviewRequested({required this.rating, this.comment});

  @override
  List<Object?> get props => [rating, comment];
}

class ClearReviewStatus extends TurfDetailEvent {}

// ==========================================
// BLOC
// ==========================================
class TurfDetailBloc extends Bloc<TurfDetailEvent, TurfDetailState> {
  final TurfRepository _turfRepository;

  TurfDetailBloc(this._turfRepository) : super(TurfDetailInitial()) {
    on<LoadTurfDetails>(_onLoadTurfDetails);
    on<ChangeSelectedDate>(_onChangeSelectedDate);
    on<ChangeSelectedCourt>(_onChangeSelectedCourt);
    on<SelectBookingSlot>(_onSelectBookingSlot);
    on<SubmitReviewRequested>(_onSubmitReview);
    on<ClearReviewStatus>(_onClearReviewStatus);
  }

  Future<void> _onLoadTurfDetails(
    LoadTurfDetails event,
    Emitter<TurfDetailState> emit,
  ) async {
    emit(TurfDetailLoading());
    try {
      final turf = await _turfRepository.getTurfById(event.turfId);
      final today = DateTime.now();
      final dateStr = _formatDate(today);

      final slots = await _turfRepository.getSlotsForTurf(
        event.turfId,
        dateStr,
      );
      final reviews = await _turfRepository.getReviewsForTurf(event.turfId);

      final selectedCourt = turf.courts.isNotEmpty ? turf.courts.first : null;

      emit(
        TurfDetailLoaded(
          turf: turf,
          slots: slots,
          reviews: reviews,
          selectedDate: today,
          selectedCourt: selectedCourt,
        ),
      );
    } catch (e) {
      emit(TurfDetailFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onChangeSelectedDate(
    ChangeSelectedDate event,
    Emitter<TurfDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is TurfDetailLoaded) {
      emit(currentState.copyWith(isLoadingSlots: true, clearSlot: true));
      try {
        final dateStr = _formatDate(event.date);
        final slots = await _turfRepository.getSlotsForTurf(
          currentState.turf.id,
          dateStr,
        );

        emit(
          currentState.copyWith(
            slots: slots,
            selectedDate: event.date,
            isLoadingSlots: false,
          ),
        );
      } catch (e) {
        emit(TurfDetailFailure(e.toString().replaceAll('Exception: ', '')));
      }
    }
  }

  void _onChangeSelectedCourt(
    ChangeSelectedCourt event,
    Emitter<TurfDetailState> emit,
  ) {
    final currentState = state;
    if (currentState is TurfDetailLoaded) {
      emit(currentState.copyWith(selectedCourt: event.court, clearSlot: true));
    }
  }

  void _onSelectBookingSlot(
    SelectBookingSlot event,
    Emitter<TurfDetailState> emit,
  ) {
    final currentState = state;
    if (currentState is TurfDetailLoaded) {
      emit(currentState.copyWith(selectedSlot: event.slot));
    }
  }

  Future<void> _onSubmitReview(
    SubmitReviewRequested event,
    Emitter<TurfDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is TurfDetailLoaded) {
      emit(
        currentState.copyWith(
          isSubmittingReview: true,
          clearReviewStatus: true,
        ),
      );
      try {
        await _turfRepository.submitReview(
          currentState.turf.id,
          event.rating,
          event.comment,
        );

        // Re-fetch reviews to update the list
        final reviews = await _turfRepository.getReviewsForTurf(
          currentState.turf.id,
        );

        emit(
          currentState.copyWith(
            isSubmittingReview: false,
            reviews: reviews,
            reviewSuccess: true,
          ),
        );
      } catch (e) {
        emit(
          currentState.copyWith(
            isSubmittingReview: false,
            reviewError: e.toString().replaceAll('Exception: ', ''),
          ),
        );
      }
    }
  }

  void _onClearReviewStatus(
    ClearReviewStatus event,
    Emitter<TurfDetailState> emit,
  ) {
    final currentState = state;
    if (currentState is TurfDetailLoaded) {
      emit(currentState.copyWith(clearReviewStatus: true));
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
