/// Ordered `(key, label)` pairs for the four early-learning developmental domains.
const List<(String, String)> developmentalDomains = [
  ('cognitive', 'Thinking'),
  ('motor', 'Moving'),
  ('language', 'Talking'),
  ('socioEmotional', 'Feelings'),
];

/// Maps a backend developmental [domain] key to its caregiver-friendly label.
String friendlyDomainLabel(String domain) {
  switch (domain.toLowerCase()) {
    case 'cognitive':
      return 'Thinking';
    case 'motor':
      return 'Moving';
    case 'language':
      return 'Talking';
    case 'socioemotional':
    case 'socio_emotional':
    case 'socio-emotional':
      return 'Feelings';
    default:
      return 'Talking';
  }
}

/// Maps a backend developmental [domain] key to its formal display label.
String formalDomainLabel(String domain) {
  switch (domain.toLowerCase()) {
    case 'socioemotional':
    case 'socio_emotional':
    case 'socio-emotional':
      return 'Socio-emotional';
    case 'cognitive':
      return 'Cognitive';
    case 'motor':
      return 'Motor';
    case 'language':
      return 'Language';
    default:
      return domain.isEmpty
          ? domain
          : '${domain[0].toUpperCase()}${domain.substring(1)}';
  }
}

/// Maps a backend play [setting] key to its display label.
String formatSettingLabel(String setting) {
  switch (setting.toLowerCase()) {
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
