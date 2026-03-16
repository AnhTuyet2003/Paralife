import 'package:app/screens/files_screen.dart';
import 'package:app/screens/cloud_screen.dart';
import 'package:flutter/material.dart';
import 'package:app/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/dashboard_provider.dart';
import 'package:app/main.dart'; 
import 'package:app/screens/chat_hub_screen.dart';
import 'package:app/services/share_intent_handler.dart';
import 'package:app/widgets/dashboard_stats_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  late final List<Widget> _tabs = [
    DashboardTab(key: ValueKey('dashboard')),
    FilesScreen(key: ValueKey('files')),
    CloudScreen(key: ValueKey('cloud')),
    ChatHubScreen(key: ValueKey('chatbox')),
    SettingsScreen(key: ValueKey('settings')), 
  ];

  @override
  void initState() {
    super.initState();
    // ✅ RE-ENABLED ShareIntent với delay để đảm bảo context ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Delay 500ms để đảm bảo navigation stack đã build xong
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            ShareIntentHandler.initialize();
            ShareIntentHandler.startListening(context);
            debugPrint('✅ ShareIntentHandler initialized in HomeScreen');
          }
        });
      }
    });
  }

  @override
  void dispose() {
    ShareIntentHandler.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 

      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs, 
        ),
      ),

      floatingActionButton: Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF9D59FF), Color(0xFF6889FF)], 
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 10, offset: Offset(0, 4))
          ]
        ),
        child: FloatingActionButton(
          heroTag: "btn_home_action",
          onPressed: () {
            setState(() => _currentIndex = 3);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Icon(Icons.auto_awesome, color: Colors.white, size: 30), 
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed, 
        selectedItemColor: Color(0xFF2D60FF), 
        unselectedItemColor: Colors.grey, 
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.folder_open), label: "Files"),
          BottomNavigationBarItem(icon: Icon(Icons.cloud_queue), label: "Cloud"),
          BottomNavigationBarItem(icon: Icon(Icons.star_outline), label: "Chatbox"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Settings"),
        ],
      ),
    );
  }
}

