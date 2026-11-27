import 'package:flutter/material.dart';

import '../../../data/philippine_rhymes.dart';
import '../../../theme/app_tokens.dart';

/// List of traditional Philippine nursery rhymes and interactive action games.
class RhymesShelf extends StatelessWidget {
  /// Creates a [RhymesShelf].
  const RhymesShelf({
    super.key,
    required this.childNickname,
    required this.onShowDetails,
    required this.onScheduleRhyme,
  });

  /// Active child's nickname (or fallback phrase) shown in the shelf subtitle.
  final String childNickname;

  /// Callback invoked when the caregiver opens the full lyrics sheet.
  final ValueChanged<PhilippineRhyme> onShowDetails;

  /// Callback invoked when the caregiver adds a rhyme to today's plan.
  final ValueChanged<PhilippineRhyme> onScheduleRhyme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space12),
          child: Text(
            'Traditional songs and rhythm games with $childNickname',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ...philippineRhymes.map((rhyme) {
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.space16),
            decoration: ShapeDecoration(
              color: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                side: const BorderSide(color: AppColors.borderSubtle),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onShowDetails(rhyme),
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.space8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.softGreen,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.badge,
                                        ),
                                      ),
                                      child: Text(
                                        rhyme.domainLabel,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.forest,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.space8),
                                    Text(
                                      '${rhyme.durationMinutes} mins',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  rhyme.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  rhyme.subtitle,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space12),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.space12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCanvas,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lyrics snippet:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space4),
                            Text(
                              rhyme.lyrics.take(4).join('\n'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textPrimary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space12),
                      Text(
                        'How to play: ${rhyme.actionPrompt}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space12),
                      OutlinedButton(
                        onPressed: () => onScheduleRhyme(rhyme),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.forest,
                          side: const BorderSide(color: AppColors.borderInput),
                          minimumSize: const Size.fromHeight(
                            AppSizes.touchTargetSecondary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.control,
                            ),
                          ),
                        ),
                        child: const Text(
                          "Add to today's plan",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
