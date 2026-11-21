import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/milestone.dart';
import '../../theme/app_tokens.dart';

/// Modal bottom sheet for recording an observation for a prompt.
/// Matches Screen 2 & 4 in Figma ("Note what you saw").
class ObservationFormSheet extends StatefulWidget {
  const ObservationFormSheet({
    super.key,
    required this.prompt,
    required this.childName,
    required this.childAgeMonths,
    this.initialObservation,
    this.isOffline = false,
    this.onRetryOffline,
    required this.onSave,
  });

  final MilestonePrompt prompt;
  final String childName;
  final int childAgeMonths;
  final MilestoneObservation? initialObservation;
  final bool isOffline;
  final VoidCallback? onRetryOffline;
  final ValueChanged<MilestoneObservation> onSave;

  @override
  State<ObservationFormSheet> createState() => _ObservationFormSheetState();
}

class _ObservationFormSheetState extends State<ObservationFormSheet> {
  late bool _isObserved;
  late DateTime _selectedDate;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _isObserved = widget.initialObservation?.isObserved ?? true;
    _selectedDate = widget.initialObservation != null
        ? DateTime.tryParse(widget.initialObservation!.observedDate) ??
            DateTime.now()
        : DateTime.now();
    _notesController = TextEditingController(
      text: widget.initialObservation?.notes ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final obs = MilestoneObservation(
      id: widget.initialObservation?.id ??
          'obs-${DateTime.now().millisecondsSinceEpoch}',
      childId: widget.initialObservation?.childId ?? 'child-maya',
      milestoneId: widget.prompt.id,
      status: _isObserved ? 'observed' : 'not_yet_observed',
      observedDate: dateStr,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: widget.initialObservation?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    widget.onSave(obs);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateDisplay = DateFormat('MMM d').format(_selectedDate);
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.space16,
        right: AppSpacing.space16,
        top: AppSpacing.space16,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Back navigation link: ‹ Milestones
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chevron_left,
                      size: 20, color: AppColors.forest),
                  Text(
                    'Milestones',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.forest,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space12),

            // Offline banner card if offline (Screen 4 in Figma)
            if (widget.isOffline) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.space16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOffline,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi_off,
                            color: AppColors.textOffline, size: 20),
                        SizedBox(width: AppSpacing.space8),
                        Text(
                          "You're offline",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textOffline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    const Text(
                      "Your note wasn't saved. Keep this screen open and tap Retry when you're back online.",
                      style: TextStyle(
                        color: AppColors.textOffline,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.control),
                        ),
                      ),
                      onPressed: widget.onRetryOffline,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space16),
            ],

            // Heading: Note what you saw
            Text(
              'Note what you saw',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),

            // Subtitle: Feelings · 12-23 months
            Text(
              '${widget.prompt.domain.label} · ${widget.prompt.ageBand}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space12),

            // Child Selector dropdown pill (For Maya · 14 months ▾)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space12,
                vertical: AppSpacing.space8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.borderSubtle),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                children: [
                  Text(
                    'For ${widget.childName} · ${widget.childAgeMonths} months',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space16),

            // Prompt Title Container (warm cream box)
            Container(
              padding: const EdgeInsets.all(AppSpacing.space16),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Text(
                widget.prompt.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space16),

            // Section: "What did you see?"
            const Text(
              'What did you see?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.space8),

            // Pill toggle buttons matching Figma
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isObserved = true),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isObserved
                            ? AppColors.forest
                            : Colors.transparent,
                        border: Border.all(
                          color: _isObserved
                              ? AppColors.forest
                              : AppColors.borderSubtle,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'I saw it',
                        style: TextStyle(
                          color: _isObserved
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space12),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isObserved = false),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: !_isObserved
                            ? AppColors.forest
                            : Colors.transparent,
                        border: Border.all(
                          color: !_isObserved
                              ? AppColors.forest
                              : AppColors.borderSubtle,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Not seen yet',
                        style: TextStyle(
                          color: !_isObserved
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space16),

            // Section: "When did you see it?"
            const Text(
              'When did you see it?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.space8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: Container(
                height: AppSizes.touchTarget,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.borderSubtle),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Row(
                  children: [
                    Text(
                      isToday ? 'Today, $dateDisplay' : dateDisplay,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space16),

            // Section: "Note (optional)"
            const Text(
              'Note (optional)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.space8),
            TextField(
              controller: _notesController,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'What happened? Describe what you saw in your own words.',
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_notesController.text.length}/500',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space16),

            // Actions: Save & Cancel
            SizedBox(
              height: AppSizes.touchTarget,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                ),
                onPressed: _submit,
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            SizedBox(
              height: AppSizes.touchTarget,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.borderSubtle),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
