import 'package:flutter/material.dart';
import '../models/gamification_model.dart';
import '../services/gamification_service.dart';
import '../utils/constants.dart';

/// Modal dialog allowing students to pick from the 5 supported streak symbols
class StreakSymbolSelectorDialog extends StatefulWidget {
  final String currentSymbol;
  final String studentId;
  final ValueChanged<String>? onSymbolSelected;

  const StreakSymbolSelectorDialog({
    super.key,
    required this.currentSymbol,
    required this.studentId,
    this.onSymbolSelected,
  });

  static Future<String?> show(
    BuildContext context, {
    required String currentSymbol,
    required String studentId,
    ValueChanged<String>? onSymbolSelected,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => StreakSymbolSelectorDialog(
        currentSymbol: currentSymbol,
        studentId: studentId,
        onSymbolSelected: onSymbolSelected,
      ),
    );
  }

  @override
  State<StreakSymbolSelectorDialog> createState() =>
      _StreakSymbolSelectorDialogState();
}

class _StreakSymbolSelectorDialogState extends State<StreakSymbolSelectorDialog>
    with SingleTickerProviderStateMixin {
  late String _selectedSymbol;
  String? _tappedSymbol;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedSymbol = StreakSymbols.isValid(widget.currentSymbol)
        ? widget.currentSymbol
        : StreakSymbols.fire;
  }

  Future<void> _handleSelect(String symbol) async {
    setState(() {
      _selectedSymbol = symbol;
      _tappedSymbol = symbol;
    });

    if (widget.studentId.isNotEmpty) {
      setState(() => _isSaving = true);
      await GamificationService().updateStreakSymbol(widget.studentId, symbol);
      if (mounted) setState(() => _isSaving = false);
    }

    widget.onSymbolSelected?.call(symbol);

    if (mounted) {
      Navigator.of(context).pop(symbol);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Streak symbol updated to $symbol ${StreakSymbols.getLabel(symbol)}!',
          ),
          backgroundColor: AppColors.mintDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.cardWhite,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.lavenderLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 20,
              color: AppColors.lavenderDark,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Your Streak Symbol',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Personalize your daily streak showcase',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(color: AppColors.border, height: 16),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: StreakSymbols.all.map((symbol) {
              final isSelected = _selectedSymbol == symbol;
              final isTapped = _tappedSymbol == symbol;
              final name = StreakSymbols.getLabel(symbol);

              return GestureDetector(
                onTap: _isSaving ? null : () => _handleSelect(symbol),
                child: AnimatedScale(
                  scale: isTapped ? 1.15 : (isSelected ? 1.08 : 1.0),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.coralLight
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.coral : AppColors.border,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.coral.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(symbol, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.coralDark
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 14,
                          color: isSelected
                              ? AppColors.coralDark
                              : AppColors.textSecondary.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.lavenderLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.lavenderDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Changing your symbol updates your streak display without affecting your streak count.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.lavenderDark.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
