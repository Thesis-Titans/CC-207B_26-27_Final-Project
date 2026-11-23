import 'package:flutter/material.dart';

import '../../models/milestone.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/screen_header.dart';
import 'observation_form_sheet.dart';

/// View states for the milestones screen.
enum MilestonesViewState { ready, loading, empty, error, offline }

/// Milestones tab displaying developmental observation prompts grouped by ECCD domain.
class MilestonesScreen extends StatefulWidget {
  const MilestonesScreen({
    super.key,
    this.initialState = MilestonesViewState.ready,
    this.prompts = sampleMilestonePrompts,
    this.initialObservations = const {},
  });

  final MilestonesViewState initialState;
  final List<MilestonePrompt> prompts;
  final Map<String, MilestoneObservation> initialObservations;

  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  late MilestonesViewState _currentState;
  late Map<String, MilestoneObservation> _observations;
  MilestoneDomain? _selectedDomainFilter;
  bool _showAdvisory = true;

  /// The age band whose prompts are currently displayed.
  /// Defaults to the active child's age band; caregiver can browse other bands.
  late String _selectedAgeBand;

  /// True after [didChangeDependencies] seeds [_selectedAgeBand] once.
  bool _ageBandSeeded = false;

  String get _childName {
    final session = AuthScope.maybeOf(context);
    return session?.activeChild?.nickname ?? 'Maya';
  }

  int get _childAgeMonths {
    final session = AuthScope.maybeOf(context);
    final ageBand = session?.activeChild?.ageBand;
    if (ageBand != null) {
      final match = RegExp(r'\d+').firstMatch(ageBand);
      if (match != null) {
        return int.tryParse(match.group(0)!) ?? 14;
      }
    }
    return 14;
  }

  String get _childAgeDisplay {
    final session = AuthScope.maybeOf(context);
    final activeChild = session?.activeChild;
    if (activeChild != null) {
      return activeChild.ageBand.contains('month')
          ? activeChild.ageBand
          : '${activeChild.ageBand} months';
    }
    return '14 months';
  }

  /// The age band that best matches the active child's age in months,
  /// used to seed [_selectedAgeBand] on first load.
  String get _childAgeBand {
    final months = _childAgeMonths;
    if (months < 12) return '0-11 months';
    if (months < 24) return '12-23 months';
    if (months < 36) return '24-35 months';
    if (months < 48) return '36-47 months';
    return '48-59 months';
  }

  static const List<String> _ageBands = [
    '0-11 months',
    '12-23 months',
    '24-35 months',
    '36-47 months',
    '48-59 months',
  ];

  @override
  void initState() {
    super.initState();
    _currentState = widget.initialState;
    _observations = Map.from(widget.initialObservations);
    _selectedAgeBand = '12-23 months'; // overwritten in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Seed once so the picker defaults to the active child's band.
    // Guard prevents resetting the picker when the widget tree rebuilds.
    if (!_ageBandSeeded) {
      _selectedAgeBand = _childAgeBand;
      _ageBandSeeded = true;
    }
  }

