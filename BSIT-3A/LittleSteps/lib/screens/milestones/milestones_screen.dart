import 'package:flutter/material.dart';

import '../../models/milestone.dart';
import '../../services/api_client.dart';
import '../../services/catalog_service.dart';
import '../../services/milestones_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/advisory_banner.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/state_views.dart';
import 'observation_form_sheet.dart';
import 'widgets/milestone_prompt_card.dart';

/// View states for the milestones screen.
enum MilestonesViewState {
  /// Prompts and saved observations are displayed.
  ready,

  /// Observations are loading from the backend.
  loading,

  /// Zero prompts match the active filters.
  empty,

  /// A recoverable request error occurred.
  error,

  /// Cached observations are displayed while offline.
  offline,
}

/// Milestones tab displaying developmental observation prompts grouped by ECCD domain.
class MilestonesScreen extends StatefulWidget {
  /// Creates a [MilestonesScreen].
  const MilestonesScreen({
    super.key,
    this.initialState = MilestonesViewState.ready,
    this.prompts = const [],
    this.initialObservations = const {},
    this.milestonesService,
    this.catalogService,
  });

  /// Initial view state override for widget tests.
  final MilestonesViewState initialState;

  /// Optional preloaded observational prompts for tests or previews.
  final List<MilestonePrompt> prompts;

  /// Preloaded observations keyed by milestone prompt identifier.
  final Map<String, MilestoneObservation> initialObservations;

  /// Optional service override for loading and saving observations.
  final MilestonesService? milestonesService;

  /// Optional catalog service override for fetching live milestone prompts.
  final CatalogService? catalogService;

  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  late MilestonesViewState _currentState;
  late List<MilestonePrompt> _prompts;
  late Map<String, MilestoneObservation> _observations;
  MilestoneDomain? _selectedDomainFilter;
  bool _showAdvisory = true;

  late String _selectedAgeBand;
  String? _lastChildId;
  bool _initialLoadStarted = false;
  bool _promptsLoadStarted = false;

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

  // Maps the active child's age in months to the nearest milestone prompt band.
  String get _childAgeBand {
    final months = _childAgeMonths;
    if (months < 12) return '0-11 months';
    if (months < 24) return '12-23 months';
    if (months < 36) return '24-35 months';
    if (months < 48) return '36-47 months';
    if (months < 60) return '48-59 months';
    return '60-71 months';
  }

  static const List<String> _ageBands = [
    '0-11 months',
    '12-23 months',
    '24-35 months',
    '36-47 months',
    '48-59 months',
    '60-71 months',
  ];

  @override
  void initState() {
    super.initState();
    _currentState = widget.initialState;
    _prompts = widget.prompts;
    _observations = Map.from(widget.initialObservations);
    _selectedAgeBand = '12-23 months';
  }

  ApiClient _resolveApiClient() {
    return widget.milestonesService?.apiClient ??
        widget.catalogService?.apiClient ??
        (AuthScope.maybeOf(context) != null
            ? AuthScope.apiClientOf(context)
            : ApiClient());
  }

  MilestonesService _resolveMilestonesService() {
    if (widget.milestonesService != null) return widget.milestonesService!;
    return MilestonesService(apiClient: _resolveApiClient());
  }

  CatalogService _resolveCatalogService() {
    if (widget.catalogService != null) return widget.catalogService!;
    return CatalogService(apiClient: _resolveApiClient());
  }

