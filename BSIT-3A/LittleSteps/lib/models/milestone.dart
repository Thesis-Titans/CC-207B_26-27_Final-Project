import 'package:flutter/material.dart';

/// A caregiver's saved observation for one milestone prompt.
///
/// The prompt text itself is not stored by the API; [milestoneId] links the
/// observation to a prompt in the app's prompt list.
class MilestoneObservation {
  const MilestoneObservation({
    required this.id,
    required this.childId,
    required this.milestoneId,
    required this.status,
    required this.observedDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String childId;
  final String milestoneId;

  /// One of `observed`, `not_yet_observed` or `not_sure`
  final String status;

  /// Local calendar date in `YYYY-MM-DD` form.
  final String observedDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether the caregiver has seen the child do this.
  bool get isObserved => status == 'observed';

  factory MilestoneObservation.fromJson(Map<String, dynamic> json) {
    return MilestoneObservation(
      id: json['id'] as String,
      childId: json['childId'] as String,
      milestoneId: json['milestoneId'] as String,
      status: json['status'] as String,
      observedDate: json['observedDate'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// The 4 ECCD developmental domains with parent-friendly display labels.
enum MilestoneDomain {
  cognitive('cognitive', 'Thinking', Icons.psychology_outlined),
  motor('motor', 'Moving', Icons.directions_run_outlined),
  language('language', 'Talking', Icons.chat_bubble_outline),
  socioEmotional('socioEmotional', 'Feelings', Icons.favorite_border);

  const MilestoneDomain(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

/// A developmental observation prompt shown to the caregiver.
class MilestonePrompt {
  const MilestonePrompt({
    required this.id,
    required this.domain,
    required this.title,
    required this.lookFor,
    required this.ageBand,
    this.provenance =
        'Source: CDC Developmental Milestones & Early Learning Guidelines',
  });

  final String id;
  final MilestoneDomain domain;
  final String title;
  final List<String> lookFor;
  final String ageBand;
  final String provenance;
}

const List<MilestonePrompt> sampleMilestonePrompts = [
  MilestonePrompt(
    id: 'lan-12-01',
    domain: MilestoneDomain.language,
    title: 'Points to familiar objects when named',
    lookFor: [
      'Points at the ball when you say "ball"',
      'Looks toward a named person',
    ],
    ageBand: '12-23 months',
    provenance: 'Source: AAP & CDC Early Communication Guidelines',
  ),
  MilestonePrompt(
    id: 'lan-12-02',
    domain: MilestoneDomain.language,
    title: 'Says one or two simple words',
    lookFor: ['Says "mama" or "dada" on purpose', 'Names a favorite toy'],
    ageBand: '12-23 months',
    provenance: 'Source: AAP & CDC Early Communication Guidelines',
  ),
  MilestonePrompt(
    id: 'soc-12-01',
    domain: MilestoneDomain.socioEmotional,
    title: 'Enjoys a back-and-forth moment during play',
    lookFor: [
      'Passes a toy back and forth with you',
      'Smiles or responds when taking turns',
    ],
    ageBand: '12-23 months',
    provenance: 'Source: Early Childhood Development Framework',
  ),
  MilestonePrompt(
    id: 'cog-12-01',
    domain: MilestoneDomain.cognitive,
    title: 'Finds a hidden toy',
    lookFor: [
      'Watches where you hide an item under a cloth or cup',
      'Uncovers or reaches directly for the hidden toy',
    ],
    ageBand: '12-23 months',
    provenance: 'Source: CDC Developmental Milestones (12–23m)',
  ),
  MilestonePrompt(
    id: 'mot-12-01',
    domain: MilestoneDomain.motor,
    title: 'Takes a few steps independently',
    lookFor: ['Walks a few paces without holding onto furniture or hands'],
    ageBand: '12-23 months',
    provenance: 'Source: CDC Developmental Milestones (12–23m)',
  ),
];
