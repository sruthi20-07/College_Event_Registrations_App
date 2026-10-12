import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/event_model.dart';
import '../../models/gamification_model.dart';
import '../../models/reward_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/gamification_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_formatter.dart';
import 'leaderboard_screen.dart';

class GamificationDashboardScreen extends StatefulWidget {
  final String? studentId;

  const GamificationDashboardScreen({super.key, this.studentId});

  @override
  State<GamificationDashboardScreen> createState() =>
      _GamificationDashboardScreenState();
}

class _GamificationDashboardScreenState
    extends State<GamificationDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GamificationService _gamificationService = GamificationService();
  final AuthService _authService = AuthService();
  final EventService _eventService = EventService();

  String get _activeStudentId =>
      widget.studentId ?? _authService.currentUid ?? '';

  String _selectedCategoryFilter = 'All';
  UserModel? _currentUser;

  final TextEditingController _referralCodeInputCtrl = TextEditingController();
  bool _isSubmittingReferral = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _referralCodeInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      if (_activeStudentId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_activeStudentId)
            .get();
        if (doc.exists) {
          _currentUser = UserModel.fromSnapshot(doc);
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    } finally {
      if (mounted) setState(() {});
    }
  }

  String _getRankTitle(int lifetimeCoins) {
    if (lifetimeCoins >= 500) return 'Diamond Legend';
    if (lifetimeCoins >= 250) return 'Gold Champion';
    if (lifetimeCoins >= 100) return 'Silver Pioneer';
    if (lifetimeCoins >= 50) return 'Bronze Scholar';
    return 'Campus Explorer';
  }

  IconData _getBadgeIcon(String badgeId) {
    switch (badgeId) {
      case 'first_step':
        return Icons.confirmation_number_outlined;
      case 'event_explorer':
        return Icons.explore_outlined;
      case 'campus_champion':
        return Icons.emoji_events_outlined;
      case 'consistency_star':
        return Icons.local_fire_department_outlined;
      case 'elite_participant':
        return Icons.diamond_outlined;
      default:
        return Icons.star_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case RedemptionStatuses.approved:
        return AppColors.lavenderDark;
      case RedemptionStatuses.fulfilled:
        return AppColors.mintDark;
      case RedemptionStatuses.pending:
        return AppColors.coralDark;
      case RedemptionStatuses.rejected:
      case RedemptionStatuses.cancelled:
        return AppColors.pinkDark;
      case RedemptionStatuses.refunded:
        return AppColors.skyBlueDark;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getStatusBg(String status) {
    switch (status) {
      case RedemptionStatuses.approved:
        return AppColors.lavenderLight;
      case RedemptionStatuses.fulfilled:
        return AppColors.mintLight;
      case RedemptionStatuses.pending:
        return AppColors.coralLight;
      case RedemptionStatuses.rejected:
      case RedemptionStatuses.cancelled:
        return AppColors.pinkLight;
      case RedemptionStatuses.refunded:
        return AppColors.skyBlueLight;
      default:
        return AppColors.background;
    }
  }

  void _showBadgeDetailsModal(
    BuildContext context,
    BadgeDefinition badge,
    bool isUnlocked,
    DateTime? unlockedAt,
    double progress,
    String progressText,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: isUnlocked ? AppColors.coralLight : AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isUnlocked ? AppColors.coral : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getBadgeIcon(badge.id),
                    size: 36,
                    color: isUnlocked ? AppColors.coralDark : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                badge.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isUnlocked ? AppColors.mintLight : AppColors.lavenderLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUnlocked ? AppColors.mint : AppColors.lavender,
                  ),
                ),
                child: Text(
                  isUnlocked
                      ? 'UNLOCKED'
                      : 'IN PROGRESS (${(progress * 100).toInt()}%)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? AppColors.mintDark : AppColors.lavenderDark,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                badge.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Requirement',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        Text(
                          badge.isStreakBadge
                              ? '${badge.requiredStreakDays} consecutive days streak'
                              : '${badge.requiredEvents} distinct verified events',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textMain,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18, color: AppColors.border),
                    if (isUnlocked && unlockedAt != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Unlocked Date',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          Text(
                            DateFormatter.formatFullDateTime(unlockedAt),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.mintDark,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Current Progress',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                progressText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.coral,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.coral,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Campus Rewards Centre',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined, color: AppColors.textMain),
            tooltip: 'Campus Leaderboard',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppColors.textMain),
            tooltip: 'Ways to Earn',
            onPressed: () => _showWaysToEarnDialog(),
          ),
        ],
      ),
      body: StreamBuilder<GamificationModel?>(
        stream: _gamificationService.streamGamification(_activeStudentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.coral),
            );
          }

          final gamification = snapshot.data ??
              GamificationModel(
                studentId: _activeStudentId,
                coins: 0,
                lifetimeCoins: 0,
                totalEventsAttended: 0,
                currentStreak: 0,
                longestStreak: 0,
                unlockedBadges: {},
              );

          final int spendableCoins = gamification.coins;
          final int lifetimeCoins = gamification.lifetimeCoins;

          return Column(
            children: [
              // 1. TOP HERO CARD
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: _buildHeroBalanceCard(spendableCoins, lifetimeCoins, gamification),
              ),

              // 2. TAB BAR
              Container(
                color: AppColors.background,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.coralDark,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.coral,
                  indicatorWeight: 3,
                  isScrollable: true,
                  tabs: const [
                    Tab(icon: Icon(Icons.card_giftcard, size: 20), text: 'Rewards'),
                    Tab(icon: Icon(Icons.receipt_long_outlined, size: 20), text: 'My Redemptions'),
                    Tab(icon: Icon(Icons.military_tech_outlined, size: 20), text: 'Badges & Streaks'),
                    Tab(icon: Icon(Icons.history, size: 20), text: 'Coin Ledger'),
                    Tab(icon: Icon(Icons.group_outlined, size: 20), text: 'Referrals'),
                  ],
                ),
              ),

              // 3. TAB VIEWS
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRewardsCatalogueTab(gamification),
                    _buildMyRedemptionsTab(),
                    _buildBadgesAndStreaksTab(gamification),
                    _buildCoinLedgerTab(),
                    _buildReferralsTab(gamification),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ========================================================
  // HERO BALANCE CARD
  // ========================================================
  Widget _buildHeroBalanceCard(
    int spendableCoins,
    int lifetimeCoins,
    GamificationModel gamification,
  ) {
    final rankTitle = _getRankTitle(lifetimeCoins);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFEDE6), Color(0xFFEDE9FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium, size: 14, color: AppColors.coral),
                    const SizedBox(width: 4),
                    Text(
                      rankTitle,
                      style: const TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.lavender.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.leaderboard, size: 13, color: AppColors.lavenderDark),
                      SizedBox(width: 4),
                      Text(
                        'Leaderboard',
                        style: TextStyle(
                          color: AppColors.lavenderDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$spendableCoins',
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: AppColors.coralDark,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'SPENDABLE COINS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$lifetimeCoins pts',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lavenderDark,
                    ),
                  ),
                  const Text(
                    'Lifetime Points',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.mintLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, size: 12, color: AppColors.coral),
                    const SizedBox(width: 3),
                    Text(
                      '${gamification.currentStreak} Day Streak',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.coralDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${gamification.totalEventsAttended} Events Attended',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========================================================
  // TAB 0: REWARDS CATALOGUE
  // ========================================================
  Widget _buildRewardsCatalogueTab(GamificationModel gamification) {
    return Column(
      children: [
        // CATEGORY FILTER CHIPS
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              'All',
              RewardCategories.freeEvent,
              RewardCategories.certificate,
              RewardCategories.collegePerk,
            ].map((cat) {
              final isSelected = _selectedCategoryFilter == cat;
              final label = cat == 'All' ? 'All Rewards' : RewardCategories.getLabel(cat);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.coral,
                  backgroundColor: AppColors.cardWhite,
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategoryFilter = cat);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // REWARDS CATALOGUE STREAM
        Expanded(
          child: StreamBuilder<List<RewardModel>>(
            stream: _gamificationService.streamActiveRewards(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.coral),
                );
              }

              final allRewards = snapshot.data ?? [];
              final filtered = _selectedCategoryFilter == 'All'
                  ? allRewards
                  : allRewards.where((r) => r.category == _selectedCategoryFilter).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.card_giftcard, size: 44, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        const Text(
                          'No Rewards Currently Available',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectedCategoryFilter == 'All'
                              ? 'The campus administration has not published rewards yet.'
                              : 'No rewards in this category yet. Check back soon!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Target Reward Goal Progress (Show progress towards the cheapest reward student can't yet afford)
              RewardModel? targetReward;
              for (final r in filtered) {
                if (r.coinCost > gamification.coins) {
                  if (targetReward == null || r.coinCost < targetReward.coinCost) {
                    targetReward = r;
                  }
                }
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  // TARGET PROGRESS BANNER (IF APPLICABLE)
                  if (targetReward != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.lavenderLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.lavender.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flag_outlined, size: 16, color: AppColors.lavenderDark),
                              const SizedBox(width: 6),
                              Text(
                                'Next Goal: ${targetReward.title}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.lavenderDark,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${gamification.coins} / ${targetReward.coinCost} coins',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.lavenderDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (gamification.coins / targetReward.coinCost).clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: Colors.white,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lavender),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Earn ${targetReward.coinCost - gamification.coins} more coins to unlock this reward.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // REWARD CARDS
                  ...filtered.map((r) {
                    final canAfford = gamification.coins >= r.coinCost;
                    final isOutOfStock = r.isOutOfStock;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.lavenderLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  RewardCategories.getLabel(r.category),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.lavenderDark,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: canAfford ? AppColors.coralLight : AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: canAfford ? AppColors.coral : AppColors.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.monetization_on,
                                      size: 14,
                                      color: canAfford ? AppColors.coralDark : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${r.coinCost} Coins',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: canAfford ? AppColors.coralDark : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            r.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textMain,
                            ),
                          ),
                          if (r.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              r.description,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                r.isUnlimitedStock ? 'Available' : 'Remaining: ${r.availableStock}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isOutOfStock ? AppColors.pinkDark : AppColors.mintDark,
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canAfford && !isOutOfStock
                                      ? AppColors.coral
                                      : AppColors.border,
                                  foregroundColor: canAfford && !isOutOfStock
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: isOutOfStock
                                    ? null
                                    : () => _handleRewardRedeemClick(r, gamification),
                                child: Text(
                                  isOutOfStock
                                      ? 'Out of Stock'
                                      : (canAfford
                                          ? 'Redeem Reward'
                                          : 'Need ${r.coinCost - gamification.coins} More'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ========================================================
  // TAB 1: MY REDEMPTIONS
  // ==========================================
  Widget _buildMyRedemptionsTab() {
    return StreamBuilder<List<RewardRedemptionModel>>(
      stream: _gamificationService.streamStudentRedemptions(_activeStudentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.coral),
          );
        }

        final redemptions = snapshot.data ?? [];

        if (redemptions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 14),
                  const Text(
                    'No Redemptions Yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Explore the Rewards tab to redeem free event registration passes, certificate benefits, and campus perks using your earned coins.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: redemptions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = redemptions[index];
            final statusColor = _getStatusColor(item.status);
            final statusBg = _getStatusBg(item.status);

            return Container(
              padding: const EdgeInsets.all(16),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '-${item.coinCost} Coins',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.coralDark,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.rewardTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ref ID: ${item.id}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (item.statusReason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.statusReason,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Redeemed on ${DateFormatter.formatFullDateTime(item.redeemedAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ========================================================
  // TAB 2: BADGES & STREAKS
  // ========================================================
  Widget _buildBadgesAndStreaksTab(GamificationModel gamification) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // STREAK SUMMARY CARD
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.coralLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: AppColors.coralDark,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${gamification.currentStreak} Consecutive Days',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Best streak: ${gamification.longestStreak} days • ${gamification.distinctAttendedDates.length} active event days',
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
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Badge Collection',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            Text(
              '${gamification.totalBadgesUnlocked} / ${BadgeDefinition.allBadges.length} Unlocked',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        ...BadgeDefinition.allBadges.map((badge) {
          final isUnlocked = gamification.isBadgeUnlocked(badge.id);
          final unlockedAt = gamification.getBadgeUnlockedDate(badge.id);
          final progress = gamification.getBadgeProgress(badge);
          final progressText = gamification.getBadgeProgressText(badge);

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showBadgeDetailsModal(
              context,
              badge,
              isUnlocked,
              unlockedAt,
              progress,
              progressText,
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUnlocked ? AppColors.cardWhite : AppColors.cardWhite.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUnlocked ? AppColors.coral : AppColors.border,
                ),
              ),
              child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isUnlocked ? AppColors.coralLight : AppColors.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUnlocked ? AppColors.coral : AppColors.border,
                    ),
                  ),
                  child: Icon(
                    _getBadgeIcon(badge.id),
                    size: 22,
                    color: isUnlocked ? AppColors.coralDark : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            badge.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          if (isUnlocked)
                            const Icon(Icons.check_circle, size: 16, color: AppColors.mintDark)
                          else
                            Text(
                              progressText,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.coral,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        badge.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (!isUnlocked) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.coral),
                          ),
                        ),
                      ] else if (unlockedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Unlocked on ${DateFormatter.formatFullDateTime(unlockedAt)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.mintDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
      ],
    );
  }

  // ========================================================
  // TAB 3: COIN ACTIVITY LEDGER
  // ========================================================
  Widget _buildCoinLedgerTab() {
    return StreamBuilder<List<CoinTransactionModel>>(
      stream: _gamificationService.streamCoinTransactions(_activeStudentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.coral),
          );
        }

        final transactions = snapshot.data ?? [];

        if (transactions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No transactions recorded in your ledger yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: transactions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final t = transactions[index];
            final isCredit = t.amount >= 0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCredit ? AppColors.mintLight : AppColors.coralLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
                      size: 18,
                      color: isCredit ? AppColors.mintDark : AppColors.coralDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (t.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            t.description,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          DateFormatter.formatFullDateTime(t.createdAt),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    isCredit ? '+${t.amount}' : '${t.amount}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isCredit ? AppColors.mintDark : AppColors.coralDark,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ========================================================
  // TAB 4: REFERRALS
  // ========================================================
  Widget _buildReferralsTab(GamificationModel gamification) {
    final code = gamification.referralCode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // YOUR REFERRAL CODE CARD
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Personal Referral Code',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Invite your classmates to register and attend college events. When they verify their first event attendance, you earn +50 coins!',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.lavenderLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lavender.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.lavenderDark,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.lavenderDark,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Referral code copied to clipboard!')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // APPLY A PEER'S CODE (IF NOT YET REFERRED)
        if (gamification.referredBy.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Have a Friend\'s Referral Code?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enter their code before attending your first event to receive +25 welcome coins upon check-in.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _referralCodeInputCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'e.g. CAMPUS-ABC123',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      onPressed: _isSubmittingReferral ? null : _applyReferralCode,
                      child: _isSubmittingReferral
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        const Text(
          'Referred Students Status',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),

        // REFERRED STUDENTS STREAM
        StreamBuilder<List<ReferralRecordModel>>(
          stream: _gamificationService.streamStudentReferrals(_activeStudentId),
          builder: (context, snapshot) {
            final referrals = snapshot.data ?? [];

            if (referrals.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'No students have joined with your code yet. Share your code to start earning referral rewards!',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: referrals.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ref = referrals[index];
                final isQualified = ref.status == 'qualified';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isQualified ? AppColors.mintLight : AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isQualified ? Icons.verified : Icons.hourglass_top,
                          size: 16,
                          color: isQualified ? AppColors.mintDark : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.referredName.isNotEmpty
                                  ? ref.referredName
                                  : 'Student ${ref.referredUid.substring(0, 4).toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              isQualified
                                  ? 'Qualified (First Event Attended)'
                                  : 'Pending (Awaiting first event check-in)',
                              style: TextStyle(
                                fontSize: 11,
                                color: isQualified ? AppColors.mintDark : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        isQualified ? '+${ref.coinsAwarded} pts' : 'Pending',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isQualified ? AppColors.mintDark : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ========================================================
  // REDEMPTION LOGIC & MODALS
  // ========================================================

  void _handleRewardRedeemClick(RewardModel reward, GamificationModel gamification) {
    if (gamification.coins < reward.coinCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient coins. You have ${gamification.coins} coins, but ${reward.coinCost} are required.',
          ),
          backgroundColor: AppColors.pinkDark,
        ),
      );
      return;
    }

    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User profile loading, please try again.')),
      );
      return;
    }

    if (reward.category == RewardCategories.freeEvent) {
      _showFreeEventRegistrationModal(reward);
    } else {
      _showStandardRedeemConfirmationDialog(reward);
    }
  }

  void _showStandardRedeemConfirmationDialog(RewardModel reward) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(reward.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reward.description,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.coralLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: AppColors.coralDark, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Cost: ${reward.coinCost} coins',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.coralDark,
                      ),
                    ),
                  ],
                ),
              ),
              if (reward.termsAndConditions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Terms: ${reward.termsAndConditions}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final result = await _gamificationService.redeemReward(
                    studentId: _activeStudentId,
                    rewardId: reward.id,
                    studentUser: _currentUser!,
                  );

                  if (mounted) {
                    _showRedemptionSuccessDialog(result);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Redemption failed: $e'),
                        backgroundColor: AppColors.pinkDark,
                      ),
                    );
                  }
                }
              },
              child: const Text('Confirm Redemption'),
            ),
          ],
        );
      },
    );
  }

  void _showFreeEventRegistrationModal(RewardModel reward) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Event for Free Pass',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your Free Event Pass will provide 100% registration waiver for the selected upcoming event.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),

              Expanded(
                child: StreamBuilder<List<EventModel>>(
                  stream: _eventService.streamEvents(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final events = snapshot.data ?? [];
                    final eligibleEvents = events.where((e) => !e.isDeadlinePassed && e.availableSeats > 0).toList();

                    if (eligibleEvents.isEmpty) {
                      return const Center(
                        child: Text(
                          'No upcoming events open for registration right now.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: eligibleEvents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final event = eligibleEvents[index];

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${event.dateFormatted} • ${event.venue}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      event.isPaid
                                          ? 'Fee: ₹${event.registrationFee.toInt()} (Free with Pass)'
                                          : 'Free Event',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.mintDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.coral,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () async {
                                  Navigator.pop(sheetCtx);
                                  await _confirmAndExecuteFreeRegistration(reward, event);
                                },
                                child: const Text('Apply Pass', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmAndExecuteFreeRegistration(RewardModel reward, EventModel event) async {
    try {
      final res = await _gamificationService.redeemFreeEventRegistration(
        studentId: _activeStudentId,
        rewardId: reward.id,
        event: event,
        studentUser: _currentUser!,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('🎉 Registration Confirmed!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your free registration for "${event.title}" has been successfully completed using ${reward.coinCost} reward coins.',
                ),
                const SizedBox(height: 10),
                Text(
                  'Registration ID: ${res.registration.id}',
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'You can view your ticket and attendance details under "My Events".',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Great!'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Free registration failed: $e'),
            backgroundColor: AppColors.pinkDark,
          ),
        );
      }
    }
  }

  void _showRedemptionSuccessDialog(RewardRedemptionModel redemption) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 Reward Redeemed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You have redeemed "${redemption.rewardTitle}".'),
            const SizedBox(height: 8),
            Text(
              'Reference ID: ${redemption.id}',
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              redemption.status == RedemptionStatuses.fulfilled
                  ? 'This reward is now active.'
                  : 'Your request has been submitted to college staff for fulfilment. Check the "My Redemptions" tab for updates.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyReferralCode() async {
    final code = _referralCodeInputCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() => _isSubmittingReferral = true);

    try {
      final success = await _gamificationService.registerReferralCode(
        newStudentUid: _activeStudentId,
        newStudentName: _currentUser?.name ?? 'Student',
        enteredReferralCode: code,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral code linked! You will receive bonus coins upon your first event attendance.'),
            backgroundColor: AppColors.mintDark,
          ),
        );
        _referralCodeInputCtrl.clear();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral code not found. Please check and try again.'),
            backgroundColor: AppColors.pinkDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.pinkDark),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReferral = false);
    }
  }

  void _showWaysToEarnDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ways to Earn Campus Coins'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Verified Event Attendance (+50 Coins)\nAttend college events and scan the official attendance QR code displayed at the venue using the app scanner.\n',
              style: TextStyle(fontSize: 12, height: 1.3),
            ),
            Text(
              '2. Daily Consecutive Streaks (+Bonuses)\nAttend events on consecutive calendar days to maintain a streak and unlock bonus milestone points.\n',
              style: TextStyle(fontSize: 12, height: 1.3),
            ),
            Text(
              '3. Peer Referrals (+50 Coins)\nShare your unique referral code with peers. When they attend their first event, you both earn bonus points!\n',
              style: TextStyle(fontSize: 12, height: 1.3),
            ),
            Text(
              '4. Achievement Badges\nUnlock special milestone badges as your campus participation grows.',
              style: TextStyle(fontSize: 12, height: 1.3),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}
