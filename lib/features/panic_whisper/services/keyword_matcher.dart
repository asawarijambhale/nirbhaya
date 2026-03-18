/// Handles case-insensitive keyword matching with basic fuzzy support.
class KeywordMatcher {
  /// Returns true if [spoken] contains the [codeword] (case-insensitive).
  /// Also handles common speech-to-text variations by checking if all
  /// words of the codeword appear in the spoken text.
  static bool matches(String spoken, String codeword) {
    if (codeword.isEmpty) return false;

    final spokenNorm = spoken.toLowerCase().trim();
    final codeNorm = codeword.toLowerCase().trim();

    // Exact or substring match
    if (spokenNorm.contains(codeNorm)) return true;

    // Fuzzy: all words of codeword present in spoken text
    final codeWords = codeNorm.split(RegExp(r'\s+'));
    final spokenWords = spokenNorm.split(RegExp(r'\s+'));
    return codeWords.every((w) => spokenWords.contains(w));
  }
}
