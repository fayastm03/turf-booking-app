import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class OwnerRepository {
  final ApiClient _apiClient;

  OwnerRepository(this._apiClient);

  Future<List<dynamic>> getOwnerTurfs() async {
    try {
      final response = await _apiClient.dio.get('/owner/turfs');
      return response.data as List<dynamic>;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to load owner turfs',
      );
    }
  }

  Future<dynamic> registerTurf({
    required String name,
    required String description,
    required String address,
    required String cityId,
    required double basePricePerHour,
    required String openingTime,
    required String closingTime,
    List<String> images = const [],
    List<String> amenities = const [],
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/owner/turfs',
        data: {
          'name': name,
          'description': description,
          'address': address,
          'cityId': cityId,
          'basePricePerHour': basePricePerHour,
          'openingTime': openingTime,
          'closingTime': closingTime,
          'images': images,
          'amenities': amenities,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to register turf facility',
      );
    }
  }

  Future<dynamic> addCourt({
    required String turfId,
    required String name,
    required String type,
    required double pricePerHour,
    required List<String> sports,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/owner/turfs/$turfId/courts',
        data: {
          'name': name,
          'type': type,
          'pricePerHour': pricePerHour,
          'sports': sports,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to add court to turf',
      );
    }
  }

  Future<dynamic> generateSlots(
    String turfId,
    String startDate,
    String endDate,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        '/owner/turfs/$turfId/generate-slots',
        data: {'startDate': startDate, 'endDate': endDate},
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to generate slots',
      );
    }
  }

  Future<List<dynamic>> getCourtTemplates(String courtId) async {
    try {
      final response = await _apiClient.dio.get(
        '/owner/courts/$courtId/templates',
      );
      return response.data as List<dynamic>;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to load templates',
      );
    }
  }

  Future<dynamic> createCourtTemplate(
    String courtId,
    int dayOfWeek,
    String start,
    String end,
    double? priceOverride,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        '/owner/courts/$courtId/templates',
        data: {
          'dayOfWeek': dayOfWeek,
          'startTime': start,
          'endTime': end,
          'priceOverride': ?priceOverride,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to save template');
    }
  }

  Future<Map<String, dynamic>> getOwnerAnalytics() async {
    try {
      final response = await _apiClient.dio.get('/owner/analytics');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to load analytics statistics',
      );
    }
  }
}
