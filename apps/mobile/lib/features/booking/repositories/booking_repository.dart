import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class BookingRepository {
  final ApiClient _apiClient;

  BookingRepository(this._apiClient);

  Future<Map<String, dynamic>> holdSlot(String slotId, {String? offerCode}) async {
    try {
      final response = await _apiClient.dio.post('/bookings/hold', data: {
        'slotId': slotId,
        'offerCode': offerCode,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to hold slot');
    }
  }

  Future<Map<String, dynamic>> createRazorpayOrder(String bookingId) async {
    try {
      final response = await _apiClient.dio.post('/bookings/$bookingId/create-order');
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to initiate payment');
    }
  }

  Future<void> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      await _apiClient.dio.post('/bookings/verify-payment', data: {
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Payment verification failed');
    }
  }

  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final response = await _apiClient.dio.post('/bookings/$bookingId/cancel');
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to cancel booking');
    }
  }

  Future<List<dynamic>> getMyBookings() async {
    try {
      final response = await _apiClient.dio.get('/bookings/my');
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to retrieve booking history');
    }
  }
}
