import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/services/citation_service.dart';

class CitationDialog extends StatefulWidget {
  final String itemId;
  final String itemName;

  const CitationDialog({
    super.key,
    required this.itemId,
    required this.itemName,
  });

  @override
  State<CitationDialog> createState() => _CitationDialogState();
}

class _CitationDialogState extends State<CitationDialog> {
  final CitationService _citationService = CitationService();
  
  List<Map<String, dynamic>> _styles = [];
  String? _selectedStyle;
  String? _citation;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStyles();
  }

  Future<void> _loadStyles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final styles = await _citationService.getStyles();
      setState(() {
        _styles = styles;
        _selectedStyle = styles.isNotEmpty ? styles[0]['id'] : null;
        _isLoading = false;
      });

      // Auto-generate with first style
      if (_selectedStyle != null) {
        _generateCitation();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _generateCitation() async {
    if (_selectedStyle == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _citation = null;
    });

    try {
      final citation = await _citationService.generateCitation(
        widget.itemId,
        _selectedStyle!,
      );

      setState(() {
        _citation = citation;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _copyCitation() {
    if (_citation != null) {
      Clipboard.setData(ClipboardData(text: _citation!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('📋 Citation copied to clipboard!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(maxHeight: 600),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.format_quote, color: Color(0xFF2D60FF), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate Citation',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.itemName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(height: 24),

            // Style Selector
            if (_styles.isNotEmpty) ...[
              Text(
                'Citation Style:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedStyle,
                  isExpanded: true,
                  underline: SizedBox(),
                  items: _styles.map((style) {
                    return DropdownMenuItem<String>(
                      value: style['id'],
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              style['name'],
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                            ),
                            SizedBox(height: 2),
                            Text(
                              style['example'],
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedStyle = value);
                    _generateCitation();
                  },
                ),
              ),
              SizedBox(height: 16),
            ],

            // Citation Output
            Text(
              'Generated Citation:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            
            Flexible(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Generating citation...'),
                          ],
                        ),
                      )
                    : _error != null
                        ? SingleChildScrollView(
                            child: Column(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red[700]),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _generateCitation,
                                  icon: Icon(Icons.refresh),
                                  label: Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _citation != null
                            ? SingleChildScrollView(
                                child: SelectableText(
                                  _citation!,
                                  style: TextStyle(fontSize: 13, height: 1.5),
                                ),
                              )
                            : Center(
                                child: Text(
                                  'Select a style to generate citation',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
              ),
            ),

            SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                    label: Text('Close'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _citation != null ? _copyCitation : null,
                    icon: Icon(Icons.copy),
                    label: Text('Copy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2D60FF),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
