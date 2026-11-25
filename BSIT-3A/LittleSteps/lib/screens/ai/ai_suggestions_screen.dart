import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/child.dart';
import '../../models/plan.dart';
import '../../models/recommendation.dart';
import '../../models/weather.dart';
import '../../services/ai_service.dart';
import '../../services/api_client.dart';
import '../../services/catalog_service.dart';
import '../../services/plan_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';

/// Screen that hosts the Idea Helper play activity recommendation flow.
///
/// Collects available materials, duration, setting, and language preferences
/// to generate personalized, non-diagnostic play activity recommendations.
class AiSuggestionsScreen extends StatefulWidget {
  /// Creates an [AiSuggestionsScreen].
  const AiSuggestionsScreen({
    super.key,
    this.apiClient,
    this.aiService,
    this.catalogService,
    this.planService,
    this.initialChild,
  });

  /// Optional HTTP client override used for tests.
  final ApiClient? apiClient;

  /// Optional AI recommendation service override used for tests.
  final AiService? aiService;

  /// Optional catalog service override for weather hints and fallback picks.
  final CatalogService? catalogService;

  /// Optional plan service override for saving suggestions to today's plan.
  final PlanService? planService;

  /// Optional active child override used when launching outside [AuthScope].
  final Child? initialChild;

  @override
  State<AiSuggestionsScreen> createState() => _AiSuggestionsScreenState();
}

enum _PlaySettingOption {
  either('either', 'Indoor or outdoor'),
  indoor('indoor', 'Indoor'),
  outdoor('outdoor', 'Outdoor');

  const _PlaySettingOption(this.code, this.label);
  final String code;
  final String label;
}

enum _PlayLanguageOption {
  english('en', 'English'),
  filipino('fil', 'Filipino'),
  hiligaynon('hil', 'Hiligaynon');

  const _PlayLanguageOption(this.code, this.label);
  final String code;
  final String label;
}

class _AiSuggestionsScreenState extends State<AiSuggestionsScreen> {
  final TextEditingController _materialsController = TextEditingController();

  int _timeMinutes = 15;
  String _setting = _PlaySettingOption.either.code;
  String _language = _PlayLanguageOption.english.code;
  String _ageBand = '12-23m';
  String? _domain;

  bool _isLoading = false;
  bool _isAddingAll = false;
  final Set<String> _addedActivityIds = {};
  RecommendationResponse? _response;
  String? _rateLimitMessage;
  String? _fallbackNotice;
  WeatherHint? _weatherHint;
  String? _lastWeatherCityKey;
  String? _lastChildId;

  static const List<int> _timeOptions = [10, 15, 30, 45];
  static const List<({String code, String label})> _ageBandOptions = [
    (code: '0-5m', label: '0-5 months'),
    (code: '6-11m', label: '6-11 months'),
    (code: '12-23m', label: '12-23 months'),
    (code: '24-35m', label: '24-35 months'),
    (code: '36-47m', label: '3-4 years'),
    (code: '48-59m', label: '4-5 years'),
    (code: '60-71m', label: '5-6 years'),
  ];

  Child? get _effectiveChild =>
      widget.initialChild ?? AuthScope.maybeOf(context)?.activeChild;

  ApiClient _resolveApiClient() {
    return widget.apiClient ??
        (AuthScope.maybeOf(context) != null
            ? AuthScope.apiClientOf(context)
            : ApiClient());
  }

  AiService _resolveAiService() {
    return widget.aiService ?? AiService(apiClient: _resolveApiClient());
  }

  CatalogService _resolveCatalogService() {
    return widget.catalogService ??
        CatalogService(apiClient: _resolveApiClient());
  }