// --- WIDGET CON: NỘI DUNG DASHBOARD  ---
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> with RouteAware {
  bool _hasInitialized = false; // FLAG MỚI: Ngăn initialize nhiều lần

  @override
  void initState() {
    super.initState();
    
    if (!_hasInitialized) {
      _hasInitialized = true;
      
      // SỬA: Không block UI thread
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Load dữ liệu ngay lập tức, không delay
          _initializeDashboard();
        }
      });
    }
  }

  // THÊM: Method riêng để initialize
  Future<void> _initializeDashboard() async {
    if (!mounted) return;
    
    try {
      final provider = context.read<DashboardProvider>();
      await Future.wait([
        provider.fetchDashboard(),
        provider.fetchStats(),  // ✅ NEW: Fetch stats for charts
      ]);
      
      if (mounted) {
        provider.startAutoRefresh();
      }
    } catch (e) {
      debugPrint('❌ Error initializing dashboard: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        routeObserver.subscribe(this, route);
      }
    } catch (e) {
      throw Exception('❌ RouteObserver subscribe error: $e');
    }
  }

  @override
  void didPopNext() {
    if (mounted) {
      try {
        context.read<DashboardProvider>().fetchDashboard(showLoading: false);
      } catch (e) {
        throw Exception('❌ Error in didPopNext: $e');
      }
    }
  }

  @override
  void dispose() {    
    // SỬA: Unsubscribe RouteObserver TRƯỚC
    try {
      routeObserver.unsubscribe(this);
    } catch (e) {
      throw Exception('❌ RouteObserver unsubscribe error: $e');
    }
    
    // SAU ĐÓ: Stop auto-refresh (KHÔNG dùng context.read)
    // Vì widget đã bị deactivate, ta không thể gọi Provider
    // Thay vào đó, Provider sẽ tự dispose khi app đóng
    
    super.dispose();
  }

  // Helper to safely convert to int
  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Helper to safely convert to double
  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }
    return '${dBytes.toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _navigateToSeeAll(String type, List<dynamic> items) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeeAllItemsScreen(
          title: type == 'favorites' ? 'Favorites' : 'Recent Files',
          items: items,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        // Loading state - HIỂN THỊ TRƯỚC
        if (provider.isLoading && provider.dashboardData == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Loading dashboard...', 
                  style: TextStyle(color: Colors.grey, fontSize: 16)
                ),
              ],
            ),
          );
        }

        // Error state - SAU ĐÓ MỚI CHECK ERROR
        if (provider.error != null && provider.dashboardData == null) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load dashboard',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    provider.error ?? 'Unknown error',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      provider.fetchDashboard();
                    },
                    icon: Icon(Icons.refresh),
                    label: Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2D60FF),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // DATA LOADED - HIỂN THỊ UI
        final data = provider.dashboardData;
        if (data == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
                SizedBox(height: 16),
                Text('No data available', style: TextStyle(color: Colors.grey, fontSize: 16)),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.fetchDashboard(),
                  child: Text('Load Dashboard'),
                ),
              ],
            ),
          );
        }

        final favorites = List<Map<String, dynamic>>.from(data['favorites'] ?? []);
        final recents = List<Map<String, dynamic>>.from(data['recents'] ?? []);

        return RefreshIndicator(
          onRefresh: () => provider.fetchDashboard(),
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[100], borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey),
                      SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Search folder or files",
                            hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 30),

                // ✅ NEW: Stats Section (từ API /api/dashboard/stats)
                if (provider.statsData != null) ...[
                  StorageProgressBar(
                    usedBytes: _toInt(provider.statsData!['used_bytes']),
                    totalBytes: _toInt(provider.statsData!['total_bytes']) == 0 ? 314572800 : _toInt(provider.statsData!['total_bytes']),
                    usagePercent: _toDouble(provider.statsData!['usage_percent']),
                  ),
                  SizedBox(height: 16),
                  
                  TotalArticlesCard(
                    totalArticles: _toInt(provider.statsData!['total_articles']),
                  ),
                  SizedBox(height: 30),
                  
                  // Topic Distribution Chart
                  if ((provider.statsData!['topic_distribution'] as List).isNotEmpty) ...[
                    Text(
                      "Research Topics Distribution",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    TopicDistributionChart(
                      topicDistribution: provider.statsData!['topic_distribution'] as List,
                    ),
                    SizedBox(height: 30),
                  ],
                ],
          
                // Favorites Section
                if (favorites.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Favorites", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () => _navigateToSeeAll('favorites', favorites),
                        child: Text("See All", style: TextStyle(color: Color(0xFF2D60FF))),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ...(favorites.take(3).map((item) => _buildListItem(item))),
                  SizedBox(height: 30),
                ],
          
                // Recent Files Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Recent Files", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (recents.isNotEmpty)
                      GestureDetector(
                        onTap: () => _navigateToSeeAll('recents', recents),
                        child: Text("See All", style: TextStyle(color: Color(0xFF2D60FF))),
                      ),
                  ],
                ),
                SizedBox(height: 16),
                
                if (recents.isEmpty)
                  Center(child: Text("No recent files", style: TextStyle(color: Colors.grey)))
                else
                  ...(recents.take(3).map((item) => _buildListItem(item))),
                  
                SizedBox(height: 80), 
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListItem(Map<String, dynamic> item) {
    bool isFolder = item['type'] == 'folder';
    bool isLinkRef = !isFolder && (item['size_bytes'] == 0 || item['size_bytes'] == null) && (item['file_url'] ?? "").contains("doi.org");

    IconData icon;
    Color iconColor;
    Color bgColor;

    if (isFolder) {
      icon = Icons.folder;
      iconColor = Colors.amber;
      bgColor = Colors.amber.withValues(alpha: 0.1);
    } else if (isLinkRef) {
      icon = Icons.link;
      iconColor = Colors.purple;
      bgColor = Colors.purple.withValues(alpha: 0.1);
    } else {
      icon = Icons.description;
      iconColor = Colors.blue;
      bgColor = Colors.blue.withValues(alpha: 0.1);
    }

    String infoText = "";
    if (isFolder) {
      infoText = "Folder";
    } else {
      var meta = item['metadata_info'] ?? item['metadata'];
      if (meta != null && meta['authors'] != null) {
        if (meta['authors'] is List && (meta['authors'] as List).isNotEmpty) {
          infoText = meta['authors'][0];
        } else if (meta['authors'] is String) {
          infoText = meta['authors'];
        }
      }
      if (infoText.isEmpty) infoText = "Unknown Author";

      if (!isLinkRef) {
        infoText += " • ${_formatBytes(_toInt(item['size_bytes']))}";
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? "No Name",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(infoText, style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}

// --- MÀNG HÌNH SEE ALL ---
class SeeAllItemsScreen extends StatelessWidget {
  final String title;
  final List<dynamic> items;

  const SeeAllItemsScreen({
    super.key,
    required this.title,
    required this.items,
  });

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }
    return '${dBytes.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
                  SizedBox(height: 16),
                  Text("No items yet", style: TextStyle(color: Colors.grey, fontSize: 18)),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _buildListItem(items[index], context);
              },
            ),
    );
  }

  Widget _buildListItem(Map<String, dynamic> item, BuildContext context) {
    bool isFolder = item['type'] == 'folder';
    bool isLinkRef = !isFolder && (item['size_bytes'] == 0 || item['size_bytes'] == null) && (item['file_url'] ?? "").contains("doi.org");

    IconData icon;
    Color iconColor;
    Color bgColor;

    if (isFolder) {
      icon = Icons.folder;
      iconColor = Colors.amber;
      bgColor = Colors.amber.withValues(alpha: 0.1);
    } else if (isLinkRef) {
      icon = Icons.link;
      iconColor = Colors.purple;
      bgColor = Colors.purple.withValues(alpha: 0.1);
    } else {
      icon = Icons.description;
      iconColor = Colors.blue;
      bgColor = Colors.blue.withValues(alpha: 0.1);
    }

    String infoText = "";
    if (isFolder) {
      infoText = "Folder";
    } else {
      var meta = item['metadata_info'] ?? item['metadata'];
      if (meta != null && meta['authors'] != null) {
        if (meta['authors'] is List && (meta['authors'] as List).isNotEmpty) {
          infoText = meta['authors'][0];
        } else if (meta['authors'] is String) {
          infoText = meta['authors'];
        }
      }
      if (infoText.isEmpty) infoText = "Unknown Author";

      if (!isLinkRef) {
        infoText += " • ${_formatBytes(_toInt(item['size_bytes']))}";
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? "No Name",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(infoText, style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}