import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/notification_model.dart';

class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository(this._apiClient);

  Future<List<NotificationModel>> getNotifications() async {
    try {
      final response = await _apiClient.dio.get('/notifications');
      final data = response.data as List<dynamic>;
      return data
          .map(
            (json) => NotificationModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to retrieve notifications',
      );
    }
  }

  Future<NotificationModel> markAsRead(String id) async {
    try {
      final response = await _apiClient.dio.put('/notifications/$id/read');
      return NotificationModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to mark notification as read',
      );
    }
  }

  Future<List<NotificationModel>> markAllAsRead() async {
    try {
      final response = await _apiClient.dio.put('/notifications/read-all');
      final data = response.data as List<dynamic>;
      return data
          .map(
            (json) => NotificationModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to mark all as read',
      );
    }
  }
}
