import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import 'api_key_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();

  bool isLogin = true; 
  bool isLoading = false;
  bool _rememberMe = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final email = await _storage.read(key: 'saved_email');
      final password = await _storage.read(key: 'saved_password');
      final rememberMe = await _storage.read(key: 'remember_me');

      if (email != null && password != null && rememberMe == 'true') {
        setState(() {
          _emailController.text = email;
          _passwordController.text = password;
          _rememberMe = true;
        });
      }
    } catch (e) {
      throw Exception("Lỗi tải thông tin đã lưu: $e");
    }
  }

  Future<void> _saveCredentials() async {
    if (_rememberMe) {
      await _storage.write(key: 'saved_email', value: _emailController.text.trim());
      await _storage.write(key: 'saved_password', value: _passwordController.text.trim());
      await _storage.write(key: 'remember_me', value: 'true');
    } else {
      await _storage.delete(key: 'saved_email');
      await _storage.delete(key: 'saved_password');
      await _storage.delete(key: 'remember_me');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _submitAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    
    try {
      if (isLogin) {
        // ✅ ĐĂNG NHẬP
        
        await _authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        
        await _saveCredentials();
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen()),
          );
        }
      } else {
        // ✅ ĐĂNG KÝ
        
        String fullName = "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";
        
        User? user = await _authService.registerWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          fullName,
        );

        if (user != null && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => ApiKeyScreen()),
          );
        }
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Đóng',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                Icon(Icons.incomplete_circle, size: 40), 
                SizedBox(height: 20),
                
                Text("Get Started now", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                  "Create an account or log in to explore about our app",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 30),

                // --- TOGGLE SWITCH (Login / Sign Up) ---
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildToggleButton("Log In", true),
                      _buildToggleButton("Sign Up", false),
                    ],
                  ),
                ),
                SizedBox(height: 30),

                // --- CÁC TRƯỜNG NHẬP LIỆU ---
                if (!isLogin) ...[
                  Row(
                    children: [
                      Expanded(child: _buildTextField(controller: _firstNameController, label: "First Name")),
                      SizedBox(width: 10),
                      Expanded(child: _buildTextField(controller: _lastNameController, label: "Last Name")),
                    ],
                  ),
                  SizedBox(height: 16),
                ],

                _buildTextField(controller: _emailController, label: "Email", isEmail: true),
                SizedBox(height: 16),

                if (!isLogin) ...[
                   GestureDetector(
                    onTap: () => _selectDate(context),
                    child: AbsorbPointer(
                      child: _buildTextField(
                        controller: _dobController, 
                        label: "Date of birth", 
                        suffixIcon: Icons.calendar_today
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildTextField(controller: _phoneController, label: "Phone Number", isPhone: true),
                  SizedBox(height: 16),
                ],

                _buildTextField(
                  controller: _passwordController, 
                  label: isLogin ? "Password" : "Set Password", 
                  isPassword: true
                ),

                // --- QUÊN MẬT KHẨU / REMEMBER ME ---
                if (isLogin) ...[
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe, 
                            onChanged: (v) {
                              setState(() => _rememberMe = v ?? false);
                            }
                          ),
                          Text("Remember me", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                      // ✅ NÚT FORGOT PASSWORD
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: Text(
                          "Forgot Password?", 
                          style: TextStyle(
                            color: Color(0xFF2D60FF),
                            fontWeight: FontWeight.w600,
                          )
                        )
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 20),

                // --- NÚT SUBMIT ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2D60FF), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading 
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(isLogin ? "Log In" : "Register", style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),

                SizedBox(height: 30),
                
                // --- SOCIAL LOGIN ---
                if (isLogin) ...[
                  Text("Or login with", style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(Icons.g_mobiledata, () async {
                         final navigator = Navigator.of(context);
                         final user = await _authService.signInWithGoogle();
                         if (user != null && mounted) {
                           navigator.pushReplacement(
                             MaterialPageRoute(builder: (_) => HomeScreen()),
                           );
                         }
                      }), 
                    ],
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget con: Ô nhập liệu
  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    bool isPassword = false,
    bool isEmail = false,
    bool isPhone = false,
    IconData? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: isEmail ? TextInputType.emailAddress : (isPhone ? TextInputType.phone : TextInputType.text),
          validator: (value) {
            if (value == null || value.isEmpty) return "Vui lòng nhập $label";
            return null;
          },
          decoration: InputDecoration(
            hintText: label,
            hintStyle: TextStyle(color: Colors.grey[400]),
            suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.grey) : (isPassword ? Icon(Icons.visibility_off, color: Colors.grey) : null),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  // Widget con: Nút Toggle
  Widget _buildToggleButton(String text, bool isLoginBtn) {
    bool isSelected = isLogin == isLoginBtn;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => isLogin = isLoginBtn);
          _formKey.currentState?.reset(); 
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
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

  // Widget con: Nút Social
  Widget _buildSocialButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 30, color: Colors.black87),
      ),
    );
  }
}