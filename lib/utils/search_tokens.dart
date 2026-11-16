/// Word-beginning tokens for searching ALL farmers on the server.
///
/// Firestore can't search inside text: it only matches exact values. So
/// each farmer stores the beginnings of every word in their name, and a
/// search asks "whose list contains what was typed?". Example:
///   "Joseph Kamau"  ->  jo, jos, jose, josep, joseph, ka, kam, kama, kamau
/// That way "jos" and "kam" both find him.
///
/// MUST stay identical to searchTokens() in
/// tools/seed_import/add_search_tokens.mjs, which back-filled the seeded
/// farmers. If the two ever disagree, some farmers stop being findable.
class SearchTokens {
  SearchTokens._();

  /// Longest beginning stored per word. Longer typed words are cut to this
  /// before searching, so they still match.
  static const maxLen = 15;

  /// Lowercase, apostrophes dropped (Ng'ang'a -> ngganga style), split on
  /// anything that isn't a letter or digit, words of 2+ characters.
  static List<String> words(String text) => text
      .toLowerCase()
      .replaceAll("'", '')
      .replaceAll('’', '')
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.length >= 2)
      .toList();

  /// Every beginning (2..maxLen characters) of every word, de-duplicated
  /// and sorted so the stored list is stable between runs.
  static List<String> forName(String name) {
    final out = <String>{};
    for (final w in words(name)) {
      for (var i = 2; i <= w.length && i <= maxLen; i++) {
        out.add(w.substring(0, i));
      }
    }
    return out.toList()..sort();
  }

  /// The one word sent to the server for a typed query: the longest, since
  /// it narrows the results most. Other typed words are checked on the
  /// phone afterwards. Null if nothing searchable was typed.
  static String? queryToken(String typed) {
    final ws = words(typed);
    if (ws.isEmpty) return null;
    ws.sort((a, b) => b.length.compareTo(a.length));
    final w = ws.first;
    return w.length > maxLen ? w.substring(0, maxLen) : w;
  }
}