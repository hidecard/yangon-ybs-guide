class MyanmarSoundex {
  MyanmarSoundex._();

  static final _regex = RegExp(r'[\u1000-\u109F]');
  static final _map = {
    'ကခ': 'က', 'ငါ': 'င', 'စျ': 'စ', 'ဇ္ဗ': 'ဇ', 'တ္မန': 'တ',
    'ပ္ဖ': 'ပ', 'ဗလ': 'ဗ', 'ရွ': 'ရ', 'လျ': 'လ', 'ဝါ': 'ဝ',
    'သြ': 'သ', 'ဟြ': 'ဟ',
  };

  static String normalize(String input) {
    if (input.isEmpty) return '';
    var s = input.trim().toLowerCase();
    for (final entry in _map.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }
    final buffer = StringBuffer();
    for (final codeUnit in s.runes) {
      final char = String.fromCharCode(codeUnit);
      buffer.write(_regex.hasMatch(char) ? char : '');
    }
    return buffer.toString();
  }

  static int similarity(String a, String b) {
    final na = normalize(a);
    final nb = normalize(b);
    if (na.isEmpty || nb.isEmpty) return 0;
    if (na == nb) return 100;

    final longer = na.length >= nb.length ? na : nb;
    final shorter = na.length >= nb.length ? nb : na;
    if (longer.isEmpty) return 0;

    final editDistance = _levenshtein(longer, shorter);
    final maxLen = longer.length;
    return ((maxLen - editDistance) / maxLen * 100).round();
  }

  static int _levenshtein(String s, String t) {
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final v0 = List<int>.generate(t.length + 1, (i) => i);
    final v1 = List<int>.filled(t.length + 1, 0);

    for (var i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < t.length; j++) {
        final cost = s[i] == t[j] ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
      v0.setRange(0, v0.length, v1);
    }
    return v1[t.length];
  }

  static List<String> suggest(String query, List<String> options,
      {int maxResults = 5, double threshold = 60.0}) {
    final scored = options.map((opt) {
      final score = similarity(query, opt);
      final starts = opt.startsWith(normalize(query)) ? 20 : 0;
      return MapEntry(opt, score.toDouble() + starts);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored
        .where((e) => e.value >= threshold)
        .take(maxResults)
        .map((e) => e.key)
        .toList();
  }
}
