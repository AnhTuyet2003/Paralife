// ignore: dangling_library_doc_comments
/// SHARE INTENT HANDLER
/// 
/// Service để xử lý URLs được share từ trình duyệt mobile (Safari, Chrome)
/// vào Refmind app.
/// 
/// Sử dụng receive_sharing_intent package để listen incoming shares.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../screens/share_save_sheet.dart';

class ShareIntentHandler {
  static StreamSubscription? _intentDataStreamSubscription;
  
  /// Initialize share intent listener (call once in main.dart)
  static void initialize() {
    debugPrint('🔗 ShareIntentHandler initialized');
  }
  
  /// Start listening for shared text/URLs (call in MyApp initState)
  static void startListening(BuildContext context) {
    debugPrint('🔗 Starting share intent listener...');
    
    // Listen when app is OPEN (hot start)
    // receive_sharing_intent 1.8.x: Use getMediaStream for both files AND text
    // When sharing text/URL, path contains the text content
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        debugPrint('📲 Received shared media: ${value.length} items');
        if (value.isNotEmpty) {
          // For text sharing, path contains the shared text/URL
          final sharedContent = value.first.path;
          debugPrint('📲 Shared content: $sharedContent');
          
          if (sharedContent.isNotEmpty) {
            // ignore: use_build_context_synchronously
            _handleSharedUrl(context, sharedContent);
          }
        }
      },
      onError: (err) {
        debugPrint('❌ Error receiving share intent: $err');
      },
    );
    
    debugPrint('✅ Stream listener setup complete (lightweight mode)');
  }
  
  /// Stop listening (call in dispose)
  static void stopListening() {
    _intentDataStreamSubscription?.cancel();
    _intentDataStreamSubscription = null;
    debugPrint('🔗 ShareIntentHandler stopped');
  }
  
  /// Reset shared data (clear after processing)
  static void reset() {
    ReceiveSharingIntent.instance.reset();
  }
  
  /// Handle shared URL by showing save dialog
  static void _handleSharedUrl(BuildContext context, String sharedText) {
    debugPrint('🔍 Handling shared URL: $sharedText');
    
    // Validate URL
    final url = _extractUrl(sharedText);
    if (url.isEmpty) {
      debugPrint('⚠️ Not a valid URL, ignoring');
      reset();
      return;
    }
    
    debugPrint('✅ Valid URL: $url');
    
    // ✅ Delay để đảm bảo context ready trước khi show dialog
    Future.delayed(Duration(milliseconds: 300), () {
      if (context.mounted) {
        showSaveDialog(context, url);
        reset();
      } else {
        debugPrint('⚠️ Context not mounted, skipping dialog');
        reset();
      }
    });
  }
  
  /// Extract URL from shared text (may contain extra text)
  static String _extractUrl(String text) {
    // URLs usually start with http:// or https://
    final urlPattern = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    );
    
    final match = urlPattern.firstMatch(text);
    if (match != null) {
      return match.group(0)!.trim();
    }
    
    // If no http/https, check if it looks like a URL
    if (text.contains('.') && !text.contains(' ')) {
      return 'https://$text'; // Add https:// prefix
    }
    
    return '';
  }
  
  /// Show bottom sheet for tags/notes input
  static void showSaveDialog(BuildContext context, String url) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareSaveSheet(url: url),
    );
  }
}
