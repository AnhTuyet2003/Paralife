import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/document_import_service.dart';

class ManualEntryScreen extends StatefulWidget {
  final String? parentId;

  const ManualEntryScreen({super.key, this.parentId});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorsController = TextEditingController();
  final _yearController = TextEditingController();
  final _publisherController = TextEditingController();
  final _journalController = TextEditingController();
  final _doiController = TextEditingController();
  final _abstractController = TextEditingController();
  
  String _selectedItemType = 'article';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _itemTypes = [
    {'value': 'article', 'label': 'Journal Article', 'icon': Icons.article},
    {'value': 'book', 'label': 'Book', 'icon': Icons.book},
    {'value': 'chapter', 'label': 'Book Chapter', 'icon': Icons.book_outlined},
    {'value': 'conference', 'label': 'Conference Paper', 'icon': Icons.groups},
    {'value': 'thesis', 'label': 'Thesis', 'icon': Icons.school},
    {'value': 'webpage', 'label': 'Webpage', 'icon': Icons.language},
    {'value': 'report', 'label': 'Report', 'icon': Icons.description},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _authorsController.dispose();
    _yearController.dispose();
    _publisherController.dispose();
    _journalController.dispose();
    _doiController.dispose();
    _abstractController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await DocumentImportService.importManual(
        title: _titleController.text.trim(),
        authors: _authorsController.text.trim(),
        year: _yearController.text.trim().isNotEmpty
            ? int.tryParse(_yearController.text.trim())
            : null,
        publisher: _publisherController.text.trim(),
        journal: _journalController.text.trim(),
        doi: _doiController.text.trim(),
        abstract: _abstractController.text.trim(),
        itemType: _selectedItemType,
        parentId: widget.parentId,
      );

      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✅ Document created successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Close screen and notify parent to refresh
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Entry'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Item Type Selector
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Document Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedItemType,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: _itemTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type['value'],
                            child: Row(
                              children: [
                                Icon(type['icon'], size: 20, color: iconColor),
                                const SizedBox(width: 8),
                                Text(type['label']),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedItemType = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Title (Required)
              _buildTextField(
                controller: _titleController,
                label: 'Title *',
                icon: Icons.title,
                hint: 'Enter document title',
                required: true,
              ),

              const SizedBox(height: 16),

              // Authors
              _buildTextField(
                controller: _authorsController,
                label: 'Authors',
                icon: Icons.people,
                hint: 'e.g., John Doe, Jane Smith',
                helperText: 'Separate multiple authors with commas',
              ),

              const SizedBox(height: 16),

              // Year
              _buildTextField(
                controller: _yearController,
                label: 'Year',
                icon: Icons.calendar_today,
                hint: 'e.g., 2024',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
              ),

              const SizedBox(height: 16),

              // Journal/Publication
              _buildTextField(
                controller: _journalController,
                label: 'Journal / Publication',
                icon: Icons.library_books,
                hint: 'e.g., Nature, Science',
              ),

              const SizedBox(height: 16),

              // Publisher
              _buildTextField(
                controller: _publisherController,
                label: 'Publisher',
                icon: Icons.business,
                hint: 'e.g., Springer, IEEE',
              ),

              const SizedBox(height: 16),

              // DOI
              _buildTextField(
                controller: _doiController,
                label: 'DOI (Optional)',
                icon: Icons.tag,
                hint: 'e.g., 10.1038/nature12373',
              ),

              const SizedBox(height: 16),

              // Abstract
              _buildTextField(
                controller: _abstractController,
                label: 'Abstract / Summary',
                icon: Icons.notes,
                hint: 'Enter a brief summary or abstract',
                maxLines: 5,
              ),

              const SizedBox(height: 30),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save),
                          SizedBox(width: 8),
                          Text(
                            'Create Document',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 16),

              // Help Text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only the title is required. You can add other information later by editing the document.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? helperText,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }
}
