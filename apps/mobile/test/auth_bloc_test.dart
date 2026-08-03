import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/repositories/auth_repository.dart';
import 'package:mobile/core/network/api_client.dart';

class MockAuthRepository implements AuthRepository {
  @override
  ApiClient get _apiClient => throw UnimplementedError();

  bool shouldFailProfile = false;

  @override
  Future<Map<String, dynamic>> login(String email, String password, {String? accountType}) async {
    if (email == 'user@turf.com' && password == 'password123') {
      return {
        'id': 'user-1',
        'email': email,
        'name': 'Regular Customer',
        'roles': ['USER']
      };
    }
    throw Exception('Invalid credentials');
  }

  @override
  Future<void> register(
    String email,
    String password,
    String name, {
    String? phone,
    String? accountType,
    String? businessName,
  }) async {}

  @override
  Future<Map<String, dynamic>> getProfile() async {
    if (shouldFailProfile) {
      throw Exception('Failed to load profile');
    }
    return {
      'id': 'user-1',
      'email': 'user@turf.com',
      'name': 'Regular Customer',
      'roles': ['USER']
    };
  }

  @override
  Future<Map<String, dynamic>> applyForOwner(String businessName) async {
    return {};
  }

  @override
  Future<void> logout() async {}
}

void main() {
  group('AuthBloc Tests', () {
    late MockAuthRepository mockRepository;
    late AuthBloc authBloc;

    setUp(() {
      mockRepository = MockAuthRepository();
      authBloc = AuthBloc(mockRepository);
    });

    tearDown(() {
      authBloc.close();
    });

    test('Initial state is AuthInitial', () {
      expect(authBloc.state, equals(AuthInitial()));
    });

    test('AppStarted emits AuthLoading and then Authenticated when profile loads successfully', () {
      final expectedStates = [
        AuthLoading(),
        const Authenticated({
          'id': 'user-1',
          'email': 'user@turf.com',
          'name': 'Regular Customer',
          'roles': ['USER']
        }),
      ];

      expectLater(
        authBloc.stream,
        emitsInOrder(expectedStates),
      );

      authBloc.add(AppStarted());
    });

    test('AppStarted emits AuthLoading and then Unauthenticated when profile load fails', () {
      mockRepository.shouldFailProfile = true;

      final expectedStates = [
        AuthLoading(),
        Unauthenticated(),
      ];

      expectLater(
        authBloc.stream,
        emitsInOrder(expectedStates),
      );

      authBloc.add(AppStarted());
    });

    test('LoginRequested emits AuthLoading and then Authenticated on successful login', () {
      final expectedStates = [
        AuthLoading(),
        const Authenticated({
          'id': 'user-1',
          'email': 'user@turf.com',
          'name': 'Regular Customer',
          'roles': ['USER']
        }),
      ];

      expectLater(
        authBloc.stream,
        emitsInOrder(expectedStates),
      );

      authBloc.add(const LoginRequested('user@turf.com', 'password123', accountType: 'USER'));
    });

    test('LoginRequested emits AuthLoading and then AuthFailure on wrong credentials', () {
      final expectedStates = [
        AuthLoading(),
        const AuthFailure('Invalid credentials'),
      ];

      expectLater(
        authBloc.stream,
        emitsInOrder(expectedStates),
      );

      authBloc.add(const LoginRequested('wrong@email.com', 'badpass', accountType: 'USER'));
    });
  });
}
