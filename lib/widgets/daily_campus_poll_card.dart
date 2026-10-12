import 'package:flutter/material.dart';
import '../models/gamification_model.dart';
import '../models/poll_model.dart';
import '../services/gamification_service.dart';
import '../services/poll_service.dart';
import '../utils/constants.dart';
import 'streak_symbol_selector_dialog.dart';

/// Animated, interactive Daily Campus Poll card for students.
/// Supports single-choice voting, safe vote editing, real-time result animations,
/// and celebration with custom streak symbols.
class DailyCampusPollCard extends StatefulWidget {
  final String studentId;
  final String studentName;
  final bool showEmptyState;

  const DailyCampusPollCard({
    super.key,
    required this.studentId,
    required this.studentName,
    this.showEmptyState = true,
  });

  @override
  State<DailyCampusPollCard> createState() => _DailyCampusPollCardState();
}

class _DailyCampusPollCardState extends State<DailyCampusPollCard>
    with SingleTickerProviderStateMixin {
  final PollService _pollService = PollService();
  final GamificationService _gamificationService = GamificationService();

  String? _selectedOptionId;
  bool _isSubmitting = false;
  bool _isEditMode = false;

  // Celebratory overlay state
  bool _showCelebration = false;
  int _celebratedStreak = 0;
  String _celebratedSymbol = StreakSymbols.fire;

  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _handleVoteSubmit({
    required CampusPollModel poll,
    required bool isEdit,
  }) async {
    if (_selectedOptionId == null || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final res = await _pollService.submitOrUpdateVote(
      pollId: poll.id,
      studentId: widget.studentId,
      studentName: widget.studentName,
      optionId: _selectedOptionId!,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _isEditMode = false;
    });

    if (res.success) {
      if (res.isFirstStreakToday && !isEdit) {
        setState(() {
          _showCelebration = true;
          _celebratedStreak = res.dailyStreak;
          _celebratedSymbol = res.streakSymbol;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppColors.mintDark,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppColors.coralDark,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.studentId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<CampusPollModel?>(
      stream: _pollService.streamActivePoll(),
      builder: (context, pollSnapshot) {
        if (pollSnapshot.connectionState == ConnectionState.waiting &&
            !pollSnapshot.hasData) {
          return _buildLoadingSkeleton();
        }

        final poll = pollSnapshot.data;
        if (poll == null) {
          if (widget.showEmptyState) {
            return _buildNoActivePollCard();
          }
          return const SizedBox.shrink();
        }

        return StreamBuilder<PollVoteModel?>(
          stream: _pollService.streamStudentVote(poll.id, widget.studentId),
          builder: (context, voteSnapshot) {
            final vote = voteSnapshot.data;
            final bool hasVoted = vote != null;

            return StreamBuilder<GamificationModel?>(
              stream: _gamificationService.streamGamification(widget.studentId),
              builder: (context, gameSnapshot) {
                final game = gameSnapshot.data;
                final streakCount = game?.dailyStreak ?? 0;
                final streakSymbol = game?.streakSymbol ?? StreakSymbols.fire;

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.lavender.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.lavender.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. TOP HEADER: CATEGORY BADGE & STREAK INDICATOR
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.lavenderLight,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.lavender.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.how_to_vote_rounded,
                                      size: 13,
                                      color: AppColors.lavenderDark,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Daily Poll • ${poll.category}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.lavenderDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              // COMPACT STREAK CHIP (Tappable to pick custom symbol)
                              InkWell(
                                onTap: () => StreakSymbolSelectorDialog.show(
                                  context,
                                  currentSymbol: streakSymbol,
                                  studentId: widget.studentId,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.coralLight,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.coral.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        streakSymbol,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Day $streakCount',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.coralDark,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(
                                        Icons.arrow_drop_down,
                                        size: 14,
                                        color: AppColors.coralDark,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // 2. QUESTION HEADING
                          Text(
                            poll.question,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                              letterSpacing: -0.3,
                              height: 1.3,
                            ),
                          ),

                          if (poll.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              poll.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // 3. CELEBRATION BANNER (If user just cast first vote)
                          if (_showCelebration) ...[
                            _buildCelebrationCard(),
                            const SizedBox(height: 14),
                          ],

                          // 4. MAIN INTERACTIVE CONTENT: VOTING VS RESULTS
                          if (!hasVoted || _isEditMode) ...[
                            _buildVotingOptions(
                              poll: poll,
                              existingVote: vote,
                              isEdit: _isEditMode,
                            ),
                          ] else ...[
                            _buildResultsView(poll: poll, myVote: vote),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ==========================================
  // VOTING OPTIONS (RADIO-STYLE TAPPABLE CARDS)
  // ==========================================
  Widget _buildVotingOptions({
    required CampusPollModel poll,
    required PollVoteModel? existingVote,
    required bool isEdit,
  }) {
    final activeSelectedId =
        _selectedOptionId ?? (isEdit ? existingVote?.selectedOptionId : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isEdit) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.yellowLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.sunnyYellow),
            ),
            child: const Row(
              children: [
                Icon(Icons.edit_note, size: 16, color: AppColors.yellowDark),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Editing your vote. Choose a new option below and confirm.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.yellowDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // OPTION CARDS LIST
        ...poll.options.map((opt) {
          final isSelected = activeSelectedId == opt.id;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: _isSubmitting
                  ? null
                  : () {
                      setState(() {
                        _selectedOptionId = opt.id;
                      });
                    },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.coralLight
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.coral : AppColors.border,
                    width: isSelected ? 1.8 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.coral.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.coral
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.coral
                              : AppColors.textSecondary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 13,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        opt.text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.textMain
                              : AppColors.textMain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 10),

        // ACTION BUTTONS (SUBMIT / UPDATE / CANCEL)
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border.withValues(
                    alpha: 0.6,
                  ),
                  disabledForegroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: (activeSelectedId == null || _isSubmitting)
                    ? null
                    : () => _handleVoteSubmit(poll: poll, isEdit: isEdit),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isEdit
                            ? Icons.check_circle_outline
                            : Icons.send_rounded,
                        size: 16,
                      ),
                label: Text(
                  _isSubmitting
                      ? 'Submitting...'
                      : (isEdit ? 'Update Vote' : 'Submit Vote'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            if (isEdit) ...[
              const SizedBox(width: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _isEditMode = false;
                          _selectedOptionId = null;
                        });
                      },
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ==========================================
  // RESULTS VIEW WITH ANIMATED PERCENTAGE BARS
  // ==========================================
  Widget _buildResultsView({
    required CampusPollModel poll,
    required PollVoteModel? myVote,
  }) {
    final mostPopular = poll.mostPopularOption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // POLL RESULTS LIST
        ...poll.options.map((opt) {
          final isMyPick = myVote?.selectedOptionId == opt.id;
          final pct = poll.percentageForOption(opt.id);
          final isLeading =
              mostPopular != null &&
              mostPopular.id == opt.id &&
              poll.totalVotes > 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMyPick
                    ? AppColors.coralLight.withValues(alpha: 0.5)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isMyPick
                      ? AppColors.coral
                      : AppColors.border.withValues(alpha: 0.8),
                  width: isMyPick ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          opt.text,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isMyPick
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                      if (isMyPick) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.coral,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Your Vote',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                      if (isLeading && !isMyPick) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mintLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.mintDark.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'Leading',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.mintDark,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isMyPick
                              ? AppColors.coralDark
                              : AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // ANIMATED PROGRESS BAR
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(begin: 0.0, end: pct / 100.0),
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 8,
                          backgroundColor: Colors.white,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isMyPick
                                ? AppColors.coral
                                : (isLeading
                                      ? AppColors.mint
                                      : AppColors.lavender.withValues(
                                          alpha: 0.7,
                                        )),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${opt.voteCount} ${opt.voteCount == 1 ? 'vote' : 'votes'}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 4),

        // FOOTER INFO & EDIT VOTE ACTION
        Row(
          children: [
            Icon(
              Icons.people_outline,
              size: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),
            Text(
              '${poll.totalVotes} total ${poll.totalVotes == 1 ? 'student' : 'students'} voted',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            if (poll.allowVoteEditing && poll.isActive)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditMode = true;
                    _selectedOptionId = myVote?.selectedOptionId;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.coralDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text(
                  'Edit My Vote',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )
            else if (!poll.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Poll Closed',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // CELEBRATION CARD
  // ==========================================
  Widget _buildCelebrationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mintLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mintDark.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_celebratedSymbol, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your vote is in! $_celebratedSymbol',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mintDark,
                      ),
                    ),
                    Text(
                      'Day $_celebratedStreak streak maintained! Keep making your voice heard.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mintDark,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                color: AppColors.mintDark,
                onPressed: () {
                  setState(() => _showCelebration = false);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => StreakSymbolSelectorDialog.show(
                context,
                currentSymbol: _celebratedSymbol,
                studentId: widget.studentId,
                onSymbolSelected: (sym) {
                  setState(() => _celebratedSymbol = sym);
                },
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.mintDark,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.palette_outlined, size: 13),
              label: const Text(
                'Customize Streak Symbol',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SKELETON LOADING VIEW
  // ==========================================
  Widget _buildLoadingSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.lavenderLight,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 220,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActivePollCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.lavender.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.lavender.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.lavenderLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.how_to_vote_outlined,
              size: 36,
              color: AppColors.lavenderDark,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Active Poll Right Now',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Campus administrators publish daily polls to gather your preferences for tech workshops, competitions, and campus events. Check back soon!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