  String? get _childId {
    final session = AuthScope.maybeOf(context);
    return session?.activeChild?.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_promptsLoadStarted) {
      _promptsLoadStarted = true;
      _loadCatalogPrompts();
    }
    final childId = _childId;
    final childChanged = childId != _lastChildId;
    if (!_initialLoadStarted || childChanged) {
      _initialLoadStarted = true;
      _lastChildId = childId;
      _selectedAgeBand = _childAgeBand;
      if (childChanged && widget.initialObservations.isEmpty) {
        _observations = {};
      }
      _loadObservations(childId);
    }
  }

  Future<void> _loadCatalogPrompts() async {
    final canFetch =
        widget.catalogService != null || AuthScope.maybeOf(context) != null;
    if (!canFetch || widget.prompts.isNotEmpty) return;

    if (_prompts.isEmpty && _currentState == MilestonesViewState.ready) {
      setState(() => _currentState = MilestonesViewState.loading);
    }

    try {
      final fetched = await _resolveCatalogService().getMilestones();
      if (!mounted) return;
      setState(() {
        _prompts = fetched;
        if (_currentState == MilestonesViewState.loading ||
            _currentState == MilestonesViewState.error) {
          _currentState = MilestonesViewState.ready;
        }
      });
    } on NoConnectionApiException {
      if (!mounted) return;
      setState(() => _currentState = MilestonesViewState.offline);
    } on TimeoutApiException {
      if (!mounted) return;
      setState(() => _currentState = MilestonesViewState.offline);
    } catch (_) {
      if (!mounted) return;
      if (_prompts.isEmpty) {
        setState(() => _currentState = MilestonesViewState.error);
      }
    }
  }

  void _retryLoad() {
    setState(() => _currentState = MilestonesViewState.ready);
    if (_prompts.isEmpty) {
      _loadCatalogPrompts();
    }
    _loadObservations(_childId);
  }

  Future<void> _loadObservations(String? childId) async {
    if (childId == null || widget.initialObservations.isNotEmpty) return;
    final session = AuthScope.maybeOf(context);
    final canFetch =
        widget.milestonesService != null || (session?.isAuthenticated ?? false);
    if (!canFetch) return;

    try {
      final service = _resolveMilestonesService();
      final fetched = await service.getObservations(childId);
      if (!mounted || childId != _lastChildId) return;
      setState(() {
        _observations = {for (final obs in fetched) obs.milestoneId: obs};
      });
    } on NoConnectionApiException {
      if (!mounted || childId != _lastChildId) return;
      setState(() => _currentState = MilestonesViewState.offline);
    } on TimeoutApiException {
      if (!mounted || childId != _lastChildId) return;
      setState(() => _currentState = MilestonesViewState.offline);
    } catch (_) {
      // Keep prompts browsable even if saved observations fail to load.
    }
  }

  void _showAgeBandPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
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

  Future<void> _saveObservation(MilestoneObservation observation) async {
    final previous = _observations[observation.milestoneId];
    setState(() {
      _observations[observation.milestoneId] = observation;
    });

    final childId = _childId;
    if (childId == null) return;

    try {
      final service = _resolveMilestonesService();
      if (previous != null &&
          previous.id.isNotEmpty &&
          !previous.id.startsWith('obs-local')) {
        await service.updateObservation(
          childId: childId,
          observationId: previous.id,
          status: observation.status,
          observedDate: observation.observedDate,
          notes: observation.notes,
        );
      } else {
        final created = await service.createObservation(
          childId: childId,
          milestoneId: observation.milestoneId,
          status: observation.status,
          observedDate: observation.observedDate,
          notes: observation.notes,
        );
        if (mounted && childId == _lastChildId) {
          setState(() {
            _observations[observation.milestoneId] = created;
          });
        }
      }
    } catch (_) {
      if (!mounted) return;
      // Restore the prior local state when persistence fails.
      setState(() {
        if (previous != null) {
          _observations[observation.milestoneId] = previous;
        } else {
          _observations.remove(observation.milestoneId);
        }
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Could not save observation. Please try again.'),
        ),
      );
    }
  }

  void _openObservationSheet(MilestonePrompt prompt) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
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
        ScreenHeader(
          title: 'Milestones',
          subtitle: 'Every child develops at their own pace.',
          onAdvisoryTap: !_showAdvisory
              ? () => setState(() => _showAdvisory = true)
              : null,
        ),
        const SizedBox(height: AppSpacing.space12),
        if (_currentState == MilestonesViewState.loading)
          _buildLoadingState()
        else if (_currentState == MilestonesViewState.error)
          _buildErrorState()
        else ...[
          if (_currentState == MilestonesViewState.offline)
            _buildOfflineBanner(),
          if (_currentState == MilestonesViewState.empty ||
              _observations.isEmpty)
            _buildEmptyStateCard(),
          if (_showAdvisory) _buildAdvisoryBanner(),
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
                        color: AppColors.surfaceCard,
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
          _buildDomainChips(),
          const SizedBox(height: AppSpacing.space16),
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
                color: AppColors.surfaceCard,
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
                            borderRadius: BorderRadius.circular(
                              AppRadius.skeleton,
                            ),
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
                            borderRadius: BorderRadius.circular(
                              AppRadius.skeleton,
                            ),
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

  Widget _buildErrorState() => InlineErrorCard(onRetry: _retryLoad);

  Widget _buildOfflineBanner() {
    return OfflineStatusCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
      message: "Your note wasn't saved. Keep this screen open and tap Retry when you're back online.",
      onRetry: _retryLoad,
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
      padding: const EdgeInsets.all(AppSpacing.space20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: const Center(
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.softGreen,
              radius: 24,
              child: Icon(
                Icons.eco_outlined,
                color: AppColors.forest,
                size: 24,
              ),
            ),
            SizedBox(height: AppSpacing.space12),
            Text(
              'Nothing noted yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: AppSpacing.space4),
            Text(
              'Look for small moments during play.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvisoryBanner() {
    return AdvisoryBanner(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
      title: 'LittleSteps is not a diagnostic tool',
      message: "LittleSteps shares play ideas and things to look for. It's not a test. Children develop at different rates. Talk to a health professional, like your pediatrician or barangay health worker, if you have concerns.",
      onDismiss: () => setState(() => _showAdvisory = false),
    );
  }

  bool _showDomainRightFade = true;

  Widget _buildDomainChips() {
    final row = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: AppSpacing.space20),
      child: Row(
        children: [
          ChoiceChip(
            showCheckmark: false,
            label: const Text('All'),
            selected: _selectedDomainFilter == null,
            selectedColor: AppColors.forest,
            backgroundColor: AppColors.surfaceCard,
            labelStyle: TextStyle(
              color: _selectedDomainFilter == null
                  ? AppColors.surfaceCard
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
                backgroundColor: AppColors.surfaceCard,
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppColors.surfaceCard
                      : AppColors.textPrimary,
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

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.horizontal) return false;
        final hasMoreRight =
            notification.metrics.maxScrollExtent > 0 &&
            notification.metrics.extentAfter > 4;
        if (hasMoreRight != _showDomainRightFade) {
          setState(() => _showDomainRightFade = hasMoreRight);
        }
        return false;
      },
      child: _showDomainRightFade
          ? ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.surfaceCard,
                  AppColors.surfaceCard,
                  Colors.transparent,
                ],
                stops: [0.0, 0.9, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: row,
            )
          : row,
    );
  }

  List<Widget> _buildGroupedPrompts() {
    final ageBandPrompts = _prompts
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
        widgets.add(
          MilestonePromptCard(
            prompt: prompt,
            observation: _observations[prompt.id],
            onTapAction: () => _openObservationSheet(prompt),
          ),
        );
      }
    }
    return widgets;
  }
}
