import 'package:flutter/material.dart';
import '../../models/feedback_model.dart';
import '../../services/feedback_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_formatter.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  int? _selectedStarFilter;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'General Experience',
    'Feature Suggestion',
    'Bug Report / Issue',
    'QR / Attendance',
    'Event Registration',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Student App Feedback',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.textMain,
        centerTitle: true,
      ),
      body: StreamBuilder<List<FeedbackModel>>(
        stream: FeedbackService.streamAllFeedback(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.sageDark),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.pinkDark,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Error loading feedback: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.pinkDark),
                    ),
                  ],
                ),
              ),
            );
          }

          final allFeedback = snapshot.data ?? [];
          final filtered = allFeedback.where((f) {
            if (_selectedStarFilter != null &&
                f.rating != _selectedStarFilter) {
              return false;
            }
            if (_selectedCategory != 'All' &&
                f.category != _selectedCategory) {
              return false;
            }
            return true;
          }).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: CustomScrollView(
                slivers: [
                  // Analytics Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAnalyticsCard(allFeedback),
                          const SizedBox(height: 16),
                          _buildFilters(allFeedback),
                        ],
                      ),
                    ),
                  ),

                  // Feedback List
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: AppColors.lavenderLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.rate_review_outlined,
                                size: 48,
                                color: AppColors.lavenderDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              allFeedback.isEmpty
                                  ? 'No feedback submitted yet.'
                                  : 'No feedback matches the selected filters.',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textMain,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Student reviews will appear here in real-time.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildFeedbackCard(filtered[index]),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsCard(List<FeedbackModel> list) {
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No feedback data collected yet.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final total = list.length;
    final avgRating = list.map((e) => e.rating).reduce((a, b) => a + b) / total;

    final counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (var f in list) {
      counts[f.rating] = (counts[f.rating] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.sageLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sentiment_satisfied_alt_outlined,
                  color: AppColors.sageDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Student Sentiment Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Average Score Box
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sageLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primarySage),
                ),
                child: Column(
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sageDark,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < avgRating.round()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: const Color(0xFFE5A83B),
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$total ${total == 1 ? 'Review' : 'Reviews'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.sageDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Rating Breakdown Bars
              Expanded(
                child: Column(
                  children: [5, 4, 3, 2, 1].map((stars) {
                    final count = counts[stars] ?? 0;
                    final ratio = total > 0 ? count / total : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            '$stars',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                            ),
                          ),
                          const Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: Color(0xFFE5A83B),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: AppColors.background,
                                valueColor: AlwaysStoppedAnimation(
                                  _getColorForRating(stars),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 24,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(List<FeedbackModel> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Star filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('All Stars'),
                selected: _selectedStarFilter == null,
                selectedColor: AppColors.sageLight,
                checkmarkColor: AppColors.sageDark,
                labelStyle: TextStyle(
                  color: _selectedStarFilter == null ? AppColors.sageDark : AppColors.textMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                backgroundColor: AppColors.cardWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _selectedStarFilter == null ? AppColors.primarySage : AppColors.border,
                  ),
                ),
                onSelected: (selected) {
                  setState(() => _selectedStarFilter = null);
                },
              ),
              const SizedBox(width: 8),
              ...[5, 4, 3, 2, 1].map((stars) {
                final isSelected = _selectedStarFilter == stars;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$stars '),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFE5A83B),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.sageLight,
                    checkmarkColor: AppColors.sageDark,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.sageDark : AppColors.textMain,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    backgroundColor: AppColors.cardWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? AppColors.primarySage : AppColors.border,
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedStarFilter = selected ? stars : null;
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Category filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AppColors.lavenderDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.lavenderLight,
                  backgroundColor: AppColors.cardWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.pastelLavender
                          : AppColors.border,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackCard(FeedbackModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showFeedbackDetailsModal(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.lavenderLight,
                      radius: 20,
                      child: Text(
                        item.studentName.isNotEmpty
                            ? item.studentName[0].toUpperCase()
                            : 'S',
                        style: const TextStyle(
                          color: AppColors.lavenderDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textMain,
                            ),
                          ),
                          if (item.rollNumber.isNotEmpty ||
                              item.department.isNotEmpty)
                            Text(
                              [item.rollNumber, item.department]
                                  .where((s) => s.isNotEmpty)
                                  .join(' • '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          if (item.studentEmail.isNotEmpty)
                            Text(
                              item.studentEmail,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < item.rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: const Color(0xFFE5A83B),
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormatter.formatDate(item.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lavenderLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lavenderDark,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.sageDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: AppColors.sageDark,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMain,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFeedbackDetailsModal(FeedbackModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.lavenderLight,
                radius: 18,
                child: Text(
                  item.studentName.isNotEmpty
                      ? item.studentName[0].toUpperCase()
                      : 'S',
                  style: const TextStyle(
                    color: AppColors.lavenderDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.studentName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                    if (item.studentEmail.isNotEmpty)
                      Text(
                        item.studentEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Star Rating & Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < item.rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: const Color(0xFFE5A83B),
                          size: 20,
                        ),
                      ),
                    ),
                    Text(
                      DateFormatter.formatDate(item.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Student metadata tags
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lavenderLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Category: ${item.category}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lavenderDark,
                        ),
                      ),
                    ),
                    if (item.rollNumber.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Roll: ${item.rollNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                    if (item.department.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Dept: ${item.department}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text(
                  'Feedback Message',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SelectableText(
                    item.message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMain,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close', style: TextStyle(color: AppColors.sageDark, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Color _getColorForRating(int rating) {
    switch (rating) {
      case 5:
        return AppColors.sageDark;
      case 4:
        return AppColors.skyBlueDark;
      case 3:
        return AppColors.peachDark;
      case 2:
        return AppColors.pinkDark;
      case 1:
        return AppColors.pinkDark;
      default:
        return AppColors.lavenderDark;
    }
  }
}
