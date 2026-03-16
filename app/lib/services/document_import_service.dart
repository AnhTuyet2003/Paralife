import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class DocumentImportService {
  static final Dio _dio = ApiService.dio;

  // ===================================================
  // 1. IMPORT BY IDENTIFIER (ISBN, PMID, arXiv)
  // ===================================================
  static Future<Map<String, dynamic>> importByIdentifier({
    required String type, // 'doi', 'isbn', 'pmid', 'arxiv'
    required String value,
    String? parentId,
  }) async {
    try {
      debugPrint('📝 Importing ${type.toUpperCase()}: $value');

      // DOI uses a dedicated backend endpoint.
      final isDoi = type.toLowerCase() == 'doi';
      final response = await _dio.post(
        isDoi ? '/api/doi/process-doi' : '/api/import/identifier',
        data: isDoi
            ? {
                'doi': value,
                'parent_id': parentId,
              }
            : {
                'type': type,
                'value': value,
                'parent_id': parentId,
              },
      );

      final successStatus = isDoi ? 200 : 201;
      if (response.statusCode == successStatus && response.data['success']) {
        final data = response.data['data'] ?? {};
        debugPrint('✅ Import successful: ${data['name'] ?? data['file_id'] ?? 'document'}');
        return {
          'success': true,
          'data': data,
          'message': response.data['message'],
          'has_pdf': response.data['has_pdf'] ?? data['has_pdf'] ?? false,
        };
      } else {
        debugPrint('❌ Import failed: ${response.data}');
        return {
          'success': false,
          'message': response.data['error'] ?? 'Import failed',
        };
      }
    } on DioException catch (e) {
      debugPrint('❌ Import error: ${e.message}');
      
      if (e.response?.statusCode == 404) {
        return {
          'success': false,
          'message': e.response?.data['error'] ?? 'Identifier not found',
        };
      } else if (e.response?.statusCode == 403) {
        return {
          'success': false,
          'message': e.response?.data['error'] ?? 'Storage quota exceeded',
          'quota_exceeded': true,
        };
      } else if (e.response?.statusCode == 429) {
        return {
          'success': false,
          'message': e.response?.data['error'] ?? 'Rate limit exceeded. Please try again in a few minutes.',
          'rate_limited': true,
        };
      } else {
        return {
          'success': false,
          'message': e.response?.data['error'] ?? 'Network error. Please try again.',
        };
      }
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  // ===================================================
  // 2. IMPORT FROM FILE (.bib, .ris)
  // ===================================================
  static Future<Map<String, dynamic>> importFromFile({
    required File file,
    String? parentId,
  }) async {
    try {
      debugPrint('📂 Importing file: ${file.path}');

      // Create form data
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
        'parent_id': parentId ?? '',
      });

      final response = await _dio.post(
        '/api/import/file',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.statusCode == 201 && response.data['success']) {
        final data = response.data['data'];
        debugPrint('✅ File import successful: ${data['success']} / ${data['total']} entries');
        
        return {
          'success': true,
          'message': response.data['message'],
          'total': data['total'],
          'success_count': data['success'],
          'failed_count': data['failed'],
          'items': data['items'],
          'errors': data['errors'] ?? [],
        };
      } else {
        debugPrint('❌ File import failed: ${response.data}');
        return {
          'success': false,
          'message': response.data['error'] ?? 'File import failed',
        };
      }
    } on DioException catch (e) {
      debugPrint('❌ File import error: ${e.message}');
      return {
        'success': false,
        'message': e.response?.data['error'] ?? 'Failed to upload file',
      };
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  // ===================================================
  // 3. MANUAL ENTRY
  // ===================================================
  static Future<Map<String, dynamic>> importManual({
    required String title,
    String? authors, // Comma-separated
    int? year,
    String? publisher,
    String? abstract,
    String? journal,
    String? doi,
    String? itemType, // 'article', 'book', 'webpage', etc.
    String? parentId,
  }) async {
    try {
      debugPrint('✍️ Manual entry: $title');

      final response = await _dio.post(
        '/api/import/manual',
        data: {
          'title': title,
          'authors': authors ?? '',
          'year': year,
          'publisher': publisher ?? '',
          'abstract': abstract ?? '',
          'journal': journal ?? '',
          'doi': doi ?? '',
          'item_type': itemType ?? 'article',
          'parent_id': parentId,
        },
      );

      if (response.statusCode == 201 && response.data['success']) {
        debugPrint('✅ Manual entry successful');
        return {
          'success': true,
          'data': response.data['data'],
          'message': response.data['message'],
        };
      } else {
        debugPrint('❌ Manual entry failed: ${response.data}');
        return {
          'success': false,
          'message': response.data['error'] ?? 'Manual entry failed',
        };
      }
    } on DioException catch (e) {
      debugPrint('❌ Manual entry error: ${e.message}');
      return {
        'success': false,
        'message': e.response?.data['error'] ?? 'Failed to create entry',
      };
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }
}