  PlanService _resolvePlanService() {
    return widget.planService ?? PlanService(apiClient: _resolveApiClient());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync the age band only when the active child changes so manual
    // dropdown selections are not overwritten when the keyboard opens.
    final activeChild = _effectiveChild;
    if (widget.initialChild == null && activeChild?.id != _lastChildId) {
      _lastChildId = activeChild?.id;
      if (activeChild != null) {
        _ageBand = activeChild.ageBand;
      }
    }
    final session = AuthScope.maybeOf(context);
    final weatherLocation = session != null
        ? session.weatherLocation
        : WeatherLocation.iloiloCity;
    final weatherCityKey = weatherLocation?.name ?? '__off__';
    if (_lastWeatherCityKey != weatherCityKey) {
      _lastWeatherCityKey = weatherCityKey;
      if (weatherLocation == null) {
        _weatherHint = null;
      } else {
        _fetchWeatherGuidance(weatherLocation);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final initialChild = widget.initialChild;
    if (initialChild != null) {
      _ageBand = initialChild.ageBand;
    }
  }

  @override
  void dispose() {
    // Release native text-editing resources when the screen unmounts.
    _materialsController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeatherGuidance(WeatherLocation location) async {
    try {
      final hint = await _resolveCatalogService().getWeather(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (!mounted) return;
      setState(() {
        _weatherHint = hint;
        if (hint.suggestedSetting == 'indoor') {
          _setting = 'indoor';
        }
      });
    } catch (_) {}
  }

  // Splits and sanitizes comma-separated household materials (max 10 items)
  // before sending them to the backend prompt builder.
  List<String> _parseMaterials() {
    return _materialsController.text
        .split(',')
        .map((m) => m.trim().toLowerCase())
        .where((m) => m.isNotEmpty && m.length <= 40)
        .take(10)
        .toList();
  }

  // Requests AI play suggestions using only non-PII parameters (age band,
  // setting, duration, materials, and language). Falls back to catalog picks
  // on timeout, HTTP 429 rate limits, or service errors.
  Future<void> _submitRequest() async {
    setState(() {
      _isLoading = true;
      _rateLimitMessage = null;
      _fallbackNotice = null;
    });

    final materials = _parseMaterials();

    try {
      final result = await _resolveAiService()
          .getRecommendations(
            ageBand: _ageBand,
            setting: _setting,
            timeMinutes: _timeMinutes,
            materials: materials,
            language: _language,
            domain: _domain,
            count: 3,
          )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;
      var resolved = result;
      if (!resolved.isAiGenerated && resolved.suggestions.isEmpty) {
        final picks = await _catalogPicks();
        if (!mounted) return;
        if (picks.isNotEmpty) {
          resolved = _fallbackResponse(picks);
        }
      }
      setState(() {
        _response = resolved;
        _isLoading = false;
        if (!resolved.isAiGenerated) {
          _fallbackNotice = resolved.suggestions.isNotEmpty
              ? 'AI suggestions are unavailable right now. Here are reviewed play ideas for this age.'
              : 'AI suggestions are unavailable right now, and no matching activities could be loaded.';
        }
      });
      unawaited(_syncTodayPlannedIds());
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 429 || e.code == 'RATE_LIMITED') {
        _handleRateLimit();
      } else {
        _handleGenericFallback();
      }
    } catch (_) {
      if (!mounted) return;
      _handleGenericFallback();
    }
  }

  Future<void> _handleRateLimit() async {
    final picks = await _catalogPicks();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _rateLimitMessage = "Let's take a short break. You've asked for many ideas in a row. Please wait a minute, then try again.";
      _response = _fallbackResponse(picks);
    });
  }

  Future<void> _handleGenericFallback() async {
    final picks = await _catalogPicks();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _fallbackNotice = picks.isNotEmpty
          ? 'AI suggestions are unavailable right now. Here are reviewed play ideas for this age.'
          : 'AI suggestions are unavailable right now, and no matching activities could be loaded.';
      _response = _fallbackResponse(picks);
    });
  }

  RecommendationResponse _fallbackResponse(List<Recommendation> picks) {
    return RecommendationResponse(
      suggestions: picks,
      source: 'catalog_fallback',
      tier: 3,
      label: 'Our picks',
      disclaimer:
          'Observational play suggestion only. Not developmental assessment.',
    );
  }

  // Fetches real catalog activities constrained by age band, setting, and time
  // first, progressively relaxing constraints only when no matches exist.
  Future<List<Recommendation>> _catalogPicks() async {
    try {
      final catalog = _resolveCatalogService();
      final ageActivities = await catalog.getActivities(ageBand: _ageBand);
      var pool = ageActivities;

      if (pool.isEmpty) {
        pool = await catalog.getActivities();
      }
      if (pool.isEmpty) {
        return const [];
      }

      bool matchesSetting(String itemSetting) {
        return _setting == 'either' ||
            itemSetting == _setting ||
            itemSetting == 'either';
      }

      var filtered = pool
          .where(
            (a) =>
                matchesSetting(a.setting) && a.durationMinutes <= _timeMinutes,
          )
          .toList();
      if (filtered.isEmpty) {
        filtered = pool.where((a) => matchesSetting(a.setting)).toList();
      }
      if (filtered.isEmpty) {
        filtered = pool;
      }

      return filtered
          .take(3)
          .map(
            (a) => Recommendation(
              activityId: a.id,
              title: a.title,
              whyPicked: 'A reviewed pick for this age from our activity list.',
              activity: a,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _syncTodayPlannedIds() async {
    final childId = _effectiveChild?.id ?? widget.initialChild?.id;
    final session = AuthScope.maybeOf(context);
    final canFetch =
        widget.planService != null ||
        widget.apiClient != null ||
        (session?.isAuthenticated ?? false);
    if (childId == null || !canFetch) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final plans = await _resolvePlanService().getPlans(childId, date: today);
      if (!mounted) return;
      setState(() {
        _addedActivityIds.addAll(plans.map((p) => p.activityId));
      });
    } catch (_) {
      // Ignore pre-check failures; individual add actions handle errors.
    }
  }

  String _planActivityId(Recommendation item) {
    if (!item.isCustom) return item.activityId;
    final slug = item.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (slug.isEmpty) return 'custom-play-idea';
    final full = 'custom-$slug';
    return full.length <= 64
        ? full
        : full.substring(0, 64).replaceAll(RegExp(r'-+$'), '');
  }

  CustomPlanActivity? _customSnapshotFor(Recommendation item) {
    if (!item.isCustom || item.activity == null) return null;
    return CustomPlanActivity.fromActivity(
      item.activity!,
      sourceLabel: 'Material adaptation',
    );
  }

  Future<void> _addToPlan(Recommendation item) async {
    final childId = _effectiveChild?.id ?? widget.initialChild?.id;
    final planActivityId = _planActivityId(item);
    if (childId == null || _addedActivityIds.contains(planActivityId)) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      await _resolvePlanService().addActivityToPlan(
        childId: childId,
        activityId: planActivityId,
        scheduledDate: today,
        durationMinutes: item.activity?.durationMinutes,
        customActivity: _customSnapshotFor(item),
      );
      if (!mounted) return;
      setState(() {
        _addedActivityIds.add(planActivityId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${item.title}" to today\'s plan'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not add this to today\'s plan. Please try again.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _addAllToPlan(List<Recommendation> suggestions) async {
    final childId = _effectiveChild?.id ?? widget.initialChild?.id;
    if (childId == null || _isAddingAll) return;
    final pending = suggestions
        .where((item) => !_addedActivityIds.contains(_planActivityId(item)))
        .toList();
    if (pending.isEmpty) return;

    setState(() => _isAddingAll = true);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final service = _resolvePlanService();
    var addedCount = 0;

    for (final item in pending) {
      final planActivityId = _planActivityId(item);
      try {
        await service.addActivityToPlan(
          childId: childId,
          activityId: planActivityId,
          scheduledDate: today,
          durationMinutes: item.activity?.durationMinutes,
          customActivity: _customSnapshotFor(item),
        );
        addedCount++;
        if (mounted) {
          setState(() {
            _addedActivityIds.add(planActivityId);
          });
        }
      } catch (_) {
        // Continue attempting remaining items so partial success is preserved.
      }
    }

    if (!mounted) return;
    setState(() => _isAddingAll = false);
    final message = addedCount > 0
        ? 'Added $addedCount ${addedCount == 1 ? 'activity' : 'activities'} to today\'s plan'
        : 'Could not add activities to today\'s plan. Please try again.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  void _resetToForm() {
    setState(() {
      _response = null;
      _rateLimitMessage = null;
      _fallbackNotice = null;
      _addedActivityIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Idea helper')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.space16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isLoading)
                    _buildLoadingView()
                  else if (_response != null)
                    _buildResultsView()
                  else
                    _buildFormView(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    // Copy nullable field to a local variable for Dart null-safety promotion.
    final weatherHint = _weatherHint;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Idea helper',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'Find a play idea with the time and materials you have.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.space16),

            if (weatherHint != null && !weatherHint.isUnavailable) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.space12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAdvisory,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: AppColors.borderAdvisory),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          weatherHint.isRainy
                              ? Icons.cloud_outlined
                              : Icons.wb_sunny_outlined,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: AppSpacing.space8),
                        Expanded(
                          child: Text(
                            weatherHint.hint ??
                                (weatherHint.suggestedSetting == 'indoor'
                                    ? 'Rainy weather · Indoor play suggested'
                                    : 'Outdoor play recommended today'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      _lastWeatherCityKey != null &&
                              _lastWeatherCityKey != '__off__'
                          ? '$_lastWeatherCityKey · ${weatherHint.attribution}'
                          : weatherHint.attribution,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space16),
            ],

            Text(
              'How much time do you have?',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.space8),
            // Wrap flows chips onto a new row on narrow screens instead of overflowing.
            Wrap(
              spacing: AppSpacing.space8,
              children: _timeOptions.map((mins) {
                final isSelected = _timeMinutes == mins;
                return ChoiceChip(
                  label: Text('$mins min'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _timeMinutes = mins);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.space16),

            Text(
              'Where will you play?',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.space8),
            Wrap(
              spacing: AppSpacing.space8,
              children: _PlaySettingOption.values.map((opt) {
                final isSelected = _setting == opt.code;
                return ChoiceChip(
                  label: Text(opt.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _setting = opt.code);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.space16),

            Text(
              'Child age range',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.space8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _ageBand,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12,
                  vertical: AppSpacing.space8,
                ),
              ),
              items: _ageBandOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt.code,
                  child: Text(opt.label),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _ageBand = val);
              },
            ),
            const SizedBox(height: AppSpacing.space16),

            Text(
              'Language',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.space8),
            Wrap(
              spacing: AppSpacing.space8,
              children: _PlayLanguageOption.values.map((opt) {
                final isSelected = _language == opt.code;
                return ChoiceChip(
                  label: Text(opt.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _language = opt.code);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.space16),

            Text(
              'What do you have at home?',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.space4),
            TextFormField(
              controller: _materialsController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'For example: cups, spoon, towel, paper',
                helperText: 'Materials only, no names. Comma-separated.',
              ),
            ),
            const SizedBox(height: AppSpacing.space16),

            Container(
              padding: const EdgeInsets.all(AppSpacing.space12),
              decoration: BoxDecoration(
                color: AppColors.surfaceCanvas,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  Expanded(
                    child: Text(
                      'We send only: time, setting, materials, and age band. Child names and notes are never sent.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submitRequest,
                child: const Text('Find play ideas'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.forest),
            const SizedBox(height: AppSpacing.space16),
            Text(
              'Finding ideas… This usually takes a few seconds.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    final response = _response;
    final rateLimitMessage = _rateLimitMessage;
    final fallbackNotice = _fallbackNotice;
    final isAi = response?.isAiGenerated ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rateLimitMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.space16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAdvisory,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.borderAdvisory),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    Text(
                      'Taking a short break',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space8),
                Text(
                  rateLimitMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.space12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to activities'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
        ],

        if (fallbackNotice != null && rateLimitMessage == null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.space16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAdvisory,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.borderAdvisory),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: AppSpacing.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Using our activity list',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      Text(
                        fallbackNotice,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
        ],

        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.space8,
          runSpacing: AppSpacing.space8,
          children: [
            Text(
              isAi ? 'AI suggestions' : 'Catalog picks · not AI',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (isAi)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space8,
                  vertical: AppSpacing.space4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: AppColors.forest),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: AppColors.forest,
                    ),
                    const SizedBox(width: AppSpacing.space4),
                    Text(
                      'Suggested by AI',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.forest,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (isAi) ...[
          const SizedBox(height: AppSpacing.space4),
          Text(
            (response?.isCustomGenerated ?? false)
                ? 'Custom idea tailored to your materials; not from the reviewed catalog.'
                : 'Matched from reviewed LittleSteps activities for your inputs.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (response?.materialNote != null &&
            response!.materialNote!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space12),
          Container(
            padding: const EdgeInsets.all(AppSpacing.space12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAdvisory,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: AppColors.borderAdvisory),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.health_and_safety_outlined,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: AppSpacing.space8),
                Expanded(
                  child: Text(
                    response.materialNote!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.space8),

        if (_timeMinutes >= 30 &&
            response != null &&
            response.suggestions.isNotEmpty) ...[
          _buildPlayBlockBanner(response.suggestions),
          const SizedBox(height: AppSpacing.space12),
        ],

        Container(
          padding: const EdgeInsets.all(AppSpacing.space12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCanvas,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAi
                    ? 'Suggested by AI: always adapt activities to your child and ensure adult supervision.'
                    : 'Always adapt activities to your child and ensure adult supervision.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                _response?.disclaimer ?? 'Observational play suggestion only. Not developmental assessment.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space16),

        if (response != null && response.suggestions.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space20),
              child: Column(
                children: [
                  const Icon(
                    Icons.search_off_outlined,
                    size: 36,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  Text(
                    'No matching play ideas yet',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    'Try changing the time, setting, or language, or tap Try again once your connection is ready.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else if (response != null)
          ...response.suggestions.map((suggestion) {
            return _buildSuggestionCard(suggestion);
          }),

        const SizedBox(height: AppSpacing.space16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitRequest,
                child: Text(isAi ? 'Generate another' : 'Try again'),
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: TextButton(
                onPressed: _resetToForm,
                child: const Text('Change answers'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space24),
      ],
    );
  }

  String _formatSetting(String setting) {
    switch (setting) {
      case 'indoor':
        return 'Indoor';
      case 'outdoor':
        return 'Outdoor';
      case 'either':
        return 'Indoor or outdoor';
      default:
        return setting;
    }
  }

  Widget _buildPlayBlockBanner(List<Recommendation> suggestions) {
    final totalMinutes = suggestions.fold<int>(
      0,
      (sum, item) => sum + (item.activity?.durationMinutes ?? 10),
    );
    final count = suggestions.length;
    final hasCustom = suggestions.any((item) => item.isCustom);
    final saveable = suggestions;
    final allAdded =
        saveable.isNotEmpty &&
        saveable.every(
          (item) => _addedActivityIds.contains(_planActivityId(item)),
        );
    final itemLabel = hasCustom
        ? (count == 1 ? 'play idea' : 'play ideas')
        : (count == 1 ? 'reviewed activity' : 'reviewed activities');
    final pacingSummary = totalMinutes < _timeMinutes
        ? '$count short $itemLabel '
              '(~$totalMinutes mins total) · repeat favorites or mix in free '
              'play to fill $_timeMinutes min.'
        : '$count short $itemLabel '
              '(~$totalMinutes mins total) paced for young attention spans.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space12),
      decoration: BoxDecoration(
        color: AppColors.softGreen.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                size: 18,
                color: AppColors.forest,
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  'Play block for $_timeMinutes min',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            pacingSummary,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textPrimary),
          ),
          if (saveable.length >= 2 && _effectiveChild != null) ...[
            const SizedBox(height: AppSpacing.space12),
            OutlinedButton.icon(
              onPressed: (allAdded || _isAddingAll)
                  ? null
                  : () => _addAllToPlan(saveable),
              icon: Icon(allAdded ? Icons.check : Icons.playlist_add, size: 18),
              label: Text(
                allAdded
                    ? "All added to today's plan"
                    : "Add all to today's plan",
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(Recommendation suggestion) {
    final activity = suggestion.activity;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.space16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activity != null)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.space8,
                runSpacing: AppSpacing.space4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space8,
                      vertical: AppSpacing.space4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCanvas,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Text(
                      activity.domain.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${activity.durationEstimate} · ${_formatSetting(activity.setting)}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  if (suggestion.isCustom)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space8,
                        vertical: AppSpacing.space4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAdvisory,
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                        border: Border.all(color: AppColors.borderAdvisory),
                      ),
                      child: Text(
                        'Material adaptation',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.space8),

            Text(
              suggestion.title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.space8),

            Container(
              padding: const EdgeInsets.all(AppSpacing.space12),
              decoration: BoxDecoration(
                color: AppColors.softGreen.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: AppColors.forest,
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  Expanded(
                    child: Text(
                      'Why this fits: ${suggestion.whyPicked}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space12),

            if (activity != null) ...[
              if (activity.materials.isNotEmpty) ...[
                Text(
                  'Materials needed:',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  activity.materials.join(', '),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.space8),
              ],
              if (activity.instructions.isNotEmpty) ...[
                Text(
                  'Steps to play:',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.space4),
                ...activity.instructions.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}. ',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.space12),
              ],
            ],

            if (suggestion.isCustom &&
                activity != null &&
                activity.limitations.isNotEmpty) ...[
              Text(
                'Safety note: ${activity.limitations}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.space12),
            ],

            if (_effectiveChild == null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.space8),
                child: Text(
                  'Choose a child to add this to a plan.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: Builder(
                builder: (context) {
                  final alreadyAdded = _addedActivityIds.contains(
                    _planActivityId(suggestion),
                  );
                  return FilledButton.icon(
                    onPressed: (_effectiveChild == null || alreadyAdded)
                        ? null
                        : () => _addToPlan(suggestion),
                    icon: Icon(
                      alreadyAdded ? Icons.check : Icons.add,
                      size: 18,
                    ),
                    label: Text(
                      alreadyAdded
                          ? "Added to today's plan"
                          : "Add to today's plan",
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
