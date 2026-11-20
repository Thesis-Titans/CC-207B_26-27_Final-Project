import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/milestone.dart';
import '../../theme/app_tokens.dart';

/// Modal bottom sheet for recording an observation for a prompt.
class ObservationFormSheet extends StatefulWidget {
  const ObservationFormSheet({
    super.key,
    required this.prompt,
    required this.childName,
    required this.childAgeMonths,
    this.initialObservation,
    required this.onSave,
  });

  final MilestonePrompt prompt;
  final String childName;
  final int childAgeMonths;
  final MilestoneObservation? initialObservation;
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
        ? DateTime.tryParse(widget.initialObservation!.observedDate) ?? DateTime.now()
        : DateTime.now();
    _notesController = TextEditingController(text: widget.initialObservation?.notes ?? '');
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
      id: widget.initialObservation?.id ?? 'obs-${DateTime.now().millisecondsSinceEpoch}',
      childId: widget.initialObservation?.childId ?? 'child-maya',
      milestoneId: widget.prompt.id,
      status: _isObserved ? 'observed' : 'not_yet_observed',
      observedDate: dateStr,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: widget.initialObservation?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    widget.onSave(obs);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateDisplay = DateFormat('MMM d, yyyy').format(_selectedDate);

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
            Text('Note what you saw', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.space4),
            Text('${widget.prompt.domain.label} · ${widget.prompt.ageBand}', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.space16),

            // Prompt Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.space16),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Text(widget.prompt.title, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: AppSpacing.space16),

        
            const Text('What did you see?', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.space8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('I saw it'), icon: Icon(Icons.check)),
                ButtonSegment(value: false, label: Text('Not seen yet'), icon: Icon(Icons.hourglass_empty)),
              ],
              selected: {_isObserved},
              onSelectionChanged: (set) => setState(() => _isObserved = set.first),
            ),
            const SizedBox(height: AppSpacing.space16),

            // Date Picker 
            const Text('When did you see it?', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.space8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: Container(
                height: AppSizes.touchTarget,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderInput),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: AppSpacing.space8),
                    Text(dateDisplay),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space16),

            // Input Field
            const Text('Note (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.space8),
            TextField(
              controller: _notesController,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'What happened? Describe what you saw in your own words.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.space16),

            // Save and cancel button
            SizedBox(
              height: AppSizes.touchTarget,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
                onPressed: _submit,
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            SizedBox(
              height: AppSizes.touchTarget,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}