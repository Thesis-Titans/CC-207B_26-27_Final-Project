import '../models/activity.dart';

/// A traditional Philippine children's rhyme paired with a play prompt.
class PhilippineRhyme {
  /// Creates a [PhilippineRhyme].
  const PhilippineRhyme({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.domain,
    required this.domainLabel,
    required this.language,
    required this.lyrics,
    required this.actionPrompt,
    this.materials = const ['None required'],
    this.durationMinutes = 5,
  });

  /// Unique identifier for this rhyme.
  final String id;

  /// Display title of the rhyme.
  final String title;

  /// Short subtitle describing the play focus.
  final String subtitle;

  /// Developmental domain key matching the catalog schema.
  final String domain;

  /// Caregiver-facing label for [domain].
  final String domainLabel;

  /// ISO language code of the rhyme lyrics.
  final String language;

  /// Lines of lyrics sung with the child.
  final List<String> lyrics;

  /// Movement or interaction cue performed while singing.
  final String actionPrompt;

  /// Optional household items used during the rhyme.
  final List<String> materials;

  /// Estimated duration in minutes.
  final int durationMinutes;

  /// Converts this rhyme into an [Activity] that can be scheduled in a plan.
  Activity toActivity({String? childNickname}) {
    final name = childNickname ?? 'your child';
    return Activity(
      id: id,
      title: 'Sing & Play: $title',
      type: 'rhyme',
      language: language,
      setting: 'either',
      ageBand: 'all',
      domain: domain,
      durationMinutes: durationMinutes,
      durationEstimate: '$durationMinutes mins',
      materials: materials,
      instructions: [
        'Sit together in a comfortable spot facing $name.',
        'Sing through the rhyme with expressive hand motions and rhythm.',
        actionPrompt,
        'Pause and invite $name to copy your gestures or sound out favorite words.',
      ],
      provenanceSource: 'Traditional Philippine Children\'s Rhyme & Folk Song',
      status: 'reviewed_approved',
      limitations: 'Shared cultural singing and bonding routine.',
    );
  }
}

/// Rhymes available in the Explore shelf.
const List<PhilippineRhyme> philippineRhymes = [
  PhilippineRhyme(
    id: 'rhyme-bahay-kubo',
    title: 'Bahay Kubo',
    subtitle: 'Traditional vegetable naming & rhythm song',
    domain: 'cognitive',
    domainLabel: 'Thinking',
    language: 'fil',
    lyrics: [
      'Bahay kubo, kahit munti,',
      'Ang halaman doon ay sari-sari:',
      'Singkamas at talong, sigarilyas at mani,',
      'Sitaw, bataw, patani.',
      'Kundol, patola, upo\'t kalabasa,',
      'At saka mayroon pang labanos, mustasa,',
      'Sibuyas, kamatis, bawang at luya,',
      'Sa paligid-ligid ay puro linga.',
    ],
    actionPrompt: 'Clap to the beat and pretend to pick each vegetable from the ground as you sing its name!',
    materials: ['None required (optional: toy vegetables or drawing)'],
    durationMinutes: 5,
  ),
  PhilippineRhyme(
    id: 'rhyme-pakitong-kitong',
    title: 'Tong, Tong, Tong Pakitong-kitong',
    subtitle: 'Playful crab pinch & finger-movement song',
    domain: 'motor',
    domainLabel: 'Moving',
    language: 'fil',
    lyrics: [
      'Tong, tong, tong, tong, pakitong-kitong,',
      'Alimango sa dagat, malaki at masarap!',
      'Kay hirap hulihin, sapagkat nangangagat,',
      'Tong, tong, tong, tong, pakitong-kitong!',
    ],
    actionPrompt: 'Make crab claws with thumbs and index fingers. Pinch gently in the air on "nangangagat"!',
    materials: ['None required'],
    durationMinutes: 5,
  ),
  PhilippineRhyme(
    id: 'rhyme-pen-pen',
    title: 'Pen Pen de Sarapen',
    subtitle: 'Rhythmic palm-tapping circle rhyme',
    domain: 'socioEmotional',
    domainLabel: 'Feelings',
    language: 'fil',
    lyrics: [
      'Pen, pen de sarapen,',
      'De kutsilyo, de almasen,',
      'Haw, haw de karabaw,',
      'Batuten!',
      'Sipit namimilipit,',
      'Ginto\'t pilak namumulaklak,',
      'Sa tabi ng dagat.',
    ],
    actionPrompt: 'Lay your hands flat on your laps. Gently tap each hand in rhythm on every syllable.',
    materials: ['None required'],
    durationMinutes: 5,
  ),
  PhilippineRhyme(
    id: 'rhyme-ako-may-lobo',
    title: 'Ako ay May Lobo',
    subtitle: 'Breath control & playful surprise rhyme',
    domain: 'language',
    domainLabel: 'Talking',
    language: 'fil',
    lyrics: [
      'Ako ay may lobo, lumipad sa langit,',
      '\'Di ko na nakita, pumutok na pala!',
      'Sayang ang pera ko, binili ng lobo,',
      'Sa pagkain sana, nabusog pa ako.',
    ],
    actionPrompt: 'Pretend to blow up a huge balloon with deep breaths, then clap loudly on "Pumutok na pala!"',
    materials: ['None required'],
    durationMinutes: 5,
  ),
  PhilippineRhyme(
    id: 'rhyme-tatlong-bibe',
    title: 'Tatlong Bibe',
    subtitle: 'Gross-motor waddling & counting action song',
    domain: 'motor',
    domainLabel: 'Moving',
    language: 'fil',
    lyrics: [
      'May tatlong bibe akong nakita,',
      'Mataba, mapayat, mga bibe,',
      'Ngunit ang may pakpak sa likod ay iisa,',
      'Siya ang lider na nagsabi ng "Kwak, kwak, kwak!"',
    ],
    actionPrompt: 'Waddle like a little duck with elbows bent and flap hands on "Kwak, kwak, kwak!"',
    materials: ['None required'],
    durationMinutes: 5,
  ),
];
