import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      
      final data = response.data;
      await _apiClient.saveTokens(data['accessToken'], data['refreshToken']);
      return data['user'];
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Login failed');
    }
  }

  Future<void> register(String email, String password, String name, {String? phone}) async {
    try {
      final response = await _apiClient.dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
        if (phone != null) 'phone': phone,
      });
      
      final data = response.data;
      await _apiClient.saveTokens(data['accessToken'], data['refreshToken']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Registration failed');
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _apiClient.dio.get('/auth/me');
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to load profile');
    }
  }

  Future<Map<String, dynamic>> applyForOwner(String businessName) async {
    try {
      final response = await _apiClient.dio.post('/auth/owner-apply', data: {
        'businessName': businessName,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Owner application failed');
    }
  }

  Future<void> logout() async {
    await _apiClient.logout();
  }
}
