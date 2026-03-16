import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart'; 
import 'package:url_launcher/url_launcher.dart';

class ApiKeyScreen extends StatefulWidget {
  final bool isFromSettings; 
  final int initialIndex;
  const ApiKeyScreen({super.key, this.isFromSettings = false, this.initialIndex = 1});
  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  late int _selectedIndex; // Mặc định chọn Gemini (1), OpenAI (0)
  final _openaiController = TextEditingController();
  final _geminiController = TextEditingController();
  bool _isLoading = false;
  final bool _isObscure = true; 

  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:3000'));
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  Future<void> _saveKeys({bool skip = false}) async {
    setState(() => _isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      if (token == null) throw Exception("User not found");
      String provider = skip ? 'system' : (_selectedIndex == 0 ? 'openai' : 'gemini');

      await _dio.post(
        '/api/user/keys',
        data: {
          "active_provider": provider,
          
          "openai_key": (!skip && _selectedIndex == 0) ? _openaiController.text.trim() : null,
          "gemini_key": (!skip && _selectedIndex == 1) ? _geminiController.text.trim() : null,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi lưu Key: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 40),
              // Logo
              Icon(Icons.vpn_key, size: 40, color: Colors.black), 
              SizedBox(height: 20),
              
              Text("Power Up Your AI", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text(
                "Connect your OpenAI or Gemini API key to enable unlimited reading, chatting, and analysis.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
              SizedBox(height: 30),

              // --- TOGGLE SWITCH ---
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTabButton("OpenAI Key", 0),
                    _buildTabButton("Google Gemini Key", 1),
                  ],
                ),
              ),
              SizedBox(height: 30),

              // --- INPUT FIELD ---
              Align(alignment: Alignment.centerLeft, child: Text("API Key", style: TextStyle(fontWeight: FontWeight.w500))),
              SizedBox(height: 8),
              TextField(
                controller: _selectedIndex == 0 ? _openaiController : _geminiController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  hintText: "********",
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.person_outline, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: (_isLoading || (_selectedIndex == 0 ? _openaiController.text.isEmpty : _geminiController.text.isEmpty))
                        ? null // Nếu đang load HOẶC ô text trống -> Disable nút
                        : () => _saveKeys(skip: false),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onChanged: (val) {
                  setState(() {});
                },
              ),
              SizedBox(height: 16),

              // --- LINK GET KEY ---
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.open_in_new, size: 16),
                  label: Text("Get API Key here"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2D60FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final Uri uri = Uri.parse(
                      _selectedIndex == 0
                          ? 'https://platform.openai.com/api-keys'
                          : 'https://aistudio.google.com/app/apikey',
                    );

                    if (!await canLaunchUrl(uri)) {
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Không thể mở trình duyệt!")),
                      );
                      return;
                    }

                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ),
              
              SizedBox(height: 30),
              Text("OR Use System Default Key", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text("Limited to 5 queries/day. Slower response.", style: TextStyle(color: Colors.grey, fontSize: 12)),
              
              Spacer(),

              // --- BUTTONS ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _saveKeys(skip: false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2D60FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Verify & Continue", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading 
                    ? null 
                    : () {
                        if (widget.isFromSettings) {
                          // Từ settings → quay lại settings
                          Navigator.of(context).pop();
                        } else {
                          // Từ đăng ký → đến home
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => HomeScreen()),
                            (route) => false,
                          );
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Skip for now"),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 2)] : [],
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}