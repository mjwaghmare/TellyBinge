/// Ranks TMDB artwork (the `images` block of a details response, or an
/// `/images` response) for the Polaroid share card and details-page banner.
///
/// The share card's photo area is ~0.84 wide-per-tall, so posters (0.67) crop far
/// less than backdrops (1.78), and text-free art avoids repeating the title the
/// card already prints underneath.
class TmdbArtwork {
  TmdbArtwork._();

  /// Below this width an image looks soft when rendered at `w780`.
  static const int _minSharpWidth = 1000;

  /// Best default image for the share card, in order of preference:
  /// text-free poster → English poster → text-free backdrop → any backdrop.
  /// Returns null when [images] has nothing usable.
  static String? bestSharePath(Map<String, dynamic>? images) {
    if (images == null) return null;
    final posters = _ranked(images['posters']);
    final backdrops = _ranked(images['backdrops']);

    return _firstPath(posters.where(_isTextFree)) ??
        _firstPath(posters) ??
        _firstPath(backdrops.where(_isTextFree)) ??
        _firstPath(backdrops);
  }

  /// Best backdrop for a details-page banner: the top text-free one. The
  /// banner overlays its own title, so key art with the title or logo baked in
  /// would double up. Returns null when there's none, leaving callers to fall
  /// back to TMDB's primary `backdrop_path`.
  static String? bestBannerPath(Map<String, dynamic>? images) {
    if (images == null) return null;
    return _firstPath(_ranked(images['backdrops']).where(_isTextFree));
  }

  /// Top-ranked file paths of one kind (`'posters'` or `'backdrops'`).
  static List<String> topPaths(
    Map<String, dynamic>? images,
    String kind, {
    int limit = 8,
  }) {
    if (images == null) return const [];
    return _ranked(images[kind])
        .take(limit)
        .map((img) => img['file_path'] as String)
        .toList();
  }

  static bool _isTextFree(Map<String, dynamic> img) =>
      img['iso_639_1'] == null;

  static String? _firstPath(Iterable<Map<String, dynamic>> images) =>
      images.isEmpty ? null : images.first['file_path'] as String;

  /// Sharp images before soft ones, voted before unvoted, then by
  /// `vote_average` and `vote_count`. Unvoted images are ranked last rather
  /// than dropped — many newer titles have nothing else.
  static List<Map<String, dynamic>> _ranked(dynamic raw) {
    final images = (raw as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((img) => (img['file_path'] as String?)?.isNotEmpty ?? false)
        .toList();

    int flag(bool value) => value ? 1 : 0;
    num numOf(Map<String, dynamic> img, String key) =>
        (img[key] as num?) ?? 0;

    images.sort((a, b) {
      final bySharp = flag(numOf(b, 'width') >= _minSharpWidth)
          .compareTo(flag(numOf(a, 'width') >= _minSharpWidth));
      if (bySharp != 0) return bySharp;
      final byVoted = flag(numOf(b, 'vote_count') > 0)
          .compareTo(flag(numOf(a, 'vote_count') > 0));
      if (byVoted != 0) return byVoted;
      final byAverage =
          numOf(b, 'vote_average').compareTo(numOf(a, 'vote_average'));
      if (byAverage != 0) return byAverage;
      return numOf(b, 'vote_count').compareTo(numOf(a, 'vote_count'));
    });
    return images;
  }
}
