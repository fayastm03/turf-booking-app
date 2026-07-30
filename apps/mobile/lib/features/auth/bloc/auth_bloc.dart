import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/auth_repository.dart';

// ==========================================
// STATES
// ==========================================
abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final Map<String, dynamic> user;

  const Authenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String error;

  const AuthFailure(this.error);

  @override
  List<Object?> get props => [error];
}

// ==========================================
// EVENTS
// ==========================================
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested(this.email, this.password);

  @override
  List<Object?> get props => [email, password];
}

class RegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final String? phone;

  const RegisterRequested(this.email, this.password, this.name, this.phone);

  @override
  List<Object?> get props => [email, password, name, phone];
}

class LogoutRequested extends AuthEvent {}

class RefreshProfileRequested extends AuthEvent {}

class ApplyForOwnerRequested extends AuthEvent {
  final String businessName;

  const ApplyForOwnerRequested(this.businessName);

  @override
  List<Object?> get props => [businessName];
}

// ==========================================
// BLOC
// ==========================================
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<RefreshProfileRequested>(_onRefreshProfile);
    on<ApplyForOwnerRequested>(_onApplyForOwner);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.getProfile();
      emit(Authenticated(user));
    } catch (_) {
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.login(event.email, event.password);
      final user = await _authRepository.getProfile();
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onRegisterRequested(RegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.register(event.email, event.password, event.name, phone: event.phone);
      final user = await _authRepository.getProfile();
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _authRepository.logout();
    emit(Unauthenticated());
  }

  Future<void> _onRefreshProfile(RefreshProfileRequested event, Emitter<AuthState> emit) async {
    try {
      final user = await _authRepository.getProfile();
      emit(Authenticated(user));
    } catch (e) {
      // Don't log out on random network failures, only if auth fails
      if (e.toString().contains('Unauthorized') || e.toString().contains('401')) {
        await _authRepository.logout();
        emit(Unauthenticated());
      }
    }
  }

  Future<void> _onApplyForOwner(ApplyForOwnerRequested event, Emitter<AuthState> emit) async {
    if (state is Authenticated) {
      try {
        await _authRepository.applyForOwner(event.businessName);
        final user = await _authRepository.getProfile();
        emit(Authenticated(user));
      } catch (e) {
        emit(AuthFailure(e.toString().replaceAll('Exception: ', '')));
      }
    }
  }
}
