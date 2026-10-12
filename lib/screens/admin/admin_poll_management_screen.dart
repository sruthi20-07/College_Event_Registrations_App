import 'package:flutter/material.dart';

import '../../models/poll_model.dart';
import '../../services/auth_service.dart';
import '../../services/poll_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_formatter.dart';

class AdminPollManagementScreen extends StatefulWidget {
  const AdminPollManagementScreen({super.key});

  @override
  State<AdminPollManagementScreen> createState() =>
      _AdminPollManagementScreenState();
}

class _AdminPollManagementScreenState extends State<AdminPollManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PollService _pollService = PollService();
  final AuthService _authService = AuthService();

  String? _selectedAnalyticsPollId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentAdminUid => _authService.currentUid ?? 'admin';

  Color _getStatusColor(String status) {
    switch (status) {
      case PollStatuses.active:
        return AppColors.mintDark;
      case PollStatuses.scheduled:
        return AppColors.skyBlueDark;
      case PollStatuses.draft:
        return AppColors.lavenderDark;
      case PollStatuses.closed:
        return AppColors.coralDark;
      case PollStatuses.archived:
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getStatusBg(String status) {
    switch (status) {
      case PollStatuses.active:
        return AppColors.mintLight;
      case PollStatuses.scheduled:
        return AppColors.skyBlueLight;
      case PollStatuses.draft:
        return AppColors.lavenderLight;
      case PollStatuses.closed:
        return AppColors.coralLight;
      case PollStatuses.archived:
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case PollCategories.workshops:
        return Icons.code_rounded;
      case PollCategories.hackathons:
        return Icons.terminal_rounded;
      case PollCategories.clubs:
        return Icons.groups_rounded;
      case PollCategories.festivals:
        return Icons.celebration_rounded;
      case PollCategories.career:
        return Icons.work_outline_rounded;
      case PollCategories.facilities:
        return Icons.apartment_rounded;
      default:
        return Icons.poll_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Daily Campus Poll Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _showCreateOrEditPollDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'New Poll',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.coral,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.coral,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.play_circle_outline, size: 18),
              text: 'Active & Scheduled',
            ),
            Tab(
              icon: Icon(Icons.history_toggle_off, size: 18),
              text: 'Drafts & History',
            ),
            Tab(
              icon: Icon(Icons.insights_rounded, size: 18),
              text: 'Decision Analytics',
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<CampusPollModel>>(
        stream: _pollService.streamAllPollsAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.coral),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading polls: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.coralDark),
                ),
              ),
            );
          }

          final polls = snapshot.data ?? [];

          final activeAndScheduled = polls.where((p) {
            return p.status == PollStatuses.active ||
                p.status == PollStatuses.scheduled;
          }).toList();

          final draftsAndHistory = polls.where((p) {
            return p.status == PollStatuses.draft ||
                p.status == PollStatuses.closed ||
                p.status == PollStatuses.archived;
          }).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildPollListTab(
                polls: activeAndScheduled,
                emptyTitle: 'No Active Polls',
                emptySubtitle:
                    'Create and publish a daily campus poll to engage students and gather interest data.',
                isActiveTab: true,
              ),
              _buildPollListTab(
                polls: draftsAndHistory,
                emptyTitle: 'No Drafts or Past Polls',
                emptySubtitle:
                    'Drafts, closed, and archived campus polls will appear here.',
                isActiveTab: false,
              ),
              _buildAnalyticsTab(polls),
            ],
          );
        },
      ),
    );
  }

  // ========================================================
  // 1. POLL LIST TAB (ACTIVE OR DRAFTS/HISTORY)
  // ========================================================
  Widget _buildPollListTab({
    required List<CampusPollModel> polls,
    required String emptyTitle,
    required String emptySubtitle,
    required bool isActiveTab,
  }) {
    if (polls.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppColors.lavenderLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.poll_outlined,
                  size: 40,
                  color: AppColors.lavenderDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  emptySubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showCreateOrEditPollDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Create Campus Poll',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: polls.length,
      itemBuilder: (context, index) {
        final poll = polls[index];
        return _buildPollAdminCard(poll);
      },
    );
  }

  // ========================================================
  // POLL ADMIN CARD
  // ========================================================
  Widget _buildPollAdminCard(CampusPollModel poll) {
    final statusColor = _getStatusColor(poll.status);
    final statusBg = _getStatusBg(poll.status);
    final popular = poll.mostPopularOption;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Category, Status badge & Total Voters
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getCategoryIcon(poll.category),
                        size: 14,
                        color: AppColors.lavenderDark,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        poll.category,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.lavenderDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    poll.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_alt_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${poll.totalVotes} votes',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Question Text
            Text(
              poll.question,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 8),

            // Timestamps info
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Created: ${DateFormatter.formatFullDateTime(poll.createdAt)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (poll.endDate != null) ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.timer_outlined,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Ends: ${DateFormatter.formatFullDateTime(poll.endDate!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 14),

            // Options & Percentage Results
            Column(
              children: poll.options.map((option) {
                final pct = poll.percentageForOption(option.id);
                final isTop = popular?.id == option.id && poll.totalVotes > 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isTop
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isTop
                            ? AppColors.mintDark.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  if (isTop) ...[
                                    const Icon(
                                      Icons.stars_rounded,
                                      size: 15,
                                      color: AppColors.mintDark,
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                  Flexible(
                                    child: Text(
                                      option.text,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isTop
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isTop
                                            ? AppColors.mintDark
                                            : AppColors.textMain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${option.voteCount} (${pct.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isTop
                                    ? AppColors.mintDark
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: poll.totalVotes > 0 ? (pct / 100.0) : 0.0,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isTop ? AppColors.mintDark : AppColors.coral,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 10),

            // Controls & Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Edit button (only if draft or has 0 votes, or metadata edit)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMain,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () =>
                      _showCreateOrEditPollDialog(context, pollToEdit: poll),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                ),

                // Publish Now (if draft or scheduled)
                if (poll.status == PollStatuses.draft ||
                    poll.status == PollStatuses.scheduled) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mintDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _publishPoll(poll),
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: const Text(
                      'Publish Now',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],

                // Close Poll (if active)
                if (poll.status == PollStatuses.active) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coralLight,
                      foregroundColor: AppColors.coralDark,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _confirmClosePoll(poll),
                    icon: const Icon(Icons.stop_circle_outlined, size: 14),
                    label: const Text(
                      'Close Poll',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],

                // Archive Poll (if closed)
                if (poll.status == PollStatuses.closed) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _archivePoll(poll),
                    icon: const Icon(Icons.archive_outlined, size: 14),
                    label: const Text(
                      'Archive',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],

                // Jump to Analytics
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.lavenderDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedAnalyticsPollId = poll.id;
                      _tabController.animateTo(2);
                    });
                  },
                  icon: const Icon(Icons.insights, size: 14),
                  label: const Text(
                    'View Analytics',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================
  // 3. DECISION-SUPPORT ANALYTICS TAB
  // ========================================================
  Widget _buildAnalyticsTab(List<CampusPollModel> polls) {
    if (polls.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No poll analytics available yet.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final selectedPoll = polls.firstWhere(
      (p) => p.id == _selectedAnalyticsPollId,
      orElse: () => polls.first,
    );

    final totalVotesSum = polls.fold<int>(0, (sum, p) => sum + p.totalVotes);
    final activePollsCount = polls
        .where((p) => p.status == PollStatuses.active)
        .length;
    final popular = selectedPoll.mostPopularOption;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decision Support Disclaimer Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppColors.skyBlueDark,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Student Preference Data for Campus Planning',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'These analytics reflect authentic student interest to help organizers curate high-impact technical workshops, hackathons, guest lectures, and campus facility upgrades.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E40AF),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Overview KPI Row
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Votes',
                  '$totalVotesSum',
                  Icons.how_to_vote_outlined,
                  AppColors.mintLight,
                  AppColors.mintDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Active Polls',
                  '$activePollsCount',
                  Icons.poll_outlined,
                  AppColors.skyBlueLight,
                  AppColors.skyBlueDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Total Polls',
                  '${polls.length}',
                  Icons.analytics_outlined,
                  AppColors.lavenderLight,
                  AppColors.lavenderDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Selector Dropdown for Detailed Inspection
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Text(
                  'Select Poll: ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedPoll.id,
                      isExpanded: true,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMain,
                        fontWeight: FontWeight.w600,
                      ),
                      items: polls.map((p) {
                        return DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(
                            '[${p.status.toUpperCase()}] ${p.question}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null) {
                          setState(() => _selectedAnalyticsPollId = newId);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Detailed Selected Poll Analytics Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusBg(selectedPoll.status),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        selectedPoll.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(selectedPoll.status),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Category: ${selectedPoll.category}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${selectedPoll.totalVotes} Total Unique Voters',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.coralDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  selectedPoll.question,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Created: ${DateFormatter.formatFullDateTime(selectedPoll.createdAt)} • Admin: ${selectedPoll.createdBy}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Divider(height: 24, color: AppColors.border),

                // Leading Preference Highlight
                if (popular != null && selectedPoll.totalVotes > 0) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: AppColors.mintDark,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Most Popular Student Choice',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF166534),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${popular.text} (${popular.voteCount} votes, ${selectedPoll.percentageForOption(popular.id).toStringAsFixed(1)}%)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.mintDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Full Breakdown Table
                const Text(
                  'Full Option Distribution',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 10),

                ...selectedPoll.options.map((opt) {
                  final pct = selectedPoll.percentageForOption(opt.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                opt.text,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMain,
                                ),
                              ),
                            ),
                            Text(
                              '${opt.voteCount} votes • ${pct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.coralDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: selectedPoll.totalVotes > 0
                                ? (pct / 100.0)
                                : 0.0,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.coral,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 14),

                // Settings Breakdown
                Row(
                  children: [
                    _buildTag(
                      'Vote Editing: ${selectedPoll.allowVoteEditing ? "Allowed" : "Disabled"}',
                      selectedPoll.allowVoteEditing
                          ? AppColors.mintLight
                          : AppColors.coralLight,
                      selectedPoll.allowVoteEditing
                          ? AppColors.mintDark
                          : AppColors.coralDark,
                    ),
                    const SizedBox(width: 8),
                    _buildTag(
                      'Pre-vote Results: ${selectedPoll.resultsVisibleBeforeVote ? "Visible" : "Hidden"}',
                      AppColors.lavenderLight,
                      AppColors.lavenderDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textCol,
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color bg,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================
  // ACTIONS: PUBLISH, CLOSE, ARCHIVE
  // ========================================================
  Future<void> _publishPoll(CampusPollModel poll) async {
    try {
      await _pollService.publishPoll(poll.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poll published! It is now active for all students.'),
            backgroundColor: AppColors.mintDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish poll: $e'),
            backgroundColor: AppColors.coralDark,
          ),
        );
      }
    }
  }

  Future<void> _confirmClosePoll(CampusPollModel poll) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Close Daily Poll?'),
        content: Text(
          'Students will no longer be able to submit or edit votes for "${poll.question}". All votes and results will be permanently preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close Poll'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _pollService.closePoll(poll.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Poll closed successfully.'),
              backgroundColor: AppColors.mintDark,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to close poll: $e'),
              backgroundColor: AppColors.coralDark,
            ),
          );
        }
      }
    }
  }

  Future<void> _archivePoll(CampusPollModel poll) async {
    try {
      await _pollService.archivePoll(poll.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poll moved to archive.'),
            backgroundColor: AppColors.lavenderDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to archive: $e'),
            backgroundColor: AppColors.coralDark,
          ),
        );
      }
    }
  }

  // ========================================================
  // CREATE / EDIT POLL DIALOG
  // ========================================================
  void _showCreateOrEditPollDialog(
    BuildContext context, {
    CampusPollModel? pollToEdit,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _PollFormDialog(
        pollToEdit: pollToEdit,
        adminUid: _currentAdminUid,
        pollService: _pollService,
      ),
    );
  }
}

// ========================================================
// STATEFUL FORM DIALOG FOR CREATING / EDITING A POLL
// ========================================================
class _PollFormDialog extends StatefulWidget {
  final CampusPollModel? pollToEdit;
  final String adminUid;
  final PollService pollService;

  const _PollFormDialog({
    this.pollToEdit,
    required this.adminUid,
    required this.pollService,
  });

  @override
  State<_PollFormDialog> createState() => _PollFormDialogState();
}

class _PollFormDialogState extends State<_PollFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _questionCtrl;
  late String _category;
  late List<TextEditingController> _optionCtrls;
  late bool _allowVoteEditing;
  late bool _resultsVisibleBeforeVote;
  late String _status;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;

  bool get _isEditing => widget.pollToEdit != null;
  bool get _hasExistingVotes =>
      (_isEditing && widget.pollToEdit!.totalVotes > 0);

  @override
  void initState() {
    super.initState();
    final p = widget.pollToEdit;
    _questionCtrl = TextEditingController(text: p?.question ?? '');
    _category = p?.category ?? PollCategories.workshops;
    _allowVoteEditing = p?.allowVoteEditing ?? true;
    _resultsVisibleBeforeVote = p?.resultsVisibleBeforeVote ?? false;
    _status = p?.status ?? PollStatuses.active;
    _startDate = p?.startDate ?? DateTime.now();
    _endDate = p?.endDate ?? DateTime.now().add(const Duration(days: 1));

    if (p != null && p.options.isNotEmpty) {
      _optionCtrls = p.options
          .map((o) => TextEditingController(text: o.text))
          .toList();
    } else {
      _optionCtrls = [
        TextEditingController(text: ''),
        TextEditingController(text: ''),
      ];
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_hasExistingVotes) return;
    if (_optionCtrls.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A maximum of 6 options is supported for poll readability.',
          ),
          backgroundColor: AppColors.coralDark,
        ),
      );
      return;
    }
    setState(() {
      _optionCtrls.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_hasExistingVotes) return;
    if (_optionCtrls.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least 2 options are required for a valid poll.'),
          backgroundColor: AppColors.coralDark,
        ),
      );
      return;
    }
    setState(() {
      _optionCtrls.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate options
    final cleanedOptions = _optionCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (cleanedOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide at least 2 non-empty answer options.'),
          backgroundColor: AppColors.coralDark,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        final existing = widget.pollToEdit!;
        // Build updated options preserving vote count if editing is allowed
        List<PollOptionModel> updatedOptions;
        if (_hasExistingVotes) {
          // Keep existing options and vote counts intact to prevent vote corruption
          updatedOptions = existing.options;
        } else {
          updatedOptions = cleanedOptions.asMap().entries.map((entry) {
            final idx = entry.key;
            final text = entry.value;
            final id = idx < existing.options.length
                ? existing.options[idx].id
                : 'opt_${idx + 1}';
            return PollOptionModel(
              id: id,
              text: text,
              voteCount: idx < existing.options.length
                  ? existing.options[idx].voteCount
                  : 0,
            );
          }).toList();
        }

        final updatedPoll = existing.copyWith(
          question: _questionCtrl.text.trim(),
          category: _category,
          options: updatedOptions,
          status: _status,
          startDate: _startDate,
          endDate: _endDate,
          allowVoteEditing: _allowVoteEditing,
          resultsVisibleBeforeVote: _resultsVisibleBeforeVote,
        );

        await widget.pollService.updatePoll(updatedPoll);
      } else {
        // Create new poll
        final newOptions = cleanedOptions.asMap().entries.map((entry) {
          return PollOptionModel(
            id: 'opt_${entry.key + 1}',
            text: entry.value,
            voteCount: 0,
          );
        }).toList();

        final newPoll = CampusPollModel(
          id: '',
          question: _questionCtrl.text.trim(),
          category: _category,
          options: newOptions,
          status: _status,
          startDate: _startDate,
          endDate: _endDate,
          allowVoteEditing: _allowVoteEditing,
          resultsVisibleBeforeVote: _resultsVisibleBeforeVote,
          createdBy: widget.adminUid,
          createdAt: DateTime.now(),
        );

        await widget.pollService.createPoll(newPoll);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Poll updated successfully.'
                  : 'New poll created successfully.',
            ),
            backgroundColor: AppColors.mintDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save poll: $e'),
            backgroundColor: AppColors.coralDark,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.coralLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.poll_rounded,
                        color: AppColors.coralDark,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isEditing
                            ? 'Edit Campus Poll'
                            : 'Create New Daily Poll',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const Divider(height: 20, color: AppColors.border),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Safe versioning notice if votes already exist
                        if (_hasExistingVotes) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.lock_clock,
                                  color: Color(0xFFD97706),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${widget.pollToEdit!.totalVotes} votes already recorded. Options are locked to preserve voter integrity. You may still adjust question title, deadline, and editing permissions.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Category Dropdown
                        const Text(
                          'Poll Topic & Category',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: PollCategories.all.map((c) {
                            return DropdownMenuItem<String>(
                              value: c,
                              child: Text(c),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _category = val);
                          },
                        ),

                        const SizedBox(height: 14),

                        // Question Field
                        const Text(
                          'Question Title',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _questionCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText:
                                'e.g. Which hands-on workshop would you like to see next?',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a question.';
                            }
                            if (val.trim().length < 8) {
                              return 'Question must be at least 8 characters long.';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Answer Options
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Answer Options (Minimum 2)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain,
                              ),
                            ),
                            if (!_hasExistingVotes)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.coral,
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _addOption,
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Add Option',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        ..._optionCtrls.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final ctrl = entry.value;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppColors.lavenderLight,
                                  child: Text(
                                    '${idx + 1}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.lavenderDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: ctrl,
                                    enabled: !_hasExistingVotes,
                                    decoration: InputDecoration(
                                      hintText: 'Option ${idx + 1}',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Option text cannot be empty';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                if (!_hasExistingVotes &&
                                    _optionCtrls.length > 2) ...[
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: AppColors.coralDark,
                                      size: 18,
                                    ),
                                    onPressed: () => _removeOption(idx),
                                    tooltip: 'Remove option',
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 14),

                        // Poll Status Selector
                        const Text(
                          'Initial Status',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: PollStatuses.active,
                              child: Text('Active (Live for Voting)'),
                            ),
                            DropdownMenuItem(
                              value: PollStatuses.draft,
                              child: Text('Draft (Saved privately)'),
                            ),
                            DropdownMenuItem(
                              value: PollStatuses.scheduled,
                              child: Text('Scheduled'),
                            ),
                            DropdownMenuItem(
                              value: PollStatuses.closed,
                              child: Text('Closed'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _status = val);
                          },
                        ),

                        const SizedBox(height: 14),

                        // Settings Toggles
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Allow students to edit vote',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'Allows correcting vote while poll is active without duplicate counts',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          value: _allowVoteEditing,
                          activeThumbColor: AppColors.coral,
                          onChanged: (v) =>
                              setState(() => _allowVoteEditing = v),
                        ),

                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Show results before voting',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'When off, percentages reveal only after student casts their vote',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          value: _resultsVisibleBeforeVote,
                          activeThumbColor: AppColors.coral,
                          onChanged: (v) =>
                              setState(() => _resultsVisibleBeforeVote = v),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 20, color: AppColors.border),

                // Footer Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isSaving ? null : _submitForm,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditing ? 'Save Changes' : 'Create Poll',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
