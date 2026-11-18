import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../models/child.dart';
import '../../models/recommendation.dart';
import '../../models/weather.dart';
import '../../services/ai_service.dart';
import '../../services/api_client.dart';
import '../../services/catalog_service.dart';
import '../../services/plan_service.dart';
import '../../theme/app_tokens.dart';

class AiSuggestionsScreen extends StatefulWidget {
  const AiSuggestionsScreen({
    super.key,
    this.apiClient,
    this.aiService,
    this.catalogService,
    this.planService,
    this.initialChild,
  });

  final ApiClient? apiClient;
  final AiService? aiService;
  final CatalogService? catalogService;
  final PlanService? planService;
  final Child? initialChild;

  @override
  State<AiSuggestionsScreen> createState() => _AiSuggestionsScreenState();
}

class _AiSuggestionsScreenState extends State<AiSuggestionsScreen> {
  late final ApiClient _apiClient;
  late final AiService _aiService;
  late final CatalogService _catalogService;
  late final PlanService _planService;

  final TextEditingController _materialsController = TextEditingController();

  int _timeMinutes = 15;
  String _setting = 'either';
  String _language = 'en';
  String _ageBand = '12-23m';
  String? _domain;

  bool _isLoading = false;
  RecommendationResponse? _response;
  String? _rateLimitMessage;
  String? _fallbackNotice;
  WeatherHint? _weatherHint;

  static const List<int> _timeOptions = [10, 15, 30, 45];
  static const List<Map<String, String>> _settingOptions = [
    {'value': 'either', 'label': 'Indoor or outdoor'},
    {'value': 'indoor', 'label': 'Indoor'},
    {'value': 'outdoor', 'label': 'Outdoor'},
  ];
  static const List<Map<String, String>> _languageOptions = [
    {'value': 'en', 'label': 'English'},
    {'value': 'fil', 'label': 'Filipino'},
    {'value': 'hil', 'label': 'Hiligaynon'},
  ];
  static const List<Map<String, String>> _ageBandOptions = [
    {'value': '0-5m', 'label': '0-5 months'},
    {'value': '6-11m', 'label': '6-11 months'},
    {'value': '12-23m', 'label': '12-23 months'},
    {'value': '24-35m', 'label': '24-35 months'},
    {'value': '36-47m', 'label': '3-4 years'},
    {'value': '48-59m', 'label': '4-5 years'},
    {'value': '60-71m', 'label': '5-6 years'},
  ];

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _aiService = widget.aiService ?? AiService(apiClient: _apiClient);
    _catalogService =
        widget.catalogService ?? CatalogService(apiClient: _apiClient);
    _planService = widget.planService ?? PlanService(apiClient: _apiClient);

    if (widget.initialChild != null) {
      _ageBand = widget.initialChild!.ageBand;
    }

