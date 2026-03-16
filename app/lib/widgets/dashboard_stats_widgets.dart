import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// ✅ WIDGET: Biểu đồ phân bố chủ đề (Topic Distribution Pie Chart)
class TopicDistributionChart extends StatelessWidget {
  final List<dynamic> topicDistribution;

  const TopicDistributionChart({
    super.key,
    required this.topicDistribution,
  });

  // Helper to safely convert to int
  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (topicDistribution.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No topic data yet.\nAdd tags to your documents to see distribution.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    // Calculate total count for percentage
    final totalCount = topicDistribution.fold<int>(
      0,
      (sum, item) => sum + _toInt(item['count']),
    );

    // Generate colors for pie chart
    final colors = [
      Color(0xFF2D60FF),
      Color(0xFF9D59FF),
      Color(0xFF6889FF),
      Colors.amber,
      Colors.teal,
      Colors.pink,
      Colors.orange,
      Colors.green,
      Colors.cyan,
      Colors.purple,
    ];

    return Column(
      children: [
        // Pie Chart
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              sections: topicDistribution.asMap().entries.map((entry) {
                final index = entry.key;
                final topic = entry.value;
                final count = _toInt(topic['count']);
                final percentage = (count / totalCount) * 100;

                return PieChartSectionData(
                  color: colors[index % colors.length],
                  value: count.toDouble(),
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: 40,
                  titleStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        
        SizedBox(height: 20),
        
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: topicDistribution.asMap().entries.map((entry) {
            final index = entry.key;
            final topic = entry.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  '${topic['topic']} (${topic['count']})',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// ✅ WIDGET: Storage Progress Bar với cảnh báo
class StorageProgressBar extends StatelessWidget {
  final int usedBytes;
  final int totalBytes;
  final double usagePercent;

  const StorageProgressBar({
    super.key,
    required this.usedBytes,
    required this.totalBytes,
    required this.usagePercent,
  });

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }
    return '${dBytes.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Color _getProgressColor() {
    if (usagePercent >= 90) return Colors.red;
    if (usagePercent >= 80) return Colors.orange;
    return Color(0xFF2D60FF);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Storage Usage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${usagePercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getProgressColor(),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '${_formatBytes(usedBytes)} of ${_formatBytes(totalBytes)} used',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: (usagePercent / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.grey[200],
            color: _getProgressColor(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          if (usagePercent >= 80) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      usagePercent >= 90
                          ? 'Storage almost full! Consider removing unused files.'
                          : 'Storage usage is high. ${_formatBytes(totalBytes - usedBytes)} remaining.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ✅ WIDGET: Total Articles Card
class TotalArticlesCard extends StatelessWidget {
  final int totalArticles;

  const TotalArticlesCard({
    super.key,
    required this.totalArticles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF9D59FF), Color(0xFF6889FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6889FF).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.library_books,
              color: Colors.white,
              size: 32,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Articles',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$totalArticles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'documents in library',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
