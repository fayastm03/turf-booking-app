import 'package:get_it/get_it.dart';
import 'core/network/api_client.dart';
import 'core/storage/local_storage.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/booking/repositories/booking_repository.dart';
import 'features/turf/repositories/turf_repository.dart';
import 'features/wallet/repositories/wallet_repository.dart';
import 'features/notification/repositories/notification_repository.dart';
import 'features/owner/repositories/owner_repository.dart';

final getIt = GetIt.instance;

void setupLocator() {
  // Core Services
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());
  getIt.registerLazySingleton<LocalStorage>(() => LocalStorage());

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(() => AuthRepository(getIt<ApiClient>()));
  getIt.registerLazySingleton<BookingRepository>(() => BookingRepository(getIt<ApiClient>()));
  getIt.registerLazySingleton<TurfRepository>(() => TurfRepository(getIt<ApiClient>()));
  getIt.registerLazySingleton<WalletRepository>(() => WalletRepository(getIt<ApiClient>()));
  getIt.registerLazySingleton<NotificationRepository>(() => NotificationRepository(getIt<ApiClient>()));
  getIt.registerLazySingleton<OwnerRepository>(() => OwnerRepository(getIt<ApiClient>()));
}