  void _showAgeBandPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Child's age range",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  'You can browse any age range.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.space12),
                ..._ageBands.map((band) {
                  final isSelected = band == _selectedAgeBand;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space8,
                      vertical: AppSpacing.space4,
                    ),
                    title: Text(
                      band,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? AppColors.forest
                            : AppColors.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.forest)
                        : null,
                    onTap: () {
                      setState(() => _selectedAgeBand = band);
                      Navigator.of(context).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _saveObservation(MilestoneObservation observation) {
    setState(() {
      _observations[observation.milestoneId] = observation;
    });
  }

  void _openObservationSheet(MilestonePrompt prompt) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ObservationFormSheet(
          prompt: prompt,
          childName: _childName,
          childAgeMonths: _childAgeMonths,
          initialObservation: _observations[prompt.id],
          isOffline: _currentState == MilestonesViewState.offline,
          onRetryOffline: () =>
              setState(() => _currentState = MilestonesViewState.ready),
          onSave: _saveObservation,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space16,
      ),
      children: [
        // Title & Subtitle with persistent advisory access
        ScreenHeader(
          title: 'Milestones',
          subtitle: 'Every child develops at their own pace.',
          onAdvisoryTap: !_showAdvisory
              ? () => setState(() => _showAdvisory = true)
              : null,
        ),
        const SizedBox(height: AppSpacing.space12),

        // Child Selector Dropdown Pill
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
                'For $_childName · $_childAgeDisplay',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space12),

        // State-driven Content
        if (_currentState == MilestonesViewState.loading)
          _buildLoadingState()
        else if (_currentState == MilestonesViewState.error)
          _buildErrorState()
        else ...[
          if (_currentState == MilestonesViewState.offline)
            _buildOfflineBanner(),

          // Introductory prompt card displayed when no observations have been recorded yet.
          if (_currentState == MilestonesViewState.empty ||
              _observations.isEmpty)
            _buildEmptyStateCard(),

          // Educational advisory banner reminding caregivers that children develop at different paces.
          if (_showAdvisory) _buildAdvisoryBanner(),

          // Child's Age Selector — tapping opens the age-band picker
          InkWell(
            onTap: _showAgeBandPicker,
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Child's age",
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.space4),
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
                            _selectedAgeBand,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: AppSpacing.space8),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space12),

          // Domain Filter Chips
          _buildDomainChips(),
          const SizedBox(height: AppSpacing.space16),

          // Prompts list
          ..._buildGroupedPrompts(),
        ],
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loading milestones...',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.space16),
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space12),
            child: Container(
              height: 72,
              padding: const EdgeInsets.all(AppSpacing.space16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.borderSubtle,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space8),
                        Container(
                          width: 140,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.borderSubtle.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space16),
                  Container(
                    width: 48,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceError,
        border: Border.all(color: AppColors.borderError),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.textError, size: 20),
              SizedBox(width: AppSpacing.space8),
              Text(
                "We couldn't load this right now",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textError,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          const Text(
            'Try again in a moment.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.space16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.borderInput),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
            ),
            onPressed: () =>
                setState(() => _currentState = MilestonesViewState.ready),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
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
              Icon(Icons.wifi_off, color: AppColors.textOffline, size: 20),
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
          const SizedBox(height: AppSpacing.space4),
          const Text(
            "Your note wasn't saved. Keep this screen open and tap Retry when you're back online.",
            style: TextStyle(color: AppColors.textOffline, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.space12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
            ),
            onPressed: () =>
                setState(() => _currentState = MilestonesViewState.ready),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
      padding: const EdgeInsets.all(AppSpacing.space20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Center(
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.softGreen,
              radius: 24,
              child: const Icon(
                Icons.eco_outlined,
                color: AppColors.forest,
                size: 24,
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            const Text(
              'Nothing noted yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.space4),
            const Text(
              'Look for small moments during play.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvisoryBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
      padding: const EdgeInsets.all(AppSpacing.space12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAdvisory,
        border: Border.all(color: AppColors.borderAdvisory),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 20,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LittleSteps is not a diagnostic tool',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  "LittleSteps shares play ideas and things to look for. It's not a test. Children develop at different rates. Talk to a health professional, like your pediatrician or barangay health worker, if you have concerns.",
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textPrimary, height: 1.3),
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _showAdvisory = false),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            showCheckmark: false,
            label: const Text('All'),
            selected: _selectedDomainFilter == null,
            selectedColor: AppColors.forest,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: _selectedDomainFilter == null
                  ? Colors.white
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              side: BorderSide(
                color: _selectedDomainFilter == null
                    ? AppColors.forest
                    : AppColors.borderSubtle,
              ),
            ),
            onSelected: (_) => setState(() => _selectedDomainFilter = null),
          ),
          const SizedBox(width: AppSpacing.space8),
          ...MilestoneDomain.values.map((domain) {
            final isSelected = _selectedDomainFilter == domain;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.space8),
              child: ChoiceChip(
                showCheckmark: false,
                label: Text(domain.label),
                selected: isSelected,
                selectedColor: AppColors.forest,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.forest
                        : AppColors.borderSubtle,
                  ),
                ),
                onSelected: (_) =>
                    setState(() => _selectedDomainFilter = domain),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedPrompts() {
    // First filter by the selected age band, then optionally by domain chip.
    final ageBandPrompts = widget.prompts
        .where((p) => p.ageBand == _selectedAgeBand)
        .toList();

    final filteredPrompts = _selectedDomainFilter == null
        ? ageBandPrompts
        : ageBandPrompts
              .where((p) => p.domain == _selectedDomainFilter)
              .toList();

    final Map<MilestoneDomain, List<MilestonePrompt>> grouped = {};
    for (final p in filteredPrompts) {
      grouped.putIfAbsent(p.domain, () => []).add(p);
    }

    final List<Widget> widgets = [];
    for (final domain in MilestoneDomain.values) {
      final domainPrompts = grouped[domain];
      if (domainPrompts == null || domainPrompts.isEmpty) continue;

      // Section header per domain (e.g. "Talking")
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
          child: Text(
            domain.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );

      for (final prompt in domainPrompts) {
        final obs = _observations[prompt.id];
        final isObserved = obs?.isObserved ?? false;

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space12),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.space16),
              decoration: BoxDecoration(
                color: isObserved ? AppColors.softGreen : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: isObserved
                      ? AppColors.forest.withValues(alpha: 0.3)
                      : AppColors.borderSubtle,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          prompt.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space8),
                      // Action Button (Add or Update)
                      SizedBox(
                        height: 36,
                        child: isObserved
                            ? OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.space16,
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.forest,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.control,
                                    ),
                                  ),
                                ),
                                onPressed: () => _openObservationSheet(prompt),
                                child: const Text(
                                  'Update',
                                  style: TextStyle(
                                    color: AppColors.forest,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.forest,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.space16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.control,
                                    ),
                                  ),
                                ),
                                onPressed: () => _openObservationSheet(prompt),
                                child: const Text(
                                  'Add',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space8),

                  // Everyday observational cues formatted with separator dots.
                  Text(
                    'Look for: ${prompt.lookFor.join(' · ')}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),

                  const SizedBox(height: AppSpacing.space8),

                  // Status line: "Not seen yet" or saved notes box
                  if (isObserved) ...[
                    if (obs?.notes != null && obs!.notes!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(AppSpacing.space8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.note_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.space4),
                            Expanded(
                              child: Text(
                                obs.notes!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else ...[
                    Text(
                      'Not seen yet',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Provenance source indicator with blue info icon
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Color(0xFF2B6CB0),
                      ),
                      const SizedBox(width: AppSpacing.space4),
                      Expanded(
                        child: Text(
                          prompt.provenance,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}
