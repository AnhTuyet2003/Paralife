import 'package:flutter/material.dart';
import '../services/document_import_service.dart';

class IdentifierInputScreen extends StatefulWidget {
  final String? parentId;

  const IdentifierInputScreen({super.key, this.parentId});

  @override
  State<IdentifierInputScreen> createState() => _IdentifierInputScreenState();
}

class _IdentifierInputScreenState extends State<IdentifierInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  
  String _selectedType = 'doi';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _identifierTypes = [
    {
      'value': 'doi',
      'label': 'DOI',
      'hint': 'e.g., 10.1038/nature12373',
      'icon': Icons.science,
    },
    {
      'value': 'isbn',
      'label': 'ISBN',
      'hint': 'e.g., 978-0-13-468599-1',
      'icon': Icons.book,
    },
    {
      'value': 'pmid',
      'label': 'PubMed ID (PMID)',
      'hint': 'e.g., 23846655',
      'icon': Icons.medical_services,
    },
    {
      'value': 'arxiv',
      'label': 'arXiv ID',
      'hint': 'e.g., 1234.5678 or 1234.5678v2',
      'icon': Icons.article,
    },
  ];

  Map<String, dynamic> get _currentType {
    return _identifierTypes.firstWhere(
      (type) => type['value'] == _selectedType,
      orElse: () => _identifierTypes[0],
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _handleImport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await DocumentImportService.importByIdentifier(
        type: _selectedType,
        value: _identifierController.text.trim(),
        parentId: widget.parentId,
      );

      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result['has_pdf'] ? Icons.check_circle : Icons.info,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result['has_pdf']
                        ? '✅ ${result['message']} (with PDF)'
                        : '✅ ${result['message']} (metadata only)',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Close screen and notify parent to refresh
        Navigator.pop(context, true);
      } else {
        // Show error
        final isRateLimited = result['rate_limited'] == true;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isRateLimited ? Icons.schedule : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('❌ ${result['message']}'),
                ),
              ],
            ),
            backgroundColor: isRateLimited ? Colors.orange : Colors.red,
            duration: Duration(seconds: isRateLimited ? 5 : 4),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add by Identifier'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type Selector
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
                        'Select Identifier Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        decoration: InputDecoration(
                          prefixIcon: Icon(_currentType['icon']),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: _identifierTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type['value'],
                            child: Row(
                              children: [
                                Icon(type['icon'], size: 20),
                                const SizedBox(width: 8),
                                Text(type['label']),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                            _identifierController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Identifier Input
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
                      Text(
                        'Enter ${_currentType['label']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _identifierController,
                        decoration: InputDecoration(
                          hintText: _currentType['hint'],
                          prefixIcon: const Icon(Icons.tag),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a ${_currentType['label']}';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleImport(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About ${_currentType['label']}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getInfoText(_selectedType),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Import Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleImport,
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
                          Icon(Icons.download),
                          SizedBox(width: 8),
                          Text(
                            'Import Document',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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

  String _getInfoText(String type) {
    switch (type) {
      case 'doi':
        return 'Digital Object Identifier - A unique code for academic papers. We\'ll fetch metadata and PDF if available.';
      case 'isbn':
        return 'International Standard Book Number - Used for books. We\'ll fetch information from Google Books.';
      case 'pmid':
        return 'PubMed ID - Identifier for biomedical literature. We\'ll fetch from PubMed database.';
      case 'arxiv':
        return 'arXiv preprint ID - Open-access repository. We\'ll download the PDF and metadata.';
      default:
        return '';
    }
  }
}
