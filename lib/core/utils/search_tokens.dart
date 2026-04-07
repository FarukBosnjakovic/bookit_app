List<String> generateSearchTokens(String name, List<String> cuisines, String city) {
  final terms = [name, city, ...cuisines];
  final tokens = <String>{};
  for (final term in terms) {
    final words = term.toLowerCase().trim().split(' ');
    for (final word in words) {
      for (int i = 1; i <= word.length; i++) {
        tokens.add(word.substring(0, i));
      }
    }
  }
  return tokens.toList();
}