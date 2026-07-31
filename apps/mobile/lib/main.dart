import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/storage/local_storage.dart';
import 'app/router.dart';
import 'injection.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/booking/bloc/booking_bloc.dart';
import 'features/booking/repositories/booking_repository.dart';
import 'features/turf/bloc/home_bloc.dart';
import 'features/turf/bloc/search_bloc.dart';
import 'features/turf/repositories/turf_repository.dart';
import 'features/wallet/bloc/wallet_bloc.dart';
import 'features/wallet/repositories/wallet_repository.dart';
import 'features/notification/bloc/notification_bloc.dart';
import 'features/notification/repositories/notification_repository.dart';
import 'features/owner/bloc/owner_bloc.dart';
import 'features/owner/repositories/owner_repository.dart';

import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up dependency injection locator
  setupLocator();

  // Initialize local key-value databases
  await getIt<LocalStorage>().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) =>
              AuthBloc(getIt<AuthRepository>())..add(AppStarted()),
        ),
        BlocProvider<BookingBloc>(
          create: (context) => BookingBloc(getIt<BookingRepository>()),
        ),
        BlocProvider<HomeBloc>(
          create: (context) =>
              HomeBloc(getIt<TurfRepository>())..add(LoadHomeData()),
        ),
        BlocProvider<SearchBloc>(
          create: (context) =>
              SearchBloc(getIt<TurfRepository>(), getIt<LocalStorage>())
                ..add(LoadSearchInit()),
        ),
        BlocProvider<WalletBloc>(
          create: (context) =>
              WalletBloc(getIt<WalletRepository>())..add(LoadWallet()),
        ),
        BlocProvider<NotificationBloc>(
          create: (context) =>
              NotificationBloc(getIt<NotificationRepository>())
                ..add(LoadNotifications()),
        ),
        BlocProvider<OwnerBloc>(
          create: (context) =>
              OwnerBloc(getIt<OwnerRepository>())..add(LoadOwnerTurfs()),
        ),
      ],
      child: MaterialApp.router(
        title: 'Turf Booking System',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        themeMode:
            ThemeMode.dark, // Default to dark mode but allow system matching
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
      ),
    );
  }
}
