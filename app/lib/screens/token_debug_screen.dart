// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 🔑 Debug Screen: Show Firebase Token for Postman Testing
/// 
/// Màn hình này giúp developers lấy Firebase JWT token để test APIs với Postman.
/// 
/// Cách dùng:
/// 1. Login vào app
/// 2. Vào màn hình này
/// 3. Copy token hiển thị
/// 4. Paste vào Postman header: Authorization: Bearer {token}
class TokenDebugScreen extends StatefulWidget {
  const TokenDebugScreen({super.key});

  @override
  State<TokenDebugScreen> createState() => _TokenDebugScreenState();
}

class _TokenDebugScreenState extends State<TokenDebugScreen> {
  String? _token;
  String? _userId;
  String? _email;
  bool _isLoading = false;
  DateTime? _tokenExpiry;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      String? token = await user.getIdToken();
      
      setState(() {
        _token = token;
        _userId = user.uid;
        _email = user.email;
        _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
        _isLoading = false;
      });

      // Print to console for quick access
      print('\n${'='*70}');
      print('🔑 FIREBASE TOKEN (Debug Screen)');
      print('='*70);
      print('User ID: $_userId');
      print('Email: $_email');
      print('Token:');
      print(token ?? 'No token');
      print('='*70 + '\n');

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting token: $e')),
        );
      }
    }
  }

  Future<void> _copyToken() async {
    if (_token != null) {
      await Clipboard.setData(ClipboardData(text: _token!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Token copied to clipboard!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _copyAuthHeader() async {
    if (_token != null) {
      await Clipboard.setData(ClipboardData(text: 'Bearer $_token'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Authorization header copied!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatExpiry() {
    if (_tokenExpiry == null) return 'Unknown';
    final now = DateTime.now();
    final diff = _tokenExpiry!.difference(now);
    final minutes = diff.inMinutes;
    return '$minutes minutes remaining';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔑 Token Debug'),
        backgroundColor: const Color(0xFF2D60FF),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadToken,
            tooltip: 'Refresh Token',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _token == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text(
                        'No user logged in',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Please login first'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadToken,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'User Info',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Divider(),
                              const SizedBox(height: 8),
                              _buildInfoRow('User ID:', _userId ?? 'N/A'),
                              const SizedBox(height: 8),
                              _buildInfoRow('Email:', _email ?? 'N/A'),
                              const SizedBox(height: 8),
                              _buildInfoRow('Token Expiry:', _formatExpiry()),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Token Display Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Firebase Token',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _copyToken,
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('Copy'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2D60FF),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: SelectableText(
                                  _token ?? '',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Postman Instructions Card
                      Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Color(0xFF2D60FF)),
                                  SizedBox(width: 8),
                                  Text(
                                    'How to use in Postman',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D60FF),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              const SizedBox(height: 8),
                              _buildInstructionStep('1', 'Copy token above'),
                              const SizedBox(height: 8),
                              _buildInstructionStep('2', 'Open Postman'),
                              const SizedBox(height: 8),
                              _buildInstructionStep('3', 'Add Header:'),
                              const SizedBox(height: 4),
                              Container(
                                margin: const EdgeInsets.only(left: 32),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Key: Authorization',
                                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Value: Bearer {token}',
                                            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 16),
                                          onPressed: _copyAuthHeader,
                                          tooltip: 'Copy full header value',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildInstructionStep('4', 'Test your API request!'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Test URLs Card
                      Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '🧪 Test URLs',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Divider(),
                              const SizedBox(height: 8),
                              _buildTestUrl('GET', 'http://localhost:3000/api/storage/items'),
                              const SizedBox(height: 8),
                              _buildTestUrl('POST', 'http://localhost:3000/api/import/manual'),
                              const SizedBox(height: 8),
                              _buildTestUrl('POST', 'http://localhost:3000/api/import/file'),
                              const SizedBox(height: 8),
                              _buildTestUrl('POST', 'http://localhost:3000/api/import/identifier'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Warning
                      Card(
                        color: Colors.orange[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber, color: Colors.orange),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Security Warning',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Token expires in 1 hour. Never share your token publicly! Use only for testing on localhost.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: SelectableText(value),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF2D60FF),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text),
          ),
        ),
      ],
    );
  }

  Widget _buildTestUrl(String method, String url) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: method == 'GET' ? Colors.blue : Colors.green,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              method,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              url,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
