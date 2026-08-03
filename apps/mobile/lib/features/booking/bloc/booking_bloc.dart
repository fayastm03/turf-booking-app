import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/booking_repository.dart';

// ==========================================
// STATES
// ==========================================
abstract class BookingState extends Equatable {
  const BookingState();

  @override
  List<Object?> get props => [];
}

class BookingInitial extends BookingState {}

// Hold States
class BookingHoldLoading extends BookingState {}

class BookingHoldSuccess extends BookingState {
  final String bookingId;
  final double amount;
  final DateTime expiresAt;

  const BookingHoldSuccess({
    required this.bookingId,
    required this.amount,
    required this.expiresAt,
  });

  @override
  List<Object?> get props => [bookingId, amount, expiresAt];
}

class BookingHoldFailure extends BookingState {
  final String error;

  const BookingHoldFailure(this.error);

  @override
  List<Object?> get props => [error];
}

// Razorpay Order States
class RazorpayOrderLoading extends BookingState {}

class RazorpayOrderSuccess extends BookingState {
  final String orderId;
  final double amount;
  final String razorpayKey;

  const RazorpayOrderSuccess({
    required this.orderId,
    required this.amount,
    required this.razorpayKey,
  });

  @override
  List<Object?> get props => [orderId, amount, razorpayKey];
}

class RazorpayOrderFailure extends BookingState {
  final String error;

  const RazorpayOrderFailure(this.error);

  @override
  List<Object?> get props => [error];
}

// Payment States
class PaymentSuccess extends BookingState {}

class PaymentFailure extends BookingState {
  final String error;

  const PaymentFailure(this.error);

  @override
  List<Object?> get props => [error];
}

// Cancellation States
class CancellationLoading extends BookingState {}

class CancellationSuccess extends BookingState {}

class CancellationFailure extends BookingState {
  final String error;

  const CancellationFailure(this.error);

  @override
  List<Object?> get props => [error];
}

// Load Booking History States
class MyBookingsLoadInProgress extends BookingState {}

class MyBookingsLoadSuccess extends BookingState {
  final List<dynamic> bookings;

  const MyBookingsLoadSuccess(this.bookings);

  @override
  List<Object?> get props => [bookings];
}

class MyBookingsLoadFailure extends BookingState {
  final String error;

  const MyBookingsLoadFailure(this.error);

  @override
  List<Object?> get props => [error];
}

// ==========================================
// EVENTS
// ==========================================
abstract class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => [];
}

class HoldSlotRequested extends BookingEvent {
  final String slotId;
  final String? offerCode;

  const HoldSlotRequested(this.slotId, {this.offerCode});

  @override
  List<Object?> get props => [slotId, offerCode];
}

class CreateRazorpayOrderRequested extends BookingEvent {
  final String bookingId;

  const CreateRazorpayOrderRequested(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

class PaymentCompleted extends BookingEvent {
  final String orderId;
  final String paymentId;
  final String signature;

  const PaymentCompleted({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  @override
  List<Object?> get props => [orderId, paymentId, signature];
}

class CancelBookingRequested extends BookingEvent {
  final String bookingId;

  const CancelBookingRequested(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

class LoadMyBookingsRequested extends BookingEvent {}

// ==========================================
// BLOC
// ==========================================
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingRepository _bookingRepository;

  BookingBloc(this._bookingRepository) : super(BookingInitial()) {
    on<HoldSlotRequested>(_onHoldSlot);
    on<CreateRazorpayOrderRequested>(_onCreateRazorpayOrder);
    on<PaymentCompleted>(_onPaymentCompleted);
    on<CancelBookingRequested>(_onCancelBooking);
    on<LoadMyBookingsRequested>(_onLoadMyBookings);
  }

  Future<void> _onHoldSlot(
    HoldSlotRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingHoldLoading());
    try {
      final result = await _bookingRepository.holdSlot(
        event.slotId,
        offerCode: event.offerCode,
      );
      emit(
        BookingHoldSuccess(
          bookingId: result['bookingId'],
          amount: (result['amount'] as num).toDouble(),
          expiresAt: DateTime.parse(result['expiresAt']),
        ),
      );
    } catch (e) {
      emit(BookingHoldFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateRazorpayOrder(
    CreateRazorpayOrderRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(RazorpayOrderLoading());
    try {
      final result = await _bookingRepository.createRazorpayOrder(
        event.bookingId,
      );
      emit(
        RazorpayOrderSuccess(
          orderId: result['orderId'],
          amount: (result['amount'] as num).toDouble(),
          razorpayKey: result['key'],
        ),
      );
    } catch (e) {
      emit(RazorpayOrderFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onPaymentCompleted(
    PaymentCompleted event,
    Emitter<BookingState> emit,
  ) async {
    try {
      await _bookingRepository.verifyPayment(
        orderId: event.orderId,
        paymentId: event.paymentId,
        signature: event.signature,
      );
      emit(PaymentSuccess());
    } catch (e) {
      emit(PaymentFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCancelBooking(
    CancelBookingRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(CancellationLoading());
    try {
      await _bookingRepository.cancelBooking(event.bookingId);
      emit(CancellationSuccess());
    } catch (e) {
      emit(CancellationFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLoadMyBookings(
    LoadMyBookingsRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(MyBookingsLoadInProgress());
    try {
      final bookings = await _bookingRepository.getMyBookings();
      emit(MyBookingsLoadSuccess(bookings));
    } catch (e) {
      emit(MyBookingsLoadFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