    _fetchWeatherGuidance();
  }

  @override
  void dispose() {
    _materialsController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeatherGuidance() async {
    try {
      final hint = await _catalogService.getWeather();
      if (!mounted) return;
      setState(() {
        _weatherHint = hint;
        if (hint.suggestedSetting == 'indoor') {
          _setting = 'indoor';
        }
      });
    } catch (_) {}
  }

  List<String> _parseMaterials() {
    return _materialsController.text
        .split(',')
        .map((m) => m.trim().toLowerCase())
        .filter((m) => m.isNotEmpty && m.length <= 40)
        .take(10)
        .toList();
  }

  Future<void> _submitRequest() async {
    setState(() {
      _isLoading = true;
      _rateLimitMessage = null;
      _fallbackNotice = null;
    });

    final materials = _parseMaterials();

    try {
      final result = await _aiService
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
      setState(() {
        _response = result;
        _isLoading = false;
        if (!result.isAiGenerated) {
          _fallbackNotice = "The idea helper isn't working right now. Here are a few favorites for this age from our activity list.";
        }
      });
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

  void _handleRateLimit() {
    setState(() {
      _isLoading = false;
      _rateLimitMessage = "Let's take a short break. You've asked for many ideas in a row. Please wait a minute, then try again.";
      _response = RecommendationResponse(
        suggestions: _buildOfflineCatalogPicks(),
        source: 'catalog_fallback',
        tier: 3,
        label: 'Our picks',
        disclaimer:
            'Observational play suggestion only. Not developmental assessment.',
      );
    });
  }

  void _handleGenericFallback() {
    setState(() {
      _isLoading = false;
      _fallbackNotice = "The idea helper isn't working right now. Here are a few favorites for this age from our activity list.";
      _response = RecommendationResponse(
        suggestions: _buildOfflineCatalogPicks(),
        source: 'catalog_fallback',
        tier: 3,
        label: 'Our picks',
        disclaimer:
            'Observational play suggestion only. Not developmental assessment.',
      );
    });
  }

  List<Recommendation> _buildOfflineCatalogPicks() {
    return [
      Recommendation(
        activityId: 'act-sensory-water',
        title: 'Water and Cups Exploration',
        whyPicked: 'Simple everyday items support fine motor grasping and cause-and-effect exploration.',
        activity: Activity(
          id: 'act-sensory-water',
          title: 'Water and Cups Exploration',
          type: 'activity',
          language: _language,
          domain: 'motor',
          ageBand: _ageBand,
          durationMinutes: _timeMinutes,
          durationEstimate: '$_timeMinutes mins',
          setting: _setting,
          materials: const ['plastic cups', 'water bowl'],
          instructions: const [
            'Place cups with a shallow bowl of water.',
            'Let your child scoop and pour water freely.',
            'Name actions like scoop, pour, and splash.',
          ],
          limitations: 'Ensure active adult supervision near water.',
          status: 'reviewed_approved',
          provenanceSource: 'LittleSteps Learning Catalog',
        ),
      ),
      Recommendation(
        activityId: 'act-peekaboo-cloth',
        title: 'Peekaboo with a Towel',
        whyPicked: 'Builds object permanence and interactive communication between caregiver and child.',
        activity: Activity(
          id: 'act-peekaboo-cloth',
          title: 'Peekaboo with a Towel',
          type: 'activity',
          language: _language,
          domain: 'socioEmotional',
          ageBand: _ageBand,
          durationMinutes: _timeMinutes,
          durationEstimate: '$_timeMinutes mins',
          setting: _setting,
          materials: const ['towel or washcloth'],
          instructions: const [
            'Hold the towel gently in front of your face.',
            'Pull it down with a gentle smile and say Peekaboo!',
            'Encourage your child to reach or pull the towel.',
          ],
          limitations: 'Do not leave cloths over the face unattended.',
          status: 'reviewed_approved',
          provenanceSource: 'LittleSteps Learning Catalog',
        ),
      ),
    ];
  }

  Future<void> _addToPlan(Recommendation item) async {
    final childId = widget.initialChild?.id ?? 'demo-child';
    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      await _planService.addActivityToPlan(
        childId: childId,
        activityId: item.activityId,
        scheduledDate: today,
      );
      if (!mounted) return;
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
          content: Text('Saved to today\'s plan offline'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _resetToForm() {
    setState(() {
      _response = null;
      _rateLimitMessage = null;
      _fallbackNotice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI play ideas')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.space16),
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
    );
  }

  Widget _buildFormView() {
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
              'Idea Helper',
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

            if (_weatherHint != null && !_weatherHint!.isUnavailable) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.space12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAdvisory,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: AppColors.borderAdvisory),
                ),
                child: Row(
                  children: [
                    Icon(
                      _weatherHint!.condition == 'rainy'
                          ? Icons.cloud
                          : Icons.wb_sunny_outlined,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    Expanded(
                      child: Text(
                        _weatherHint!.hint ??
                            (_weatherHint!.suggestedSetting == 'indoor'
                                ? 'Rainy weather · Indoor play suggested'
                                : 'Outdoor play recommended today'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
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
              children: _settingOptions.map((opt) {
                final isSelected = _setting == opt['value'];
                return ChoiceChip(
                  label: Text(opt['label']!),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _setting = opt['value']!);
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
                  value: opt['value'],
                  child: Text(opt['label']!),
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
              children: _languageOptions.map((opt) {
                final isSelected = _language == opt['value'];
                return ChoiceChip(
                  label: Text(opt['label']!),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _language = opt['value']!);
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
    final isAi = _response?.isAiGenerated ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_rateLimitMessage != null) ...[
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
                  _rateLimitMessage!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.space12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/');
                  },
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Browse activity catalog'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
        ],

        if (_fallbackNotice != null && _rateLimitMessage == null) ...[
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
                        'Catalog picks · not AI',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      Text(
                        _fallbackNotice!,
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
        const SizedBox(height: AppSpacing.space8),

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
                'AI Suggestion — Always adapt to your child and ensure adult supervision.',
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

        if (_response != null)
          ..._response!.suggestions.map((suggestion) {
            return _buildSuggestionCard(suggestion);
          }),

        const SizedBox(height: AppSpacing.space16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitRequest,
                child: const Text('Generate another'),
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.space8,
              runSpacing: AppSpacing.space4,
              children: [
                if (activity != null)
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
                  'Item ID: ${suggestion.activityId}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.textTertiary,
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

            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _addToPlan(suggestion),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add to today's plan"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _IterableFilter<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) test) => where(test);
}
