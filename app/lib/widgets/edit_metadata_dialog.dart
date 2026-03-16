import 'package:flutter/material.dart';
import 'package:app/services/api_service.dart';

/// ✅ DIALOG: Edit Metadata với AI Auto-suggest Tags
class EditMetadataDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(Map<String, dynamic>) onSave;

  const EditMetadataDialog({
    super.key,
    required this.item,
    required this.onSave,
  });

  @override
  State<EditMetadataDialog> createState() => _EditMetadataDialogState();
}

class _EditMetadataDialogState extends State<EditMetadataDialog> {
  late TextEditingController _titleController;
  late TextEditingController _authorsController;
  late TextEditingController _yearController;
  late TextEditingController _doiController;
  late TextEditingController _isbnController;
  late TextEditingController _publisherController;
  late TextEditingController _abstractController;
  late TextEditingController _tagsController;
  late TextEditingController _journalController;

  bool _isLoading = false;
  bool _isSuggestingTags = false;

  @override
  void initState() {
    super.initState();
    final metadata = widget.item['metadata'] ?? {};

    _titleController = TextEditingController(text: metadata['title'] ?? widget.item['name'] ?? '');
    _authorsController = TextEditingController(
      text: _formatAuthors(metadata['authors']),
    );
    _yearController = TextEditingController(text: metadata['year']?.toString() ?? '');
    _doiController = TextEditingController(text: metadata['doi'] ?? '');
    _isbnController = TextEditingController(text: metadata['isbn'] ?? '');
    _publisherController = TextEditingController(text: metadata['publisher'] ?? '');
    _abstractController = TextEditingController(text: metadata['abstract'] ?? '');
    _tagsController = TextEditingController(
      text: _formatTags(metadata['tags']),
    );
    _journalController = TextEditingController(text: metadata['journal'] ?? '');
  }

  String _formatAuthors(dynamic authors) {
    if (authors == null) return '';
    if (authors is List) return authors.join(', ');
    return authors.toString();
  }

  String _formatTags(dynamic tags) {
    if (tags == null) return '';
    if (tags is List) return tags.join(', ');
    return tags.toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorsController.dispose();
    _yearController.dispose();
    _doiController.dispose();
    _isbnController.dispose();
    _publisherController.dispose();
    _abstractController.dispose();
    _tagsController.dispose();
    _journalController.dispose();
    super.dispose();
  }

  // ✅ AI AUTO-SUGGEST TAGS
  Future<void> _suggestTags() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a title first')),
      );
      return;
    }

    setState(() => _isSuggestingTags = true);

    try {
      final response = await ApiService.dio.post(
        '/api/ai/suggest-tags',
        data: {
          'title': _titleController.text.trim(),
          'abstract': _abstractController.text.trim(),
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final tags = response.data['tags'] as List;
        setState(() {
          _tagsController.text = tags.join(', ');
        });
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ AI suggested ${tags.length} tags!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to suggest tags');
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to suggest tags: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSuggestingTags = false);
    }
  }

  // ✅ SAVE METADATA
  Future<void> _saveMetadata() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.dio.put(
        '/api/storage/items/${widget.item['id']}/metadata',
        data: {
          'title': _titleController.text.trim(),
          'authors': _authorsController.text.trim(),
          'year': _yearController.text.trim(),
          'doi': _doiController.text.trim(),
          'isbn': _isbnController.text.trim(),
          'publisher': _publisherController.text.trim(),
          'abstract': _abstractController.text.trim(),
          'tags': _tagsController.text.trim(),
          'journal': _journalController.text.trim(),
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Metadata updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSave(response.data['data']);
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to update metadata');
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF2D60FF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Edit Metadata',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form Fields
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField('Title', _titleController, required: true),
                    _buildTextField('Authors', _authorsController, hint: 'Separate with commas'),
                    _buildTextField('Year', _yearController, keyboardType: TextInputType.number),
                    _buildTextField('DOI', _doiController),
                    _buildTextField('ISBN', _isbnController),
                    _buildTextField('Publisher', _publisherController),
                    _buildTextField('Journal', _journalController),
                    _buildTextField('Abstract', _abstractController, maxLines: 4),
                    
                    // Tags với AI Suggest Button
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tags',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isSuggestingTags ? null : _suggestTags,
                          icon: _isSuggestingTags
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(Icons.auto_awesome, size: 16),
                          label: Text('AI Suggest'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF9D59FF),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _tagsController,
                      decoration: InputDecoration(
                        hintText: 'e.g., NLP, Machine Learning',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveMetadata,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2D60FF),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              if (required)
                Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint ?? 'Enter $label',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
