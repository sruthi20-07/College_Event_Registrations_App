import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/reward_model.dart';
import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_formatter.dart';

class AdminGamificationScreen extends StatefulWidget {
  const AdminGamificationScreen({super.key});

  @override
  State<AdminGamificationScreen> createState() =>
      _AdminGamificationScreenState();
}

class _AdminGamificationScreenState extends State<AdminGamificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GamificationService _gamificationService = GamificationService();
  final AuthService _authService = AuthService();

  String _redemptionStatusFilter = 'All';

  // Manual Adjustment Controllers
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _coinDeltaController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _isAdjusting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _studentIdController.dispose();
    _coinDeltaController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String get _currentAdminUid => _authService.currentUid ?? 'admin';

  Color _getStatusColor(String status) {
    switch (status) {
      case RedemptionStatuses.approved:
        return AppColors.lavender;
      case RedemptionStatuses.fulfilled:
        return AppColors.mintDark;
      case RedemptionStatuses.pending:
        return AppColors.coral;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Campus Rewards Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.coralDark,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.coral,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Catalogue'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Redemptions'),
            Tab(icon: Icon(Icons.rule_outlined), text: 'Earning Rules'),
            Tab(icon: Icon(Icons.tune_outlined), text: 'Adjustments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCatalogueTab(),
          _buildRedemptionsTab(),
          _buildEarningRulesTab(),
          _buildManualAdjustmentTab(),
        ],
      ),
    );
  }

  // ========================================================
  // TAB 1: REWARDS CATALOGUE
  // ========================================================
  Widget _buildCatalogueTab() {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Reward'),
        onPressed: () => _showAddEditRewardDialog(),
      ),
      body: StreamBuilder<List<RewardModel>>(
        stream: _gamificationService.streamAllRewardsAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.coral),
            );
          }

          final rewards = snapshot.data ?? [];

          if (rewards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_giftcard, size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 14),
                    const Text(
                      'No Rewards Configured Yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap "Add Reward" below to create your first campus reward.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _seedDefaultRewards(),
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Seed Standard College Rewards'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: rewards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final r = rewards[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: r.isEnabled ? AppColors.border : AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cost avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: r.isEnabled ? AppColors.coralLight : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: r.isEnabled ? AppColors.coral : AppColors.border,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.monetization_on,
                            size: 16,
                            color: r.isEnabled ? AppColors.coralDark : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${r.coinCost}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: r.isEnabled ? AppColors.coralDark : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                              Switch(
                                value: r.isEnabled,
                                activeThumbColor: AppColors.coral,
                                onChanged: (val) {
                                  _gamificationService.toggleRewardStatus(r.id, val);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: r.isEnabled ? AppColors.textMain : AppColors.textSecondary,
                            ),
                          ),
                          if (r.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              r.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                r.isUnlimitedStock
                                    ? 'Unlimited Stock'
                                    : 'Stock: ${r.availableStock}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: r.isOutOfStock
                                      ? AppColors.pinkDark
                                      : AppColors.mintDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                r.fulfilmentType == 'automatic'
                                    ? 'Auto Fulfilment'
                                    : 'Manual Approval',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                color: AppColors.textSecondary,
                                onPressed: () => _showAddEditRewardDialog(existing: r),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                color: AppColors.pinkDark,
                                onPressed: () => _confirmDeleteReward(r),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ========================================================
  // TAB 2: REDEMPTIONS & FULFILMENT
  // ========================================================
  Widget _buildRedemptionsTab() {
    return Column(
      children: [
        // FILTER CHIPS ROW
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              'All',
              RedemptionStatuses.pending,
              RedemptionStatuses.approved,
              RedemptionStatuses.fulfilled,
              RedemptionStatuses.rejected,
              RedemptionStatuses.refunded,
            ].map((status) {
              final isSelected = _redemptionStatusFilter == status;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.coral,
                  backgroundColor: AppColors.cardWhite,
                  onSelected: (val) {
                    if (val) setState(() => _redemptionStatusFilter = status);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // STREAM OF REDEMPTIONS
        Expanded(
          child: StreamBuilder<List<RewardRedemptionModel>>(
            stream: _gamificationService.streamAllRedemptionsAdmin(
              statusFilter: _redemptionStatusFilter,
            ),
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
                  child: Text(
                    'No redemptions found for filter "$_redemptionStatusFilter"',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: redemptions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = redemptions[index];
                  final statusColor = _getStatusColor(item.status);
                  final statusBg = _getStatusBg(item.status);

                  return Container(
                    padding: const EdgeInsets.all(14),
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
                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
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
                          'Student: ${item.studentName} (${item.studentRoll.isNotEmpty ? item.studentRoll : item.studentId})',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (item.statusReason.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Note: ${item.statusReason}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Redeemed: ${DateFormatter.formatFullDateTime(item.redeemedAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Divider(height: 16),

                        // ACTION BUTTONS FOR ADMIN
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (item.status == RedemptionStatuses.pending) ...[
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.pinkDark,
                                  side: const BorderSide(color: AppColors.pinkDark),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () => _showRejectRefundDialog(item),
                                child: const Text('Reject & Refund', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.mintDark,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () => _updateRedemption(
                                  item.id,
                                  RedemptionStatuses.fulfilled,
                                  'Fulfilled by admin',
                                ),
                                child: const Text('Mark Fulfilled', style: TextStyle(fontSize: 12)),
                              ),
                            ] else if (item.status == RedemptionStatuses.approved) ...[
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.pinkDark,
                                  side: const BorderSide(color: AppColors.pinkDark),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () => _showRejectRefundDialog(item),
                                child: const Text('Refund Coins', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.mintDark,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () => _updateRedemption(
                                  item.id,
                                  RedemptionStatuses.fulfilled,
                                  'Fulfilled by admin',
                                ),
                                child: const Text('Mark Fulfilled', style: TextStyle(fontSize: 12)),
                              ),
                            ] else ...[
                              Text(
                                item.fulfilledAt != null
                                    ? 'Fulfilled on ${DateFormatter.formatFullDateTime(item.fulfilledAt!)}'
                                    : 'Completed',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
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
    );
  }

  // ========================================================
  // TAB 3: EARNING RULES CONFIGURATION
  // ========================================================
  Widget _buildEarningRulesTab() {
    return StreamBuilder<List<GamificationRuleModel>>(
      stream: _gamificationService.streamRules(),
      builder: (context, snapshot) {
        final rules = snapshot.data ?? [];
        final attendanceRule = rules.firstWhere(
          (r) => r.id == 'attendance',
          orElse: () => const GamificationRuleModel(
            id: 'attendance',
            name: 'Verified Event Attendance',
            activityType: 'attendance',
            coinAmount: 50,
            description: 'Coins awarded per event check-in via official event QR',
          ),
        );

        final referralRule = rules.firstWhere(
          (r) => r.id == 'referral',
          orElse: () => const GamificationRuleModel(
            id: 'referral',
            name: 'Verified Peer Referral',
            activityType: 'referral',
            coinAmount: 50,
            description: 'Coins awarded to referring student on peer first attendance',
          ),
        );

        final streakRule = rules.firstWhere(
          (r) => r.id == 'streak_milestone_3',
          orElse: () => const GamificationRuleModel(
            id: 'streak_milestone_3',
            name: '3-Day Streak Milestone',
            activityType: 'streak_milestone',
            coinAmount: 30,
            description: 'Bonus coins awarded on 3 consecutive days streak',
          ),
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lavenderLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.lavender.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: AppColors.lavenderDark),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Configure coin awards for campus activities. Changes take effect immediately for all subsequent verified check-ins and activities.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.lavenderDark,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildRuleConfigCard(
              title: 'Verified Event Attendance',
              description: 'Coins automatically credited upon scanning official event QR at the venue',
              icon: Icons.qr_code_scanner,
              currentAmount: attendanceRule.coinAmount,
              onSave: (amount) async {
                final messenger = ScaffoldMessenger.of(context);
                await _gamificationService.saveRule(
                  GamificationRuleModel(
                    id: 'attendance',
                    name: 'Verified Event Attendance',
                    activityType: 'attendance',
                    coinAmount: amount,
                    description: 'Coins awarded per event check-in via official event QR',
                  ),
                );
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Attendance earning rule updated!')),
                  );
                }
              },
            ),

            const SizedBox(height: 12),

            _buildRuleConfigCard(
              title: 'Verified Student Referral',
              description: 'Awarded to referring student when referred student attends their first event',
              icon: Icons.people_outline,
              currentAmount: referralRule.coinAmount,
              onSave: (amount) async {
                final messenger = ScaffoldMessenger.of(context);
                await _gamificationService.saveRule(
                  GamificationRuleModel(
                    id: 'referral',
                    name: 'Verified Peer Referral',
                    activityType: 'referral',
                    coinAmount: amount,
                    description: 'Coins awarded to referring student on peer first attendance',
                  ),
                );
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Referral earning rule updated!')),
                  );
                }
              },
            ),

            const SizedBox(height: 12),

            _buildRuleConfigCard(
              title: '3-Day Streak Milestone Bonus',
              description: 'One-time bonus credited when a student maintains a 3-consecutive-day streak',
              icon: Icons.local_fire_department_outlined,
              currentAmount: streakRule.coinAmount,
              onSave: (amount) async {
                final messenger = ScaffoldMessenger.of(context);
                await _gamificationService.saveRule(
                  GamificationRuleModel(
                    id: 'streak_milestone_3',
                    name: '3-Day Streak Milestone',
                    activityType: 'streak_milestone',
                    coinAmount: amount,
                    description: 'Bonus coins awarded on 3 consecutive days streak',
                  ),
                );
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Streak milestone rule updated!')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRuleConfigCard({
    required String title,
    required String description,
    required IconData icon,
    required int currentAmount,
    required Function(int) onSave,
  }) {
    final controller = TextEditingController(text: currentAmount.toString());

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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.coralLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.coralDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Coin Award',
                    isDense: true,
                    border: OutlineInputBorder(),
                    suffixText: 'pts',
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                onPressed: () {
                  final val = int.tryParse(controller.text) ?? currentAmount;
                  onSave(val);
                },
                child: const Text('Update Rule'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========================================================
  // TAB 4: MANUAL COIN ADJUSTMENT
  // ========================================================
  Widget _buildManualAdjustmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  'Manual Coin Balance Adjustment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Adjust a student\'s spendable coin balance. All adjustments require an auditable reason and record the acting admin UID.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _studentIdController,
                  decoration: const InputDecoration(
                    labelText: 'Student UID or ID',
                    hintText: 'e.g. 5xX8vQ...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _coinDeltaController,
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  decoration: const InputDecoration(
                    labelText: 'Coin Amount (+ to award, - to deduct)',
                    hintText: 'e.g. +50 or -30',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Mandatory Adjustment Reason',
                    hintText: 'e.g. Event volunteering bonus, Quiz competition prize',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isAdjusting ? null : _submitManualAdjustment,
                    child: _isAdjusting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Apply Adjustment',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Recent Audit Ledger Entries',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 10),

          // RECENT AUDIT LOGS STREAM
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('reward_history')
                .orderBy('createdAt', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text('No ledger entries recorded yet.');
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final amount = (data['amount'] ?? data['coinsAwarded'] ?? 0) as int;
                  final title = data['title'] ?? data['rewardReason'] ?? 'Activity';
                  final studentId = data['studentId'] ?? '';
                  final type = data['type'] ?? data['rewardType'] ?? '';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          amount >= 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                          size: 18,
                          color: amount >= 0 ? AppColors.mintDark : AppColors.coralDark,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                'Student: $studentId • Type: $type',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          amount >= 0 ? '+$amount' : '$amount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: amount >= 0 ? AppColors.mintDark : AppColors.coralDark,
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
      ),
    );
  }

  // ========================================================
  // HELPER METHODS & ACTIONS
  // ========================================================

  Future<void> _submitManualAdjustment() async {
    final studentId = _studentIdController.text.trim();
    final deltaStr = _coinDeltaController.text.trim();
    final reason = _reasonController.text.trim();

    if (studentId.isEmpty || deltaStr.isEmpty || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields.')),
      );
      return;
    }

    final delta = int.tryParse(deltaStr);
    if (delta == null || delta == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid non-zero integer coin delta.')),
      );
      return;
    }

    setState(() => _isAdjusting = true);

    try {
      await _gamificationService.adminManualCoinAdjustment(
        studentId: studentId,
        coinDelta: delta,
        reason: reason,
        adminUid: _currentAdminUid,
      );

      _studentIdController.clear();
      _coinDeltaController.clear();
      _reasonController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Coin adjustment of $delta successfully recorded for $studentId!'),
            backgroundColor: AppColors.mintDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Adjustment failed: $e'), backgroundColor: AppColors.pinkDark),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdjusting = false);
    }
  }

  Future<void> _updateRedemption(String redemptionId, String status, String note) async {
    try {
      await _gamificationService.adminUpdateRedemptionStatus(
        redemptionId: redemptionId,
        newStatus: status,
        adminUid: _currentAdminUid,
        reason: note,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Redemption updated to $status.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: AppColors.pinkDark),
        );
      }
    }
  }

  void _showRejectRefundDialog(RewardRedemptionModel item) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reject & Refund Coins'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to reject "${item.rewardTitle}" for student ${item.studentName}? This will refund ${item.coinCost} coins back to their account.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason',
                  hintText: 'e.g. Ineligible, out of physical vouchers',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pinkDark,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                Navigator.pop(ctx);
                _updateRedemption(
                  item.id,
                  RedemptionStatuses.rejected,
                  reason.isNotEmpty ? reason : 'Rejected by administrator',
                );
              },
              child: const Text('Confirm Rejection & Refund'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteReward(RewardModel r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reward'),
        content: Text('Are you sure you want to delete "${r.title}" from the catalogue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.pinkDark, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _gamificationService.deleteReward(r.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddEditRewardDialog({RewardModel? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final costCtrl = TextEditingController(text: existing != null ? existing.coinCost.toString() : '100');
    final stockCtrl = TextEditingController(text: existing != null ? existing.availableStock.toString() : '-1');
    final termsCtrl = TextEditingController(text: existing?.termsAndConditions ?? '');
    String category = existing?.category ?? RewardCategories.collegePerk;
    String fulfilment = existing?.fulfilmentType ?? 'manual_approval';
    bool isEnabled = existing?.isEnabled ?? true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Campus Reward' : 'Edit Reward'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Reward Title *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: RewardCategories.all.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(RewardCategories.getLabel(c)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Coin Cost *'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Stock (-1 for ∞)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: fulfilment,
                      decoration: const InputDecoration(labelText: 'Fulfilment Method'),
                      items: const [
                        DropdownMenuItem(
                          value: 'manual_approval',
                          child: Text('Staff Approval / Manual Verification'),
                        ),
                        DropdownMenuItem(
                          value: 'automatic',
                          child: Text('Automatic Digital Pass'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => fulfilment = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: termsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Terms & Conditions',
                        hintText: 'e.g. Valid during current academic term only',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Active in Catalogue'),
                        const Spacer(),
                        Switch(
                          value: isEnabled,
                          activeThumbColor: AppColors.coral,
                          onChanged: (val) => setDialogState(() => isEnabled = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    final cost = int.tryParse(costCtrl.text.trim()) ?? 100;
                    final stock = int.tryParse(stockCtrl.text.trim()) ?? -1;

                    if (title.isEmpty) return;

                    final model = RewardModel(
                      id: existing?.id ?? '',
                      title: title,
                      description: descCtrl.text.trim(),
                      category: category,
                      coinCost: cost,
                      availableStock: stock,
                      initialStock: stock,
                      isEnabled: isEnabled,
                      fulfilmentType: fulfilment,
                      termsAndConditions: termsCtrl.text.trim(),
                    );

                    Navigator.pop(dialogCtx);

                    if (existing == null) {
                      await _gamificationService.createReward(model);
                    } else {
                      await _gamificationService.updateReward(model);
                    }
                  },
                  child: Text(existing == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _seedDefaultRewards() async {
    final standardRewards = [
      RewardModel(
        id: 'free_event_pass',
        title: 'Free Event Registration Pass',
        description: '100% registration fee waiver for any eligible paid technical or cultural event.',
        category: RewardCategories.freeEvent,
        coinCost: 150,
        availableStock: -1,
        fulfilmentType: 'automatic',
        termsAndConditions: 'Applies automatically at registration checkout for eligible events.',
      ),
      RewardModel(
        id: 'priority_certificate',
        title: 'Priority Certificate Endorsement',
        description: 'Verified attendance certificate with official faculty endorsement distinction.',
        category: RewardCategories.certificate,
        coinCost: 200,
        availableStock: -1,
        fulfilmentType: 'manual_approval',
        termsAndConditions: 'Requires verified attendance at the associated workshop or event.',
      ),
      RewardModel(
        id: 'library_extension',
        title: 'Library Extended Borrowing Pass',
        description: 'Extend book borrowing period by 14 days and borrow up to 2 additional books.',
        category: RewardCategories.collegePerk,
        coinCost: 100,
        availableStock: 50,
        fulfilmentType: 'manual_approval',
        termsAndConditions: 'Present reference code at the Central College Library desk.',
      ),
      RewardModel(
        id: 'canteen_snack_pass',
        title: 'Campus Canteen Refreshment Voucher',
        description: 'College-sponsored refreshment voucher redeemable at the main college cafeteria.',
        category: RewardCategories.collegePerk,
        coinCost: 80,
        availableStock: 100,
        fulfilmentType: 'manual_approval',
        termsAndConditions: 'One voucher per student per week. Valid during working campus hours.',
      ),
    ];

    for (final r in standardRewards) {
      await _gamificationService.createReward(r);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Standard campus rewards added to catalogue!')),
      );
    }
  }
}
