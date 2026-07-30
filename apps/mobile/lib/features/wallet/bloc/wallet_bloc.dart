import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/wallet_repository.dart';
import '../domain/wallet_models.dart';

// ==========================================
// STATES
// ==========================================
abstract class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletLoaded extends WalletState {
  final Wallet wallet;
  final bool isActionInProgress;
  final String? actionError;
  final String? actionSuccessMsg;

  const WalletLoaded({
    required this.wallet,
    this.isActionInProgress = false,
    this.actionError,
    this.actionSuccessMsg,
  });

  WalletLoaded copyWith({
    Wallet? wallet,
    bool? isActionInProgress,
    String? actionError,
    String? actionSuccessMsg,
    bool clearStatus = false,
  }) {
    return WalletLoaded(
      wallet: wallet ?? this.wallet,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      actionError: clearStatus ? null : (actionError ?? this.actionError),
      actionSuccessMsg: clearStatus ? null : (actionSuccessMsg ?? this.actionSuccessMsg),
    );
  }

  @override
  List<Object?> get props => [wallet, isActionInProgress, actionError, actionSuccessMsg];
}

class WalletFailure extends WalletState {
  final String error;

  const WalletFailure(this.error);

  @override
  List<Object?> get props => [error];
}

// ==========================================
// EVENTS
// ==========================================
abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

class LoadWallet extends WalletEvent {}

class TopupWalletRequested extends WalletEvent {
  final double amount;

  const TopupWalletRequested(this.amount);

  @override
  List<Object?> get props => [amount];
}

class PayBookingWithWalletRequested extends WalletEvent {
  final String bookingId;

  const PayBookingWithWalletRequested(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

class ClearWalletStatus extends WalletEvent {}

// ==========================================
// BLOC
// ==========================================
class WalletBloc extends Bloc<WalletEvent, WalletState> {
  final WalletRepository _walletRepository;

  WalletBloc(this._walletRepository) : super(WalletInitial()) {
    on<LoadWallet>(_onLoadWallet);
    on<TopupWalletRequested>(_onTopupWallet);
    on<PayBookingWithWalletRequested>(_onPayBooking);
    on<ClearWalletStatus>(_onClearWalletStatus);
  }

  Future<void> _onLoadWallet(LoadWallet event, Emitter<WalletState> emit) async {
    emit(WalletLoading());
    try {
      final wallet = await _walletRepository.getWallet();
      emit(WalletLoaded(wallet: wallet));
    } catch (e) {
      emit(WalletFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onTopupWallet(TopupWalletRequested event, Emitter<WalletState> emit) async {
    final currentState = state;
    if (currentState is WalletLoaded) {
      emit(currentState.copyWith(isActionInProgress: true, clearStatus: true));
      try {
        final updatedWallet = await _walletRepository.topupWallet(event.amount);
        emit(currentState.copyWith(
          wallet: updatedWallet,
          isActionInProgress: false,
          actionSuccessMsg: 'Successfully topped-up ₹${event.amount.toInt()} into Turf Wallet!',
        ));
      } catch (e) {
        emit(currentState.copyWith(
          isActionInProgress: false,
          actionError: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
  }

  Future<void> _onPayBooking(PayBookingWithWalletRequested event, Emitter<WalletState> emit) async {
    final currentState = state;
    if (currentState is WalletLoaded) {
      emit(currentState.copyWith(isActionInProgress: true, clearStatus: true));
      try {
        await _walletRepository.payFromWallet(event.bookingId);
        
        // Re-load wallet state balance
        final updatedWallet = await _walletRepository.getWallet();

        emit(currentState.copyWith(
          wallet: updatedWallet,
          isActionInProgress: false,
          actionSuccessMsg: 'PAYMENT_SUCCESS',
        ));
      } catch (e) {
        emit(currentState.copyWith(
          isActionInProgress: false,
          actionError: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
  }

  void _onClearWalletStatus(ClearWalletStatus event, Emitter<WalletState> emit) {
    final currentState = state;
    if (currentState is WalletLoaded) {
      emit(currentState.copyWith(clearStatus: true));
    }
  }
}
