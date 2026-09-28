/// Generates a clean, alphanumeric lowercase username handle from a display name.
///
/// Strips non-alphanumeric characters, converts to lowercase, and pads single
/// trailing digits (e.g. `user5` -> `user05`).
/// If [name] is null, blank, or `'User'`, returns [fallback].
String generateUsername(String? name, {String fallback = 'user_popverse'}) {
  if (name == null) return fallback;
  final trimmed = name.trim();
  if (trimmed.isEmpty || trimmed == 'User') return fallback;

  // Strip everything except letters and numbers, then lowercase
  String cleanName = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
  if (cleanName.isEmpty) return fallback;

  // If it ends with exactly one digit (like 'mjwaghmare5'), pad it to '05'
  if (RegExp(r'[a-z]\d$').hasMatch(cleanName)) {
    cleanName = '${cleanName.substring(0, cleanName.length - 1)}0${cleanName.substring(cleanName.length - 1)}';
  }

  return cleanName;
}
