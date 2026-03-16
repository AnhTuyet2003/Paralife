import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_key_screen.dart';

class ApiManagementScreen extends StatefulWidget {
  const ApiManagementScreen({super.key});
  @override
  State<ApiManagementScreen> createState() => _ApiManagementScreenState();
}

class _ApiManagementScreenState extends State<ApiManagementScreen> {
  bool _isLoading = true;
  
  bool _hasOpenAI = false;
  bool _hasGemini = false;

  String _activeProvider = "system";

  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:3000'));

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();
      
      final response = await _dio.get(
        '/api/user/keys/status',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      setState(() {
        _activeProvider = response.data['active_provider'] ?? "system"; 
        _hasOpenAI = response.data['has_openai'] ?? false;
        _hasGemini = response.data['has_gemini'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      throw("lỗi tải trạng thái API keys: $e");
    }
  }

  Future<void> _handleModeChange(String provider) async {
    // provider sẽ là: 'system', 'openai', hoặc 'gemini'
    
    if (provider == 'system') {
      await _updateProvider('system');
      setState(() => _activeProvider = 'system');
      return;
    }

    bool hasKey = (provider == 'openai') ? _hasOpenAI : _hasGemini;
    
    if (hasKey) {
      await _updateProvider(provider);
      setState(() => _activeProvider = provider);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Switched to $provider")));
      }
    } else {
      int tabIndex = (provider == 'openai') ? 0 : 1;
      _goToEditScreen(tabIndex);
    }
  }

  Future<void> _updateProvider(String provider) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();
      
      await _dio.post(
        '/api/user/keys',
        data: {
          "active_provider": provider,
          "openai_key": null, 
          "gemini_key": null 
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating mode")));
      }
    }
  }

  // Chuyển sang màn hình Edit
  void _goToEditScreen(int tabIndex) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApiKeyScreen(
          isFromSettings: true,
          initialIndex: tabIndex, 
        ),
      ),
    );
    _fetchStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("API Configuration", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.black),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  // Option 1: System Default
                  _buildOptionCard(
                    index: 0,
                    title: "System Default",
                    subtitle: "Free, limited speed & requests",
                    icon: Icons.cloud_queue,
                    isSelected: _activeProvider == 'system', 
                    onTap: () => _handleModeChange('system'), 
                  ),
                  SizedBox(height: 16),

                  // Option 2: OpenAI
                  _buildOptionCard(
                    index: 1,
                    title: "OpenAI (GPT-4o)",
                    subtitle: _hasOpenAI ? "Key configured • Ready to use" : "No key provided",
                    icon: Icons.bolt,
                    isSelected: _activeProvider == 'openai',
                    onTap: () => _handleModeChange('openai'),
                    hasKey: _hasOpenAI,
                    onEdit: () => _goToEditScreen(0), 
                  ),
                  SizedBox(height: 16),

                  // Option 3: Gemini
                  _buildOptionCard(
                    index: 2,
                    title: "Google Gemini",
                    subtitle: _hasGemini ? "Key configured • Ready to use" : "No key provided",
                    icon: Icons.auto_awesome,
                    isSelected: _activeProvider == 'gemini',
                    onTap: () => _handleModeChange('gemini'),
                    hasKey: _hasGemini,
                    onEdit: () => _goToEditScreen(1), 
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOptionCard({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool? hasKey, 
    VoidCallback? onEdit,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF2D60FF).withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Color(0xFF2D60FF) : Colors.grey[200]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Radio Icon
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? Color(0xFF2D60FF) : Colors.grey,
            ),
            SizedBox(width: 16),
            
            // Icon Provider
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.black87, size: 20),
            ),
            SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: hasKey == false ? Colors.red[400] : Colors.grey, fontSize: 12)),
                ],
              ),
            ),

            // Edit Button (Chỉ hiện cho OpenAI/Gemini)
            if (hasKey != null) 
              IconButton(
                icon: Icon(Icons.edit_outlined, color: Colors.grey),
                onPressed: onEdit,
              )
          ],
        ),
      ),
    );
  }
}