// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class PdfReaderScreen extends StatefulWidget {
  final String fileId;
  final String fileName;
  final String pdfUrl;
  final Map<String, dynamic>? metadata;

  const PdfReaderScreen({
    super.key,
    required this.fileId,
    required this.fileName,
    required this.pdfUrl,
    this.metadata,
  });

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:3000'));
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  List<Map<String, dynamic>> _highlights = [];
  int? _currentPage;

  // ✅ Get full PDF URL (handle relative URLs from backend)
  String get _fullPdfUrl {
    final url = widget.pdfUrl;
    debugPrint('📄 Original PDF URL: $url');
    
    if (url.startsWith('http://') || url.startsWith('https://')) {
      debugPrint('✅ Using absolute URL: $url');
      return url;
    }
    
    // For local storage URLs like /uploads/..., prepend backend URL
    final fullUrl = 'http://10.0.2.2:3000${url.startsWith('/') ? url : '/$url'}';
    debugPrint('✅ Constructed full URL: $fullUrl');
    return fullUrl;
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 PdfReaderScreen initialized with URL: ${widget.pdfUrl}');
    _loadHighlights();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  // ✅ LOAD HIGHLIGHTS FROM BACKEND
  Future<void> _loadHighlights() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await user.getIdToken();
      final response = await _dio.get(
        '/api/items/${widget.fileId}/highlights',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success']) {
        setState(() {
          _highlights = List<Map<String, dynamic>>.from(response.data['data']);
        });
      }
    } catch (e) {
      debugPrint('❌ Load highlights error: $e');
    }
  }

  // ✅ SHOW HIGHLIGHT & NOTE DIALOG
  void _showHighlightDialog(String selectedText, int pageNumber) {
    final TextEditingController noteController = TextEditingController();
    String selectedColor = 'yellow';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit_note, color: Colors.blue),
              SizedBox(width: 8),
              Text('Highlight & Note'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected text preview
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    selectedText,
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: 16),

                // Color picker
                Text('Highlight Color:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['yellow', 'green', 'blue', 'red', 'purple'].map((color) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getColor(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == color ? Colors.black : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: selectedColor == color
                            ? Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),

                // Note input
                Text('Add Note (Optional):', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Your thoughts, insights, or questions...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _saveHighlight(selectedText, noteController.text, selectedColor, pageNumber);
              },
              icon: Icon(Icons.save),
              label: Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2D60FF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ SAVE HIGHLIGHT TO BACKEND
  Future<void> _saveHighlight(String text, String note, String color, int pageNumber) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final token = await user.getIdToken();
      await _dio.post(
        '/api/items/${widget.fileId}/highlights',
        data: {
          'text': text,
          'note': note.isNotEmpty ? note : null,
          'color': color,
          'page_number': pageNumber,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      Navigator.pop(context); // Close loading
      await _loadHighlights(); // Refresh

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Highlight saved!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to save: $e')),
      );
    }
  }

  // ✅ SMART COPY WITH CITATION
  void _smartCopy(String selectedText) {
    final authors = widget.metadata?['authors'];
    final year = widget.metadata?['year'];

    String citation = '';
    if (authors != null && authors is List && authors.isNotEmpty) {
      citation = ' (${authors[0]}, $year)';
    } else if (widget.fileName.isNotEmpty) {
      citation = ' (${'widget.fileName'})';
    }

    final textWithCitation = '"$selectedText"$citation';

    Clipboard.setData(ClipboardData(text: textWithCitation));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 Copied with citation!'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // ✅ SHOW AI PARAPHRASE BOTTOM SHEET
  void _showParaphraseSheet(String selectedText) {
    String selectedStyle = 'academic';
    String? paraphrasedText;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.auto_fix_high, color: Colors.purple),
                  SizedBox(width: 8),
                  Text(
                    'AI Paraphrase',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(),
              SizedBox(height: 12),

              // Original text
              Text('Original:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(selectedText, style: TextStyle(fontSize: 13)),
              ),
              SizedBox(height: 16),

              // Style selector
              Text('Style:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('Academic'),
                    selected: selectedStyle == 'academic',
                    onSelected: (selected) {
                      if (selected) setSheetState(() => selectedStyle = 'academic');
                    },
                  ),
                  ChoiceChip(
                    label: Text('Simple'),
                    selected: selectedStyle == 'simple',
                    onSelected: (selected) {
                      if (selected) setSheetState(() => selectedStyle = 'simple');
                    },
                  ),
                  ChoiceChip(
                    label: Text('Summarize'),
                    selected: selectedStyle == 'summarize',
                    onSelected: (selected) {
                      if (selected) setSheetState(() => selectedStyle = 'summarize');
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Generate button
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        setSheetState(() {
                          isLoading = true;
                          paraphrasedText = null;
                        });

                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          final token = await user?.getIdToken();

                          final response = await _dio.post(
                            '/api/ai/paraphrase',
                            data: {'text': selectedText, 'style': selectedStyle},
                            options: Options(headers: {'Authorization': 'Bearer $token'}),
                          );

                          if (response.data['success']) {
                            setSheetState(() {
                              paraphrasedText = response.data['paraphrased_text'];
                            });
                          }
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ Error: $e')),
                          );
                        } finally {
                          setSheetState(() => isLoading = false);
                        }
                      },
                icon: Icon(Icons.auto_awesome),
                label: Text(isLoading ? 'Generating...' : 'Generate Paraphrase'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 48),
                ),
              ),
              SizedBox(height: 16),

              // Result
              if (isLoading)
                Center(child: CircularProgressIndicator())
              else if (paraphrasedText != null) ...[
                Text('Paraphrased:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                    ),
                    child: Markdown(
                      data: paraphrasedText!,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(fontSize: 14),
                      ),
                      shrinkWrap: true,
                      selectable: true,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: paraphrasedText!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('📋 Copied to clipboard!')),
                    );
                  },
                  icon: Icon(Icons.copy),
                  label: Text('Copy'),
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 40)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ✅ SHOW AI CRITIQUE DIALOG
  void _showCritiqueDialog(String selectedText) async {
    String? critique;
    bool isLoading = true;
    Function? updateDialog;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Save the setState callback
          updateDialog = setDialogState;
          
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.rate_review, color: Colors.orange),
                SizedBox(width: 8),
                Text('AI Critique'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Analyzing selected text...'),
                        ],
                      ),
                    )
                  : Markdown(
                      data: critique ?? 'No critique available',
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(fontSize: 14, height: 1.5),
                        h1: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        h2: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        h3: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        strong: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      shrinkWrap: true,
                      selectable: true,
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
              if (!isLoading && critique != null)
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: critique!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('📋 Copied!')),
                    );
                  },
                  icon: Icon(Icons.copy),
                  label: Text('Copy'),
                ),
            ],
          );
        },
      ),
    );

    // Fetch critique in background
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        critique = 'Error: User not authenticated';
        isLoading = false;
        updateDialog?.call(() {});
        return;
      }

      final token = await user.getIdToken();

      debugPrint('🔍 Sending critique request with text length: ${selectedText.length}');

      final response = await _dio.post(
        '/api/ai/critique',
        data: {'text': selectedText},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status! < 500,
        ),
      );

      debugPrint('📥 Critique response: ${response.statusCode}');

      if (response.data['success']) {
        critique = response.data['critique'];
        debugPrint('✅ Critique received: ${critique?.substring(0, 100)}...');
      } else {
        critique = 'Error: ${response.data['error'] ?? 'Unknown error'}';
        debugPrint('❌ Critique error: $critique');
      }
    } catch (e) {
      critique = 'Error: $e';
      debugPrint('❌ Critique exception: $e');
    } finally {
      isLoading = false;
      // Update the dialog with new state
      updateDialog?.call(() {});
    }
  }

  // ✅ SHOW NOTES SUMMARY DRAWER
  void _showNotesSummary() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sticky_note_2, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Notes Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  Text('${_highlights.length} notes', style: TextStyle(color: Colors.grey)),
                ],
              ),
              Divider(),
              SizedBox(height: 12),

              Expanded(
                child: _highlights.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.note_add_outlined, size: 64, color: Colors.grey[300]),
                            SizedBox(height: 16),
                            Text('No highlights yet', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _highlights.length,
                        itemBuilder: (context, index) {
                          final highlight = _highlights[index];
                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Container(
                                width: 8,
                                height: double.infinity,
                                color: _getColor(highlight['color']),
                              ),
                              title: Text(
                                highlight['text'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (highlight['note'] != null) ...[
                                    SizedBox(height: 4),
                                    Text(
                                      '💭 ${highlight['note']}',
                                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                  SizedBox(height: 4),
                                  Text(
                                    'Page ${highlight['page_number']}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteHighlight(highlight['id']),
                              ),
                              onTap: () {
                                // Jump to page
                                _pdfViewerController.jumpToPage(highlight['page_number']);
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ DELETE HIGHLIGHT
  Future<void> _deleteHighlight(String highlightId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      await _dio.delete(
        '/api/highlights/$highlightId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      await _loadHighlights();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🗑️ Highlight deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Delete failed: $e')),
      );
    }
  }

  Color _getColor(String colorName) {
    switch (colorName) {
      case 'yellow':
        return Colors.yellow.shade300;
      case 'green':
        return Colors.green.shade300;
      case 'blue':
        return Colors.blue.shade300;
      case 'red':
        return Colors.red.shade300;
      case 'purple':
        return Colors.purple.shade300;
      default:
        return Colors.yellow.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.fileName,
              style: TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            // Debug mode: Uncomment to see URL
            // if (true)
            //   Text(
            //     _fullPdfUrl,
            //     style: TextStyle(fontSize: 9, color: Colors.white70),
            //     maxLines: 1,
            //     overflow: TextOverflow.ellipsis,
            //   ),
          ],
        ),
        backgroundColor: Color(0xFF2D60FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.notes),
            tooltip: 'Notes Summary',
            onPressed: _showNotesSummary,
          ),
        ],
      ),
      body: SfPdfViewer.network(
        _fullPdfUrl,
        controller: _pdfViewerController,
        key: _pdfViewerKey,
        onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
          if (details.selectedText != null && details.selectedText!.isNotEmpty) {
            _showCustomContextMenu(details.selectedText!);
          }
        },
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          debugPrint('❌ PDF Load Failed:');
          debugPrint('   Error: ${details.error}');
          debugPrint('   Description: ${details.description}');
          debugPrint('   URL: $_fullPdfUrl');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red[700],
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'PDF Load Failed',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(details.error, style: TextStyle(fontSize: 13)),
                ],
              ),
              duration: Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Details',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('PDF Load Failed'),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Error: ${details.error}'),
                            SizedBox(height: 8),
                            Text('Description: ${details.description}'),
                            SizedBox(height: 8),
                            Text('URL: $_fullPdfUrl'),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ SHOW CUSTOM CONTEXT MENU FOR TEXT SELECTION
  void _showCustomContextMenu(String selectedText) {
    _currentPage ??= _pdfViewerController.pageNumber;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Selected Text Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.highlight, color: Colors.yellow.shade700),
              title: Text('Highlight & Note'),
              onTap: () {
                Navigator.pop(context);
                _showHighlightDialog(selectedText, _currentPage ?? 1);
              },
            ),
            ListTile(
              leading: Icon(Icons.copy, color: Colors.blue),
              title: Text('Smart Copy'),
              subtitle: Text('Copy with citation', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _smartCopy(selectedText);
              },
            ),
            ListTile(
              leading: Icon(Icons.auto_fix_high, color: Colors.purple),
              title: Text('AI Paraphrase'),
              subtitle: Text('Rewrite text', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _showParaphraseSheet(selectedText);
              },
            ),
            ListTile(
              leading: Icon(Icons.rate_review, color: Colors.orange),
              title: Text('AI Critique'),
              subtitle: Text('Academic analysis', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _showCritiqueDialog(selectedText);
              },
            ),
          ],
        ),
      ),
    );
  }
}
