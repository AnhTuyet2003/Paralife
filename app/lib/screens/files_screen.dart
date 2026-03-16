import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:app/screens/identifier_input_screen.dart';
import 'package:app/screens/manual_entry_screen.dart';
import 'package:app/screens/token_debug_screen.dart';
import 'package:app/services/document_import_service.dart';
import 'package:app/widgets/edit_metadata_dialog.dart';
import 'package:app/widgets/citation_dialog.dart';
import 'package:app/screens/pdf_reader_screen.dart';
import 'package:app/screens/fact_check_screen.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});
  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final List<Map<String, dynamic>> _folderStack = [
    {"id": null, "name": "Storage"}
  ];
  
  List<dynamic> _items = [];
  List<dynamic> _filteredItems = []; 
  bool _isLoading = false;
  bool _isGridView = false; 
  bool _isSearching = false; 
  final TextEditingController _searchController = TextEditingController();
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:3000'));

  bool _isMeaningfulMetadataValue(dynamic value) {
    if (value == null) return false;

    if (value is List) {
      return value.any(_isMeaningfulMetadataValue);
    }

    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) return false;

    const placeholders = {
      'unknown',
      'unknown author',
      'unknown title',
      'untitled document',
      'could not extract metadata',
      'n/a',
      'na',
      'null',
      'none',
      '-',
    };

    return !placeholders.contains(text);
  }

  bool _hasUsableMetadata(Map<String, dynamic> item) {
    final metadata = item['metadata_info'] ?? item['metadata'];
    if (metadata is! Map) return false;

    // DOI có giá trị là tín hiệu metadata đáng tin nhất.
    if (_isMeaningfulMetadataValue(metadata['doi'])) {
      return true;
    }

    // Nếu không có DOI, cần ít nhất 2 trường có ý nghĩa để coi là usable.
    final candidateValues = [
      metadata['title'],
      metadata['authors'],
      metadata['year'],
      metadata['journal'],
      metadata['abstract'],
      metadata['keywords'],
      metadata['publisher'],
    ];

    final meaningfulCount = candidateValues.where(_isMeaningfulMetadataValue).length;
    return meaningfulCount >= 2;
  }

  bool _isAbstractOnly(Map<String, dynamic> item) {
    if (_hasUsableMetadata(item)) return false;
    final metadata = item['metadata_info'] ?? item['metadata'];
    if (metadata is! Map) return false;
    return _isMeaningfulMetadataValue(metadata['abstract']);
  }

  Widget _buildMissingMetadataBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Text(
        'Missing metadata',
        style: TextStyle(
          color: Colors.red[800],
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAbstractOnlyBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Text(
        'Abstract only',
        style: TextStyle(
          color: Colors.orange[800],
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? get _currentParentId => _folderStack.last['id'];

  Future<void> _fetchItems() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      final response = await _dio.get(
        '/api/storage/items',
        queryParameters: _currentParentId != null ? {'parent_id': _currentParentId} : null,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        setState(() {
          // ✅ XỬ LÝ CẢ 2 FORMAT
          List<dynamic> rawData;
          
          if (response.data is List) {
            // Format mới: trả về mảng trực tiếp
            rawData = response.data as List;
          } else if (response.data is Map && response.data['data'] != null) {
            // Format cũ: trả về { success: true, data: [...] }
            rawData = response.data['data'] as List;
          } else {
            // Fallback: empty array
            rawData = [];
          }

          _items = rawData;
          _filteredItems = _items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải danh sách tài liệu')),
        );
      }
    }
  }

  void _filterItems() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _items;
      } else {
        _filteredItems = _items.where((item) {
          String name = (item['name'] ?? '').toLowerCase();
          var metadata = item['metadata_info'] ?? item['metadata'] ?? {};
          String title = (metadata['title'] ?? '').toLowerCase();
          String authors = (metadata['authors'] as List?)?.join(' ').toLowerCase() ?? '';
          
          return name.contains(query) || title.contains(query) || authors.contains(query);
        }).toList();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredItems = _items;
      }
    });
  }

  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
    });
  }

  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text("AI is reading & extracting metadata..."))
            ],
          ),
        ),
      );

      try {
        User? user = FirebaseAuth.instance.currentUser;
        String? token = await user?.getIdToken();
        
        String fileName = file.path.split('/').last;
        FormData formData = FormData.fromMap({
          "file": await MultipartFile.fromFile(file.path, filename: fileName),
          "parent_id": _currentParentId ?? "null",
        });

        await _dio.post(
          '/api/storage/upload',
          data: formData,
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );

        if (!mounted) return;
        
        Navigator.pop(context); 
        _fetchItems(); 
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload & Analysis Complete!"), backgroundColor: Colors.green),
        );

      } catch (e) {
        if (!mounted) return;
        
        Navigator.pop(context);
        
        // ✅ CHECK FOR DUPLICATE ERROR (409)
        if (e is DioException && e.response?.statusCode == 409) {
          final duplicate = e.response?.data['duplicate'];
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Duplicate Document'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This document already exists in your library:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          duplicate?['name'] ?? 'Unknown',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (duplicate?['doi'] != null)
                          Text('DOI: ${duplicate['doi']}', style: TextStyle(fontSize: 12)),
                        if (duplicate?['isbn'] != null)
                          Text('ISBN: ${duplicate['isbn']}', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Upload Failed: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _createFolder() async {
    TextEditingController nameController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("New Folder"),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(hintText: "Folder Name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2D60FF)),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(ctx);
                try {
                  User? user = FirebaseAuth.instance.currentUser;
                  String? token = await user?.getIdToken();

                  // Gọi API tạo folder (Ta sẽ dùng chung API upload hoặc tạo riêng, 
                  // nhưng ở đây ta dùng mẹo gọi API upload nhưng chỉ gửi metadata để tạo folder)
                  // HOẶC TỐT NHẤT: Ta nên thêm 1 API create_folder ở Python.
                  // Tạm thời để nhanh, mình sẽ giả định bạn đã upload 1 file, 
                  // nhưng để đúng logic, hãy thêm API tạo folder ở Backend nhé.
                  
                  // ==> GIẢI PHÁP TẠM THỜI: GỌI API PYTHON ĐỂ TẠO FOLDER
                  await _dio.post(
                    '/api/storage/create_folder', 
                    data: {
                      "name": nameController.text,
                      "parent_id": _currentParentId
                    },
                    options: Options(headers: {'Authorization': 'Bearer $token'}),
                  );
                  
                  _fetchItems(); 
                } catch (e) {
                  if (!mounted) return;
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            }, 
            child: Text("Create"), 
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              if (_folderStack.length > 1)
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, size: 16),
                  onPressed: () {
                    setState(() => _folderStack.removeLast());
                    _fetchItems();
                  },
                ),
              Expanded(
                child: _isSearching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: "Search files & folders...",
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: TextStyle(fontSize: 16),
                      )
                    : Text(
                        _folderStack.last['name'],
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
              ),
              Spacer(),
              IconButton(
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: _isSearching ? Colors.blue : Colors.grey,
                ),
                onPressed: _toggleSearch,
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _isGridView ? Icons.view_list : Icons.grid_view,
                  color: Colors.grey,
                ),
                onPressed: _toggleViewMode,
              ),
            ],
          ),
          if (_isSearching && _searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "${_filteredItems.length} results found",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Add Document", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                
                // ✅ NEW: Add by Identifier (DOI, ISBN, PMID, arXiv)
                _buildMenuItem(Icons.tag, "Add by Identifier", () {
                  Navigator.pop(context);
                  _navigateToIdentifierScreen();
                }, subtitle: "DOI, ISBN, PMID, arXiv"),
                
                // ✅ NEW: Import from File (.bib, .ris)
                _buildMenuItem(Icons.file_upload, "Import from File", () {
                  Navigator.pop(context);
                  _importFromFile();
                }, subtitle: ".bib, .ris"),
                
                // ✅ NEW: Manual Entry
                _buildMenuItem(Icons.edit_note, "Manual Entry", () {
                  Navigator.pop(context);
                  _navigateToManualEntryScreen();
                }, subtitle: "Enter information manually"),
                
                Divider(height: 32),
                
                // Upload PDF
                _buildMenuItem(Icons.upload_file, "Upload PDF", () {
                  Navigator.pop(context); 
                  _uploadFile(); 
                }),
                
                // Create Folder
                _buildMenuItem(Icons.create_new_folder, "New Folder", () {
                  Navigator.pop(context);
                  _createFolder();
                }),
                
                Divider(height: 32),
                
                // 🔑 Debug: Get Token for Postman
                _buildMenuItem(Icons.vpn_key, "🔑 Get Token (Debug)", () {
                  Navigator.pop(context);
                  _navigateToTokenDebugScreen(); 
                }, subtitle: "For Postman API testing"),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(IconData icon, String text, VoidCallback onTap, {String? subtitle}) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Color(0xFF2D60FF), size: 24),
      ),
      title: Text(text, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])) : null,
      trailing: Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    );
  }

  // ===================================================
  // NEW NAVIGATION METHODS
  // ===================================================
  
  // Navigate to Identifier Input Screen (DOI, ISBN, PMID, arXiv)
  void _navigateToIdentifierScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IdentifierInputScreen(parentId: _currentParentId),
      ),
    );

    if (result == true) {
      _fetchItems(); // Refresh list
    }
  }

  void _navigateToTokenDebugScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TokenDebugScreen()),
    );
  }

  // Import from File (.bib, .ris)
  void _importFromFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bib', 'ris'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text("Importing entries..."))
            ],
          ),
        ),
      );

      try {
        final importResult = await DocumentImportService.importFromFile(
          file: file,
          parentId: _currentParentId,
        );

        if (!mounted) return;
        
        Navigator.pop(context); // Close loading dialog
        
        if (importResult['success']) {
          final successCount = importResult['success_count'];
          final totalCount = importResult['total'];
          
          _fetchItems(); // Refresh list
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Imported $successCount out of $totalCount entries"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Show errors if any
          if (importResult['failed_count'] > 0) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text("Import Summary"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("✅ Success: $successCount"),
                    Text("❌ Failed: ${importResult['failed_count']}"),
                    SizedBox(height: 10),
                    Text("Some entries could not be imported due to invalid format.",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text("OK"),
                  ),
                ],
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ ${importResult['message']}"),
              backgroundColor: Colors.red,
            ),
          );
        }

      } catch (e) {
        if (!mounted) return;
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import Failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Navigate to Manual Entry Screen
  void _navigateToManualEntryScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManualEntryScreen(parentId: _currentParentId),
      ),
    );

    if (result == true) {
      _fetchItems(); // Refresh list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildBreadcrumb(),
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator()) 
              : _filteredItems.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchController.text.isNotEmpty 
                                ? Icons.search_off 
                                : Icons.folder_open,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty 
                                ? "No results found" 
                                : "No files yet",
                            style: TextStyle(color: Colors.grey, fontSize: 18),
                          ),
                          Text(
                            _searchController.text.isNotEmpty 
                                ? "Try a different search term" 
                                : "Tap + to add files or folders",
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    )
              : _isGridView ? _buildGridView() : _buildListView(),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0), 
        child: FloatingActionButton(
          heroTag: "btn_upload_file",
          onPressed: _showAddMenu, 
          backgroundColor: Color(0xFF2D60FF),
          child: Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        return _buildListTile(_filteredItems[index]);
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        return _buildGridTile(_filteredItems[index]);
      },
    );
  }

  Widget _buildListTile(Map<String, dynamic> item) {
    bool isFolder = item['type'] == 'folder';
    bool isLinkRef = !isFolder && item['size_bytes'] == 0 && (item['file_url'] ?? "").contains("doi.org");
    final hasUsableMetadata = isFolder ? true : _hasUsableMetadata(item);

    String subtitleText = "";
    if (isFolder) {
      subtitleText = "Folder";
    } else {
      var metadata = item['metadata_info'] ?? item['metadata'];
      String author = "Unknown Author";
      
      if (metadata != null && metadata['authors'] != null) {
        List authors = metadata['authors'];
        if (authors.isNotEmpty) {
          author = authors.first.toString();
        }
      }

      // ✅ PARSE size_bytes AN TOÀN
      double sizeInMB = 0.0;
      if (item['size_bytes'] != null) {
        try {
          // Chuyển String hoặc int thành double
          final sizeBytes = item['size_bytes'];
          if (sizeBytes is int) {
            sizeInMB = sizeBytes / 1024 / 1024;
          } else if (sizeBytes is String) {
            sizeInMB = int.parse(sizeBytes) / 1024 / 1024;
          } else if (sizeBytes is double) {
            sizeInMB = sizeBytes / 1024 / 1024;
          }
        } catch (e) {
          sizeInMB = 0.0;
        }
      }
          
      subtitleText = "$author • ${sizeInMB.toStringAsFixed(1)} MB";
    }

    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isFolder ? Colors.amber.withValues(alpha: 0.1) 
          : (isLinkRef ? Colors.purple.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isFolder ? Icons.folder : (isLinkRef ? Icons.link : Icons.picture_as_pdf), 
          color: isFolder ? Colors.amber : (isLinkRef ? Colors.purple : Colors.blue),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item['name'] ?? "No Name",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(subtitleText, style: TextStyle(fontSize: 12)),
          if (!isFolder && !hasUsableMetadata) ...[                
            SizedBox(height: 4),
            _isAbstractOnly(item) ? _buildAbstractOnlyBadge() : _buildMissingMetadataBadge(),
          ],
        ],
      ),
      trailing: IconButton( 
        icon: Icon(Icons.more_vert),
        onPressed: () => _showItemOptions(item), 
      ),
      onTap: () => _handleItemTap(item),
    );
  }

  Widget _buildGridTile(Map<String, dynamic> item) {
    bool isFolder = item['type'] == 'folder';
    bool isLinkRef = !isFolder && item['size_bytes'] == 0 && (item['file_url'] ?? "").contains("doi.org");
    final hasUsableMetadata = isFolder ? true : _hasUsableMetadata(item);

    // ✅ PARSE size_bytes AN TOÀN
    String sizeText = "Link";
    if (!isFolder && item['size_bytes'] != null) {
      try {
        double sizeInMB = 0.0;
        final sizeBytes = item['size_bytes'];
        
        if (sizeBytes is int) {
          sizeInMB = sizeBytes / 1024 / 1024;
        } else if (sizeBytes is String) {
          sizeInMB = int.parse(sizeBytes) / 1024 / 1024;
        } else if (sizeBytes is double) {
          sizeInMB = sizeBytes / 1024 / 1024;
        }
        
        sizeText = "${sizeInMB.toStringAsFixed(1)} MB";
      } catch (e) {
        sizeText = "0.0 MB";
      }
    }

    return GestureDetector(
      onTap: () => _handleItemTap(item),
      onLongPress: () => _showItemOptions(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isFolder ? Colors.amber.withValues(alpha: 0.1) 
                : (isLinkRef ? Colors.purple.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFolder ? Icons.folder : (isLinkRef ? Icons.link : Icons.picture_as_pdf),
                size: 40,
                color: isFolder ? Colors.amber : (isLinkRef ? Colors.purple : Colors.blue),
              ),
            ),
            SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                item['name'] ?? "No Name",
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            if (!isFolder && !hasUsableMetadata) ...[
              SizedBox(height: 6),
              _isAbstractOnly(item) ? _buildAbstractOnlyBadge() : _buildMissingMetadataBadge(),
            ],
            if (!isFolder) ...[
              SizedBox(height: 4),
              Text(
                sizeText,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
            Spacer(),
            IconButton(
              icon: Icon(Icons.more_horiz, size: 20),
              onPressed: () => _showItemOptions(item),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleItemTap(Map<String, dynamic> item) async {
    bool isFolder = item['type'] == 'folder';
    
    // ✅ HANDLE FOLDER: Navigate into folder
    if (isFolder) {
      setState(() {
        _folderStack.add({"id": item['id'], "name": item['name']});
        _searchController.clear();
        _isSearching = false;
      });
      _fetchItems();
      return;
    }

    // ✅ HANDLE FILE: Check if it has actual PDF or is metadata-only
    final fileUrl = item['file_url'] as String?;
    final metadata = item['metadata'] ?? item['metadata_info'];
    
    // Check if this file has a real PDF (local or cloud storage)
    // Exclude doi.org links which are just metadata references
    final hasPdf = fileUrl != null && 
                   fileUrl.isNotEmpty && 
                   !fileUrl.contains('doi.org');
    
    if (hasPdf) {
      // ✅ OPEN PDF READER for files with actual PDF
      
      // For cloud files, construct API endpoint URL with auth token
      String pdfViewerUrl = fileUrl;
      if (fileUrl.startsWith('dropbox://') || 
          fileUrl.startsWith('gdrive://') || 
          fileUrl.startsWith('onedrive://')) {
        // Get Firebase token for authentication
        final user = FirebaseAuth.instance.currentUser;
        final token = await user?.getIdToken();
        
        // Use backend streaming endpoint for cloud files
        pdfViewerUrl = 'http://10.0.2.2:3000/api/storage/cloud-file/${item['id']}?token=$token';
        debugPrint('☁️ Cloud file detected, using streaming endpoint: $pdfViewerUrl');
      }
      
      Navigator.push(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(
          builder: (context) => PdfReaderScreen(
            fileId: item['id'],
            fileName: item['name'],
            pdfUrl: pdfViewerUrl,
            metadata: metadata is Map ? Map<String, dynamic>.from(metadata) : null,
          ),
        ),
      );
    } else {
      // ✅ METADATA ONLY: Open DOI or URL in browser
      String? urlToOpen;
      
      // Priority: DOI > URL from metadata
      if (metadata != null) {
        final doi = metadata['doi'];
        final url = metadata['url'];
        
        if (doi != null && doi.toString().isNotEmpty) {
          urlToOpen = 'https://doi.org/$doi';
        } else if (url != null && url.toString().isNotEmpty) {
          urlToOpen = url.toString();
        }
      }
      
      if (urlToOpen != null && urlToOpen.isNotEmpty) {
        final Uri uri = Uri.parse(urlToOpen);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Could not open URL: $urlToOpen")),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ℹ️ No PDF or URL available for this item")),
        );
      }
    }
  }

  void _showItemOptions(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(item['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Divider(),
              
              ListTile(
                leading: Icon(Icons.info_outline, color: Colors.blue),
                title: Text("View Details (Metadata)"),
                onTap: () {
                  Navigator.pop(context);
                  _showMetadataDialog(item);
                },
              ),
              
              ListTile(
                leading: Icon(Icons.edit_outlined, color: Colors.green),
                title: Text("Edit Metadata"),
                onTap: () {
                  Navigator.pop(context);
                  _showEditMetadataDialog(item);
                },
              ),
              
              if (item['type'] == 'file') // Only show for files
                ListTile(
                  leading: Icon(Icons.format_quote, color: Colors.purple),
                  title: Text("Generate Citation"),
                  onTap: () {
                    Navigator.pop(context);
                    _showCitationDialog(item);
                  },
                ),
              
              if (item['type'] == 'file') // Only show for files
                ListTile(
                  leading: Icon(Icons.fact_check_outlined, color: Colors.orange),
                  title: Text("Fact Check DOIs"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FactCheckScreen(
                          itemId: item['id'].toString(),
                          title: item['name'] ?? 'Document',
                        ),
                      ),
                    );
                  },
                ),

              ListTile(
                leading: Icon(Icons.drive_file_move_outline, color: Colors.orange),
                title: Text("Move to..."),
                onTap: () {
                   Navigator.pop(context);
                   _showMoveDialog(item);
                },
              ),

              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text("Delete"),
                onTap: () {
                  Navigator.pop(context);
                  _deleteItem(item['id']);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMoveDialog(Map<String, dynamic> item) async {
    User? user = FirebaseAuth.instance.currentUser;
    String? token = await user?.getIdToken();
    var res = await _dio.get('/api/storage/folders', options: Options(headers: {'Authorization': 'Bearer $token'}));
    List folders = res.data;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Move '${item['name']}' to..."),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: [
              if (_currentParentId != null)
                ListTile(
                  leading: Icon(Icons.arrow_upward),
                  title: Text(".. (Parent Folder)"),
                  onTap: () => _performMove(item['id'], null, ctx), 
                ),
              
              Divider(),
              ...folders.where((f) => f['id'] != item['id']).map((f) => ListTile( 
                leading: Icon(Icons.folder, color: Colors.amber),
                title: Text(f['name']),
                onTap: () => _performMove(item['id'], f['id'], ctx),
              ))
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performMove(String itemId, String? newParentId, BuildContext ctx) async {
    Navigator.pop(ctx);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();
      await _dio.patch('/api/storage/items/$itemId/move',
        data: {"new_parent_id": newParentId},
        options: Options(headers: {'Authorization': 'Bearer $token'})
      );
      _fetchItems();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Moved successfully")));
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Move failed")));
    }
  }

  void _showEditMetadataDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => EditMetadataDialog(
        item: item,
        onSave: (updatedItem) {
          // Refresh the file list after successful edit
          _fetchItems();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Metadata updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _showCitationDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => CitationDialog(
        itemId: item['id'],
        itemName: item['name'],
      ),
    );
  }

  void _showMetadataDialog(Map<String, dynamic> item) {
    var meta = item['metadata_info'] ?? item['metadata'] ?? {};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Document Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetaRow("Title", meta['title'] ?? item['name']),
              _buildMetaRow("Authors", (meta['authors'] as List?)?.join(", ") ?? "N/A"),
              _buildMetaRow("Year", meta['year']?.toString() ?? "N/A"),
              _buildMetaRow("DOI", meta['doi'] ?? "N/A"),
              _buildMetaRow("Journal", meta['journal'] ?? "N/A"),
              SizedBox(height: 10),
              Text("Abstract:", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(meta['abstract'] ?? "No abstract available.", style: TextStyle(color: Colors.grey[700])),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Close"))],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(text: TextSpan(
        style: TextStyle(color: Colors.black, fontSize: 14),
        children: [
          TextSpan(text: "$label: ", style: TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: value),
        ]
      )),
    );
  }

  Future<void> _deleteItem(String itemId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Item?"),
        content: Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) {
       try {
         User? user = FirebaseAuth.instance.currentUser;
         String? token = await user?.getIdToken();
         await _dio.delete('/api/storage/items/$itemId',
            options: Options(headers: {'Authorization': 'Bearer $token'})
         );
         _fetchItems();
       } catch (e) {
        if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete failed")));
       }
    }
  }
}