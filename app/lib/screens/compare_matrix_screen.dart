import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompareMatrixScreen extends StatefulWidget {
  final List<String> fileIds;
  const CompareMatrixScreen({super.key, required this.fileIds});

  @override
  State<CompareMatrixScreen> createState() => _CompareMatrixScreenState();
}

class _CompareMatrixScreenState extends State<CompareMatrixScreen> {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://10.0.2.2:3000',
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 60),
  ));
  List<dynamic> _matrix = [];
  List<dynamic> _missingFiles = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _displayValue(dynamic value) {
    if (value == null) return '-';
    final text = value.toString().trim();
    if (text.isEmpty) return '-';
    final normalized = text.toLowerCase();
    if (normalized == 'n/a' || normalized == 'null' || normalized == 'undefined') {
      return '-';
    }
    return text;
  }

  @override
  void initState() {
    super.initState();
    _fetchMatrix();
  }

  Future<void> _fetchMatrix() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      final res = await _dio.post('/api/chat/compare',
        data: {'file_ids': widget.fileIds},
        options: Options(headers: {'Authorization': 'Bearer $token'})
      );

      final matrix = (res.data is Map<String, dynamic>)
        ? (res.data['matrix'] as List<dynamic>? ?? <dynamic>[])
        : <dynamic>[];

      final missingFiles = (res.data is Map<String, dynamic>)
        ? (res.data['missing_files'] as List<dynamic>? ?? <dynamic>[])
        : <dynamic>[];

      setState(() {
        _matrix = matrix;
        _missingFiles = missingFiles;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải dữ liệu so sánh. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("So Sánh Tài Liệu")),
      body: _isLoading 
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(), SizedBox(height: 10), Text("AI đang đọc & phân tích...")
          ]))
        : _errorMessage != null
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red[700], fontSize: 16),
                ),
              ),
            )
        : _matrix.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Chưa có dữ liệu metadata để hiển thị so sánh.\nHãy cập nhật metadata (method/data/result/limitation) cho tài liệu.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
        : Column(
            children: [
              if (_missingFiles.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.fromLTRB(12, 12, 12, 0),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    '⚠️ ${_missingFiles.length} tài liệu chưa có dữ liệu phân tích (embeddings/metadata đầy đủ): ${_missingFiles.map((f) => _displayValue(f['file_name'])).join(', ')}. Hệ thống đã thử tra cứu nguồn học thuật uy tín nếu có thể.',
                    style: TextStyle(color: Colors.orange[900]),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                      dataRowMinHeight: 60,
                      dataRowMaxHeight: double.infinity,
                      columnSpacing: 20,
                      columns: [
                        DataColumn(label: Text('Tài liệu', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: SizedBox(width: 150, child: Text('Phương Pháp', style: TextStyle(fontWeight: FontWeight.bold)))),
                        DataColumn(label: SizedBox(width: 150, child: Text('Dữ Liệu', style: TextStyle(fontWeight: FontWeight.bold)))),
                        DataColumn(label: SizedBox(width: 150, child: Text('Kết Quả', style: TextStyle(fontWeight: FontWeight.bold)))),
                        DataColumn(label: SizedBox(width: 150, child: Text('Hạn Chế', style: TextStyle(fontWeight: FontWeight.bold)))),
                      ],
                      rows: _matrix.map((row) {
                        return DataRow(cells: [
                          DataCell(Container(
                            width: 100,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(_displayValue(row['file_name']), style: TextStyle(fontWeight: FontWeight.bold)),
                          )),
                          DataCell(Container(width: 150, padding: EdgeInsets.symmetric(vertical: 8), child: Text(_displayValue(row['method'])))),
                          DataCell(Container(width: 150, padding: EdgeInsets.symmetric(vertical: 8), child: Text(_displayValue(row['data'])))),
                          DataCell(Container(width: 150, padding: EdgeInsets.symmetric(vertical: 8), child: Text(_displayValue(row['result'])))),
                          DataCell(Container(width: 150, padding: EdgeInsets.symmetric(vertical: 8), child: Text(_displayValue(row['limitation'])))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }
}