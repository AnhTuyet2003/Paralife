import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

class FactCheckScreen extends StatefulWidget {
  final String itemId;
  final String title;

  const FactCheckScreen({
    super.key,
    required this.itemId,
    required this.title,
  });

  @override
  State<FactCheckScreen> createState() => _FactCheckScreenState();
}

class _FactCheckScreenState extends State<FactCheckScreen> {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:3000'));
  
  bool _isLoading = true;
  String? _error;
  
  Map<String, dynamic>? _result;
  List<dynamic> _references = [];

  @override
  void initState() {
    super.initState();
    _performFactCheck();
  }

  Future<void> _performFactCheck() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _dio.post(
        '/api/items/${widget.itemId}/fact-check',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      setState(() {
        _result = response.data;
        _references = response.data['references'] ?? [];
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = 'Failed to perform fact check: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fact Check', style: TextStyle(fontSize: 18)),
            Text(
              widget.title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _performFactCheck,
            tooltip: 'Recheck',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking DOI references...', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('This may take a moment', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _performFactCheck,
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_references.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No DOIs Found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'This document does not contain any DOI references to check.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Summary Card
        _buildSummaryCard(),
        
        // References List
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _references.length,
            itemBuilder: (context, index) {
              return _buildReferenceCard(_references[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final summary = _result?['summary'];
    if (summary == null) return SizedBox.shrink();

    final total = summary['total'] ?? 0;
    final valid = summary['valid'] ?? 0;
    final invalid = summary['invalid'] ?? 0;
    final unknown = summary['unknown'] ?? 0;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D60FF), Color(0xFF1a4acc)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fact Check Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Total', total, Colors.white70),
              _buildStat('✅ Valid', valid, Colors.greenAccent),
              _buildStat('❌ Invalid', invalid, Colors.redAccent),
              if (unknown > 0) _buildStat('❓ Unknown', unknown, Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceCard(Map<String, dynamic> reference) {
    final doi = reference['doi'] ?? '';
    final isValid = reference['isValid'];
    final warning = reference['warning'];
    final metadata = reference['metadata'];

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (isValid == true) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusLabel = 'Valid';
    } else if (isValid == false) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusLabel = 'Hallucination Detected';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.help_outline;
      statusLabel = 'Unknown';
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Row
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                if (isValid == true)
                  Icon(Icons.verified, color: Colors.blue, size: 20),
              ],
            ),
            
            SizedBox(height: 12),
            
            // DOI
            GestureDetector(
              onTap: () => _launchDOI(doi),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doi,
                        style: TextStyle(
                          color: Colors.blue,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                  ],
                ),
              ),
            ),
            
            // Warning (for invalid)
            if (warning != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: TextStyle(color: Colors.red[900], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Metadata (for valid DOIs)
            if (metadata != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (metadata['title'] != null) ...[
                      Text(
                        metadata['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                    ],
                    if (metadata['authors'] != null)
                      _buildMetadataRow(Icons.person, metadata['authors']),
                    if (metadata['year'] != null)
                      _buildMetadataRow(Icons.calendar_today, metadata['year'].toString()),
                    if (metadata['journal'] != null)
                      _buildMetadataRow(Icons.book, metadata['journal']),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchDOI(String doi) async {
    final url = Uri.parse('https://doi.org/$doi');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
