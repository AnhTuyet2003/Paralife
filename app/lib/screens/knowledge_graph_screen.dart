// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';

class KnowledgeGraphScreen extends StatefulWidget {
  const KnowledgeGraphScreen({super.key});

  @override
  State<KnowledgeGraphScreen> createState() => _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState extends State<KnowledgeGraphScreen> {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:3000'));
  
  bool _isLoading = true;
  String? _error;
  
  List<dynamic> _nodes = [];
  List<dynamic> _links = [];
  List<dynamic> _aiSuggestions = [];
  Map<String, dynamic>? _stats;
  
  bool _showAISuggestions = false;
  bool _loadingAI = false;
  String? _selectedNodeId;

  @override
  void initState() {
    super.initState();
    _loadGraph();
  }

  Future<void> _loadGraph() async {
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

      final response = await _dio.get(
        '/api/graph',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      setState(() {
        _nodes = response.data['nodes'] ?? [];
        _links = response.data['links'] ?? [];
        _stats = response.data['stats'];
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = 'Failed to load graph: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAISuggestions() async {
    setState(() {
      _loadingAI = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _dio.get(
        '/api/ai/missing-links',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      setState(() {
        _aiSuggestions = response.data['suggestions'] ?? [];
        _showAISuggestions = true;
        _loadingAI = false;
      });

      if (_aiSuggestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No AI suggestions found'),
            backgroundColor: Colors.orange,
          ),
        );
      }

    } catch (e) {
      setState(() {
        _loadingAI = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get AI suggestions: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Knowledge Graph', style: TextStyle(fontSize: 18)),
            if (_stats != null)
              Text(
                '${_stats!['totalNodes']} documents • ${_stats!['totalLinks']} connections',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadGraph,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _nodes.isNotEmpty ? Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_showAISuggestions && _aiSuggestions.isNotEmpty)
            FloatingActionButton(
              heroTag: 'hide_ai',
              onPressed: () {
                setState(() {
                  _showAISuggestions = false;
                });
              },
              backgroundColor: Colors.grey,
              mini: true,
              child: Icon(Icons.visibility_off),
            ),
          SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'ai_suggest',
            onPressed: _loadingAI ? null : _loadAISuggestions,
            backgroundColor: Color(0xFF2D60FF),
            icon: _loadingAI 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Icon(Icons.auto_awesome),
            label: Text('AI Suggestions'),
          ),
        ],
      ) : null,
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
            Text('Loading knowledge graph...', style: TextStyle(color: Colors.grey)),
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
              Text('Error', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadGraph,
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_nodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_tree_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No Documents', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                'Add documents to see connections',
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
        // Stats Card
        _buildStatsCard(),
        
        // Graph Tabs
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                TabBar(
                  labelColor: Color(0xFF2D60FF),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Color(0xFF2D60FF),
                  tabs: [
                    Tab(text: 'Network View'),
                    Tab(text: 'Connections'),
                    Tab(text: 'AI Suggestions'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildNetworkView(),
                      _buildConnectionsList(),
                      _buildAISuggestionsList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    if (_stats == null) return SizedBox.shrink();

    final linkTypes = _stats!['linkTypes'] ?? {};
    
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D60FF), Color(0xFF1a4acc)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Documents', _stats!['totalNodes'], Icons.description),
              _buildStatItem('Links', _stats!['totalLinks'], Icons.link),
            ],
          ),
          if (linkTypes.isNotEmpty) ...[
            Divider(color: Colors.white30, height: 24),
            Text('Connection Types', style: TextStyle(color: Colors.white70, fontSize: 12)),
            SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (linkTypes['shared_author'] > 0)
                  _buildChip('👥 Authors: ${linkTypes['shared_author']}'),
                if (linkTypes['shared_keyword'] > 0)
                  _buildChip('🏷️ Keywords: ${linkTypes['shared_keyword']}'),
                if (linkTypes['citation'] > 0)
                  _buildChip('📚 Citations: ${linkTypes['citation']}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        SizedBox(height: 8),
        Text(
          value.toString(),
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: TextStyle(color: Colors.white, fontSize: 11)),
    );
  }

  Widget _buildNetworkView() {
    // Simple grid view of nodes with color coding
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _nodes.length,
      itemBuilder: (context, index) {
        final node = _nodes[index];
        return _buildNodeCard(node);
      },
    );
  }

  Widget _buildNodeCard(Map<String, dynamic> node) {
    final id = node['id'].toString();
    final title = node['title'] ?? 'Untitled';
    final group = node['group'] ?? 'default';
    final year = node['year'];
    
    // Color by group
    Color color;
    IconData icon;
    switch (group) {
      case 'article':
        color = Colors.blue;
        icon = Icons.article;
        break;
      case 'book':
        color = Colors.green;
        icon = Icons.book;
        break;
      case 'conference':
        color = Colors.orange;
        icon = Icons.event;
        break;
      default:
        color = Colors.grey;
        icon = Icons.description;
    }

    // Count connections
    final connectionCount = _links.where((link) => 
      link['source'] == id || link['target'] == id
    ).length;

    return GestureDetector(
      onTap: () => _showNodeDetails(node),
      child: Card(
        elevation: _selectedNodeId == id ? 8 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: _selectedNodeId == id 
            ? BorderSide(color: Color(0xFF2D60FF), width: 2)
            : BorderSide.none,
        ),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  SizedBox(width: 8),
                  if (year != null)
                    Text(
                      year.toString(),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.link, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    '$connectionCount connections',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionsList() {
    if (_links.isEmpty) {
      return Center(
        child: Text('No connections found', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _links.length,
      itemBuilder: (context, index) {
        return _buildLinkCard(_links[index]);
      },
    );
  }

  Widget _buildLinkCard(Map<String, dynamic> link) {
    final source = _nodes.firstWhere((n) => n['id'].toString() == link['source'], orElse: () => {});
    final target = _nodes.firstWhere((n) => n['id'].toString() == link['target'], orElse: () => {});
    final type = link['type'] ?? 'unknown';
    final label = link['label'] ?? type;

    IconData icon;
    Color color;
    switch (type) {
      case 'shared_author':
        icon = Icons.person;
        color = Colors.blue;
        break;
      case 'shared_keyword':
        icon = Icons.label;
        color = Colors.green;
        break;
      case 'citation':
        icon = Icons.format_quote;
        color = Colors.purple;
        break;
      default:
        icon = Icons.link;
        color = Colors.grey;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildDocumentChip(source['title'] ?? 'Unknown', true),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 20),
                  Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('connected to', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            _buildDocumentChip(target['title'] ?? 'Unknown', false),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentChip(String title, bool isSource) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSource ? Colors.blue[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: TextStyle(fontSize: 13),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildAISuggestionsList() {
    if (_loadingAI) {
      return Center(child: CircularProgressIndicator());
    }

    if (_aiSuggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No AI Suggestions Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Tap the AI Suggestions button to generate',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _aiSuggestions.length,
      itemBuilder: (context, index) {
        return _buildAISuggestionCard(_aiSuggestions[index]);
      },
    );
  }

  Widget _buildAISuggestionCard(Map<String, dynamic> suggestion) {
    final sourceId = suggestion['source_id'].toString();
    final targetId = suggestion['target_id'].toString();
    final relationType = suggestion['relation_type'] ?? 'unknown';
    final reasoning = suggestion['reasoning'] ?? '';

    final source = _nodes.firstWhere((n) => n['id'].toString() == sourceId, orElse: () => {});
    final target = _nodes.firstWhere((n) => n['id'].toString() == targetId, orElse: () => {});

    IconData icon;
    Color color;
    String typeLabel;

    switch (relationType) {
      case 'similar_methodology':
        icon = Icons.science;
        color = Colors.blue;
        typeLabel = 'Similar Methodology';
        break;
      case 'conflicting_results':
        icon = Icons.warning_amber_rounded;
        color = Colors.orange;
        typeLabel = 'Conflicting Results';
        break;
      case 'complementary_findings':
        icon = Icons.groups;
        color = Colors.green;
        typeLabel = 'Complementary Findings';
        break;
      default:
        icon = Icons.link;
        color = Colors.purple;
        typeLabel = 'Related';
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF2D60FF), size: 24),
                SizedBox(width: 8),
                Text(
                  'AI Suggestion',
                  style: TextStyle(
                    color: Color(0xFF2D60FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 16),
                  SizedBox(width: 6),
                  Text(
                    typeLabel,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            _buildDocumentChip(source['title'] ?? 'Unknown', true),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 2,
                    height: 20,
                    color: color,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Container(height: 2, color: color),
                  ),
                  Icon(Icons.arrow_forward, color: color, size: 20),
                ],
              ),
            ),
            _buildDocumentChip(target['title'] ?? 'Unknown', false),
            
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reasoning,
                      style: TextStyle(fontSize: 13, height: 1.4),
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

  void _showNodeDetails(Map<String, dynamic> node) {
    setState(() {
      _selectedNodeId = node['id'].toString();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 24),
              
              Text(
                node['title'] ?? 'Untitled',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              
              if (node['authors'] != null) ...[
                _buildDetailRow(Icons.person, 'Authors', node['authors'].toString()),
                SizedBox(height: 12),
              ],
              
              if (node['year'] != null) ...[
                _buildDetailRow(Icons.calendar_today, 'Year', node['year'].toString()),
                SizedBox(height: 12),
              ],
              
              if (node['keywords'] != null) ...[
                _buildDetailRow(Icons.label, 'Keywords', node['keywords'].toString()),
                SizedBox(height: 12),
              ],
              
              if (node['abstract'] != null) ...[
                SizedBox(height: 8),
                Text('Abstract', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 8),
                Text(
                  node['abstract'],
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
