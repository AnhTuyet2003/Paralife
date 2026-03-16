import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://10.0.2.2:3000',
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
  ));

  // ✅ INTERCEPTOR TỰ ĐỘNG REFRESH TOKEN
  static void setupInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            // ✅ LUÔN LẤY TOKEN MỚI
            final token = await user.getIdToken(true); // forceRefresh = true
            options.headers['Authorization'] = 'Bearer $token';
          } catch (e) {
            debugPrint('❌ Token refresh error: $e');
          }
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        if (error.response?.statusCode == 401) {
          final errorCode = error.response?.data['code'];
          
          if (errorCode == 'TOKEN_EXPIRED') {
            
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              try {
                final newToken = await user.getIdToken(true);
                
                final options = error.requestOptions;
                options.headers['Authorization'] = 'Bearer $newToken';
                
                final response = await _dio.fetch(options);
                return handler.resolve(response);
              } catch (refreshError) {
                await FirebaseAuth.instance.signOut();
              }
            }
          }
        }
        
        return handler.next(error);
      },
    ));
  }

  static Dio get dio => _dio;
}