import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_model.dart';

class ChatScreen extends StatefulWidget {
  final String fileId;
  final String fileName;

  const ChatScreen({super.key, required this.fileId, required this.fileName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:3000')); 
  
  String? _sessionId;
  final List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isSummarizing = false;

  @override
  void initState() {
    super.initState();
    _initChatSession();
  }

  Future<void> _initChatSession() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await _dio.post(
        '/api/chat/sessions',
        data: {'file_id': widget.fileId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      setState(() {
        _sessionId = response.data['id'];
        _isLoading = false;
        _messages.add(ChatMessage(
          id: 'welcome',
          role: 'ai',
          content: 'Hello! I have read **${widget.fileName}**. Ask me anything about it.',
          createdAt: DateTime.now()
        ));
      });
    } catch (e) {
      setState(() => _isLoading = false);
      
      // SỬA: Better error handling
      String errorMsg = 'Failed to initialize chat';
      if (e is DioException) {
        errorMsg = e.response?.data?['error'] ?? e.message ?? errorMsg;
      }
      
      debugPrint("❌ Init Chat Error: $errorMsg");
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _sessionId == null) return;

    final String content = _controller.text;
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().toString(),
        role: 'user',
        content: content,
        createdAt: DateTime.now()
      ));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      final response = await _dio.post(
        '/api/chat/messages',
        data: {
          'session_id': _sessionId,
          'content': content
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final aiMsg = ChatMessage.fromJson(response.data);

      setState(() {
        _messages.add(aiMsg);
        _isSending = false;
      });
      _scrollToBottom();

    } catch (e) {
      // SỬA: Better error message
      String errorMsg = 'Sorry, I encountered an error';
      if (e is DioException) {
        errorMsg = e.response?.data?['error'] ?? e.message ?? errorMsg;
      }
      
      setState(() {
        _isSending = false;
        _messages.add(ChatMessage(
          id: 'error', 
          role: 'ai', 
          content: '⚠️ $errorMsg', 
          createdAt: DateTime.now()
        ));
      });
      
      debugPrint("❌ Send Message Error: $errorMsg");
    }
  }

  // 1. Hàm hiển thị Menu lựa chọn (Bottom Sheet)
  void _showSummaryOptions() {
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
              
              _buildSummaryOption(
                icon: Icons.bolt, 
                color: Colors.orange,
                title: "Siêu ngắn (TL;DR)", 
                subtitle: "Nắm ý chính trong 30 giây",
                onTap: () => _performSummary("tldr")
              ),
              
              _buildSummaryOption(
                icon: Icons.list_alt, 
                color: Colors.blue,
                title: "Các điểm chính (Key Points)", 
                subtitle: "Danh sách gạch đầu dòng súc tích",
                onTap: () => _performSummary("bullet")
              ),
              
              _buildSummaryOption(
                icon: Icons.article_outlined, 
                color: Colors.green,
                title: "Chi tiết (Detailed)", 
                subtitle: "Phân tích sâu cấu trúc tài liệu",
                onTap: () => _performSummary("detailed")
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryOption({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      onTap: () {
        Navigator.pop(context); 
        onTap(); 
      },
    );
  }

  Future<void> _performSummary(String type) async {
    if (_isSummarizing) return;
    setState(() => _isSummarizing = true);

    String loadingText = "Đang tóm tắt...";
    if (type == "tldr") loadingText = "Đang rút gọn nội dung (TL;DR)...";
    if (type == "detailed") loadingText = "Đang đọc sâu và phân tích chi tiết...";

    _messages.add(ChatMessage(
      id: 'summary_loading', role: 'ai', 
      content: '🔄 **$loadingText**', 
      createdAt: DateTime.now()
    ));
    _scrollToBottom();

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      final response = await _dio.post(
        '/api/chat/summary',
        data: {
          'file_id': widget.fileId,
          'type': type // 👈 Gửi loại tóm tắt lên server
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == 'summary_loading');
        
        // Tiêu đề tương ứng
        String title = "📝 TÓM TẮT CHI TIẾT";
        if (type == "tldr") title = "⚡ TÓM TẮT NHANH (TL;DR)";
        if (type == "bullet") title = "📌 CÁC ĐIỂM CHÍNH";

        _messages.add(ChatMessage(
          id: DateTime.now().toString(),
          role: 'ai',
          content: "## $title\n\n${response.data['summary']}",
          createdAt: DateTime.now()
        ));
        _isSummarizing = false;
      });
      _scrollToBottom();

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == 'summary_loading');
        _isSummarizing = false;
        _messages.add(ChatMessage(id: 'error', role: 'ai', content: '❌ Lỗi: $e', createdAt: DateTime.now()));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Chat Document", style: TextStyle(fontSize: 16)),
            Text(widget.fileName, style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
        IconButton(
          icon: _isSummarizing 
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
            : Icon(Icons.summarize_outlined, color: Colors.blue),
          onPressed: _isSummarizing ? null : _showSummaryOptions,
          tooltip: "Tóm tắt tài liệu",
        ),
      ],
      ),
      body: Column(
        children: [
          // DANH SÁCH TIN NHẮN
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg.role == 'user';
                    return _buildMessageBubble(msg, isUser);
                  },
                ),
          ),
          
          // THANH LOADING KHI AI ĐANG NGHĨ
          if (_isSending)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Row(children: [
                SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text("AI is thinking...", style: TextStyle(color: Colors.grey, fontSize: 12))
              ]),
            ),

          // Ô NHẬP LIỆU
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, -2))]
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Ask about this document...",
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Color(0xFF2D60FF)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isUser ? Color(0xFF2D60FF) : Colors.grey[200],
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
            // Nội dung tin nhắn
            isUser 
              ? Text(msg.content, style: TextStyle(color: Colors.white))
              : MarkdownBody(data: msg.content), 
            
            // Hiển thị Trích dẫn (Citations) 
            if (!isUser && msg.citations != null && msg.citations!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Wrap(
                  spacing: 4,
                  children: msg.citations!.map((c) {
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(4)
                      ),
                      child: Text(
                        "Pg ${c['metadata']?['page_number'] ?? 'Ref'}", // Hiển thị số trang
                        style: TextStyle(fontSize: 10, color: Colors.blue[900]),
                      ),
                    );
                  }).toList(),
                ),
              )
          ],
        ),
      ),
    );
  }
}