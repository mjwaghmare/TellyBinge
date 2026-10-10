import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/profile/presentation/pages/profile_page.dart';

void main() {
  group('ProfilePage.normalizeShowCategory', () {
    test('unparseable nextCode does not reclassify FINISHED show as WATCH_NEXT', () {
      final category = ProfilePage.normalizeShowCategory({
        'category': 'FINISHED',
        'nextEpisodeCode': 'Invalid-Code-Format',
        'watchedEpisodes': ['1-1', '1-2'],
        'totalEpisodes': 2,
      });
      expect(category, 'FINISHED');
    });

    test('unparseable nextCode does not reclassify UP_TO_DATE show as WATCH_NEXT', () {
      final category = ProfilePage.normalizeShowCategory({
        'category': 'UP_TO_DATE',
        'nextEpisodeCode': 'NonStandardCode',
        'watchedEpisodes': ['1-1'],
        'totalEpisodes': 5,
      });
      expect(category, 'UP_TO_DATE');
    });

    test('valid nextCode reclassifies FINISHED show as WATCH_NEXT when aired unwatched episode exists', () {
      final category = ProfilePage.normalizeShowCategory({
        'category': 'FINISHED',
        'nextEpisodeCode': 'S02 | E01',
        'watchedEpisodes': ['1-1', '1-2'],
        'totalEpisodes': 4,
      });
      expect(category, 'WATCH_NEXT');
    });

    test('fallback branch returns UP_TO_DATE when next episode is upcoming', () {
      final futureDate = DateTime.now().add(const Duration(days: 5)).toIso8601String();
      final category = ProfilePage.normalizeShowCategory({
        'category': 'HAVENT_STARTED',
        'watchedEpisodes': ['1-1'],
        'nextEpisodeCode': 'S01 | E02',
        'upcomingEpisodeCode': 'S01 | E02',
        'hasUpcoming': true,
        'upcomingAirDate': futureDate,
        'totalEpisodes': 5,
      });
      expect(category, 'UP_TO_DATE');
    });

    test('fallback branch returns UP_TO_DATE when totalEpisodes > 0 and fully watched', () {
      final category = ProfilePage.normalizeShowCategory({
        'category': 'HAVENT_STARTED',
        'watchedEpisodes': ['1-1', '1-2', '1-3'],
        'nextEpisodeCode': '',
        'totalEpisodes': 3,
      });
      expect(category, 'UP_TO_DATE');
    });

    test('fallback branch returns WATCH_NEXT when missing evidence of aired unwatched episodes but not fully watched and not upcoming', () {
      final category = ProfilePage.normalizeShowCategory({
        'category': 'HAVENT_STARTED',
        'watchedEpisodes': ['1-1'],
        'nextEpisodeCode': '',
        'totalEpisodes': 10,
      });
      expect(category, 'WATCH_NEXT');
    });

    test('fallback branch with empty rawCategory returns WATCH_NEXT when partially watched and not upcoming', () {
      final category = ProfilePage.normalizeShowCategory({
        'category': '',
        'watchedEpisodes': ['1-1'],
        'nextEpisodeCode': 'TBA',
        'totalEpisodes': 5,
      });
      expect(category, 'WATCH_NEXT');
    });

    test('trimmed and case-insensitive TBA nextCode does not reclassify FINISHED show', () {
      final category = ProfilePage.normalizeShowCategory({
        'category': 'FINISHED',
        'nextEpisodeCode': '   tba   ',
        'watchedEpisodes': ['1-1', '1-2'],
        'totalEpisodes': 2,
      });
      expect(category, 'FINISHED');
    });

    test('trimmed and case-insensitive Up to date nextCode does not reclassify UP_TO_DATE show', () {
      final category = ProfilePage.normalizeShowCategory({
        'category': 'UP_TO_DATE',
        'nextEpisodeCode': '  up to date  ',
        'watchedEpisodes': ['1-1'],
        'totalEpisodes': 5,
      });
      expect(category, 'UP_TO_DATE');
    });
  });
}
