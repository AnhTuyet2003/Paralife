import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class CloudScreen extends StatefulWidget {
  const CloudScreen({super.key});

  @override
  State<CloudScreen> createState() => _CloudScreenState();
}

class _CloudScreenState extends State<CloudScreen> {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://10.0.2.2:3000',
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 10),
  ));

  List<CloudProvider> _cloudProviders = [];
  bool _isLoading = true;
  String _preferredStorage = 'auto'; // auto, local, gdrive, dropbox, onedrive
  bool _isLoadingPreference = true;

  @override
  void initState() {
    super.initState();
    _loadCloudStatus();
    _loadStoragePreference();
  }

  // ================== LOAD CLOUD STATUS ==================
  Future<void> _loadCloudStatus() async {
    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      final response = await _dio.get(
        '/api/cloud/status',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!mounted) return;

      setState(() {
        _cloudProviders = (response.data['providers'] as List)
            .map((p) => CloudProvider.fromJson(p))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
      );
    }
  }

  // ================== LOAD STORAGE PREFERENCE ==================
  Future<void> _loadStoragePreference() async {
    setState(() => _isLoadingPreference = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();
      
      // 🔑 Debug: Print token for Postman testing
      debugPrint('🔑 Firebase Token for Postman: $token');

      final response = await _dio.get(
        '/api/user/storage-preference',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!mounted) return;

      setState(() {
        _preferredStorage = response.data['preferred_storage'] ?? 'auto';
        _isLoadingPreference = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preferredStorage = 'auto';
        _isLoadingPreference = false;
      });
      debugPrint('Lỗi tải storage preference: $e');
    }
  }

  // ================== UPDATE STORAGE PREFERENCE ==================
  Future<void> _updateStoragePreference(String newPreference) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      await _dio.patch(
        '/api/user/storage-preference',
        data: {'preferred_storage': newPreference},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!mounted) return;

      setState(() {
        _preferredStorage = newPreference;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã cập nhật nơi lưu trữ: ${_getStorageLabel(newPreference)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi cập nhật: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getStorageLabel(String storage) {
    switch (storage) {
      case 'auto':
        return 'Tự động (ưu tiên cloud)';
      case 'local':
        return 'Server nội bộ';
      case 'gdrive':
        return 'Google Drive';
      case 'dropbox':
        return 'Dropbox';
      case 'onedrive':
        return 'OneDrive';
      default:
        return storage;
    }
  }

  // ================== TEST STORAGE STRATEGY ==================
  Future<void> _testStorageStrategy() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      final response = await _dio.get(
        '/api/user/test-storage-strategy',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!mounted) return;

      final data = response.data;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 10),
              Text('Storage Strategy Test'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('User ID:', data['user_id'] ?? 'N/A'),
                _buildInfoRow('Email:', data['user_email'] ?? 'N/A'),
                SizedBox(height: 12),
                Divider(),
                SizedBox(height: 12),
                _buildInfoRow('Provider:', data['provider'] ?? 'N/A', 
                  valueColor: data['provider'] == 'gdrive' ? Colors.blue : 
                             data['provider'] == 'local' ? Colors.grey : Colors.green),
                _buildInfoRow('Quota Check:', data['requiresQuotaCheck'].toString()),
                if (data['cloudEmail'] != null)
                  _buildInfoRow('Cloud Email:', data['cloudEmail']),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: data['provider'] == 'local' ? Colors.orange.withValues(alpha: .1) : Colors.green.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        data['provider'] == 'local' ? Icons.warning : Icons.check_circle,
                        color: data['provider'] == 'local' ? Colors.orange : Colors.green,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['provider'] == 'local' 
                            ? 'Files will be saved to local server'
                            : 'Files will be saved to ${_getStorageLabel(data['provider'])}',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Copy JSON'),
              onPressed: () {
                debugPrint('📋 Storage Strategy Result: ${response.data}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('JSON printed to debug console')),
                );
              },
            ),
            ElevatedButton(
              child: Text('Close'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Test failed: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      debugPrint('❌ Storage Strategy Test Error: $e');
    }
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? Colors.black87,
                fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================== LINK CLOUD PROVIDER ==================
  Future<void> _linkCloudProvider(String provider) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Liên kết ${_getProviderName(provider)}'),
        content: Text('Bạn sẽ được chuyển đến trang đăng nhập ${_getProviderName(provider)} để cấp quyền truy cập.\n\nSau khi hoàn tất, hãy quay lại ứng dụng để kiểm tra kết nối.'),
        actions: [
          TextButton(
            child: Text('Hủy'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Tiếp tục'),
            onPressed: () async {
              Navigator.pop(context);
              await _launchOAuthFlow(provider);
            },
          ),
        ],
      ),
    );
  }

  // ================== LAUNCH OAUTH FLOW ==================
  Future<void> _launchOAuthFlow(String provider) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Đang tải...'),
              ],
            ),
          ),
        ),
      );

      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      // Gọi API để lấy OAuth URL
      final response = await _dio.get(
        '/api/cloud/$provider/auth',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final authUrl = response.data['auth_url'];
      if (authUrl == null || authUrl.isEmpty) {
        throw Exception('Không nhận được OAuth URL từ server');
      }

      // Mở OAuth URL trong external browser (PC's default browser)
      final Uri uri = Uri.parse(authUrl);
      if (!await launchUrl(
        uri, 
        mode: LaunchMode.platformDefault, // Dùng browser mặc định của hệ thống
        webOnlyWindowName: '_blank',
      )) {
        throw Exception('Không thể mở trình duyệt');
      }

      // Show instruction dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 10),
              Text('Cấp quyền truy cập'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trình duyệt đã được mở.'),
              SizedBox(height: 10),
              Text('Vui lòng:'),
              SizedBox(height: 5),
              Text('1. Đăng nhập ${_getProviderName(provider)}'),
              Text('2. Cấp quyền cho ứng dụng Refmind'),
              Text('3. Sau đó quay lại đây và nhấn "Kiểm tra"'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Đóng'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text('Kiểm tra kết nối'),
              onPressed: () async {
                Navigator.pop(context);
                await _checkConnectionStatus(provider);
              },
            ),
          ],
        ),
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close any dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================== CHECK CONNECTION STATUS ==================
  Future<void> _checkConnectionStatus(String provider) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Đang kiểm tra...'),
              ],
            ),
          ),
        ),
      );

      // Wait a bit for OAuth callback to complete
      await Future.delayed(Duration(seconds: 2));

      // Reload cloud status
      await _loadCloudStatus();

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      // Check if provider was added
      final hasProvider = _cloudProviders.any(
        (p) => p.provider == provider && p.isActive,
      );

      if (hasProvider) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Liên kết ${_getProviderName(provider)} thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Chưa nhận được xác nhận liên kết. Vui lòng thử lại.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kiểm tra kết nối: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================== HANDLE DISCONNECT ==================
  Future<void> _handleDisconnect(CloudProvider provider) async {
    try {
      // Lấy Firebase token
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      // Gọi DELETE API
      await _dio.delete(
        '/api/cloud/${provider.id}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã ngắt kết nối ${provider.provider}'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload danh sách
      await _loadCloudStatus();
      await _loadStoragePreference();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================== SHOW ADD PROVIDER MENU ==================
  void _showAddProviderMenu() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Liên kết dịch vụ lưu trữ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            
            _buildProviderOption(
              icon: Icons.cloud,
              iconColor: Color(0xFF4285F4),
              title: 'Google Drive',
              subtitle: 'Dung lượng: 15 GB miễn phí',
              onTap: () {
                Navigator.pop(context);
                _linkCloudProvider('gdrive');
              },
            ),
            
            _buildProviderOption(
              icon: Icons.folder,
              iconColor: Color(0xFF0061FF),
              title: 'Dropbox',
              subtitle: 'Dung lượng: 2 GB miễn phí',
              onTap: () {
                Navigator.pop(context);
                _linkCloudProvider('dropbox');
              },
            ),
            
            _buildProviderOption(
              icon: Icons.cloud_outlined,
              iconColor: Color(0xFF0078D4),
              title: 'OneDrive',
              subtitle: 'Dung lượng: 5 GB miễn phí',
              onTap: () {
                Navigator.pop(context);
                _linkCloudProvider('onedrive');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 28),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  String _getProviderName(String provider) {
    switch (provider) {
      case 'gdrive':
        return 'Google Drive';
      case 'dropbox':
        return 'Dropbox';
      case 'onedrive':
        return 'OneDrive';
      default:
        return 'Cloud Storage';
    }
  }

  // ================== BUILD STORAGE PREFERENCE SELECTOR ==================
  Widget _buildStoragePreferenceSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, size: 20, color: Colors.grey[700]),
              SizedBox(width: 8),
              Text(
                'Nơi lưu trữ tài liệu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _isLoadingPreference
              ? Center(child: CircularProgressIndicator())
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStorageChip(
                      label: '🤖 Tự động',
                      value: 'auto',
                      isSelected: _preferredStorage == 'auto',
                    ),
                    _buildStorageChip(
                      label: '🖥️ Server',
                      value: 'local',
                      isSelected: _preferredStorage == 'local',
                    ),
                    _buildStorageChip(
                      label: '📁 Google Drive',
                      value: 'gdrive',
                      isSelected: _preferredStorage == 'gdrive',
                      isDisabled: !_isProviderConnected('gdrive'),
                    ),
                    _buildStorageChip(
                      label: '📦 Dropbox',
                      value: 'dropbox',
                      isSelected: _preferredStorage == 'dropbox',
                      isDisabled: !_isProviderConnected('dropbox'),
                    ),
                    _buildStorageChip(
                      label: '☁️ OneDrive',
                      value: 'onedrive',
                      isSelected: _preferredStorage == 'onedrive',
                      isDisabled: !_isProviderConnected('onedrive'),
                    ),
                  ],
                ),
          if (_preferredStorage != 'auto' && _preferredStorage != 'local')
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                _isProviderConnected(_preferredStorage)
                    ? '✅ Tài liệu mới sẽ được lưu vào ${_getStorageLabel(_preferredStorage)}'
                    : '⚠️ Chưa kết nối ${_getStorageLabel(_preferredStorage)}. Tài liệu sẽ lưu vào server.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStorageChip({
    required String label,
    required String value,
    required bool isSelected,
    bool isDisabled = false,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: isDisabled
          ? null
          : (selected) {
              if (selected) {
                _updateStoragePreference(value);
              }
            },
      selectedColor: Color(0xFF2D60FF).withValues(alpha: .2),
      checkmarkColor: Color(0xFF2D60FF),
      backgroundColor: Colors.white,
      disabledColor: Colors.grey[200],
      labelStyle: TextStyle(
        color: isDisabled
            ? Colors.grey[400]
            : (isSelected ? Color(0xFF2D60FF) : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? Color(0xFF2D60FF)
            : (isDisabled ? Colors.grey[300]! : Colors.grey[400]!),
      ),
    );
  }

  bool _isProviderConnected(String provider) {
    return _cloudProviders.any((p) => p.provider == provider && p.isActive);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Cloud Storage',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Debug button: Test Storage Strategy
          IconButton(
            icon: Icon(Icons.bug_report, color: Colors.orange, size: 24),
            tooltip: 'Test Storage Strategy',
            onPressed: _testStorageStrategy,
          ),
          IconButton(
            icon: Icon(Icons.add, color: Color(0xFF2D60FF), size: 28),
            onPressed: _showAddProviderMenu,
          ),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Storage Preference Selector
                _buildStoragePreferenceSelector(),
                
                // Divider
                Divider(height: 1),
                
                // Cloud Providers Grid
                Expanded(
                  child: _cloudProviders.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadCloudStatus,
                          child: GridView.builder(
                            padding: EdgeInsets.all(16),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: _cloudProviders.length,
                            itemBuilder: (context, index) {
                              return CloudCard(
                                provider: _cloudProviders[index],
                                onDisconnect: _handleDisconnect,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 100, color: Colors.grey[300]),
          SizedBox(height: 20),
          Text(
            'Chưa liên kết dịch vụ nào',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Liên kết Google Drive hoặc Dropbox\nđể mở rộng dung lượng',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _showAddProviderMenu,
            icon: Icon(Icons.add),
            label: Text('Liên kết ngay'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2D60FF),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ================== CLOUD CARD WIDGET ==================
class CloudCard extends StatelessWidget {
  final CloudProvider provider;
  final Function(CloudProvider) onDisconnect;

  const CloudCard({super.key, required this.provider, required this.onDisconnect});

  @override
  Widget build(BuildContext context) {
    final usedGB = (provider.usedSpaceBytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
    final percentage = (provider.usedSpaceBytes / provider.totalSpaceBytes * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon và Menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildProviderIcon(provider.provider),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, color: Colors.grey[600]),
                  onSelected: (value) async {
                    if (value == 'disconnect') {
                      // Xóa liên kết
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Ngắt kết nối?'),
                          content: Text('Các file đã upload sẽ vẫn được giữ nguyên trên ${provider.email}.'),
                          actions: [
                            TextButton(
                              child: Text('Hủy'),
                              onPressed: () => Navigator.pop(context, false),
                            ),
                            ElevatedButton(
                              child: Text('Ngắt kết nối'),
                              onPressed: () => Navigator.pop(context, true),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        // Gọi callback tới parent để xử lý disconnect
                        onDisconnect(provider);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'disconnect', child: Text('Ngắt kết nối')),
                  ],
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Email
            Text(
              provider.email,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            SizedBox(height: 4),
            
            // Storage info
            Text(
              '${provider.itemCount} items • $usedGB GB',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            
            Spacer(),
            
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: provider.usedSpaceBytes / provider.totalSpaceBytes,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProgressColor(percentage),
                ),
                minHeight: 6,
              ),
            ),
            
            SizedBox(height: 6),
            
            // Percentage text
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getProgressColor(percentage),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderIcon(String provider) {
    IconData icon;
    Color color;

    switch (provider) {
      case 'gdrive':
        icon = Icons.cloud;
        color = Color(0xFF4285F4);
        break;
      case 'dropbox':
        icon = Icons.folder;
        color = Color(0xFF0061FF);
        break;
      case 'onedrive':
        icon = Icons.cloud_outlined;
        color = Color(0xFF0078D4);
        break;
      default:
        icon = Icons.cloud;
        color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Color _getProgressColor(int percentage) {
    if (percentage < 70) return Color(0xFF2D60FF);
    if (percentage < 90) return Colors.orange;
    return Colors.red;
  }
}

// ================== DATA MODEL ==================
class CloudProvider {
  final String id;
  final String provider;
  final String email;
  final int totalSpaceBytes;
  final int usedSpaceBytes;
  final int itemCount;
  final bool isActive;

  CloudProvider({
    required this.id,
    required this.provider,
    required this.email,
    required this.totalSpaceBytes,
    required this.usedSpaceBytes,
    required this.itemCount,
    required this.isActive,
  });

  factory CloudProvider.fromJson(Map<String, dynamic> json) {
    return CloudProvider(
      id: json['id'] ?? '',
      provider: json['provider'] ?? '',
      email: json['email'] ?? '',
      totalSpaceBytes: _parseInt(json['total_space_bytes']),
      usedSpaceBytes: _parseInt(json['used_space_bytes']),
      itemCount: _parseInt(json['item_count']),
      isActive: json['is_active'] ?? false,
    );
  }

  // Helper method to safely parse int from dynamic (can be String or int)
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
