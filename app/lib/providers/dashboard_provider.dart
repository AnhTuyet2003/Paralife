// lib/providers/dashboard_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class DashboardProvider with ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://10.0.2.2:3000',
    connectTimeout: Duration(seconds: 5),  // ✅ GIẢM từ 15s → 5s
    receiveTimeout: Duration(seconds: 5),  // ✅ GIẢM từ 15s → 5s
  ));
  
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _statsData;  // ✅ NEW: Stats data
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;
  bool _isFetching = false;
  String? _cachedToken;

  Map<String, dynamic>? get dashboardData => _dashboardData;
  Map<String, dynamic>? get statsData => _statsData;  // ✅ NEW
  bool get isLoading => _isLoading;
  String? get error => _error;

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (!_isFetching) {
        fetchDashboard(showLoading: false);
      }
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
  }

  Future<void> fetchDashboard({bool showLoading = true}) async {
    if (_isFetching) {
      return;
    }

    _isFetching = true;

    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // ✅ CHECK: Firebase phải được init trước
      if (Firebase.apps.isEmpty) {
        debugPrint('⚠️ Firebase not initialized, using mock data');
        _dashboardData = {
          'usage_bytes': 0,
          'favorites': [],
          'recents': [],
        };
        _error = null;
        return;
      }
      
      User? user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        debugPrint('⚠️ No user logged in, using mock data');
        _dashboardData = {
          'usage_bytes': 0,
          'favorites': [],
          'recents': [],
        };
        _error = null;
        return;
      }

      // SỬA: Optimized token fetching
      String? token = _cachedToken;
      if (token == null) {
        // Không delay, Firebase Auth đã sẵn sàng khi user != null
        token = await user.getIdToken(false).timeout(
          Duration(seconds: 5), // Giảm timeout xuống 5s
          onTimeout: () => null,
        );
        
        // Nếu timeout, thử lần cuối với forceRefresh
        token ??= await user.getIdToken(true).timeout(
            Duration(seconds: 3),
            onTimeout: () => throw Exception('Token fetch timeout'),
          );
        
        if (token != null) {
          _cachedToken = token;
        }
      }

      if (token == null || token.isEmpty) {
        throw Exception('Could not get Firebase token');
      }

      final response = await _dio.get(
        '/api/dashboard/overview',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        // Map backend keys to expected frontend keys
        final data = response.data;
        _dashboardData = {
          ...data,
          'recents': data['recent_files'] ?? [], // Map recent_files -> recents
          'favorites': data['favorites'] ?? [],
        };
        _error = null;
      } else if (response.statusCode == 401) {
        // Token expired, clear cache và retry
        _cachedToken = null;
        _isFetching = false;
        return fetchDashboard(showLoading: false); // Retry without showing loading
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Dashboard fetch error: $e');
    } finally {
      _isFetching = false;
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  // ✅ NEW: Fetch Stats (Usage, Articles, Topic Distribution)
  Future<void> fetchStats({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('⚠️ Firebase not initialized, using mock stats');
        _statsData = {
          'used_bytes': 0,
          'total_bytes': 314572800,
          'usage_percent': 0.0,
          'total_articles': 0,
          'topic_distribution': []
        };
        _error = null;
        return;
      }

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _statsData = {
          'used_bytes': 0,
          'total_bytes': 314572800,
          'usage_percent': 0.0,
          'total_articles': 0,
          'topic_distribution': []
        };
        _error = null;
        return;
      }

      String? token = _cachedToken;
      if (token == null) {
        token = await user.getIdToken(false).timeout(
          Duration(seconds: 5),
          onTimeout: () => null,
        );
        if (token != null) {
          _cachedToken = token;
        }
      }

      if (token == null || token.isEmpty) {
        throw Exception('Could not get Firebase token');
      }

      final response = await _dio.get(
        '/api/dashboard/stats',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        _statsData = response.data['stats'];
        _error = null;
        debugPrint('✅ Stats loaded: ${_statsData?['total_articles']} articles');
      } else if (response.statusCode == 401) {
        _cachedToken = null;
        return fetchStats(showLoading: false);
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Stats fetch error: $e');
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopAutoRefresh();
    _dio.close();
    super.dispose();
  }
}