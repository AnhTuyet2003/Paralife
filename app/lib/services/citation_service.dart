import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CitationService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:3000'));

  /// Get available citation styles
  Future<List<Map<String, dynamic>>> getStyles() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final token = await user.getIdToken();
      final response = await _dio.get(
        '/api/citation/styles',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success']) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }

      throw Exception('Failed to fetch styles');
    } catch (e) {
      throw Exception('Get styles error: $e');
    }
  }

  /// Generate citation for an item
  Future<String> generateCitation(String itemId, String style) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final token = await user.getIdToken();
      final response = await _dio.get(
        '/api/citation/items/$itemId/cite',
        queryParameters: {'style': style},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success']) {
        return response.data['data']['citation'];
      }

      throw Exception(response.data['error'] ?? 'Citation generation failed');
    } catch (e) {
      if (e is DioException && e.response != null) {
        final error = e.response!.data['error'] ?? 'Citation generation failed';
        final hint = e.response!.data['hint'] ?? '';
        throw Exception('$error${hint.isNotEmpty ? '\n\n$hint' : ''}');
      }
      throw Exception('Generate citation error: $e');
    }
  }

  /// Export library
  Future<String> exportLibrary(String format) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      // Note: This returns binary data, handle in UI
      return '/api/citation/export?format=$format';
    } catch (e) {
      throw Exception('Export library error: $e');
    }
  }
}
