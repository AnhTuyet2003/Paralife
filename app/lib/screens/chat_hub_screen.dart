import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_model.dart';
import 'package:app/screens/compare_matrix_screen.dart';

class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key});

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://10.0.2.2:3000', 
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 60),
  ));
  
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedMode = 'library';
  String? _selectedFileId;
  List<dynamic> _userFiles = [];

  String? _sessionId;
  List<ChatMessage> _messages = [];
  bool _isSessionLoading = false;
  bool _isSending = false;
  bool _isSummarizing = false; 

  bool _hasUsableMetadata(dynamic file) {
    if (file is! Map) return false;
    final metadata = file['metadata'];
    if (metadata is! Map) return false;

    String normalize(dynamic value) {
      if (value == null) return '';
      if (value is List) {
        return value
            .map((v) => v == null ? '' : v.toString().trim())
            .where((v) => v.isNotEmpty)
            .join(', ')
            .trim();
      }
      return value.toString().trim();
    }

    const candidateKeys = [
      'title',
      'authors',
      'year',
      'journal',
      'doi',
      'abstract',
      'keywords',
      'publisher'
    ];

    for (final key in candidateKeys) {
      final value = normalize(metadata[key]);
      if (value.isNotEmpty) return true;
    }
    return false;
  }

  List<dynamic> get _documentChatFiles {
    return _userFiles.where(_hasUsableMetadata).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchUserFiles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChatSession();
    });
  }

  // 1. Tải danh sách file từ Server
  Future<void> _fetchUserFiles() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();
      
      final res = await _dio.get('/api/storage/items',
        queryParameters: {'type': 'file'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        setState(() {
          // ✅ XỬ LÝ CẢ 2 FORMAT
          List<dynamic> rawData;
          
          if (res.data is List) {
            rawData = res.data as List;
          } else if (res.data is Map && res.data['data'] != null) {
            rawData = res.data['data'] as List;
          } else {
            rawData = [];
          }

          _userFiles = rawData.where((f) => f['type'] == 'file').toList();

          final documentFiles = _documentChatFiles;
          final selectedStillValid = documentFiles.any((f) => f['id'] == _selectedFileId);
          if (!selectedStillValid) {
            _selectedFileId = documentFiles.isNotEmpty ? documentFiles[0]['id'] : null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải danh sách tài liệu'))
        );
      }
      debugPrint("❌ Lỗi tải file: $e");
    }
  }

  // 2. Tạo phiên Chat mới
  Future<void> _initChatSession() async {
    if (_selectedMode == 'document' && _selectedFileId == null) {
      setState(() {
        _isSessionLoading = false;
        _messages = [ChatMessage(id: 'info', role: 'ai', content: '👈 Vui lòng chọn tài liệu để bắt đầu.', createdAt: DateTime.now())];
      });
      return;
    }

    setState(() {
      _isSessionLoading = true;
      _sessionId = null;
      _messages.clear();
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      Map<String, dynamic> body = {'mode': _selectedMode};
      if (_selectedMode == 'document') body['file_id'] = _selectedFileId;

      final response = await _dio.post(
        '/api/chat/sessions',
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!mounted) return;

      setState(() {
        _sessionId = response.data['id'];
        _isSessionLoading = false;

        String welcome = "";
        if (_selectedMode == 'library') {
          welcome = "📚 **Chat Thư Viện**\nTôi đã sẵn sàng trả lời câu hỏi từ toàn bộ tài liệu của bạn.";
        } else if (_selectedMode == 'online') {
          welcome = "🌐 **Tra Cứu Online**\n\n💡 Cách dùng:\n- Nhập yêu cầu tìm kiếm (VD: *\"tìm bài báo về AI trong y tế\"*)\n- Tôi sẽ tìm tài liệu học thuật trên Crossref\n- Bạn chọn tài liệu muốn thêm vào thư viện\n- Hệ thống tự động download PDF và tạo embedding";
        } else {
           var file = _userFiles.firstWhere((f) => f['id'] == _selectedFileId, orElse: () => {'name': 'Tài liệu'});
           welcome = "📄 **${file['name']}**\nBạn có thể hỏi chi tiết hoặc bấm nút **Tóm tắt** ở góc phải.";
        }
        
        _messages.add(ChatMessage(id: 'welcome', role: 'ai', content: welcome, createdAt: DateTime.now()));
      });

    } catch (e) {
      if (!mounted) return;

      final isTimeout = e is DioException && (
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout
      );

      final message = isTimeout
        ? '⚠️ Kết nối đến server bị chậm. Vui lòng thử lại sau vài giây.'
        : '⚠️ Không thể kết nối server.\nLỗi: $e';

      setState(() {
        _isSessionLoading = false;
        _messages.add(ChatMessage(
          id: 'err',
          role: 'ai',
          content: message,
          createdAt: DateTime.now(),
        ));
      });
      debugPrint("❌ Lỗi tạo session: $e");
    }
  }

  // 3. Gửi tin nhắn
  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    
    String content = _controller.text;
    _controller.clear();

    // ✅ XỬ LÝ RIÊNG CHO MODE ONLINE
    if (_selectedMode == 'online') {
      await _handleOnlineSearch(content);
      return;
    }

    // === XỬ LÝ CHO MODE LIBRARY/DOCUMENT ===
    if (_sessionId == null) await _initChatSession(); // Retry init
    if (_sessionId == null) return;

    setState(() {
      _messages.add(ChatMessage(id: DateTime.now().toString(), role: 'user', content: content, createdAt: DateTime.now()));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      final response = await _dio.post(
        '/api/chat/messages',
        data: {'session_id': _sessionId, 'content': content},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!mounted) return;
      var aiMsg = ChatMessage.fromJson(response.data);

      setState(() {
        _messages.add(aiMsg);
        _isSending = false;
      });
      _scrollToBottom();

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages.add(ChatMessage(id: 'err', role: 'ai', content: "❌ Lỗi: $e", createdAt: DateTime.now()));
      });
    }
  }

  // 3.B. XỬ LÝ CHAT ONLINE SEARCH
  Future<void> _handleOnlineSearch(String query) async {
    setState(() {
      _messages.add(ChatMessage(id: DateTime.now().toString(), role: 'user', content: query, createdAt: DateTime.now()));
      _isSending = true;
      _messages.add(ChatMessage(id: 'searching', role: 'ai', content: '🔍 Đang tìm kiếm tài liệu học thuật...', createdAt: DateTime.now()));
    });
    _scrollToBottom();

    try {
      User? user = FirebaseAuth.instance.currentUser;

      // Gọi Python AI Engine để search
      final searchResponse = await Dio(BaseOptions(
        baseUrl: 'http://10.0.2.2:8000', // Python AI Engine
        connectTimeout: Duration(seconds: 30),
        receiveTimeout: Duration(seconds: 30),
      )).post(
        '/chat-online/search',
        data: {
          'message': query,
          'user_id': user?.uid,
          'max_results': 5
        },
      );

      if (!mounted) return;

      setState(() {
        _messages.removeWhere((m) => m.id == 'searching');
        _isSending = false;
      });

      final data = searchResponse.data;
      
      if (data['papers'] == null || (data['papers'] as List).isEmpty) {
        setState(() {
          _messages.add(ChatMessage(
            id: DateTime.now().toString(),
            role: 'ai',
            content: '😔 ${data["message"] ?? "Không tìm thấy tài liệu"}',
            createdAt: DateTime.now()
          ));
        });
        return;
      }

      // Hiển thị kết quả và cho user chọn
      final papers = data['papers'] as List;
      final searchQuery = data['search_query'] ?? query;
      
      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().toString(),
          role: 'ai',
          content: '📚 Tìm thấy **${papers.length} tài liệu** cho từ khóa: *"$searchQuery"*\n\nVui lòng chọn tài liệu muốn thêm vào thư viện:',
          createdAt: DateTime.now()
        ));
      });
      _scrollToBottom();

      // Hiển thị dialog chọn DOI
      _showPaperSelectionDialog(papers);

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == 'searching');
        _isSending = false;
        _messages.add(ChatMessage(
          id: 'err',
          role: 'ai',
          content: "❌ Lỗi tìm kiếm: $e",
          createdAt: DateTime.now()
        ));
      });
    }
  }

  // 3.C. DIALOG CHỌN TÀI LIỆU TỪ KẾT QUẢ SEARCH
  void _showPaperSelectionDialog(List<dynamic> papers) {
    List<String> selectedDOIs = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.library_add, color: Colors.blue),
                  SizedBox(width: 8),
                  Text("Chọn tài liệu", style: TextStyle(fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: papers.length,
                  itemBuilder: (ctx, i) {
                    final paper = papers[i];
                    final doi = paper['doi'] ?? '';
                    final isSelected = selectedDOIs.contains(doi);
                    
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 6),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setStateDialog(() {
                            if (val == true) {
                              selectedDOIs.add(doi);
                            } else {
                              selectedDOIs.remove(doi);
                            }
                          });
                        },
                        title: Text(
                          paper['title'] ?? 'Unknown Title',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text('👤 ${paper['authors'] ?? 'Unknown'}', style: TextStyle(fontSize: 12)),
                            Text('📅 ${paper['year']} • 📖 ${paper['journal'] ?? 'N/A'}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            Text('🔗 DOI: $doi', style: TextStyle(fontSize: 10, color: Colors.blue[800])),
                          ],
                        ),
                        isThreeLine: true,
                        dense: false,
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  child: Text("Hủy"),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  onPressed: selectedDOIs.isEmpty
                    ? null
                    : () {
                        Navigator.pop(context);
                        _processSelectedDOIs(selectedDOIs);
                      },
                  child: Text("Thêm (${selectedDOIs.length})"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 3.D. XỬ LÝ CÁC DOI ĐÃ CHỌN
  Future<void> _processSelectedDOIs(List<String> dois) async {
    setState(() {
      _isSending = true;
      _messages.add(ChatMessage(
        id: 'processing',
        role: 'ai',
        content: '⏳ Đang xử lý ${dois.length} tài liệu...\n(Download PDF, tạo embedding, lưu vào thư viện)',
        createdAt: DateTime.now()
      ));
    });
    _scrollToBottom();

    try {
      User? user = FirebaseAuth.instance.currentUser;
      
      // Gọi Python AI Engine để process
      final processResponse = await Dio(BaseOptions(
        baseUrl: 'http://10.0.2.2:8000',
        connectTimeout: Duration(seconds: 120),
        receiveTimeout: Duration(seconds: 300), // 5 phút cho nhiều DOI
      )).post(
        '/chat-online/process',
        data: {
          'user_id': user?.uid,
          'selected_dois': dois
        },
      );

      if (!mounted) return;

      setState(() {
        _messages.removeWhere((m) => m.id == 'processing');
        _isSending = false;
      });

      final data = processResponse.data;
      final results = data['results'] as List? ?? [];
      final successCount = data['success_count'] ?? 0;
      final failedCount = data['failed_count'] ?? 0;

      // Tạo báo cáo kết quả
      String report = '## 📊 KẾT QUẢ XỬ LÝ\n\n';
      report += '**Tổng số:** ${results.length} tài liệu\n';
      report += '✅ **Thành công:** $successCount\n';
      report += '❌ **Thất bại:** $failedCount\n\n';
      
      if (successCount > 0) {
        report += '### ✅ Đã thêm vào thư viện:\n';
        for (var r in results) {
          if (r['status'] == 'success') {
            String fileName = r['file_name'] ?? r['doi'];
            bool isAbstractOnly = r['is_abstract_only'] == true;
            
            if (isAbstractOnly) {
              report += '- 📝 $fileName *(Abstract only - Paywall)*\n';
            } else {
              report += '- 📄 $fileName\n';
            }
          }
        }
        report += '\n';
      }
      
      if (failedCount > 0) {
        report += '### ⚠️ Không thể thêm:\n';
        for (var r in results) {
          if (r['status'] != 'success') {
            report += '- ${r['doi']}: ${r['message']}\n';
          }
        }
      }

      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().toString(),
          role: 'ai',
          content: report,
          createdAt: DateTime.now()
        ));
      });
      _scrollToBottom();

      // Refresh danh sách file
      await _fetchUserFiles();

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == 'processing');
        _isSending = false;
        _messages.add(ChatMessage(
          id: 'err',
          role: 'ai',
          content: "❌ Lỗi xử lý: $e",
          createdAt: DateTime.now()
        ));
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSummaryOptions() {
    if (_selectedMode != 'document') return;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Chọn kiểu tóm tắt", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              
              _buildSummaryOption(Icons.bolt, Colors.orange, "Siêu ngắn (TL;DR)", "Nắm ý chính trong 30 giây", "tldr"),
              _buildSummaryOption(Icons.list_alt, Colors.blue, "Các điểm chính", "Danh sách gạch đầu dòng", "bullet"),
              _buildSummaryOption(Icons.article_outlined, Colors.green, "Chi tiết", "Phân tích sâu cấu trúc", "detailed"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryOption(IconData icon, Color color, String title, String sub, String type) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(sub),
      onTap: () {
        Navigator.pop(context);
        _performSummary(type);
      },
    );
  }

  // 5. THỰC HIỆN TÓM TẮT
  Future<void> _performSummary(String type) async {
    if (_isSummarizing || _selectedFileId == null) return;
    
    setState(() => _isSummarizing = true);
    _messages.add(ChatMessage(id: 'loading_sum', role: 'ai', content: '🔄 Đang tóm tắt tài liệu...', createdAt: DateTime.now()));
    _scrollToBottom();

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();
      
      // ✅ GỌI QUA NODE.JS GATEWAY (KHÔNG GỌI TRỰC TIẾP PYTHON)
      final response = await _dio.post(
        '/api/chat/summary',
        data: {
          'file_id': _selectedFileId,
          'type': type
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          receiveTimeout: Duration(seconds: 90),
        ),
      );

      if (!mounted) return;
      
      setState(() {
        _messages.removeWhere((m) => m.id == 'loading_sum');
        _isSummarizing = false;
        
        String title = type == "tldr" ? "⚡ TÓM TẮT NHANH" : (type == "bullet" ? "📌 ĐIỂM CHÍNH" : "📝 TÓM TẮT CHI TIẾT");
        _messages.add(ChatMessage(
          id: DateTime.now().toString(),
          role: 'ai',
          content: "## $title\n\n${response.data['summary']}",
          createdAt: DateTime.now()
        ));
      });
      _scrollToBottom();

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == 'loading_sum');
        _isSummarizing = false;
        _messages.add(ChatMessage(id: 'err', role: 'ai', content: "❌ Lỗi tóm tắt: $e", createdAt: DateTime.now()));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedMode,
            icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue),
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
            items: [
               DropdownMenuItem(value: 'library', child: Row(children: [Icon(Icons.library_books, color: Colors.indigo, size: 20), SizedBox(width: 8), Text("Toàn bộ thư viện")])),
               DropdownMenuItem(value: 'document', child: Row(children: [Icon(Icons.description, color: Colors.orange, size: 20), SizedBox(width: 8), Text("Một tài liệu")])),
               DropdownMenuItem(value: 'online', child: Row(children: [Icon(Icons.public, color: Colors.green, size: 20), SizedBox(width: 8), Text("Tra cứu Online")])),
            ],
            onChanged: (val) {
              if (val != null && val != _selectedMode) {
                setState(() {
                  _selectedMode = val;
                  if (_selectedMode == 'document') {
                    final documentFiles = _documentChatFiles;
                    final selectedStillValid = documentFiles.any((f) => f['id'] == _selectedFileId);
                    if (!selectedStillValid) {
                      _selectedFileId = documentFiles.isNotEmpty ? documentFiles[0]['id'] : null;
                    }
                  }
                });
                _initChatSession();
              }
            },
          ),
        ),
        actions: [
          if (_selectedMode != 'document')
            IconButton(
              icon: Icon(Icons.compare_arrows, color: Colors.indigo),
              tooltip: "So sánh tài liệu (Matrix)",
              onPressed: _showCompareDialog,
            ),

          // Nút Tóm tắt (Chỉ hiện khi chọn 1 tài liệu)
          if (_selectedMode == 'document')
            IconButton(
              icon: _isSummarizing 
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : Icon(Icons.summarize_outlined, color: Colors.blue),
              tooltip: "Tóm tắt tài liệu",
              onPressed: _isSummarizing ? null : _showSummaryOptions,
            )
        ],
        bottom: _selectedMode == 'document' 
          ? PreferredSize(
              preferredSize: Size.fromHeight(50),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16),
                color: Colors.grey[50],
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _documentChatFiles.any((f) => f['id'] == _selectedFileId) ? _selectedFileId : null,
                    hint: Text(_documentChatFiles.isEmpty ? "📂 Không có tài liệu đủ metadata" : "📂 Chọn tài liệu..."),
                    items: _documentChatFiles.map((f) => DropdownMenuItem<String>(
                      value: f['id'], 
                      child: Text(f['name'], overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14))
                    )).toList(),
                    onChanged: _documentChatFiles.isEmpty ? null : (val) {
                      setState(() => _selectedFileId = val);
                      _initChatSession();
                    },
                  ),
                ),
              ),
            ) 
          : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isSessionLoading 
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i]),
                ),
          ),
          if (_isSending) LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent),
          
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(hintText: "Nhập câu hỏi...", border: InputBorder.none),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(icon: Icon(Icons.send, color: Color(0xFF2D60FF)), onPressed: _sendMessage),
              ],
            ),
          )
        ],
      ),
    );
  }

  // WIDGET TIN NHẮN (CÓ HIỂN THỊ REF/CITATION)
  Widget _buildMessageBubble(ChatMessage msg) {
    bool isUser = msg.role == 'user';
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser ? Color(0xFF2D60FF) : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: isUser ? Radius.circular(12) : Radius.circular(0),
            bottomRight: isUser ? Radius.circular(0) : Radius.circular(12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. NỘI DUNG CHÍNH
            isUser 
              ? Text(msg.content, style: TextStyle(color: Colors.white))
              : SelectionArea(
                  // Menu bôi đen để giải thích thuật ngữ
                  contextMenuBuilder: (context, editableTextState) {
                    // ignore: deprecated_member_use
                    final selectedText = editableTextState.textEditingValue.selection.textInside(editableTextState.textEditingValue.text);
                    return AdaptiveTextSelectionToolbar.buttonItems(
                      anchors: editableTextState.contextMenuAnchors,
                      buttonItems: [
                        ...editableTextState.contextMenuButtonItems,
                        ContextMenuButtonItem(
                          onPressed: () {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              editableTextState.hideToolbar();
                            });
                            // Gọi hàm giải thích (Đảm bảo bạn đã copy hàm _callExplainAPI vào class này)
                            _callExplainAPI(selectedText, msg.content); 
                          },
                          label: '🔍 Giải thích',
                        ),
                      ],
                    );
                  },
                  child: MarkdownBody(
                    data: msg.content,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: Colors.black87, fontSize: 15, height: 1.4),
                    ),
                  ),
                ),
            // 2. PHẦN TRÍCH DẪN (REFERENCE) - HIỆN TÊN FILE & TRANG
            if (!isUser && msg.citations != null && msg.citations!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Nguồn tham khảo:", style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: msg.citations!.map((c) {
                        var meta = c['metadata'] ?? {};
                        String page = meta['page_number']?.toString() ?? '?';
                        String fileName = c['file_name'] ?? ''; // Đọc từ cấp cao, không phải trong metadata
                        
                        String label = "Pg $page";
                        
                        // Logic hiển thị: Nếu chat thư viện thì hiện tên file
                        if (fileName.isNotEmpty && _selectedMode == 'library') {
                          if (fileName.length > 15) fileName = "${fileName.substring(0, 12)}...";
                          label = "$fileName • $page";
                        }

                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)]
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.description, size: 10, color: Colors.blue[800]),
                              SizedBox(width: 4),
                              Text(
                                label, 
                                style: TextStyle(fontSize: 11, color: Colors.blue[900], fontWeight: FontWeight.w500)
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }

  Future<void> _callExplainAPI(String term, String fullContext) async {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator())
    );

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      final res = await _dio.post('/api/chat/explain', 
        data: {'term': term, 'context': fullContext},
        options: Options(headers: {'Authorization': 'Bearer $token'})
      );

      if (!mounted) return;
      Navigator.pop(context); 

      // Hiện kết quả (Bottom Sheet)
      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("📖 $term", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[800])),
              SizedBox(height: 12),
              Text(res.data['explanation'], style: TextStyle(fontSize: 16, height: 1.5)),
              SizedBox(height: 20),
            ],
          ),
        )
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi giải thích: $e")));
    }
  }

  void _showCompareDialog() {
    // 1. Lọc ra danh sách các file ID đang chọn
    List<String> selectedForCompare = [];
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Chọn tài liệu để so sánh"),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: _userFiles.isEmpty 
                  ? Center(child: Text("Chưa có tài liệu nào."))
                  : ListView.builder(
                      itemCount: _userFiles.length,
                      itemBuilder: (ctx, i) {
                        final file = _userFiles[i];
                        final isSelected = selectedForCompare.contains(file['id']);
                        return CheckboxListTile(
                          title: Text(file['name']),
                          value: isSelected,
                          onChanged: (val) {
                            setStateDialog(() {
                              if (val == true) {
                                if (selectedForCompare.length >= 5) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tối đa 5 tài liệu thôi nhé!")));
                                } else {
                                  selectedForCompare.add(file['id']);
                                }
                              } else {
                                selectedForCompare.remove(file['id']);
                              }
                            });
                          },
                        );
                      },
                    ),
              ),
              actions: [
                TextButton(child: Text("Hủy"), onPressed: () => Navigator.pop(context)),
                ElevatedButton(
                  onPressed: selectedForCompare.length < 2 
                    ? null 
                    : () {
                        Navigator.pop(context); 
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => CompareMatrixScreen(fileIds: selectedForCompare)
                        ));
                      },
                  child: Text("So sánh (${selectedForCompare.length})"),
                )
              ],
            );
          }
        );
      },
    );
  }
}