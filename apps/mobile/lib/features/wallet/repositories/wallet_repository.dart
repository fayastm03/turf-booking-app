import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/wallet_models.dart';

class WalletRepository {
  final ApiClient _apiClient;

  WalletRepository(this._apiClient);

  Future<Wallet> getWallet() async {
    try {
      final response = await _apiClient.dio.get('/wallet');
      return Wallet.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to retrieve wallet information');
    }
  }

  Future<Wallet> topupWallet(double amount) async {
    try {
      final response = await _apiClient.dio.post('/wallet/topup', data: {
        'amount': amount,
      });
      return Wallet.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to top-up wallet');
    }
  }

  Future<Map<String, dynamic>> payFromWallet(String bookingId) async {
    try {
      final response = await _apiClient.dio.post('/wallet/pay', data: {
        'bookingId': bookingId,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Payment via wallet failed');
    }
  }
}
