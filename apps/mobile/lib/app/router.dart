import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/turf/domain/turf_models.dart';
import 'package:mobile/features/turf/repositories/turf_repository.dart';
import 'package:mobile/injection.dart';
import '../features/auth/bloc/auth_bloc.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/turf/presentation/home_screen.dart';
import '../features/turf/presentation/turf_list_screen.dart';
import '../features/turf/presentation/turf_detail_screen.dart';
import '../features/turf/bloc/turf_detail_bloc.dart';
import '../features/notification/presentation/notifications_screen.dart';
import '../features/owner/presentation/owner_dashboard_screen.dart';
import '../features/owner/presentation/add_turf_screen.dart';
import '../features/booking/presentation/checkout_screen.dart';
import '../features/booking/presentation/my_bookings_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';

// Import screens (we will stub these screens to make sure the router compiles perfectly)
// To keep things simple and avoid circular reference issues, we define stub screens in a widgets file or in this router file directly.
// Stubs allow the router to compile and route correctly.

class StubScreen extends StatelessWidget {
  final String title;
  const StubScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Welcome to $title')),
    );
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) {
    final authState = context.read<AuthBloc>().state;
    final path = state.uri.path;

    // Check if user is authenticated
    final isAuthenticated = authState is Authenticated;
    final isLoggingInOrRegistering = path == '/login' || path == '/register';

    if (!isAuthenticated) {
      // Allow public routes: Home '/' or Turf detail '/turfs/:id'
      final isPublicRoute = path == '/' || path.startsWith('/turfs/');
      if (!isPublicRoute && !isLoggingInOrRegistering) {
        return '/login';
      }
      return null;
    }

    // User is authenticated
    if (isLoggingInOrRegistering) {
      return '/';
    }

    final user = (authState).user;
    final roles = List<String>.from(user['roles'] ?? []);

    // Role Guards
    if (path.startsWith('/owner') && !roles.contains('OWNER') && !roles.contains('USER')) {
      return '/'; // Redirect non-owners to home
    }

    if (path.startsWith('/admin') && !roles.contains('ADMIN')) {
      return '/'; // Redirect non-admins to home
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/turfs/list',
      builder: (context, state) {
        final sportId = state.uri.queryParameters['sportId'];
        final cityId = state.uri.queryParameters['cityId'];
        final sportName = state.uri.queryParameters['sportName'];
        return TurfListScreen(
          sportId: sportId,
          cityId: cityId,
          sportName: sportName,
        );
      },
    ),
    GoRoute(
      path: '/turfs/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return BlocProvider<TurfDetailBloc>(
          create: (context) =>
              TurfDetailBloc(getIt<TurfRepository>())..add(LoadTurfDetails(id)),
          child: TurfDetailScreen(turfId: id),
        );
      },
    ),
    GoRoute(
      path: '/booking/:slotId',
      builder: (context, state) {
        final slotId = state.pathParameters['slotId'] ?? '';
        final extra = state.extra as Map<String, dynamic>?;
        final turf = extra?['turf'] as Turf;
        final slot = extra?['slot'] as Slot;
        return CheckoutScreen(slotId: slotId, turf: turf, slot: slot);
      },
    ),
    GoRoute(
      path: '/my-bookings',
      builder: (context, state) => const MyBookingsScreen(),
    ),
    GoRoute(path: '/wallet', builder: (context, state) => const WalletScreen()),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/owner',
      builder: (context, state) => const OwnerDashboardScreen(),
    ),
    GoRoute(
      path: '/owner/turfs/add',
      builder: (context, state) => const AddTurfScreen(),
    ),
    GoRoute(
      path: '/owner/turfs/:id/slots',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return StubScreen(title: 'Manage Slots for Turf $id');
      },
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const StubScreen(title: 'Admin Panel'),
    ),
  ],
);
