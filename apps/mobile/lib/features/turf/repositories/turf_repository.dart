import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/turf_models.dart';

class TurfRepository {
  final ApiClient _apiClient;

  TurfRepository(this._apiClient);

  Future<List<City>> getCities() async {
    try {
      final response = await _apiClient.dio.get('/cities');
      final data = response.data as List<dynamic>;
      return data.map((json) => City.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch cities');
    }
  }

  Future<List<Sport>> getSports() async {
    try {
      final response = await _apiClient.dio.get('/sports');
      final data = response.data as List<dynamic>;
      return data.map((json) => Sport.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch sports');
    }
  }

  Future<List<Turf>> getTurfs({String? cityId, String? sportId, String? search}) async {
    try {
      final response = await _apiClient.dio.get(
        '/turfs',
        queryParameters: {
          'cityId': ?cityId,
          'sportId': ?sportId,
          'search': ?search,
        },
      );
      final data = response.data as List<dynamic>;
      return data.map((json) => Turf.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch turfs');
    }
  }

  Future<Turf> getTurfById(String id) async {
    try {
      final response = await _apiClient.dio.get('/turfs/$id');
      return Turf.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch turf details');
    }
  }

  Future<List<Slot>> getSlotsForTurf(String turfId, String date) async {
    try {
      final response = await _apiClient.dio.get(
        '/turfs/$turfId/slots',
        queryParameters: {'date': date},
      );
      final data = response.data as List<dynamic>;
      return data.map((json) => Slot.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch slots');
    }
  }

  Future<List<dynamic>> getReviewsForTurf(String turfId) async {
    try {
      final response = await _apiClient.dio.get('/turfs/$turfId/reviews');
      return response.data as List<dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch reviews');
    }
  }

  Future<Map<String, dynamic>> submitReview(String turfId, int rating, String? comment) async {
    try {
      final response = await _apiClient.dio.post(
        '/turfs/$turfId/reviews',
        data: {
          'rating': rating,
          'comment': ?comment,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to submit review');
    }
  }
}
