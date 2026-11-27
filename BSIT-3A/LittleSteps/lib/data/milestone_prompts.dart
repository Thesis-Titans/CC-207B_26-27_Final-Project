import '../models/milestone.dart';

/// Default non-diagnostic observational prompts grouped across age bands.
const List<MilestonePrompt> defaultMilestonePrompts = [
  // 0-11 months
  MilestonePrompt(
    id: 'lan-00-01',
    domain: MilestoneDomain.language,
    title: 'Reacts to familiar voices and sounds',
    lookFor: [
      'Turns head toward caregiver when spoken to',
      'Makes cooing or babbling sounds in response',
    ],
    ageBand: '0-11 months',
    provenance: 'Source: ECCD Council Early Learning Guidelines (0–11m)',
  ),
  MilestonePrompt(
    id: 'mot-00-01',
    domain: MilestoneDomain.motor,
    title: 'Pushes up on arms during tummy time',
    lookFor: [
      'Lifts head and chest while lying on tummy',
      'Rolls from tummy to back during play',
    ],
    ageBand: '0-11 months',
    provenance: 'Source: CDC Milestone Guidelines (0–11m)',
  ),
  MilestonePrompt(
    id: 'cog-00-01',
    domain: MilestoneDomain.cognitive,
    title: 'Explores objects by reaching and grasping',
    lookFor: [
      'Reaches for a toy held within reach',
      'Passes an item from one hand to the other',
    ],
    ageBand: '0-11 months',
    provenance: 'Source: Early Learning & Development Standards',
  ),
  MilestonePrompt(
    id: 'soc-00-01',
    domain: MilestoneDomain.socioEmotional,
    title: 'Smiles and laughs during playful interactions',
    lookFor: [
      'Smiles spontaneously when looking at family members',
      'Enjoys games like peek-a-boo',
    ],
    ageBand: '0-11 months',
    provenance: 'Source: CDC Early Social-Emotional Milestones',
  ),

  // 12-23 months
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

  // 24-35 months
  MilestonePrompt(
    id: 'lan-24-01',
    domain: MilestoneDomain.language,
    title: 'Uses two-word phrases to express needs',
    lookFor: [
      'Says phrases like "more milk" or "big dog"',
      'Repeats simple words heard during play',
    ],
    ageBand: '24-35 months',
    provenance: 'Source: ECCD Early Language Framework',
  ),
  MilestonePrompt(
    id: 'mot-24-01',
    domain: MilestoneDomain.motor,
    title: 'Jumps with both feet leaving the ground',
    lookFor: [
      'Jumps off a low step with both feet together',
      'Kicks a large ball while maintaining balance',
    ],
    ageBand: '24-35 months',
    provenance: 'Source: CDC Toddler Motor Benchmarks',
  ),
  MilestonePrompt(
    id: 'cog-24-01',
    domain: MilestoneDomain.cognitive,
    title: 'Sorts everyday items by color or size',
    lookFor: [
      'Groups red blocks together or pairs shoes',
      'Completes simple 3-piece wooden puzzles',
    ],
    ageBand: '24-35 months',
    provenance: 'Source: Early Learning & Development Standards',
  ),
  MilestonePrompt(
    id: 'soc-24-01',
    domain: MilestoneDomain.socioEmotional,
    title: 'Notices and mirrors other children at play',
    lookFor: [
      'Plays alongside another child with similar toys',
      'Shows awareness when a playmate is smiling or crying',
    ],
    ageBand: '24-35 months',
    provenance: 'Source: Early Childhood Social-Emotional Guidelines',
  ),

  // 36-47 months
  MilestonePrompt(
    id: 'lan-36-01',
    domain: MilestoneDomain.language,
    title: 'Asks "who", "what", and "where" questions',
    lookFor: [
      'Asks curious questions about everyday objects',
      'Speaks in sentences of 3 to 4 words',
    ],
    ageBand: '36-47 months',
    provenance: 'Source: DepEd Kindergarten & ECCD Framework',
  ),
  MilestonePrompt(
    id: 'mot-36-01',
    domain: MilestoneDomain.motor,
    title: 'Balances on one foot for a moment',
    lookFor: [
      'Stands on one foot for 2 to 3 seconds',
      'Catches a large bounced ball with two hands',
    ],
    ageBand: '36-47 months',
    provenance: 'Source: CDC Preschool Developmental Milestones',
  ),
  MilestonePrompt(
    id: 'cog-36-01',
    domain: MilestoneDomain.cognitive,
    title: 'Identifies familiar colors and counts small sets',
    lookFor: [
      'Names common colors like red, blue, and yellow',
      'Counts up to 3 objects by touching each one',
    ],
    ageBand: '36-47 months',
    provenance: 'Source: Early Learning Cognitive Guidelines',
  ),
  MilestonePrompt(
    id: 'soc-36-01',
    domain: MilestoneDomain.socioEmotional,
    title: 'Takes turns during simple games with guidance',
    lookFor: [
      'Shares toys when gently reminded',
      'Expresses a wide range of emotions through words',
    ],
    ageBand: '36-47 months',
    provenance: 'Source: ECCD Social Competence Standards',
  ),

  // 48-59 months
  MilestonePrompt(
    id: 'lan-48-01',
    domain: MilestoneDomain.language,
    title: 'Tells a simple story about their day',
    lookFor: [
      'Describes what happened at playtime in sequence',
      'Uses full sentences with words like "because"',
    ],
    ageBand: '48-59 months',
    provenance: 'Source: DepEd MATATAG Curriculum Kindergarten Framework',
  ),
  MilestonePrompt(
    id: 'mot-48-01',
    domain: MilestoneDomain.motor,
    title: 'Hops and skips during energetic games',
    lookFor: [
      'Hops forward on one foot several times',
      'Pours water or sand into a cup without spilling',
    ],
    ageBand: '48-59 months',
    provenance: 'Source: CDC Early Childhood Motor Guidelines',
  ),
  MilestonePrompt(
    id: 'cog-48-01',
    domain: MilestoneDomain.cognitive,
    title: 'Recognizes some printed letters and numbers',
    lookFor: [
      'Points out familiar letters like the first letter of their name',
      'Draws a person with 3 or more recognizable parts',
    ],
    ageBand: '48-59 months',
    provenance: 'Source: DepEd MATATAG Kindergarten Standards',
  ),
  MilestonePrompt(
    id: 'soc-48-01',
    domain: MilestoneDomain.socioEmotional,
    title: 'Engages in cooperative pretend play with peers',
    lookFor: [
      'Agrees on roles during make-believe games',
      'Comforts a friend or sibling who seems upset',
    ],
    ageBand: '48-59 months',
    provenance: 'Source: ECCD Early Social Development Standards',
  ),
];
