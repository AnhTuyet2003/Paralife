import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:dio/dio.dart'; 
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import 'auth_screen.dart';
import 'api_management_screen.dart';
import 'personal_info_screen.dart'; 
import 'security_screen.dart';
import 'knowledge_graph_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with AutomaticKeepAliveClientMixin {
  User? user = FirebaseAuth.instance.currentUser;
  final AuthService _authService = AuthService();
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://10.0.2.2:3000', // SỬA: Từ 8000 → 3000 (Node.js Gateway)
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 10),
  ));
  
  bool _isUploading = false;
  bool _isLoadingProfile = true;
  bool _loadingInProgress = false; // FLAG: Tránh concurrent fetch
  
  String? _backendAvatarUrl;
  String? _backendFullName;
  String? _backendEmail;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // THÊM: Hook để reload khi tab được focus lại
  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _loadUserProfile({bool force = false}) async {
    if (_loadingInProgress && !force) {
      return;
    }

    _loadingInProgress = true;
    
    if (mounted) {
      setState(() => _isLoadingProfile = true);
    }
      
    try {     
      String? token = await user?.getIdToken(true).timeout(
        Duration(seconds: 15),
        onTimeout: () {
          return null;
        },
      );
      
      if (token == null) {
        if (mounted) {
          setState(() => _isLoadingProfile = false);
        }
        return;
      }

      final response = await _dio.get(
        '/api/user/profile',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Cache-Control': 'no-cache', // Force no cache
          },
          validateStatus: (status) => status! < 500,
        ),
      ).timeout(
        Duration(seconds: 15),
        onTimeout: () {
          throw DioException(
            requestOptions: RequestOptions(path: '/api/user/profile'),
            type: DioExceptionType.connectionTimeout,
          );
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final userData = response.data['user'];
        
        if (mounted) {
          setState(() {
            _backendFullName = userData['full_name'];
            _backendEmail = userData['email'];
            _backendAvatarUrl = userData['avatar_url'];
            _isLoadingProfile = false;
          });
        }
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException) {
      }
      
      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load profile. Using cached data.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      _loadingInProgress = false;
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _isUploading = true);

      try {
        String? token = await user?.getIdToken(true).timeout(
          Duration(seconds: 15),
          onTimeout: () => null,
        );
        
        if (token == null) {
          throw Exception('Failed to get authentication token');
        }

        String fileName = image.path.split('/').last;

        FormData formData = FormData.fromMap({
          "file": await MultipartFile.fromFile(image.path, filename: fileName),
        });

        final response = await _dio.post(
          '/api/user/avatar',
          data: formData,
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            validateStatus: (status) => status! < 500,
          ),
        ).timeout(Duration(seconds: 30));


        if (response.statusCode == 200 && response.data['success'] == true) {
          // ✅ LẤY URL TỪ RESPONSE
          String newAvatarUrl = response.data['avatar_url'];
          
          // ✅ DEBUG

          if (mounted) {
            setState(() {
              // ✅ CẬP NHẬT NGAY
              _backendAvatarUrl = newAvatarUrl;
              _isUploading = false;
            });

            // ✅ RELOAD PROFILE ĐỂ XÁC NHẬN
            await _loadUserProfile(force: true);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Avatar updated successfully!"),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        } else {
          throw Exception('Upload failed: ${response.data}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to upload avatar: ${e.toString()}"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    } else {
      throw('⚠️ No image selected');
    }
  }

  void _navigateTo(Widget screen) async { 
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    if (result != null) {
      if (result is Map<String, dynamic>) {
        
        if (mounted) {
          setState(() {
            _backendFullName = result['full_name'];
            _backendEmail = result['email'];
            _backendAvatarUrl = result['avatar_url'];
            _isLoadingProfile = false;
          });
        }
        return; 
      }
    }

    try {
      
      if (mounted) {
        await user?.reload();
        setState(() {
          user = FirebaseAuth.instance.currentUser;
        });
        await _loadUserProfile(force: true);
      }
    } catch (e) {
      if (mounted) {
        await Future.delayed(Duration(milliseconds: 500));
        await _loadUserProfile(force: true);
      }
    }
  }

  Widget _buildAvatarWidget() {
    String? displayAvatar;
    bool hasAvatar = false;
    
    if (_backendAvatarUrl != null && _backendAvatarUrl!.isNotEmpty) {
      String cleanUrl = _backendAvatarUrl!.split('?').first;
      
      
      if (cleanUrl.startsWith('/uploads/')) {
        final String cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
        displayAvatar = "http://10.0.2.2:3000$cleanUrl?v=$cacheBuster";
        hasAvatar = true;
      } else if (cleanUrl.startsWith('http')) {
        final String cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
        displayAvatar = "$cleanUrl?v=$cacheBuster";
        hasAvatar = true;
      } else {
      }
    } else if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
      final String cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
      displayAvatar = "${user!.photoURL}?v=$cacheBuster";
      hasAvatar = true;
    } else {
    }
    
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey[200]!, width: 2),
      ),
      child: _isUploading
          ? CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[100],
              child: CircularProgressIndicator(),
            )
          : hasAvatar && displayAvatar != null
              ? CircleAvatar(
                  radius: 50,
                  key: ValueKey(displayAvatar),
                  backgroundImage: NetworkImage(displayAvatar),
                  backgroundColor: Colors.grey[100],
                  onBackgroundImageError: (exception, stackTrace) {
                  },
                )
              : CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF2D60FF).withValues(alpha: .1),
                  child: Icon(Icons.person, size: 50, color: Color(0xFF2D60FF)),
                ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final displayName = _backendFullName ?? user?.displayName ?? "User Name";
    final displayEmail = _backendEmail ?? user?.email ?? "user@email.com";
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, 
      ),
      body: _isLoadingProfile
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading profile...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                children: [
                  SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickAndUploadImage, 
                    child: Stack(
                      children: [
                        _buildAvatarWidget(),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Color(0xFF2D60FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(Icons.camera_alt, color: Colors.white, size: 14),
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(displayName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(displayEmail, style: TextStyle(color: Colors.grey, fontSize: 14)),
                  SizedBox(height: 30),

                  _buildSectionHeader("Account Settings"),
                  _buildSettingsGroup([
                    _buildTile(
                      Icons.person_outline, 
                      "Personal Information", 
                      onTap: () => _navigateTo(PersonalInfoScreen()) 
                    ),
                    _buildTile(
                      Icons.lock_outline, 
                      "Password & Security", 
                      onTap: () => _navigateTo(SecurityScreen()) 
                    ),
                    _buildTile(Icons.payment_outlined, "Payment Methods", onTap: () {}),
                  ]),

                  SizedBox(height: 20),

                  _buildSectionHeader("App Settings"),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor, 
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Consumer<ThemeProvider>(
                          builder: (context, theme, _) => SwitchListTile(
                            secondary: Container(
                               padding: EdgeInsets.all(8),
                               decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                               child: Icon(Icons.notifications_outlined, color: Color(0xFF2D60FF), size: 20),
                            ),
                            title: Text("Notifications", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            value: theme.enableNotifications,
                            onChanged: (bool value) {
                              theme.toggleNotifications(value);
                            },
                            activeThumbColor: Color(0xFF2D60FF),
                          ),
                        ),
                        
                        Divider(height: 1, indent: 60),

                        _buildTile(Icons.language, "Language", trailingText: "English"),
                        
                        _buildTile(Icons.vpn_key_outlined, "API Keys", subtitle: "Manage AI providers", onTap: () => _navigateTo(ApiManagementScreen())),
                        
                        Divider(height: 1, indent: 60),
                        
                        // Font Size Slider
                        Consumer<ThemeProvider>(
                          builder: (context, theme, _) => ListTile(
                            leading: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                              child: Icon(Icons.format_size, color: Color(0xFF2D60FF), size: 20),
                            ),
                            title: Text("Font Size", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('A', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Expanded(
                                      child: Slider(
                                        value: theme.textScaleFactor,
                                        min: 0.8,
                                        max: 1.5,
                                        divisions: 14,
                                        label: '${(theme.textScaleFactor * 100).toInt()}%',
                                        onChanged: (value) => theme.setTextScaleFactor(value),
                                        activeColor: Color(0xFF2D60FF),
                                      ),
                                    ),
                                    Text('A', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  _buildSectionHeader("Advanced Features"),
                  _buildSettingsGroup([
                    _buildTile(
                      Icons.account_tree_outlined,
                      "Knowledge Graph",
                      subtitle: "Visualize citation network",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => KnowledgeGraphScreen()),
                      ),
                    ),
                    _buildTile(
                      Icons.fact_check_outlined,
                      "Fact Check",
                      subtitle: "Validate DOIs and references",
                      onTap: () {
                        // Show dialog to select document for fact check
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please select a document from Files screen to fact check'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ]),

                  SizedBox(height: 20),

                  _buildSectionHeader("Data Management"),
                  _buildSettingsGroup([
                    _buildTile(
                      Icons.download_outlined, 
                      "Export Library", 
                      subtitle: "Export as BibTeX or CSV",
                      onTap: _showExportDialog,
                    ),
                  ]),

                  SizedBox(height: 20),

                  _buildSectionHeader("Developer"),
                  _buildSettingsGroup([
                    _buildTile(
                      Icons.vpn_key_outlined, 
                      "API Token", 
                      subtitle: "Copy token for plugins",
                      onTap: _showApiToken,
                    ),
                  ]),

                  _buildSectionHeader("Support"),
                  _buildSettingsGroup([
                    _buildTile(Icons.help_outline, "Help Center", onTap: () {}),
                    _buildTile(Icons.headset_mic_outlined, "Contact Us", onTap: () {}),
                  ]),

                  SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () async {
                        bool confirm = await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text("Log Out"),
                            content: Text("Are you sure you want to log out?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel")),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("Log Out", style: TextStyle(color: Colors.red))),
                            ],
                          )
                        ) ?? false;

                        if (confirm) {
                          await _authService.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => AuthScreen()),
                              (route) => false,
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50], 
                        foregroundColor: Colors.red,       
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0, left: 4),
        child: Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.download, color: Color(0xFF2D60FF)),
            SizedBox(width: 12),
            Text('Export Library'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose export format:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16),
            
            // BibTeX Option
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _exportLibrary('bib');
              },
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.code, color: Colors.orange),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BibTeX (.bib)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'For LaTeX and bibliography managers',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 12),
            
            // CSV Option
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _exportLibrary('csv');
              },
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.green),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CSV (.csv)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'For Excel and spreadsheet apps',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLibrary(String format) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Exporting library...'),
            ],
          ),
        ),
      ),
    );

    try {
      final token = await user?.getIdToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await _dio.get(
        '/api/citation/export',
        queryParameters: {'format': format},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.bytes,
        ),
      );

      // Save file to temporary directory
      final fileName = format == 'bib' 
          ? 'refmind-library.bib' 
          : 'refmind-library.csv';
      
      final directory = await getTemporaryDirectory();
      final filePath = path.join(directory.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(response.data);

      // Close loading dialog
      // ignore: use_build_context_synchronously
      Navigator.pop(context);

      // Share file using share dialog
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'RefMind Library Export',
        text: 'Exported library in ${format.toUpperCase()} format',
      );

      // Show success message after sharing
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('File exported successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      // ignore: use_build_context_synchronously
      Navigator.pop(context); // Close loading
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show API Token dialog
  Future<void> _showApiToken() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Get Firebase ID token
      String? token = await user.getIdToken();
      
      if (token == null) {
        throw Exception('Failed to get token');
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.vpn_key_outlined, color: Color(0xFF2D60FF)),
              SizedBox(width: 8),
              Text('API Token'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use this token to authenticate with Google Docs Add-on and other plugins:',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SelectableText(
                  token,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                '⚠️ Keep this token private. Do not share publicly.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: token));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Token copied to clipboard!'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: Icon(Icons.copy),
              label: Text('Copy Token'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2D60FF),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get token: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50], 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildTile(IconData icon, String title, {String? trailingText, String? subtitle, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white, 
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[200]!)
        ),
        child: Icon(icon, color: Color(0xFF2D60FF), size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey)) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) 
            Text(trailingText, style: TextStyle(color: Colors.grey, fontSize: 13)),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
        ],
      ),
    );
  }
}