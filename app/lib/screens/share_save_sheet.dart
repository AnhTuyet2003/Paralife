// ignore: dangling_library_doc_comments
/// SHARE SAVE SHEET
/// 
/// Bottom sheet UI để nhập tags và notes khi save URL từ Share Intent

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';

class ShareSaveSheet extends StatefulWidget {
  final String url;
  
  const ShareSaveSheet({
    super.key,
    required this.url,
  });
  
  @override
  State<ShareSaveSheet> createState() => _ShareSaveSheetState();
}

class _ShareSaveSheetState extends State<ShareSaveSheet> {
  final _tagsController = TextEditingController();
  final _notesController = TextEditingController();
  final _dio = Dio();
  
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  void dispose() {
    _tagsController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Get keyboard height for padding
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Title
              const Text(
                'Save to Refmind',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // URL (truncated)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.url,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Tags input
              TextField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: 'Tags (optional)',
                  hintText: 'machine learning, nlp, transformers',
                  prefixIcon: const Icon(Icons.label_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: 'Separate tags with commas',
                ),
                textInputAction: TextInputAction.next,
              ),
              
              const SizedBox(height: 16),
              
              // Notes input
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add your thoughts or summary...',
                  prefixIcon: const Icon(Icons.note_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 4,
                textInputAction: TextInputAction.done,
              ),
              
              const SizedBox(height: 20),
              
              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Save button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D60FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_outlined),
                          SizedBox(width: 8),
                          Text(
                            'Save to Refmind',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
              
              const SizedBox(height: 8),
              
              // Cancel button
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _handleSave() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get Firebase token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Not logged in. Please login first.');
      }
      
      final token = await user.getIdToken();
      if (token == null) {
        throw Exception('Failed to get authentication token');
      }
      
      // Parse tags
      final tagsString = _tagsController.text.trim();
      final tags = tagsString.isEmpty
          ? <String>[]
          : tagsString.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      
      // Prepare payload
      final payload = {
        'url': widget.url,
        'title': widget.url, // Backend will extract title from metadata
        'tags': tags,
        'notes': _notesController.text.trim(),
        'page_type': 'webpage', // Default, backend may upgrade to 'article'
      };
      
      // Backend URL (change to production URL when deploying)
      const backendUrl = 'http://10.0.2.2:3000'; // Android emulator
      // const backendUrl = 'https://your-production-url.com'; // Production
      
      debugPrint('📤 Sending to backend: $payload');
      
      // Call API
      final response = await _dio.post(
        '$backendUrl/api/extension/save',
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => true, // Don't throw on error status
        ),
      );
      
      if (response.statusCode != 200) {
        final error = response.data['error'] ?? 'Unknown error';
        throw Exception(error);
      }
      
      final data = response.data;
      debugPrint('✅ Save successful: $data');
      
      // Close bottom sheet
      if (mounted) {
        Navigator.pop(context);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data['has_pdf'] == true
                        ? '✅ Saved with PDF!'
                        : '✅ Saved to Refmind!',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
    } catch (error) {
      debugPrint('❌ Save error: $error');
      
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
